# =============================================================================
# Exhibit 12.1.2A: ATEs and Horowitz and Manski Bounds
# =============================================================================
# Compares default model with upper and lower bounds from Horowitz & Manski (2000).
# Column 1: Default model (no attrition adjustment)
# Column 2: Upper bound (best-case scenario for treatment effect)
# Column 3: Lower bound (worst-case scenario for treatment effect)
#
# Reference: Horowitz, J. L., & Manski, C. F. (2000). Nonparametric Analysis
# of Randomized Experiments with Missing Covariate and Outcome Data.
# Journal of the American Statistical Association, 95(449), 77-84.

from pathlib import Path
import pandas as pd
import statsmodels.api as sm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Parameters --------------------------------------------------------------
# Bounds for outcome variable (standardized cognitive test scores)
UPPER_BOUND = 3
LOWER_BOUND = -3


# --- Load and filter data ----------------------------------------------------
# Load synthetic data (for testing/demonstration)
data_12_1_2A = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_1_2A = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")


data_12_1_2A['year'] = pd.to_numeric(data_12_1_2A['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_1_2A = data_12_1_2A[
    (data_12_1_2A['year'] >= 2012) &
    ((data_12_1_2A['treatment'] == 'control') |
     (data_12_1_2A['treatment'] == 'prek')) &
    (data_12_1_2A['kinderprep'] == 0) &
    (data_12_1_2A['late_randomized'] == 0) &
    (data_12_1_2A['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_1_2A['block'] = cleaned_data_12_1_2A.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_1_2A['std_cog_sl'] = cleaned_data_12_1_2A['std_cog_sl'].where(
    cleaned_data_12_1_2A['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_1_2A['d_i'] = (cleaned_data_12_1_2A['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_1_2A['r_i'] = cleaned_data_12_1_2A['std_cog_sl'].notna().astype(int)


# --- Create bounding datasets ------------------------------------------------
# Upper bound: Assign best outcome to treatment attritors, worst to control attritors
# This maximizes the treatment effect estimate
upper_bound_data = cleaned_data_12_1_2A.copy()
upper_bound_data.loc[
    (upper_bound_data['r_i'] == 0) & (upper_bound_data['d_i'] == 1),
    'std_cog_sl'
] = UPPER_BOUND
upper_bound_data.loc[
    (upper_bound_data['r_i'] == 0) & (upper_bound_data['d_i'] == 0),
    'std_cog_sl'
] = LOWER_BOUND

# Lower bound: Assign worst outcome to treatment attritors, best to control attritors
# This minimizes the treatment effect estimate
lower_bound_data = cleaned_data_12_1_2A.copy()
lower_bound_data.loc[
    (lower_bound_data['r_i'] == 0) & (lower_bound_data['d_i'] == 1),
    'std_cog_sl'
] = LOWER_BOUND
lower_bound_data.loc[
    (lower_bound_data['r_i'] == 0) & (lower_bound_data['d_i'] == 0),
    'std_cog_sl'
] = UPPER_BOUND


# --- Filter for available cases ---------------------------------------------
# Default model uses only observed cases
filtered_data_12_1_2A = cleaned_data_12_1_2A[cleaned_data_12_1_2A['r_i'] == 1]


# --- Estimate models ---------------------------------------------------------
# Column 1: Default model (available cases only, no bounding)
model_default_hm = sm.OLS.from_formula(
    'std_cog_sl ~ d_i',
    data=filtered_data_12_1_2A
).fit()

# Column 2: Horowitz & Manski upper bound
model_hm_upper = sm.OLS.from_formula(
    'std_cog_sl ~ d_i',
    data=upper_bound_data
).fit()

# Column 3: Horowitz & Manski lower bound
model_hm_lower = sm.OLS.from_formula(
    'std_cog_sl ~ d_i',
    data=lower_bound_data
).fit()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.1.2A: ATEs and Horowitz and Manski Bounds")
print("=" * 80)
print(f"{'':20} {'(1)':>15} {'(2)':>15} {'(3)':>15}")
print(f"{'':20} {'Default':>15} {'H&M':>15} {'H&M':>15}")
print(f"{'':20} {'Model':>15} {'Upper Bound':>15} {'Lower Bound':>15}")
print("-" * 80)

# Pre-K coefficient row
print(f"{'Pre-K':<20} {model_default_hm.params['d_i']:>15.3f} "
      f"{model_hm_upper.params['d_i']:>15.3f} "
      f"{model_hm_lower.params['d_i']:>15.3f}")
print(f"{'':20} ({model_default_hm.bse['d_i']:>13.3f}) "
      f"({model_hm_upper.bse['d_i']:>13.3f}) "
      f"({model_hm_lower.bse['d_i']:>13.3f})")

# Constant row
print(f"{'Constant':<20} {model_default_hm.params['Intercept']:>15.3f} "
      f"{model_hm_upper.params['Intercept']:>15.3f} "
      f"{model_hm_lower.params['Intercept']:>15.3f}")
print(f"{'':20} ({model_default_hm.bse['Intercept']:>13.3f}) "
      f"({model_hm_upper.bse['Intercept']:>13.3f}) "
      f"({model_hm_lower.bse['Intercept']:>13.3f})")

# Controls indicator row
print(f"{'Controls':<20} {'No':>15} {'No':>15} {'No':>15}")

# R-squared row
print(f"{'R-squared':<20} {model_default_hm.rsquared:>15.3f} "
      f"{model_hm_upper.rsquared:>15.3f} "
      f"{model_hm_lower.rsquared:>15.3f}")

# Observations row
print(f"{'Observations':<20} {int(model_default_hm.nobs):>15} "
      f"{int(model_hm_upper.nobs):>15} "
      f"{int(model_hm_lower.nobs):>15}")
print("=" * 80)


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table = pd.DataFrame({
    'Variable': ['Pre-K', '', 'Constant', '', 'Controls', 'R-squared', 'Observations'],
    '(1) Default Model': [
        f"{model_default_hm.params['d_i']:.3f}",
        f"({model_default_hm.bse['d_i']:.3f})",
        f"{model_default_hm.params['Intercept']:.3f}",
        f"({model_default_hm.bse['Intercept']:.3f})",
        'No',
        f"{model_default_hm.rsquared:.3f}",
        f"{int(model_default_hm.nobs)}"
    ],
    '(2) H&M Upper Bound': [
        f"{model_hm_upper.params['d_i']:.3f}",
        f"({model_hm_upper.bse['d_i']:.3f})",
        f"{model_hm_upper.params['Intercept']:.3f}",
        f"({model_hm_upper.bse['Intercept']:.3f})",
        'No',
        f"{model_hm_upper.rsquared:.3f}",
        f"{int(model_hm_upper.nobs)}"
    ],
    '(3) H&M Lower Bound': [
        f"{model_hm_lower.params['d_i']:.3f}",
        f"({model_hm_lower.bse['d_i']:.3f})",
        f"{model_hm_lower.params['Intercept']:.3f}",
        f"({model_hm_lower.bse['Intercept']:.3f})",
        'No',
        f"{model_hm_lower.rsquared:.3f}",
        f"{int(model_hm_lower.nobs)}"
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_12_1_2A_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="ATEs and Horowitz and Manski Bounds",
                       label="tab:exhibit_12_1_2A")
print(f"\n✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 12.1.2A
# =============================================================================
