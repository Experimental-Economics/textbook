# =============================================================================
# Exhibit 5.7: Multiple Hypothesis Testing (MHT) and Statistical Power
# =============================================================================
# Demonstrates how sample size requirements grow with the number of hypothesis
# tests when using Bonferroni corrections to control family-wise error rates.
#
# Three correction strategies are compared:
#   1. No Adjustment: Standard α and power (ignores multiple testing)
#   2. FWE Adjustment: α/k (Bonferroni correction for family-wise error)
#   3. FWE + FWP Adjustment: α/k AND power^(1/k) (controls both error rates)
#
# Shows that detecting multiple effects requires substantially larger samples,
# especially when controlling both family-wise error and family-wise power.
#
# Reference: Chapter 5, Power Analysis

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(ggplot2)
library(pwr)

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

# Set random seed for reproducibility
set.seed(52649583)


# --- Parameters --------------------------------------------------------------
# Design inputs
mde_sds <- 0.5    # Effect size in standard deviation units
alpha <- 0.05     # Significance level (uncorrected)
power <- 0.80     # Statistical power (uncorrected)
max_hypo <- 10    # Maximum number of hypothesis tests to consider


# --- Core function -----------------------------------------------------------
compute_sample_sizes <- function(mde, alpha, power, n_tests) {
  #' Compute required sample size per group for 1..n_tests hypotheses under
  #' three Bonferroni-based correction strategies:
  #'
  #'   - No Adjustment:        standard alpha and power
  #'   - FWE Adjustment:       alpha / k  (controls family-wise error rate)
  #'   - FWE + FWP Adjustment: alpha / k  and  power^(1/k)
  #'                           (controls both family-wise error and power)
  #'
  #' @param mde Effect size in SD units
  #' @param alpha Significance level
  #' @param power Target statistical power
  #' @param n_tests Maximum number of hypotheses
  #' @return Data frame with sample sizes for each strategy

  hypotheses <- 1:n_tests

  no_adj <- sapply(hypotheses, function(k) {
    pwr.t.test(d = mde, sig.level = alpha, power = power,
               type = "two.sample")$n
  })

  fwe <- sapply(hypotheses, function(k) {
    pwr.t.test(d = mde, sig.level = alpha / k, power = power,
               type = "two.sample")$n
  })

  fwe_fwp <- sapply(hypotheses, function(k) {
    pwr.t.test(d = mde, sig.level = alpha / k, power = power^(1 / k),
               type = "two.sample")$n
  })

  data.frame(
    hypotheses = rep(hypotheses, 3),
    total_sample_size = c(no_adj, fwe, fwe_fwp),
    adjustment_type = factor(
      rep(c("No Adjustment", "FWE Adjustment", "FWE + FWP Adjustment"),
          each = n_tests),
      levels = c("No Adjustment", "FWE Adjustment", "FWE + FWP Adjustment"))
  )
}


# --- Compute results ---------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.7: Multiple Hypothesis Testing and Statistical Power\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Effect size (MDE): %.1f SD units\n", mde_sds))
cat(sprintf("Significance level (α): %.2f\n", alpha))
cat(sprintf("Statistical power: %.0f%%\n", power * 100))
cat(sprintf("Number of hypothesis tests: 1 to %d\n", max_hypo))
cat(strrep("-", 80), "\n", sep = "")
cat("Computing required sample sizes for each correction strategy...\n")

results <- compute_sample_sizes(mde_sds, alpha, power, max_hypo)

cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("%-12s %-18s %-18s %-18s\n", "k (tests)", "No Adjustment",
            "FWE Adjustment", "FWE + FWP"))
cat(strrep("-", 80), "\n", sep = "")

# Print results
for (k in 1:max_hypo) {
  no_adj <- results[results$hypotheses == k & results$adjustment_type == "No Adjustment",
                    "total_sample_size"]
  fwe <- results[results$hypotheses == k & results$adjustment_type == "FWE Adjustment",
                 "total_sample_size"]
  fwe_fwp <- results[results$hypotheses == k & results$adjustment_type == "FWE + FWP Adjustment",
                     "total_sample_size"]
  cat(sprintf("%-12d %-18.1f %-18.1f %-18.1f\n", k, no_adj, fwe, fwe_fwp))
}

