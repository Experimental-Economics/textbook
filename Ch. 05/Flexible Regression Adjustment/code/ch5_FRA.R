# =============================================================================
# Flexible Regression Adjustment (FRA): Variance Reduction via ML Cross-Fitting
# =============================================================================
# Demonstrates variance reduction from flexible covariate adjustment using
# machine learning methods with cross-fitting. Replicates Table 7 from Chapter 5.
#
# Compares three estimators on Oregon Health Insurance Experiment (OHIE) data
# (Finkelstein et al., 2016):
#
#   SM  = Subsample Means (simple difference in means, no covariates)
#   LRA = Linear Regression Adjustment (OLS-based cross-fitting)
#   FRA = Flexible Regression Adjustment (Random Forest-based cross-fitting)
#
# For each estimator, three parameters are estimated:
#   1. Reduced Form: Impact of treatment assignment (W) on ER visits (Y)
#   2. First Stage: Impact of treatment assignment (W) on Medicaid take-up (D)
#   3. LATE: Local Average Treatment Effect using Wald estimator (RF / FS)
#
# The cross-fitting approach avoids overfitting by splitting the sample into
# folds, fitting models on other folds, and predicting on held-out data. This
# ensures valid asymptotic inference while allowing flexible functional forms.
#
# NOTE: Random Forest fitting may take several minutes to complete depending
# on sample size and number of covariates.
#
# Outputs: LaTeX table (.tex) and styled HTML table (.html)
#
# Reference: Chapter 5, Power Analysis
# Data: Oregon Health Insurance Experiment (Finkelstein et al., 2016)
# =============================================================================

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Automatically set working directory to the folder containing this script.
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
} else if (length(sys.frames()) > 0 && !is.null(sys.frame(1)$ofile)) {
  setwd(dirname(sys.frame(1)$ofile))
} else if (!is.null(commandArgs(trailingOnly = FALSE))) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
  }
}

# Install any missing packages, then load them
required_lib <- c("dplyr", "readr", "randomForest")
invisible(lapply(required_lib, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  library(pkg, character.only = TRUE)
}))

# Output directory: one level up from code/
output_dir <- file.path(dirname(getwd()), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)


# =============================================================================
# PART 1: FRA FUNCTIONS
# =============================================================================

# --- Cross-fitted regression adjustment --------------------------------------
# Performs sample-splitting (cross-fitting) to estimate E[Y | X, W=w] for each
# outcome Y and treatment level w. Then constructs "influence function" columns
# that are the building blocks for regression-adjusted estimators.
#
# Inputs:
#   dat            : data frame with outcomes, treatment, and covariates
#   outcome_cols   : names of outcome columns (e.g., c("Y", "D"))
#   treat_col      : name of treatment column (e.g., "W")
#   covariate_cols : names of covariate columns
#   n_folds        : number of cross-fitting folds
#   method         : "linear" (OLS) or "rf" (Random Forest)
#
# Output:
#   Original data frame augmented with columns:
#     m_{outcome}_{treat} : cross-fitted predictions E[Y|X, W=treat]
#     u_{outcome}_{treat} : influence function for E[Y(treat)]
#       -> mean(u) = regression-adjusted estimator for E[Y(treat)]
#       -> var(u)/N = asymptotically valid variance estimate

