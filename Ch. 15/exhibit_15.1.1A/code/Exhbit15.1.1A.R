# =============================================================================
# Exhibit 15.1.1A: PSP as a Function of Number of Replications
# Generates two-panel figure showing PSP under different replication scenarios
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

# Define paths relative to script location
output_dir <- file.path(dirname(getwd()), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)


# --- Parameters --------------------------------------------------------------
alpha <- 0.05
n     <- 10
v     <- 0.3
omega <- 0.4
pi0   <- 0.5
phi   <- 0.33
psi   <- 0.33


# --- Core functions ----------------------------------------------------------
# Computes PSP for unbiased replication.
#
# Inputs:
#   r    : Number of successful replications
#   beta : Type II error rate (1 - power)
#
# Returns:
#   Post-study probability for unbiased replication
#
# Based on binomial probabilities under true and false hypotheses.

calculate_psp_unbiased <- function(r, beta) {
  b_true  <- choose(n, r) * (1 - beta)^r * beta^(n - r)
  b_false <- choose(n, r) * alpha^r * (1 - alpha)^(n - r)
  (b_true * pi0) / (b_true * pi0 + b_false * (1 - pi0))
}


# Computes PSP for sympathetic replication.
#
# Inputs:
#   r    : Number of successful replications
#   beta : Type II error rate (1 - power)
#
# Returns:
#   Post-study probability for sympathetic replication
#
# Based on Equation A15.1.3 with pure sympathetic bias v.
# Successful replication probability is (1-beta) + beta*v.

calculate_psp_sympathetic <- function(r, beta) {
  p_success_true  <- (1 - beta) + beta * v
  p_success_false <- alpha + (1 - alpha) * v
  b_true  <- choose(n, r) * p_success_true^r  * (1 - p_success_true)^(n - r)
  b_false <- choose(n, r) * p_success_false^r * (1 - p_success_false)^(n - r)
  (pi0 * b_true) / (pi0 * b_true + (1 - pi0) * b_false)
}


# Computes PSP for adversarial replication.
#
# Inputs:
#   r    : Number of successful replications
#   beta : Type II error rate (1 - power)
#
# Returns:
#   Post-study probability for adversarial replication
#
# Adversarial replication reduces success probability by factor (1 - omega).

calculate_psp_adversarial <- function(r, beta) {
  gamma1 <- (1 - beta) * (1 - omega)
  gamma2 <- alpha * (1 - omega)
  b_true  <- choose(n, r) * gamma1^r * (1 - gamma1)^(n - r)
  b_false <- choose(n, r) * gamma2^r * (1 - gamma2)^(n - r)
  (b_true * pi0) / (b_true * pi0 + b_false * (1 - pi0))
}


# Computes PSP for heterogeneous replication.
#
# Inputs:
#   r    : Number of successful replications
#   beta : Type II error rate (1 - power)
#
# Returns:
#   Post-study probability for heterogeneous replication
#
# Based on Equation A15.1.5: weighted mixture of phi fraction sympathetic,
# psi fraction adversarial, and (1-phi-psi) fraction neutral.

calculate_psp_heterogeneous <- function(r, beta) {
  chi1 <- phi * ((1 - beta) + beta * v) +
    psi * ((1 - beta) * (1 - omega)) +
    (1 - phi - psi) * (1 - beta)
  chi2 <- phi * (alpha + (1 - alpha) * v) +
    psi * (alpha * (1 - omega)) +
    (1 - phi - psi) * alpha
  b_chi1 <- choose(n, r) * chi1^r * (1 - chi1)^(n - r)
  b_chi2 <- choose(n, r) * chi2^r * (1 - chi2)^(n - r)
  (pi0 * b_chi1) / (pi0 * b_chi1 + (1 - pi0) * b_chi2)
}


# Helper function to add grid lines to plots
add_grid <- function() {
  abline(h = seq(0, 1, by = 0.25), col = "grey90", lty = 1)
  abline(v = 1:10,              col = "grey95", lty = 1)
}


# --- Plot generation ---------------------------------------------------------
r_values <- 1:n

# Close any open device
try(dev.off(), silent = TRUE)

# Open PNG device for output
png(file.path(output_dir, "Exhibit15.1.1A_R.png"),
    width = 1800, height = 900, res = 300)

