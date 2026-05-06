# =============================================================================
# Exhibit 8.1.3A: A Comparison of Mediation Analysis Methods: Parental Beliefs
# =============================================================================
# This exhibit compares three mediation analysis methods:
# 1. Baron and Kenny (traditional approach)
# 2. Interaction Model (Imai et al. 2010a, Kraemer et al. 2008)
# 3. Non-parametric Model (Imai et al. 2010a)
#
# The exhibit reports Average Indirect Effect (AIE), Average Direct Effect (ADE),
# and Average Total Effect (ATE) for two outcomes: Parental Investments and
# Child Outcome.


# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Required packages
required_lib <- c("mediation", "mgcv", "dplyr", "knitr", "haven")

install_required_libs <- function() {
  for (i in 1:length(required_lib)) {
    if (required_lib[i] %in% rownames(installed.packages()) == FALSE) {
      install.packages(required_lib[i])
    }
  }
}
install_required_libs()
lapply(required_lib, require, character.only = TRUE)

# Set paths relative to script location
script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
if (length(script_dir) == 0 || script_dir == "") {
  script_dir <- getwd()
}
data_dir <- file.path(script_dir, "..", "data")
output_dir <- file.path(script_dir, "..", "output")

# Create output directory if it doesn't exist
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Set seed for reproducibility
# set.seed(1234)


# --- Load Data ---------------------------------------------------------------
data <- haven::read_dta(file.path(data_dir, "TMPdata_de-identified.dta"))

input_data <- data %>%
  dplyr::select(speak22_A2_sd, Treated, cvc_A2_sd, ctc_A2_sd) %>%
  rename(M = speak22_A2_sd,
         D = Treated,
         Y_child = cvc_A2_sd,
         Y_invest = ctc_A2_sd)


# =============================================================================
# EXHIBIT 8.1.3A: COMPARISON OF MEDIATION METHODS
# =============================================================================

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("EXHIBIT 8.1.3A: Comparison of Mediation Analysis Methods\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n")


# --- Method 1: Baron and Kenny -----------------------------------------------
cat("Method 1: Baron and Kenny\n")
cat(paste(rep("-", 80), collapse = ""), "\n")

# Step 1: Regression of Y on D without including the mediator M
model.invest <- lm(Y_invest ~ D, data = input_data)
model.child <- lm(Y_child ~ D, data = input_data)

# Step 2: Regression of M on D
model.m <- lm(M ~ D, data = input_data)

# Step 3: Regression of Y on M, controlling for D
model.childm <- lm(Y_child ~ M + D, data = input_data)
model.investm <- lm(Y_invest ~ M + D, data = input_data)

# Step 4: Test for mediation using the Sobel test

# Calculate the Sobel test statistic and its p-value: Parental Investments
i_indirect <- coef(model.m)["D"] * coef(model.investm)["M"]
i_coef_a <- coef(model.m)["D"]
i_coef_b <- coef(model.investm)["M"]
i_var_a <- vcov(model.m)["D", "D"]
i_var_b <- vcov(model.investm)["M", "M"]
i_se_indirect <- sqrt(i_coef_a^2 * i_var_b + i_coef_b^2 * i_var_a)
i_z <- i_indirect / i_se_indirect
i_p <- 2 * (1 - pnorm(abs(i_z)))

# Calculate the Sobel test statistic and its p-value: Child Outcome
c_indirect <- coef(model.m)["D"] * coef(model.childm)["M"]
c_coef_a <- coef(model.m)["D"]
c_coef_b <- coef(model.childm)["M"]
c_var_a <- vcov(model.m)["D", "D"]
c_var_b <- vcov(model.childm)["M", "M"]
c_se_indirect <- sqrt(c_coef_a^2 * c_var_b + c_coef_b^2 * c_var_a)
c_z <- c_indirect / c_se_indirect
c_p <- 2 * (1 - pnorm(abs(c_z)))

cat("Parental Investments:\n")
cat(sprintf("  AIE = %.2f (SE = %.2f)\n", i_indirect, i_se_indirect))
cat(sprintf("  ADE = %.2f (SE = %.2f)\n", coef(model.investm)["D"], sqrt(vcov(model.investm)["D", "D"])))
cat(sprintf("  ATE = %.2f (SE = %.2f)\n", coef(model.invest)["D"], sqrt(vcov(model.invest)["D", "D"])))
cat("\nChild Outcome:\n")
cat(sprintf("  AIE = %.2f (SE = %.2f)\n", c_indirect, c_se_indirect))
cat(sprintf("  ADE = %.2f (SE = %.2f)\n", coef(model.childm)["D"], sqrt(vcov(model.childm)["D", "D"])))
cat(sprintf("  ATE = %.2f (SE = %.2f)\n\n", coef(model.child)["D"], sqrt(vcov(model.child)["D", "D"])))


