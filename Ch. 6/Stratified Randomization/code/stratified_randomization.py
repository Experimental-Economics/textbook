# =============================================================================
# Stratified Randomization
# =============================================================================
# Implements Stratified Randomization (also called Block Randomization) to assign
# treatment status within strata defined by baseline covariates. This ensures
# balance on the stratification variables and can improve precision of treatment
# effect estimates.
#
# The procedure:
# 1. Partition the sample into strata based on specified covariates
# 2. Apply Complete Randomization within each stratum
# 3. Combine the randomized strata back together


from pathlib import Path
import numpy as np
import pandas as pd

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


# --- Stratified randomization function ---------------------------------------
def stratified_randomize(data, categorical_vars=None, continuous_vars=None, seed=None):
    """
    Assign treatment status using Stratified Randomization.

    Partitions the sample into strata based on specified variables, then
    applies Complete Randomization within each stratum. This ensures exact
    balance on stratification variables and preserves the original row order.

    Categorical variables are split by their unique values. Continuous variables
    are split at the median (calculated from the full dataset) into two groups:
    <= median and > median.

    Parameters
    ----------
    data : pd.DataFrame
        Input dataset to which treatment will be assigned.
    categorical_vars : list of str, optional
        List of categorical variable names to use for stratification. The dataset
        will be split into all unique values of these variables.
    continuous_vars : list of str, optional
        List of continuous variable names to use for stratification. The dataset
        will be split at the median into <= median and > median groups.
    seed : int, optional
        Random seed for reproducibility. If None, randomization is not reproducible.

    Returns
    -------
    pd.DataFrame
        Dataset with new 'Treatment' variable (1 = treatment, 0 = control),
        preserving the original row order.

    Raises
    ------
    ValueError
        If any stratification variable is not found in the dataset, or if both
        categorical_vars and continuous_vars are None.
    """
    # Handle default values
    if categorical_vars is None:
        categorical_vars = []
    if continuous_vars is None:
        continuous_vars = []

    # Validate that at least one stratification variable is provided
    if len(categorical_vars) == 0 and len(continuous_vars) == 0:
        raise ValueError("Must provide at least one stratification variable (categorical or continuous)")

    # Combine all stratification variables for validation
    all_strata_vars = categorical_vars + continuous_vars

    # Validate that all stratification variables exist in the dataset
    missing_vars = [var for var in all_strata_vars if var not in data.columns]
    if missing_vars:
        raise ValueError(f"Stratification variables not found in data: {', '.join(missing_vars)}")

    # Create a copy to avoid modifying the original dataset
    randomized_data = data.copy()

    # Create temporary variable to preserve original order
    randomized_data['_original_order'] = range(len(randomized_data))

    # Calculate medians for continuous variables from the FULL dataset
    # This ensures consistent split points across all strata
    medians = {}
    for cont_var in continuous_vars:
        medians[cont_var] = randomized_data[cont_var].median()

    # Initialize list with the full dataset
    y = [randomized_data]

    # Iteratively split by each stratification variable
    for strata_var in all_strata_vars:
        z = []  # Empty list for this iteration's splits

        # Determine if this is a continuous or categorical variable
        is_continuous = strata_var in continuous_vars

        # Split each dataset in y by the current stratification variable
        for dataset in y:
            if is_continuous:
                # Continuous variable: split at the median
                median_value = medians[strata_var]

                # Split into <= median and > median
                stratum_low = dataset[dataset[strata_var] <= median_value].copy()
                stratum_high = dataset[dataset[strata_var] > median_value].copy()

                # Add non-empty strata
                if len(stratum_low) > 0:
                    z.append(stratum_low)
                if len(stratum_high) > 0:
                    z.append(stratum_high)

            else:
                # Categorical variable: split by unique values
                unique_values = dataset[strata_var].dropna().unique()

                # Split dataset by each unique value
                for value in unique_values:
                    stratum = dataset[dataset[strata_var] == value].copy()
                    if len(stratum) > 0:  # Only add non-empty strata
                        z.append(stratum)

        # Replace y with the newly split datasets
        y = z

    # Apply Complete Randomization within each stratum
    randomized_strata = []
    for i, stratum in enumerate(y):
        # Use different seed for each stratum if seed is provided
        stratum_seed = seed + i if seed is not None else None
        randomized_stratum = complete_randomize(stratum, seed=stratum_seed)
        randomized_strata.append(randomized_stratum)

    # Combine all randomized strata back together
    combined_data = pd.concat(randomized_strata, ignore_index=True)

    # Restore original order using temporary variable
    combined_data = combined_data.sort_values('_original_order').reset_index(drop=True)

    # Drop temporary variable
    combined_data = combined_data.drop(columns=['_original_order'])

    return combined_data


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace 'input_dataset.dta' with your actual dataset filename
input_file = DATA_DIR / "unique_data_clean_main_synthetic.dta"
data = pd.read_stata(input_file)


