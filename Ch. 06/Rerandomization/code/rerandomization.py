# =============================================================================
# Rerandomization
# =============================================================================
# Implements Rerandomization to improve covariate balance beyond what is
# achieved by standard Complete Randomization. The procedure repeatedly applies
# Complete Randomization and checks for significant imbalances on specified
# baseline covariates. If any covariate shows significant imbalance (p < threshold),
# the randomization is rejected and the process repeats.

from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Complete randomization function -----------------------------------------
def complete_randomize(data, seed=None):
    """
    Assign treatment status using Complete Randomization.

    Exactly half of the observations are assigned to treatment, with the
    remaining assigned to control. If the sample size is odd, the extra
    observation is randomly assigned to either treatment or control. The
    original row order of the dataset is preserved after randomization.

    Parameters
    ----------
    data : pd.DataFrame
        Input dataset to which treatment will be assigned.
    seed : int, optional
        Random seed for reproducibility. If None, randomization is not reproducible.

    Returns
    -------
    pd.DataFrame
        Dataset with new 'Treatment' variable (1 = treatment, 0 = control),
        preserving the original row order.
    """
    # Create a copy to avoid modifying the original dataset
    randomized_data = data.copy()

    # Create temporary variable to preserve original order
    randomized_data['_temp_order'] = range(len(randomized_data))

    # Set random seed if provided
    if seed is not None:
        np.random.seed(seed)

    # Shuffle the dataset
    randomized_data = randomized_data.sample(frac=1, random_state=seed).reset_index(drop=True)

    # Calculate split point: if odd, randomly assign the extra observation
    n_total = len(randomized_data)
    if n_total % 2 == 1:
        # Odd sample size: randomly decide which group gets the extra observation
        extra_to_treatment = np.random.choice([0, 1])
        n_treatment = n_total // 2 + extra_to_treatment
    else:
        # Even sample size: split evenly
        n_treatment = n_total // 2

    # Assign treatment to first half, control to second half
    randomized_data['Treatment'] = 0
    randomized_data.loc[:n_treatment - 1, 'Treatment'] = 1

    # Restore original order using temporary variable
    randomized_data = randomized_data.sort_values('_temp_order').reset_index(drop=True)

    # Drop temporary variable
    randomized_data = randomized_data.drop(columns=['_temp_order'])

    return randomized_data


# --- Balance checking function -----------------------------------------------
def check_balance(data, treatment_col, balance_vars, continuous_vars):
    """
    Check covariate balance between treatment groups.

    Tests whether there are significant differences in baseline covariates
    between treatment and control groups. Uses t-tests for continuous variables
    and z-tests for binary/categorical variables.

    Parameters
    ----------
    data : pd.DataFrame
        Dataset with treatment assignment.
    treatment_col : str
        Name of the treatment column.
    balance_vars : list of str
        List of variables to check for balance.
    continuous_vars : list of str
        List of variables that should be treated as continuous (use t-test).

    Returns
    -------
    dict
        Dictionary with p-values for each variable.
    bool
        True if all variables are balanced (all p-values >= threshold), False otherwise.
    float
        Minimum p-value across all variables.
    """
    p_values = {}

    for var in balance_vars:
        # Split by treatment group
        vals_control = data[data[treatment_col] == 0][var].dropna()
        vals_treatment = data[data[treatment_col] == 1][var].dropna()

        # Skip if either group has no observations
        if len(vals_control) == 0 or len(vals_treatment) == 0:
            p_values[var] = np.nan
            continue

        # Use t-test for continuous variables
        if var in continuous_vars:
            try:
                _, p_val = stats.ttest_ind(vals_control, vals_treatment, equal_var=False)
            except Exception:
                p_val = np.nan
        # Use z-test for proportions for binary/categorical variables
        else:
            try:
                p_control = vals_control.mean()
                p_treatment = vals_treatment.mean()
                n_control = len(vals_control)
                n_treatment = len(vals_treatment)
                se = np.sqrt(p_control * (1 - p_control) / n_control +
                           p_treatment * (1 - p_treatment) / n_treatment)
                if se == 0:
                    p_val = 1.0 if p_control == p_treatment else 0.0
                else:
                    z = (p_control - p_treatment) / se
                    p_val = 2 * stats.norm.sf(np.abs(z))
            except Exception:
                p_val = np.nan

        p_values[var] = p_val

    # Get minimum p-value (excluding NaN)
    valid_pvals = [p for p in p_values.values() if not np.isnan(p)]
    min_pval = min(valid_pvals) if len(valid_pvals) > 0 else np.nan

    return p_values, min_pval


