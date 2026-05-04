# =============================================================================
# Exhibit 12.4: Determinants of Attrition Tests
# =============================================================================
# Tests which baseline characteristics predict attrition (non-response).
# This analysis identifies which covariates are associated with the probability
# of having an observed outcome in the second period.
#
# Methodology: Regress response indicator (r_i) on treatment status and baseline
# covariates using robust standard errors (HC2).
#
# Covariates: treatment (d_i), female, race_w, hl_eng_span, birthweight, std_cog_pre

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(tidyverse)
library(haven)
library(estimatr)
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


# --- Estimate attrition model ------------------------------------------------
# Regress response indicator on treatment and baseline covariates
deter <- lm_robust(
  r_i ~ d_i + female + race_w + hl_eng_span + birthweight + std_cog_pre,
  data = cleaned_data
)


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.4: Determinants of Attrition Tests\n")
cat(strrep("=", 80), "\n", sep = "")
print(summary(deter))
cat(strrep("=", 80), "\n", sep = "")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table <- data.frame(
  Variable = c("d_i (Treatment)", "female", "race_w (White)",
               "hl_eng_span (Spanish)", "birthweight", "std_cog_pre",
               "Intercept"),
  Coefficient = c(
    sprintf("%.3f", coef(deter)["d_iTRUE"]),
    sprintf("%.3f", coef(deter)["female"]),
    sprintf("%.3f", coef(deter)["race_w"]),
    sprintf("%.3f", coef(deter)["hl_eng_span"]),
    sprintf("%.5f", coef(deter)["birthweight"]),
    sprintf("%.3f", coef(deter)["std_cog_pre"]),
    sprintf("%.3f", coef(deter)["(Intercept)"])
  ),
  `Std. Error` = c(
    sprintf("%.3f", deter$std.error["d_iTRUE"]),
    sprintf("%.3f", deter$std.error["female"]),
    sprintf("%.3f", deter$std.error["race_w"]),
    sprintf("%.3f", deter$std.error["hl_eng_span"]),
    sprintf("%.5f", deter$std.error["birthweight"]),
    sprintf("%.3f", deter$std.error["std_cog_pre"]),
    sprintf("%.3f", deter$std.error["(Intercept)"])
  ),
  `t-statistic` = c(
    sprintf("%.3f", deter$statistic["d_iTRUE"]),
    sprintf("%.3f", deter$statistic["female"]),
    sprintf("%.3f", deter$statistic["race_w"]),
    sprintf("%.3f", deter$statistic["hl_eng_span"]),
    sprintf("%.3f", deter$statistic["birthweight"]),
    sprintf("%.3f", deter$statistic["std_cog_pre"]),
    sprintf("%.3f", deter$statistic["(Intercept)"])
  ),
  `p-value` = c(
    sprintf("%.3f", deter$p.value["d_iTRUE"]),
    sprintf("%.3f", deter$p.value["female"]),
    sprintf("%.3f", deter$p.value["race_w"]),
    sprintf("%.3f", deter$p.value["hl_eng_span"]),
    sprintf("%.3f", deter$p.value["birthweight"]),
    sprintf("%.3f", deter$p.value["std_cog_pre"]),
    sprintf("%.3f", deter$p.value["(Intercept)"])
  ),
  check.names = FALSE
)

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_12_4_r.tex")
print(xtable(results_table,
             caption = "Determinants of Attrition Tests",
             label = "tab:exhibit_12_4"),
      file = tex_file,
      include.rownames = FALSE)
cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 12.4
# =============================================================================
