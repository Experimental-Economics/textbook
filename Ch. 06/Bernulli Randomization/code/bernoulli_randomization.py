# =============================================================================
# Bernoulli Randomization
# =============================================================================
# Implements Bernoulli randomization to assign treatment status to observations
# in a dataset. Each unit is independently assigned to treatment with probability p
# and to control with probability 1-p.

from pathlib import Path
import numpy as np
import pandas as pd


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Bernoulli randomization function ----------------------------------------
def bernoulli_randomize(data, probability, seed=None):
    """
    Assign treatment status using Bernoulli randomization.

    Each observation is independently assigned to treatment with probability p
    and to control with probability 1-p. This allows the number of treated
    units to vary randomly (unlike complete randomization which fixes it).

    Parameters
    ----------
    data : pd.DataFrame
        Input dataset to which treatment will be assigned.
    probability : float
        Probability of assignment to treatment (must be between 0 and 1).
    seed : int, optional
        Random seed for reproducibility. If None, randomization is not reproducible.

    Returns
    -------
    pd.DataFrame
        Dataset with new 'Treatment' variable (1 = treatment, 0 = control).

    Raises
    ------
    ValueError
        If probability is not between 0 and 1.
    """
    # Validate probability parameter
    if not 0 <= probability <= 1:
        raise ValueError(f"Probability must be between 0 and 1, got {probability}")

    # Create a copy to avoid modifying the original dataset
    randomized_data = data.copy()

    # Set random seed if provided
    if seed is not None:
        np.random.seed(seed)

    # Generate random draws from uniform distribution
    # Assign treatment if random draw < probability
    random_draws = np.random.uniform(0, 1, size=len(randomized_data))
    randomized_data['Treatment'] = (random_draws < probability).astype(int)

    return randomized_data


# --- Load data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
input_file = DATA_DIR / "unique_data_clean_main_synthetic.dta"
data = pd.read_stata(input_file)


# --- Apply Bernoulli randomization -------------------------------------------
# Set treatment probability (default: 0.5 for equal allocation)
TREATMENT_PROBABILITY = 0.5

# Apply randomization with fixed seed for reproducibility
randomized_data = bernoulli_randomize(
    data=data,
    probability=TREATMENT_PROBABILITY,
    seed=None
)


# --- Print summary statistics ------------------------------------------------
n_total = len(randomized_data)
n_treatment = randomized_data['Treatment'].sum()
n_control = n_total - n_treatment
actual_proportion = n_treatment / n_total

print("\n" + "=" * 80)
print("BERNOULLI RANDOMIZATION SUMMARY")
print("=" * 80)
print(f"Treatment probability (p):        {TREATMENT_PROBABILITY:.3f}")
print(f"Total observations:                {n_total:,}")
print(f"Assigned to treatment:             {n_treatment:,}")
print(f"Assigned to control:               {n_control:,}")
print(f"Actual treatment proportion:       {actual_proportion:.3f}")
print(f"Expected number treated (n*p):     {n_total * TREATMENT_PROBABILITY:.1f}")
print("=" * 80)


# --- Save randomized dataset -------------------------------------------------
# Save to output directory
# TODO: Replace 'randomized_dataset.dta' with your desired output filename
output_file = OUTPUT_DIR / "randomized_dataset.dta"
randomized_data.to_stata(output_file, write_index=False)

print(f"\n✓ Saved to: {output_file}\n")

# =============================================================================
# END OF BERNOULLI RANDOMIZATION
# =============================================================================
