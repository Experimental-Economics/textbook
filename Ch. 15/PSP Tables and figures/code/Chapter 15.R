# =============================================================================
# Chapter 15: Post-Study Probability (PSP) Tables and Figures
# Generates Exhibits 15.2, 15.3, 15.4, 15.5, 15.6, and 15.8
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


# =============================================================================
# EXHIBIT 15.2: PSP Across Different Priors
# =============================================================================
# PSP is calculated based on Equation 15.1 (Chapter 15)
# Reference: https://onlinelibrary.wiley.com/doi/epdf/10.1111/ecoj.12527 (pg 211)

# Computes Post-Study Probability for different prior values.
#
# Inputs:
#   beta  : Type II error rate (power = 1 - beta)
#   alpha : Significance level (Type I error rate)
#   pi    : Prior probability
#
# Returns:
#   Data frame with Prior, Power, Significance, True Null Rej,
#   False Null Rej, Total Null Rej, PSP
#
# Based on Equation 15.1.

compute_PSP_15_2 <- function(beta, alpha, pi) {
  result <- data.frame(
    "Prior" = pi,
    "Power" = 1 - beta,
    "Significance" = alpha,
    "True Null Rej" = (1 - beta) * pi,
    "False Null Rej" = alpha * (1 - pi),
    "Total Null Rej" = (1 - beta) * pi + alpha * (1 - pi),
    "PSP" = ((1 - beta) * pi) / ((1 - beta) * pi + alpha * (1 - pi)),
    check.names = FALSE
  )
  return(result)
}

# Parameters
beta <- 0           # power = 1 - beta = 1.0
alpha <- 0.05
pi <- c(0.0001, 0.001, 0.01, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5)

