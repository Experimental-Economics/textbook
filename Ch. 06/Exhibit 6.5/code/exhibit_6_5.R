# =============================================================================
# Exhibit 6.5: Covariate Balance with CRE in Lalonde (1986; NSW)
# =============================================================================
# Creates a balance table comparing baseline characteristics across treatment and
# control groups in the Lalonde (1986; NSW) dataset using a Completely Randomized
# Experiment (CRE).
#
# Column 1: Covariate name and type (proportion vs. mean)
# Column 2: Control group mean (SD)
# Column 3: Treatment group mean (SD)
# Column 4: Difference of means with p-value
#
# For continuous variables: Uses t-test for difference in means
# For binary/categorical variables: Uses z-test for difference in proportions
#
# Reference: Chapter 6, Exhibit 6.5

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(tidyverse)
library(haven)
library(xtable)

# Automatically set working directory to the folder containing this script.
# Supports RStudio (Source/Knit), source(), and Rscript from the command line.
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

# Define paths relative to script location
data_dir <- file.path(dirname(getwd()), "data")
output_dir <- file.path(dirname(getwd()), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)


# --- Balance table function --------------------------------------------------
create_balance_table <- function(data, treatment_col, variables,
                                 variable_labels = NULL, continuous_vars = NULL) {
  # Validate inputs
  if (!treatment_col %in% names(data)) {
    stop("Treatment column '", treatment_col, "' not found in data")
  }

  missing_vars <- setdiff(variables, names(data))
  if (length(missing_vars) > 0) {
    stop("Variables not found in data: ", paste(missing_vars, collapse = ", "))
  }

  # Auto-detect continuous variables if not specified
  if (is.null(continuous_vars)) {
    continuous_vars <- variables[sapply(data[variables], function(x) {
      is.numeric(x) && (length(unique(x[!is.na(x)])) > 10 || any(x != floor(x), na.rm = TRUE))
    })]
  }

  # Create variable labels if not provided
  if (is.null(variable_labels)) {
    variable_labels <- setNames(variables, variables)
  } else {
    missing_labels <- setdiff(variables, names(variable_labels))
    if (length(missing_labels) > 0) {
      additional_labels <- setNames(missing_labels, missing_labels)
      variable_labels <- c(variable_labels, additional_labels)
    }
  }

  # Get unique treatment groups
  treatment_groups <- unique(data[[treatment_col]])
  treatment_groups <- treatment_groups[!is.na(treatment_groups)]

  if (length(treatment_groups) < 2) {
    stop("Need at least 2 treatment groups for comparison")
  }

  # Calculate summary statistics for each treatment group
  summary_stats <- data %>%
    group_by(!!sym(treatment_col)) %>%
    summarise(
      across(all_of(variables), list(
        mean = ~ mean(.x, na.rm = TRUE),
        sd = ~ sd(.x, na.rm = TRUE),
        n = ~ sum(!is.na(.x))
      ), .names = "{.col}_{.fn}"),
      .groups = 'drop'
    )

  # Reshape to wide format
  balance_long <- summary_stats %>%
    pivot_longer(
      cols = -!!sym(treatment_col),
      names_to = c("variable", "stat"),
      names_pattern = "^(.*)_(mean|sd|n)$"
    ) %>%
    pivot_wider(
      names_from = stat,
      values_from = value
    ) %>%
    mutate(variable_label = variable_labels[variable]) %>%
    pivot_wider(
      names_from = !!sym(treatment_col),
      values_from = c(mean, sd, n),
      names_sep = "_"
    )

  # Calculate p-values
  treatment_combinations <- combn(treatment_groups, 2, simplify = FALSE)

  for (combo in treatment_combinations) {
    group1 <- combo[1]
    group2 <- combo[2]
    col_name <- paste0("p_val_", group1, "_", group2)

    balance_long[[col_name]] <- sapply(balance_long$variable, function(var) {
      group1_data <- data[data[[treatment_col]] == group1, var]
      group2_data <- data[data[[treatment_col]] == group2, var]

      group1_data <- group1_data[!is.na(group1_data)]
      group2_data <- group2_data[!is.na(group2_data)]

      if (length(group1_data) == 0 || length(group2_data) == 0) {
        return(NA_real_)
      }

      if (var %in% continuous_vars) {
        # Welch's t-test for continuous variables
        tryCatch({
          t_test_result <- t.test(group1_data, group2_data, var.equal = FALSE)
          return(t_test_result$p.value)
        }, error = function(e) NA_real_)
      } else {
        # Z-test for proportions
        tryCatch({
          p1 <- mean(group1_data)
          p2 <- mean(group2_data)
          n1 <- length(group1_data)
          n2 <- length(group2_data)

          se <- sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)

          if (se == 0) {
            return(ifelse(p1 == p2, 1, 0))
          }

          z <- (p1 - p2) / se
          p_val <- 2 * pnorm(-abs(z))
          return(p_val)
        }, error = function(e) NA_real_)
      }
    })
  }

  # Mark continuous variables
  balance_long$continuous <- ifelse(balance_long$variable %in% continuous_vars, 1, 0)

  # Reorder columns
  balance_long <- balance_long %>%
    select(variable_label, everything(), continuous, -variable)

  return(balance_long)
}


