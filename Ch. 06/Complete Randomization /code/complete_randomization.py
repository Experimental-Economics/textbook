# =============================================================================
# Complete Randomization
# =============================================================================
# Implements Complete Randomization to assign treatment status to observations
# in a dataset. Exactly n/2 units are assigned to treatment (or n/2 +- 0.5 if n is odd),
# with the remaining units assigned to control.

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


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
input_file = DATA_DIR / "unique_data_clean_main_synthetic.dta"
data = pd.read_stata(input_file)


# --- Apply Complete randomization --------------------------------------------
# Apply randomization with fixed seed for reproducibility
randomized_data = complete_randomize(
    data=data,
    seed=None
)


# --- Print summary statistics ------------------------------------------------
n_total = len(randomized_data)
n_treatment = randomized_data['Treatment'].sum()
n_control = n_total - n_treatment
actual_proportion = n_treatment / n_total

print("\n" + "=" * 80)
print("COMPLETE RANDOMIZATION SUMMARY")
print("=" * 80)
print(f"Total observations:                {n_total:,}")
print(f"Assigned to treatment:             {n_treatment:,}")
print(f"Assigned to control:               {n_control:,}")
print(f"Treatment proportion:              {actual_proportion:.3f}")
print(f"Sample size difference:            {abs(n_treatment - n_control):,}")
print("=" * 80)
print("\nNote: Complete randomization fixes the number of treated units at n/2,")
print("      ensuring balanced group sizes. If n is odd, the extra observation")
print("      is randomly assigned to either treatment or control.")


# --- Save randomized dataset -------------------------------------------------
# Save to output directory
# TODO: Replace 'randomized_dataset.dta' with your desired output filename
output_file = OUTPUT_DIR / "randomized_dataset.dta"
randomized_data.to_stata(output_file, write_index=False)

print(f"\n✓ Saved to: {output_file}\n")

# =============================================================================
# END OF COMPLETE RANDOMIZATION
# =============================================================================
