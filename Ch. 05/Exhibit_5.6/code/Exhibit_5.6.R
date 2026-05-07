# =============================================================================
# Exhibit 5.6: Simple Rules of Thumb for Sample Size (Clustered Units)
# =============================================================================
# Computes the optimal total number of participants (n*) and optimal number
# of clusters (k*) for cluster-randomized designs using Equation 5.12:
#
# n* = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2 * (1 + (m - 1) * ρ)
#
# where m is the cluster size and ρ is the intra-cluster correlation (ICC).
# The design effect (1 + (m - 1) * ρ) inflates the required sample size
# relative to individual randomization.
#
# Generates LaTeX and HTML tables showing required sample sizes for various
# combinations of cluster size (m) and ICC (ρ).
#
# Reference: Chapter 5, Power Analysis

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

# Define paths relative to script location
output_dir <- file.path(dirname(getwd()), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)


# --- Parameters --------------------------------------------------------------
# Significance level and power
alpha <- 0.05  # Two-sided significance level
power <- 0.80  # Statistical power (1 - β)
MDE <- 0.5     # Minimum detectable effect (in SD units)
sigma <- 1.0   # Standard deviation

# Critical values
z_alpha_2 <- qnorm(1 - alpha / 2)  # z_{α/2} for two-sided test
z_beta <- qnorm(power)              # z_{β} for power calculation

# Parameter grid
rho_values <- c(0, 0.25, 0.50, 0.75, 1.0)  # Intra-cluster correlation (ICC)
cluster_sizes <- c(10, 30)                  # Individuals per cluster (m)


# --- Core function -----------------------------------------------------------
optimal_participants <- function(m, rho) {
  #' Compute the optimal total number of participants (n*) for a clustered
  #' experiment using Equation 5.12 from the textbook:
  #'
  #'   n* = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2 * (1 + (m - 1) * rho)
  #'
  #' @param m Number of individuals per cluster
  #' @param rho Intra-cluster correlation coefficient (ICC)
  #' @return Optimal total number of participants (n*)

  2 * ((z_alpha_2 + z_beta) / MDE)^2 * sigma^2 * (1 + (m - 1) * rho)
}


# --- Generate results --------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.6: Sample Size Rules of Thumb (Clustered Units)\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Significance level (α): %.2f (two-sided)\n", alpha))
cat(sprintf("Statistical power: %.0f%%\n", power * 100))
cat(sprintf("Minimum detectable effect (MDE): %.1f SD units\n", MDE))
cat(sprintf("Critical values: z_α/2 = %.3f, z_β = %.3f\n", z_alpha_2, z_beta))
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("%-10s %-20s %-25s %-20s\n", "ρ (ICC)", "m (cluster size)",
            "n* (participants)", "k* (clusters)"))
cat(strrep("-", 80), "\n", sep = "")

# Calculate and display results for each combination
for (rho in rho_values) {
  for (m in cluster_sizes) {
    n_star <- optimal_participants(m, rho)
    k_star <- n_star / m
    cat(sprintf("%-10.2f %-20d %-25s %-20s\n",
                rho, m,
                format(round(n_star, 2), nsmall = 2, big.mark = ","),
                format(round(k_star, 2), nsmall = 2, big.mark = ",")))
  }
}

cat(strrep("=", 80), "\n", sep = "")


# --- Build and save LaTeX table ----------------------------------------------
# Format the two-row block for each rho (one sub-row per cluster size m)
format_rho_block <- function(rho) {
  lines <- c()
  for (i in seq_along(cluster_sizes)) {
    m <- cluster_sizes[i]
    n_star <- optimal_participants(m, rho)
    k_star <- n_star / m

    n_str <- sprintf("%s $\\approx$ %s",
                     format(round(n_star, 2), nsmall = 2, big.mark = ","),
                     format(ceiling(n_star), big.mark = ","))
    k_str <- sprintf("%s $\\approx$ %s",
                     format(round(k_star, 2), nsmall = 2, big.mark = ","),
                     format(ceiling(k_star), big.mark = ","))

    if (i == 1) {
      # First sub-row: includes the multirow rho label
      lines <- c(lines, sprintf(
        "    \\multirow{2}{*}{%g}  &  %d & %s & %s \\\\ \\cline{2-4}",
        rho, m, n_str, k_str))
    } else {
      # Second sub-row: rho cell is merged, so leave it blank
      lines <- c(lines, sprintf(
        "    & %d & %s & %s \\\\",
        m, n_str, k_str))
    }
  }
  lines <- c(lines, "    \\hline")
  paste(lines, collapse = "\n")
}

