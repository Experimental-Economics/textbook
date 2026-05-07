# =============================================================================
# Exhibit 5.3: Simple Rules of Thumb for Sample Size (Binary Outcomes)
# =============================================================================
# Computes the minimum sample size per group needed to detect a given Minimum
# Detectable Effect (MDE) for binary outcomes using Equation 5.9.
#
# Unlike continuous outcomes, sample size for binary outcomes depends on both
# the MDE level and p̄ (the average of control and treatment proportions).
# MDE is defined as (p₁ - p₀) / p₀, where p₀ and p₁ are the control and
# treatment proportions, respectively.
#
# Generates:
#   - Line plot showing sample size vs. p̄ for different MDE levels
#   - Heatmap showing required sample size for each (MDE, p̄) combination
#
# Reference: Chapter 5, Power Analysis

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(ggplot2)
library(dplyr)
library(latex2exp)
library(scales)
library(stringr)

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


# --- Parameters --------------------------------------------------------------
# Significance level and power
alpha <- 0.05  # Two-sided significance level
power <- 0.80  # Statistical power (1 - β)

# Critical values (using large df to approximate normal)
z_alpha_2 <- qt(1 - alpha / 2, df = 1e9)  # z_{α/2} for two-sided test
z_beta <- qt(power, df = 1e9)              # z_{β} for power calculation

# Parameter grid for analysis
mde_levels <- c(1/100, 1/50, 1/20, 1/10, 1/5, 1/3, 1/2)  # Relative MDE levels
p_bar_levels <- c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9)  # Average proportions


# --- Core function -----------------------------------------------------------
minimum_necessary_sample_size <- function(mde_level, p_bar) {
  #' Compute the minimum sample size *per group* needed to detect a given
  #' relative MDE at the specified average proportion (p_bar).
  #'
  #' @param mde_level Relative minimum detectable effect, defined as (p1 - p0) / p0
  #' @param p_bar Average proportion across treatment and control, (p0 + p1) / 2
  #' @return Required N per group, or NA when the implied p0 or p1 falls
  #'         outside [0, 1] (infeasible for a binary outcome)
  #'
  #' Based on Equation 5.9 in the textbook.

  # Derive p0 and p1 from the two-equation system:
  #   p_bar = (p0 + p1) / 2   and   mde_level = (p1 - p0) / p0
  p0 <- (2 * p_bar) / (2 + mde_level)
  p1 <- (2 * (1 + mde_level) * p_bar) / (2 + mde_level)

  # Feasibility check: ensure proportions are valid
  if (p1 > 1 || p0 < 0) return(NA)

  # Sample size per group (Equation 5.9)
  N <- (z_alpha_2 * sqrt(2 * p_bar * (1 - p_bar)) +
        z_beta * sqrt(p0 * (1 - p0) + p1 * (1 - p1)))^2 / (mde_level^2)
  return(N)
}


# --- Generate results --------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.3: Sample Size Rules of Thumb (Binary Outcomes)\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Significance level (α): %.2f (two-sided)\n", alpha))
cat(sprintf("Statistical power: %.0f%%\n", power * 100))
cat(sprintf("Critical values: z_α/2 = %.3f, z_β = %.3f\n", z_alpha_2, z_beta))
cat(strrep("-", 80), "\n", sep = "")
cat("Computing minimum sample size for every (p̄, MDE) combination...\n")

# Compute minimum sample size for every (p_bar, MDE) combination
results <- expand.grid(p_bar = p_bar_levels, mde = mde_levels)
results$min_sample_size <- mapply(
  minimum_necessary_sample_size,
  mde_level = results$mde,
  p_bar = results$p_bar
)
results$mde <- round(results$mde, 2)

# Count feasible and infeasible combinations
total_combinations <- nrow(results)
feasible_combinations <- sum(!is.na(results$min_sample_size))
infeasible_combinations <- sum(is.na(results$min_sample_size))

cat(sprintf("Total combinations: %d\n", total_combinations))
cat(sprintf("Feasible combinations: %d\n", feasible_combinations))
cat(sprintf("Infeasible combinations: %d (p₁ > 1 or p₀ < 0)\n", infeasible_combinations))
cat(strrep("=", 80), "\n", sep = "")


# --- Create line plot --------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("Creating line plot: Sample Size vs. p̄ for different MDE levels\n")
cat(strrep("=", 80), "\n", sep = "")

clean_results <- results %>% filter(!is.na(min_sample_size))

