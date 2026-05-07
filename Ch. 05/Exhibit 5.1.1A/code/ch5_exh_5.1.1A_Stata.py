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

from pathlib import Path
import math
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.api as sm
from tqdm import tqdm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Set random seed for reproducibility
# Note: R code uses "L'Ecuyer-CMRG" method for parallel RNG
np.random.seed(52649583)


# --- Parameters --------------------------------------------------------------
# Design inputs
N = 10000  # Size of overall population subject to randomization

# Treatment assignment: discrete uniform distribution over {0, 1, 2, 3, 4, 5}
SUPPORT_OF_TREATMENT = np.arange(0, 6)
TREAT_ASSIGN_PROBS = np.ones(len(SUPPORT_OF_TREATMENT)) / len(SUPPORT_OF_TREATMENT)

# Causal model parameters for potential outcomes
# Logistic model: p_i(d) = 1 / (1 + exp(-(-1.75 + 0.40*d + 0.05*d²)))
PREF_INTERCEPT = -1.75
PREF_LINEAR_LOADING = 0.40
PREF_QUAD_LOADING = 0.05

# Simulation parameters
SAMPLE_SIZES = np.arange(100, 3100, 100)  # Sample sizes to test
ITERS_PER_SAMPLE_SIZE = 1000  # Number of iterations per sample size
ALPHA_LEVEL = 0.05  # Significance level


# --- Helper functions --------------------------------------------------------
def make_potential_prob(dose, intercept, linear_loading, quad_loading):
    """
    Calculate potential outcome probability for a given dose using logistic model.

    Parameters:
        dose: Treatment dose level
        intercept: Intercept parameter (β₀)
        linear_loading: Linear coefficient (β₁)
        quad_loading: Quadratic coefficient (β₂)

    Returns:
        Probability p_i(d) = 1 / (1 + exp(-(β₀ + β₁*d + β₂*d²)))
    """
    return 1 / (1 + math.exp(-(intercept + (linear_loading * dose) + (quad_loading * (dose ** 2)))))


def rdiscuniform(n, support, probs):
    """
    Generate random draws from discrete distribution with given support and probabilities.

    Parameters:
        n: Number of draws
        support: Array of possible values
        probs: Probability of each value in support

    Returns:
        Array of n random draws
    """
    return np.random.choice(support, n, replace=True, p=probs)


def simulate_power(sample_size, iter_num, iter_per_sample_size):
    """
    Run a single iteration of the power simulation for a given sample size.

    Parameters:
        sample_size: Number of subjects in this iteration
        iter_num: Current iteration number
        iter_per_sample_size: Total iterations per sample size

    Returns:
        Tuple of (sample_size, iter_per_sample_size, p_val_dose, p_val_dose_sqrt)
    """
    # Calculate potential probabilities for each dose level
    potential_probs = [make_potential_prob(dose, PREF_INTERCEPT, PREF_LINEAR_LOADING,
                                           PREF_QUAD_LOADING) for dose in SUPPORT_OF_TREATMENT]

    # Data construction for a single instance of size 'sample_size'
    sim_dt = pd.DataFrame({'unit_id': range(1, sample_size + 1), 'dose': "-"})
    sim_dt['dose'] = rdiscuniform(sample_size, SUPPORT_OF_TREATMENT, TREAT_ASSIGN_PROBS)
    sim_dt['dose_squared'] = sim_dt['dose'] ** 2

    # Generate potential outcomes for each dose level
    # Y_i(d) ~ Bernoulli(p_i(d))
    for i in range(len(potential_probs)):
        sim_dt[f'Y_{i}'] = np.random.binomial(1, potential_probs[i], size=sample_size)

    # Observation equation: Y_i = sum_d Y_i(d) * 1[D_i = d]
    # Each subject reveals only the potential outcome corresponding to their assigned dose
    sim_dt['observed_outcome'] = sum(sim_dt[f'Y_{i}'] * (sim_dt['dose'] == i).astype(int)
                                      for i in range(len(SUPPORT_OF_TREATMENT)))

    # Estimate logistic regression model
    endog = sim_dt['observed_outcome']
    exog = sm.add_constant(sim_dt[['dose', 'dose_squared']])
    logit = sm.families.links.Logit()
    result = sm.GLM(endog, exog, family=sm.families.Binomial(link=logit)).fit()

    # Extract p-values for dose and dose-squared coefficients
    p_val_dose = result.pvalues['dose']
    p_val_dose_sqrt = result.pvalues['dose_squared']

    return sample_size, iter_per_sample_size, p_val_dose, p_val_dose_sqrt


