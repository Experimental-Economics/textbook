# =============================================================================
# Bernoulli Randomization
# =============================================================================
# Implements Bernoulli randomization to assign treatment status to observations
# in a dataset. Each unit is independently assigned to treatment with probability p
# and to control with probability 1-p.

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
# Set treatment probability (default: 0.5 for equal allocation)
treatment_probability <- 0.5

# Set random seed for reproducibility
# set.seed(42)


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
data <- read_dta(file.path(data_dir, "unique_data_clean_main_synthetic.dta"))


# --- Apply Bernoulli randomization -------------------------------------------
# Generate random uniform draws between 0 and 1
# Assign treatment if random draw < probability
randomized_data <- data %>%
  mutate(Treatment = as.integer(runif(n()) < treatment_probability))


# --- Print summary statistics ------------------------------------------------
# Count observations by treatment status
n_total <- nrow(randomized_data)
n_treatment <- sum(randomized_data$Treatment)
n_control <- n_total - n_treatment
actual_proportion <- n_treatment / n_total
expected_treated <- n_total * treatment_probability

cat("\n", strrep("=", 80), "\n", sep = "")
cat("BERNOULLI RANDOMIZATION SUMMARY\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Treatment probability (p):        %.3f\n", treatment_probability))
cat(sprintf("Total observations:                %s\n", format(n_total, big.mark = ",")))
cat(sprintf("Assigned to treatment:             %s\n", format(n_treatment, big.mark = ",")))
cat(sprintf("Assigned to control:               %s\n", format(n_control, big.mark = ",")))
cat(sprintf("Actual treatment proportion:       %.3f\n", actual_proportion))
cat(sprintf("Expected number treated (n*p):     %.1f\n", expected_treated))
cat(strrep("=", 80), "\n", sep = "")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory
# TODO: Replace 'randomized_dataset.dta' with your desired output filename
output_file <- file.path(output_dir, "randomized_dataset.dta")
write_dta(randomized_data, output_file)

cat(sprintf("\n✓ Saved to: %s\n\n", output_file))

# =============================================================================
# END OF BERNOULLI RANDOMIZATION
# =============================================================================
