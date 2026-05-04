# =============================================================================
# Exhibit 12.2: GHO (2020) Attrition Tests for CHECC Data
# =============================================================================
# Tests whether attrition is related to baseline characteristics.
# Methodology: Regress baseline outcomes on four group indicators:
#   - π11: treatment × respond
#   - π01: control × respond
#   - π10: treatment × attrit
#   - π00: control × attrit
#
# Column 1: Baseline cognitive score (std_cog_pre)
# Column 2: Baseline non-cognitive score (std_ncog_pre)
#
# Hypothesis tests:
#   H0^12.2: π10 = π00 & π11 = π01 (attrition same across treatment/control)
#   H0^12.3: π10 = π00 = π11 = π01 (all groups have same baseline)
#
# Reference: Ghanem, D., Hirshleifer, S., & Ortiz-Becerra, K. (2020).
# Testing Attrition Bias in Field Experiments. Working Paper.

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(tidyverse)
library(haven)
library(estimatr)
library(car)
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


# --- Load and filter data ----------------------------------------------------
# Load synthetic data (for testing/demonstration)
data <- read_dta(file.path(data_dir, "unique_data_clean_main_synthetic.dta"))
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data <- read_dta(file.path(data_dir, "unique_data_clean_main.dta"))

# Apply filters and create necessary variables
cleaned_data <- data %>%
  filter(year >= 2012 &
         (treatment == "control" | treatment == "prek") &
         kinderprep == 0 &
         late_randomized == 0 &
         has_cog_pre != 0) %>%
  mutate(
    # Create block variable (prioritize 2012 block, fallback to 2013)
    block = case_when(
      block_2012 != "" ~ block_2012,
      block_2013 != "" ~ block_2013
    ),
    # Set summer loss cognitive score to NA when not observed
    std_cog_sl = ifelse(has_cog_sl == 0, NA, std_cog_sl),
    # Treatment indicator: 1 if pre-K, 0 if control
    d_i = (treatment == "prek"),
    # Response indicator: 1 if outcome observed, 0 if attrited
    r_i = !is.na(std_cog_sl)
  )


# --- Create group indicators -------------------------------------------------
# Four mutually exclusive groups based on treatment and response status
cleaned_data <- cleaned_data %>%
  mutate(
    pi11 = d_i * r_i,
    pi01 = (1 - d_i) * r_i,
    pi10 = d_i * (1 - r_i),
    pi00 = (1 - d_i) * (1 - r_i)
  )


# --- Estimate models ---------------------------------------------------------
# Column 1: Regress baseline cognitive score on group indicators (no intercept)
model_cog <- lm_robust(
  std_cog_pre ~ pi11 + pi01 + pi10 + pi00 + 0,
  data = cleaned_data
)

# Column 2: Regress baseline non-cognitive score on group indicators (no intercept)
model_ncog <- lm_robust(
  std_ncog_pre ~ pi11 + pi01 + pi10 + pi00 + 0,
  data = cleaned_data
)


# --- Hypothesis tests --------------------------------------------------------
# Test whether baseline characteristics differ across response/attrition groups

# Hypothesis tests for Cognitive Score
# H0^12.2: π10 = π00 & π11 = π01 (attrition rate same across treatment/control)
h0_12_2_cog <- linearHypothesis(
  model_cog,
  c("pi10 = pi00", "pi11 = pi01")
)
pvalue_cog_12_2 <- h0_12_2_cog$`Pr(>Chisq)`[2]

# H0^12.3: π10 = π00 = π11 = π01 (all groups have same baseline)
h0_12_3_cog <- linearHypothesis(
  model_cog,
  c("pi10 = pi00", "pi10 = pi11", "pi10 = pi01")
)
pvalue_cog_12_3 <- h0_12_3_cog$`Pr(>Chisq)`[2]

