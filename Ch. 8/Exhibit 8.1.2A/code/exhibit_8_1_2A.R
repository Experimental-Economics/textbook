# =============================================================================
# Exhibit 8.1.2A: Baron and Kenny Mediation Analysis: Parental Beliefs
# =============================================================================
# Conducts mediation analysis using the Baron and Kenny framework to examine
# the relationship between home visiting programs, parental beliefs, and outcomes
# (parental investments and child outcomes).
#
# Implements the Baron and Kenny approach with three regression equations:
# - M_i = α + λ_dm*D_i + X_i'δ + v_i                    (A8.1.4)
# - Y_i = θ + λ_dy*D_i + X_i'δ + ω_i                    (A8.1.5)
# - Y_i = μ + λ_dy*D_i + λ_my*M_i + X_i'δ + ε_i        (A8.1.6)
#
# where:
# - D_i: Treatment indicator (Home Visiting Program)
# - M_i: Mediator (Parental Beliefs)
# - Y_i: Outcome (Parental Investments or Child Outcome)
#
# Reference: Chapter 8, Section 8.3.1, Mediation Analysis

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


# --- Load data ---------------------------------------------------------------
data <- read_dta(file.path(data_dir, "TMPdata_de-identified.dta"))

# Prepare input data with renamed variables
input_data <- data %>%
  select(speak22_A2_sd, Treated, cvc_A2_sd, ctc_A2_sd) %>%
  rename(M = speak22_A2_sd,
         D = Treated,
         Y_child = cvc_A2_sd,
         Y_invest = ctc_A2_sd)


# --- Step 1: Regression of Y on D (without mediator) ------------------------
model_child <- lm(Y_child ~ D, data = input_data)
model_invest <- lm(Y_invest ~ D, data = input_data)


# --- Step 2: Regression of M on D -------------------------------------------
model_m <- lm(M ~ D, data = input_data)


# --- Step 3: Regression of Y on M, controlling for D ------------------------
model_childm <- lm(Y_child ~ M + D, data = input_data)
model_investm <- lm(Y_invest ~ M + D, data = input_data)


# --- Step 4: Sobel test for mediation ---------------------------------------
# Calculate the Sobel test statistic and its p-value: Child Outcome
c_indirect <- coef(model_m)["D"] * coef(model_childm)["M"]
c_coef_a <- coef(model_m)["D"]
c_coef_b <- coef(model_childm)["M"]
c_var_a <- vcov(model_m)["D", "D"]
c_var_b <- vcov(model_childm)["M", "M"]
c_se_indirect <- sqrt(c_coef_a^2 * c_var_b + c_coef_b^2 * c_var_a)
c_z <- c_indirect / c_se_indirect
c_p <- 2 * (1 - pnorm(abs(c_z)))

# Calculate the Sobel test statistic and its p-value: Parental Investments
i_indirect <- coef(model_m)["D"] * coef(model_investm)["M"]
i_coef_a <- coef(model_m)["D"]
i_coef_b <- coef(model_investm)["M"]
i_var_a <- vcov(model_m)["D", "D"]
i_var_b <- vcov(model_investm)["M", "M"]
i_se_indirect <- sqrt(i_coef_a^2 * i_var_b + i_coef_b^2 * i_var_a)
i_z <- i_indirect / i_se_indirect
i_p <- 2 * (1 - pnorm(abs(i_z)))


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 8.1.2A: Baron and Kenny Mediation Analysis: Parental Beliefs\n")
cat(strrep("=", 80), "\n\n", sep = "")

cat("(1) Parental Beliefs: M ~ D\n")
cat(strrep("-", 80), "\n", sep = "")
print(summary(model_m))
cat("\n")

cat("(2) Parental Investments: Y_invest ~ D (no mediator)\n")
cat(strrep("-", 80), "\n", sep = "")
print(summary(model_invest))
cat("\n")

cat("(3) Parental Investments: Y_invest ~ M + D (with mediator)\n")
cat(strrep("-", 80), "\n", sep = "")
print(summary(model_investm))
cat("\n")

cat("(4) Child Outcome: Y_child ~ D (no mediator)\n")
cat(strrep("-", 80), "\n", sep = "")
print(summary(model_child))
cat("\n")

cat("(5) Child Outcome: Y_child ~ M + D (with mediator)\n")
cat(strrep("-", 80), "\n", sep = "")
print(summary(model_childm))
cat("\n")

cat("Sobel Test Results\n")
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("Parental Investments: z = %.2f, p = %.4f\n", i_z, i_p))
cat(sprintf("Child Outcome: z = %.2f, p = %.4f\n", c_z, c_p))
cat("\n")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table <- data.frame(
  Variable = c("Parental Beliefs", "", "Home Visiting Program", "", "Sobel z-test"),
  `(1) Parental Beliefs` = c(
    "-",
    "-",
    sprintf("%.2f", coef(model_m)["D"]),
    sprintf("(%.2f)", summary(model_m)$coefficients["D", "Std. Error"]),
    "-"
  ),
  `(2) Parental Investments` = c(
    "-",
    "-",
    sprintf("%.2f", coef(model_invest)["D"]),
    sprintf("(%.2f)", summary(model_invest)$coefficients["D", "Std. Error"]),
    "-"
  ),
  `(3) Parental Investments` = c(
    sprintf("%.2f", coef(model_investm)["M"]),
    sprintf("(%.2f)", summary(model_investm)$coefficients["M", "Std. Error"]),
    sprintf("%.3f", coef(model_investm)["D"]),
    sprintf("(%.3f)", summary(model_investm)$coefficients["D", "Std. Error"]),
    sprintf("%.2f", i_z)
  ),
  `(4) Child Outcome` = c(
    "-",
    "-",
    sprintf("%.2f", coef(model_child)["D"]),
    sprintf("(%.2f)", summary(model_child)$coefficients["D", "Std. Error"]),
    "-"
  ),
  `(5) Child Outcome` = c(
    sprintf("%.2f", coef(model_childm)["M"]),
    sprintf("(%.2f)", summary(model_childm)$coefficients["M", "Std. Error"]),
    sprintf("%.2f", coef(model_childm)["D"]),
    sprintf("(%.2f)", summary(model_childm)$coefficients["D", "Std. Error"]),
    sprintf("%.2f", c_z)
  ),
  check.names = FALSE
)

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_8_1_2A_r.tex")
print(xtable(results_table,
             caption = "Baron and Kenny Mediation Analysis: Parental Beliefs",
             label = "tab:exhibit_8_1_2A"),
      file = tex_file,
      include.rownames = FALSE)
cat(sprintf("\n✓ Saved to: %s\n\n", tex_file))

# =============================================================================
# END OF EXHIBIT 8.1.2A
# =============================================================================
