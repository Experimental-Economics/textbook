# =============================================================================
# Exhibit 12.1.2A: ATEs and Horowitz and Manski Bounds
# =============================================================================
# Compares default model with upper and lower bounds from Horowitz & Manski (2000).
# Column 1: Default model (no attrition adjustment)
# Column 2: Upper bound (best-case scenario for treatment effect)
# Column 3: Lower bound (worst-case scenario for treatment effect)
#
# Reference: Horowitz, J. L., & Manski, C. F. (2000). Nonparametric Analysis
# of Randomized Experiments with Missing Covariate and Outcome Data.
# Journal of the American Statistical Association, 95(449), 77-84.

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


# --- Parameters --------------------------------------------------------------
# Bounds for outcome variable (standardized cognitive test scores)
upper_bound <- 3
lower_bound <- -3


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


# --- Filter for available cases ---------------------------------------------
# Default model uses only observed cases
filtered_data <- cleaned_data %>% filter(r_i == 1)


# --- Estimate models ---------------------------------------------------------
# Column 1: Default model (available cases only, no bounding)
model_default_hm <- lm(
  std_cog_sl ~ d_i,
  data = filtered_data
)

# Column 2: Horowitz & Manski upper bound
horowitz.manski.model.upper <- lm(
  std_cog_sl ~ d_i,
  data = cleaned_data %>% mutate(std_cog_sl = case_when(
    r_i == 0 & d_i == 1 ~ upper_bound,
    r_i == 0 & d_i == 0 ~ lower_bound,
    TRUE ~ std_cog_sl
  ))
)

# Column 3: Horowitz & Manski lower bound
horowitz.manski.model.lower <- lm(
  std_cog_sl ~ d_i,
  data = cleaned_data %>% mutate(std_cog_sl = case_when(
    r_i == 0 & d_i == 1 ~ lower_bound,
    r_i == 0 & d_i == 0 ~ upper_bound,
    TRUE ~ std_cog_sl
  ))
)


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.1.2A: ATEs and Horowitz and Manski Bounds\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("%-20s %15s %15s %15s\n", "", "(1)", "(2)", "(3)"))
cat(sprintf("%-20s %15s %15s %15s\n", "", "Default", "H&M", "H&M"))
cat(sprintf("%-20s %15s %15s %15s\n", "", "Model", "Upper Bound", "Lower Bound"))
cat(strrep("-", 80), "\n", sep = "")

# Pre-K coefficient row
cat(sprintf("%-20s %15.3f %15.3f %15.3f\n",
            "Pre-K",
            coef(model_default_hm)["d_iTRUE"],
            coef(horowitz.manski.model.upper)["d_iTRUE"],
            coef(horowitz.manski.model.lower)["d_iTRUE"]))
cat(sprintf("%-20s (%13.3f) (%13.3f) (%13.3f)\n",
            "",
            summary(model_default_hm)$coefficients["d_iTRUE", "Std. Error"],
            summary(horowitz.manski.model.upper)$coefficients["d_iTRUE", "Std. Error"],
            summary(horowitz.manski.model.lower)$coefficients["d_iTRUE", "Std. Error"]))

# Constant row
cat(sprintf("%-20s %15.3f %15.3f %15.3f\n",
            "Constant",
            coef(model_default_hm)["(Intercept)"],
            coef(horowitz.manski.model.upper)["(Intercept)"],
            coef(horowitz.manski.model.lower)["(Intercept)"]))
cat(sprintf("%-20s (%13.3f) (%13.3f) (%13.3f)\n",
            "",
            summary(model_default_hm)$coefficients["(Intercept)", "Std. Error"],
            summary(horowitz.manski.model.upper)$coefficients["(Intercept)", "Std. Error"],
            summary(horowitz.manski.model.lower)$coefficients["(Intercept)", "Std. Error"]))

# Controls indicator row
cat(sprintf("%-20s %15s %15s %15s\n", "Controls", "No", "No", "No"))

# R-squared row
cat(sprintf("%-20s %15.3f %15.3f %15.3f\n",
            "R-squared",
            summary(model_default_hm)$r.squared,
            summary(horowitz.manski.model.upper)$r.squared,
            summary(horowitz.manski.model.lower)$r.squared))

# Observations row
cat(sprintf("%-20s %15d %15d %15d\n",
            "Observations",
            nobs(model_default_hm),
            nobs(horowitz.manski.model.upper),
            nobs(horowitz.manski.model.lower)))
cat(strrep("=", 80), "\n", sep = "")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table <- data.frame(
  Variable = c("Pre-K", "", "Constant", "", "Controls", "R-squared", "Observations"),
  `(1) Default Model` = c(
    sprintf("%.3f", coef(model_default_hm)["d_iTRUE"]),
    sprintf("(%.3f)", summary(model_default_hm)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(model_default_hm)["(Intercept)"]),
    sprintf("(%.3f)", summary(model_default_hm)$coefficients["(Intercept)", "Std. Error"]),
    "No",
    sprintf("%.3f", summary(model_default_hm)$r.squared),
    sprintf("%d", nobs(model_default_hm))
  ),
  `(2) H&M Upper Bound` = c(
    sprintf("%.3f", coef(horowitz.manski.model.upper)["d_iTRUE"]),
    sprintf("(%.3f)", summary(horowitz.manski.model.upper)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(horowitz.manski.model.upper)["(Intercept)"]),
    sprintf("(%.3f)", summary(horowitz.manski.model.upper)$coefficients["(Intercept)", "Std. Error"]),
    "No",
    sprintf("%.3f", summary(horowitz.manski.model.upper)$r.squared),
    sprintf("%d", nobs(horowitz.manski.model.upper))
  ),
  `(3) H&M Lower Bound` = c(
    sprintf("%.3f", coef(horowitz.manski.model.lower)["d_iTRUE"]),
    sprintf("(%.3f)", summary(horowitz.manski.model.lower)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(horowitz.manski.model.lower)["(Intercept)"]),
    sprintf("(%.3f)", summary(horowitz.manski.model.lower)$coefficients["(Intercept)", "Std. Error"]),
    "No",
    sprintf("%.3f", summary(horowitz.manski.model.lower)$r.squared),
    sprintf("%d", nobs(horowitz.manski.model.lower))
  ),
  check.names = FALSE
)

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_12_1_2A_r.tex")
print(xtable(results_table,
             caption = "ATEs and Horowitz and Manski Bounds",
             label = "tab:exhibit_12_1_2A"),
      file = tex_file,
      include.rownames = FALSE)
cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 12.1.2A
# =============================================================================