# Header
header <- paste0(
  "\\begin{table}[h!]\n",
  "\\centering\n",
  "\\renewcommand{\\arraystretch}{2}\n",
  "\\begin{tabular}{|>{\\centering\\arraybackslash}m{1.6cm}|>{\\centering\\arraybackslash}m{2.0cm}|>{\\centering\\arraybackslash}m{5.0cm}|>{\\centering\\arraybackslash}m{5.0cm}|}\n",
  "    \\hline\n",
  "    \\multicolumn{4}{|>{\\centering\\arraybackslash}m{13.6cm}|}{%\n",
  "        \\textbf{Exhibit 5.6: Simple Rules of Thumb for Sample Size\n",
  "                 for Clustered Units}} \\\\\n",
  "    \\hline\n",
  "    {$\\boldsymbol{\\rho}$} & {$\\mathbf{m}$} & {$\\mathbf{n^{*}}$} & {$\\mathbf{k^{*}}$} \\\\\n",
  "    \\hline"
)

# Data rows
body_blocks <- sapply(rho_values, format_rho_block)

# Footer with caption
footer <- paste0(
  "\n    \\multicolumn{4}{|>{\\centering\\arraybackslash}m{13.6cm}|}{%\n",
  "        \\scriptsize\\textit{Note:} $n^{*}$ is the optimal total number of\n",
  "        participants and $k^{*} = n^{*}/m$ is the optimal number of clusters,\n",
  "        each of size $m$. Assumes a two-sided test with $\\alpha = 0.05$,\n",
  "        80\\% power, MDE $ = 0.5\\sigma$, and intra-cluster correlation $\\rho$.\n",
  "        Based on Equation~5.12.} \\\\\n",
  "    \\hline\n",
  "\\end{tabular}\n",
  "\\end{table}"
)

latex_table <- paste0(header, "\n", paste(body_blocks, collapse = "\n"), footer)

# Save LaTeX output
tex_file <- file.path(output_dir, "exhibit_5.6.tex")
writeLines(latex_table, con = tex_file)
cat(sprintf("\n✓ Saved LaTeX table to: %s\n", tex_file))


# --- Build and save HTML table -----------------------------------------------
# Build HTML rows with rowspan for rho
tbody_lines <- c()
for (rho in rho_values) {
  for (i in seq_along(cluster_sizes)) {
    m <- cluster_sizes[i]
    n_star <- optimal_participants(m, rho)
    k_star <- n_star / m

    n_str <- sprintf("%s ≈ %s",
                     format(round(n_star, 2), nsmall = 2, big.mark = ","),
                     format(ceiling(n_star), big.mark = ","))
    k_str <- sprintf("%s ≈ %s",
                     format(round(k_star, 2), nsmall = 2, big.mark = ","),
                     format(ceiling(k_star), big.mark = ","))

    cls <- if (i == 1) ' class="group-top"' else ""
    rho_cell <- if (i == 1) sprintf('<td rowspan="2">%g</td>', rho) else ""

    tbody_lines <- c(tbody_lines, sprintf(
      '      <tr%s>%s<td>%d</td><td>%s</td><td>%s</td></tr>',
      cls, rho_cell, m, n_str, k_str))
  }
}

html_content <- paste0(
  '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n',
  '<title>Exhibit 5.6</title>\n',
  '<style>\n',
  '    body { font-family: "Helvetica Neue", Arial, sans-serif; margin: 40px; color: #2c3e50; }\n',
  '    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }\n',
  '    table { border-collapse: collapse; margin: 20px auto; }\n',
  '    th { background-color: #1a3e82; color: white; padding: 10px 20px;\n',
  '         font-size: 13px; text-align: center; }\n',
  '    td { padding: 8px 20px; text-align: center; font-size: 13px;\n',
  '         border-bottom: 1px solid #ddd; }\n',
  '    tr:hover { background-color: #f0f4fb; }\n',
  '    .group-top td { border-top: 2px solid #999; }\n',
  '    .note { max-width: 650px; margin: 12px auto; font-size: 11px;\n',
  '            color: #666; text-align: center; line-height: 1.5; }\n',
  '</style>\n',
  '</head>\n<body>\n',
  '<h2>Exhibit 5.6: Simple Rules of Thumb for Sample Size<br>\n',
  'for Clustered Units</h2>\n',
  '<table>\n',
  '    <thead>\n',
  '      <tr><th>ρ</th><th>m</th><th>n*</th><th>k*</th></tr>\n',
  '    </thead>\n',
  '    <tbody>\n',
  paste(tbody_lines, collapse = "\n"), "\n",
  '    </tbody>\n',
  '</table>\n',
  '<p class="note"><em>Note:</em> n* is the optimal total number of ',
  'participants and k* = n*/m is the optimal number of clusters, each of ',
  'size m. Assumes a two-sided test with α = 0.05, 80% power, ',
  'MDE = 0.5σ, and intra-cluster correlation ρ. ',
  'Based on Equation 5.12.</p>\n',
  '</body>\n</html>'
)

# Save HTML output
html_file <- file.path(output_dir, "exhibit_5.6.html")
writeLines(html_content, con = html_file)
cat(sprintf("✓ Saved HTML table to: %s\n\n", html_file))

# =============================================================================
# END OF EXHIBIT 5.6
# =============================================================================
