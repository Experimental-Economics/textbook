# =============================================================================
# Synthetic Data Creation for Chapter 12
# =============================================================================
# Creates synthetic CHECC data for testing and demonstration purposes.
# This script generates 1000 observations with the same structure as the
# original CHECC dataset but with randomized values.
#
# Output: unique_data_clean_main_synthetic.dta (Stata format)

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Set random seed for reproducibility
set.seed(42)

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
ch12_dir <- dirname(getwd())

# Find all Exhibit folders in Ch. 12
exhibit_folders <- list.dirs(ch12_dir, recursive = FALSE, full.names = TRUE)
exhibit_folders <- exhibit_folders[grepl("Exhibit", basename(exhibit_folders))]
exhibit_folders <- sort(exhibit_folders)


# --- Generate synthetic data -------------------------------------------------
# Sample size
N <- 1000

# Create synthetic data with same structure as CHECC dataset
data <- tibble(
  # Treatment assignment
  treatment = sample(c("prek", "control"), size = N, replace = TRUE),

  # Exclusion criteria
  kinderprep = sample(c(0, 1), size = N, replace = TRUE, prob = c(0.8, 0.2)),
  late_randomized = sample(c(0, 1), size = N, replace = TRUE, prob = c(0.8, 0.2)),

  # Block identifiers
  block_2012 = sample(c("", "A", "B", "C", "D"), size = N, replace = TRUE),
  block_2013 = sample(c("", "A", "B", "C", "D"), size = N, replace = TRUE),

  # Outcome availability indicators
  has_cog_sl = sample(c(0, 1), size = N, replace = TRUE, prob = c(0.3, 0.7)),
  has_cog_pre = sample(c(0, 1), size = N, replace = TRUE, prob = c(0.3, 0.7)),

  # Outcome variables (standardized cognitive and non-cognitive scores)
  std_cog_sl = rnorm(N, mean = 0, sd = 1),
  std_ncog_sl = rnorm(N, mean = 0, sd = 1),
  std_cog_pre = rnorm(N, mean = 0, sd = 1),
  std_ncog_pre = rnorm(N, mean = 0, sd = 1),

  # Demographic covariates
  female = sample(c(0, 1), size = N, replace = TRUE, prob = c(0.5, 0.5)),
  race_w = sample(c(0, 1), size = N, replace = TRUE, prob = c(0.3, 0.7)),
  hl_eng_span = sample(c(0, 1), size = N, replace = TRUE, prob = c(0.3, 0.7)),
  birthweight = sample(c(1.0, 1.5, 2.0, 3.0), size = N, replace = TRUE,
                      prob = c(0.3, 0.2, 0.3, 0.2)),

  # Year indicator
  year = sample(2011:2018, size = N, replace = TRUE)
)

# Set missing values where has_cog_sl = 0
data <- data %>%
  mutate(std_cog_sl = ifelse(has_cog_sl == 0, NA, std_cog_sl))

# Set missing values where has_cog_pre = 0
data <- data %>%
  mutate(std_cog_pre = ifelse(has_cog_pre == 0, NA, std_cog_pre))


# --- Save output -------------------------------------------------------------
# Save as Stata file to all exhibit data folders (overwrites if exists)
cat("\nSaving synthetic data to all exhibit folders...\n")
for (exhibit_folder in exhibit_folders) {
  data_dir <- file.path(exhibit_folder, "data")
  dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
  output_file <- file.path(data_dir, "unique_data_clean_main_synthetic.dta")
  write_dta(data, output_file)
  cat("  ✓", basename(exhibit_folder), "/data/unique_data_clean_main_synthetic.dta\n")
}

# Print summary statistics
cat("\n", strrep("=", 80), "\n", sep = "")
cat("SYNTHETIC DATA SUMMARY\n")
cat(strrep("=", 80), "\n", sep = "")
cat("Total observations:", nrow(data), "\n")

cat("\nTreatment distribution:\n")
print(table(data$treatment))

cat("\nYear distribution:\n")
print(table(data$year))

cat(strrep("=", 80), "\n", sep = "")

# =============================================================================
# END OF SYNTHETIC DATA CREATION
# =============================================================================
