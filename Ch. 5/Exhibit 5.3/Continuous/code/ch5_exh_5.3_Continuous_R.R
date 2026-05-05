# =============================================================================
# Exhibit 5.3: Simple Rules of Thumb for Sample Size (Continuous Outcomes)
# =============================================================================
# Computes the minimum sample size per group needed to detect a given Minimum
# Detectable Effect (MDE) for continuous outcomes using Equation 5.8:
#
# n = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2
#
# Assumes two-sided test with α = 0.05, power = 80%, and variance ratio = 1.
# Generates LaTeX and HTML tables showing required sample sizes for various
# MDE levels (in standard deviation units).
#
# Reference: Chapter 5, Power Analysis

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
library(MASS)

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

# Critical values
z_alpha_2 <- qnorm(1 - alpha / 2)  # z_{α/2} for two-sided test
z_beta <- qnorm(power)              # z_{β} for power calculation

# MDE levels to compute (in standard deviation units)
mde_levels <- c(1/50, 1/20, 1/10, 1/5, 1/3, 1/2, 1)


# --- Core function -----------------------------------------------------------
minimum_necessary_sample_size <- function(mde_level) {
  #' Compute the minimum sample size *per group* needed to detect a given MDE
  #' (in standard deviation units) for a continuous outcome.
  #'
  #' For continuous outcomes the variance ratio simplifies to 1, so Equation 5.8
  #' reduces to:  N = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2
  #'
  #' @param mde_level Minimum detectable effect in standard deviation units
  #' @return Required N per group

  2 * ((z_alpha_2 + z_beta) / mde_level)^2
}


# --- Generate results --------------------------------------------------------
# Calculate sample sizes for each MDE level
results <- data.frame(
  mde = mde_levels,
  mde_frac = sapply(mde_levels, function(x) as.character(fractions(x))),
  n_exact = sapply(mde_levels, minimum_necessary_sample_size),
  stringsAsFactors = FALSE
)
results$n_rounded <- ceiling(results$n_exact)


# --- Print results -----------------------------------------------------------
cat("\n", strrep("=", 80), "\n", sep = "")
cat("EXHIBIT 5.3: Sample Size Rules of Thumb (Continuous Outcomes)\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Significance level (α): %.2f (two-sided)\n", alpha))
cat(sprintf("Statistical power: %.0f%%\n", power * 100))
cat(sprintf("Critical values: z_α/2 = %.3f, z_β = %.3f\n", z_alpha_2, z_beta))
cat(strrep("-", 80), "\n", sep = "")
cat(sprintf("%-20s %30s\n", "MDE (SD units)", "Sample Size (per group)"))
cat(strrep("-", 80), "\n", sep = "")
for (i in 1:nrow(results)) {
  cat(sprintf("%-20s %20s ≈ %8s\n",
              results$mde_frac[i],
              format(round(results$n_exact[i], 1), nsmall = 1, big.mark = ","),
              format(results$n_rounded[i], big.mark = ",")))
}
cat(strrep("=", 80), "\n", sep = "")


# --- Build and save LaTeX table ----------------------------------------------
# Format one data row
format_row <- function(mde) {
  n <- minimum_necessary_sample_size(mde)
  sprintf("    \\footnotesize $%s$ & \\footnotesize %s $\\approx$ %s  \\\\",
          as.character(fractions(mde)),
          format(round(n, 1), nsmall = 1, big.mark = ","),
          format(ceiling(n), big.mark = ","))
}

# Build rows
body_lines <- c()
for (mde in mde_levels) {
  body_lines <- c(body_lines, format_row(mde), "    \\hline")
}

# Assemble full LaTeX table
header <- paste0(
  "\\begin{table}[h!]\n",
  "\\centering\n",
  "\\renewcommand{\\arraystretch}{1.6}\n",
  "\\begin{tabular}{|>{\\centering\\arraybackslash}m{7.2cm}|>{\\centering\\arraybackslash}m{5.4cm}|}\n",
  "    \\hline\n",
  "    \\multicolumn{2}{|>{\\centering\\arraybackslash}m{12.6cm}|}{%\n",
  "        \\textbf{\\normalsize Exhibit 5.3: Simple Rules of Thumb for Sample Size\n",
  "                 by Minimum Detectable Effect}} \\\\\n",
  "    \\hline\n",
  "    \\footnotesize\\textbf{\\textit{MDE} (in standard deviation units)} &\n",
  "    \\footnotesize\\textbf{\\textit{n} (per cell)} \\\\\n",
  "    \\hline"
)

