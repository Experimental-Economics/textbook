# ==============================================================================
# Chapter 5 - Power Analysis
# ==============================================================================
# Functions for computing the minimum detectable effect (MDE) and required
# sample size (N) for common experimental designs.
#
# Each design provides two functions:
#   mde_given_n  -- compute MDE for a given total sample size
#   n_given_mde  -- compute required total sample size for a given MDE
#
# Contents:
#   Part 1: Binary treatment, continuous outcome
#   Part 2: Binary treatment, binary outcome
#   Part 3: Varying treatment levels, continuous outcome
#   Part 4: Accounting for heterogeneity in sampling costs
#   Part 5: Clustered experimental design
# ==============================================================================

# --- Setup: auto-detect working directory ------------------------------------
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getSourceEditorContext()$path))
}

rm(list = ls())


# ==============================================================================
# Part 1: Binary treatment, continuous outcome
# ==============================================================================
# Consider an experiment with two groups (treatment and control) and a
# continuous outcome Y. The treatment effect is delta = E[Y1] - E[Y0].
#
# The core relationship linking MDE to sample size is:
#
#   delta = (t_{alpha/2} + t_beta) * sqrt(sigma_0^2 / n_0 + sigma_1^2 / n_1)
#
# where sigma_0, sigma_1 are the std. deviations of outcomes in control and
# treatment, and n_0, n_1 are the sample sizes.
#
# Special case — equal variances (sigma_0 = sigma_1 = sigma):
# The optimal design allocates subjects equally (n_0 = n_1 = N/2), giving:
#
#   delta = (t_{alpha/2} + t_beta) * sigma * sqrt(4 / N)
#   N     = 4 * (t_{alpha/2} + t_beta)^2 * (sigma / delta)^2
#
# When variances differ, the optimal allocation rule is:
#   n_0 / n_1 = sigma_0 / sigma_1
# (allocate more subjects to the higher-variance group)
# ==============================================================================

# --- 1a. Equal variances ------------------------------------------------------

mde_given_n_continuous <- function(N, sigma, alpha = 0.05, power = 0.80) {
  # N:     total sample size (split equally across two arms)
  # sigma: common std. deviation of outcomes
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  mde <- (t_a + t_b) * sigma * sqrt(4 / N)
  return(mde)
}

n_given_mde_continuous <- function(delta, sigma, alpha = 0.05, power = 0.80) {
  # delta: minimum detectable effect size
  # sigma: common std. deviation of outcomes
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  N <- 4 * (t_a + t_b)^2 * (sigma / delta)^2
  return(ceiling(N))
}

# --- 1b. Unequal variances ----------------------------------------------------

mde_given_n_continuous_uneq <- function(N, sigma_0, sigma_1,
                                        alpha = 0.05, power = 0.80) {
  # N:       total sample size
  # sigma_0: std. deviation of outcomes in control group
  # sigma_1: std. deviation of outcomes in treatment group
  # Optimal allocation: n_0/n_1 = sigma_0/sigma_1
  t_a  <- qnorm(1 - alpha / 2)
  t_b  <- qnorm(power)
  pi_0 <- sigma_0 / (sigma_0 + sigma_1)      # optimal share in control
  n_0  <- N * pi_0
  n_1  <- N * (1 - pi_0)
  mde  <- (t_a + t_b) * sqrt(sigma_0^2 / n_0 + sigma_1^2 / n_1)
  return(mde)
}

n_given_mde_continuous_uneq <- function(delta, sigma_0, sigma_1,
                                        alpha = 0.05, power = 0.80) {
  # delta:   minimum detectable effect size
  # sigma_0: std. deviation of outcomes in control group
  # sigma_1: std. deviation of outcomes in treatment group
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  N   <- ((t_a + t_b) / delta)^2 * (sigma_0 + sigma_1)^2
  return(ceiling(N))
}

