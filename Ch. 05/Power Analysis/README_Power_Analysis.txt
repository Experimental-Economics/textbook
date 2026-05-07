================================================================================
Chapter 5 - Power Analysis
================================================================================

OVERVIEW
--------
This folder contains functions for computing the minimum detectable effect (MDE)
and required sample size (N) for common experimental designs. Each design type
provides two directions of the power formula:

  - MDE given N:  "Given my sample size, what is the smallest effect I can detect?"
  - N given MDE:  "Given the effect I want to detect, how many subjects do I need?"

All functions take flexible parameters (significance level, power, variances,
costs, etc.) with standard defaults (alpha = 0.05, power = 0.80).


FOLDER STRUCTURE
----------------
  code/     R script with functions and worked examples
  output/   Generated output files (created automatically when you run the script)


CONTENTS
--------
The script covers five experimental design types:

  Part 1 — Binary treatment, continuous outcome
            The baseline case. Includes both equal-variance (optimal = equal
            allocation) and unequal-variance (optimal allocation proportional
            to the ratio of standard deviations) formulas.
            Functions: mde_given_n_continuous, n_given_mde_continuous
                       mde_given_n_continuous_uneq, n_given_mde_continuous_uneq

  Part 2 — Binary treatment, binary outcome
            When the outcome is binary (0/1), variance is determined by the
            mean: sigma^2 = p(1-p). Under the null (equal proportions), equal
            allocation is always optimal. Under the alternative (unequal
            proportions), allocation follows the same rule as Part 1.
            Functions: mde_given_n_binary, n_given_mde_binary
                       mde_given_n_binary_uneq, n_given_mde_binary_uneq

  Part 3 — Varying treatment levels, continuous outcome
            When the treatment variable takes on multiple levels (e.g., different
            dosages or prices), power depends on Var(T). Rule of thumb: to
            maximize power with a linear effect, place all subjects at the two
            endpoints of the feasible treatment range.
            Functions: mde_given_n_varying, n_given_mde_varying

  Part 4 — Accounting for heterogeneity in sampling costs
            When the cost of sampling differs between treatment and control,
            the optimal allocation shifts toward the cheaper group:
            n_0/n_1 = (sigma_0/sigma_1) * sqrt(c_1/c_0).
            Functions take a total budget as input instead of N.
            Functions: mde_given_budget, budget_given_mde

  Part 5 — Clustered experimental design
            When randomization occurs at the cluster level (e.g., classrooms),
            the intracluster correlation (rho) inflates the required sample
            size by a design effect = 1 + (m-1)*rho. Also includes the formula
            for the cost-optimal cluster size m*.
            Functions: mde_given_n_cluster, n_given_mde_cluster,
                       optimal_cluster_size


HOW TO RUN
----------
  R:
    1. Open code/power_analysis.R in RStudio and click "Source"
       (or Ctrl+Shift+S / Cmd+Shift+S).
    2. From a terminal:    Rscript code/power_analysis.R

  Requirements: R with the data.table package (installed automatically if missing).

  The script prints worked examples for each design type to the console and
  exports a panel-data sample-size grid to output/power-paneldata-A.csv.


KEY FORMULAS
------------
All formulas build on the same core relationship (for a two-sided t-test):

  delta = (t_{alpha/2} + t_beta) * sqrt(sigma_0^2/n_0 + sigma_1^2/n_1)

Special cases:

  Equal variances:
    N = 4 * (t_{alpha/2} + t_beta)^2 * (sigma/delta)^2

  Binary outcome (equal proportions under H0):
    N = 4 * (t_{alpha/2} + t_beta)^2 * p(1-p) / delta^2

  Varying treatment levels:
    N = (t_{alpha/2} + t_beta)^2 * sigma_eps^2 / (Var(T) * delta^2)

  Clustered design:
    N = 4 * (t_{alpha/2} + t_beta)^2 * (sigma/delta)^2 * [1 + (m-1)*rho]

  Unequal costs (optimal allocation):
    pi_0 = (sigma_0/sqrt(c_0)) / (sigma_0/sqrt(c_0) + sigma_1/sqrt(c_1))

where:
  t_{alpha/2} = critical value for significance level alpha (e.g., 1.96)
  t_beta      = critical value for desired power (e.g., 0.84 for 80% power)
  sigma       = std. deviation of outcomes
  delta       = minimum detectable effect size
  p           = event probability (binary outcomes)
  Var(T)      = variance of the treatment variable
  rho         = intracluster correlation
  m           = individuals per cluster
  c_0, c_1    = per-subject sampling costs in control and treatment
================================================================================
