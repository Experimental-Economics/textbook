# =============================================================================
# Optimal Matched-Pairs Randomization Using Pilot Study
# =============================================================================
# Implements optimal matched-pairs randomization based on Bai (2022) framework
# for minimizing mean-squared error. Uses pilot study regression to estimate
# expected outcomes g_i = E[Y_i(1) + Y_i(0) | X_i] for main sample, then creates
# matched pairs by sorting on g_i and pairing adjacent units.
#
# Steps:
#   1. Load pilot data (with Treatment and Outcome from previous randomization)
#   2. Run regression on pilot to estimate relationship between covariates and outcomes
#   3. For main sample: predict outcomes under D=0 and D=1
#   4. Calculate g_hat = g_0 + g_1 for each unit
#   5. Sort main sample by g_hat
#   6. Create matched pairs from sorted data (pair adjacent units)
#   7. Within each pair, randomly assign treatment
#
# Section 6.3.5.1: Efficient Matching Minimizing Mean-Squared Error

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
output_dir <- file.path("..", "output")
data_dir <- file.path("..", "data")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)


# --- Parameters --------------------------------------------------------------
# TODO: Set random seed for reproducibility
random_seed <- 42

# TODO: Specify control variables to use in g_i estimation
# These should be the covariates available in your dataset
# IMPORTANT: Must match the control variables used in the pilot regression
control_vars <- c("female", "race_w", "birthweight", "std_ncog_pre", "year")


# --- Initialize random state -------------------------------------------------
set.seed(random_seed)


# --- Load pilot data and estimate g_i model ---------------------------------
# TODO: Specify the pilot data file
# This file should contain:
#   - Treatment variable (0/1 or binary)
#   - Outcome variable (continuous)
#   - All control variables specified in control_vars
pilot_data <- read_dta(file.path(output_dir, "pilot_sample_with_treatment_and_outcome.dta"))

# Prepare regression data (drop missing values in controls)
pilot_reg <- pilot_data %>%
  dplyr::select(Outcome, Treatment, all_of(control_vars)) %>%
  drop_na()

# TODO: Modify regression specification if desired
# You can add interaction effects, polynomials, or other transformations
# Example: pilot_formula <- as.formula("Outcome ~ Treatment + female + race_w + female:race_w + I(birthweight^2)")
# Run regression: Outcome ~ Treatment + Controls
pilot_formula <- as.formula(paste("Outcome ~ Treatment +", paste(control_vars, collapse = " + ")))
pilot_model <- lm(pilot_formula, data = pilot_reg)

# Extract model statistics
r2_pilot <- summary(pilot_model)$r.squared
r2_adj_pilot <- summary(pilot_model)$adj.r.squared
coef_treatment <- coef(pilot_model)["Treatment"]
pval_treatment <- summary(pilot_model)$coefficients["Treatment", "Pr(>|t|)"]


# --- Load main sample and estimate g_0 and g_1 ------------------------------
# TODO: Specify the main sample data file
# This file should contain:
#   - All control variables specified in control_vars
#   - NO Treatment variable (will be assigned by this script)
main_data <- read_dta(file.path(output_dir, "main_sample.dta"))

# Keep only complete cases for prediction
main_complete <- main_data %>%
  dplyr::select(all_of(control_vars)) %>%
  drop_na() %>%
  mutate(original_index = row_number())

n_complete <- nrow(main_complete)

# TODO: If you modified the regression specification above,
# you must apply the SAME transformations here for prediction
# Example: If you added interaction terms or polynomials in pilot_formula,
#          you must also create those features in main_d0 and main_d1 below
# Predict under D=0 (Treatment=0)
main_d0 <- main_complete %>%
  mutate(Treatment = 0)
main_d0$g_0 <- predict(pilot_model, newdata = main_d0)

# Predict under D=1 (Treatment=1)
main_d1 <- main_complete %>%
  mutate(Treatment = 1)
main_d1$g_1 <- predict(pilot_model, newdata = main_d1)

# Add predictions to main_complete
main_complete$g_0 <- main_d0$g_0
main_complete$g_1 <- main_d1$g_1

# Calculate g_hat = g_0 + g_1
main_complete <- main_complete %>%
  mutate(g_hat = g_0 + g_1)

# Calculate summary statistics
mean_g_hat <- mean(main_complete$g_hat)
sd_g_hat <- sd(main_complete$g_hat)
min_g_hat <- min(main_complete$g_hat)
max_g_hat <- max(main_complete$g_hat)


# --- Sort by g_hat and create matched pairs ---------------------------------
# Sort by g_hat (increasing order)
sorted_data <- main_complete %>%
  arrange(g_hat) %>%
  mutate(sorted_index = row_number())

# Create pairs from adjacent units in sorted order
n_units <- nrow(sorted_data)
n_pairs <- floor(n_units / 2)
n_unpaired <- n_units %% 2

# Initialize treatment and pair ID columns
sorted_data$Treatment_Final <- -1
sorted_data$Pair_ID <- -1

