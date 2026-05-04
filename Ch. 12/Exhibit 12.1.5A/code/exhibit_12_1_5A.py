# =============================================================================
# Exhibit 12.1.5A: ATEs: Default and IPW
# =============================================================================
# Compares treatment effects between default model and Inverse Probability
# Weighting (IPW) approach.
# Column 1: Default model (available cases only)
# Column 2: Inverse Probability Weighting (IPW) model
#
# IPW adjusts for differential attrition by weighting observations by the inverse
# of their predicted probability of response, conditional on baseline covariates.

from pathlib import Path
import pandas as pd
import statsmodels.api as sm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Load and filter data ----------------------------------------------------
# Load synthetic data (for testing/demonstration)
data_12_1_5A = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_1_5A = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")



data_12_1_5A['year'] = pd.to_numeric(data_12_1_5A['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_1_5A = data_12_1_5A[
    (data_12_1_5A['year'] >= 2012) &
    ((data_12_1_5A['treatment'] == 'control') |
     (data_12_1_5A['treatment'] == 'prek')) &
    (data_12_1_5A['kinderprep'] == 0) &
    (data_12_1_5A['late_randomized'] == 0) &
    (data_12_1_5A['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_1_5A['block'] = cleaned_data_12_1_5A.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_1_5A['std_cog_sl'] = cleaned_data_12_1_5A['std_cog_sl'].where(
    cleaned_data_12_1_5A['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_1_5A['d_i'] = (cleaned_data_12_1_5A['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_1_5A['r_i'] = cleaned_data_12_1_5A['std_cog_sl'].notna().astype(int)


# --- Filter for available cases ---------------------------------------------
# Default model uses only observed cases
filtered_data_12_1_5A = cleaned_data_12_1_5A[cleaned_data_12_1_5A['r_i'] == 1]


# --- Estimate propensity scores ----------------------------------------------
# Fit logistic regression models to predict response probability by treatment group
psreg_d_1 = sm.GLM.from_formula(
    'r_i ~ female + race_w + hl_eng_span + birthweight',
    data=cleaned_data_12_1_5A[cleaned_data_12_1_5A['d_i'] == 1],
    family=sm.families.Binomial(link=sm.families.links.Logit())
).fit()

psreg_d_0 = sm.GLM.from_formula(
    'r_i ~ female + race_w + hl_eng_span + birthweight',
    data=cleaned_data_12_1_5A[cleaned_data_12_1_5A['d_i'] == 0],
    family=sm.families.Binomial(link=sm.families.links.Logit())
).fit()


# --- Create IPW dataset ------------------------------------------------------
# Predict response probabilities for each treatment group
ipwdata_1_12_1_5A = cleaned_data_12_1_5A.loc[cleaned_data_12_1_5A['d_i'] == 1].copy()
ipwdata_1_12_1_5A['prob'] = psreg_d_1.predict(ipwdata_1_12_1_5A)

ipwdata_0_12_1_5A = cleaned_data_12_1_5A.loc[cleaned_data_12_1_5A['d_i'] == 0].copy()
ipwdata_0_12_1_5A['prob'] = psreg_d_0.predict(ipwdata_0_12_1_5A)

# Combine treatment groups
ipwdata_12_1_5A = pd.concat([ipwdata_0_12_1_5A, ipwdata_1_12_1_5A])

# Calculate inverse probability weights
ipwdata_12_1_5A['invwt'] = 1 / ipwdata_12_1_5A['prob']


# --- Estimate models ---------------------------------------------------------
# Column 1: Default model (available cases only, no weighting)
model_default_ipw = sm.OLS.from_formula(
    'std_cog_sl ~ d_i',
    data=filtered_data_12_1_5A
).fit()

# Column 2: Inverse Probability Weighted model
model_ipw = sm.WLS.from_formula(
    'std_cog_sl ~ d_i',
    data=ipwdata_12_1_5A,
    weights=ipwdata_12_1_5A['invwt']
).fit()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.1.5A: ATEs: Default and IPW")
print("=" * 80)
print(f"{'':20} {'(1)':>15} {'(2)':>15}")
print(f"{'':20} {'Default Model':>15} {'IPW':>15}")
print("-" * 80)

# Pre-K coefficient row
print(f"{'Pre-K':<20} {model_default_ipw.params['d_i']:>15.3f} "
      f"{model_ipw.params['d_i']:>15.3f}")
print(f"{'':20} ({model_default_ipw.bse['d_i']:>13.3f}) "
      f"({model_ipw.bse['d_i']:>13.3f})")

# Constant row
print(f"{'Constant':<20} {model_default_ipw.params['Intercept']:>15.3f} "
      f"{model_ipw.params['Intercept']:>15.3f}")
print(f"{'':20} ({model_default_ipw.bse['Intercept']:>13.3f}) "
      f"({model_ipw.bse['Intercept']:>13.3f})")

# Controls indicator row
print(f"{'Controls':<20} {'No':>15} {'No':>15}")

# R-squared row
print(f"{'R-squared':<20} {model_default_ipw.rsquared:>15.3f} "
      f"{model_ipw.rsquared:>15.3f}")

# Observations row
print(f"{'Observations':<20} {int(model_default_ipw.nobs):>15} "
      f"{int(model_ipw.nobs):>15}")
print("=" * 80)


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table = pd.DataFrame({
    'Variable': ['Pre-K', '', 'Constant', '', 'Controls', 'R-squared', 'Observations'],
    '(1) Default Model': [
        f"{model_default_ipw.params['d_i']:.3f}",
        f"({model_default_ipw.bse['d_i']:.3f})",
        f"{model_default_ipw.params['Intercept']:.3f}",
        f"({model_default_ipw.bse['Intercept']:.3f})",
        'No',
        f"{model_default_ipw.rsquared:.3f}",
        f"{int(model_default_ipw.nobs)}"
    ],
    '(2) IPW': [
        f"{model_ipw.params['d_i']:.3f}",
        f"({model_ipw.bse['d_i']:.3f})",
        f"{model_ipw.params['Intercept']:.3f}",
        f"({model_ipw.bse['Intercept']:.3f})",
        'No',
        f"{model_ipw.rsquared:.3f}",
        f"{int(model_ipw.nobs)}"
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_12_1_5A_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="ATEs: Default and IPW",
                       label="tab:exhibit_12_1_5A")
print(f"\n✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 12.1.5A
# =============================================================================