# Hypothesis tests for Non-Cognitive Score
# H0^12.2: π10 = π00 & π11 = π01 (attrition rate same across treatment/control)
h0_12_2_ncog <- linearHypothesis(
  model_ncog,
  c("pi10 = pi00", "pi11 = pi01")
)
pvalue_ncog_12_2 <- h0_12_2_ncog$`Pr(>Chisq)`[2]

# H0^12.3: π10 = π00 = π11 = π01 (all groups have same baseline)
h0_12_3_ncog <- linearHypothesis(
  model_ncog,
  c("pi10 = pi00", "pi10 = pi11", "pi10 = pi01")
)
pvalue_ncog_12_3 <- h0_12_3_ncog$`Pr(>Chisq)`[2]


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.2: GHO (2020) Attrition Tests for CHECC Data\n")
cat(strrep("=", 80), "\n\n", sep = "")

cat("COGNITIVE SCORE MODEL (Column 1)\n")
cat(strrep("-", 80), "\n", sep = "")
print(summary(model_cog))

cat("\n", strrep("=", 80), "\n", sep = "")
cat("NON-COGNITIVE SCORE MODEL (Column 2)\n")
cat(strrep("=", 80), "\n", sep = "")
print(summary(model_ncog))

cat("\n", strrep("=", 80), "\n", sep = "")
cat("HYPOTHESIS TEST RESULTS\n")
cat(strrep("=", 80), "\n\n", sep = "")

cat("Cognitive Score:\n")
cat(sprintf("  H0^12.2: π10 = π00 & π11 = π01     p-value: %.3f\n", pvalue_cog_12_2))
cat(sprintf("  H0^12.3: π10 = π00 = π11 = π01     p-value: %.3f\n", pvalue_cog_12_3))

cat("\nNon-Cognitive Score:\n")
cat(sprintf("  H0^12.2: π10 = π00 & π11 = π01     p-value: %.3f\n", pvalue_ncog_12_2))
cat(sprintf("  H0^12.3: π10 = π00 = π11 = π01     p-value: %.3f\n", pvalue_ncog_12_3))
cat(strrep("=", 80), "\n", sep = "")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with coefficients and hypothesis test results
results_table <- data.frame(
  Group = c("π11 (Treat × Respond)", "π01 (Control × Respond)",
            "π10 (Treat × Attrit)", "π00 (Control × Attrit)",
            "", "H0^12.2: π10=π00 & π11=π01", "H0^12.3: All groups equal"),
  `Cognitive Score` = c(
    sprintf("%.3f (%.3f)", coef(model_cog)["pi11"], model_cog$std.error["pi11"]),
    sprintf("%.3f (%.3f)", coef(model_cog)["pi01"], model_cog$std.error["pi01"]),
    sprintf("%.3f (%.3f)", coef(model_cog)["pi10"], model_cog$std.error["pi10"]),
    sprintf("%.3f (%.3f)", coef(model_cog)["pi00"], model_cog$std.error["pi00"]),
    "",
    sprintf("p = %.3f", pvalue_cog_12_2),
    sprintf("p = %.3f", pvalue_cog_12_3)
  ),
  `Non-Cognitive Score` = c(
    sprintf("%.3f (%.3f)", coef(model_ncog)["pi11"], model_ncog$std.error["pi11"]),
    sprintf("%.3f (%.3f)", coef(model_ncog)["pi01"], model_ncog$std.error["pi01"]),
    sprintf("%.3f (%.3f)", coef(model_ncog)["pi10"], model_ncog$std.error["pi10"]),
    sprintf("%.3f (%.3f)", coef(model_ncog)["pi00"], model_ncog$std.error["pi00"]),
    "",
    sprintf("p = %.3f", pvalue_ncog_12_2),
    sprintf("p = %.3f", pvalue_ncog_12_3)
  ),
  check.names = FALSE
)

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_12_2_r.tex")
print(xtable(results_table,
             caption = "GHO (2020) Attrition Tests for CHECC Data",
             label = "tab:exhibit_12_2"),
      file = tex_file,
      include.rownames = FALSE)
cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 12.2
# =============================================================================
