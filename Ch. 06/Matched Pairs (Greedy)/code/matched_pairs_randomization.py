# =============================================================================
# Matched-Pairs Randomization
# =============================================================================
# Implements Matched-Pairs Design (also called Pairwise Matching) to assign
# treatment status to observations. This is a limiting case of stratification
# where pairs of similar units are matched based on baseline covariates, and
# then one unit in each pair is randomly assigned to treatment.
#
# Performance optimizations:
# - Vectorized Mahalanobis distance calculation using numpy broadcasting and einsum
# - Vectorized greedy matching using numpy array indexing instead of nested loops
# - Vectorized string concatenation for stratum IDs instead of .apply()
# - These optimizations provide significant speedup for large datasets
#
# The procedure:
# 1. Create outer strata based on discrete/categorical variables
# 2. Within each outer stratum, calculate Mahalanobis distance between all
#    pairs of units using continuous covariates
# 3. Use greedy algorithm to match pairs:
#    - Find the two units with smallest pairwise distance
#    - Randomly assign one to treatment, one to control
#    - Remove both from the pool
#    - Repeat until all units are matched
# 4. If stratum has odd number of units, apply Complete Randomization (CRE)
#    to the unpaired unit

from pathlib import Path
import numpy as np
import pandas as pd
from scipy.spatial.distance import pdist, squareform
from scipy import stats


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Mahalanobis distance calculation ----------------------------------------
def mahalanobis_distances(data, continuous_vars):
    """
    Calculate pairwise Mahalanobis distances for all observations.

    Uses vectorized operations for efficient computation.

    Parameters
    ----------
    data : pd.DataFrame
        Dataset containing the continuous variables.
    continuous_vars : list of str
        List of continuous variable names to use for distance calculation.

    Returns
    -------
    np.ndarray
        Square distance matrix where element [i,j] is the Mahalanobis distance
        between observation i and observation j.
    """
    # Extract continuous variables as matrix
    X = data[continuous_vars].values

    # Calculate covariance matrix
    cov_matrix = np.cov(X, rowvar=False)

    # Calculate inverse covariance matrix (with regularization for stability)
    try:
        cov_inv = np.linalg.inv(cov_matrix)
    except np.linalg.LinAlgError:
        # If singular, add small regularization
        cov_inv = np.linalg.inv(cov_matrix + 1e-6 * np.eye(len(continuous_vars)))

    # Vectorized calculation of Mahalanobis distances
    # For each pair (i,j): distance = sqrt((X[i] - X[j])' * cov_inv * (X[i] - X[j]))

    # Expand dimensions for broadcasting: X_i and X_j
    X_expanded_i = X[:, np.newaxis, :]  # Shape: (n, 1, p)
    X_expanded_j = X[np.newaxis, :, :]  # Shape: (1, n, p)

    # Compute differences for all pairs at once
    diff = X_expanded_i - X_expanded_j  # Shape: (n, n, p)

    # Compute Mahalanobis distance using einsum for efficient matrix multiplication
    # dist[i,j] = sqrt(sum_k sum_l diff[i,j,k] * cov_inv[k,l] * diff[i,j,l])
    distances_squared = np.einsum('ijk,kl,ijl->ij', diff, cov_inv, diff)
    distances = np.sqrt(np.maximum(distances_squared, 0))  # Ensure non-negative due to numerical errors

    return distances


