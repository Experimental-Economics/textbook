# =============================================================================
# Exhibit 8.1.3A: A Comparison of Mediation Analysis Methods: Parental Beliefs
# =============================================================================
# This exhibit compares two mediation analysis methods:
# 1. Baron and Kenny (traditional approach with Sobel test)
# 2. Interaction Model (Imai et al. 2010a, Kraemer et al. 2008 with bootstrap)
#
# Note: The Non-parametric Model with GAM smoothing is not available in Python
# due to statsmodels.Mediation limitations. Use R for full 3-method comparison.
#
# The exhibit reports Average Indirect Effect (AIE), Average Direct Effect (ADE),
# and Average Total Effect (ATE) for two outcomes: Parental Investments and
# Child Outcome.

from pathlib import Path
import numpy as np
import pandas as pd
from scipy.stats import norm
import statsmodels.api as sm
from statsmodels.stats.mediation import Mediation


# --- Setup -------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Set seed for reproducibility
# np.random.seed(1234)


# --- Load data ---------------------------------------------------------------
data = pd.read_stata(DATA_DIR / "TMPdata_de-identified.dta")

# Prepare input data (same as Exhibit 8.1.2A)
input_data = data[['speak22_A2_sd', 'Treated', 'cvc_A2_sd', 'ctc_A2_sd']].rename(columns={
    'speak22_A2_sd': 'M',
    'Treated': 'D',
    'cvc_A2_sd': 'Y_child',
    'ctc_A2_sd': 'Y_invest'
})


# =============================================================================
# EXHIBIT 8.1.3A: COMPARISON OF MEDIATION METHODS
# =============================================================================

print("\n" + "=" * 80)
print("EXHIBIT 8.1.3A: Comparison of Mediation Analysis Methods")
print("=" * 80 + "\n")


# --- Method 1: Baron and Kenny -----------------------------------------------
print("Method 1: Baron and Kenny")
print("-" * 80)

# Step 1: Regression of Y on D (without mediator)
model_invest = sm.OLS.from_formula('Y_invest ~ D', data=input_data).fit()
model_child = sm.OLS.from_formula('Y_child ~ D', data=input_data).fit()

# Step 2: Regression of M on D
model_m = sm.OLS.from_formula('M ~ D', data=input_data).fit()

# Step 3: Regression of Y on M, controlling for D
model_childm = sm.OLS.from_formula('Y_child ~ M + D', data=input_data).fit()
model_investm = sm.OLS.from_formula('Y_invest ~ M + D', data=input_data).fit()

# Calculate indirect effects (Sobel test)
i_indirect = model_m.params['D'] * model_investm.params['M']
i_coef_a = model_m.params['D']
i_coef_b = model_investm.params['M']
i_var_a = model_m.cov_params().loc['D', 'D']
i_var_b = model_investm.cov_params().loc['M', 'M']
i_se_indirect = np.sqrt(i_coef_a**2 * i_var_b + i_coef_b**2 * i_var_a)
i_z = i_indirect / i_se_indirect
i_p = 2 * (1 - norm.cdf(abs(i_z)))

c_indirect = model_m.params['D'] * model_childm.params['M']
c_coef_a = model_m.params['D']
c_coef_b = model_childm.params['M']
c_var_a = model_m.cov_params().loc['D', 'D']
c_var_b = model_childm.cov_params().loc['M', 'M']
c_se_indirect = np.sqrt(c_coef_a**2 * c_var_b + c_coef_b**2 * c_var_a)
c_z = c_indirect / c_se_indirect
c_p = 2 * (1 - norm.cdf(abs(c_z)))

print("Parental Investments:")
print(f"  AIE = {i_indirect:.2f} (SE = {i_se_indirect:.2f})")
print(f"  ADE = {model_investm.params['D']:.2f} (SE = {model_investm.bse['D']:.2f})")
print(f"  ATE = {model_invest.params['D']:.2f} (SE = {model_invest.bse['D']:.2f})")
print(f"\nChild Outcome:")
print(f"  AIE = {c_indirect:.2f} (SE = {c_se_indirect:.2f})")
print(f"  ADE = {model_childm.params['D']:.2f} (SE = {model_childm.bse['D']:.2f})")
print(f"  ATE = {model_child.params['D']:.2f} (SE = {model_child.bse['D']:.2f})")
print()


# --- Method 2: Interaction Model ---------------------------------------------
print("Method 2: Interaction Model")
print("-" * 80)

# Filter to complete cases (required for Mediation class)
input_data_complete = input_data.dropna()

# Parental Investments with interaction
outcome_model_i = sm.OLS.from_formula(
    "Y_invest ~ D + M + M * D", input_data_complete
)
mediator_model_i = sm.OLS.from_formula("M ~ D", input_data_complete)
med_invest_interact = Mediation(
    outcome_model_i, mediator_model_i, "D", "M"
).fit(n_rep=1000)
summary_invest_interact = med_invest_interact.summary()

# Child Outcome with interaction
outcome_model_c = sm.OLS.from_formula(
    "Y_child ~ D + M + M * D", input_data_complete
)
mediator_model_c = sm.OLS.from_formula("M ~ D", input_data_complete)
med_child_interact = Mediation(
    outcome_model_c, mediator_model_c, "D", "M"
).fit(n_rep=1000)
summary_child_interact = med_child_interact.summary()

print("Parental Investments:")
print(f"  AIE = {summary_invest_interact['Estimate']['ACME (average)']:.2f}")
print(f"  CI = [{summary_invest_interact['Lower CI bound']['ACME (average)']:.2f}, "
      f"{summary_invest_interact['Upper CI bound']['ACME (average)']:.2f}]")