# --- Method 2: Interaction Model ---------------------------------------------
cat("Method 2: Interaction Model\n")
cat(paste(rep("-", 80), collapse = ""), "\n")

# Filter to complete cases (required for mediation package)
input_data_int <- na.omit(input_data)

# Step 1: Regression of M on D
model.intm <- lm(M ~ D, data = input_data_int)

# Step 2: Regression of Y on M, D, and the interaction term D*M
model.int.invest <- lm(Y_invest ~ D + M + D:M, data = input_data_int)
model.int.child <- lm(Y_child ~ D + M + D:M, data = input_data_int)

# Step 3: Call "mediate" to obtain the average effects
out.invest <- mediate(model.intm, model.int.invest, sims = 1000,
                      boot = TRUE, treat = "D", mediator = "M")
out.child <- mediate(model.intm, model.int.child, sims = 1000,
                     boot = TRUE, treat = "D", mediator = "M")

# Parental Investments
summary_invest <- summary(out.invest)
cat("Parental Investments:\n")
cat(sprintf("  AIE = %.2f\n", summary_invest$d.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_invest$d.avg.ci[1], summary_invest$d.avg.ci[2]))
cat(sprintf("  ADE = %.2f\n", summary_invest$z.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_invest$z.avg.ci[1], summary_invest$z.avg.ci[2]))
cat(sprintf("  ATE = %.2f\n", summary_invest$tau.coef))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_invest$tau.ci[1], summary_invest$tau.ci[2]))

# Child Outcome
summary_child <- summary(out.child)
cat("\nChild Outcome:\n")
cat(sprintf("  AIE = %.2f\n", summary_child$d.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_child$d.avg.ci[1], summary_child$d.avg.ci[2]))
cat(sprintf("  ADE = %.2f\n", summary_child$z.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_child$z.avg.ci[1], summary_child$z.avg.ci[2]))
cat(sprintf("  ATE = %.2f\n", summary_child$tau.coef))
cat(sprintf("  CI = [%.2f, %.2f]\n\n", summary_child$tau.ci[1], summary_child$tau.ci[2]))


# --- Method 3: Non-parametric Model ------------------------------------------
cat("Method 3: Non-parametric Model\n")
cat(paste(rep("-", 80), collapse = ""), "\n")

# Mediator model
model.np.m <- lm(M ~ D, data = input_data_int)

# Outcome models with GAM (non-parametric smoothing)
model.np.invest <- gam(Y_invest ~ D + s(M, bs = "cr"), data = input_data_int)
model.np.child <- gam(Y_child ~ D + s(M, bs = "cr"), data = input_data_int)

# Mediation analysis
out.np.invest <- mediate(model.np.m, model.np.invest, sims = 1000,
                         boot = TRUE, treat = "D", mediator = "M")
out.np.child <- mediate(model.np.m, model.np.child, sims = 1000,
                        boot = TRUE, treat = "D", mediator = "M")

# Parental Investments
summary_invest <- summary(out.np.invest)
cat("Parental Investments:\n")
cat(sprintf("  AIE = %.2f\n", summary_invest$d.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_invest$d.avg.ci[1], summary_invest$d.avg.ci[2]))
cat(sprintf("  ADE = %.2f\n", summary_invest$z.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_invest$z.avg.ci[1], summary_invest$z.avg.ci[2]))
cat(sprintf("  ATE = %.2f\n", summary_invest$tau.coef))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_invest$tau.ci[1], summary_invest$tau.ci[2]))

# Child Outcome
summary_child <- summary(out.np.child)
cat("\nChild Outcome:\n")
cat(sprintf("  AIE = %.2f\n", summary_child$d.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_child$d.avg.ci[1], summary_child$d.avg.ci[2]))
cat(sprintf("  ADE = %.2f\n", summary_child$z.avg))
cat(sprintf("  CI = [%.2f, %.2f]\n", summary_child$z.avg.ci[1], summary_child$z.avg.ci[2]))
cat(sprintf("  ATE = %.2f\n", summary_child$tau.coef))
cat(sprintf("  CI = [%.2f, %.2f]\n\n", summary_child$tau.ci[1], summary_child$tau.ci[2]))