FRA <- function(dat, outcome_cols = c("Y"),
                treat_col = "W",
                covariate_cols = c("X1", "X2", "X3"),
                n_folds = 2,
                method = "linear") {

  dat <- as.data.frame(dat)

  # --- Step 1: Create balanced folds -----------------------------------------
  # Sort by treatment status, then shuffle within each group to ensure
  # each fold has roughly the same proportion of treated/control units
  dat$order <- sample(seq_len(nrow(dat)))
  dat <- dat %>% arrange(!!sym(treat_col), order)
  dat$fold <- rep(1:n_folds, length.out = nrow(dat))

  treat_levels <- sort(unique(dat[[treat_col]]))

  # --- Step 2: Cross-fitting -------------------------------------------------
  # For each (outcome, treatment level) pair, fit a model on all folds
  # except the current one, then predict on the held-out fold.
  # This avoids overfitting and ensures valid inference.
  for (y in outcome_cols) {
    for (w in treat_levels) {
      col_name <- paste0("m_", y, "_", w)
      dat[[col_name]] <- 0

      for (f in 1:n_folds) {
        # Training set: other folds, same treatment group
        train <- dat[dat$fold != f & dat[[treat_col]] == w, ]
        # Held-out set: current fold (all treatment groups)
        holdout <- dat[dat$fold == f, ]

        fml <- formula(paste(y, "~", paste(covariate_cols, collapse = " + ")))

        if (method == "linear") {
          model <- lm(fml, data = train)
        } else if (method == "rf") {
          model <- randomForest(fml, data = train)
        } else {
          stop("method must be 'linear' or 'rf'")
        }

        dat[dat$fold == f, col_name] <- predict(model, newdata = holdout)
      }
    }
  }

  # --- Step 3: Construct influence functions ---------------------------------
  # For each (outcome, treatment level), the influence function is:
  #   u = (1/P(W=w)) * (Y - m(X)) * 1{W=w} + m(X)
  # where m(X) = E[Y|X, W=w] is the cross-fitted prediction.
  # The mean of u is the regression-adjusted estimator for E[Y(w)].
  for (w in treat_levels) {
    prop_w <- mean(dat[[treat_col]] == w)
    for (y in outcome_cols) {
      m_col <- paste0("m_", y, "_", w)
      u_col <- paste0("u_", y, "_", w)
      dat[[u_col]] <- ifelse(dat[[treat_col]] == w,
                             (1 / prop_w) * (dat[[y]] - dat[[m_col]]),
                             0) + dat[[m_col]]
    }
  }

  dat
}


# --- Estimate ATE -----------------------------------------------------------
# ATE = E[Y(1)] - E[Y(0)]
# Uses the influence function columns from FRA to compute point estimate
# and standard error.

FRA_ATE <- function(dat_fra, outcome_col = "Y", treat_lvl = 1, ctrl_lvl = 0) {
  u1 <- dat_fra[[paste0("u_", outcome_col, "_", treat_lvl)]]
  u0 <- dat_fra[[paste0("u_", outcome_col, "_", ctrl_lvl)]]
  u  <- u1 - u0

  pe <- mean(u)
  se <- sd(u) / sqrt(length(u))
  c(pe = pe, se = se)
}


# --- Estimate LATE -----------------------------------------------------------
# LATE = E[Y(1) - Y(0)] / E[D(1) - D(0)]
# Uses the delta method for standard errors of the Wald (IV) estimator.

FRA_LATE <- function(dat_fra, outcome_col = "Y", endog_col = "D",
                     treat_lvl = 1, ctrl_lvl = 0) {
  u_num   <- dat_fra[[paste0("u_", outcome_col, "_", treat_lvl)]] -
             dat_fra[[paste0("u_", outcome_col, "_", ctrl_lvl)]]
  u_denom <- dat_fra[[paste0("u_", endog_col, "_", treat_lvl)]] -
             dat_fra[[paste0("u_", endog_col, "_", ctrl_lvl)]]

  n  <- nrow(dat_fra)
  pe <- mean(u_num) / mean(u_denom)

  # Delta method: Var(g(mu)) ≈ D' * Sigma * D / n
  VCV <- matrix(c(var(u_num),              cov(u_num, u_denom),
                   cov(u_num, u_denom),     var(u_denom)),
                nrow = 2) / n
  D <- c(1 / mean(u_denom), -mean(u_num) / mean(u_denom)^2)
  se <- as.numeric(sqrt(t(D) %*% VCV %*% D))

  c(pe = pe, se = se)
}