cat(strrep("=", 80), "\n", sep = "")


# --- Create plot -------------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("Creating plot: Sample Size vs. Number of Hypothesis Tests\n")
cat(strrep("=", 80), "\n", sep = "")

exhibit_plot <- ggplot(results,
                       aes(x = hypotheses, y = total_sample_size,
                           color = adjustment_type)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:max_hypo,
                     expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous(breaks = seq(50, 200, by = 25),
                     labels = scales::label_comma(),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_color_manual(values = c("No Adjustment" = "#CCCCCC",
                                "FWE Adjustment" = "#999999",
                                "FWE + FWP Adjustment" = "#000000")) +
  coord_cartesian(ylim = c(50, 200)) +
  labs(x = "Number of Outcomes / Hypothesis Tests per Experimental Unit",
       y = "Total Sample Size Required (Given Inputs)") +
  theme_bw(base_size = 10) +
  theme(
    panel.grid = element_blank(),
    legend.position = c(0.17, 0.90),
    legend.title = element_blank(),
    legend.background = element_rect(fill = "white", color = NA),
    legend.text = element_text(size = 8),
    legend.key = element_rect(fill = NA),
    legend.spacing.y = unit(2, "mm"),
    legend.key.height = unit(4, "mm"),
    legend.key.width = unit(4, "mm"),
    legend.margin = margin(t = 0, r = 1, b = 1, l = 1, unit = "mm")
  )

# Save plot
plot_file <- file.path(output_dir, "exhibit_5.7.png")
ggsave(plot_file, plot = exhibit_plot, width = 10, height = 7, units = "in", dpi = 300)
cat(sprintf("✓ Plot saved to: %s\n", plot_file))


# --- Print summary statistics ------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.7: Summary\n")
cat(strrep("=", 80), "\n", sep = "")

# Sample size inflation from 1 to max_hypo tests
no_adj_1 <- results[results$hypotheses == 1 & results$adjustment_type == "No Adjustment",
                    "total_sample_size"]
no_adj_max <- results[results$hypotheses == max_hypo & results$adjustment_type == "No Adjustment",
                      "total_sample_size"]
fwe_1 <- results[results$hypotheses == 1 & results$adjustment_type == "FWE Adjustment",
                 "total_sample_size"]
fwe_max <- results[results$hypotheses == max_hypo & results$adjustment_type == "FWE Adjustment",
                   "total_sample_size"]
fwe_fwp_1 <- results[results$hypotheses == 1 & results$adjustment_type == "FWE + FWP Adjustment",
                     "total_sample_size"]
fwe_fwp_max <- results[results$hypotheses == max_hypo & results$adjustment_type == "FWE + FWP Adjustment",
                       "total_sample_size"]

cat(sprintf("\nSample size inflation from 1 to %d tests:\n", max_hypo))
cat(sprintf("  No Adjustment:       %.1f → %.1f (%.2fx)\n",
            no_adj_1, no_adj_max, no_adj_max / no_adj_1))
cat(sprintf("  FWE Adjustment:      %.1f → %.1f (%.2fx)\n",
            fwe_1, fwe_max, fwe_max / fwe_1))
cat(sprintf("  FWE + FWP:           %.1f → %.1f (%.2fx)\n",
            fwe_fwp_1, fwe_fwp_max, fwe_fwp_max / fwe_fwp_1))
cat("\nKey insight: Testing multiple hypotheses with proper error rate control\n")
cat("requires substantially larger samples, especially when controlling both\n")
cat("family-wise error (FWE) and family-wise power (FWP).\n")
cat(strrep("=", 80), "\n", sep = "")
cat("\n")

# =============================================================================
# END OF EXHIBIT 5.7
# =============================================================================
