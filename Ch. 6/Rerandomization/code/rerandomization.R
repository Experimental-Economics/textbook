# =============================================================================
# Rerandomization
# =============================================================================
# Implements Rerandomization to improve covariate balance beyond what is
# achieved by standard Complete Randomization. The procedure repeatedly applies
# Complete Randomization and checks for significant imbalances on specified
# baseline covariates. If any covariate shows significant imbalance (p < threshold),
# the randomization is rejected and the process repeats.


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

# Set significance level for balance tests
significance_level <- 0.1

# Maximum number of rerandomization attempts
max_attempts <- 1000


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
data <- read_dta(file.path(data_dir, "unique_data_clean_main_synthetic.dta"))


# --- Define balance variables ------------------------------------------------
# Categorical variables (will use proportion tests)
categorical_vars <- c("female", "race_w", "hl_eng_span")

# Continuous variables (will use t-tests)
continuous_vars <- c("std_cog_pre", "std_ncog_pre", "birthweight")

# Combine all balance variables
balance_vars <- c(categorical_vars, continuous_vars)


# --- Complete randomization function -----------------------------------------
complete_randomize <- function(data) {
  # Create temporary variable to preserve original order
  data_with_order <- data %>%
    mutate(temp_order = row_number())

  # Calculate split point
  n_total <- nrow(data_with_order)
  n_half <- floor(n_total / 2)

  if (n_total %% 2 == 1) {
    extra_to_treatment <- as.integer(runif(1) < 0.5)
    n_treatment <- n_half + extra_to_treatment
  } else {
    n_treatment <- n_half
  }

  # Shuffle and assign treatment
  randomized <- data_with_order %>%
    mutate(random_order = runif(n())) %>%
    arrange(random_order) %>%
    mutate(Treatment = as.integer(row_number() <= n_treatment)) %>%
    arrange(temp_order) %>%
    select(-temp_order, -random_order)

  return(randomized)
}


# --- Balance checking function -----------------------------------------------
check_balance <- function(data, balance_vars, categorical_vars, continuous_vars, sig_level) {
  pvalues <- list()
  all_balanced <- TRUE

  for (var in balance_vars) {
    is_continuous <- var %in% continuous_vars

    if (is_continuous) {
      # Use t-test for continuous variables
      test_result <- t.test(
        data[[var]][data$Treatment == 1],
        data[[var]][data$Treatment == 0],
        var.equal = FALSE
      )
      pval <- test_result$p.value
    } else {
      # Use z-test for proportions for categorical variables
      p0 <- mean(data[[var]][data$Treatment == 0], na.rm = TRUE)
      p1 <- mean(data[[var]][data$Treatment == 1], na.rm = TRUE)
      n0 <- sum(data$Treatment == 0)
      n1 <- sum(data$Treatment == 1)

      se <- sqrt(p0 * (1 - p0) / n0 + p1 * (1 - p1) / n1)
      if (se > 0) {
        z <- abs(p0 - p1) / se
        pval <- 2 * pnorm(-abs(z))
      } else {
        pval <- ifelse(p0 == p1, 1.0, 0.0)
      }
    }

    pvalues[[var]] <- pval

    if (pval < sig_level) {
      all_balanced <- FALSE
    }
  }

  return(list(pvalues = pvalues, all_balanced = all_balanced))
}


# --- Rerandomization loop ----------------------------------------------------
balanced <- FALSE
num_attempts <- 0

while (!balanced && num_attempts < max_attempts) {
  num_attempts <- num_attempts + 1

  # Apply Complete Randomization
  randomized_data <- complete_randomize(data)

  # Check balance
  balance_result <- check_balance(
    randomized_data,
    balance_vars,
    categorical_vars,
    continuous_vars,
    significance_level
  )

  if (balance_result$all_balanced) {
    balanced <- TRUE
    final_pvalues <- balance_result$pvalues
  }
}

# Check if we found a balanced randomization
if (!balanced) {
  stop(sprintf(
    "Failed to achieve balance after %d attempts.\nConsider relaxing the significance level or reducing the number of balance variables.",
    max_attempts
  ))
}


# --- Print summary statistics ------------------------------------------------
# Count observations by treatment status
n_total <- nrow(randomized_data)
n_treatment <- sum(randomized_data$Treatment)
n_control <- n_total - n_treatment
actual_proportion <- n_treatment / n_total

cat("\n", strrep("=", 80), "\n", sep = "")
cat("RERANDOMIZATION SUMMARY\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Significance threshold:            %.3f\n", significance_level))
cat(sprintf("Number of rerandomizations:        %s\n", format(num_attempts, big.mark = ",")))
cat(sprintf("Balance variables checked:         %d\n", length(balance_vars)))
cat(sprintf("Total observations:                %s\n", format(n_total, big.mark = ",")))
cat(sprintf("Assigned to treatment:             %s\n", format(n_treatment, big.mark = ",")))
cat(sprintf("Assigned to control:               %s\n", format(n_control, big.mark = ",")))
cat(sprintf("Treatment proportion:              %.3f\n", actual_proportion))
cat(strrep("-", 80), "\n", sep = "")

# Print balance check results
cat("\nFinal Balance Check (p-values):\n")
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("%-20s %-15s %-12s %-10s\n", "Variable", "Type", "p-value", "Status"))
cat(strrep("-", 80), "\n", sep = "")

for (var in balance_vars) {
  is_continuous <- var %in% continuous_vars
  var_type <- ifelse(is_continuous, "Continuous", "Binary")
  pval <- final_pvalues[[var]]
  status <- ifelse(pval >= significance_level, "Balanced", "IMBALANCED")

  cat(sprintf("%-20s %-15s %12.4f %-10s\n", var, var_type, pval, status))
}

min_pval <- min(unlist(final_pvalues))
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("Minimum p-value: %.4f\n", min_pval))
cat(strrep("=", 80), "\n", sep = "")
cat("\nNote: Rerandomization improves covariate balance by rejecting randomizations\n")
cat(sprintf("      with any p-value below %.1f. Standard errors and confidence\n", significance_level))
cat("      intervals should be adjusted to account for the rerandomization procedure.\n")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory with number of rerandomizations in filename
output_file <- file.path(output_dir, sprintf("rerandomized_dataset_%d_attempts.dta", num_attempts))
write_dta(randomized_data, output_file)

cat(sprintf("\n✓ Saved to: %s\n\n", output_file))

# =============================================================================
# END OF RERANDOMIZATION
# =============================================================================