# --- Save Results to LaTeX ---------------------------------------------------
# Define function to add stars based on p-value
add_stars <- function(estimate, p_value) {
  if (p_value <= 0.001) {
    return(paste0(estimate, "***"))
  } else if (p_value <= 0.01) {
    return(paste0(estimate, "**"))
  } else if (p_value <= 0.05) {
    return(paste0(estimate, "*"))
  } else if (p_value <= 0.1) {
    return(paste0(estimate, "."))
  } else {
    return(estimate)
  }
}

# Exhibit 8.1.3A: Comparison Table (matches Python output)
exhibit_8_1_3A <- matrix("-", nrow = 6, ncol = 7)
colnames(exhibit_8_1_3A) <- c(
  "Method",
  "Baron and Kenny",
  "Interaction Model",
  "Non-parametric Model",
  "Baron and Kenny.1",
  "Interaction Model.1",
  "Non-parametric Model.1"
)
rownames(exhibit_8_1_3A) <- NULL

# Row labels
exhibit_8_1_3A[, 1] <- c("AIE", "", "ADE", "", "ATE", "")

# Parental Investments - Baron and Kenny
formatted_AIE <- sprintf("%.2f", round(i_indirect, 2))
exhibit_8_1_3A[1, 2] <- add_stars(formatted_AIE, i_p)
exhibit_8_1_3A[2, 2] <- sprintf("(%.2f)", round(i_se_indirect, 2))

formatted_ADE <- sprintf("%.3f", round(coef(model.investm)["D"], 3))
exhibit_8_1_3A[3, 2] <- add_stars(formatted_ADE, summary(model.investm)$coefficients["D", "Pr(>|t|)"])
exhibit_8_1_3A[4, 2] <- sprintf("(%.2f)", round(sqrt(vcov(model.investm)["D", "D"]), 2))

formatted_TE <- sprintf("%.2f", round(coef(model.invest)["D"], 2))
exhibit_8_1_3A[5, 2] <- add_stars(formatted_TE, summary(model.invest)$coefficients["D", "Pr(>|t|)"])
exhibit_8_1_3A[6, 2] <- sprintf("(%.2f)", round(sqrt(vcov(model.invest)["D", "D"]), 2))

# Parental Investments - Interaction Model
summary_invest_int <- summary(out.invest)
formatted_AIE <- sprintf("%.2f", round(summary_invest_int$d.avg, 2))
exhibit_8_1_3A[1, 3] <- add_stars(formatted_AIE, summary_invest_int$d.avg.p)
exhibit_8_1_3A[2, 3] <- sprintf("[%.2f, %.2f]", summary_invest_int$d.avg.ci[1], summary_invest_int$d.avg.ci[2])

formatted_ADE <- sprintf("%.2f", round(summary_invest_int$z.avg, 2))
exhibit_8_1_3A[3, 3] <- add_stars(formatted_ADE, summary_invest_int$z.avg.p)
exhibit_8_1_3A[4, 3] <- sprintf("[%.2f, %.2f]", summary_invest_int$z.avg.ci[1], summary_invest_int$z.avg.ci[2])

formatted_TE <- sprintf("%.2f", round(summary_invest_int$tau.coef, 2))
exhibit_8_1_3A[5, 3] <- add_stars(formatted_TE, summary_invest_int$tau.p)
exhibit_8_1_3A[6, 3] <- sprintf("[%.2f, %.2f]", summary_invest_int$tau.ci[1], summary_invest_int$tau.ci[2])

# Parental Investments - Non-parametric Model
summary_invest_np <- summary(out.np.invest)
formatted_AIE <- sprintf("%.2f", round(summary_invest_np$d.avg, 2))
exhibit_8_1_3A[1, 4] <- add_stars(formatted_AIE, summary_invest_np$d.avg.p)
exhibit_8_1_3A[2, 4] <- sprintf("[%.2f, %.2f]", summary_invest_np$d.avg.ci[1], summary_invest_np$d.avg.ci[2])

formatted_ADE <- sprintf("%.2f", round(summary_invest_np$z.avg, 2))
exhibit_8_1_3A[3, 4] <- add_stars(formatted_ADE, summary_invest_np$z.avg.p)
exhibit_8_1_3A[4, 4] <- sprintf("[%.2f, %.2f]", summary_invest_np$z.avg.ci[1], summary_invest_np$z.avg.ci[2])