# Create pairs from adjacent units
pair_id <- 0
for (i in seq(1, 2 * n_pairs, by = 2)) {
  if (i + 1 <= nrow(sorted_data)) {
    # Randomly assign treatment within pair
    if (runif(1) < 0.5) {
      sorted_data$Treatment_Final[i] <- 1
      sorted_data$Treatment_Final[i + 1] <- 0
    } else {
      sorted_data$Treatment_Final[i] <- 0
      sorted_data$Treatment_Final[i + 1] <- 1
    }

    # Assign same pair ID
    sorted_data$Pair_ID[i] <- pair_id
    sorted_data$Pair_ID[i + 1] <- pair_id

    pair_id <- pair_id + 1
  }
}

# Handle unpaired unit (if odd number of units)
if (n_unpaired > 0) {
  sorted_data$Treatment_Final[n_units] <- sample(c(0, 1), 1)
  sorted_data$Pair_ID[n_units] <- -1
}


# --- Validate matching quality -----------------------------------------------
# Calculate within-pair differences in g_hat
paired_data <- sorted_data %>%
  filter(Pair_ID >= 0)

if (nrow(paired_data) > 0) {
  # Create pair-level dataset
  pairs_df <- paired_data %>%
    group_by(Pair_ID) %>%
    filter(n() == 2) %>%
    summarise(
      g_hat_diff = abs(diff(g_hat)),
      g_hat_mean = mean(g_hat),
      .groups = "drop"
    )

  # Calculate summary statistics
  mean_diff <- mean(pairs_df$g_hat_diff)
  median_diff <- median(pairs_df$g_hat_diff)
  max_diff <- max(pairs_df$g_hat_diff)
  min_diff <- min(pairs_df$g_hat_diff)

  # Calculate what the mean difference would be under random pairing
  random_diff_mean <- sd_g_hat * sqrt(2)
  reduction <- 100 * (1 - mean_diff / random_diff_mean)
}


# --- Merge with full data and save results -----------------------------------
# Merge back with original main data to get all variables
original_indices <- sorted_data$original_index
full_matched_data <- main_data[original_indices, ]

# Add the matching variables
full_matched_data$Treatment <- sorted_data$Treatment_Final
full_matched_data$Pair_ID <- sorted_data$Pair_ID
full_matched_data$g_hat <- sorted_data$g_hat
full_matched_data$g_0 <- sorted_data$g_0
full_matched_data$g_1 <- sorted_data$g_1

# TODO: Specify output file name
# This file will contain the main sample with Treatment and Pair_ID assigned
output_file <- file.path(output_dir, "optimal_matched_main_sample.dta")
write_dta(full_matched_data, output_file)

# Count treated and control
n_treated <- sum(sorted_data$Treatment_Final == 1)
n_control <- sum(sorted_data$Treatment_Final == 0)


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("OPTIMAL MATCHED-PAIRS RANDOMIZATION FROM PILOT STUDY\n")
cat(strrep("=", 80), "\n", sep = "")

cat("\nPILOT REGRESSION RESULTS\n")
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("  R-squared:            %.4f\n", r2_pilot))
cat(sprintf("  Adj. R-squared:       %.4f\n", r2_adj_pilot))
cat(sprintf("  Treatment coef:       %7.4f\n", coef_treatment))
cat(sprintf("  Treatment p-value:    %7.4f\n", pval_treatment))

cat("\nESTIMATED g_hat STATISTICS\n")
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("  Sample size:          %d\n", n_complete))
cat(sprintf("  Mean:                 %7.4f\n", mean_g_hat))
cat(sprintf("  Std:                  %7.4f\n", sd_g_hat))
cat(sprintf("  Min:                  %7.4f\n", min_g_hat))
cat(sprintf("  Max:                  %7.4f\n", max_g_hat))

cat("\nMATCHED PAIRS STATISTICS\n")
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("  Total units:          %d\n", n_units))
cat(sprintf("  Matched pairs:        %d\n", n_pairs))
cat(sprintf("  Unpaired units:       %d\n", n_unpaired))
cat(sprintf("  Pairing rate:         %.1f%%\n", 100 * n_pairs * 2 / n_units))

if (nrow(paired_data) > 0) {
  cat("\nWITHIN-PAIR g_hat DIFFERENCES\n")
  cat(strrep("-", 80), "\n", sep = "")
  cat(sprintf("  Mean:                 %7.6f\n", mean_diff))
  cat(sprintf("  Median:               %7.6f\n", median_diff))
  cat(sprintf("  Max:                  %7.6f\n", max_diff))
  cat(sprintf("  Min:                  %7.6f\n", min_diff))

  cat("\nCOMPARISON TO RANDOM PAIRING\n")
  cat(strrep("-", 80), "\n", sep = "")
  cat(sprintf("  Expected diff (random):  %7.6f\n", random_diff_mean))
  cat(sprintf("  Achieved diff (optimal): %7.6f\n", mean_diff))
  cat(sprintf("  Reduction:               %7.1f%%\n", reduction))
}

cat("\nTREATMENT ASSIGNMENT\n")
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("  Treated:              %d (%.1f%%)\n", n_treated, 100 * n_treated / n_units))
cat(sprintf("  Control:              %d (%.1f%%)\n", n_control, 100 * n_control / n_units))

cat("\n", strrep("=", 80), "\n", sep = "")
cat("OPTIMAL MATCHING COMPLETE\n")
cat(strrep("=", 80), "\n", sep = "")
cat("\nSaved to:", output_file, "\n\n")

# =============================================================================
# END OF OPTIMAL MATCHING SCRIPT
# =============================================================================