line_plot <- ggplot(clean_results,
                    aes(x = p_bar, y = min_sample_size,
                        color = factor(mde), group = mde)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Dark2", name = "MDE Level") +
  scale_x_continuous(breaks = p_bar_levels) +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(
    x = TeX("$\\bar{p}$"),
    y = "Minimum Sample Size (per group)",
    title = TeX("Minimum Sample Size vs. $\\bar{p}$ for Different MDE Levels")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

# Save line plot
lineplot_file <- file.path(output_dir, "lineplot_exh5.3_binary.pdf")
ggsave(lineplot_file, plot = line_plot, device = "pdf",
       width = 9, height = 6, units = "in")
cat(sprintf("✓ Line plot saved to: %s\n", lineplot_file))


# --- Create heatmap ----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("Creating heatmap: Required Sample Size by MDE and p̄\n")
cat(strrep("=", 80), "\n", sep = "")

# Prepare data: convert to factors for even tile spacing and format labels
results_plot <- transform(results,
                          mde = factor(mde),
                          p_bar = factor(p_bar))

results_plot$label <- vapply(results_plot$min_sample_size, function(x) {
  if (is.na(x)) return("")
  if (x >= 1000) return(format(round(x, 0), big.mark = ","))
  if (x >= 100) return(format(round(x, 1), nsmall = 1, big.mark = ","))
  if (x >= 10) return(format(round(x, 2), nsmall = 2, big.mark = ","))
  format(round(x, 3), nsmall = 3, big.mark = ",")
}, character(1))

# Caption
caption_text <- paste(
  "Each cell shows the minimum sample size per group needed to detect",
  "the corresponding MDE at the given level of p-bar, assuming a two-sided",
  "test with alpha = 0.05 and 80% power (Equation 5.9).",
  "MDE is defined as (p1 - p0) / p0, where p0 and p1 are the control and",
  "treatment proportions and p-bar = (p0 + p1) / 2.",
  "As p-bar approaches 0.5, the variance of the binary outcome is maximized,",
  "which increases the required sample size.",
  "Smaller MDEs also require larger samples, since detecting a subtler effect",
  "demands more statistical precision.",
  "Gray cells indicate infeasible combinations: the implied p1 would exceed 1",
  "or p0 would fall below 0, which is impossible for a binary outcome."
)

heatmap <- ggplot(results_plot,
                  aes(x = mde, y = p_bar, fill = min_sample_size)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = label), size = 3, color = "black") +
  scale_fill_gradient(
    low = "#dce6f7", high = "#1a3e82",
    na.value = "grey85",
    name = "Sample Size\n(per group)",
    labels = scales::label_comma()
  ) +
  labs(
    x = "MDE",
    y = TeX("$\\bar{p}$"),
    title = TeX("Required Sample Size by MDE and $\\bar{p}$ (Binary Outcomes)"),
    caption = str_wrap(caption_text, width = 110)
  ) +
  coord_equal() +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.caption = element_text(hjust = 0, size = 7, lineheight = 1.3,
                                color = "grey30", margin = margin(t = 10)),
    panel.grid = element_blank(),
    axis.ticks = element_blank(),
    legend.title = element_text(size = 9),
    legend.text = element_text(size = 8)
  )

# Save heatmap
heatmap_file <- file.path(output_dir, "heatmap_exh5.3_binary.pdf")
ggsave(heatmap_file, plot = heatmap, device = "pdf",
       width = 9, height = 7, units = "in")
cat(sprintf("✓ Heatmap saved to: %s\n", heatmap_file))


# --- Print summary statistics ------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.3: Summary Statistics (Binary Outcomes)\n")
cat(strrep("=", 80), "\n", sep = "")
cat("\nSample sizes at selected p̄ and MDE values:\n")
cat(sprintf("%-10s %-10s %30s\n", "p̄", "MDE", "Sample Size (per group)"))
cat(strrep("-", 80), "\n", sep = "")

# Show a few representative combinations
selected_combos <- list(
  c(0.5, 0.50),  # Mid-range p̄, large MDE
  c(0.5, 0.10),  # Mid-range p̄, small MDE
  c(0.1, 0.50),  # Low p̄, large MDE
  c(0.9, 0.50)   # High p̄, large MDE
)

for (combo in selected_combos) {
  p_bar <- combo[1]
  mde <- combo[2]
  n <- minimum_necessary_sample_size(mde, p_bar)
  if (is.na(n)) {
    cat(sprintf("%-10.1f %-10.2f %30s\n", p_bar, mde, "Infeasible"))
  } else {
    cat(sprintf("%-10.1f %-10.2f %30s\n", p_bar, mde,
                format(round(n, 1), nsmall = 1, big.mark = ",")))
  }
}

cat(strrep("=", 80), "\n", sep = "")
cat("\n")

# =============================================================================
# END OF EXHIBIT 5.3 (BINARY)
# =============================================================================
