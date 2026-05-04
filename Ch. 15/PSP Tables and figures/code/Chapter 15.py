# =============================================================================
# Chapter 15: Post-Study Probability (PSP) Tables and Figures
# Generates Exhibits 15.2, 15.3, 15.4, 15.5, 15.6, and 15.8
# =============================================================================

from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import binom
from tabulate import tabulate


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# =============================================================================
# EXHIBIT 15.2: PSP Across Different Priors
# =============================================================================
# PSP is calculated based on Equation 15.1 (Chapter 15)
# Reference: https://onlinelibrary.wiley.com/doi/epdf/10.1111/ecoj.12527 (pg 211)

def compute_PSP_15_2(beta: float, alpha: float, pi: np.ndarray) -> pd.DataFrame:
    """
    Compute Post-Study Probability for different prior values.

    Parameters
    ----------
    beta : float
        Type II error rate (power = 1 - beta).
    alpha : float
        Significance level (Type I error rate).
    pi : np.ndarray
        Array of prior probabilities.

    Returns
    -------
    pd.DataFrame
        Table with columns: Prior, Power, Significance, True Null Rej,
        False Null Rej, Total Null Rej, PSP.

    Based on Equation 15.1.
    """
    results = []
    for prior in pi:
        true_null_rej = (1 - beta) * prior
        false_null_rej = alpha * (1 - prior)
        total_null_rej = true_null_rej + false_null_rej
        psp = true_null_rej / total_null_rej if total_null_rej != 0 else np.nan

        results.append([
            prior,
            1 - beta,
            alpha,
            true_null_rej,
            false_null_rej,
            total_null_rej,
            psp if not np.isnan(psp) else np.nan
        ])

    df = pd.DataFrame(results, columns=[
        "Prior", "Power", "Significance", "True Null Rej",
        "False Null Rej", "Total Null Rej", "PSP"
    ])
    return df


# Parameters
beta = 0            # power = 1 - beta = 1.0
alpha = 0.05
pi = np.array([0.0001, 0.001, 0.01, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5])

# Generate table
result_15_2 = compute_PSP_15_2(beta, alpha, pi)
print("=" * 80)
print("EXHIBIT 15.2: PSP Across Different Priors")
print("=" * 80)
print(tabulate(result_15_2, headers='keys', tablefmt='pipe', showindex=False, floatfmt=".4f"))
print("\n")

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_15_2_python.tex"
result_15_2.to_latex(tex_file, index=False, float_format="%.4f",
                     caption="PSP Across Different Priors",
                     label="tab:exhibit_15_2")
print(f"Saved to: {tex_file}\n")


# =============================================================================
# EXHIBIT 15.3: PSP Changes with Power and Priors
# =============================================================================
# PSP is calculated based on Equation 15.1 (Chapter 15)
# Reference: https://onlinelibrary.wiley.com/doi/epdf/10.1111/ecoj.12527 (pg. 211)

def compute_PSP_15_3(beta: list, alpha: float, pi: list) -> pd.DataFrame:
    """
    Compute PSP for different power levels and priors.

    Parameters
    ----------
    beta : list
        List of Type II error rates.
    alpha : float
        Significance level.
    pi : list
        List of prior probabilities.

    Returns
    -------
    pd.DataFrame
        Table with Power column and PSP columns for each beta value.

    Based on Equation 15.1.
    """
    result = pd.DataFrame({"Power": pi})
    for b in beta:
        col_name = f"PSP_{b * 100:.0f}"
        PSP = ((1 - b) * pd.Series(pi)) / (((1 - b) * pd.Series(pi)) + (alpha * (1 - pd.Series(pi))))
        result[col_name] = PSP.values
    return result


# Parameters
beta = [0.2, 0.5]   # Power levels: 0.80 and 0.50
alpha = 0.05
pi = [0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50]