formatted_TE <- sprintf("%.2f", round(summary_invest_np$tau.coef, 2))
exhibit_8_1_3A[5, 4] <- add_stars(formatted_TE, summary_invest_np$tau.p)
exhibit_8_1_3A[6, 4] <- sprintf("[%.2f, %.2f]", summary_invest_np$tau.ci[1], summary_invest_np$tau.ci[2])

# Child Outcome - Baron and Kenny
formatted_AIE <- sprintf("%.2f", round(c_indirect, 2))
exhibit_8_1_3A[1, 5] <- add_stars(formatted_AIE, c_p)
exhibit_8_1_3A[2, 5] <- sprintf("(%.2f)", round(c_se_indirect, 2))

formatted_ADE <- sprintf("%.2f", round(coef(model.childm)["D"], 2))
exhibit_8_1_3A[3, 5] <- add_stars(formatted_ADE, summary(model.childm)$coefficients["D", "Pr(>|t|)"])
exhibit_8_1_3A[4, 5] <- sprintf("(%.2f)", round(sqrt(vcov(model.childm)["D", "D"]), 2))

formatted_TE <- sprintf("%.2f", round(coef(model.child)["D"], 2))
exhibit_8_1_3A[5, 5] <- add_stars(formatted_TE, summary(model.child)$coefficients["D", "Pr(>|t|)"])
exhibit_8_1_3A[6, 5] <- sprintf("(%.2f)", round(sqrt(vcov(model.child)["D", "D"]), 2))

# Child Outcome - Interaction Model
summary_child_int <- summary(out.child)
formatted_AIE <- sprintf("%.2f", round(summary_child_int$d.avg, 2))
exhibit_8_1_3A[1, 6] <- add_stars(formatted_AIE, summary_child_int$d.avg.p)
exhibit_8_1_3A[2, 6] <- sprintf("[%.2f, %.2f]", summary_child_int$d.avg.ci[1], summary_child_int$d.avg.ci[2])

formatted_ADE <- sprintf("%.2f", round(summary_child_int$z.avg, 2))
exhibit_8_1_3A[3, 6] <- add_stars(formatted_ADE, summary_child_int$z.avg.p)
exhibit_8_1_3A[4, 6] <- sprintf("[%.2f, %.2f]", summary_child_int$z.avg.ci[1], summary_child_int$z.avg.ci[2])

formatted_TE <- sprintf("%.2f", round(summary_child_int$tau.coef, 2))
exhibit_8_1_3A[5, 6] <- add_stars(formatted_TE, summary_child_int$tau.p)
exhibit_8_1_3A[6, 6] <- sprintf("[%.2f, %.2f]", summary_child_int$tau.ci[1], summary_child_int$tau.ci[2])

# Child Outcome - Non-parametric Model
summary_child_np <- summary(out.np.child)
formatted_AIE <- sprintf("%.2f", round(summary_child_np$d.avg, 2))
exhibit_8_1_3A[1, 7] <- add_stars(formatted_AIE, summary_child_np$d.avg.p)
exhibit_8_1_3A[2, 7] <- sprintf("[%.2f, %.2f]", summary_child_np$d.avg.ci[1], summary_child_np$d.avg.ci[2])

formatted_ADE <- sprintf("%.2f", round(summary_child_np$z.avg, 2))
exhibit_8_1_3A[3, 7] <- add_stars(formatted_ADE, summary_child_np$z.avg.p)
exhibit_8_1_3A[4, 7] <- sprintf("[%.2f, %.2f]", summary_child_np$z.avg.ci[1], summary_child_np$z.avg.ci[2])

formatted_TE <- sprintf("%.2f", round(summary_child_np$tau.coef, 2))
exhibit_8_1_3A[5, 7] <- add_stars(formatted_TE, summary_child_np$tau.p)
exhibit_8_1_3A[6, 7] <- sprintf("[%.2f, %.2f]", summary_child_np$tau.ci[1], summary_child_np$tau.ci[2])

# Display the table
print(kable(exhibit_8_1_3A, caption = "Exhibit 8.1.3A: A Comparison of Mediation Analysis Methods: Parental Beliefs"))

# Save to file
tex_file <- file.path(output_dir, "Exhibit_8_1_3A_r.tex")
write(kable(exhibit_8_1_3A, format = "latex",
            caption = "A Comparison of Mediation Analysis Methods: Parental Beliefs",
            label = "tab:exhibit_8_1_3A"),
      file = tex_file)

cat(sprintf("\n✓ Saved to: %s\n", tex_file))


# =============================================================================
# END OF EXHIBIT 8.1.3A
# =============================================================================