# --- Greedy matching algorithm -----------------------------------------------
def greedy_match_pairs(data, distances, seed=None):
    """
    Match pairs using greedy algorithm based on pairwise distances.

    Iteratively finds the pair with smallest distance, randomly assigns
    treatment/control, and removes both from the pool. If an odd number
    of units remains (always 0 or 1), applies Complete Randomization (CRE)
    to the unpaired unit.

    Parameters
    ----------
    data : pd.DataFrame
        Dataset to match.
    distances : np.ndarray
        Square matrix of pairwise distances.
    seed : int, optional
        Random seed for reproducibility.

    Returns
    -------
    pd.DataFrame
        Dataset with 'Treatment' and 'Pair_ID' columns added.
        Treatment: 1 (treatment) or 0 (control)
        Pair_ID: unique pair ID (>= 0) or -1 if unpaired
    int
        Number of units that could not be paired (0 or 1).
    """
    # Set random seed if provided
    if seed is not None:
        np.random.seed(seed)

    # Create copy of data and RESET INDEX to ensure 0-based indexing
    matched_data = data.reset_index(drop=True).copy()
    matched_data['Treatment'] = -1  # Initialize as unassigned
    matched_data['Pair_ID'] = -1    # Initialize as unpaired

    # Track which units are still available for matching
    available = np.arange(len(matched_data))
    pair_counter = 0


    # Continue until fewer than 2 units remain
    while len(available) >= 2:
        # Create submatrix of distances for available units only
        # This is more efficient than checking all pairs
        available_distances = distances[np.ix_(available, available)]

        # Set diagonal to infinity to avoid self-matching
        np.fill_diagonal(available_distances, np.inf)

        # Find the pair with minimum distance using vectorized operations
        # This is much faster than nested loops
        min_idx = np.argmin(available_distances)
        best_i_local = min_idx // len(available)
        best_j_local = min_idx % len(available)

        # Convert local indices back to original indices
        best_i = available[best_i_local]
        best_j = available[best_j_local]

        # Randomly assign treatment to one unit in the pair
        treat_unit, control_unit = (best_i, best_j) if np.random.rand() < 0.5 else (best_j, best_i)

        # Assign treatment status and pair ID
        matched_data.loc[treat_unit, 'Treatment'] = 1
        matched_data.loc[control_unit, 'Treatment'] = 0
        matched_data.loc[treat_unit, 'Pair_ID'] = pair_counter
        matched_data.loc[control_unit, 'Pair_ID'] = pair_counter

        # Remove matched units from available pool using numpy operations
        mask = (available != best_i) & (available != best_j)
        available = available[mask]

        pair_counter += 1

    # Handle unmatched units with Complete Randomization
    n_unmatched = len(available)

    if n_unmatched > 0:
        # Apply CRE to unmatched unit(s)
        # For odd stratum: 1 unit remains, randomly assign to treatment or control
        for unit in available:
            matched_data.loc[unit, 'Treatment'] = np.random.choice([0, 1])
            matched_data.loc[unit, 'Pair_ID'] = -1  # Mark as unpaired
    
    return matched_data, n_unmatched


# --- Matched-pairs randomization function ------------------------------------
def matched_pairs_randomize(data, categorical_vars=None, continuous_vars=None, seed=None):
    """
    Assign treatment status using Matched-Pairs Randomization.

    Creates outer strata based on categorical variables, then matches pairs
    within each stratum using Mahalanobis distance on continuous variables.
    Uses greedy algorithm to find best matches and randomly assigns treatment
    within each pair.

    Parameters
    ----------
    data : pd.DataFrame
        Input dataset to which treatment will be assigned.
    categorical_vars : list of str, optional
        List of categorical variable names to create outer strata.
        If None, all observations are in a single stratum.
    continuous_vars : list of str, optional
        List of continuous variable names for Mahalanobis distance calculation.
        Required for matching.
    seed : int, optional
        Random seed for reproducibility. If None, randomization is not reproducible.

    Returns
    -------
    pd.DataFrame
        Dataset with 'Treatment' variable (1 = treatment, 0 = control),
        'Pair_ID' variable (unique ID for each matched pair, -1 = unpaired),
        and 'Stratum_ID' variable (identifies outer strata).

        Note: Units in strata with odd sizes are assigned treatment via Complete
        Randomization (CRE) but have Pair_ID = -1 to indicate they were not paired.

    Raises
    ------
    ValueError
        If continuous_vars is not provided or if variables are not found in dataset.
    """
    # Validate inputs
    if continuous_vars is None or len(continuous_vars) == 0:
        raise ValueError("Must provide at least one continuous variable for matching")

    if categorical_vars is None:
        categorical_vars = []

    # Validate that all variables exist in the dataset
    all_vars = categorical_vars + continuous_vars
    missing_vars = [var for var in all_vars if var not in data.columns]
    if missing_vars:
        raise ValueError(f"Variables not found in data: {', '.join(missing_vars)}")

    # Create copy to avoid modifying original
    randomized_data = data.copy()
    randomized_data['_original_order'] = range(len(randomized_data))

    # Create outer strata based on categorical variables
    if len(categorical_vars) > 0:
        # Combine categorical variables to create stratum identifier
        # Using vectorized string operations instead of .apply() for speed
        if len(categorical_vars) == 1:
            randomized_data['Stratum_ID'] = randomized_data[categorical_vars[0]].astype(str)
        else:
            # Vectorized string concatenation
            randomized_data['Stratum_ID'] = randomized_data[categorical_vars[0]].astype(str)
            for var in categorical_vars[1:]:
                randomized_data['Stratum_ID'] = randomized_data['Stratum_ID'] + '_' + randomized_data[var].astype(str)
        strata = randomized_data.groupby('Stratum_ID')
    else:
        # Single stratum containing all observations
        randomized_data['Stratum_ID'] = 0
        strata = [(0, randomized_data)]

    # Initialize output columns
    randomized_data['Treatment'] = -1
    randomized_data['Pair_ID'] = -1

    # Process each stratum
    matched_strata = []
    total_unmatched = 0
    pair_id_offset = 0

    for stratum_id, stratum_data in strata:
        # Use different seed for each stratum if seed is provided
        stratum_seed = seed + hash(str(stratum_id)) % 10000 if seed is not None else None

        if len(stratum_data) < 1:
            # Empty stratum - skip
            continue

        if len(stratum_data) == 1:
            # Single observation - apply CRE (Complete Randomization)
            if stratum_seed is not None:
                np.random.seed(stratum_seed)
            stratum_matched = stratum_data.copy()
            stratum_matched['Treatment'] = np.random.choice([0, 1])
            stratum_matched['Pair_ID'] = -1
            matched_strata.append(stratum_matched)
            total_unmatched += 1
            continue

        # Calculate Mahalanobis distances within this stratum
        distances = mahalanobis_distances(stratum_data, continuous_vars)

        # Match pairs using greedy algorithm
        stratum_matched, n_unmatched = greedy_match_pairs(
            stratum_data,
            distances,
            seed=stratum_seed
        )

        # Adjust Pair_ID to be globally unique
        stratum_matched.loc[stratum_matched['Pair_ID'] >= 0, 'Pair_ID'] += pair_id_offset
        max_pair_id = stratum_matched['Pair_ID'].max()
        if max_pair_id >= 0:
            pair_id_offset = max_pair_id + 1  # Set to next available ID (not +=)

        matched_strata.append(stratum_matched)
        total_unmatched += n_unmatched

    # Combine all strata

    combined_data = pd.concat(matched_strata, ignore_index=True)

    # Restore original order
    combined_data = combined_data.sort_values('_original_order').reset_index(drop=True)
    combined_data = combined_data.drop(columns=['_original_order'])

    return combined_data


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace with your actual dataset filename
input_file = DATA_DIR / "unique_data_clean_main_synthetic.dta"
data = pd.read_stata(input_file)


