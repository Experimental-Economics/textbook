# =============================================================================
# Exhibit 12.4: Determinants of Attrition Tests
# =============================================================================
# Tests which baseline characteristics predict attrition (non-response).
# This analysis identifies which covariates are associated with the probability
# of having an observed outcome in the second period.
#
# Methodology: Regress response indicator (r_i) on treatment status and baseline
# covariates using robust standard errors (HC2).
#
# Covariates: treatment (d_i), female, race_w, hl_eng_span, birthweight, std_cog_pre

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
data_12_4 = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_4 = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")

data_12_4['year'] = pd.to_numeric(data_12_4['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_4 = data_12_4[
    (data_12_4['year'] >= 2012) &
    ((data_12_4['treatment'] == 'control') | (data_12_4['treatment'] == 'prek')) &
    (data_12_4['kinderprep'] == 0) &
    (data_12_4['late_randomized'] == 0) &
    (data_12_4['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_4['block'] = cleaned_data_12_4.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_4['std_cog_sl'] = cleaned_data_12_4['std_cog_sl'].where(
    cleaned_data_12_4['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_4['d_i'] = (cleaned_data_12_4['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_4['r_i'] = cleaned_data_12_4['std_cog_sl'].notna().astype(int)


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


# --- Estimate attrition model ------------------------------------------------
# Regress response indicator on treatment and baseline covariates
formula_deter = 'r_i ~ d_i + female + race_w + hl_eng_span + birthweight + std_cog_pre'
deter = lm_robust(formula_deter, cleaned_data_12_4)


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.4: Determinants of Attrition Tests")
print("=" * 80)
print(deter.summary())


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table = pd.DataFrame({
    'Variable': ['d_i (Treatment)', 'female', 'race_w (White)',
                 'hl_eng_span (Spanish)', 'birthweight', 'std_cog_pre',
                 'Intercept'],
    'Coefficient': [
        f"{deter.params['d_i']:.3f}",
        f"{deter.params['female']:.3f}",
        f"{deter.params['race_w']:.3f}",
        f"{deter.params['hl_eng_span']:.3f}",
        f"{deter.params['birthweight']:.5f}",
        f"{deter.params['std_cog_pre']:.3f}",
        f"{deter.params['Intercept']:.3f}"
    ],
    'Std. Error': [
        f"{deter.bse['d_i']:.3f}",
        f"{deter.bse['female']:.3f}",
        f"{deter.bse['race_w']:.3f}",
        f"{deter.bse['hl_eng_span']:.3f}",
        f"{deter.bse['birthweight']:.5f}",
        f"{deter.bse['std_cog_pre']:.3f}",
        f"{deter.bse['Intercept']:.3f}"
    ],
    't-statistic': [
        f"{deter.tvalues['d_i']:.3f}",
        f"{deter.tvalues['female']:.3f}",
        f"{deter.tvalues['race_w']:.3f}",
        f"{deter.tvalues['hl_eng_span']:.3f}",
        f"{deter.tvalues['birthweight']:.3f}",
        f"{deter.tvalues['std_cog_pre']:.3f}",
        f"{deter.tvalues['Intercept']:.3f}"
    ],
    'p-value': [
        f"{deter.pvalues['d_i']:.3f}",
        f"{deter.pvalues['female']:.3f}",
        f"{deter.pvalues['race_w']:.3f}",
        f"{deter.pvalues['hl_eng_span']:.3f}",
        f"{deter.pvalues['birthweight']:.3f}",
        f"{deter.pvalues['std_cog_pre']:.3f}",
        f"{deter.pvalues['Intercept']:.3f}"
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_12_4_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="Determinants of Attrition Tests",
                       label="tab:exhibit_12_4")
print(f"\n✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 12.4
# =============================================================================