# --- Apply Stratified randomization ------------------------------------------
# Define stratification variables
# Use baseline characteristics known before treatment assignment
CATEGORICAL_VARIABLES = ['female', 'race_w']
CONTINUOUS_VARIABLES = ['std_cog_pre', 'birthweight']

# Apply randomization with fixed seed for reproducibility
randomized_data = stratified_randomize(
    data=data,
    categorical_vars=CATEGORICAL_VARIABLES,
    continuous_vars=CONTINUOUS_VARIABLES,
    seed=42
)


# --- Print summary statistics ------------------------------------------------
n_total = len(randomized_data)
n_treatment = randomized_data['Treatment'].sum()
n_control = n_total - n_treatment
actual_proportion = n_treatment / n_total

# Combine all stratification variables for display
all_strata_vars = CATEGORICAL_VARIABLES + CONTINUOUS_VARIABLES

print("\n" + "=" * 80)
print("STRATIFIED RANDOMIZATION SUMMARY")
print("=" * 80)
if len(CATEGORICAL_VARIABLES) > 0:
    print(f"Categorical variables:             {', '.join(CATEGORICAL_VARIABLES)}")
if len(CONTINUOUS_VARIABLES) > 0:
    print(f"Continuous variables (median split): {', '.join(CONTINUOUS_VARIABLES)}")
print(f"Total observations:                {n_total:,}")
print(f"Assigned to treatment:             {n_treatment:,}")
print(f"Assigned to control:               {n_control:,}")
print(f"Treatment proportion:              {actual_proportion:.3f}")
print("-" * 80)

# Print balance by stratification variables
print("\nBalance by Stratification Variables:")
print("-" * 80)

# Display categorical variables
for var in CATEGORICAL_VARIABLES:
    print(f"\n{var} (categorical):")
    balance = randomized_data.groupby(var)['Treatment'].agg(['sum', 'count'])
    balance['control'] = balance['count'] - balance['sum']
    balance.columns = ['Treatment', 'Total', 'Control']
    balance = balance[['Treatment', 'Control', 'Total']]
    print(balance.to_string())

# Display continuous variables with median split
for var in CONTINUOUS_VARIABLES:
    median_value = randomized_data[var].median()
    print(f"\n{var} (continuous, median = {median_value:.2f}):")

    # Create binary indicator for <= median vs > median
    median_split = (randomized_data[var] > median_value).astype(int)
    median_split_labels = median_split.map({0: f'<= {median_value:.2f}', 1: f'> {median_value:.2f}'})

    balance_df = pd.DataFrame({
        'median_split': median_split_labels,
        'Treatment': randomized_data['Treatment']
    })
    balance = balance_df.groupby('median_split')['Treatment'].agg(['sum', 'count'])
    balance['control'] = balance['count'] - balance['sum']
    balance.columns = ['Treatment', 'Total', 'Control']
    balance = balance[['Treatment', 'Control', 'Total']]
    print(balance.to_string())

print("\n" + "=" * 80)
print("\nNote: Stratified randomization ensures exact balance on stratification")
print("      variables by applying Complete Randomization within each stratum.")
print("      Continuous variables are split at the median calculated from the full dataset.")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory
# TODO: Replace 'stratified_randomized_dataset.dta' with your desired output filename
output_file = OUTPUT_DIR / "stratified_randomized_dataset.dta"
randomized_data.to_stata(output_file, write_index=False)

print(f"\n✓ Saved to: {output_file}\n")

# =============================================================================
# END OF STRATIFIED RANDOMIZATION
# =============================================================================
