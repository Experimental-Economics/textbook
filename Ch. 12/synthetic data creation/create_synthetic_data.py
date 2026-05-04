# =============================================================================
# Synthetic Data Creation for Chapter 12
# =============================================================================
# Creates synthetic CHECC data for testing and demonstration purposes.
# This script generates 1000 observations with the same structure as the
# original CHECC dataset but with randomized values.
#
# Output: unique_data_clean_main_synthetic.dta (Stata format)

from pathlib import Path
import numpy as np
import pandas as pd


# --- Setup -------------------------------------------------------------------
# Set random seed for reproducibility
np.random.seed(42)

# Automatically resolve paths relative to this script's location
SCRIPT_DIR = Path(__file__).resolve().parent
CH12_DIR = SCRIPT_DIR.parent

# Find all Exhibit folders in Ch. 12
EXHIBIT_FOLDERS = sorted([d for d in CH12_DIR.glob("Exhibit*") if d.is_dir()])


# --- Generate synthetic data -------------------------------------------------
# Sample size
N = 1000

# Create synthetic data with same structure as CHECC dataset
data = pd.DataFrame({
    # Treatment assignment
    'treatment': np.random.choice(['prek', 'control'], size=N),

    # Exclusion criteria
    'kinderprep': np.random.choice([0, 1], size=N, p=[0.8, 0.2]),
    'late_randomized': np.random.choice([0, 1], size=N, p=[0.8, 0.2]),

    # Block identifiers
    'block_2012': np.random.choice(['', 'A', 'B', 'C', 'D'], size=N),
    'block_2013': np.random.choice(['', 'A', 'B', 'C', 'D'], size=N),

    # Outcome availability indicators
    'has_cog_sl': np.random.choice([0, 1], size=N, p=[0.3, 0.7]),
    'has_cog_pre': np.random.choice([0, 1], size=N, p=[0.3, 0.7]),

    # Outcome variables (standardized cognitive and non-cognitive scores)
    'std_cog_sl': np.random.normal(0, 1, size=N),
    'std_ncog_sl': np.random.normal(0, 1, size=N),
    'std_cog_pre': np.random.normal(0, 1, size=N),
    'std_ncog_pre': np.random.normal(0, 1, size=N),

    # Demographic covariates
    'female': np.random.choice([0, 1], size=N, p=[0.5, 0.5]),
    'race_w': np.random.choice([0, 1], size=N, p=[0.3, 0.7]),
    'hl_eng_span': np.random.choice([0, 1], size=N, p=[0.3, 0.7]),
    'birthweight': np.random.choice([1.0, 1.5, 2.0, 3.0], size=N, p=[0.3, 0.2, 0.3, 0.2]),

    # Year indicator
    'year': np.random.choice(range(2011, 2019), size=N)
})

# Set missing values where has_cog_sl = 0
data.loc[data['has_cog_sl'] == 0, 'std_cog_sl'] = np.nan

# Set missing values where has_cog_pre = 0
data.loc[data['has_cog_pre'] == 0, 'std_cog_pre'] = np.nan


# --- Save output -------------------------------------------------------------
# Save as Stata file to all exhibit data folders (overwrites if exists)
print("\nSaving synthetic data to all exhibit folders...")
for exhibit_folder in EXHIBIT_FOLDERS:
    data_dir = exhibit_folder / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    output_file = data_dir / "unique_data_clean_main_synthetic.dta"
    data.to_stata(output_file, write_index=False)
    print(f"  ✓ {exhibit_folder.name}/data/unique_data_clean_main_synthetic.dta")

# Print summary statistics
print("\n" + "=" * 80)
print("SYNTHETIC DATA SUMMARY")
print("=" * 80)
print(f"Total observations: {len(data)}")
print(f"\nTreatment distribution:")
print(data['treatment'].value_counts())
print(f"\nYear distribution:")
print(data['year'].value_counts().sort_index())
print("=" * 80)

# =============================================================================
# END OF SYNTHETIC DATA CREATION
# =============================================================================
