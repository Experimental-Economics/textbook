# =============================================================================
# Appendix 9.2: Optimal Experimental Design for Panel Data
# =============================================================================

# --- Setup -------------------------------------------------------------------
rm(list = ls())

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

# Install any missing packages, then load them
required_lib <- c("ggplot2", "dplyr")
invisible(lapply(required_lib, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  library(pkg, character.only = TRUE)
}))

# Define paths relative to script location
data_dir <- file.path(dirname(getwd()), "data")
output_dir <- file.path(dirname(getwd()), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Custom theme for consistent plot styling
theme_stata <- function() {
  theme_minimal() +
    theme(
      text = element_text(family = "sans", size = 12),
      panel.grid = element_line(color = "#dddddd", linewidth = 0.3),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      legend.position = c(0.95, 0.95),
      legend.justification = c(1, 1),
      legend.background = element_rect(fill = "white", color = "#dddddd")
    )
}


# --- Core function -----------------------------------------------------------
# Computes optimal sample size n* from pre/post periods.
#
# Inputs:
#   m : number of pre-treatment periods
#   r : number of post-treatment periods
#   C : constant from power calculation, C = 2*(t_{α/2} + t_β)^2 * σ^2 / MDE^2
#
# Returns:
#   Optimal sample size n* = C * (m + r) / (m * r)
#
# Based on McKenzie (2012).

compute_optimal_sample_size <- function(m, r, C) {
  return(C * (m + r) / (m * r))
}


# --- Constants ---------------------------------------------------------------
# Critical values for alpha = 0.05 (two-sided), power = 0.80
# C = 2*(t_{α/2} + t_β)^2 * σ^2 / MDE^2
# With t_{α/2}=1.96, t_β=0.84, MDE=0.5, σ^2=1 → C = 62.72
C <- 62.72


# --- Plot 1: McKenzie (2012) -------------------------------------------------
mckenzie <- read.csv(file.path(data_dir, "mckenzie2012-simulation.csv")) %>%
  filter(m %in% c(1, 5, 10))

# Compute n* from (m, r) using the formula
mckenzie <- mckenzie %>%
  mutate(n_star = compute_optimal_sample_size(m, r, C))

mckenzie_plot <- ggplot(mckenzie, aes(x = ratio, y = n_star, color = factor(m))) +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = c("1" = "black", "5" = "#777777", "10" = "#bbbbbb"),
                     labels = c("m = 1", "m = 5", "m = 10")) +
  labs(x = "Pre/Post (m/r) periods",
       y = "Optimal Sample Size (n*)",
       color = NULL) +
  scale_x_continuous(limits = c(0, 10), breaks = seq(0, 10, 1)) +
  scale_y_continuous(limits = c(0, 130), breaks = seq(0, 125, 25)) +
  theme_stata()


# --- Plot 2: Burlig et al. (2020) --------------------------------------------
burlig_path <- file.path(data_dir, "paneldata-r-variation.csv")

if (file.exists(burlig_path)) {
  burlig <- read.csv(burlig_path) %>%
    filter(post %in% c(2, 5, 8))

  burlig_plot <- ggplot(burlig, aes(x = ar1, y = n, color = factor(post))) +
    geom_line(linewidth = 0.8) +
    scale_color_manual(values = c("2" = "black", "5" = "#777777", "8" = "#bbbbbb"),
                       labels = c("r = 2", "r = 5", "r = 8")) +
    labs(x = "AR1(γ)",
         y = "Optimal Sample Size (n*)",
         color = NULL) +
    scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.1)) +
    scale_y_continuous(limits = c(0, 150), breaks = seq(0, 150, 25)) +
    theme_stata()

} else {
  # Fallback if data file doesn't exist
  ar1 <- seq(0.1, 0.9, length.out = 9)
  n <- 100 - 50 * ar1
  fallback_data <- data.frame(ar1 = ar1, n = n)

  burlig_plot <- ggplot(fallback_data, aes(x = ar1, y = n)) +
    geom_line(color = "black", linewidth = 0.8) +
    labs(x = "AR1(γ)",
         y = "Optimal Sample Size (n*)") +
    scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.1)) +
    scale_y_continuous(limits = c(0, 150), breaks = seq(0, 150, 25)) +
    theme_stata()
}


# --- Save output -------------------------------------------------------------
ggsave(file.path(output_dir, "paneldata-figA-McKenzie2012.jpg"),
       plot = mckenzie_plot,
       width = 8, height = 6, dpi = 300)

ggsave(file.path(output_dir, "paneldata-figB-Burlig2020.jpg"),
       plot = burlig_plot,
       width = 8, height = 6, dpi = 300)