# Generate table
result_15_2 <- as.data.frame(t(sapply(pi, compute_PSP_15_2, beta = beta, alpha = alpha)))
cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("EXHIBIT 15.2: PSP Across Different Priors\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
print(result_15_2, digits = 4)
cat("\n")

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_15_2_r.tex")
print(xtable(result_15_2, digits = 4, caption = "PSP Across Different Priors",
             label = "tab:exhibit_15_2"), file = tex_file, include.rownames = FALSE)
cat(paste0("Saved to: ", tex_file, "\n\n"))


# =============================================================================
# EXHIBIT 15.3: PSP Changes with Power and Priors
# =============================================================================
# PSP is calculated based on Equation 15.1 (Chapter 15)
# Reference: https://onlinelibrary.wiley.com/doi/epdf/10.1111/ecoj.12527 (pg. 211)

# Computes PSP for different power levels and priors.
#
# Inputs:
#   beta  : Vector of Type II error rates
#   alpha : Significance level
#   pi    : Vector of prior probabilities
#
# Returns:
#   Data frame with Power column and PSP columns for each beta value
#
# Based on Equation 15.1.

compute_PSP_15_3 <- function(beta, alpha, pi) {
  result <- data.frame("Power" = pi, check.names = FALSE)

  for (i in seq_along(beta)) {
    col_name <- paste0("PSP_", sprintf("%.0f", beta[i] * 100))
    PSP <- ((1 - beta[i]) * pi) / ((1 - beta[i]) * pi + alpha * (1 - pi))
    result[, col_name] <- PSP
  }
  return(result)
}

# Parameters
beta <- c(0.2, 0.5)     # Power levels: 0.80 and 0.50
alpha <- 0.05
pi <- c(0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50)

# Generate table
result_15_3 <- compute_PSP_15_3(beta, alpha, pi)
cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("EXHIBIT 15.3: PSP Changes with Power and Priors\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
print(result_15_3, digits = 2)
cat("\n")

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_15_3_r.tex")
print(xtable(result_15_3, digits = 2, caption = "PSP Changes with Power and Priors",
             label = "tab:exhibit_15_3"), file = tex_file, include.rownames = FALSE)
cat(paste0("Saved to: ", tex_file, "\n\n"))


# =============================================================================
# EXHIBIT 15.4: PSP Across Different Levels of Significance, Power, and Priors
# =============================================================================
# PSP is calculated based on Equation 15.1 (Chapter 15)

# Computes PSP tables for different alpha levels.
#
# Inputs:
#   alpha_list : Vector of significance levels
#   power      : Vector of power values
#   pi         : Vector of prior probabilities
#
# Prints tables for each alpha level.
# Based on Equation 15.1.

compute_PSP_15_4 <- function(alpha_list, power, pi) {
  all_results <- list()
  for (k in 1:length(alpha_list)) {
    result <- matrix(NA, nrow = length(pi), ncol = length(power))
    for (j in 1:length(power)) {
      for (i in 1:length(pi)) {
        numerator <- (power[j] * pi[i])
        denominator <- (power[j] * pi[i]) + alpha_list[k] * (1 - pi[i])
        result[i, j] <- round(numerator / denominator, 2)
      }
    }

    colnames(result) <- sprintf("%.2f", power)
    rownames(result) <- sprintf("%.2f", pi)

    cat("\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat(sprintf("EXHIBIT 15.4: PSP at alpha = %.3f\n", alpha_list[k]))
    cat(paste(rep("=", 80), collapse = ""), "\n")
    print(result)
    cat("\n")

    all_results[[k]] <- list(alpha = alpha_list[k], data = result)
  }
  return(all_results)
}

# Parameters
pi <- c(0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50)
pow <- c(0.20, 0.30, 0.50, 0.70, 0.80)
alpha_list <- c(0.05, 0.005)

# Generate tables
results_15_4 <- compute_PSP_15_4(alpha_list, pow, pi)

# Save to LaTeX
for (result in results_15_4) {
  alpha_val <- result$alpha
  df <- as.data.frame(result$data)
  df <- cbind(Prior = rownames(df), df)
  rownames(df) <- NULL

  tex_file <- file.path(output_dir, sprintf("Exhibit_15_4_alpha_%.3f_r.tex", alpha_val))
  print(xtable(df, digits = 2, caption = sprintf("PSP at alpha = %.3f", alpha_val),
               label = sprintf("tab:exhibit_15_4_alpha_%.3f", alpha_val)),
        file = tex_file, include.rownames = FALSE)
  cat(paste0("Saved to: ", tex_file, "\n\n"))
}


# =============================================================================
# EXHIBIT 15.5: PSP With and Without a Statistically Significant Finding
# =============================================================================
# PSP(reject NULL) in top panel is derived from Equation 15.1 (Chapter 15)
# PSP(NULL) in bottom panel is derived from Equation 15.4 (Chapter 15)

# Computes PSP for both rejecting and not rejecting the null.
#
# Inputs:
#   alpha : Significance level
#   power : Vector of power values
#   pi    : Vector of prior probabilities
#
# Prints two tables:
#   - Panel 1: PSP(reject NULL) using Equation 15.1
#   - Panel 2: PSP(NULL) using Equation 15.4 (PSP = 1 - eq 15.4)

compute_PSP_15_5 <- function(alpha, power, pi) {
  all_results <- list()
  for (k in 1:2) {
    result <- matrix(NA, nrow = length(pi), ncol = length(power))
    for (j in 1:length(power)) {
      for (i in 1:length(pi)) {
        if (k == 1) {
          # PSP when rejecting null
          numerator <- (power[j] * pi[i])
          denominator <- (power[j] * pi[i]) + alpha * (1 - pi[i])
          result[i, j] <- round(numerator / denominator, 2)
        } else {
          # PSP when not rejecting null
          numerator <- (1 - alpha) * (1 - pi[i])
          denominator <- (1 - power[j]) * pi[i] + (1 - alpha) * (1 - pi[i])
          result[i, j] <- round(1 - numerator / denominator, 2)
        }
      }
    }
    colnames(result) <- sprintf("%.2f", power)
    rownames(result) <- sprintf("%.2f", pi)

    caption <- if (k == 1) "EXHIBIT 15.5: PSP(reject NULL)" else "EXHIBIT 15.5: PSP(NULL)"

    cat("\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat(caption, "\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    print(result)
    cat("\n")

    all_results[[k]] <- list(panel = k, data = result)
  }
  return(all_results)
}

# Parameters
pi <- c(0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.99)
pow <- c(0.20, 0.30, 0.50, 0.70, 0.80)
alpha <- 0.05

# Generate tables
results_15_5 <- compute_PSP_15_5(alpha, pow, pi)

# Save to LaTeX
for (result in results_15_5) {
  panel_name <- if (result$panel == 1) "reject_NULL" else "NULL"
  df <- as.data.frame(result$data)
  df <- cbind(Prior = rownames(df), df)
  rownames(df) <- NULL

  tex_file <- file.path(output_dir, sprintf("Exhibit_15_5_%s_r.tex", panel_name))
  print(xtable(df, digits = 2, caption = sprintf("PSP(%s)", panel_name),
               label = sprintf("tab:exhibit_15_5_%s", panel_name)),
        file = tex_file, include.rownames = FALSE)
  cat(paste0("Saved to: ", tex_file, "\n\n"))
}


# =============================================================================
# EXHIBIT 15.6: PSP Across Different Power, Stat Sig Level, Prior, and Number of Tests
# =============================================================================
# PSP is calculated based on Equation 15.5 (Chapter 15)
# Assumes n = i

# Computes PSP using binomial distribution for multiple tests.
#
# Inputs:
#   n     : Number of tests
#   i     : Number of successes (assumes n = i)
#   alpha : Significance level
#   beta  : Type II error rate
#   pi    : Vector of prior probabilities
#
# Returns:
#   Data frame with Prior and PSP columns for different i values
#
# Based on Equation 15.5.

compute_PSP_15_6 <- function(n, i, alpha, beta, pi) {
  result <- data.frame(
    "Prior" = pi,
    "i=0" = (pi * dbinom(i[1], n[1], 1 - beta)) / (pi * dbinom(i[1], n[1], 1 - beta) + (1 - pi) * dbinom(i[1], n[1], alpha)),
    "i=1" = (pi * dbinom(i[2], n[2], 1 - beta)) / (pi * dbinom(i[2], n[2], 1 - beta) + (1 - pi) * dbinom(i[2], n[2], alpha)),
    "i=2" = (pi * dbinom(i[3], n[3], 1 - beta)) / (pi * dbinom(i[3], n[3], 1 - beta) + (1 - pi) * dbinom(i[3], n[3], alpha)),
    "i=3" = (pi * dbinom(i[4], n[4], 1 - beta)) / (pi * dbinom(i[4], n[4], 1 - beta) + (1 - pi) * dbinom(i[4], n[4], alpha)),
    check.names = FALSE
  )
  return(result)
}

# Parameters
i <- c(1, 2, 3, 4)
n <- i
alpha <- 0.05
beta <- 0.2         # 1 - beta = 0.80
pi <- c(0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50)

# Generate tables for Power = 0.80
result_15_6_power_80 <- compute_PSP_15_6(n, i, alpha, beta, pi)
cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("EXHIBIT 15.6: PSP for Power = 0.80\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
print(result_15_6_power_80, digits = 2)
cat("\n")

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_15_6_power_0.80_r.tex")
print(xtable(result_15_6_power_80, digits = 2, caption = "PSP for Power = 0.80",
             label = "tab:exhibit_15_6_power_80"), file = tex_file, include.rownames = FALSE)
cat(paste0("Saved to: ", tex_file, "\n\n"))

# Generate tables for Power = 0.50
result_15_6_power_50 <- compute_PSP_15_6(n, i, alpha, beta = 0.5, pi)
cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("EXHIBIT 15.6: PSP for Power = 0.50\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
print(result_15_6_power_50, digits = 2)
cat("\n")

# Save to LaTeX
tex_file <- file.path(output_dir, "Exhibit_15_6_power_0.50_r.tex")
print(xtable(result_15_6_power_50, digits = 2, caption = "PSP for Power = 0.50",
             label = "tab:exhibit_15_6_power_50"), file = tex_file, include.rownames = FALSE)
cat(paste0("Saved to: ", tex_file, "\n\n"))


# =============================================================================
# EXHIBIT 15.8: PSP with Various Distance Levels
# =============================================================================
# PSP is calculated based on Equation 15.6 (Chapter 15)

# Computes PSP with different distance levels from null hypothesis.
#
# Inputs:
#   power    : Vector of power values
#   alpha    : Significance level
#   distance : Vector of distance values from null
#   pi       : Vector of prior probabilities
#
# Prints tables for each distance level.
# Based on Equation 15.6.

compute_PSP_15_8 <- function(power, alpha, distance, pi) {
  beta <- 1 - power
  all_results <- list()

  for (k in 1:length(distance)) {
    result <- matrix(NA, nrow = length(pi), ncol = length(power))

    for (j in 1:length(pi)) {
      for (i in 1:length(power)) {
        numerator <- (power[i] * pi[j]) + (beta[i] * pi[j] * distance[k])
        denominator <- (power[i] * pi[j]) + (beta[i] * pi[j] * distance[k]) + ((alpha + (1 - alpha) * distance[k]) * (1 - pi[j]))
        result[j, i] <- round(numerator / denominator, 2)
      }
    }

    colnames(result) <- sprintf("%.2f", power)
    rownames(result) <- sprintf("%.2f", pi)

    cat("\n")
    cat(paste(rep("=", 80), collapse = ""), "\n")
    cat(sprintf("EXHIBIT 15.8: PSP at Distance = %.2f\n", distance[k]))
    cat(paste(rep("=", 80), collapse = ""), "\n")
    print(result)
    cat("\n")

    all_results[[k]] <- list(distance = distance[k], data = result)
  }
  return(all_results)
}

# Parameters
alpha <- 0.05
distance <- c(0.00, 0.10, 0.25, 0.50)
power <- c(0.20, 0.30, 0.50, 0.70, 0.80)
pi <- c(0.01, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50)

# Generate tables
results_15_8 <- compute_PSP_15_8(power, alpha, distance, pi)

# Save to LaTeX
for (result in results_15_8) {
  dist_val <- result$distance
  df <- as.data.frame(result$data)
  df <- cbind(Prior = rownames(df), df)
  rownames(df) <- NULL

  tex_file <- file.path(output_dir, sprintf("Exhibit_15_8_distance_%.2f_r.tex", dist_val))
  print(xtable(df, digits = 2, caption = sprintf("PSP at Distance = %.2f", dist_val),
               label = sprintf("tab:exhibit_15_8_distance_%.2f", dist_val)),
        file = tex_file, include.rownames = FALSE)
  cat(paste0("Saved to: ", tex_file, "\n\n"))
}
