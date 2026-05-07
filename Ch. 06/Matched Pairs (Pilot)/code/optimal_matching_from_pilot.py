# =============================================================================
# Optimal Matched-Pairs Randomization Using Pilot Study
# =============================================================================
# Implements optimal matched-pairs randomization based on Bai (2022) framework
# for minimizing mean-squared error. Uses pilot study regression to estimate
# expected outcomes g_i = E[Y_i(1) + Y_i(0) | X_i] for main sample, then creates
# matched pairs by sorting on g_i and pairing adjacent units.
#
# Steps:
#   1. Load pilot data (with Treatment and Outcome from previous randomization)
#   2. Run regression on pilot to estimate relationship between covariates and outcomes
#   3. For main sample: predict outcomes under D=0 and D=1
#   4. Calculate g_hat = g_0 + g_1 for each unit
#   5. Sort main sample by g_hat
#   6. Create matched pairs from sorted data (pair adjacent units)
#   7. Within each pair, randomly assign treatment
#
# Section 6.3.5.1: Efficient Matching Minimizing Mean-Squared Error

from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Parameters --------------------------------------------------------------
# TODO: Set random seed for reproducibility
RANDOM_SEED = 42

# TODO: Specify control variables to use in g_i estimation
# These should be the covariates available in your dataset
# IMPORTANT: Must match the control variables used in the pilot regression
CONTROL_VARS = ['female', 'race_w', 'birthweight', 'std_ncog_pre', 'year']


# --- Initialize random state -------------------------------------------------
np.random.seed(RANDOM_SEED)


# --- Load pilot data and estimate g_i model ---------------------------------
# TODO: Specify the pilot data file
# This file should contain:
#   - Treatment variable (0/1 or binary)
#   - Outcome variable (continuous)
#   - All control variables specified in CONTROL_VARS
pilot_file = OUTPUT_DIR / 'pilot_sample_with_treatment_and_outcome.dta'
pilot_data = pd.read_stata(pilot_file)

# Prepare regression data (drop missing values in controls)
reg_vars = ['Outcome', 'Treatment'] + CONTROL_VARS
pilot_reg = pilot_data[reg_vars].dropna().copy()

# TODO: Modify regression specification if desired
# You can add interaction effects, polynomials, or other transformations
# Example: X['interaction'] = X['female'] * X['race_w']
# Example: X['birthweight_sq'] = X['birthweight'] ** 2
# Run regression: Outcome ~ Treatment + Controls
X = pilot_reg[['Treatment'] + CONTROL_VARS]
X = sm.add_constant(X)
y = pilot_reg['Outcome']

pilot_model = sm.OLS(y, X).fit()


# --- Load main sample and estimate g_0 and g_1 ------------------------------
# TODO: Specify the main sample data file
# This file should contain:
#   - All control variables specified in CONTROL_VARS
#   - NO Treatment variable (will be assigned by this script)
main_file = OUTPUT_DIR / 'main_sample.dta'
main_data = pd.read_stata(main_file)

# Keep only complete cases for prediction
main_complete = main_data[CONTROL_VARS].dropna().copy()
main_complete['original_index'] = main_complete.index

# TODO: If you modified the regression specification above,
# you must apply the SAME transformations here for prediction
# Example: If you added X['interaction'] = X['female'] * X['race_w'] above,
#          you must also add main_complete_d0['interaction'] = ... and main_complete_d1['interaction'] = ... below
# Predict under D=0 (Treatment=0)
main_complete_d0 = main_complete[CONTROL_VARS].copy()
main_complete_d0['Treatment'] = 0
X_d0 = sm.add_constant(main_complete_d0[['Treatment'] + CONTROL_VARS], has_constant='add')
g_0 = pilot_model.predict(X_d0)

# Predict under D=1 (Treatment=1)
main_complete_d1 = main_complete[CONTROL_VARS].copy()
main_complete_d1['Treatment'] = 1
X_d1 = sm.add_constant(main_complete_d1[['Treatment'] + CONTROL_VARS], has_constant='add')
g_1 = pilot_model.predict(X_d1)

# Add predictions to main_complete
main_complete['g_0'] = g_0
main_complete['g_1'] = g_1

# Calculate g_hat = g_0 + g_1
main_complete['g_hat'] = main_complete['g_0'] + main_complete['g_1']


# --- Sort by g_hat and create matched pairs ---------------------------------
# Sort by g_hat (increasing order)
sorted_data = main_complete.sort_values('g_hat').reset_index(drop=True)

# Create pairs from adjacent units in sorted order
n_units = len(sorted_data)
n_pairs = n_units // 2
n_unpaired = n_units % 2

# Initialize treatment and pair ID columns
sorted_data['Treatment_Final'] = -1
sorted_data['Pair_ID'] = -1

pair_id = 0

# Create pairs from adjacent units
for i in range(0, n_pairs * 2, 2):
    if i + 1 < len(sorted_data):
        # Randomly assign treatment within pair
        if np.random.random() < 0.5:
            sorted_data.loc[i, 'Treatment_Final'] = 1
            sorted_data.loc[i+1, 'Treatment_Final'] = 0
        else:
            sorted_data.loc[i, 'Treatment_Final'] = 0
            sorted_data.loc[i+1, 'Treatment_Final'] = 1

        # Assign same pair ID
        sorted_data.loc[i, 'Pair_ID'] = pair_id
        sorted_data.loc[i+1, 'Pair_ID'] = pair_id

        pair_id += 1

