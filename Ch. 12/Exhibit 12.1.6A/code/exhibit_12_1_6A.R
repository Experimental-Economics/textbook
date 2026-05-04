# =============================================================================
# Exhibit 12.1.6A: Default Model Outcomes
# =============================================================================
# Visualizes the density distribution of cognitive scores for the default model
# using kernel density plots. Shows available cases only (those who did not attrit).
#
# This plot provides a baseline view of the observed outcome distributions
# without any attrition adjustment. It includes only participants for whom
# we have observed post-treatment outcomes.

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
# Default model uses only observed cases (no imputation or weighting)
filtered_data <- cleaned_data %>% filter(r_i == 1)


# --- Calculate summary statistics --------------------------------------------
prek_avg <- mean((filtered_data %>% filter(d_i == 1))$std_cog_sl, na.rm = TRUE)
ctrl_avg <- mean((filtered_data %>% filter(d_i == 0))$std_cog_sl, na.rm = TRUE)


# --- Create plot -------------------------------------------------------------
base.plot <- ggplot(
  data = filtered_data,
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
output_file <- file.path(output_dir, "exhibit_12_1_6A_default_model_outcomes.png")
ggsave(output_file, plot = base.plot, width = 10, height = 6, units = "in", dpi = 300)

cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.1.6A: Default Model Outcomes - Plot saved\n")
cat(strrep("=", 80), "\n", sep = "")
cat("Saved to:", output_file, "\n")
cat(sprintf("Pre-K Average: %.3f\n", prek_avg))
cat(sprintf("Control Average: %.3f\n", ctrl_avg))
cat(sprintf("Treatment Effect: %.3f\n", prek_avg - ctrl_avg))
cat(sprintf("Sample Size (Pre-K): %d\n", sum(filtered_data$d_i == 1)))
cat(sprintf("Sample Size (Control): %d\n", sum(filtered_data$d_i == 0)))
cat(strrep("=", 80), "\n", sep = "")

# =============================================================================
# END OF EXHIBIT 12.1.6A
# =============================================================================