# --- Rerandomization function ------------------------------------------------
def rerandomize(data, balance_vars, continuous_vars=None, significance_level=0.1,
                seed=None, max_attempts=1000):
    """
    Assign treatment status using Rerandomization.

    Repeatedly applies Complete Randomization until achieving acceptable
    covariate balance on all specified variables. Balance is checked using
    t-tests (continuous variables) or z-tests (binary variables). The process
    stops when all p-values exceed the significance threshold, or after
    max_attempts tries.

    Parameters
    ----------
    data : pd.DataFrame
        Input dataset to which treatment will be assigned.
    balance_vars : list of str
        List of variables to check for balance.
    continuous_vars : list of str, optional
        List of variables to treat as continuous (use t-test). If None,
        all variables are treated as binary/categorical (use z-test).
    significance_level : float, optional
        Significance threshold for balance tests. Randomization is rejected
        if any p-value is below this threshold. Default is 0.1.
    seed : int, optional
        Random seed for reproducibility. If None, randomization is not reproducible.
    max_attempts : int, optional
        Maximum number of rerandomization attempts. Default is 1000.

    Returns
    -------
    pd.DataFrame
        Dataset with new 'Treatment' variable (1 = treatment, 0 = control),
        preserving the original row order.
    int
        Number of rerandomizations performed before achieving balance.
    dict
        P-values for each balance variable in the final randomization.

    Raises
    ------
    ValueError
        If any balance variable is not found in the dataset.
    RuntimeError
        If acceptable balance is not achieved after max_attempts tries.
    """
    # Handle default values
    if continuous_vars is None:
        continuous_vars = []

    # Validate that all balance variables exist in the dataset
    missing_vars = [var for var in balance_vars if var not in data.columns]
    if missing_vars:
        raise ValueError(f"Balance variables not found in data: {', '.join(missing_vars)}")

    # Validate continuous variables
    invalid_continuous = [var for var in continuous_vars if var not in balance_vars]
    if invalid_continuous:
        raise ValueError(f"Continuous variables must be in balance_vars: {', '.join(invalid_continuous)}")

    # Track rerandomizations
    num_rerandomizations = 0
    balanced = False

    # Try up to max_attempts times
    for attempt in range(max_attempts):
        # Generate seed for this attempt
        attempt_seed = seed + attempt if seed is not None else None

        # Apply Complete Randomization
        randomized_data = complete_randomize(data, seed=attempt_seed)

        # Check balance
        p_values, min_pval = check_balance(
            randomized_data,
            treatment_col='Treatment',
            balance_vars=balance_vars,
            continuous_vars=continuous_vars
        )

        # Check if all p-values meet the threshold
        all_balanced = all(
            p >= significance_level or np.isnan(p)
            for p in p_values.values()
        )

        if all_balanced:
            balanced = True
            num_rerandomizations = attempt
            break

    # Check if we found a balanced randomization
    if not balanced:
        raise RuntimeError(
            f"Failed to achieve balance after {max_attempts} attempts. "
            f"Consider relaxing the significance level or reducing the number of balance variables."
        )

    return randomized_data, num_rerandomizations, p_values


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace 'input_dataset.dta' with your actual dataset filename
input_file = DATA_DIR / "unique_data_clean_main_synthetic.dta"
data = pd.read_stata(input_file)


# --- Apply Rerandomization ---------------------------------------------------
# Define balance variables
# Use baseline characteristics known before treatment assignment
BALANCE_VARIABLES = ['female', 'race_w', 'hl_eng_span', 'std_cog_pre', 'std_ncog_pre', 'birthweight']
CONTINUOUS_VARIABLES = ['std_cog_pre', 'std_ncog_pre', 'birthweight']  # Variables to treat as continuous

# Set significance level for balance tests
SIGNIFICANCE_LEVEL = 0.1  # Reject randomizations with any p-value < 0.1

# Apply rerandomization with fixed seed for reproducibility
randomized_data, num_attempts, final_pvalues = rerandomize(
    data=data,
    balance_vars=BALANCE_VARIABLES,
    continuous_vars=CONTINUOUS_VARIABLES,
    significance_level=SIGNIFICANCE_LEVEL,
    seed=42,
    max_attempts=1000
)


# --- Print summary statistics ------------------------------------------------
n_total = len(randomized_data)
n_treatment = randomized_data['Treatment'].sum()
n_control = n_total - n_treatment
actual_proportion = n_treatment / n_total

print("\n" + "=" * 80)
print("RERANDOMIZATION SUMMARY")
print("=" * 80)
print(f"Significance threshold:            {SIGNIFICANCE_LEVEL}")
print(f"Number of rerandomizations:        {num_attempts:,}")
print(f"Balance variables checked:         {len(BALANCE_VARIABLES)}")
print(f"Total observations:                {n_total:,}")
print(f"Assigned to treatment:             {n_treatment:,}")
print(f"Assigned to control:               {n_control:,}")
print(f"Treatment proportion:              {actual_proportion:.3f}")
print("-" * 80)

# Print balance check results
print("\nFinal Balance Check (p-values):")
print("-" * 80)
print(f"{'Variable':<20} {'Type':<15} {'p-value':<12} {'Status':<10}")
print("-" * 80)
for var in BALANCE_VARIABLES:
    var_type = "Continuous" if var in CONTINUOUS_VARIABLES else "Binary"
    pval = final_pvalues.get(var, np.nan)
    status = "Balanced" if pval >= SIGNIFICANCE_LEVEL else "IMBALANCED"

    if np.isnan(pval):
        print(f"{var:<20} {var_type:<15} {'N/A':<12} {'N/A':<10}")
    else:
        print(f"{var:<20} {var_type:<15} {pval:<12.4f} {status:<10}")

print("-" * 80)
min_pval = min([p for p in final_pvalues.values() if not np.isnan(p)])
print(f"Minimum p-value: {min_pval:.4f}")
print("=" * 80)

print("\nNote: Rerandomization improves covariate balance by rejecting randomizations")
print(f"      with any p-value below {SIGNIFICANCE_LEVEL}. Standard errors and confidence")
print("      intervals should be adjusted to account for the rerandomization procedure.")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory with number of rerandomizations in filename
# TODO: Replace 'rerandomized_dataset_rerandomizations.dta' with your desired output filename
output_file = OUTPUT_DIR / f"rerandomized_dataset_{num_attempts}_rerandomizations.dta"
randomized_data.to_stata(output_file, write_index=False)

print(f"\n✓ Saved to: {output_file}\n")

# =============================================================================
# END OF RERANDOMIZATION
# =============================================================================
