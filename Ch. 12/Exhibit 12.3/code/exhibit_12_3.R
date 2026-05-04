# =============================================================================
# Exhibit 12.3: Selective Attrition Tests for CHECC Data
# =============================================================================
# Tests whether attrition is selectively related to baseline covariates (demographics).
# Extends Exhibit 12.2 by examining specific demographic variables instead of outcomes.
#
# Methodology: Regress each baseline covariate on four group indicators:
#   - π11: treatment × respond
#   - π01: control × respond
#   - π10: treatment × attrit
#   - π00: control × attrit
#
# Covariates tested: female, race_w (white), hl_eng_span (Spanish), birthweight
#
# Hypothesis tests:
#   H0^12.2: π10 = π00 & π11 = π01 (attrition same across treatment/control)
#   H0^12.3: π10 = π00 = π11 = π01 (all groups have same covariate means)

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


# --- Estimate models for each covariate -------------------------------------
# Fit robust linear regression models for each baseline covariate

# Female
female_cog <- lm_robust(
  female ~ pi11 + pi01 + pi10 + pi00 + 0,
  data = cleaned_data
)

# White
white_cog <- lm_robust(
  race_w ~ pi11 + pi01 + pi10 + pi00 + 0,
  data = cleaned_data
)

# Spanish
spanish_cog <- lm_robust(
  hl_eng_span ~ pi11 + pi01 + pi10 + pi00 + 0,
  data = cleaned_data
)

# Birthweight
birthweight_cog <- lm_robust(
  birthweight ~ pi11 + pi01 + pi10 + pi00 + 0,
  data = cleaned_data
)


# --- Hypothesis tests --------------------------------------------------------
# Test whether demographic characteristics differ across attrition groups

# Hypothesis tests for Female
h0_12_2_female <- linearHypothesis(
  female_cog,
  c("pi10 = pi00", "pi11 = pi01")
)
pvalue_female_12_2 <- h0_12_2_female$`Pr(>Chisq)`[2]

h0_12_3_female <- linearHypothesis(
  female_cog,
  c("pi10 = pi00", "pi10 = pi11", "pi10 = pi01")
)
pvalue_female_12_3 <- h0_12_3_female$`Pr(>Chisq)`[2]

# Hypothesis tests for White
h0_12_2_white <- linearHypothesis(
  white_cog,
  c("pi10 = pi00", "pi11 = pi01")
)
pvalue_white_12_2 <- h0_12_2_white$`Pr(>Chisq)`[2]

h0_12_3_white <- linearHypothesis(
  white_cog,
  c("pi10 = pi00", "pi10 = pi11", "pi10 = pi01")
)
pvalue_white_12_3 <- h0_12_3_white$`Pr(>Chisq)`[2]

# Hypothesis tests for Spanish
h0_12_2_spanish <- linearHypothesis(
  spanish_cog,
  c("pi10 = pi00", "pi11 = pi01")
)
pvalue_spanish_12_2 <- h0_12_2_spanish$`Pr(>Chisq)`[2]

h0_12_3_spanish <- linearHypothesis(
  spanish_cog,
  c("pi10 = pi00", "pi10 = pi11", "pi10 = pi01")
)
pvalue_spanish_12_3 <- h0_12_3_spanish$`Pr(>Chisq)`[2]

# Hypothesis tests for Birthweight
h0_12_2_birthweight <- linearHypothesis(
  birthweight_cog,
  c("pi10 = pi00", "pi11 = pi01")
)
pvalue_birthweight_12_2 <- h0_12_2_birthweight$`Pr(>Chisq)`[2]

h0_12_3_birthweight <- linearHypothesis(
  birthweight_cog,
  c("pi10 = pi00", "pi10 = pi11", "pi10 = pi01")
)
pvalue_birthweight_12_3 <- h0_12_3_birthweight$`Pr(>Chisq)`[2]


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.3: Selective Attrition Tests for CHECC Data\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("%-15s %-12s %-12s %-12s %-12s %-10s %-10s\n",
            "Variable", "π11", "π01", "π10", "π00", "H0^12.2", "H0^12.3"))
cat(strrep("-", 80), "\n", sep = "")

# Female
cat(sprintf("%-15s %11.3f  %11.3f  %11.3f  %11.3f  %9.3f  %9.3f\n",
            "Female",
            female_cog$coefficients["pi11"],
            female_cog$coefficients["pi01"],
            female_cog$coefficients["pi10"],
            female_cog$coefficients["pi00"],
            pvalue_female_12_2,
            pvalue_female_12_3))
cat(sprintf("%-15s (%9.3f)  (%9.3f)  (%9.3f)  (%9.3f)\n",
            "(SE)",
            female_cog$std.error["pi11"],
            female_cog$std.error["pi01"],
            female_cog$std.error["pi10"],
            female_cog$std.error["pi00"]))

# White
cat(sprintf("%-15s %11.3f  %11.3f  %11.3f  %11.3f  %9.3f  %9.3f\n",
            "White",
            white_cog$coefficients["pi11"],
            white_cog$coefficients["pi01"],
            white_cog$coefficients["pi10"],
            white_cog$coefficients["pi00"],
            pvalue_white_12_2,
            pvalue_white_12_3))
cat(sprintf("%-15s (%9.3f)  (%9.3f)  (%9.3f)  (%9.3f)\n",
            "(SE)",
            white_cog$std.error["pi11"],
            white_cog$std.error["pi01"],
            white_cog$std.error["pi10"],
            white_cog$std.error["pi00"]))

