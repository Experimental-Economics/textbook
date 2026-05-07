# =============================================================================
# Exhibit 5.7: Multiple Hypothesis Testing (MHT) and Statistical Power
# =============================================================================
# Demonstrates how sample size requirements grow with the number of hypothesis
# tests when using Bonferroni corrections to control family-wise error rates.
#
# Three correction strategies are compared:
#   1. No Adjustment: Standard α and power (ignores multiple testing)
#   2. FWE Adjustment: α/k (Bonferroni correction for family-wise error)
#   3. FWE + FWP Adjustment: α/k AND power^(1/k) (controls both error rates)
#
# Shows that detecting multiple effects requires substantially larger samples,
# especially when controlling both family-wise error and family-wise power.
#
# Reference: Chapter 5, Power Analysis

from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
from statsmodels.stats.power import TTestIndPower


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Set random seed for reproducibility
np.random.seed(52649583)


# --- Parameters --------------------------------------------------------------
# Design inputs
MDE_SDS = 0.5    # Effect size in standard deviation units
ALPHA = 0.05     # Significance level (uncorrected)
POWER = 0.80     # Statistical power (uncorrected)
MAX_HYPO = 10    # Maximum number of hypothesis tests to consider


# --- Core function -----------------------------------------------------------
def compute_sample_sizes(mde: float, alpha: float, power: float,
                         n_tests: int) -> dict:
    """
    Compute required sample size per group for 1..n_tests hypotheses under
    three Bonferroni-based correction strategies:

      - No Adjustment:        standard alpha and power
      - FWE Adjustment:       alpha / k  (controls family-wise error rate)
      - FWE + FWP Adjustment: alpha / k  and  power^(1/k)
                              (controls both family-wise error and power)

    Parameters
    ----------
    mde     : float — effect size in SD units
    alpha   : float — significance level
    power   : float — target statistical power
    n_tests : int   — maximum number of hypotheses

    Returns
    -------
    dict with keys 'hypotheses', 'No Adjustment', 'FWE Adjustment',
    'FWE + FWP Adjustment', each mapping to a list of sample sizes.
    """
    solver = TTestIndPower()
    hypotheses = list(range(1, n_tests + 1))

    no_adj = []
    fwe = []
    fwe_fwp = []

    for k in hypotheses:
        # No adjustment: same alpha and power regardless of k
        no_adj.append(solver.solve_power(
            effect_size=mde, alpha=alpha, power=power, alternative="two-sided"))

        # FWE only: Bonferroni-corrected alpha
        fwe.append(solver.solve_power(
            effect_size=mde, alpha=alpha / k, power=power, alternative="two-sided"))

        # FWE + FWP: corrected alpha AND corrected power
        fwe_fwp.append(solver.solve_power(
            effect_size=mde, alpha=alpha / k, power=power ** (1 / k),
            alternative="two-sided"))

    return {
        "hypotheses":            hypotheses,
        "No Adjustment":         no_adj,
        "FWE Adjustment":        fwe,
        "FWE + FWP Adjustment":  fwe_fwp,
    }


# --- Compute results ---------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.7: Multiple Hypothesis Testing and Statistical Power")
print("=" * 80)
print(f"Effect size (MDE): {MDE_SDS} SD units")
print(f"Significance level (α): {ALPHA}")
print(f"Statistical power: {POWER * 100:.0f}%")
print(f"Number of hypothesis tests: 1 to {MAX_HYPO}")
print("-" * 80)
print("Computing required sample sizes for each correction strategy...")

results = compute_sample_sizes(MDE_SDS, ALPHA, POWER, MAX_HYPO)

print("-" * 80)
print(f"{'k (tests)':>12} {'No Adjustment':>18} {'FWE Adjustment':>18} {'FWE + FWP':>18}")
print("-" * 80)

for i, k in enumerate(results["hypotheses"]):
    print(f"{k:>12} {results['No Adjustment'][i]:>18,.1f} "
          f"{results['FWE Adjustment'][i]:>18,.1f} "
          f"{results['FWE + FWP Adjustment'][i]:>18,.1f}")

print("=" * 80)


# --- Create plot -------------------------------------------------------------
print("\n" + "=" * 80)
print("Creating plot: Sample Size vs. Number of Hypothesis Tests")
print("=" * 80)

fig, ax = plt.subplots(figsize=(10, 7))

x = results["hypotheses"]
ax.plot(x, results["No Adjustment"],        color="#CCCCCC", linewidth=2,
        label="No Adjustment", marker='o', markersize=5)
ax.plot(x, results["FWE Adjustment"],       color="#999999", linewidth=2,
        label="FWE Adjustment", marker='s', markersize=5)
ax.plot(x, results["FWE + FWP Adjustment"], color="#000000", linewidth=2,
        label="FWE + FWP Adjustment", marker='^', markersize=5)

ax.set_xlim(0.5, 10.5)
ax.set_ylim(50, 200)
ax.set_xticks(range(1, 11))
ax.set_xlabel("Number of Outcomes / Hypothesis Tests per Experimental Unit",
              fontsize=11)
ax.set_ylabel("Total Sample Size Required (Given Inputs)", fontsize=11)
ax.legend(loc="upper left", fontsize=9, frameon=True, edgecolor="none")
ax.grid(True, alpha=0.3, linestyle='--')

fig.tight_layout()

# Save plot
plot_file = OUTPUT_DIR / "exhibit_5.7.png"
fig.savefig(plot_file, dpi=300, bbox_inches='tight')
plt.close()

print(f"✓ Plot saved to: {plot_file}")


# --- Print summary statistics ------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.7: Summary")
print("=" * 80)
print(f"\nSample size inflation from 1 to {MAX_HYPO} tests:")
print(f"  No Adjustment:       {results['No Adjustment'][0]:.1f} → "
      f"{results['No Adjustment'][-1]:.1f} "
      f"({results['No Adjustment'][-1] / results['No Adjustment'][0]:.2f}x)")
print(f"  FWE Adjustment:      {results['FWE Adjustment'][0]:.1f} → "
      f"{results['FWE Adjustment'][-1]:.1f} "
      f"({results['FWE Adjustment'][-1] / results['FWE Adjustment'][0]:.2f}x)")
print(f"  FWE + FWP:           {results['FWE + FWP Adjustment'][0]:.1f} → "
      f"{results['FWE + FWP Adjustment'][-1]:.1f} "
      f"({results['FWE + FWP Adjustment'][-1] / results['FWE + FWP Adjustment'][0]:.2f}x)")
print("\nKey insight: Testing multiple hypotheses with proper error rate control")
print("requires substantially larger samples, especially when controlling both")
print("family-wise error (FWE) and family-wise power (FWP).")
print("=" * 80)
print()

# =============================================================================
# END OF EXHIBIT 5.7
# =============================================================================
