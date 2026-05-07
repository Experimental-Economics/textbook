# =============================================================================
# Complete Randomization
# =============================================================================
# Implements Complete Randomization to assign treatment status to observations
# in a dataset. Exactly n/2 units are assigned to treatment (or n/2 +- 0.5 if n is odd),
# with the remaining units assigned to control.

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


# --- Apply Complete randomization --------------------------------------------
# Create temporary variable to preserve original order
data_with_order <- data %>%
  mutate(temp_order = row_number())

# Calculate split point: if odd, randomly assign the extra observation
n_total <- nrow(data_with_order)
n_half <- floor(n_total / 2)

if (n_total %% 2 == 1) {
  # Odd sample size: randomly decide which group gets the extra observation
  extra_to_treatment <- as.integer(runif(1) < 0.5)
  n_treatment <- n_half + extra_to_treatment
} else {
  # Even sample size: split evenly
  n_treatment <- n_half
}

# Shuffle the dataset and assign treatment
randomized_data <- data_with_order %>%
  mutate(random_order = runif(n())) %>%
  arrange(random_order) %>%
  mutate(Treatment = as.integer(row_number() <= n_treatment)) %>%
  arrange(temp_order) %>%
  select(-temp_order, -random_order)


# --- Print summary statistics ------------------------------------------------
# Count observations by treatment status
n_total <- nrow(randomized_data)
n_treatment <- sum(randomized_data$Treatment)
n_control <- n_total - n_treatment
actual_proportion <- n_treatment / n_total
sample_diff <- abs(n_treatment - n_control)

cat("\n", strrep("=", 80), "\n", sep = "")
cat("COMPLETE RANDOMIZATION SUMMARY\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Total observations:                %s\n", format(n_total, big.mark = ",")))
cat(sprintf("Assigned to treatment:             %s\n", format(n_treatment, big.mark = ",")))
cat(sprintf("Assigned to control:               %s\n", format(n_control, big.mark = ",")))
cat(sprintf("Treatment proportion:              %.3f\n", actual_proportion))
cat(sprintf("Sample size difference:            %s\n", format(sample_diff, big.mark = ",")))
cat(strrep("=", 80), "\n", sep = "")
cat("\nNote: Complete randomization fixes the number of treated units at n/2,\n")
cat("      ensuring balanced group sizes. If n is odd, the extra observation\n")
cat("      is randomly assigned to either treatment or control.\n")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory
# TODO: Replace 'randomized_dataset.dta' with your desired output filename
output_file <- file.path(output_dir, "randomized_dataset.dta")
write_dta(randomized_data, output_file)

cat(sprintf("\n✓ Saved to: %s\n\n", output_file))

# =============================================================================
# END OF COMPLETE RANDOMIZATION
# =============================================================================
