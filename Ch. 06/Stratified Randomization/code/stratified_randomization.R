# =============================================================================
# Stratified Randomization
# =============================================================================
# Implements Stratified Randomization (also called Block Randomization) to assign
# treatment status within strata defined by baseline covariates. This ensures
# balance on the stratification variables and can improve precision of treatment
# effect estimates.
#
# The procedure:
# 1. Partition the sample into strata based on specified covariates
# 2. Apply Complete Randomization within each stratum
# 3. Combine the randomized strata back together


# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(tidyverse)
library(haven)

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


# --- Parameters --------------------------------------------------------------
# Set random seed for reproducibility
# set.seed(42)


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
data <- read_dta(file.path(data_dir, "unique_data_clean_main_synthetic.dta"))


# --- Define stratification variables ----------------------------------------
# Categorical variables: will split by unique values
categorical_vars <- c("female", "race_w")

# Continuous variables: will split at median
continuous_vars <- c("std_cog_pre", "birthweight")


# --- Create stratification groups -------------------------------------------
# Create temporary variable to preserve original order
data_with_strata <- data %>%
  mutate(original_order = row_number())

# For continuous variables, create binary indicators (above/below median)
for (var in continuous_vars) {
  median_val <- median(data_with_strata[[var]], na.rm = TRUE)
  strata_var_name <- paste0("strata_", var)
  data_with_strata <- data_with_strata %>%
    mutate(!!strata_var_name := as.integer(.data[[var]] > median_val))
}

# Create combined strata identifier
strata_vars <- c(categorical_vars, paste0("strata_", continuous_vars))
data_with_strata <- data_with_strata %>%
  unite("stratum_id", all_of(strata_vars), sep = "_", remove = FALSE)


# --- Apply Complete Randomization within each stratum -----------------------
# Within each stratum, assign treatment to first half after shuffling
randomized_data <- data_with_strata %>%
  group_by(stratum_id) %>%
  mutate(
    random_order = runif(n()),
    n_in_stratum = n(),
    n_half = floor(n() / 2),
    extra_to_treatment = if_else(row_number() == 1,
                                   as.integer(runif(1) < 0.5),
                                   NA_integer_),
    extra_to_treatment = max(extra_to_treatment, na.rm = TRUE),
    n_treatment_stratum = if_else(n_in_stratum %% 2 == 1,
                                   n_half + extra_to_treatment,
                                   n_half)
  ) %>%
  arrange(stratum_id, random_order) %>%
  mutate(Treatment = as.integer(row_number() <= first(n_treatment_stratum))) %>%
  ungroup() %>%
  arrange(original_order) %>%
  select(-original_order, -random_order, -n_in_stratum, -n_half,
         -extra_to_treatment, -n_treatment_stratum, -stratum_id,
         -starts_with("strata_"))


# --- Print summary statistics ------------------------------------------------
# Overall counts
n_total <- nrow(randomized_data)
n_treatment <- sum(randomized_data$Treatment)
n_control <- n_total - n_treatment
actual_proportion <- n_treatment / n_total

cat("\n", strrep("=", 80), "\n", sep = "")
cat("STRATIFIED RANDOMIZATION SUMMARY\n")
cat(strrep("=", 80), "\n", sep = "")

# Display stratification variables
if (length(categorical_vars) > 0) {
  cat(sprintf("Categorical variables:             %s\n",
              paste(categorical_vars, collapse = ", ")))
}
if (length(continuous_vars) > 0) {
  cat(sprintf("Continuous variables (median split): %s\n",
              paste(continuous_vars, collapse = ", ")))
}

cat(sprintf("Total observations:                %s\n", format(n_total, big.mark = ",")))
cat(sprintf("Assigned to treatment:             %s\n", format(n_treatment, big.mark = ",")))
cat(sprintf("Assigned to control:               %s\n", format(n_control, big.mark = ",")))
cat(sprintf("Treatment proportion:              %.3f\n", actual_proportion))
cat(strrep("-", 80), "\n", sep = "")

# Balance by stratification variables
cat("\nBalance by Stratification Variables:\n")
cat(strrep("-", 80), "\n", sep = "")

# Display balance for categorical variables
for (var in categorical_vars) {
  cat(sprintf("\n%s (categorical):\n", var))
  balance_table <- randomized_data %>%
    group_by(!!sym(var), Treatment) %>%
    summarise(n = n(), .groups = 'drop') %>%
    pivot_wider(names_from = Treatment, values_from = n, values_fill = 0) %>%
    rename(Control = `0`, Treatment = `1`) %>%
    mutate(Total = Control + Treatment)
  print(balance_table)
}

# Display balance for continuous variables (median split)
for (var in continuous_vars) {
  median_val <- median(data[[var]], na.rm = TRUE)
  cat(sprintf("\n%s (continuous, median = %.2f):\n", var, median_val))

  balance_table <- randomized_data %>%
    mutate(median_split = if_else(.data[[var]] > median_val,
                                   sprintf("> %.2f", median_val),
                                   sprintf("<= %.2f", median_val))) %>%
    group_by(median_split, Treatment) %>%
    summarise(n = n(), .groups = 'drop') %>%
    pivot_wider(names_from = Treatment, values_from = n, values_fill = 0) %>%
    rename(Control = `0`, Treatment = `1`) %>%
    mutate(Total = Control + Treatment)
  print(balance_table)
}

cat("\n", strrep("=", 80), "\n", sep = "")
cat("\nNote: Stratified randomization ensures exact balance on stratification\n")
cat("      variables by applying Complete Randomization within each stratum.\n")
cat("      Continuous variables are split at the median calculated from the full dataset.\n")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory
output_file <- file.path(output_dir, "stratified_randomized_dataset.dta")
write_dta(randomized_data, output_file)

cat(sprintf("\n✓ Saved to: %s\n\n", output_file))

# =============================================================================
# END OF STRATIFIED RANDOMIZATION
# =============================================================================