# --- Subsample Means (SM) estimator -----------------------------------------
# Simple difference in means — no covariates, no adjustment.

SM_ATE <- function(dat, outcome_col = "Y", treat_col = "W",
                   treat_lvl = 1, ctrl_lvl = 0) {
  y1 <- dat[[outcome_col]][dat[[treat_col]] == treat_lvl]
  y0 <- dat[[outcome_col]][dat[[treat_col]] == ctrl_lvl]

  pe <- mean(y1) - mean(y0)
  se <- sqrt(var(y1) / length(y1) + var(y0) / length(y0))
  c(pe = pe, se = se)
}

SM_LATE <- function(dat, outcome_col = "Y", endog_col = "D", treat_col = "W",
                    treat_lvl = 1, ctrl_lvl = 0) {
  rf <- SM_ATE(dat, outcome_col, treat_col, treat_lvl, ctrl_lvl)  # reduced form
  fs <- SM_ATE(dat, endog_col,  treat_col, treat_lvl, ctrl_lvl)  # first stage

  pe <- rf["pe"] / fs["pe"]

  # Delta method
  y1 <- dat[[outcome_col]][dat[[treat_col]] == treat_lvl]
  y0 <- dat[[outcome_col]][dat[[treat_col]] == ctrl_lvl]
  d1 <- dat[[endog_col]][dat[[treat_col]] == treat_lvl]
  d0 <- dat[[endog_col]][dat[[treat_col]] == ctrl_lvl]

  u_num   <- c(y1 - mean(y1), -(y0 - mean(y0)))
  u_denom <- c(d1 - mean(d1), -(d0 - mean(d0)))
  n <- nrow(dat)
  VCV <- matrix(c(var(u_num),           cov(u_num, u_denom),
                   cov(u_num, u_denom),  var(u_denom)),
                nrow = 2) / n
  D <- c(1 / fs["pe"], -rf["pe"] / fs["pe"]^2)
  se <- as.numeric(sqrt(t(D) %*% VCV %*% D))

  c(pe = unname(pe), se = se)
}


# =============================================================================
# PART 2: REPLICATE TABLE 7 ON OHIE DATA
# =============================================================================

# --- Load data ---------------------------------------------------------------
# Y = ER visit indicator, D = Medicaid take-up, W = treatment assignment
# Covariates: gender, age, prior health, education, ER visit counts
data_path <- file.path(dirname(getwd()), "data/OHIE_data.csv")
dat <- read_csv(data_path, show_col_types = FALSE) %>% na.omit()
dat$Y <- as.numeric(dat$Y)

cat("Sample size after dropping NAs:", nrow(dat), "\n")

# All columns after Y, D, W are covariates
covariate_cols <- setdiff(colnames(dat), c("Y", "D", "W"))


# --- Run estimators ----------------------------------------------------------
set.seed(623)

cat("Running FRA (Random Forest, 3 folds)... ")
dat_fra <- FRA(dat, outcome_cols = c("Y", "D"),
               covariate_cols = covariate_cols, method = "rf", n_folds = 3)
cat("done.\n")

cat("Running LRA (Linear, 10 folds)... ")
dat_lra <- FRA(dat, outcome_cols = c("Y", "D"),
               covariate_cols = covariate_cols, method = "linear", n_folds = 10)
cat("done.\n")


# --- Collect results for Table 7 ---------------------------------------------
# Row 1: Reduced form — impact of treatment assignment (W) on ER visits (Y)
sm_er  <- SM_ATE(dat, outcome_col = "Y")
lra_er <- FRA_ATE(dat_lra, outcome_col = "Y")
fra_er <- FRA_ATE(dat_fra, outcome_col = "Y")

# Row 2: First stage — impact of treatment assignment (W) on Medicaid take-up (D)
sm_d  <- SM_ATE(dat, outcome_col = "D")
lra_d <- FRA_ATE(dat_lra, outcome_col = "D")
fra_d <- FRA_ATE(dat_fra, outcome_col = "D")