par(mfrow = c(1, 2),
    mar  = c(4, 4, 2, 1),         # bottom, left, top, right
    oma  = c(3, 1, 4, 1),         # outer margins (for common labels/title)
    cex  = 0.4,                   # shrink everything a bit
    mgp  = c(2, 0.7, 0))          # axis title/label distances


# Left panel: beta = 0.3
beta <- 0.3
psp_adv  <- calculate_psp_adversarial(r_values, beta)
psp_unb  <- calculate_psp_unbiased(r_values, beta)
psp_het  <- calculate_psp_heterogeneous(r_values, beta)
psp_symp <- calculate_psp_sympathetic(r_values, beta)

plot(r_values, psp_unb,
     type = "n",
     xlim = c(1, 10),
     ylim = c(0, 1.05),
     xlab = "Number of successful replications out of 10 attempts",
     ylab = "PSP_rep",
     xaxt = "n", yaxt = "n")
add_grid()
axis(1, at = 1:10)
axis(2, at = c(0, 0.25, 0.5, 0.75, 1))

lines(r_values, psp_adv,
      type = "b", pch = 22, lty = 2, lwd = 1.5,
      col = "black", bg = "white")
lines(r_values, psp_unb,
      type = "b", pch = 16, lty = 1, lwd = 2,
      col = "black")
lines(r_values, psp_het,
      type = "b", pch = 24, lty = 3, lwd = 1.5,
      col = "grey40", bg = "white")
lines(r_values, psp_symp,
      type = "b", pch = 23, lty = 4, lwd = 1.5,
      col = "grey40", bg = "white")

mtext(expression(beta == 0.3), side = 1, line = 5, cex = 0.9, font = 2)

legend("bottomright",
       legend = c("Adversarial", "Unbiased", "Heterogeneous", "Sympathetic"),
       pch    = c(22, 16, 24, 23),
       lty    = c(2, 1, 3, 4),
       pt.bg  = c("white", "black", "white", "white"),
       col    = c("black", "black", "grey40", "grey40"),
       lwd    = c(1.3, 1.5, 1.3, 1.3),
       pt.cex = 0.8,
       cex    = 1.5,
       bty    = "n")


# Right panel: beta = 0.8
beta <- 0.8
psp_adv  <- calculate_psp_adversarial(r_values, beta)
psp_unb  <- calculate_psp_unbiased(r_values, beta)
psp_het  <- calculate_psp_heterogeneous(r_values, beta)
psp_symp <- calculate_psp_sympathetic(r_values, beta)

plot(r_values, psp_unb,
     type = "n",
     xlim = c(1, 10),
     ylim = c(0, 1.05),
     xlab = "Number of successful replications out of 10 attempts",
     ylab = "PSP_rep",
     xaxt = "n", yaxt = "n")
add_grid()
axis(1, at = 1:10)
axis(2, at = c(0, 0.25, 0.5, 0.75, 1))

lines(r_values, psp_adv,
      type = "b", pch = 22, lty = 2, lwd = 1.5,
      col = "black", bg = "white")
lines(r_values, psp_unb,
      type = "b", pch = 16, lty = 1, lwd = 2,
      col = "black")
lines(r_values, psp_het,
      type = "b", pch = 24, lty = 3, lwd = 1.5,
      col = "grey40", bg = "white")
lines(r_values, psp_symp,
      type = "b", pch = 23, lty = 4, lwd = 1.5,
      col = "grey40", bg = "white")

mtext(expression(beta == 0.8), side = 1, line = 5, cex = 0.9, font = 2)

legend("bottomright",
       legend = c("Adversarial", "Unbiased", "Heterogeneous", "Sympathetic"),
       pch    = c(22, 16, 24, 23),
       lty    = c(2, 1, 3, 4),
       pt.bg  = c("white", "black", "white", "white"),
       col    = c("black", "black", "grey40", "grey40"),
       lwd    = c(1.3, 1.5, 1.3, 1.3),
       pt.cex = 0.8,
       cex    = 1.5,
       bty    = "n")


# Common title across both panels
mtext("Exhibit 15.1.1A: PSP as a Function of Number of Replications out of 10 Attempts",
      side = 3, outer = TRUE, line = 1.5, cex = 0.7, font = 2)


# --- Save output -------------------------------------------------------------
dev.off()
cat("Saved to:", file.path(output_dir, "Exhibit15.1.1A_R.png"), "\n")
