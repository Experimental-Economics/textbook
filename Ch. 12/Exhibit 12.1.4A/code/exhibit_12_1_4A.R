# =============================================================================
# Exhibit 12.1.4A: Horowitz and Manski Bounds (Upper)
# =============================================================================
# Visualizes the upper bound scenario for treatment effects using kernel density plots.
# Upper bound: best case for treatment (assign +3), worst case for control (assign -3)
#
# This plot shows the distribution of outcomes under the optimistic bounding
# assumption where all treatment attritors had the best possible outcome and
# all control attritors had the worst possible outcome. This provides an upper
# bound on the treatment effect.
#
# Reference: Horowitz, J. L., & Manski, C. F. (2000). Nonparametric Analysis
# of Randomized Experiments with Missing Covariate and Outcome Data.
# Journal of the American Statistical Association, 95(449), 77-84.

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


# --- Create upper bound dataset ----------------------------------------------
# Upper bound: Assign best outcome to treatment attritors, worst to control attritors
upper_bound_data <- cleaned_data %>%
  mutate(std_cog_sl = case_when(
    r_i == 0 & d_i == 1 ~ upper_bound,
    r_i == 0 & d_i == 0 ~ lower_bound,
    TRUE ~ std_cog_sl
  ))


# --- Calculate summary statistics --------------------------------------------
prek_avg <- mean((upper_bound_data %>% filter(d_i == 1))$std_cog_sl, na.rm = TRUE)
ctrl_avg <- mean((upper_bound_data %>% filter(d_i == 0))$std_cog_sl, na.rm = TRUE)


# --- Create plot -------------------------------------------------------------
horowitz.manski.upper.plot <- ggplot(
  data = upper_bound_data,
  aes(x = std_cog_sl, group = d_i, fill = d_i)
) +
  geom_density(adjust = 0.5, alpha = 0.4) +
  xlab("Cognitive Test Score after Summer Loss") +
  ylab("Density") +
  scale_fill_discrete(
    name = "Treatment Status",
    labels = c("Control", "Pre-K")
  ) +
  geom_vline(
    xintercept = prek_avg,
    color = "blue",
    size = 0.8,
    linetype = "dotted"
  ) +
  geom_text(
    aes(x = prek_avg, label = "\nPre-K", y = 0.4),
    color = "blue",
    angle = 90
  ) +
  geom_vline(
    xintercept = ctrl_avg,
    color = "red",
    size = 0.8,
    linetype = "dotted"
  ) +
  geom_text(
    aes(x = ctrl_avg, label = "\nCtrl", y = 0.4),
    color = "red",
    angle = 90
  ) +
  theme_dark()


# --- Save output -------------------------------------------------------------
output_file <- file.path(output_dir, "exhibit_12_1_4A_hm_bounds_upper.png")
ggsave(output_file, plot = horowitz.manski.upper.plot, width = 10, height = 6, units = "in", dpi = 300)

cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.1.4A: Horowitz and Manski Bounds (Upper) - Plot saved\n")
cat(strrep("=", 80), "\n", sep = "")
cat("Saved to:", output_file, "\n")
cat(sprintf("Pre-K Average: %.3f\n", prek_avg))
cat(sprintf("Control Average: %.3f\n", ctrl_avg))
cat(sprintf("Treatment Effect (Upper Bound): %.3f\n", prek_avg - ctrl_avg))
cat(strrep("=", 80), "\n", sep = "")

# =============================================================================
# END OF EXHIBIT 12.1.4A
# =============================================================================
