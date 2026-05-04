# =============================================================================
# Exhibit 12.2: GHO (2020) Attrition Tests for CHECC Data
# =============================================================================
# Tests whether attrition is related to baseline characteristics.
# Methodology: Regress baseline outcomes on four group indicators:
#   - π11: treatment × respond
#   - π01: control × respond
#   - π10: treatment × attrit
#   - π00: control × attrit
#
# Column 1: Baseline cognitive score (std_cog_pre)
# Column 2: Baseline non-cognitive score (std_ncog_pre)
#
# Hypothesis tests:
#   H0^12.2: π10 = π00 & π11 = π01 (attrition same across treatment/control)
#   H0^12.3: π10 = π00 = π11 = π01 (all groups have same baseline)
#
# Reference: Ghanem, D., Hirshleifer, S., & Ortiz-Becerra, K. (2020).
# Testing Attrition Bias in Field Experiments. Working Paper.

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
# data_12_2 = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
data_12_2 = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")

data_12_2['year'] = pd.to_numeric(data_12_2['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_2 = data_12_2[
    (data_12_2['year'] >= 2012) &
    ((data_12_2['treatment'] == 'control') |
     (data_12_2['treatment'] == 'prek')) &
    (data_12_2['kinderprep'] == 0) &
    (data_12_2['late_randomized'] == 0) &
    (data_12_2['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_2['block'] = cleaned_data_12_2.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_2['std_cog_sl'] = cleaned_data_12_2['std_cog_sl'].where(
    cleaned_data_12_2['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_2['d_i'] = (cleaned_data_12_2['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_2['r_i'] = cleaned_data_12_2['std_cog_sl'].notna().astype(int)


# --- Create group indicators -------------------------------------------------
# Four mutually exclusive groups based on treatment and response status
cleaned_data_12_2['pi11'] = cleaned_data_12_2['d_i'] * cleaned_data_12_2['r_i']
cleaned_data_12_2['pi01'] = (1 - cleaned_data_12_2['d_i']) * cleaned_data_12_2['r_i']
cleaned_data_12_2['pi10'] = cleaned_data_12_2['d_i'] * (1 - cleaned_data_12_2['r_i'])
cleaned_data_12_2['pi00'] = (1 - cleaned_data_12_2['d_i']) * (1 - cleaned_data_12_2['r_i'])


# --- Estimate models ---------------------------------------------------------
# Column 1: Regress baseline cognitive score on group indicators
model_cog = smf.ols(
    'std_cog_pre ~ pi11 + pi01 + pi10 + pi00 - 1',
    data=cleaned_data_12_2
).fit(cov_type='HC2')

# Column 2: Regress baseline non-cognitive score on group indicators
model_ncog = smf.ols(
    'std_ncog_pre ~ pi11 + pi01 + pi10 + pi00 - 1',
    data=cleaned_data_12_2
).fit(cov_type='HC2')


# --- Hypothesis tests --------------------------------------------------------
# Test whether baseline characteristics differ across response/attrition groups

# Hypothesis tests for Cognitive Score
# H0^12.2: π10 = π00 & π11 = π01 (attrition rate same across treatment/control)
hypothesis_cog_12_2 = 'pi10 = pi00, pi11 = pi01'
test_cog_12_2 = model_cog.wald_test(hypothesis_cog_12_2)
pvalue_cog_12_2 = test_cog_12_2.pvalue

# H0^12.3: π10 = π00 = π11 = π01 (all groups have same baseline)
hypothesis_cog_12_3 = 'pi10 = pi00, pi10 = pi11, pi10 = pi01'
test_cog_12_3 = model_cog.wald_test(hypothesis_cog_12_3)
pvalue_cog_12_3 = test_cog_12_3.pvalue

# Hypothesis tests for Non-Cognitive Score
# H0^12.2: π10 = π00 & π11 = π01 (attrition rate same across treatment/control)
hypothesis_ncog_12_2 = 'pi10 = pi00, pi11 = pi01'
test_ncog_12_2 = model_ncog.wald_test(hypothesis_ncog_12_2)
pvalue_ncog_12_2 = test_ncog_12_2.pvalue

# H0^12.3: π10 = π00 = π11 = π01 (all groups have same baseline)
hypothesis_ncog_12_3 = 'pi10 = pi00, pi10 = pi11, pi10 = pi01'
test_ncog_12_3 = model_ncog.wald_test(hypothesis_ncog_12_3)
pvalue_ncog_12_3 = test_ncog_12_3.pvalue


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.2: GHO (2020) Attrition Tests for CHECC Data")
print("=" * 80)
print("\nCOGNITIVE SCORE MODEL (Column 1)")
print("-" * 80)
print(model_cog.summary())

print("\n" + "=" * 80)
print("NON-COGNITIVE SCORE MODEL (Column 2)")
print("=" * 80)
print(model_ncog.summary())

print("\n" + "=" * 80)
print("HYPOTHESIS TEST RESULTS")
print("=" * 80)
print("\nCognitive Score:")
print(f"  H0^12.2: π10 = π00 & π11 = π01     p-value: {pvalue_cog_12_2:.3f}")
print(f"  H0^12.3: π10 = π00 = π11 = π01     p-value: {pvalue_cog_12_3:.3f}")

print("\nNon-Cognitive Score:")
print(f"  H0^12.2: π10 = π00 & π11 = π01     p-value: {pvalue_ncog_12_2:.3f}")
print(f"  H0^12.3: π10 = π00 = π11 = π01     p-value: {pvalue_ncog_12_3:.3f}")


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with coefficients and hypothesis test results
results_table = pd.DataFrame({
    'Group': ['π11 (Treat × Respond)', 'π01 (Control × Respond)',
              'π10 (Treat × Attrit)', 'π00 (Control × Attrit)',
              '', 'H0^12.2: π10=π00 & π11=π01', 'H0^12.3: All groups equal'],
    'Cognitive Score': [
        f"{model_cog.params['pi11']:.3f} ({model_cog.bse['pi11']:.3f})",
        f"{model_cog.params['pi01']:.3f} ({model_cog.bse['pi01']:.3f})",
        f"{model_cog.params['pi10']:.3f} ({model_cog.bse['pi10']:.3f})",
        f"{model_cog.params['pi00']:.3f} ({model_cog.bse['pi00']:.3f})",
        '',
        f"p = {pvalue_cog_12_2:.3f}",
        f"p = {pvalue_cog_12_3:.3f}"
    ],
    'Non-Cognitive Score': [
        f"{model_ncog.params['pi11']:.3f} ({model_ncog.bse['pi11']:.3f})",
        f"{model_ncog.params['pi01']:.3f} ({model_ncog.bse['pi01']:.3f})",
        f"{model_ncog.params['pi10']:.3f} ({model_ncog.bse['pi10']:.3f})",
        f"{model_ncog.params['pi00']:.3f} ({model_ncog.bse['pi00']:.3f})",
        '',
        f"p = {pvalue_ncog_12_2:.3f}",
        f"p = {pvalue_ncog_12_3:.3f}"
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_12_2_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="GHO (2020) Attrition Tests for CHECC Data",
                       label="tab:exhibit_12_2")
print(f"\n✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 12.2
# =============================================================================
