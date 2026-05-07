# =============================================================================
# Exhibit 9.4: Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods
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
required_lib <- c("xtable")
invisible(lapply(required_lib, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  library(pkg, character.only = TRUE)
}))

# Define paths relative to script location
output_dir <- file.path(dirname(getwd()), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)


# --- Core function -----------------------------------------------------------
# Calculates optimal sample size using the formula for panel data designs.
#
# Inputs:
#   N_pre     : number of pre-treatment periods
#   N_post    : number of post-treatment periods
#   MDE       : minimum detectable effect in standard deviations
#   t_alpha_2 : critical value for two-tailed test at alpha/2
#   t_beta    : critical value for power (1 - beta)
#
# Returns:
#   Optimal sample size n* = 2(t_α/2 + t_β)²σ² / (MDE)² * (N_pre + N_post) / (N_pre * N_post)
#
# Assumes σ² = 1 (standardized).

calculate_n_star <- function(N_pre, N_post, MDE, t_alpha_2, t_beta) {
  numerator <- 2 * (t_alpha_2 + t_beta)^2 * (N_pre + N_post)
  denominator <- (MDE)^2 * N_pre * N_post
  return(numerator / denominator)
}


# --- Parameters --------------------------------------------------------------
MDE <- 0.5          # Standard deviations
t_alpha_2 <- 1.96   # For 95% confidence (two-tailed)
t_beta <- 0.84      # For 80% power


# --- Generate table data -----------------------------------------------------
results <- list()

for (total_periods in c(4, 8, 16)) {
  # Three allocation ratios for each total period count
  ratios <- list(
    c(total_periods %/% 4, 3 * total_periods %/% 4),  # 1/4 : 3/4
    c(total_periods %/% 2, total_periods %/% 2),      # 1/2 : 1/2
    c(3 * total_periods %/% 4, total_periods %/% 4)   # 3/4 : 1/4
  )

  ratio_strings <- c('1/4 : 3/4', '1/2 : 1/2', '3/4 : 1/4')

  for (i in 1:3) {
    N_pre <- ratios[[i]][1]
    N_post <- ratios[[i]][2]
    ratio_str <- ratio_strings[i]

    # Calculate n* using the formula
    n_star <- calculate_n_star(N_pre, N_post, MDE, t_alpha_2, t_beta)

    results[[length(results) + 1]] <- data.frame(
      `Total Number of Periods` = total_periods,
      `Pre-to-Post Ratio` = ratio_str,
      `n*` = round(n_star),
      check.names = FALSE
    )
  }
}

# Combine all results into a single dataframe
df <- do.call(rbind, results)
rownames(df) <- NULL

# Preview
cat("Exhibit 9.4: Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods\n\n")
print(df, row.names = FALSE)
cat("\nCalculated using formula with MDE = 0.5 SD, 95% confidence, 80% power\n")


# --- Save output -------------------------------------------------------------
tex_file <- file.path(output_dir, "Exhibit_9.4_r.tex")
print(
  xtable(df, digits = c(0, 0, 0, 0)),  # 0 decimals: (row names), col1, col2, col3
  file = tex_file,
  include.rownames = FALSE
)
cat(paste0("\nSaved to: ", tex_file, "\n"))