# Generate table
result_15_3 = compute_PSP_15_3(beta, alpha, pi)
print("=" * 80)
print("EXHIBIT 15.3: PSP Changes with Power and Priors")
print("=" * 80)
print(tabulate(result_15_3, headers='keys', tablefmt='pipe', showindex=False, floatfmt=".2f"))
print("\n")

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_15_3_python.tex"
result_15_3.to_latex(tex_file, index=False, float_format="%.2f",
                     caption="PSP Changes with Power and Priors",
                     label="tab:exhibit_15_3")
print(f"Saved to: {tex_file}\n")


# =============================================================================
# EXHIBIT 15.4: PSP Across Different Levels of Significance, Power, and Priors
# =============================================================================
# PSP is calculated based on Equation 15.1 (Chapter 15)

def compute_PSP_15_4(alpha_list: list, power: list, pi: list):
    """
    Compute PSP tables for different alpha levels.

    Parameters
    ----------
    alpha_list : list
        List of significance levels.
    power : list
        List of power values.
    pi : list
        List of prior probabilities.

    Returns list of dataframes for each alpha level.
    Based on Equation 15.1.
    """
    all_results = []
    for k in range(len(alpha_list)):
        result = []
        for i in range(len(pi)):
            row = []
            for j in range(len(power)):
                numerator = power[j] * pi[i]
                denominator = (power[j] * pi[i]) + alpha_list[k] * (1 - pi[i])
                row.append(round(numerator / denominator, 2))
            result.append(row)

        # Create dataframe
        df = pd.DataFrame(result, columns=[f"{p:.2f}" for p in power])
        df.insert(0, "Prior", [f"{p:.2f}" for p in pi])

        # Formatting table for print
        headers = [f"{p:.2f}" for p in power]
        rows = [[f"{p:.2f}"] + r for p, r in zip(pi, result)]

        print("=" * 80)
        print(f"EXHIBIT 15.4: PSP at alpha = {alpha_list[k]}")
        print("=" * 80)
        print(tabulate(rows, headers=headers, tablefmt='pipe',
                       numalign='center', stralign='center',
                       floatfmt=".2f", colalign=("center",)))
        print("\n")

        all_results.append((alpha_list[k], df))

    return all_results


# Parameters
pi = [0.01, 0.02, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5]
power = [0.2, 0.3, 0.5, 0.7, 0.8]
alpha_list = [0.05, 0.005]

# Generate tables
results_15_4 = compute_PSP_15_4(alpha_list, power, pi)

# Save to LaTeX
for alpha_val, df in results_15_4:
    tex_file = OUTPUT_DIR / f"Exhibit_15_4_alpha_{alpha_val}_python.tex"
    df.to_latex(tex_file, index=False, float_format="%.2f",
                caption=f"PSP at alpha = {alpha_val}",
                label=f"tab:exhibit_15_4_alpha_{alpha_val}")
    print(f"Saved to: {tex_file}\n")


# =============================================================================
# EXHIBIT 15.5: PSP With and Without a Statistically Significant Finding
# =============================================================================
# PSP(reject NULL) in top panel is derived from Equation 15.1 (Chapter 15)
# PSP(NULL) in bottom panel is derived from Equation 15.4 (Chapter 15)

