# =============================================================================
# Exhibit 12.1.5A: ATEs: Default and IPW
# =============================================================================
# Compares treatment effects between default model and Inverse Probability
# Weighting (IPW) approach.
# Column 1: Default model (available cases only)
# Column 2: Inverse Probability Weighting (IPW) model
#
# IPW adjusts for differential attrition by weighting observations by the inverse
# of their predicted probability of response, conditional on baseline covariates.

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


# --- Filter for available cases ---------------------------------------------
# Default model uses only observed cases
filtered_data <- cleaned_data %>% filter(r_i == 1)


# --- Estimate propensity scores ----------------------------------------------
# Fit logistic regression models to predict response probability by treatment group
psreg_d.1 <- glm(
  r_i ~ female + race_w + hl_eng_span + birthweight,
  data = cleaned_data %>% filter(d_i == 1),
  family = binomial(link = "logit")
)

psreg_d.0 <- glm(
  r_i ~ female + race_w + hl_eng_span + birthweight,
  data = cleaned_data %>% filter(d_i == 0),
  family = binomial(link = "logit")
)


# --- Create IPW dataset ------------------------------------------------------
# Predict response probabilities for each treatment group
ipwdata_1 <- cleaned_data %>%
  filter(d_i == 1) %>%
  mutate(prob = predict(psreg_d.1, type = 'response'))

ipwdata_0 <- cleaned_data %>%
  filter(d_i == 0) %>%
  mutate(prob = predict(psreg_d.0, type = 'response'))

# Combine treatment groups and calculate inverse probability weights
ipwdata <- rbind(ipwdata_0, ipwdata_1) %>%
  mutate(invwt = 1 / prob)


# --- Estimate models ---------------------------------------------------------
# Column 1: Default model (available cases only, no weighting)
model_default_ipw <- lm(
  std_cog_sl ~ d_i,
  data = filtered_data
)

# Column 2: Inverse Probability Weighted model
ipw.model <- lm(
  std_cog_sl ~ d_i,
  data = ipwdata,
  weights = invwt
)


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.1.5A: ATEs: Default and IPW\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("%-20s %15s %15s\n", "", "(1)", "(2)"))
cat(sprintf("%-20s %15s %15s\n", "", "Default Model", "IPW"))
cat(strrep("-", 80), "\n", sep = "")

# Pre-K coefficient row
cat(sprintf("%-20s %15.3f %15.3f\n",
            "Pre-K",
            coef(model_default_ipw)["d_iTRUE"],
            coef(ipw.model)["d_iTRUE"]))
cat(sprintf("%-20s (%13.3f) (%13.3f)\n",
            "",
            summary(model_default_ipw)$coefficients["d_iTRUE", "Std. Error"],
            summary(ipw.model)$coefficients["d_iTRUE", "Std. Error"]))

# Constant row
cat(sprintf("%-20s %15.3f %15.3f\n",
            "Constant",
            coef(model_default_ipw)["(Intercept)"],
            coef(ipw.model)["(Intercept)"]))
cat(sprintf("%-20s (%13.3f) (%13.3f)\n",
            "",
            summary(model_default_ipw)$coefficients["(Intercept)", "Std. Error"],
            summary(ipw.model)$coefficients["(Intercept)", "Std. Error"]))

# Controls indicator row
cat(sprintf("%-20s %15s %15s\n", "Controls", "No", "No"))

# R-squared row
cat(sprintf("%-20s %15.3f %15.3f\n",
            "R-squared",
            summary(model_default_ipw)$r.squared,
            summary(ipw.model)$r.squared))

# Observations row
cat(sprintf("%-20s %15d %15d\n",
            "Observations",
            nobs(model_default_ipw),
            nobs(ipw.model)))
cat(strrep("=", 80), "\n", sep = "")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table <- data.frame(
  Variable = c("Pre-K", "", "Constant", "", "Controls", "R-squared", "Observations"),
  `(1) Default Model` = c(
    sprintf("%.3f", coef(model_default_ipw)["d_iTRUE"]),
    sprintf("(%.3f)", summary(model_default_ipw)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(model_default_ipw)["(Intercept)"]),
    sprintf("(%.3f)", summary(model_default_ipw)$coefficients["(Intercept)", "Std. Error"]),
    "No",
    sprintf("%.3f", summary(model_default_ipw)$r.squared),
    sprintf("%d", nobs(model_default_ipw))
  ),
  `(2) IPW` = c(
    sprintf("%.3f", coef(ipw.model)["d_iTRUE"]),
    sprintf("(%.3f)", summary(ipw.model)$coefficients["d_iTRUE", "Std. Error"]),
    sprintf("%.3f", coef(ipw.model)["(Intercept)"]),
    sprintf("(%.3f)", summary(ipw.model)$coefficients["(Intercept)", "Std. Error"]),
    "No",
    sprintf("%.3f", summary(ipw.model)$r.squared),
    sprintf("%d", nobs(ipw.model))
  ),
  check.names = FALSE
)

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_12_1_5A_r.tex")
print(xtable(results_table,
             caption = "ATEs: Default and IPW",
             label = "tab:exhibit_12_1_5A"),
      file = tex_file,
      include.rownames = FALSE)
cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 12.1.5A
# =============================================================================
