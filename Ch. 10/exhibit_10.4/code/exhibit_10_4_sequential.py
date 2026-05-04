# =============================================================================
# Exhibit 10.4: Power Analysis - Within vs. Between Subjects Designs
# =============================================================================
# Conducts Monte Carlo simulation to compare statistical power between
# within-subjects and between-subjects experimental designs.
#
# Data generating process (Equation 10.4):
# Y_it = π₀ + τ*D_it + μ_i + ε_it
#
# Where:
# - Y_it: Outcome for individual i at time t
# - π₀: Baseline mean
# - τ: Treatment effect (varies: 0.05, 0.10, 0.15)
# - D_it: Treatment indicator
# - μ_i: Individual fixed effect (constant across time)
# - ε_it: Random error
#
# Reference: Chapter 10, Experimental Design

from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import linregress


# --- Setup -------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Set random seed for replication
np.random.seed(123)


# --- Parameters --------------------------------------------------------------
TREATMENT_EFFECTS = [0.05, 0.10, 0.15]
BASELINE_MEAN = 0.37
INDIVIDUAL_SD = np.sqrt(0.09)
ERROR_SD = np.sqrt(0.02)
TIME_PERIODS = 2
SAMPLE_SIZES = list(range(10, 401))
N_ITERATIONS = 1000
ALPHA_LEVEL = 0.05


# --- Functions ---------------------------------------------------------------
def assign_treatment(design, dataframe):
    """
    Assign treatment based on design.

    Parameters:
    - design: "WS" or "BS"
    - dataframe: DataFrame with columns ['i', 't']

    Returns:
    - dataframe: DataFrame with added 'D' column
    """
    # Shuffle data
    dataframe = dataframe.sample(frac=1).reset_index(drop=True)

    # Get unique subjects after shuffling
    unique_subjects = dataframe['i'].unique()
    n_half = len(unique_subjects) // 2
    first_half = set(unique_subjects[:n_half])

    if design == "WS":
        # First half: treated in period 0
        # Second half: treated in period 1
        in_first = dataframe['i'].isin(first_half)
        is_period_0 = dataframe['t'] == 0
        dataframe['D'] = ((in_first & is_period_0) | (~in_first & ~is_period_0)).astype(int)

    elif design == "BS":
        # First half: always treated
        # Second half: never treated
        dataframe['D'] = dataframe['i'].isin(first_half).astype(int)

    # Sort by i and t
    dataframe = dataframe.sort_values(['i', 't']).reset_index(drop=True)

    return dataframe


def generate_data(baseline, treatment_effect, individual_sd, error_sd,
                  n_subjects, n_periods, design):
    """
    Generate simulated data following Equation 10.4.

    Y_it = π₀ + τ*D_it + μ_i + ε_it

    Parameters:
    - baseline: Baseline mean (π₀)
    - treatment_effect: Treatment effect (τ)
    - individual_sd: Standard deviation of individual effects (μ_i)
    - error_sd: Standard deviation of random errors (ε_it)
    - n_subjects: Number of subjects
    - n_periods: Number of time periods
    - design: "WS" or "BS"

    Returns:
    - dataframe: DataFrame with columns ['i', 't', 'D', 'mu', 'epsilon', 'Y']
    """
    # Create panel structure
    data = pd.DataFrame({
        'i': np.repeat(np.arange(1, n_subjects + 1), n_periods),
        't': np.tile(np.arange(n_periods), n_subjects)
    })

    # Assign treatment based on design
    data = assign_treatment(design, data)

    # Generate individual fixed effects (constant within subject)
    individual_effects = np.random.normal(0, individual_sd, n_subjects)
    data['mu'] = individual_effects[data['i'].values - 1]

    # Generate random errors
    data['epsilon'] = np.random.normal(0, error_sd, n_subjects * n_periods)

    # Generate outcome: Y_it = π₀ + τ*D_it + μ_i + ε_it
    data['Y'] = baseline + treatment_effect * data['D'] + data['mu'] + data['epsilon']

    return data