# --- Examples -----------------------------------------------------------------
cat("==============================================================\n")
cat("Part 1: Binary treatment, continuous outcome\n")
cat("==============================================================\n\n")

cat("1a. Equal variances (sigma = 1)\n")
cat(sprintf("  MDE given N = 200:     %.4f\n",
            mde_given_n_continuous(N = 200, sigma = 1)))
cat(sprintf("  N given MDE = 0.5:     %d\n\n",
            n_given_mde_continuous(delta = 0.5, sigma = 1)))

cat("1b. Unequal variances (sigma_0 = 80, sigma_1 = 46)\n")
cat(sprintf("  MDE given N = 175:     %.4f\n",
            mde_given_n_continuous_uneq(N = 175, sigma_0 = 80, sigma_1 = 46)))
cat(sprintf("  N given MDE = 20:      %d\n",
            n_given_mde_continuous_uneq(delta = 20, sigma_0 = 80, sigma_1 = 46)))
cat(sprintf("  Optimal allocation:    pi_0 = %.2f, pi_1 = %.2f\n\n",
            80 / (80 + 46), 46 / (80 + 46)))


# ==============================================================================
# Part 2: Binary treatment, binary outcome
# ==============================================================================
# When the outcome is binary (Y in {0,1}), the variance is determined by the
# mean: sigma^2 = p * (1 - p).
#
# Under H0 (no treatment effect, p_0 = p_1 = p):
#   - Equal allocation is always optimal (since variances are equal)
#   - N = 4 * (t_{alpha/2} + t_beta)^2 * p(1-p) / delta^2
#
# Under H1 (p_0 != p_1):
#   - Variances differ, so optimal allocation follows the same rule as Part 1:
#     n_0/n_1 = sigma_0/sigma_1 = sqrt(p_0(1-p_0)) / sqrt(p_1(1-p_1))
# ==============================================================================

# --- 2a. Under H0 (common proportion p) --------------------------------------

mde_given_n_binary <- function(N, p, alpha = 0.05, power = 0.80) {
  # N: total sample size (split equally)
  # p: common event probability under H0
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  mde <- (t_a + t_b) * sqrt(4 * p * (1 - p) / N)
  return(mde)
}

n_given_mde_binary <- function(delta, p, alpha = 0.05, power = 0.80) {
  # delta: minimum detectable effect (difference in proportions)
  # p:     common event probability under H0
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  N   <- 4 * (t_a + t_b)^2 * p * (1 - p) / delta^2
  return(ceiling(N))
}

# --- 2b. Under H1 (known p_0, p_1) -------------------------------------------

mde_given_n_binary_uneq <- function(N, p_0, p_1, alpha = 0.05, power = 0.80) {
  # N:   total sample size
  # p_0: event probability in control
  # p_1: event probability in treatment
  sigma_0 <- sqrt(p_0 * (1 - p_0))
  sigma_1 <- sqrt(p_1 * (1 - p_1))
  mde_given_n_continuous_uneq(N, sigma_0, sigma_1, alpha, power)
}

n_given_mde_binary_uneq <- function(delta, p_0, p_1,
                                    alpha = 0.05, power = 0.80) {
  # delta: minimum detectable effect
  # p_0:   event probability in control
  # p_1:   event probability in treatment
  sigma_0 <- sqrt(p_0 * (1 - p_0))
  sigma_1 <- sqrt(p_1 * (1 - p_1))
  n_given_mde_continuous_uneq(delta, sigma_0, sigma_1, alpha, power)
}

# --- Examples -----------------------------------------------------------------
cat("==============================================================\n")
cat("Part 2: Binary treatment, binary outcome\n")
cat("==============================================================\n\n")

cat("2a. Under H0 (p = 0.50)\n")
cat(sprintf("  MDE given N = 1000:    %.4f\n",
            mde_given_n_binary(N = 1000, p = 0.50)))
cat(sprintf("  N given MDE = 0.05:    %d\n\n",
            n_given_mde_binary(delta = 0.05, p = 0.50)))

