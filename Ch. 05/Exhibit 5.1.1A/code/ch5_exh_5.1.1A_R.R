# =============================================================================
# Exhibit 5.1.1A: Power Analysis with Varying Treatment Levels
# =============================================================================
# Simulates power analysis for varying treatment levels (dose-response) with
# binary outcomes. Treatment doses are drawn from a discrete uniform distribution
# over {0, 1, 2, 3, 4, 5}, and potential outcomes follow a logistic model:
#
# Y_i(d) ~ Bernoulli(p_i(d))
# p_i(d) = 1 / (1 + exp(−(−1.75 + 0.40·d + 0.05·d²)))
#
# The simulation verifies model recovery and estimates statistical power across
# different sample sizes.
#
# Reference: Chapter 5, Power Analysis

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(data.table)
library(ggplot2)
library(scales)
library(cowplot)
library(latex2exp)

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

# Set options
options(scipen = 999)
options(show.error.messages = TRUE)
options(show.error.locations = TRUE)
options(warn = 1)

# Set random seed for reproducibility
# Note: Uses L'Ecuyer-CMRG method for parallel RNG compatibility
RNGkind("L'Ecuyer-CMRG")
seed <- 52649583L
set.seed(seed)


# --- Parameters --------------------------------------------------------------
# Design inputs
N <- 10000L  # Size of overall population subject to randomization

# Treatment assignment: discrete uniform distribution over {0, 1, 2, 3, 4, 5}
support_of_treatment <- c(0L:5L)
treat_assign_probs <- rep((1 / length(support_of_treatment)),
                          length(support_of_treatment))

# Causal model parameters for potential outcomes
# Logistic model: p_i(d) = 1 / (1 + exp(-(-1.75 + 0.40*d + 0.05*d²)))
pref_intercept <- -1.75
pref_linear_loading <- 0.40
pref_quad_loading <- 0.05

# Simulation parameters
sample_sizes <- seq.int(from = 100L, to = 3000L, by = 100L)
iters_per_sample_size <- 1000L
print_progress <- TRUE
progress_step <- 100L


# --- Helper functions --------------------------------------------------------
makePotentialProb <- function(dose, intercept, linear_loading, quad_loading) {
  #' Calculate potential outcome probability for a given dose using logistic model.
  #'
  #' @param dose Treatment dose level
  #' @param intercept Intercept parameter (β₀)
  #' @param linear_loading Linear coefficient (β₁)
  #' @param quad_loading Quadratic coefficient (β₂)
  #' @return Probability p_i(d) = 1 / (1 + exp(-(β₀ + β₁*d + β₂*d²)))

  return(1 / (1 + exp(x = -(intercept + (linear_loading * dose) +
                              (quad_loading * (dose ^ 2))))))
}

rdiscuniform <- function(n, support, probs) {
  #' Generate random draws from discrete distribution with given support and probabilities.
  #'
  #' @param n Number of draws
  #' @param support Vector of possible values
  #' @param probs Probability of each value in support
  #' @return Vector of n random draws

  sample(x = support, size = n, replace = TRUE, prob = probs)
}