# Handle unpaired unit (if odd number of units)
if n_unpaired > 0:
    sorted_data.loc[len(sorted_data)-1, 'Treatment_Final'] = np.random.randint(0, 2)
    sorted_data.loc[len(sorted_data)-1, 'Pair_ID'] = -1


# --- Validate matching quality -----------------------------------------------
# Calculate within-pair differences in g_hat
paired_data = sorted_data[sorted_data['Pair_ID'] >= 0].copy()

if len(paired_data) > 0:
    pairs_list = []
    for pid in paired_data['Pair_ID'].unique():
        pair = paired_data[paired_data['Pair_ID'] == pid]
        if len(pair) == 2:
            g_vals = pair['g_hat'].values
            g_diff = abs(g_vals[0] - g_vals[1])
            g_mean = (g_vals[0] + g_vals[1]) / 2
            pairs_list.append({
                'Pair_ID': pid,
                'g_hat_diff': g_diff,
                'g_hat_mean': g_mean
            })

    pairs_df = pd.DataFrame(pairs_list)

    # Calculate what the mean difference would be under random pairing
    all_g_hat = sorted_data['g_hat'].values
    random_diff_mean = np.std(all_g_hat) * np.sqrt(2)
    reduction = 100*(1 - pairs_df['g_hat_diff'].mean()/random_diff_mean)


# --- Merge with full data and save results -----------------------------------
# Merge back with original main data to get all variables
original_indices = sorted_data['original_index'].astype(int).values
full_matched_data = main_data.iloc[original_indices].copy()

# Add the matching variables
full_matched_data['Treatment'] = sorted_data['Treatment_Final'].values
full_matched_data['Pair_ID'] = sorted_data['Pair_ID'].values
full_matched_data['g_hat'] = sorted_data['g_hat'].values
full_matched_data['g_0'] = sorted_data['g_0'].values
full_matched_data['g_1'] = sorted_data['g_1'].values

# TODO: Specify output file name
# This file will contain the main sample with Treatment and Pair_ID assigned
output_file = OUTPUT_DIR / 'optimal_matched_main_sample.dta'
full_matched_data.to_stata(output_file, write_index=False)


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("OPTIMAL MATCHED-PAIRS RANDOMIZATION FROM PILOT STUDY")
print("=" * 80)

print("\nPILOT REGRESSION RESULTS")
print("-" * 80)
print(f"  R-squared:            {pilot_model.rsquared:.4f}")
print(f"  Adj. R-squared:       {pilot_model.rsquared_adj:.4f}")
print(f"  Treatment coef:       {pilot_model.params['Treatment']:>7.4f}")
print(f"  Treatment p-value:    {pilot_model.pvalues['Treatment']:>7.4f}")

print("\nESTIMATED g_hat STATISTICS")
print("-" * 80)
print(f"  Sample size:          {len(main_complete)}")
print(f"  Mean:                 {main_complete['g_hat'].mean():>7.4f}")
print(f"  Std:                  {main_complete['g_hat'].std():>7.4f}")
print(f"  Min:                  {main_complete['g_hat'].min():>7.4f}")
print(f"  Max:                  {main_complete['g_hat'].max():>7.4f}")

print("\nMATCHED PAIRS STATISTICS")
print("-" * 80)
print(f"  Total units:          {n_units}")
print(f"  Matched pairs:        {n_pairs}")
print(f"  Unpaired units:       {n_unpaired}")
print(f"  Pairing rate:         {100*n_pairs*2/n_units:.1f}%")

if len(paired_data) > 0:
    print("\nWITHIN-PAIR g_hat DIFFERENCES")
    print("-" * 80)
    print(f"  Mean:                 {pairs_df['g_hat_diff'].mean():>7.6f}")
    print(f"  Median:               {pairs_df['g_hat_diff'].median():>7.6f}")
    print(f"  Max:                  {pairs_df['g_hat_diff'].max():>7.6f}")
    print(f"  Min:                  {pairs_df['g_hat_diff'].min():>7.6f}")

    print("\nCOMPARISON TO RANDOM PAIRING")
    print("-" * 80)
    print(f"  Expected diff (random):  {random_diff_mean:>7.6f}")
    print(f"  Achieved diff (optimal): {pairs_df['g_hat_diff'].mean():>7.6f}")
    print(f"  Reduction:               {reduction:>7.1f}%")

n_treated = (sorted_data['Treatment_Final'] == 1).sum()
n_control = (sorted_data['Treatment_Final'] == 0).sum()
print("\nTREATMENT ASSIGNMENT")
print("-" * 80)
print(f"  Treated:              {n_treated} ({100*n_treated/len(sorted_data):.1f}%)")
print(f"  Control:              {n_control} ({100*n_control/len(sorted_data):.1f}%)")

print("\n" + "=" * 80)
print("OPTIMAL MATCHING COMPLETE")
print("=" * 80)
print(f"\n✓ Saved to: {output_file}\n")

# =============================================================================
# END OF OPTIMAL MATCHING SCRIPT
# =============================================================================