# Row 3: LATE — Wald estimator (reduced form / first stage)
sm_late  <- SM_LATE(dat)
lra_late <- FRA_LATE(dat_lra)
fra_late <- FRA_LATE(dat_fra)

# Organize into a matrix for display
table7 <- data.frame(
  Parameter = c("ER Visits", "Medicaid Take-Up", "LATE"),
  SM_pe  = c(sm_er["pe"],  sm_d["pe"],  sm_late["pe"]),
  SM_se  = c(sm_er["se"],  sm_d["se"],  sm_late["se"]),
  LRA_pe = c(lra_er["pe"], lra_d["pe"], lra_late["pe"]),
  LRA_se = c(lra_er["se"], lra_d["se"], lra_late["se"]),
  FRA_pe = c(fra_er["pe"], fra_d["pe"], fra_late["pe"]),
  FRA_se = c(fra_er["se"], fra_d["se"], fra_late["se"]),
  row.names = NULL
)

# Print to console
cat("\n--- Table 7: Variance Reduction for OHIE ---\n")
cat(sprintf("%-20s %12s %12s %12s\n", "", "SM", "LRA", "FRA"))
for (i in 1:nrow(table7)) {
  cat(sprintf("%-20s %12s %12s %12s\n",
              table7$Parameter[i],
              sprintf("%.4f", table7$SM_pe[i]),
              sprintf("%.4f", table7$LRA_pe[i]),
              sprintf("%.4f", table7$FRA_pe[i])))
  cat(sprintf("%-20s %12s %12s %12s\n", "",
              sprintf("(%.4f)", table7$SM_se[i]),
              sprintf("(%.4f)", table7$LRA_se[i]),
              sprintf("(%.4f)", table7$FRA_se[i])))
}
cat(sprintf("N = %s\n", format(nrow(dat), big.mark = ",")))


# =============================================================================
# PART 3: EXPORT TABLE 7
# =============================================================================

# Helper: format a point estimate + SE pair for a table cell
fmt_cell <- function(pe, se, pe_digits = 4, se_digits = 4) {
  list(
    pe = formatC(pe, format = "f", digits = pe_digits),
    se = formatC(se, format = "f", digits = se_digits)
  )
}


# --- LaTeX output ------------------------------------------------------------
format_tex_row <- function(label, sm, lra, fra, pe_dig = 4, se_dig = 4) {
  s <- fmt_cell(sm["pe"],  sm["se"],  pe_dig, se_dig)
  l <- fmt_cell(lra["pe"], lra["se"], pe_dig, se_dig)
  f <- fmt_cell(fra["pe"], fra["se"], pe_dig, se_dig)

  paste0(
    "    ", label, " & ", s$pe, " & ", l$pe, " & ", f$pe, " \\\\\n",
    "    & (", s$se, ") & (", l$se, ") & (", f$se, ") \\\\\n",
    "    \\hline"
  )
}

tex_rows <- paste(
  format_tex_row("ER Visits",        sm_er,   lra_er,   fra_er),
  format_tex_row("Medicaid Take-Up", sm_d,    lra_d,    fra_d),
  format_tex_row("LATE",             sm_late, lra_late, fra_late),
  sep = "\n"
)

latex_table <- paste0(
  "\\begin{table}[h!]\n",
  "\\centering\n",
  "\\renewcommand{\\arraystretch}{1.5}\n",
  "\\begin{tabular}{l c c c}\n",
  "    \\hline\\hline\n",
  "    & \\textbf{SM} & \\textbf{LRA} & \\textbf{FRA} \\\\\n",
  "    \\hline\n",
  tex_rows, "\n",
  "    \\hline\n",
  "    \\multicolumn{4}{l}{\\scriptsize\\textit{Note:} Point estimates with standard errors in parentheses.} \\\\\n",
  "    \\multicolumn{4}{l}{\\scriptsize SM = Subsample Means, LRA = Linear Regression Adjustment,} \\\\\n",
  "    \\multicolumn{4}{l}{\\scriptsize FRA = Flexible Regression Adjustment (Random Forest). $N = ",
  format(nrow(dat), big.mark = ","), "$.} \\\\\n",
  "    \\hline\\hline\n",
  "\\end{tabular}\n",
  "\\caption{Variance Reduction for OHIE (Table 7)}\n",
  "\\end{table}"
)

