# =============================================================================
# Exhibit 8.1.2A: Baron and Kenny Mediation Analysis: Parental Beliefs
# =============================================================================
# Conducts mediation analysis using the Baron and Kenny framework to examine
# the relationship between home visiting programs, parental beliefs, and outcomes
# (parental investments and child outcomes).
#
# Implements the Baron and Kenny approach with three regression equations:
# - M_i = α + λ_dm*D_i + X_i'δ + v_i                    (A8.1.4)
# - Y_i = θ + λ_dy*D_i + X_i'δ + ω_i                    (A8.1.5)
# - Y_i = μ + λ_dy*D_i + λ_my*M_i + X_i'δ + ε_i        (A8.1.6)
#
# where:
# - D_i: Treatment indicator (Home Visiting Program)
# - M_i: Mediator (Parental Beliefs)
# - Y_i: Outcome (Parental Investments or Child Outcome)
#
# Reference: Chapter 8, Section 8.3.1, Mediation Analysis

from pathlib import Path
import numpy as np
import pandas as pd
from scipy.stats import norm
import statsmodels.api as sm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Load data ---------------------------------------------------------------
data = pd.read_stata(DATA_DIR / "TMPdata_de-identified.dta")


# Prepare input data
input_data = data[['speak22_A2_sd', 'Treated', 'cvc_A2_sd', 'ctc_A2_sd']].rename(columns={
    'speak22_A2_sd': 'M',
    'Treated': 'D',
    'cvc_A2_sd': 'Y_child',
    'ctc_A2_sd': 'Y_invest'
})


# --- Step 1: Regression of Y on D (Y_child and Y_invest) --------------------
model_child = sm.OLS.from_formula('Y_child ~ D', data=input_data).fit()
model_invest = sm.OLS.from_formula('Y_invest ~ D', data=input_data).fit()


# --- Step 2: Regression of M on D -------------------------------------------
model_m = sm.OLS.from_formula('M ~ D', data=input_data).fit()


# --- Step 3: Regression of Y on M, controlling for D ------------------------
model_childm = sm.OLS.from_formula('Y_child ~ M + D', data=input_data).fit()
model_investm = sm.OLS.from_formula('Y_invest ~ M + D', data=input_data).fit()


# --- Step 4: Sobel test for mediation ---------------------------------------
# Calculate the Sobel test statistic and its p-value: Child Outcome
c_indirect = model_m.params['D'] * model_childm.params['M']
c_coef_a = model_m.params['D']
c_coef_b = model_childm.params['M']
c_var_a = model_m.cov_params().loc['D', 'D']
c_var_b = model_childm.cov_params().loc['M', 'M']
c_se_indirect = np.sqrt(c_coef_a**2 * c_var_b + c_coef_b**2 * c_var_a)
c_z = c_indirect / c_se_indirect
c_p = 2 * (1 - norm.cdf(abs(c_z)))

# Calculate the Sobel test statistic and its p-value: Parental Investments
i_indirect = model_m.params['D'] * model_investm.params['M']
i_coef_a = model_m.params['D']
i_coef_b = model_investm.params['M']
i_var_a = model_m.cov_params().loc['D', 'D']
i_var_b = model_investm.cov_params().loc['M', 'M']
i_se_indirect = np.sqrt(i_coef_a**2 * i_var_b + i_coef_b**2 * i_var_a)
i_z = i_indirect / i_se_indirect
i_p = 2 * (1 - norm.cdf(abs(i_z)))


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 8.1.2A: Baron and Kenny Mediation Analysis: Parental Beliefs")
print("=" * 80 + "\n")

print("(1) Parental Beliefs: M ~ D")
print("-" * 80)
print(model_m.summary())
print("\n")

print("(2) Parental Investments: Y_invest ~ D (no mediator)")
print("-" * 80)
print(model_invest.summary())
print("\n")

print("(3) Parental Investments: Y_invest ~ M + D (with mediator)")
print("-" * 80)
print(model_investm.summary())
print("\n")

print("(4) Child Outcome: Y_child ~ D (no mediator)")
print("-" * 80)
print(model_child.summary())
print("\n")

print("(5) Child Outcome: Y_child ~ M + D (with mediator)")
print("-" * 80)
print(model_childm.summary())
print("\n")

print("Sobel Test Results")
print("-" * 80)
print(f"Parental Investments: z = {i_z:.2f}, p = {i_p:.4f}")
print(f"Child Outcome: z = {c_z:.2f}, p = {c_p:.4f}")
print()


# --- Save results to LaTeX ---------------------------------------------------
# Create summary table with regression results
results_table = pd.DataFrame({
    'Variable': ['Parental Beliefs', '', 'Home Visiting Program', '', 'Sobel z-test'],
    '(1) Parental Beliefs': [
        '-',
        '-',
        f"{model_m.params['D']:.2f}",
        f"({model_m.bse['D']:.2f})",
        '-'
    ],
    '(2) Parental Investments': [
        '-',
        '-',
        f"{model_invest.params['D']:.2f}",
        f"({model_invest.bse['D']:.2f})",
        '-'
    ],
    '(3) Parental Investments': [
        f"{model_investm.params['M']:.2f}",
        f"({model_investm.bse['M']:.2f})",
        f"{model_investm.params['D']:.3f}",
        f"({model_investm.bse['D']:.3f})",
        f"{i_z:.2f}"
    ],
    '(4) Child Outcome': [
        '-',
        '-',
        f"{model_child.params['D']:.2f}",
        f"({model_child.bse['D']:.2f})",
        '-'
    ],
    '(5) Child Outcome': [
        f"{model_childm.params['M']:.2f}",
        f"({model_childm.bse['M']:.2f})",
        f"{model_childm.params['D']:.2f}",
        f"({model_childm.bse['D']:.2f})",
        f"{c_z:.2f}"
    ]
})

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_8_1_2A_python.tex"
results_table.to_latex(tex_file, index=False, escape=False,
                       caption="Baron and Kenny Mediation Analysis: Parental Beliefs",
                       label="tab:exhibit_8_1_2A")
print(f"✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 8.1.2A
# =============================================================================