# --- Apply Matched-Pairs randomization ---------------------------------------
# TODO: Define variables for matching
# Categorical variables create outer strata (discrete/binary variables)
# These should be variables like gender, race, location, etc.
CATEGORICAL_VARIABLES = ['female', 'race_w']

# TODO: Continuous variables used for Mahalanobis distance calculation
# These should be numeric variables like test scores, age, income, etc.
# The algorithm will match units with similar values on these variables
CONTINUOUS_VARIABLES = ['std_cog_pre', 'birthweight', 'std_ncog_pre', 'year']

# TODO: Set random seed for reproducibility
# Change to any integer for different randomization results
# Apply randomization with fixed seed for reproducibility
randomized_data = matched_pairs_randomize(
    data=data,
    categorical_vars=CATEGORICAL_VARIABLES,
    continuous_vars=CONTINUOUS_VARIABLES,
    seed=42
)


# --- Print summary statistics ------------------------------------------------
n_total = len(randomized_data)
n_treatment = (randomized_data['Treatment'] == 1).sum()
n_control = (randomized_data['Treatment'] == 0).sum()
n_paired = (randomized_data['Pair_ID'] >= 0).sum()
n_unpaired = (randomized_data['Pair_ID'] == -1).sum()
n_pairs = randomized_data[randomized_data['Pair_ID'] >= 0]['Pair_ID'].nunique()

print("\n" + "=" * 80)
print("MATCHED-PAIRS RANDOMIZATION SUMMARY")
print("=" * 80)
if len(CATEGORICAL_VARIABLES) > 0:
    print(f"Categorical variables (outer strata): {', '.join(CATEGORICAL_VARIABLES)}")
print(f"Continuous variables (matching):      {', '.join(CONTINUOUS_VARIABLES)}")
print(f"Total observations:                   {n_total:,}")
print(f"Matched pairs:                        {n_pairs:,}")
print(f"  - Paired units:                     {n_paired:,}")
print(f"  - Unpaired units (CRE):             {n_unpaired:,}")
print(f"Assigned to treatment:                {n_treatment:,}")
print(f"Assigned to control:                  {n_control:,}")
print("-" * 80)

