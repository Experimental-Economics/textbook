# =============================================================================
# Exhibit 12.1.8A: Lee Bounds (Upper)
# =============================================================================
# Implements Lee (2009) bounds for treatment effects with differential attrition.
# Upper bound: Trims observations from top of control group distribution.
#
# Lee bounds address selective attrition by trimming the distribution with higher
# response rates to match the response rate of the group with lower response.
# The upper bound trims from the top of the control distribution, providing an
# optimistic estimate of the treatment effect.
#
# Reference: Lee, D. S. (2009). Training, Wages, and Sample Selection: Estimating
# Sharp Bounds on Treatment Effects. The Review of Economic Studies, 76(3), 1071-1102.

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


# --- Calculate trimming parameters -------------------------------------------
# Calculate response rates by treatment group
percentage_of_ri_in_control <- mean((cleaned_data %>% filter(d_i == 0))$r_i)
percentage_of_ri_in_prek <- mean((cleaned_data %>% filter(d_i == 1))$r_i)

# Calculate fraction to trim from control group (group with lower response rate)
trimming.fraction <- (percentage_of_ri_in_prek - percentage_of_ri_in_control) /
  percentage_of_ri_in_prek


# --- Apply Lee bounds trimming (upper) ---------------------------------------
# Upper bound: Trim from top of control distribution
# Find quantile threshold for trimming (keep values below this threshold)
mean.outcome.treatment <- mean((cleaned_data %>% filter(d_i == 1))$std_cog_sl, na.rm = TRUE)

# Trim from TOP: keep control observations below (1 - trimming.fraction) quantile
step2 <- cleaned_data %>%
  filter(
    d_i == 0 &
    std_cog_sl < quantile(
      (cleaned_data %>% filter(d_i == 0))$std_cog_sl,
      1 - trimming.fraction,
      na.rm = TRUE
    )
  )

mean.lefttrimmed.control <- mean(step2$std_cog_sl, na.rm = TRUE)
upper_bound <- mean.outcome.treatment - mean.lefttrimmed.control

# Combine trimmed control group with full treatment group
lefttrimmed <- rbind(step2, cleaned_data %>% filter(d_i == 1))


# --- Calculate summary statistics --------------------------------------------
prek_avg <- mean((lefttrimmed %>% filter(d_i == 1))$std_cog_sl, na.rm = TRUE)
ctrl_avg <- mean((lefttrimmed %>% filter(d_i == 0))$std_cog_sl, na.rm = TRUE)


# --- Create plot -------------------------------------------------------------
lee.lefttrimmed.plot <- ggplot(
  data = lefttrimmed,
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
output_file <- file.path(output_dir, "exhibit_12_1_8A_lee_bounds_upper.png")
ggsave(output_file, plot = lee.lefttrimmed.plot, width = 10, height = 6, units = "in", dpi = 300)

cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 12.1.8A: Lee Bounds (Upper) - Plot saved\n")
cat(strrep("=", 80), "\n", sep = "")
cat("Saved to:", output_file, "\n")
cat(sprintf("Response Rate (Control): %.3f\n", percentage_of_ri_in_control))
cat(sprintf("Response Rate (Pre-K): %.3f\n", percentage_of_ri_in_prek))
cat(sprintf("Trimming Fraction: %.3f\n", trimming.fraction))
cat(sprintf("Pre-K Average: %.3f\n", prek_avg))
cat(sprintf("Control Average (trimmed): %.3f\n", ctrl_avg))
cat(sprintf("Treatment Effect (Upper Bound): %.3f\n", upper_bound))
cat(strrep("=", 80), "\n", sep = "")

# =============================================================================
# END OF EXHIBIT 12.1.8A
# =============================================================================