cat("2b. Under H1 (p_0 = 0.10, p_1 = 0.15)\n")
cat(sprintf("  MDE given N = 2000:    %.4f\n",
            mde_given_n_binary_uneq(N = 2000, p_0 = 0.10, p_1 = 0.15)))
cat(sprintf("  N given MDE = 0.05:    %d\n\n",
            n_given_mde_binary_uneq(delta = 0.05, p_0 = 0.10, p_1 = 0.15)))


# ==============================================================================
# Part 3: Varying treatment levels, continuous outcome
# ==============================================================================
# When the treatment variable T takes on multiple levels (e.g., different
# dosages, prices, or match ratios), and we assume a linear relationship
# Y = alpha + beta * T + epsilon, the key quantity is the variance of T.
#
# The variance of the OLS estimator of beta is:
#   Var(beta_hat) = sigma_eps^2 / (N * Var(T))
#
# So the MDE is:
#   delta = (t_{alpha/2} + t_beta) * sigma_eps / sqrt(N * Var(T))
#
# Rule of thumb: to maximize power, maximize Var(T). For a linear effect,
# place all subjects at the two endpoints of the feasible treatment range
# (50/50 split), with no intermediate points.
# ==============================================================================

mde_given_n_varying <- function(N, sigma_eps, var_T,
                                alpha = 0.05, power = 0.80) {
  # N:         total sample size
  # sigma_eps: std. deviation of the error term
  # var_T:     variance of the treatment variable
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  mde <- (t_a + t_b) * sigma_eps / sqrt(N * var_T)
  return(mde)
}

n_given_mde_varying <- function(delta, sigma_eps, var_T,
                                alpha = 0.05, power = 0.80) {
  # delta:     minimum detectable effect (slope coefficient)
  # sigma_eps: std. deviation of the error term
  # var_T:     variance of the treatment variable
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  N   <- (t_a + t_b)^2 * sigma_eps^2 / (var_T * delta^2)
  return(ceiling(N))
}

# --- Examples -----------------------------------------------------------------
cat("==============================================================\n")
cat("Part 3: Varying treatment levels, continuous outcome\n")
cat("==============================================================\n\n")

# Example: treatment levels T in {0, 1, 2, 3} with equal allocation
T_levels <- c(0, 1, 2, 3)
var_T    <- var(rep(T_levels, each = 1))  # population variance

cat(sprintf("Treatment levels: {%s}, Var(T) = %.2f\n",
            paste(T_levels, collapse = ", "), var_T))
cat(sprintf("  MDE given N = 500:     %.4f\n",
            mde_given_n_varying(N = 500, sigma_eps = 1, var_T = var_T)))
cat(sprintf("  N given MDE = 0.2:     %d\n\n",
            n_given_mde_varying(delta = 0.2, sigma_eps = 1, var_T = var_T)))

# Compare: binary treatment at endpoints only (T in {0, 3})
var_T_endpoints <- var(c(0, 3))
cat(sprintf("Endpoints only: {0, 3}, Var(T) = %.2f\n", var_T_endpoints))
cat(sprintf("  MDE given N = 500:     %.4f\n",
            mde_given_n_varying(N = 500, sigma_eps = 1, var_T = var_T_endpoints)))
cat(sprintf("  N given MDE = 0.2:     %d\n",
            n_given_mde_varying(delta = 0.2, sigma_eps = 1, var_T = var_T_endpoints)))
cat("  -> Placing subjects at endpoints reduces the required N.\n\n")


