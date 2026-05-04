# =============================================================================
# Exhibit 12.1.1A: ATEs With and Without Available Case Analysis
# =============================================================================
# Compares treatment effects with and without available case analysis.
# Columns 1-2: Without controls
# Columns 3-4: With controls (female, race_w, hl_eng_span, birthweight)
#
# Reference: Chapter 12, Addressing Attrition

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
data_12_1_1A = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_1_1A = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")


data_12_1_1A['year'] = pd.to_numeric(data_12_1_1A['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_1_1A = data_12_1_1A[
    (data_12_1_1A['year'] >= 2012) &
    ((data_12_1_1A['treatment'] == 'control') |
     (data_12_1_1A['treatment'] == 'prek')) &
    (data_12_1_1A['kinderprep'] == 0) &
    (data_12_1_1A['late_randomized'] == 0) &
    (data_12_1_1A['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_1_1A['block'] = cleaned_data_12_1_1A.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_1_1A['std_cog_sl'] = cleaned_data_12_1_1A['std_cog_sl'].where(
    cleaned_data_12_1_1A['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_1_1A['d_i'] = (cleaned_data_12_1_1A['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_1_1A['r_i'] = cleaned_data_12_1_1A['std_cog_sl'].notna().astype(int)


# --- Filter for available case analysis -------------------------------------
# Available case analysis: restrict to observations with observed outcomes
filtered_data_12_1_1A = cleaned_data_12_1_1A[cleaned_data_12_1_1A['r_i'] == 1]


# --- Estimate models ---------------------------------------------------------
# Column 1: Default model without controls (full data, includes missing outcomes)
model_default = sm.OLS.from_formula(
    'std_cog_sl ~ d_i',
    data=cleaned_data_12_1_1A
).fit()

# Column 2: Available case analysis without controls (only observed outcomes)
model_aca = sm.OLS.from_formula(
    'std_cog_sl ~ d_i',
    data=filtered_data_12_1_1A
).fit()

# Column 3: Default model with controls (full data)
model_default_controls = sm.OLS.from_formula(
    'std_cog_sl ~ d_i + female + race_w + hl_eng_span + birthweight',
    data=cleaned_data_12_1_1A
).fit()

# Column 4: Available case analysis with controls (only observed outcomes)
model_aca_controls = sm.OLS.from_formula(
    'std_cog_sl ~ d_i + female + race_w + hl_eng_span + birthweight',
    data=filtered_data_12_1_1A
).fit()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.1.1A: ATEs With and Without Available Case Analysis")
print("=" * 80)
print(f"{'':20} {'(1)':>15} {'(2)':>15} {'(3)':>15} {'(4)':>15}")
print(f"{'':20} {'Default':>15} {'Available':>15} {'Default':>15} {'Available':>15}")
print(f"{'':20} {'Model':>15} {'Case':>15} {'Model':>15} {'Case':>15}")
print("-" * 80)

# Pre-K coefficient row
print(f"{'Pre-K':<20} {model_default.params['d_i']:>15.3f} "
      f"{model_aca.params['d_i']:>15.3f} "
      f"{model_default_controls.params['d_i']:>15.3f} "
      f"{model_aca_controls.params['d_i']:>15.3f}")
print(f"{'':20} ({model_default.bse['d_i']:>13.3f}) "
      f"({model_aca.bse['d_i']:>13.3f}) "
      f"({model_default_controls.bse['d_i']:>13.3f}) "
      f"({model_aca_controls.bse['d_i']:>13.3f})")

# Constant row
print(f"{'Constant':<20} {model_default.params['Intercept']:>15.3f} "
      f"{model_aca.params['Intercept']:>15.3f} "
      f"{model_default_controls.params['Intercept']:>15.3f} "
      f"{model_aca_controls.params['Intercept']:>15.3f}")
print(f"{'':20} ({model_default.bse['Intercept']:>13.3f}) "
      f"({model_aca.bse['Intercept']:>13.3f}) "
      f"({model_default_controls.bse['Intercept']:>13.3f}) "
      f"({model_aca_controls.bse['Intercept']:>13.3f})")

# Controls indicator row
print(f"{'Controls':<20} {'No':>15} {'No':>15} {'Yes':>15} {'Yes':>15}")

# R-squared row
print(f"{'R-squared':<20} {model_default.rsquared:>15.3f} "
      f"{model_aca.rsquared:>15.3f} "
      f"{model_default_controls.rsquared:>15.3f} "
      f"{model_aca_controls.rsquared:>15.3f}")

# Observations row
print(f"{'Observations':<20} {int(model_default.nobs):>15} "
      f"{int(model_aca.nobs):>15} "
      f"{int(model_default_controls.nobs):>15} "
      f"{int(model_aca_controls.nobs):>15}")
print("=" * 80)


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table = pd.DataFrame({
    'Variable': ['Pre-K', '', 'Constant', '', 'Controls', 'R-squared', 'Observations'],
    '(1) Default Model': [
        f"{model_default.params['d_i']:.3f}",
        f"({model_default.bse['d_i']:.3f})",
        f"{model_default.params['Intercept']:.3f}",
        f"({model_default.bse['Intercept']:.3f})",
        'No',
        f"{model_default.rsquared:.3f}",
        f"{int(model_default.nobs)}"
    ],
    '(2) Available Case': [
        f"{model_aca.params['d_i']:.3f}",
        f"({model_aca.bse['d_i']:.3f})",
        f"{model_aca.params['Intercept']:.3f}",
        f"({model_aca.bse['Intercept']:.3f})",
        'No',
        f"{model_aca.rsquared:.3f}",
        f"{int(model_aca.nobs)}"
    ],
    '(3) Default Model': [
        f"{model_default_controls.params['d_i']:.3f}",
        f"({model_default_controls.bse['d_i']:.3f})",
        f"{model_default_controls.params['Intercept']:.3f}",
        f"({model_default_controls.bse['Intercept']:.3f})",
        'Yes',
        f"{model_default_controls.rsquared:.3f}",
        f"{int(model_default_controls.nobs)}"
    ],
    '(4) Available Case': [
        f"{model_aca_controls.params['d_i']:.3f}",
        f"({model_aca_controls.bse['d_i']:.3f})",
        f"{model_aca_controls.params['Intercept']:.3f}",
        f"({model_aca_controls.bse['Intercept']:.3f})",
        'Yes',
        f"{model_aca_controls.rsquared:.3f}",
        f"{int(model_aca_controls.nobs)}"
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_12_1_1A_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="ATEs With and Without Available Case Analysis",
                       label="tab:exhibit_12_1_1A")
print(f"\n✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 12.1.1A
# =============================================================================
