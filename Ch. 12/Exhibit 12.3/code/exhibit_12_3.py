# =============================================================================
# Exhibit 12.3: Selective Attrition Tests for CHECC Data
# =============================================================================
# Tests whether attrition is selectively related to baseline covariates (demographics).
# Extends Exhibit 12.2 by examining specific demographic variables instead of outcomes.
#
# Methodology: Regress each baseline covariate on four group indicators:
#   - π11: treatment × respond
#   - π01: control × respond
#   - π10: treatment × attrit
#   - π00: control × attrit
#
# Covariates tested: female, race_w (white), hl_eng_span (Spanish), birthweight
#
# Hypothesis tests:
#   H0^12.2: π10 = π00 & π11 = π01 (attrition same across treatment/control)
#   H0^12.3: π10 = π00 = π11 = π01 (all groups have same covariate means)

from pathlib import Path
import pandas as pd
import statsmodels.formula.api as smf


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Load and filter data ----------------------------------------------------
# Load synthetic data (for testing/demonstration)
data_12_3 = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_3 = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")


# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_3 = data_12_3[
    (data_12_3['year'] >= 2012) &
    ((data_12_3['treatment'] == 'control') | (data_12_3['treatment'] == 'prek')) &
    (data_12_3['kinderprep'] == 0) &
    (data_12_3['late_randomized'] == 0) &
    (data_12_3['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_3['block'] = cleaned_data_12_3.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_3['std_cog_sl'] = cleaned_data_12_3['std_cog_sl'].where(
    cleaned_data_12_3['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_3['d_i'] = (cleaned_data_12_3['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_3['r_i'] = cleaned_data_12_3['std_cog_sl'].notna().astype(int)


# --- Create group indicators -------------------------------------------------
# Four mutually exclusive groups based on treatment and response status
cleaned_data_12_3['pi11'] = cleaned_data_12_3['d_i'] * cleaned_data_12_3['r_i']
cleaned_data_12_3['pi01'] = (1 - cleaned_data_12_3['d_i']) * cleaned_data_12_3['r_i']
cleaned_data_12_3['pi10'] = cleaned_data_12_3['d_i'] * (1 - cleaned_data_12_3['r_i'])
cleaned_data_12_3['pi00'] = (1 - cleaned_data_12_3['d_i']) * (1 - cleaned_data_12_3['r_i'])


# --- Helper function ---------------------------------------------------------
def lm_robust(formula: str, data: pd.DataFrame):
    """
    Fit OLS regression with heteroskedasticity-robust standard errors (HC2).

    Parameters
    ----------
    formula : str
        R-style formula for regression.
    data : pd.DataFrame
        Data for regression.

    Returns
    -------
    RegressionResults
        Fitted model with robust standard errors.
    """
    return smf.ols(formula, data=data).fit(cov_type='HC2')


# --- Estimate models for each covariate -------------------------------------
# Fit robust linear regression models for each baseline covariate
female_cog = lm_robust('female ~ pi11 + pi01 + pi10 + pi00 - 1', cleaned_data_12_3)
white_cog = lm_robust('race_w ~ pi11 + pi01 + pi10 + pi00 - 1', cleaned_data_12_3)
spanish_cog = lm_robust('hl_eng_span ~ pi11 + pi01 + pi10 + pi00 - 1', cleaned_data_12_3)
birthweight_cog = lm_robust('birthweight ~ pi11 + pi01 + pi10 + pi00 - 1', cleaned_data_12_3)

# Define the joint hypotheses for the Wald tests
hypotheses = [
    ['pi10 = pi00', 'pi11 = pi01'],
    ['pi10 = pi00', 'pi10 = pi11', 'pi10 = pi01']
]

# Perform Wald tests and extract p-values for each variable (joint test p-values)
h017_2_female = female_cog.wald_test(hypotheses[0]).pvalue
h017_3_female = female_cog.wald_test(hypotheses[1]).pvalue

h017_2_white = white_cog.wald_test(hypotheses[0]).pvalue
h017_3_white = white_cog.wald_test(hypotheses[1]).pvalue

h017_2_spanish = spanish_cog.wald_test(hypotheses[0]).pvalue
h017_3_spanish = spanish_cog.wald_test(hypotheses[1]).pvalue

h017_2_birthweight = birthweight_cog.wald_test(hypotheses[0]).pvalue
h017_3_birthweight = birthweight_cog.wald_test(hypotheses[1]).pvalue

print("\n" + "="*80)
print("EXHIBIT 12.3: Selective Attrition Tests for CHECC Data")
print("="*80)
print(f"{'Variable':<15} {'π11':<12} {'π01':<12} {'π10':<12} {'π00':<12} {'H0^12.2':<10} {'H0^12.3':<10}")
print("-"*80)

# Female
print(f"{'Female':<15} {female_cog.params['pi11']:>11.3f}  {female_cog.params['pi01']:>11.3f}  "
      f"{female_cog.params['pi10']:>11.3f}  {female_cog.params['pi00']:>11.3f}  "
      f"{h017_2_female:>9.3f}  {h017_3_female:>9.3f}")
print(f"{'(SE)':<15} ({female_cog.bse['pi11']:>9.3f})  ({female_cog.bse['pi01']:>9.3f})  "
      f"({female_cog.bse['pi10']:>9.3f})  ({female_cog.bse['pi00']:>9.3f})")

# White
print(f"{'White':<15} {white_cog.params['pi11']:>11.3f}  {white_cog.params['pi01']:>11.3f}  "
      f"{white_cog.params['pi10']:>11.3f}  {white_cog.params['pi00']:>11.3f}  "
      f"{h017_2_white:>9.3f}  {h017_3_white:>9.3f}")
print(f"{'(SE)':<15} ({white_cog.bse['pi11']:>9.3f})  ({white_cog.bse['pi01']:>9.3f})  "
      f"({white_cog.bse['pi10']:>9.3f})  ({white_cog.bse['pi00']:>9.3f})")

# Spanish
print(f"{'Spanish':<15} {spanish_cog.params['pi11']:>11.3f}  {spanish_cog.params['pi01']:>11.3f}  "
      f"{spanish_cog.params['pi10']:>11.3f}  {spanish_cog.params['pi00']:>11.3f}  "
      f"{h017_2_spanish:>9.3f}  {h017_3_spanish:>9.3f}")
print(f"{'(SE)':<15} ({spanish_cog.bse['pi11']:>9.3f})  ({spanish_cog.bse['pi01']:>9.3f})  "
      f"({spanish_cog.bse['pi10']:>9.3f})  ({spanish_cog.bse['pi00']:>9.3f})")

# Birthweight
print(f"{'Birthweight':<15} {birthweight_cog.params['pi11']:>11.3f}  {birthweight_cog.params['pi01']:>11.3f}  "
      f"{birthweight_cog.params['pi10']:>11.3f}  {birthweight_cog.params['pi00']:>11.3f}  "
      f"{h017_2_birthweight:>9.3f}  {h017_3_birthweight:>9.3f}")
print(f"{'(SE)':<15} ({birthweight_cog.bse['pi11']:>9.3f})  ({birthweight_cog.bse['pi01']:>9.3f})  "
      f"({birthweight_cog.bse['pi10']:>9.3f})  ({birthweight_cog.bse['pi00']:>9.3f})")

print(f"{'Observations':<15} {len(cleaned_data_12_3)}")
print("="*80)


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with coefficients and hypothesis test results
results_table = pd.DataFrame({
    'Variable': ['Female', '', 'White', '', 'Spanish', '', 'Birthweight', ''],
    'π11 (Treat × Respond)': [
        f"{female_cog.params['pi11']:.3f}",
        f"({female_cog.bse['pi11']:.3f})",
        f"{white_cog.params['pi11']:.3f}",
        f"({white_cog.bse['pi11']:.3f})",
        f"{spanish_cog.params['pi11']:.3f}",
        f"({spanish_cog.bse['pi11']:.3f})",
        f"{birthweight_cog.params['pi11']:.3f}",
        f"({birthweight_cog.bse['pi11']:.3f})"
    ],
    'π01 (Control × Respond)': [
        f"{female_cog.params['pi01']:.3f}",
        f"({female_cog.bse['pi01']:.3f})",
        f"{white_cog.params['pi01']:.3f}",
        f"({white_cog.bse['pi01']:.3f})",
        f"{spanish_cog.params['pi01']:.3f}",
        f"({spanish_cog.bse['pi01']:.3f})",
        f"{birthweight_cog.params['pi01']:.3f}",
        f"({birthweight_cog.bse['pi01']:.3f})"
    ],
    'π10 (Treat × Attrit)': [
        f"{female_cog.params['pi10']:.3f}",
        f"({female_cog.bse['pi10']:.3f})",
        f"{white_cog.params['pi10']:.3f}",
        f"({white_cog.bse['pi10']:.3f})",
        f"{spanish_cog.params['pi10']:.3f}",
        f"({spanish_cog.bse['pi10']:.3f})",
        f"{birthweight_cog.params['pi10']:.3f}",
        f"({birthweight_cog.bse['pi10']:.3f})"
    ],
    'π00 (Control × Attrit)': [
        f"{female_cog.params['pi00']:.3f}",
        f"({female_cog.bse['pi00']:.3f})",
        f"{white_cog.params['pi00']:.3f}",
        f"({white_cog.bse['pi00']:.3f})",
        f"{spanish_cog.params['pi00']:.3f}",
        f"({spanish_cog.bse['pi00']:.3f})",
        f"{birthweight_cog.params['pi00']:.3f}",
        f"({birthweight_cog.bse['pi00']:.3f})"
    ],
    'H0^12.2 (p-value)': [
        f"{h017_2_female:.3f}", '',
        f"{h017_2_white:.3f}", '',
        f"{h017_2_spanish:.3f}", '',
        f"{h017_2_birthweight:.3f}", ''
    ],
    'H0^12.3 (p-value)': [
        f"{h017_3_female:.3f}", '',
        f"{h017_3_white:.3f}", '',
        f"{h017_3_spanish:.3f}", '',
        f"{h017_3_birthweight:.3f}", ''
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_12_3_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="Selective Attrition Tests for CHECC Data",
                       label="tab:exhibit_12_3")
print(f"\n✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 12.3
# =============================================================================