# Summary by strata
if len(CATEGORICAL_VARIABLES) > 0:
    print("\nMatching Summary by Stratum:")
    print("-" * 80)

    stratum_summary = randomized_data.groupby('Stratum_ID').agg({
        'Pair_ID': lambda x: [(x >= 0).sum() // 2, (x == -1).sum()],  # Pairs and unpaired
        'Treatment': lambda x: [(x == 1).sum(), (x == 0).sum()]
    })

    for stratum_id, row in stratum_summary.iterrows():
        pair_counts = row['Pair_ID']
        n_pairs_stratum = pair_counts[0]
        n_unpaired = pair_counts[1]
        treat_counts = row['Treatment']
        n_treat = treat_counts[0]
        n_ctrl = treat_counts[1]

        print(f"\nStratum: {stratum_id}")
        print(f"  Pairs:      {n_pairs_stratum:,}")
        print(f"  Treatment:  {n_treat:,}")
        print(f"  Control:    {n_ctrl:,}")
        if n_unpaired > 0:
            print(f"  Unpaired (CRE): {n_unpaired:,}")

print("\n" + "=" * 80)
print("\nNote: Matched-pairs design creates pairs of similar units based on")
print("      Mahalanobis distance using continuous variables. Within outer strata")
print("      defined by categorical variables, pairs are matched using a greedy")
print("      algorithm (smallest distance first), and treatment is randomly assigned")
print("      within each pair.")
print("")
print("      Units in strata with odd sizes cannot be paired. These unpaired units")
print("      are assigned to treatment or control using Complete Randomization (CRE).")
print("      They have Pair_ID = -1 to distinguish them from paired units.")


# --- Validation: Check Each Pair has 1 Treatment and 1 Control ---------------
print("\n" + "=" * 80)
print("PAIR VALIDATION")
print("=" * 80)

# Check pairs (exclude unpaired units with Pair_ID == -1)
paired_data = randomized_data[randomized_data['Pair_ID'] >= 0]

if len(paired_data) > 0:
    # Group by Pair_ID and check treatment assignment
    pair_check = paired_data.groupby('Pair_ID').agg({
        'Treatment': ['sum', 'count']
    })
    pair_check.columns = ['Treatment_Sum', 'Pair_Size']

    # Each pair should have exactly 2 units
    bad_size = pair_check[pair_check['Pair_Size'] != 2]
    if len(bad_size) > 0:
        print(f"❌ ERROR: Found {len(bad_size)} pairs with size != 2")
        print(bad_size)
    else:
        print(f"✓ All {len(pair_check)} pairs have exactly 2 units")

    # Each pair should have sum(Treatment) == 1 (one 1, one 0)
    bad_treatment = pair_check[pair_check['Treatment_Sum'] != 1]
    if len(bad_treatment) > 0:
        print(f"❌ ERROR: Found {len(bad_treatment)} pairs without 1 treatment + 1 control")
        print(bad_treatment)
    else:
        print(f"✓ All {len(pair_check)} pairs have exactly 1 treatment and 1 control")
else:
    print("⚠ No paired units found")

print("=" * 80)


# --- Balance Table for Debugging ---------------------------------------------
print("\n" + "=" * 80)
print("BALANCE TABLE (for debugging)")
print("=" * 80)

# Get all variables to check (categorical + continuous)
balance_vars = CATEGORICAL_VARIABLES + CONTINUOUS_VARIABLES

# Calculate means by treatment group
treatment_data = randomized_data[randomized_data['Treatment'] == 1]
control_data = randomized_data[randomized_data['Treatment'] == 0]

balance_results = []
for var in balance_vars:
    mean_treat = treatment_data[var].mean()
    mean_control = control_data[var].mean()
    diff = mean_treat - mean_control

    # Calculate standardized difference
    pooled_sd = np.sqrt((treatment_data[var].var() + control_data[var].var()) / 2)
    std_diff = diff / pooled_sd if pooled_sd > 0 else 0

    # Simple t-test
    t_stat, p_value = stats.ttest_ind(treatment_data[var], control_data[var], nan_policy='omit')

    balance_results.append({
        'Variable': var,
        'Mean_Treatment': mean_treat,
        'Mean_Control': mean_control,
        'Difference': diff,
        'Std_Diff': std_diff,
        'p_value': p_value
    })

balance_df = pd.DataFrame(balance_results)

print("\nBalance across covariates:")
print("-" * 80)
print(f"{'Variable':<20} {'Treat':<10} {'Control':<10} {'Diff':<10} {'Std_Diff':<10} {'p-value':<10}")
print("-" * 80)
for _, row in balance_df.iterrows():
    sig = "***" if row['p_value'] < 0.001 else ("**" if row['p_value'] < 0.01 else ("*" if row['p_value'] < 0.05 else ""))
    print(f"{row['Variable']:<20} {row['Mean_Treatment']:<10.3f} {row['Mean_Control']:<10.3f} "
          f"{row['Difference']:<10.3f} {row['Std_Diff']:<10.3f} {row['p_value']:<10.4f} {sig}")

print("-" * 80)
print("\nNote: * p<0.05, ** p<0.01, *** p<0.001")
print("Standardized difference > 0.1 may indicate imbalance")
print("=" * 80)
print("")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory
# TODO: Replace with your desired output filename
output_file = OUTPUT_DIR / "matched_pairs_randomized_dataset.dta"
randomized_data.to_stata(output_file, write_index=False)

print(f"\n✓ Saved to: {output_file}\n")

# =============================================================================
# END OF MATCHED-PAIRS RANDOMIZATION
# =============================================================================