# --- Initial demonstration ---------------------------------------------------
# Generate a single dataset to verify model recovery
print("\n" + "=" * 80)
print("EXHIBIT 5.1.1A: Initial Model Verification (N = 10,000)")
print("=" * 80)

# Calculate potential probabilities
potential_probs = [make_potential_prob(dose, PREF_INTERCEPT, PREF_LINEAR_LOADING,
                                       PREF_QUAD_LOADING) for dose in SUPPORT_OF_TREATMENT]

# Data construction for a single instance of size N
sim_dt = pd.DataFrame({'unit_id': range(1, N + 1), 'dose': "-"})
sim_dt['dose'] = rdiscuniform(N, SUPPORT_OF_TREATMENT, TREAT_ASSIGN_PROBS)
sim_dt['dose_squared'] = sim_dt['dose'] ** 2

# Generate potential outcomes
for i in range(len(potential_probs)):
    sim_dt[f'Y_{i}'] = np.random.binomial(1, potential_probs[i], size=N)

# Observation equation
sim_dt['observed_outcome'] = sum(sim_dt[f'Y_{i}'] * (sim_dt['dose'] == i).astype(int)
                                  for i in range(len(SUPPORT_OF_TREATMENT)))

# Checking that we recover our assumed model coefficients (within confidence interval)
endog = sim_dt['observed_outcome']
exog = sm.add_constant(sim_dt[['dose', 'dose_squared']])
logit = sm.families.links.Logit()
model = sm.GLM(endog, exog, family=sm.families.Binomial(link=logit)).fit()
print(model.summary())
print("=" * 80)


# --- Run power simulation ----------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.1.1A: Power Simulation")
print("=" * 80)
print(f"Running {ITERS_PER_SAMPLE_SIZE} iterations for each of {len(SAMPLE_SIZES)} sample sizes...")
print(f"Sample sizes: {SAMPLE_SIZES[0]} to {SAMPLE_SIZES[-1]} (step: {SAMPLE_SIZES[1] - SAMPLE_SIZES[0]})")
print("=" * 80)

# Run the simulation across all sample sizes
simulation_results = []
for sample_size in SAMPLE_SIZES:
    for iter_num in tqdm(range(1, ITERS_PER_SAMPLE_SIZE + 1),
                          desc=f"Sample size {sample_size}"):
        sample_size_result, iter_per_sample_size, p_val_dose, p_val_dose_sqrt = \
            simulate_power(sample_size, iter_num, ITERS_PER_SAMPLE_SIZE)
        simulation_results.append({
            'sample_size': sample_size_result,
            'iteration_per_sample': iter_per_sample_size,
            'p_val_dose': p_val_dose,
            'p_val_dose_sqrt': p_val_dose_sqrt
        })

# Convert to DataFrame
simulation_results = pd.DataFrame(simulation_results)
simulation_results['reject_null_linear'] = (simulation_results['p_val_dose'] <= ALPHA_LEVEL).astype(int)
simulation_results['reject_null_quad'] = (simulation_results['p_val_dose_sqrt'] <= ALPHA_LEVEL).astype(int)