simulatePower <- function(sample_size_of_iteration, iter, iters_per_sample_size,
                          print_progress = FALSE, progress_step = 100L,
                          pref_intercept, pref_linear_loading, pref_quad_loading) {
  #' Run a single iteration of the power simulation for a given sample size.
  #'
  #' @param sample_size_of_iteration Number of subjects in this iteration
  #' @param iter Current iteration number
  #' @param iters_per_sample_size Total iterations per sample size
  #' @param print_progress Whether to print progress messages
  #' @param progress_step Print progress every N iterations
  #' @param pref_intercept Model intercept
  #' @param pref_linear_loading Model linear coefficient
  #' @param pref_quad_loading Model quadratic coefficient
  #' @return Data table with p-values for linear and quadratic coefficients

  # Design inputs
  support_of_treatment <- c(0L:5L)
  treat_assign_probs <- rep((1 / length(support_of_treatment)),
                            length(support_of_treatment))

  # Calculate potential probabilities for each dose level
  potential_prob_0 <- makePotentialProb(0, pref_intercept, pref_linear_loading, pref_quad_loading)
  potential_prob_1 <- makePotentialProb(1, pref_intercept, pref_linear_loading, pref_quad_loading)
  potential_prob_2 <- makePotentialProb(2, pref_intercept, pref_linear_loading, pref_quad_loading)
  potential_prob_3 <- makePotentialProb(3, pref_intercept, pref_linear_loading, pref_quad_loading)
  potential_prob_4 <- makePotentialProb(4, pref_intercept, pref_linear_loading, pref_quad_loading)
  potential_prob_5 <- makePotentialProb(5, pref_intercept, pref_linear_loading, pref_quad_loading)

  # Data construction for a single instance of size 'sample_size_of_iteration'
  sim_dt <- data.table(unit_id = seq_len(sample_size_of_iteration))
  sim_dt[, dose := rdiscuniform(n = sample_size_of_iteration,
                                support = support_of_treatment,
                                probs = treat_assign_probs)]
  sim_dt[, dose_squared := (dose * dose)]

  # Generate potential outcomes for each dose level: Y_i(d) ~ Bernoulli(p_i(d))
  sim_dt[, Y_0 := rbinom(n = .N, size = 1, prob = potential_prob_0)]
  sim_dt[, Y_1 := rbinom(n = .N, size = 1, prob = potential_prob_1)]
  sim_dt[, Y_2 := rbinom(n = .N, size = 1, prob = potential_prob_2)]
  sim_dt[, Y_3 := rbinom(n = .N, size = 1, prob = potential_prob_3)]
  sim_dt[, Y_4 := rbinom(n = .N, size = 1, prob = potential_prob_4)]
  sim_dt[, Y_5 := rbinom(n = .N, size = 1, prob = potential_prob_5)]

  # Observation equation: Y_i = sum_d Y_i(d) * 1[D_i = d]
  # Each subject reveals only the potential outcome corresponding to their assigned dose
  sim_dt[, observed_outcome :=
           as.integer(
             as.integer(dose == 0) * Y_0 +
               as.integer(dose == 1) * Y_1 +
               as.integer(dose == 2) * Y_2 +
               as.integer(dose == 3) * Y_3 +
               as.integer(dose == 4) * Y_4 +
               as.integer(dose == 5) * Y_5
           )]

  # Estimate logistic regression model
  result <- as.data.table(
    coef(summary(glm(data = sim_dt,
                     formula = observed_outcome ~ dose + dose_squared,
                     family = quasibinomial(link = "logit"))))[, 1:4],
    keep.rownames = TRUE
  )

  # Extract p-values for dose and dose-squared coefficients
  result <- result[rn %in% c("dose", "dose_squared")]
  gc()
  setnames(result, c("rn", "estimate", "se", "z_val", "p_val"))
  result[, sample_size := sample_size_of_iteration]
  result[, iteration := iter]

  result[rn == "dose", rn := "linear"]
  result[rn == "dose_squared", rn := "quadratic"]

  result <- result[, list(rn, sample_size, iteration, p_val)]

  if (print_progress == TRUE) {
    if ((iter %% progress_step) == 0) {
      cat(sprintf("Completed iteration %s (of %s) for sample size %s\n",
                  iter, iters_per_sample_size, sample_size_of_iteration))
    }
  }

  return(result)
}


# --- Initial demonstration ---------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.1.1A: Initial Model Verification (N = 10,000)\n")
cat(strrep("=", 80), "\n", sep = "")

# Calculate potential probabilities
potential_prob_0 <- makePotentialProb(0, pref_intercept, pref_linear_loading, pref_quad_loading)
potential_prob_1 <- makePotentialProb(1, pref_intercept, pref_linear_loading, pref_quad_loading)
potential_prob_2 <- makePotentialProb(2, pref_intercept, pref_linear_loading, pref_quad_loading)
potential_prob_3 <- makePotentialProb(3, pref_intercept, pref_linear_loading, pref_quad_loading)
potential_prob_4 <- makePotentialProb(4, pref_intercept, pref_linear_loading, pref_quad_loading)
potential_prob_5 <- makePotentialProb(5, pref_intercept, pref_linear_loading, pref_quad_loading)

# Data construction for a single instance of size N
sim_dt <- data.table(unit_id = seq_len(N))
sim_dt[, dose := rdiscuniform(n = N, support = support_of_treatment, probs = treat_assign_probs)]
sim_dt[, dose_squared := (dose * dose)]