def test_significance(dataframe, design, alpha=ALPHA_LEVEL):
    """
    Test whether treatment effect is statistically significant.

    Parameters:
    - dataframe: DataFrame with columns ['i', 't', 'D', 'Y']
    - design: "WS" or "BS"
    - alpha: Significance level (default: 0.05)

    Returns:
    - is_significant: Boolean indicating if p-value < alpha
    """
    if design == "WS":
        # Within-subjects: demean to remove individual fixed effects
        dataframe['D_demeaned'] = dataframe['D'] - dataframe.groupby('i')['D'].transform('mean')
        dataframe['Y_demeaned'] = dataframe['Y'] - dataframe.groupby('i')['Y'].transform('mean')

        slope, intercept, r_value, p_value, std_err = linregress(
            dataframe['D_demeaned'],
            dataframe['Y_demeaned']
        )

    elif design == "BS":
        # Between-subjects: standard regression
        slope, intercept, r_value, p_value, std_err = linregress(
            dataframe['D'],
            dataframe['Y']
        )

    return p_value < alpha


# --- Run simulation ----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 10.4: Power Analysis - Within vs. Between Subjects Designs")
print("=" * 80 + "\n")

# Initialize storage for results
results = {
    'WS': {tau: [] for tau in TREATMENT_EFFECTS},
    'BS': {tau: [] for tau in TREATMENT_EFFECTS}
}

# Loop over treatment effects
for treatment_effect in TREATMENT_EFFECTS:
    print(f"\nTreatment Effect τ = {treatment_effect:.2f}")
    print("-" * 80)

    # Loop over sample sizes
    for n_subjects in SAMPLE_SIZES:

        # Loop over designs
        for design in ['WS', 'BS']:
            print(f"  Design: {design} | N = {n_subjects:3}")

            # Run iterations to calculate power
            significant_count = 0

            for iteration in range(N_ITERATIONS):
                # Generate data
                data = generate_data(
                    BASELINE_MEAN,
                    treatment_effect,
                    INDIVIDUAL_SD,
                    ERROR_SD,
                    n_subjects,
                    TIME_PERIODS,
                    design
                )

                # Test significance
                is_significant = test_significance(data, design)

                if is_significant:
                    significant_count += 1

            # Calculate power for this sample size
            power = significant_count / N_ITERATIONS
            results[design][treatment_effect].append(power)


# --- Create plot -------------------------------------------------------------
print("\n" + "=" * 80)
print("Creating power curves...")
print("=" * 80 + "\n")

fig, axs = plt.subplots(1, 3, figsize=(14, 4))

for i, treatment_effect in enumerate(TREATMENT_EFFECTS):
    # Plot within-subjects
    axs[i].plot(SAMPLE_SIZES, results['WS'][treatment_effect],
                label='Within-Subjects (WS)', color='blue', linewidth=2)

    # Plot between-subjects
    axs[i].plot(SAMPLE_SIZES, results['BS'][treatment_effect],
                label='Between-Subjects (BS)', color='red', linewidth=2)

    # Formatting
    axs[i].set_xlabel('Number of Subjects', fontsize=10)
    axs[i].set_ylabel('Statistical Power', fontsize=10)
    axs[i].set_xlim([0, 400])
    axs[i].set_ylim([0, 1])
    axs[i].axhline(y=0.8, color='gray', linestyle='--', alpha=0.5, label='80% Power')
    axs[i].legend(fontsize=9)
    axs[i].set_title(f'τ = {treatment_effect}', fontsize=11)
    axs[i].grid(True, alpha=0.3)

plt.suptitle('Exhibit 10.4: Power Analysis - Within vs. Between Subjects Designs',
             fontsize=12, y=1.02)
plt.tight_layout()

# Save figure
output_file = OUTPUT_DIR / "exhibit_10_4.png"
plt.savefig(output_file, dpi=400, bbox_inches='tight')
print(f"✓ Saved to: {output_file}\n")

plt.show()


# =============================================================================
# END OF EXHIBIT 10.4
# =============================================================================
