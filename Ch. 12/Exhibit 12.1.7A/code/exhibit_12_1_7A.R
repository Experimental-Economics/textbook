# =============================================================================
# Exhibit 12.1.7A: IPW Model Outcomes
# =============================================================================
# Visualizes the density distribution of cognitive scores using Inverse Probability
# Weighting (IPW) to adjust for differential attrition.
#
# This plot shows how the outcome distributions change when we weight observations
# by the inverse of their predicted probability of response, conditional on
# baseline covariates. This reweighting adjusts for selective attrition.

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


# --- Calculate weighted summary statistics -----------------------------------
prek_avg <- weighted.mean(
  (ipwdata %>% filter(d_i == 1))$std_cog_sl,
  (ipwdata %>% filter(d_i == 1))$invwt,
  na.rm = TRUE
)

ctrl_avg <- weighted.mean(
  (ipwdata %>% filter(d_i == 0))$std_cog_sl,
  (ipwdata %>% filter(d_i == 0))$invwt,
  na.rm = TRUE
)


# --- Create plot -------------------------------------------------------------
ipw.plot <- ggplot(
  data = ipwdata,
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
output_file <- file.path(output_dir, "exhibit_12_1_7A_ipw_model_outcomes.png")
ggsave(output_file, plot = ipw.plot, width = 10, height = 6, units = "in", dpi = 300)

cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.1.7A: IPW Model Outcomes - Plot saved\n")
cat(strrep("=", 80), "\n", sep = "")
cat("Saved to:", output_file, "\n")
cat(sprintf("Pre-K Average (weighted): %.3f\n", prek_avg))
cat(sprintf("Control Average (weighted): %.3f\n", ctrl_avg))
cat(sprintf("Treatment Effect (IPW): %.3f\n", prek_avg - ctrl_avg))
cat(strrep("=", 80), "\n", sep = "")

# =============================================================================
# END OF EXHIBIT 12.1.7A
# =============================================================================
