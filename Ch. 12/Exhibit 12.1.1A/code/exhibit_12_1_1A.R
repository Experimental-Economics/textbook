# =============================================================================
# Exhibit 12.1.1A: ATEs With and Without Available Case Analysis
# =============================================================================
# Compares treatment effects with and without available case analysis.
# Columns 1-2: Without controls
# Columns 3-4: With controls (female, race_w, hl_eng_span, birthweight)
#
# Reference: Chapter 12, Addressing Attrition

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


# --- Filter for available case analysis -------------------------------------
# Available case analysis: restrict to observations with observed outcomes
filtered_data <- cleaned_data %>% filter(r_i == 1)


# --- Estimate models ---------------------------------------------------------
# Column 1: Default model without controls (full data, includes missing outcomes)
model_default <- lm(
  std_cog_sl ~ d_i,
  data = cleaned_data
)

# Column 2: Available case analysis without controls (only observed outcomes)
aca.model <- lm(
  std_cog_sl ~ d_i,
  data = filtered_data
)

# Column 3: Default model with controls (full data)
model_default_controls <- lm(
  std_cog_sl ~ d_i + female + race_w + hl_eng_span + birthweight,
  data = cleaned_data
)

# Column 4: Available case analysis with controls (only observed outcomes)
aca.model.controls <- lm(
  std_cog_sl ~ d_i + female + race_w + hl_eng_span + birthweight,
  data = filtered_data
)


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.1.1A: ATEs With and Without Available Case Analysis\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("%-20s %15s %15s %15s %15s\n", "", "(1)", "(2)", "(3)", "(4)"))
cat(sprintf("%-20s %15s %15s %15s %15s\n", "", "Default", "Available", "Default", "Available"))
cat(sprintf("%-20s %15s %15s %15s %15s\n", "", "Model", "Case", "Model", "Case"))
cat(strrep("-", 80), "\n", sep = "")

# Pre-K coefficient row
cat(sprintf("%-20s %15.3f %15.3f %15.3f %15.3f\n",
            "Pre-K",
            coef(model_default)["d_iTRUE"],
            coef(aca.model)["d_iTRUE"],
            coef(model_default_controls)["d_iTRUE"],
            coef(aca.model.controls)["d_iTRUE"]))
cat(sprintf("%-20s (%13.3f) (%13.3f) (%13.3f) (%13.3f)\n",
            "",
            summary(model_default)$coefficients["d_iTRUE", "Std. Error"],
            summary(aca.model)$coefficients["d_iTRUE", "Std. Error"],
            summary(model_default_controls)$coefficients["d_iTRUE", "Std. Error"],
            summary(aca.model.controls)$coefficients["d_iTRUE", "Std. Error"]))

# Constant row
cat(sprintf("%-20s %15.3f %15.3f %15.3f %15.3f\n",
            "Constant",
            coef(model_default)["(Intercept)"],
            coef(aca.model)["(Intercept)"],
            coef(model_default_controls)["(Intercept)"],
            coef(aca.model.controls)["(Intercept)"]))
cat(sprintf("%-20s (%13.3f) (%13.3f) (%13.3f) (%13.3f)\n",
            "",
            summary(model_default)$coefficients["(Intercept)", "Std. Error"],
            summary(aca.model)$coefficients["(Intercept)", "Std. Error"],
            summary(model_default_controls)$coefficients["(Intercept)", "Std. Error"],
            summary(aca.model.controls)$coefficients["(Intercept)", "Std. Error"]))

# Controls indicator row
cat(sprintf("%-20s %15s %15s %15s %15s\n", "Controls", "No", "No", "Yes", "Yes"))

# R-squared row
cat(sprintf("%-20s %15.3f %15.3f %15.3f %15.3f\n",
            "R-squared",
            summary(model_default)$r.squared,
            summary(aca.model)$r.squared,
            summary(model_default_controls)$r.squared,
            summary(aca.model.controls)$r.squared))

# Observations row
cat(sprintf("%-20s %15d %15d %15d %15d\n",
            "Observations",
            nobs(model_default),
            nobs(aca.model),
            nobs(model_default_controls),
            nobs(aca.model.controls)))
cat(strrep("=", 80), "\n", sep = "")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table <- data.frame(
  Variable = c("Pre-K", "", "Constant", "", "Controls", "R-squared", "Observations"),
  `(1) Default Model` = c(
    sprintf("%.3f", coef(model_default)["d_iTRUE"]),
    sprintf("(%.3f)", summary(model_default)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(model_default)["(Intercept)"]),
    sprintf("(%.3f)", summary(model_default)$coefficients["(Intercept)", "Std. Error"]),
    "No",
    sprintf("%.3f", summary(model_default)$r.squared),
    sprintf("%d", nobs(model_default))
  ),
  `(2) Available Case` = c(
    sprintf("%.3f", coef(aca.model)["d_iTRUE"]),
    sprintf("(%.3f)", summary(aca.model)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(aca.model)["(Intercept)"]),
    sprintf("(%.3f)", summary(aca.model)$coefficients["(Intercept)", "Std. Error"]),
    "No",
    sprintf("%.3f", summary(aca.model)$r.squared),
    sprintf("%d", nobs(aca.model))
  ),
  `(3) Default Model` = c(
    sprintf("%.3f", coef(model_default_controls)["d_iTRUE"]),
    sprintf("(%.3f)", summary(model_default_controls)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(model_default_controls)["(Intercept)"]),
    sprintf("(%.3f)", summary(model_default_controls)$coefficients["(Intercept)", "Std. Error"]),
    "Yes",
    sprintf("%.3f", summary(model_default_controls)$r.squared),
    sprintf("%d", nobs(model_default_controls))
  ),
  `(4) Available Case` = c(
    sprintf("%.3f", coef(aca.model.controls)["d_iTRUE"]),
    sprintf("(%.3f)", summary(aca.model.controls)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(aca.model.controls)["(Intercept)"]),
    sprintf("(%.3f)", summary(aca.model.controls)$coefficients["(Intercept)", "Std. Error"]),
    "Yes",
    sprintf("%.3f", summary(aca.model.controls)$r.squared),
    sprintf("%d", nobs(aca.model.controls))
  ),
  check.names = FALSE
)

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_12_1_1A_r.tex")
print(xtable(results_table,
             caption = "ATEs With and Without Available Case Analysis",
             label = "tab:exhibit_12_1_1A"),
      file = tex_file,
      include.rownames = FALSE)
cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 12.1.1A
# =============================================================================