# ==============================================================================
# Part 4: Accounting for heterogeneity in sampling costs
# ==============================================================================
# When sampling costs differ across treatment and control (e.g., treatment
# involves an expensive intervention), the optimal allocation changes.
#
# Let c_0, c_1 be the per-subject costs in control and treatment. The
# optimal allocation is:
#
#   n_0 / n_1 = (sigma_0 / sigma_1) * sqrt(c_1 / c_0)
#
# Equivalently, the optimal shares are:
#   pi_0 = (sigma_0 / sqrt(c_0)) / (sigma_0/sqrt(c_0) + sigma_1/sqrt(c_1))
#
# Given a fixed budget B = c_0*n_0 + c_1*n_1, we can compute the MDE.
# Conversely, given a target MDE, we can compute the required budget.
# ==============================================================================

mde_given_budget <- function(budget, sigma_0, sigma_1, c_0, c_1,
                             alpha = 0.05, power = 0.80) {
  # budget:  total available budget
  # sigma_0: std. deviation of outcomes in control
  # sigma_1: std. deviation of outcomes in treatment
  # c_0:     per-subject cost in control group
  # c_1:     per-subject cost in treatment group
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)

  # Optimal allocation shares
  pi_0 <- (sigma_0 / sqrt(c_0)) / (sigma_0 / sqrt(c_0) + sigma_1 / sqrt(c_1))
  pi_1 <- 1 - pi_0

  # Total N from budget: B = c_0*N*pi_0 + c_1*N*pi_1
  N  <- budget / (c_0 * pi_0 + c_1 * pi_1)
  n_0 <- N * pi_0
  n_1 <- N * pi_1

  mde <- (t_a + t_b) * sqrt(sigma_0^2 / n_0 + sigma_1^2 / n_1)

  return(list(mde = mde, N = N, n_0 = n_0, n_1 = n_1, pi_0 = pi_0))
}

budget_given_mde <- function(delta, sigma_0, sigma_1, c_0, c_1,
                             alpha = 0.05, power = 0.80) {
  # delta:   minimum detectable effect size
  # sigma_0: std. deviation of outcomes in control
  # sigma_1: std. deviation of outcomes in treatment
  # c_0:     per-subject cost in control group
  # c_1:     per-subject cost in treatment group
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)

  # Optimal allocation shares
  pi_0 <- (sigma_0 / sqrt(c_0)) / (sigma_0 / sqrt(c_0) + sigma_1 / sqrt(c_1))
  pi_1 <- 1 - pi_0

  # Required N from the MDE formula
  N <- ((t_a + t_b) / delta)^2 * (sigma_0^2 / pi_0 + sigma_1^2 / pi_1)
  n_0 <- N * pi_0
  n_1 <- N * pi_1

  budget <- c_0 * n_0 + c_1 * n_1

  return(list(budget = ceiling(budget), N = ceiling(N),
              n_0 = ceiling(n_0), n_1 = ceiling(n_1), pi_0 = pi_0))
}

# --- Examples -----------------------------------------------------------------
cat("==============================================================\n")
cat("Part 4: Heterogeneity in sampling costs\n")
cat("==============================================================\n\n")

cat("Equal costs (c_0 = c_1 = 10), equal variances (sigma = 1)\n")
res <- mde_given_budget(budget = 2000, sigma_0 = 1, sigma_1 = 1, c_0 = 10, c_1 = 10)
cat(sprintf("  Budget = 2000 -> N = %.0f, MDE = %.4f, pi_0 = %.2f\n\n",
            res$N, res$mde, res$pi_0))

cat("Unequal costs (c_0 = 5, c_1 = 20), equal variances (sigma = 1)\n")
res <- mde_given_budget(budget = 2000, sigma_0 = 1, sigma_1 = 1, c_0 = 5, c_1 = 20)
cat(sprintf("  Budget = 2000 -> N = %.0f (n_0 = %.0f, n_1 = %.0f), MDE = %.4f\n",
            res$N, res$n_0, res$n_1, res$mde))
cat(sprintf("  Optimal allocation: pi_0 = %.2f (more in cheaper control)\n\n", res$pi_0))

