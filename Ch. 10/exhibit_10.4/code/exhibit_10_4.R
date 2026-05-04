# =============================================================================
# Exhibit 10.4: Power Analysis - Within vs. Between Subjects Designs
# =============================================================================
# Conducts Monte Carlo simulation to compare statistical power between
# within-subjects and between-subjects experimental designs.
#
# Data generating process (Equation 10.4):
# Y_it = π₀ + τ*D_it + μ_i + ε_it
#
# Where:
# - Y_it: Outcome for individual i at time t
# - π₀: Baseline mean
# - τ: Treatment effect (varies: 0.05, 0.10, 0.15)
# - D_it: Treatment indicator
# - μ_i: Individual fixed effect (constant across time)
# - ε_it: Random error
#
# Reference: Chapter 10, Experimental Design

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(tidyverse)
library(parallel)

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
output_dir <- file.path(dirname(getwd()), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Set random seed for replication
set.seed(123)


# --- Parameters --------------------------------------------------------------
treatment_effects <- c(0.05, 0.10, 0.15)
baseline_mean <- 0.37
individual_sd <- sqrt(0.09)
error_sd <- sqrt(0.02)
time_periods <- 2
sample_sizes <- 10:400
n_iterations <- 1000
alpha_level <- 0.05
n_cores <- detectCores()


# --- Functions ---------------------------------------------------------------
assign_treatment <- function(design, dataframe) {
  # Assign treatment based on design
  #
  # Parameters:
  # - design: "WS" or "BS"
  # - dataframe: DataFrame with columns 'i' and 't'
  #
  # Returns:
  # - dataframe: DataFrame with added 'D' column

  # Shuffle data
  dataframe <- dataframe[sample(nrow(dataframe)), ]

  # Get unique subjects after shuffling
  unique_subjects <- unique(dataframe$i)
  n_half <- length(unique_subjects) %/% 2
  first_half <- unique_subjects[1:n_half]

  if (design == "WS") {
    # First half: treated in period 0
    # Second half: treated in period 1
    dataframe$D <- as.integer(
      (dataframe$i %in% first_half & dataframe$t == 0) |
      (!dataframe$i %in% first_half & dataframe$t == 1)
    )
  } else if (design == "BS") {
    # First half: always treated
    # Second half: never treated
    dataframe$D <- as.integer(dataframe$i %in% first_half)
  }

  # Sort by i and t
  dataframe <- dataframe[order(dataframe$i, dataframe$t), ]

  return(dataframe)
}


generate_data <- function(baseline, treatment_effect, individual_sd, error_sd,
                          n_subjects, n_periods, design) {
  # Generate simulated data following Equation 10.4
  #
  # Y_it = π₀ + τ*D_it + μ_i + ε_it
  #
  # Parameters:
  # - baseline: Baseline mean (π₀)
  # - treatment_effect: Treatment effect (τ)
  # - individual_sd: Standard deviation of individual effects (μ_i)
  # - error_sd: Standard deviation of random errors (ε_it)
  # - n_subjects: Number of subjects
  # - n_periods: Number of time periods
  # - design: "WS" or "BS"
  #
  # Returns:
  # - dataframe: DataFrame with columns i, t, D, mu, epsilon, Y

  # Create panel structure
  data <- expand.grid(
    i = 1:n_subjects,
    t = 0:(n_periods - 1)
  )

  # Assign treatment based on design
  data <- assign_treatment(design, data)

  # Generate individual fixed effects (constant within subject)
  individual_effects <- rnorm(n_subjects, 0, individual_sd)
  data$mu <- individual_effects[data$i]

  # Generate random errors
  data$epsilon <- rnorm(n_subjects * n_periods, 0, error_sd)

  # Generate outcome: Y_it = π₀ + τ*D_it + μ_i + ε_it
  data$Y <- baseline + treatment_effect * data$D + data$mu + data$epsilon

  return(data)
}


test_significance <- function(dataframe, design, alpha = alpha_level) {
  # Test whether treatment effect is statistically significant
  #
  # Parameters:
  # - dataframe: DataFrame with columns i, t, D, Y
  # - design: "WS" or "BS"
  # - alpha: Significance level (default: 0.05)
  #
  # Returns:
  # - is_significant: Boolean indicating if p-value < alpha

  if (design == "WS") {
    # Within-subjects: demean to remove individual fixed effects
    dataframe <- dataframe %>%
      group_by(i) %>%
      mutate(
        D_demeaned = D - mean(D),
        Y_demeaned = Y - mean(Y)
      ) %>%
      ungroup()

    # Check for variation in treatment
    if (length(unique(dataframe$D_demeaned)) <= 1) {
      return(FALSE)
    }

    # Run regression
    model <- lm(Y_demeaned ~ D_demeaned - 1, data = dataframe)
    p_value <- summary(model)$coefficients["D_demeaned", "Pr(>|t|)"]

  } else if (design == "BS") {
    # Between-subjects: standard regression
    # Check for variation in treatment
    if (length(unique(dataframe$D)) <= 1) {
      return(FALSE)
    }

    # Run regression
    model <- lm(Y ~ D, data = dataframe)
    p_value <- summary(model)$coefficients["D", "Pr(>|t|)"]
  }

  return(p_value < alpha)
}


run_single_iteration <- function(params) {
  # Run single simulation iteration (for parallel processing)
  #
  # Parameters:
  # - params: List with baseline, treatment_effect, individual_sd, error_sd,
  #           n_subjects, n_periods, design
  #
  # Returns:
  # - is_significant: Boolean

  # Generate data
  data <- generate_data(
    params$baseline,
    params$treatment_effect,
    params$individual_sd,
    params$error_sd,
    params$n_subjects,
    params$n_periods,
    params$design
  )

  # Test significance
  return(test_significance(data, params$design))
}


# --- Run simulation ----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 10.4: Power Analysis - Within vs. Between Subjects Designs\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Using %d CPU cores for parallel processing\n\n", n_cores))

# Initialize storage for results
results <- list(
  WS = setNames(vector("list", length(treatment_effects)), treatment_effects),
  BS = setNames(vector("list", length(treatment_effects)), treatment_effects)
)

# Loop over treatment effects
for (treatment_effect in treatment_effects) {
  cat(sprintf("\nTreatment Effect τ = %.2f\n", treatment_effect))
  cat(strrep("-", 80), "\n", sep = "")

  # Loop over sample sizes
  for (n_subjects in sample_sizes) {

    # Loop over designs
    for (design in c("WS", "BS")) {
      cat(sprintf("  Design: %s | N = %3d\n", design, n_subjects))

      # Create parameter list for all iterations
      params_list <- lapply(1:n_iterations, function(x) list(
        baseline = baseline_mean,
        treatment_effect = treatment_effect,
        individual_sd = individual_sd,
        error_sd = error_sd,
        n_subjects = n_subjects,
        n_periods = time_periods,
        design = design
      ))

      # Run iterations in parallel
      results_list <- mclapply(
        params_list,
        run_single_iteration,
        mc.cores = n_cores,
        mc.set.seed = TRUE
      )

      # Calculate power
      significant_count <- sum(unlist(results_list))
      power <- significant_count / n_iterations

      # Store results
      tau_str <- as.character(treatment_effect)
      results[[design]][[tau_str]] <- c(results[[design]][[tau_str]], power)
    }
  }
}


# --- Create plot -------------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("Creating power curves...\n")
cat(strrep("=", 80), "\n", sep = "")

# Prepare data for plotting
plot_data <- data.frame()
for (design in c("WS", "BS")) {
  for (treatment_effect in treatment_effects) {
    tau_str <- as.character(treatment_effect)
    plot_data <- rbind(plot_data, data.frame(
      sample_size = sample_sizes,
      power = results[[design]][[tau_str]],
      treatment_effect = treatment_effect,
      design = design
    ))
  }
}

# Create plot
power_plot <- ggplot(plot_data, aes(x = sample_size, y = power, color = design)) +
  geom_line(linewidth = 1) +
  facet_wrap(~ treatment_effect, labeller = label_bquote(tau == .(treatment_effect))) +
  geom_hline(yintercept = 0.8, linetype = "dashed", color = "gray", alpha = 0.5) +
  scale_color_manual(
    name = "Design",
    values = c("WS" = "blue", "BS" = "red"),
    labels = c("WS" = "Within-Subjects (WS)", "BS" = "Between-Subjects (BS)")
  ) +
  labs(
    x = "Number of Subjects",
    y = "Statistical Power",
    title = "Exhibit 10.4: Power Analysis - Within vs. Between Subjects Designs"
  ) +
  xlim(0, 400) +
  ylim(0, 1) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5)
  )

# Save figure
output_file <- file.path(output_dir, "exhibit_10_4.png")
ggsave(output_file, plot = power_plot, width = 14, height = 4, units = "in", dpi = 400)

cat("\nSaved to:", output_file, "\n")
cat(strrep("=", 80), "\n", sep = "")

# =============================================================================
# END OF EXHIBIT 10.4
# =============================================================================