footer <- paste0(
  "\n    \\multicolumn{2}{|>{\\centering\\arraybackslash}m{12.6cm}|}{%\n",
  "        \\scriptsize\\textit{Note:} Each row shows the minimum sample size per group\n",
  "        needed to detect the corresponding MDE (in standard deviation units), assuming\n",
  "        a two-sided test with $\\alpha = 0.05$ and 80\\% power.\n",
  "        Based on Equation~5.8: $n = 2\\left(\\frac{z_{\\alpha/2} + z_{\\beta}}\n",
  "        {\\textit{MDE}}\\right)^{2}$.} \\\\\n",
  "    \\hline\n",
  "\\end{tabular}\n",
  "\\end{table}"
)

latex_table <- paste0(header, "\n", paste(body_lines, collapse = "\n"), footer)

# Save LaTeX output
tex_file <- file.path(output_dir, "exhibit_5.3.tex")
writeLines(latex_table, con = tex_file)
cat(sprintf("\n✓ Saved LaTeX table to: %s\n", tex_file))


# --- Build and save HTML table -----------------------------------------------
# Build a simple styled HTML table
html_rows <- sapply(mde_levels, function(mde) {
  n <- minimum_necessary_sample_size(mde)
  mde_frac <- as.character(fractions(mde))
  n_str <- paste0(format(round(n, 1), nsmall = 1, big.mark = ","),
                  " ≈ ", format(ceiling(n), big.mark = ","))
  sprintf("      <tr><td>%s</td><td>%s</td></tr>", mde_frac, n_str)
})

html_content <- paste0(
  '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n',
  '<title>Exhibit 5.3</title>\n',
  '<style>\n',
  '    body { font-family: "Helvetica Neue", Arial, sans-serif; margin: 40px; color: #2c3e50; }\n',
  '    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }\n',
  '    table { border-collapse: collapse; margin: 20px auto; }\n',
  '    th { background-color: #1a3e82; color: white; padding: 10px 24px;\n',
  '         font-size: 13px; text-align: center; }\n',
  '    td { padding: 8px 24px; text-align: center; font-size: 13px;\n',
  '         border-bottom: 1px solid #ddd; }\n',
  '    tr:hover { background-color: #f0f4fb; }\n',
  '    .note { max-width: 600px; margin: 12px auto; font-size: 11px;\n',
  '            color: #666; text-align: center; line-height: 1.5; }\n',
  '</style>\n',
  '</head>\n<body>\n',
  '<h2>Exhibit 5.3: Simple Rules of Thumb for Sample Size<br>\n',
  'by Minimum Detectable Effect</h2>\n',
  '<table>\n',
  '    <thead>\n',
  '      <tr><th>MDE (in SD units)</th><th>n (per cell)</th></tr>\n',
  '    </thead>\n',
  '    <tbody>\n',
  paste(html_rows, collapse = "\n"), "\n",
  '    </tbody>\n',
  '</table>\n',
  '<p class="note"><em>Note:</em> Each row shows the minimum sample size per group ',
  'needed to detect the corresponding MDE (in standard deviation units), assuming ',
  'a two-sided test with α = 0.05 and 80% power. ',
  'Based on Equation 5.8: n = 2 · ((z<sub>α/2</sub> + z<sub>β</sub>) / MDE)².</p>\n',
  '</body>\n</html>'
)

html_file <- file.path(output_dir, "exhibit_5.3.html")
writeLines(html_content, con = html_file)
cat(sprintf("✓ Saved HTML table to: %s\n\n", html_file))

# =============================================================================
# END OF EXHIBIT 5.3 (CONTINUOUS)
# =============================================================================