# --- Calculate and save power results ----------------------------------------
# Calculate statistical power (fraction of iterations rejecting null hypothesis)
power_results_linear = simulation_results.groupby('sample_size').mean()['reject_null_linear'].reset_index()
power_results_quad = simulation_results.groupby('sample_size').mean()['reject_null_quad'].reset_index()

# Merge and save results
merged_results = pd.merge(power_results_linear, power_results_quad, on='sample_size')
merged_results.rename(columns={
    'sample_size': 'Sample Size',
    'reject_null_linear': 'Fraction Correctly Rejecting Null (Linear)',
    'reject_null_quad': 'Fraction Correctly Rejecting Null (Quadratic)'
}, inplace=True)

# Save to CSV
csv_file = OUTPUT_DIR / 'simulation-result-python.csv'
merged_results.to_csv(csv_file, index=False)
print(f"\n✓ Power results saved to: {csv_file}")


# --- Create power curve plot -------------------------------------------------
plt.figure(figsize=(10, 7))

# Plot power curves for linear and quadratic coefficients
plt.plot(power_results_linear['sample_size'],
         power_results_linear['reject_null_linear'],
         color='black', linewidth=2)
plt.plot(power_results_quad['sample_size'],
         power_results_quad['reject_null_quad'],
         color='#B3B3B3', linewidth=2)

# Add 80% power threshold line
plt.axhline(y=0.80, color='r', linestyle='dotted', linewidth=1.5,
            label='80% power threshold')

# Labels and title
plt.xlabel('Sample Size per Iteration (with 1,000 iterations per sample size)', fontsize=11)
plt.ylabel('Fraction of Iterations Correctly Rejecting the Null (H₀)', fontsize=11)

# Add model equation annotation
model_text_p_i = r"\mathit{p_{i}\left(\beta_{0},\beta_{1},\beta_{2}, D_{i}\right)}"
model_text_log_odds = r"\log\,\frac{" + model_text_p_i + r"}{1 - " + model_text_p_i + r"}"
model_text = (f"Model underlying simulation: ${model_text_log_odds} = "
              f"{PREF_INTERCEPT:.2f} + {PREF_LINEAR_LOADING:.2f} " + r"\times D_{i} + " +
              f"{PREF_QUAD_LOADING:.2f} " + r"\times D^2_{i}$")
plt.annotate(model_text, xy=(1500, 0.2), xytext=(400, 0.12),
             fontsize=12, color='#56B4E9')

# Legend
plt.legend(loc='best', labels=[
    f"Linear Coefficient (β₁ = {PREF_LINEAR_LOADING:.2f})",
    f"Quadratic Coefficient (β₂ = {PREF_QUAD_LOADING:.2f})",
    '80% power threshold'
])

# Save plot
plot_file = OUTPUT_DIR / 'simulation-result-python.png'
plt.savefig(plot_file, dpi=300, bbox_inches='tight')
plt.close()

print(f"✓ Power curve plot saved to: {plot_file}\n")


# --- Print summary statistics ------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.1.1A: Power Simulation Summary")
print("=" * 80)
print(f"Total iterations run: {len(simulation_results):,}")
print(f"Sample sizes tested: {len(SAMPLE_SIZES)}")
print(f"Significance level (α): {ALPHA_LEVEL}")
print("\nPower at selected sample sizes:")
print(f"{'Sample Size':>15} {'Linear (β₁)':>20} {'Quadratic (β₂)':>20}")
print("-" * 80)
for idx in [0, len(SAMPLE_SIZES)//4, len(SAMPLE_SIZES)//2, 3*len(SAMPLE_SIZES)//4, -1]:
    ss = int(power_results_linear.iloc[idx]['sample_size'])
    power_lin = power_results_linear.iloc[idx]['reject_null_linear']
    power_quad = power_results_quad.iloc[idx]['reject_null_quad']
    print(f"{ss:>15} {power_lin:>20.3f} {power_quad:>20.3f}")
print("=" * 80)

# =============================================================================
# END OF EXHIBIT 5.1.1A
# =============================================================================