def compute_PSP_15_5(alpha: float, power: list, pi: list):
    """
    Compute PSP for both rejecting and not rejecting the null.

    Parameters
    ----------
    alpha : float
        Significance level.
    power : list
        List of power values.
    pi : list
        List of prior probabilities.

    Returns two dataframes:
    - Panel 1: PSP(reject NULL) using Equation 15.1
    - Panel 2: PSP(NULL) using Equation 15.4 (PSP = 1 - eq 15.4)
    """
    all_results = []
    for k in range(2):
        result = []
        for i in range(len(pi)):
            row = []
            for j in range(len(power)):
                if k == 0:
                    # PSP when rejecting null
                    numerator = power[j] * pi[i]
                    denominator = (power[j] * pi[i]) + alpha * (1 - pi[i])
                    psp_value = round(numerator / denominator, 2)
                else:
                    # PSP when not rejecting null
                    numerator = (1 - alpha) * (1 - pi[i])
                    denominator = (1 - power[j]) * pi[i] + (1 - alpha) * (1 - pi[i])
                    psp_value = round(1 - numerator / denominator, 2)
                row.append(psp_value)
            result.append(row)

        # Create dataframe
        df = pd.DataFrame(result, columns=[f"{p:.2f}" for p in power])
        df.insert(0, "Prior", [f"{p:.2f}" for p in pi])

        # Formatting table
        headers = [f"{p:.2f}" for p in power]
        rows = [[f"{p:.2f}"] + r for p, r in zip(pi, result)]

        caption = "EXHIBIT 15.5: PSP(reject NULL)" if k == 0 else "EXHIBIT 15.5: PSP(NULL)"

        print("=" * 80)
        print(caption)
        print("=" * 80)
        print(tabulate(rows, headers=headers, tablefmt='pipe',
                       numalign='center', stralign='center',
                       floatfmt=".2f", colalign=("center",)))
        print("\n")

        all_results.append((k, df))

    return all_results


# Parameters
pi = [0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.99]
power = [0.20, 0.30, 0.50, 0.70, 0.80]
alpha = 0.05

# Generate tables
results_15_5 = compute_PSP_15_5(alpha, power, pi)

# Save to LaTeX
for panel, df in results_15_5:
    panel_name = "reject_NULL" if panel == 0 else "NULL"
    tex_file = OUTPUT_DIR / f"Exhibit_15_5_{panel_name}_python.tex"
    df.to_latex(tex_file, index=False, float_format="%.2f",
                caption=f"PSP({panel_name})",
                label=f"tab:exhibit_15_5_{panel_name}")
    print(f"Saved to: {tex_file}\n")


# =============================================================================
# EXHIBIT 15.6: PSP Across Different Power, Stat Sig Level, Prior, and Number of Tests
# =============================================================================
# PSP is calculated based on Equation 15.5 (Chapter 15)
# Assumes n = i

def compute_PSP_15_6(n: list, i: list, alpha: float, pi: list, beta: float) -> pd.DataFrame:
    """
    Compute PSP using binomial distribution for multiple tests.

    Parameters
    ----------
    n : list
        Number of tests.
    i : list
        Number of successes (assumes n = i).
    alpha : float
        Significance level.
    pi : list
        List of prior probabilities.
    beta : float
        Type II error rate.

    Returns
    -------
    pd.DataFrame
        Table with Prior and PSP columns for different i values.

    Based on Equation 15.5.
    """
    data = {
        "Prior": [f"{p:.2f}" for p in pi],
        "i=0": [f"{(p * binom.pmf(i[0], n[0], 1 - beta)) / (p * binom.pmf(i[0], n[0], 1 - beta) + (1 - p) * binom.pmf(i[0], n[0], alpha)):.2f}" for p in pi],
        "i=1": [f"{(p * binom.pmf(i[1], n[1], 1 - beta)) / (p * binom.pmf(i[1], n[1], 1 - beta) + (1 - p) * binom.pmf(i[1], n[1], alpha)):.2f}" for p in pi],
        "i=2": [f"{(p * binom.pmf(i[2], n[2], 1 - beta)) / (p * binom.pmf(i[2], n[2], 1 - beta) + (1 - p) * binom.pmf(i[2], n[2], alpha)):.2f}" for p in pi],
        "i=3": [f"{(p * binom.pmf(i[3], n[3], 1 - beta)) / (p * binom.pmf(i[3], n[3], 1 - beta) + (1 - p) * binom.pmf(i[3], n[3], alpha)):.2f}" for p in pi],
    }

    result = pd.DataFrame(data)
    return result