# Generate potential outcomes
sim_dt[, Y_0 := rbinom(n = .N, size = 1, prob = potential_prob_0)]
sim_dt[, Y_1 := rbinom(n = .N, size = 1, prob = potential_prob_1)]
sim_dt[, Y_2 := rbinom(n = .N, size = 1, prob = potential_prob_2)]
sim_dt[, Y_3 := rbinom(n = .N, size = 1, prob = potential_prob_3)]
sim_dt[, Y_4 := rbinom(n = .N, size = 1, prob = potential_prob_4)]
sim_dt[, Y_5 := rbinom(n = .N, size = 1, prob = potential_prob_5)]

# Observation equation
sim_dt[, observed_outcome :=
         as.integer(
           as.integer(dose == 0) * Y_0 +
             as.integer(dose == 1) * Y_1 +
             as.integer(dose == 2) * Y_2 +
             as.integer(dose == 3) * Y_3 +
             as.integer(dose == 4) * Y_4 +
             as.integer(dose == 5) * Y_5
         )]

# Checking that we recover our assumed model coefficients (within confidence interval)
print(coef(summary(glm(data = sim_dt,
                       formula = observed_outcome ~ dose + dose_squared,
                       family = quasibinomial(link = "logit"))))[, 1:4])
cat(strrep("=", 80), "\n", sep = "")

# Clean up initial demonstration objects
sim_dt <- NULL
gc()


# --- Run power simulation ----------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.1.1A: Power Simulation\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Running %s iterations for each of %s sample sizes...\n",
            format(iters_per_sample_size, big.mark = ","),
            length(sample_sizes)))
cat(sprintf("Sample sizes: %s to %s (step: %s)\n",
            sample_sizes[1], sample_sizes[length(sample_sizes)],
            sample_sizes[2] - sample_sizes[1]))
cat(strrep("=", 80), "\n", sep = "")

# Create grid of function inputs
vector_function_inputs <- CJ(sample_size_of_iteration = sample_sizes,
                             iter = c(1L:iters_per_sample_size),
                             unique = TRUE,
                             sorted = FALSE)
sample_sizes_per_iteration <- vector_function_inputs$sample_size_of_iteration
iters <- vector_function_inputs$iter
rm(vector_function_inputs)
gc()

# Run the simulation across all sample sizes
simulation_results <-
  rbindlist(
    mapply(simulatePower,
           sample_sizes_per_iteration,
           iters,
           MoreArgs = list(iters_per_sample_size = copy(iters_per_sample_size),
                           print_progress = copy(print_progress),
                           progress_step = copy(progress_step),
                           pref_intercept = copy(pref_intercept),
                           pref_linear_loading = copy(pref_linear_loading),
                           pref_quad_loading = copy(pref_quad_loading)),
           SIMPLIFY = FALSE),
    use.names = TRUE
  )


# --- Calculate and save power results ----------------------------------------
# Calculate statistical power (fraction of iterations rejecting null hypothesis)
simulation_results[, reject_null := as.integer(p_val <= 0.05)]
simulation_results <-
  simulation_results[, list(fraction_correctly_rejecting = mean(reject_null)),
                     by = list(rn, sample_size)]
gc()

# Add legend labels
legend_label_linear_loading <- TeX(
  sprintf("Linear Coefficient ($\\beta_{1} = %s $)",
          format(pref_linear_loading, nsmall = 2))
)
legend_label_quadratic_loading <- TeX(
  sprintf("Quadratic Coefficient ($\\beta_{2} = %s $)",
          format(pref_quad_loading, nsmall = 2))
)

simulation_results[rn == "linear", rn_label := legend_label_linear_loading]
simulation_results[rn == "quadratic", rn_label := legend_label_quadratic_loading]

# Save results to CSV
csv_file <- file.path(output_dir, "simulation-result-dt.csv")
# Convert expression column to character for CSV output
simulation_results_csv <- copy(simulation_results)
simulation_results_csv[, rn_label := as.character(rn_label)]
fwrite(simulation_results_csv, csv_file)
cat(sprintf("\n✓ Power results saved to: %s\n", csv_file))


# --- Create power curve plot -------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("Creating power curve plot\n")
cat(strrep("=", 80), "\n", sep = "")

# Prep data for plotting
simulation_results[, rn_label := factor(rn_label,
                                        levels = c(legend_label_linear_loading,
                                                   legend_label_quadratic_loading))]