# Spanish
cat(sprintf("%-15s %11.3f  %11.3f  %11.3f  %11.3f  %9.3f  %9.3f\n",
            "Spanish",
            spanish_cog$coefficients["pi11"],
            spanish_cog$coefficients["pi01"],
            spanish_cog$coefficients["pi10"],
            spanish_cog$coefficients["pi00"],
            pvalue_spanish_12_2,
            pvalue_spanish_12_3))
cat(sprintf("%-15s (%9.3f)  (%9.3f)  (%9.3f)  (%9.3f)\n",
            "(SE)",
            spanish_cog$std.error["pi11"],
            spanish_cog$std.error["pi01"],
            spanish_cog$std.error["pi10"],
            spanish_cog$std.error["pi00"]))

# Birthweight
cat(sprintf("%-15s %11.3f  %11.3f  %11.3f  %11.3f  %9.3f  %9.3f\n",
            "Birthweight",
            birthweight_cog$coefficients["pi11"],
            birthweight_cog$coefficients["pi01"],
            birthweight_cog$coefficients["pi10"],
            birthweight_cog$coefficients["pi00"],
            pvalue_birthweight_12_2,
            pvalue_birthweight_12_3))
cat(sprintf("%-15s (%9.3f)  (%9.3f)  (%9.3f)  (%9.3f)\n",
            "(SE)",
            birthweight_cog$std.error["pi11"],
            birthweight_cog$std.error["pi01"],
            birthweight_cog$std.error["pi10"],
            birthweight_cog$std.error["pi00"]))

cat(sprintf("%-15s %d\n", "Observations", nrow(cleaned_data)))
cat(strrep("=", 80), "\n", sep = "")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with coefficients and hypothesis test results
results_table <- data.frame(
  Variable = c("Female", "", "White", "", "Spanish", "", "Birthweight", ""),
  `π11 (Treat × Respond)` = c(
    sprintf("%.3f", female_cog$coefficients["pi11"]),
    sprintf("(%.3f)", female_cog$std.error["pi11"]),
    sprintf("%.3f", white_cog$coefficients["pi11"]),
    sprintf("(%.3f)", white_cog$std.error["pi11"]),
    sprintf("%.3f", spanish_cog$coefficients["pi11"]),
    sprintf("(%.3f)", spanish_cog$std.error["pi11"]),
    sprintf("%.3f", birthweight_cog$coefficients["pi11"]),
    sprintf("(%.3f)", birthweight_cog$std.error["pi11"])
  ),
  `π01 (Control × Respond)` = c(
    sprintf("%.3f", female_cog$coefficients["pi01"]),
    sprintf("(%.3f)", female_cog$std.error["pi01"]),
    sprintf("%.3f", white_cog$coefficients["pi01"]),
    sprintf("(%.3f)", white_cog$std.error["pi01"]),
    sprintf("%.3f", spanish_cog$coefficients["pi01"]),
    sprintf("(%.3f)", spanish_cog$std.error["pi01"]),
    sprintf("%.3f", birthweight_cog$coefficients["pi01"]),
    sprintf("(%.3f)", birthweight_cog$std.error["pi01"])
  ),
  `π10 (Treat × Attrit)` = c(
    sprintf("%.3f", female_cog$coefficients["pi10"]),
    sprintf("(%.3f)", female_cog$std.error["pi10"]),
    sprintf("%.3f", white_cog$coefficients["pi10"]),
    sprintf("(%.3f)", white_cog$std.error["pi10"]),
    sprintf("%.3f", spanish_cog$coefficients["pi10"]),
    sprintf("(%.3f)", spanish_cog$std.error["pi10"]),
    sprintf("%.3f", birthweight_cog$coefficients["pi10"]),
    sprintf("(%.3f)", birthweight_cog$std.error["pi10"])
  ),
  `π00 (Control × Attrit)` = c(
    sprintf("%.3f", female_cog$coefficients["pi00"]),
    sprintf("(%.3f)", female_cog$std.error["pi00"]),
    sprintf("%.3f", white_cog$coefficients["pi00"]),
    sprintf("(%.3f)", white_cog$std.error["pi00"]),
    sprintf("%.3f", spanish_cog$coefficients["pi00"]),
    sprintf("(%.3f)", spanish_cog$std.error["pi00"]),
    sprintf("%.3f", birthweight_cog$coefficients["pi00"]),
    sprintf("(%.3f)", birthweight_cog$std.error["pi00"])
  ),
  `H0^12.2 (p-value)` = c(
    sprintf("%.3f", pvalue_female_12_2), "",
    sprintf("%.3f", pvalue_white_12_2), "",
    sprintf("%.3f", pvalue_spanish_12_2), "",
    sprintf("%.3f", pvalue_birthweight_12_2), ""
  ),
  `H0^12.3 (p-value)` = c(
    sprintf("%.3f", pvalue_female_12_3), "",
    sprintf("%.3f", pvalue_white_12_3), "",
    sprintf("%.3f", pvalue_spanish_12_3), "",
    sprintf("%.3f", pvalue_birthweight_12_3), ""
  ),
  check.names = FALSE
)

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_12_3_r.tex")
print(xtable(results_table,
             caption = "Selective Attrition Tests for CHECC Data",
             label = "tab:exhibit_12_3"),
      file = tex_file,
      include.rownames = FALSE)
cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 12.3
# =============================================================================