tex_file <- file.path(output_dir, "table_7_OHIE.tex")
writeLines(latex_table, con = tex_file)
cat("\nSaved to:", tex_file)


# --- HTML output -------------------------------------------------------------
format_html_row <- function(label, sm, lra, fra, pe_dig = 4, se_dig = 4) {
  s <- fmt_cell(sm["pe"],  sm["se"],  pe_dig, se_dig)
  l <- fmt_cell(lra["pe"], lra["se"], pe_dig, se_dig)
  f <- fmt_cell(fra["pe"], fra["se"], pe_dig, se_dig)

  paste0(
    "      <tr class=\"pe-row\"><td>", label, "</td>",
    "<td>", s$pe, "</td><td>", l$pe, "</td><td>", f$pe, "</td></tr>\n",
    "      <tr class=\"se-row\"><td></td>",
    "<td>(", s$se, ")</td><td>(", l$se, ")</td><td>(", f$se, ")</td></tr>"
  )
}

html_rows <- paste(
  format_html_row("ER Visits",        sm_er,   lra_er,   fra_er),
  format_html_row("Medicaid Take-Up", sm_d,    lra_d,    fra_d),
  format_html_row("LATE",             sm_late, lra_late, fra_late),
  sep = "\n"
)

html_content <- paste0(
  '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n',
  '<title>Table 7: OHIE</title>\n',
  '<style>\n',
  '    body { font-family: "Helvetica Neue", Arial, sans-serif; margin: 40px; color: #2c3e50; }\n',
  '    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }\n',
  '    table { border-collapse: collapse; margin: 20px auto; }\n',
  '    th { background-color: #1a3e82; color: white; padding: 10px 24px;\n',
  '         font-size: 13px; text-align: center; }\n',
  '    td { padding: 6px 24px; text-align: center; font-size: 13px; }\n',
  '    .pe-row td { border-top: 1px solid #ddd; padding-bottom: 2px; }\n',
  '    .pe-row td:first-child { text-align: left; font-weight: 500; }\n',
  '    .se-row td { color: #666; padding-top: 0; padding-bottom: 8px; }\n',
  '    .se-row td:first-child { text-align: left; }\n',
  '    tr:hover td { background-color: #f0f4fb; }\n',
  '    .note { max-width: 650px; margin: 12px auto; font-size: 11px;\n',
  '            color: #666; text-align: center; line-height: 1.5; }\n',
  '</style>\n',
  '</head>\n<body>\n',
  '<h2>Table 7: Variance Reduction for OHIE</h2>\n',
  '<table>\n',
  '    <thead>\n',
  '      <tr><th></th><th>SM</th><th>LRA</th><th>FRA</th></tr>\n',
  '    </thead>\n',
  '    <tbody>\n',
  html_rows, "\n",
  '    </tbody>\n',
  '</table>\n',
  '<p class="note"><em>Note:</em> Point estimates with standard errors in ',
  'parentheses. SM = Subsample Means (simple difference in means), ',
  'LRA = Linear Regression Adjustment (OLS with cross-fitting), ',
  'FRA = Flexible Regression Adjustment (Random Forest with cross-fitting). ',
  'N = ', format(nrow(dat), big.mark = ","), '.</p>\n',
  '</body>\n</html>'
)

html_file <- file.path(output_dir, "table_7_OHIE.html")
writeLines(html_content, con = html_file)
cat("\nSaved to:", html_file, "\n")