print(f"  ADE = {summary_invest_interact['Estimate']['ADE (average)']:.2f}")
print(f"  CI = [{summary_invest_interact['Lower CI bound']['ADE (average)']:.2f}, "
      f"{summary_invest_interact['Upper CI bound']['ADE (average)']:.2f}]")
print(f"  ATE = {summary_invest_interact['Estimate']['Total effect']:.2f}")
print(f"  CI = [{summary_invest_interact['Lower CI bound']['Total effect']:.2f}, "
      f"{summary_invest_interact['Upper CI bound']['Total effect']:.2f}]")
print(f"\nChild Outcome:")
print(f"  AIE = {summary_child_interact['Estimate']['ACME (average)']:.2f}")
print(f"  CI = [{summary_child_interact['Lower CI bound']['ACME (average)']:.2f}, "
      f"{summary_child_interact['Upper CI bound']['ACME (average)']:.2f}]")
print(f"  ADE = {summary_child_interact['Estimate']['ADE (average)']:.2f}")
print(f"  CI = [{summary_child_interact['Lower CI bound']['ADE (average)']:.2f}, "
      f"{summary_child_interact['Upper CI bound']['ADE (average)']:.2f}]")
print(f"  ATE = {summary_child_interact['Estimate']['Total effect']:.2f}")
print(f"  CI = [{summary_child_interact['Lower CI bound']['Total effect']:.2f}, "
      f"{summary_child_interact['Upper CI bound']['Total effect']:.2f}]")
print()


# --- Save results to LaTeX ---------------------------------------------------
# Define function to add stars based on p-value
def add_stars(estimate, p_value):
    """Add significance stars to estimate based on p-value"""
    if p_value <= 0.001:
        return f"{estimate}***"
    elif p_value <= 0.01:
        return f"{estimate}**"
    elif p_value <= 0.05:
        return f"{estimate}*"
    elif p_value <= 0.1:
        return f"{estimate}."
    else:
        return estimate

# Create combined table
results_table = pd.DataFrame({
    'Method': [
        'AIE', '',
        'ADE', '',
        'ATE', ''
    ],
    'Baron and Kenny': [
        add_stars(f"{i_indirect:.2f}", i_p),
        f"({i_se_indirect:.2f})",
        add_stars(f"{model_investm.params['D']:.3f}", model_investm.pvalues['D']),
        f"({model_investm.bse['D']:.2f})",
        add_stars(f"{model_invest.params['D']:.2f}", model_invest.pvalues['D']),
        f"({model_invest.bse['D']:.2f})"
    ],
    'Interaction Model': [
        add_stars(f"{summary_invest_interact['Estimate']['ACME (average)']:.2f}",
                  summary_invest_interact['P-value']['ACME (average)']),
        f"[{summary_invest_interact['Lower CI bound']['ACME (average)']:.2f}, "
        f"{summary_invest_interact['Upper CI bound']['ACME (average)']:.2f}]",
        add_stars(f"{summary_invest_interact['Estimate']['ADE (average)']:.2f}",
                  summary_invest_interact['P-value']['ADE (average)']),
        f"[{summary_invest_interact['Lower CI bound']['ADE (average)']:.2f}, "
        f"{summary_invest_interact['Upper CI bound']['ADE (average)']:.2f}]",
        add_stars(f"{summary_invest_interact['Estimate']['Total effect']:.2f}",
                  summary_invest_interact['P-value']['Total effect']),
        f"[{summary_invest_interact['Lower CI bound']['Total effect']:.2f}, "
        f"{summary_invest_interact['Upper CI bound']['Total effect']:.2f}]"
    ],
    'Baron and Kenny (Child)': [
        add_stars(f"{c_indirect:.2f}", c_p),
        f"({c_se_indirect:.2f})",
        add_stars(f"{model_childm.params['D']:.2f}", model_childm.pvalues['D']),
        f"({model_childm.bse['D']:.2f})",
        add_stars(f"{model_child.params['D']:.2f}", model_child.pvalues['D']),
        f"({model_child.bse['D']:.2f})"
    ],
    'Interaction Model (Child)': [
        add_stars(f"{summary_child_interact['Estimate']['ACME (average)']:.2f}",
                  summary_child_interact['P-value']['ACME (average)']),
        f"[{summary_child_interact['Lower CI bound']['ACME (average)']:.2f}, "
        f"{summary_child_interact['Upper CI bound']['ACME (average)']:.2f}]",
        add_stars(f"{summary_child_interact['Estimate']['ADE (average)']:.2f}",
                  summary_child_interact['P-value']['ADE (average)']),
        f"[{summary_child_interact['Lower CI bound']['ADE (average)']:.2f}, "
        f"{summary_child_interact['Upper CI bound']['ADE (average)']:.2f}]",
        add_stars(f"{summary_child_interact['Estimate']['Total effect']:.2f}",
                  summary_child_interact['P-value']['Total effect']),
        f"[{summary_child_interact['Lower CI bound']['Total effect']:.2f}, "
        f"{summary_child_interact['Upper CI bound']['Total effect']:.2f}]"
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_8_1_3A_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="A Comparison of Mediation Analysis Methods: Parental Beliefs",
                       label="tab:exhibit_8_1_3A")
print(f"✓ Saved to: {tex_file}\n")


# =============================================================================
# END OF EXHIBIT 8.1.3A
# =============================================================================