# --- Load data ---------------------------------------------------------------
# Load Lalonde (1986) dataset
lalonde2 <- read_dta(file.path(data_dir, "lalonde2.dta"))


# --- Generate balance table --------------------------------------------------
# Create balance table comparing treatment and control groups on baseline covariates
balance_table <- create_balance_table(
  data = lalonde2,
  treatment_col = "treated",
  variables = c("nodegree", "black", "hisp", "married", "age", "educ", "kids18", "re74"),
  variable_labels = c(
    "nodegree" = "High School Dropout",
    "black" = "Black",
    "hisp" = "Hispanic",
    "married" = "Married",
    "age" = "Age",
    "educ" = "Years of Schooling",
    "kids18" = "Num. Kids under 18",
    "re74" = "Real Earnings 1974"
  ),
  continuous_vars = c("age", "educ", "kids18", "re74")
)

# Reorder rows to match desired covariate order
desired_order <- c(
  "High School Dropout",
  "Black",
  "Hispanic",
  "Married",
  "Age",
  "Years of Schooling",
  "Num. Kids under 18",
  "Real Earnings 1974"
)
balance_table <- balance_table %>%
  slice(match(desired_order, variable_label))


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 6.5: Covariate Balance with CRE in Lalonde (1986; NSW)\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("%-25s %-12s %-18s %-18s %-12s %-10s\n",
            "Covariate", "Type", "Control", "Treatment", "Diff", "p-value"))
cat(sprintf("%-25s %-12s %-18s %-18s %-12s %-10s\n",
            "", "", "Mean (SD)", "Mean (SD)", "", ""))
cat(strrep("-", 80), "\n", sep = "")

for (i in 1:nrow(balance_table)) {
  row <- balance_table[i, ]
  covariate <- row$variable_label
  is_continuous <- row$continuous == 1
  type <- ifelse(is_continuous, "Mean", "Proportion")

  control_mean <- row$mean_0
  control_sd <- row$sd_0
  treatment_mean <- row$mean_1
  treatment_sd <- row$sd_1
  diff <- control_mean - treatment_mean
  pval <- row$p_val_1_0

  # Add significance stars
  stars <- if (is.na(pval)) {
    ""
  } else if (pval < 0.01) {
    "**"
  } else if (pval < 0.05) {
    "*"
  } else {
    ""
  }

  cat(sprintf("%-25s %-12s %6.2f (%5.2f)   %6.2f (%5.2f)   %8.2f%-4s %8.2f\n",
              covariate, type, control_mean, control_sd,
              treatment_mean, treatment_sd, diff, stars, pval))
}

cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("%-25s %-12s %15.0f %17.0f\n", "Observations", "",
            balance_table$n_0[1], balance_table$n_1[1]))
cat(strrep("=", 80), "\n", sep = "")
cat("\nNote: * p<0.05, ** p<0.01\n")


# --- Save results to LaTeX ---------------------------------------------------
# Create formatted table for LaTeX output
latex_data <- data.frame(
  Covariate = character(),
  Type = character(),
  `Control Mean (SD)` = character(),
  `Treatment Mean (SD)` = character(),
  Difference = character(),
  `p-value` = character(),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

for (i in 1:nrow(balance_table)) {
  row <- balance_table[i, ]
  covariate <- row$variable_label
  is_continuous <- row$continuous == 1
  type <- ifelse(is_continuous, "Mean", "Proportion")

  control_mean <- row$mean_0
  control_sd <- row$sd_0
  treatment_mean <- row$mean_1
  treatment_sd <- row$sd_1
  diff <- control_mean - treatment_mean
  pval <- row$p_val_1_0

  # Add significance stars
  stars <- if (is.na(pval)) {
    ""
  } else if (pval < 0.01) {
    "**"
  } else if (pval < 0.05) {
    "*"
  } else {
    ""
  }

  latex_data <- rbind(latex_data, data.frame(
    Covariate = covariate,
    Type = type,
    `Control Mean (SD)` = sprintf("%.2f (%.2f)", control_mean, control_sd),
    `Treatment Mean (SD)` = sprintf("%.2f (%.2f)", treatment_mean, treatment_sd),
    Difference = sprintf("%.2f%s", diff, stars),
    `p-value` = sprintf("%.2f", pval),
    check.names = FALSE,
    stringsAsFactors = FALSE
  ))
}

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_6_5_r.tex")
print(xtable(latex_data,
             caption = "Covariate Balance with CRE in Lalonde (1986; NSW)",
             label = "tab:exhibit_6_5"),
      file = tex_file,
      include.rownames = FALSE)

cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 6.5
# =============================================================================