# Create model equation annotation
model_text_p_i <- "p_{i}\\left(\\beta_{0},\\beta_{1},\\beta_{2}, D_{i}\\right)"
model_text_log_odds <- sprintf("\\log\\,\\frac{%s}{1 - %s}",
                               model_text_p_i, model_text_p_i)
model_text <- TeX(
  sprintf("\\textbf{Model underlying simulation}: $\\; %s = %s + %s \\times D_{i} + %s \\times D^2_{i}$",
          model_text_log_odds,
          format(pref_intercept, nsmall = 2),
          format(pref_linear_loading, nsmall = 2),
          format(pref_quad_loading, nsmall = 2)),
  output = "character"
)

# Create the plot
sim_plot <-
  ggplot(data = simulation_results,
         aes(x = sample_size, y = fraction_correctly_rejecting, color = rn_label)) +
  geom_line(size = 1.2) +
  geom_hline(yintercept = 0.80, linetype = "dotted", show.legend = TRUE) +
  theme_bw(base_size = 9) +
  scale_y_continuous(breaks = (seq.int(from = 0, to = 100, by = 10)/100),
                     labels = number_format(accuracy = 0.01, big.mark = ","),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_x_continuous(breaks = seq.int(from = 0L, to = 3000L, by = 500L),
                     expand = expansion(mult = c(0.01, 0.02))) +
  labs(x = sprintf("Sample Size per Iteration (with %s iterations per sample size)",
                   format(iters_per_sample_size, scientific = FALSE, big.mark = ",")),
       y = TeX("Fraction of Iterations Correctly Rejecting the Null (${H}_{0}$)")) +
  scale_color_manual(values = c("#000000", "#B3B3B3"),
                     labels = parse_format()) +
  coord_cartesian(ylim = c(0, 1)) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_blank(),
        axis.text = element_text(size = 6.5),
        legend.position.inside = c(0.1985, 0.93),
        strip.text.x = element_blank(),
        strip.background = element_blank(),
        legend.background = element_rect(fill = "white", color = NA),
        legend.text = element_text(size = 7, hjust = 0),
        legend.title = element_blank(),
        legend.key = element_rect(NA),
        legend.spacing.y = unit(2, 'mm'),
        legend.key.height = unit(4, 'mm'),
        legend.key.width = unit(4, 'mm'),
        legend.margin = margin(t = 0, r = 0.1, b = 0.15, l = 0.1, unit = "cm")) +
  annotate(geom = "text", x = 1550, y = 0.075, label = model_text,
           parse = TRUE, na.rm = FALSE, size = 2.3, color = "#56B4E9")

# Save plot
plot_file <- file.path(output_dir, "simulation-result.png")
save_plot(plot = sim_plot, base_aspect_ratio = 1.7, filename = plot_file)
cat(sprintf("✓ Power curve plot saved to: %s\n", plot_file))


# --- Print summary statistics ------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.1.1A: Power Simulation Summary\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Total simulation runs: %s\n",
            format(nrow(simulation_results) * iters_per_sample_size, big.mark = ",")))
cat(sprintf("Sample sizes tested: %s\n", length(sample_sizes)))
cat(sprintf("Significance level (α): 0.05\n"))
cat("\nPower at selected sample sizes:\n")
cat(sprintf("%-15s %-25s %-25s\n", "Sample Size", "Linear (β₁)", "Quadratic (β₂)"))
cat(strrep("-", 80), "\n", sep = "")

# Show power at 5 evenly spaced sample sizes
indices <- c(1, length(sample_sizes) %/% 4, length(sample_sizes) %/% 2,
             3 * length(sample_sizes) %/% 4, length(sample_sizes))
for (idx in indices) {
  ss <- simulation_results[rn == "linear", sample_size][idx]
  power_lin <- simulation_results[rn == "linear" & sample_size == ss, fraction_correctly_rejecting]
  power_quad <- simulation_results[rn == "quadratic" & sample_size == ss, fraction_correctly_rejecting]
  cat(sprintf("%-15d %-25.3f %-25.3f\n", ss, power_lin, power_quad))
}
cat(strrep("=", 80), "\n", sep = "")
cat("\n")

# =============================================================================
# END OF EXHIBIT 5.1.1A
# =============================================================================