# Parameters
i = [1, 2, 3, 4]
n = i
alpha = 0.05
beta = 0.2      # 1 - beta = 0.80
pi = [0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50]

# Generate tables for Power = 0.80
result_15_6_power_80 = compute_PSP_15_6(n, i, alpha, pi, beta)
print("=" * 80)
print("EXHIBIT 15.6: PSP for Power = 0.80")
print("=" * 80)
print(result_15_6_power_80)
print("\n")

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_15_6_power_0.80_python.tex"
result_15_6_power_80.to_latex(tex_file, index=False,
                               caption="PSP for Power = 0.80",
                               label="tab:exhibit_15_6_power_80")
print(f"Saved to: {tex_file}\n")

# Generate tables for Power = 0.50
result_15_6_power_50 = compute_PSP_15_6(n, i, alpha, pi, beta=0.5)
print("=" * 80)
print("EXHIBIT 15.6: PSP for Power = 0.50")
print("=" * 80)
print(result_15_6_power_50)
print("\n")

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_15_6_power_0.50_python.tex"
result_15_6_power_50.to_latex(tex_file, index=False,
                               caption="PSP for Power = 0.50",
                               label="tab:exhibit_15_6_power_50")
print(f"Saved to: {tex_file}\n")


# =============================================================================
# EXHIBIT 15.8: PSP with Various Distance Levels
# =============================================================================
# PSP is calculated based on Equation 15.6 (Chapter 15)

def compute_PSP_15_8(power: list, alpha: float, distance: list, pi: list):
    """
    Compute PSP with different distance levels from null hypothesis.

    Parameters
    ----------
    power : list
        List of power values.
    alpha : float
        Significance level.
    distance : list
        List of distance values from null.
    pi : list
        List of prior probabilities.

    Returns list of dataframes for each distance level.
    Based on Equation 15.6.
    """
    beta = [1 - p for p in power]
    all_results = []

    for k in range(len(distance)):
        result = []
        for j in range(len(pi)):
            row = []
            for i in range(len(power)):
                numerator = (power[i] * pi[j]) + (beta[i] * pi[j] * distance[k])
                denominator = (power[i] * pi[j]) + (beta[i] * pi[j] * distance[k]) + \
                    ((alpha + (1 - alpha) * distance[k]) * (1 - pi[j]))
                psp_value = round(numerator / denominator, 2)
                row.append(psp_value)
            result.append(row)

        # Create dataframe
        df = pd.DataFrame(result, columns=[f"{p:.2f}" for p in power])
        df.insert(0, "Prior", [f"{p:.2f}" for p in pi])

        headers = [f"{p:.2f}" for p in power]
        rows = [[f"{p:.2f}"] + r for p, r in zip(pi, result)]

        print("=" * 80)
        print(f"EXHIBIT 15.8: PSP at Distance = {distance[k]:.2f}")
        print("=" * 80)
        print(tabulate(rows, headers=headers, tablefmt='pipe',
                       numalign='center', stralign='center',
                       floatfmt=".2f", colalign=("center",)))
        print("\n")

        all_results.append((distance[k], df))

    return all_results


# Parameters
alpha = 0.05
distance = [0.00, 0.10, 0.25, 0.50]
power = [0.20, 0.30, 0.50, 0.70, 0.80]
pi = [0.01, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50]

# Generate tables
results_15_8 = compute_PSP_15_8(power, alpha, distance, pi)

# Save to LaTeX
for dist_val, df in results_15_8:
    tex_file = OUTPUT_DIR / f"Exhibit_15_8_distance_{dist_val:.2f}_python.tex"
    df.to_latex(tex_file, index=False, float_format="%.2f",
                caption=f"PSP at Distance = {dist_val:.2f}",
                label=f"tab:exhibit_15_8_distance_{dist_val:.2f}".replace(".", "_"))
    print(f"Saved to: {tex_file}\n")