cat("Required budget for MDE = 0.3 (c_0 = 5, c_1 = 20, sigma = 1)\n")
res <- budget_given_mde(delta = 0.3, sigma_0 = 1, sigma_1 = 1, c_0 = 5, c_1 = 20)
cat(sprintf("  Budget = %d, N = %d (n_0 = %d, n_1 = %d)\n\n",
            res$budget, res$N, res$n_0, res$n_1))


# ==============================================================================
# Part 5: Clustered experimental design
# ==============================================================================
# When randomization occurs at the cluster level (e.g., classrooms, villages),
# outcomes within clusters are correlated. The intracluster correlation (rho)
# inflates the required sample size by a design effect:
#
#   Design effect = 1 + (m - 1) * rho
#
# where m = number of individuals per cluster.
#
# The formulas become:
#   N = 4 * (t_{alpha/2} + t_beta)^2 * (sigma/delta)^2 * [1 + (m-1)*rho]
#   k = N / m  (number of clusters per arm, times 2 for both arms)
#
# When the cost of adding a new cluster (c_c) differs from the cost of adding
# a subject within an existing cluster (c_s), the optimal cluster size is:
#   m* = sqrt((1 - rho) / rho * c_c / c_s)
# ==============================================================================

mde_given_n_cluster <- function(N, sigma, m, rho,
                                alpha = 0.05, power = 0.80) {
  # N:     total sample size across all clusters and arms
  # sigma: std. deviation of outcomes
  # m:     number of individuals per cluster
  # rho:   intracluster correlation (ICC)
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  design_effect <- 1 + (m - 1) * rho
  mde <- (t_a + t_b) * sigma * sqrt(4 * design_effect / N)
  return(mde)
}

n_given_mde_cluster <- function(delta, sigma, m, rho,
                                alpha = 0.05, power = 0.80) {
  # delta: minimum detectable effect size
  # sigma: std. deviation of outcomes
  # m:     number of individuals per cluster
  # rho:   intracluster correlation (ICC)
  t_a <- qnorm(1 - alpha / 2)
  t_b <- qnorm(power)
  design_effect <- 1 + (m - 1) * rho
  N <- 4 * (t_a + t_b)^2 * (sigma / delta)^2 * design_effect
  return(ceiling(N))
}

optimal_cluster_size <- function(rho, c_cluster, c_subject) {
  # rho:       intracluster correlation (ICC)
  # c_cluster: fixed cost of adding a new cluster
  # c_subject: marginal cost of adding a subject within a cluster
  m_star <- sqrt((1 - rho) / rho * c_cluster / c_subject)
  return(m_star)
}

# --- Examples -----------------------------------------------------------------
cat("==============================================================\n")
cat("Part 5: Clustered experimental design\n")
cat("==============================================================\n\n")

cat("5a. MDE and N for different ICC values (m = 20, sigma = 1)\n")
for (rho in c(0, 0.05, 0.10, 0.25, 0.50)) {
  de <- 1 + (20 - 1) * rho
  n  <- n_given_mde_cluster(delta = 0.3, sigma = 1, m = 20, rho = rho)
  cat(sprintf("  rho = %.2f -> design effect = %.2f, required N = %d (k = %d clusters)\n",
              rho, de, n, ceiling(n / 20)))
}

cat(sprintf("\n  MDE given N = 1000, m = 20, rho = 0.10: %.4f\n\n",
            mde_given_n_cluster(N = 1000, sigma = 1, m = 20, rho = 0.10)))

cat("5b. Optimal cluster size with cost considerations\n")
cat(sprintf("  rho = 0.10, c_cluster = 1000, c_subject = 50 -> optimal m = %.1f\n",
            optimal_cluster_size(rho = 0.10, c_cluster = 1000, c_subject = 50)))
cat(sprintf("  rho = 0.25, c_cluster = 1000, c_subject = 50 -> optimal m = %.1f\n\n",
            optimal_cluster_size(rho = 0.25, c_cluster = 1000, c_subject = 50)))
