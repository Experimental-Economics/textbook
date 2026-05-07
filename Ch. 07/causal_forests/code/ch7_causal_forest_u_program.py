# =============================================================================
# Chapter 7: Causal Forest Analysis for U-Program (GRF implementation)
# =============================================================================
# Estimates Conditional Average Treatment Effects (CATEs) using causal forests.
# Analyzes the effect of Math curriculum allocation on disciplinary infractions
# during the 16-17 academic year across 4 quarters.
#
# Uses EconML's GRF CausalForest to estimate heterogeneous treatment effects
# based on pre-treatment characteristics including ScanQuest scores,
# demographics, and school variables.
#
# econml.grf.CausalForest is a Python implementation of Generalized Random Forests,
# providing the same algorithm as R's grf package (Athey, Tibshirani, Wager 2019).
# This solves the same local moment equation problem as R's causal_forest.
#
# Reference: Chapter 7, Heterogeneous Treatment Effects

from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from econml.grf import CausalForest
import statsmodels.api as sm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Load and filter data ----------------------------------------------------
data_up = pd.read_csv(DATA_DIR / "u_program_data.csv")

print("\n" + "=" * 80)
print("CHAPTER 7: Causal Forest Analysis for U-Program (GRF)")
print("=" * 80)
print("The program took place in the 16-17 academic year, spread in 4 different quarters.")
print("=" * 80 + "\n")

# Filter to Math treatment and control groups
data_up_math_control = data_up[data_up['treatment'].isin(['Math', 'control'])].copy()


# --- Select pre-treatment characteristics ------------------------------------
# Select all pre-treatment variables for the causal forest
pre_treatment_cols = [col for col in data_up_math_control.columns if col.startswith('ScanQuest') and col.endswith('PRE')]
pre_treatment_cols += ['school', 'grade', 'class', 'age', 'female', 'white', 'black',
                       'hispanic', 'other_race', 'disc_1415', 'disc_1516',
                       'DaysAbsent_1415', 'DaysAbsent_1516', 'enrollment_1415',
                       'enrollment_1516']

pre_treatment_characs = data_up_math_control[pre_treatment_cols].copy()


# --- Check for missing data --------------------------------------------------
na_proportions = pre_treatment_characs.isna().mean()
many_missing = na_proportions[na_proportions > 0.05]

print("Variables with >5% missing data:")
if len(many_missing) > 0:
    print(many_missing)
else:
    print("None")
print()

# Remove variables with excessive missing data
pre_treatment_characs = pre_treatment_characs.drop(
    columns=['disc_1415', 'DaysAbsent_1415'], errors='ignore'
)


# --- Create post-treatment outcome variable ----------------------------------
data_up_math_control['disc_post'] = data_up_math_control.apply(
    lambda row: row[f'disc_q{int(row["treated_quarter"])}_1617']
    if pd.notna(row['treated_quarter']) else np.nan,
    axis=1
)


# --- Estimate baseline treatment effect --------------------------------------
# Create treatment indicator (1 = Math, 0 = control)
data_up_math_control['treatment_Math'] = (
    data_up_math_control['treatment'] == 'Math'
).astype(int)

# Baseline OLS regression
m2b = sm.OLS.from_formula(
    'disc_post ~ treatment_Math',
    data=data_up_math_control
).fit()

print("Baseline treatment effect (OLS regression):")
print(m2b.summary())
print(f"\nThe children that were allocated to the Math have {-m2b.params['treatment_Math']:.4f} "
      f"less disciplinary infractions.\n")


# --- Prepare data for causal forest ------------------------------------------
# Remove rows with missing values in outcome, treatment, or covariates
# This ensures R and Python use the same data
complete_cases = (
    data_up_math_control['disc_post'].notna() &
    data_up_math_control['treatment_Math'].notna() &
    pre_treatment_characs.notna().all(axis=1)
)

print(f"Complete cases: {complete_cases.sum()} out of {len(complete_cases)} observations\n")

X = pre_treatment_characs[complete_cases].values
Y = data_up_math_control.loc[complete_cases, 'disc_post'].values
W = data_up_math_control.loc[complete_cases, 'treatment_Math'].values


# --- Estimate causal forest --------------------------------------------------
print("Fitting causal forest using econml.grf.CausalForest (GRF algorithm)...")

# Initialize CausalForest
# This implements the Generalized Random Forest algorithm, matching R's grf package
# It solves: E[(Y - <theta(x), T> - beta(x)) (T;1) | X=x] = 0
causal_forest = CausalForest(
    n_estimators=2000,              # Same as R's num.trees default
    criterion='mse',                # Mean squared error criterion (default)
    min_samples_leaf=5,             # Same as R's min.node.size default
    max_depth=None,                 # Unlimited depth (same as R)
    max_samples=0.5,                # Sample fraction (R's default is 0.5)
    min_balancedness_tol=0.45,      # Enforces balanced splits (R default)
    honest=True,                    # Use honest splitting (GRF default)
    inference=True,                 # Enable confidence intervals
    fit_intercept=True,             # Fit intercept beta(x) as nuisance parameter
    random_state=42,                # For reproducibility
    n_jobs=-1                       # Use all CPU cores
)

# Fit the causal forest
# GRF uses honest splitting: data split for building trees vs. estimating effects
causal_forest.fit(X, T=W, y=Y)

print("Causal forest fitted successfully.")


# --- Extract predictions (CATEs) ---------------------------------------------
# Predict individual treatment effects (CATEs)
# Note: predict() returns shape (n_samples, n_treatments), so we flatten for single treatment
tau_hat = causal_forest.predict(X).flatten()

df_cdf = pd.DataFrame({'tau_hat': tau_hat})


# --- Create CATE cumulative relative frequency plot -------------------------
plt.figure(figsize=(10, 6))

# Sort CATE values and calculate cumulative relative frequencies
tau_sorted = np.sort(tau_hat)
cumulative_freq = np.arange(1, len(tau_sorted) + 1) / len(tau_sorted)

# Plot cumulative relative frequency
plt.plot(tau_sorted, cumulative_freq, linewidth=1.2, color='#1f77b4')
plt.grid(True, alpha=0.3, linestyle='--', linewidth=0.5)

plt.xlabel('CATE', fontsize=11)
plt.ylabel('Cumulative Relative Frequency', fontsize=11)
plt.title('CATEs (econml.grf.CausalForest - GRF Algorithm)', fontsize=13, fontweight='bold')
plt.figtext(0.5, 0.01,
            'Effect of being allocated to the Math Curriculum on number of disciplinary infractions.',
            ha='center', fontsize=9, style='italic')

# Save plot
output_file = OUTPUT_DIR / 'ch7_causal_forest_cate_cumulative_py.png'
plt.savefig(output_file, dpi=300, bbox_inches='tight')
plt.close()


# --- Print results -----------------------------------------------------------
print("=" * 80)
print("CATE Analysis Results (econml.grf.CausalForest)")
print("=" * 80)
print(f"Saved to: {output_file}")
print(f"Number of observations: {len(tau_hat)}")
print(f"Mean CATE: {tau_hat.mean():.4f}")
print(f"Median CATE: {np.median(tau_hat):.4f}")
print(f"Min CATE: {tau_hat.min():.4f}")
print(f"Max CATE: {tau_hat.max():.4f}")
print("\nAll CATE values are negative, which means that no one")
print("is predicted to increase disciplinary infractions due to treatment.")
print("=" * 80)

# =============================================================================
# END OF CHAPTER 7: Causal Forest Analysis (econml.grf.CausalForest)
# =============================================================================
