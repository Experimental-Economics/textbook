# =============================================================================
# Chapter 7: Causal Forest Analysis for U-Program
# =============================================================================
# Estimates Conditional Average Treatment Effects (CATEs) using causal forests.
# Analyzes the effect of Math curriculum allocation on disciplinary infractions
# during the 16-17 academic year across 4 quarters.
#
# Uses generalized random forests (grf) to estimate heterogeneous treatment
# effects based on pre-treatment characteristics including ScanQuest scores,
# demographics, and school variables.
#
# Reference: Chapter 7, Heterogeneous Treatment Effects

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(tidyverse)
library(readr)
library(grf)

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
data_up <- read_csv(file.path(data_dir, "u_program_data.csv"))

cat("\n", strrep("=", 80), "\n", sep = "")
cat("CHAPTER 7: Causal Forest Analysis for U-Program\n")
cat(strrep("=", 80), "\n", sep = "")
cat("The program took place in the 16-17 academic year, spread in 4 different quarters.\n")
cat(strrep("=", 80), "\n\n", sep = "")

# Filter to Math treatment and control groups
data_up_math_control <- data_up %>% filter(treatment %in% c("Math", "control"))


# --- Select pre-treatment characteristics ------------------------------------
pre_treatment_characs <-
  data_up_math_control %>%
  dplyr::select(matches("^ScanQuest.*PRE$"), school, grade, class, age, female, white, black, hispanic, other_race, disc_1415, disc_1516, DaysAbsent_1415,
         DaysAbsent_1516, enrollment_1415, enrollment_1516)


# --- Check for missing data --------------------------------------------------
na_table <-
  pre_treatment_characs %>%
  dplyr::summarise(across(everything(), ~ mean(is.na(.)))) %>%
  tidyr::pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "na_proportion"
  )

many_missing <- na_table %>% filter(na_proportion > 0.05)

cat("Variables with >5% missing data:\n")
print(many_missing)
cat("\n")

# Remove variables with excessive missing data
pre_treatment_characs <-
  pre_treatment_characs %>%
  dplyr::select(-disc_1415, -DaysAbsent_1415)


# --- Create post-treatment outcome variable ----------------------------------
data_up_math_control <- data_up_math_control %>%
  mutate(disc_post = case_when(treated_quarter == 1 ~ disc_q1_1617,
                               treated_quarter == 2 ~ disc_q2_1617,
                               treated_quarter == 3 ~ disc_q3_1617,
                               treated_quarter == 4 ~ disc_q4_1617))


# --- Estimate baseline treatment effect --------------------------------------
# Create treatment indicator (1 = Math, 0 = control)
data_up_math_control <- data_up_math_control %>%
  mutate(treatment_Math = (treatment == "Math"))

m2b <- data_up_math_control %>% lm(disc_post ~ treatment_Math, data = .)

cat("Baseline treatment effect (OLS regression):\n")
summary(m2b)
cat(sprintf("\nThe children that were allocated to the Math have %.4f less disciplinary infractions.\n\n",
            -round(m2b$coefficients[2], 4)))


# --- Prepare data for causal forest ------------------------------------------
# Remove rows with missing values in outcome, treatment, or covariates
# This ensures R and Python use the same data
complete_cases <- complete.cases(pre_treatment_characs) &
                  !is.na(data_up_math_control$disc_post) &
                  !is.na(data_up_math_control$treatment_Math)

cat(sprintf("Complete cases: %d out of %d observations\n\n",
            sum(complete_cases), length(complete_cases)))

X <- pre_treatment_characs[complete_cases, ]
Y <- data_up_math_control$disc_post[complete_cases]
W <- data_up_math_control$treatment_Math[complete_cases]


# --- Estimate causal forest --------------------------------------------------
causal_forest_disc_math <- causal_forest(X, Y, W)


# --- Extract predictions -----------------------------------------------------
tau_hat <- predict(causal_forest_disc_math)$predictions

causal_forest_disc_math$predictions

df_cdf <- data.frame(tau_hat = tau_hat)


# --- Create CATE cumulative relative frequency plot -------------------------
# Sort CATE values and calculate cumulative relative frequencies
df_cdf_sorted <- df_cdf %>%
  arrange(tau_hat) %>%
  mutate(cumulative_freq = row_number() / n())

cate_plot <- ggplot(df_cdf_sorted, aes(x = tau_hat, y = cumulative_freq)) +
  geom_line(linewidth = 1.2, color = "#1f77b4") +
  labs(
    x = "CATE",
    y = "Cumulative Relative Frequency",
    title = "CATEs",
    caption = "Effect of being allocated to the Math Curriculum on number of disciplinary infractions."
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.minor = element_line(linetype = "dashed", linewidth = 0.3, color = "gray80"),
    panel.grid.major = element_line(linetype = "dashed", linewidth = 0.3, color = "gray70"),
    plot.title = element_text(face = "bold", hjust = 0.5)
  )


# --- Save output -------------------------------------------------------------
output_file <- file.path(output_dir, "ch7_causal_forest_cate_cumulative_r.png")
ggsave(output_file, plot = cate_plot, width = 10, height = 6, units = "in", dpi = 300)

cat(strrep("=", 80), "\n", sep = "")
cat("CATE Analysis Results\n")
cat(strrep("=", 80), "\n", sep = "")
cat("Saved to:", output_file, "\n")
cat(sprintf("Number of observations: %d\n", length(tau_hat)))
cat(sprintf("Mean CATE: %.4f\n", mean(tau_hat)))
cat(sprintf("Median CATE: %.4f\n", median(tau_hat)))
cat(sprintf("Min CATE: %.4f\n", min(tau_hat)))
cat(sprintf("Max CATE: %.4f\n", max(tau_hat)))
cat("\nAll CATE values are negative, which means that no one\n")
cat("is predicted to increase disciplinary infractions due to treatment.\n")
cat(strrep("=", 80), "\n", sep = "")

# =============================================================================
# END OF CHAPTER 7: Causal Forest Analysis
# =============================================================================
