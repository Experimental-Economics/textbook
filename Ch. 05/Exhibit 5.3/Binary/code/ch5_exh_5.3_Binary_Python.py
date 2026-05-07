# =============================================================================
# Exhibit 5.3: Simple Rules of Thumb for Sample Size (Binary Outcomes)
# =============================================================================
# Computes the minimum sample size per group needed to detect a given Minimum
# Detectable Effect (MDE) for binary outcomes using Equation 5.9.
#
# Unlike continuous outcomes, sample size for binary outcomes depends on both
# the MDE level and p̄ (the average of control and treatment proportions).
# MDE is defined as (p₁ - p₀) / p₀, where p₀ and p₁ are the control and
# treatment proportions, respectively.
#
# Generates:
#   - Line plot showing sample size vs. p̄ for different MDE levels
#   - Heatmap showing required sample size for each (MDE, p̄) combination
#
# Reference: Chapter 5, Power Analysis

from pathlib import Path
import textwrap
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import pandas as pd
from scipy.stats import norm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Parameters --------------------------------------------------------------
# Significance level and power
ALPHA = 0.05  # Two-sided significance level
POWER = 0.80  # Statistical power (1 - β)

# Critical values
Z_ALPHA_2 = norm.ppf(1 - ALPHA / 2)  # z_{α/2} for two-sided test
Z_BETA = norm.ppf(POWER)              # z_{β} for power calculation

# Parameter grid for analysis
MDE_LEVELS = [1/100, 1/50, 1/20, 1/10, 1/5, 1/3, 1/2]  # Relative MDE levels
P_BAR_LEVELS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]  # Average proportions


# --- Core function -----------------------------------------------------------
def minimum_necessary_sample_size(mde_level: float, p_bar: float) -> float:
    """
    Compute the minimum sample size *per group* needed to detect a given
    relative MDE at the specified average proportion (p_bar).

    Parameters
    ----------
    mde_level : float
        Relative minimum detectable effect, defined as (p1 - p0) / p0.
    p_bar : float
        Average proportion across treatment and control, (p0 + p1) / 2.

    Returns
    -------
    float or np.nan
        Required N per group, or NaN when the implied p0 or p1 falls
        outside [0, 1] (infeasible for a binary outcome).

    Based on Equation 5.9 in the textbook.
    """
    # Derive p0 and p1 from the two-equation system:
    #   p_bar = (p0 + p1) / 2   and   mde_level = (p1 - p0) / p0
    p0 = (2 * p_bar) / (2 + mde_level)
    p1 = (2 * (1 + mde_level) * p_bar) / (2 + mde_level)

    # Feasibility check: ensure proportions are valid
    if p1 > 1 or p0 < 0:
        return np.nan

    # Sample size per group (Equation 5.9)
    N = (Z_ALPHA_2 * np.sqrt(2 * p_bar * (1 - p_bar)) +
         Z_BETA * np.sqrt(p0 * (1 - p0) + p1 * (1 - p1)))**2 / (mde_level**2)
    return N


# --- Generate results --------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.3: Sample Size Rules of Thumb (Binary Outcomes)")
print("=" * 80)
print(f"Significance level (α): {ALPHA} (two-sided)")
print(f"Statistical power: {POWER * 100:.0f}%")
print(f"Critical values: z_α/2 = {Z_ALPHA_2:.3f}, z_β = {Z_BETA:.3f}")
print("-" * 80)
print("Computing minimum sample size for every (p̄, MDE) combination...")

# Compute minimum sample size for every (p_bar, MDE) combination
rows = []
for p_bar in P_BAR_LEVELS:
    for mde in MDE_LEVELS:
        n = minimum_necessary_sample_size(mde, p_bar)
        rows.append({"p_bar": p_bar, "mde": round(mde, 2), "min_sample_size": n})

results = pd.DataFrame(rows)

# Count feasible and infeasible combinations
total_combinations = len(results)
feasible_combinations = results['min_sample_size'].notna().sum()
infeasible_combinations = results['min_sample_size'].isna().sum()

print(f"Total combinations: {total_combinations}")
print(f"Feasible combinations: {feasible_combinations}")
print(f"Infeasible combinations: {infeasible_combinations} (p₁ > 1 or p₀ < 0)")
print("=" * 80)


# --- Create line plot --------------------------------------------------------
print("\n" + "=" * 80)
print("Creating line plot: Sample Size vs. p̄ for different MDE levels")
print("=" * 80)

clean = results.dropna(subset=["min_sample_size"])

fig1, ax1 = plt.subplots(figsize=(9, 6))
for mde_val, grp in clean.groupby("mde"):
    ax1.plot(grp["p_bar"], grp["min_sample_size"],
             marker="o", markersize=5, linewidth=1.5, label=f"{mde_val}")

ax1.set_xlabel(r"$\bar{p}$", fontsize=12)
ax1.set_ylabel("Minimum Sample Size (per group)", fontsize=12)
ax1.set_title(r"Minimum Sample Size vs. $\bar{p}$ for Different MDE Levels",
              fontsize=13, fontweight="bold")
ax1.set_xticks(P_BAR_LEVELS)
ax1.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
ax1.legend(title="MDE Level", fontsize=9, title_fontsize=10)
ax1.grid(True, alpha=0.3)
fig1.tight_layout()

# Save line plot
lineplot_file = OUTPUT_DIR / "lineplot_exh5.3_binary.pdf"
fig1.savefig(lineplot_file, format="pdf", bbox_inches="tight", dpi=300)
plt.close(fig1)

print(f"✓ Line plot saved to: {lineplot_file}")


# --- Create heatmap ----------------------------------------------------------
print("\n" + "=" * 80)
print("Creating heatmap: Required Sample Size by MDE and p̄")
print("=" * 80)

# Pivot into a matrix: rows = p_bar, columns = mde
pivot = results.pivot(index="p_bar", columns="mde", values="min_sample_size")


# Format cell labels (matching the R rounding logic)
def format_label(x):
    """Format sample size for heatmap cell annotation."""
    if np.isnan(x):
        return ""
    if x >= 1000:
        return f"{x:,.0f}"
    if x >= 100:
        return f"{x:,.1f}"
    if x >= 10:
        return f"{x:,.2f}"
    return f"{x:,.3f}"


labels = pivot.map(format_label)

# Build the heatmap
fig2, ax2 = plt.subplots(figsize=(9, 7))

masked = pivot.values.copy().astype(float)
cmap = plt.cm.colors.LinearSegmentedColormap.from_list("custom", ["#dce6f7", "#1a3e82"])
cmap.set_bad(color="#d9d9d9")  # Gray for infeasible combinations

im = ax2.imshow(np.where(np.isnan(masked), np.nan, masked),
                aspect="equal", cmap=cmap, origin="upper")

# Annotate each cell with sample size
for i in range(len(pivot.index)):
    for j in range(len(pivot.columns)):
        ax2.text(j, i, labels.iloc[i, j],
                 ha="center", va="center", fontsize=8, color="black")

# Axes
ax2.set_xticks(range(len(pivot.columns)))
ax2.set_xticklabels([str(c) for c in pivot.columns])
ax2.set_yticks(range(len(pivot.index)))
ax2.set_yticklabels([str(r) for r in pivot.index])
ax2.set_xlabel("MDE", fontsize=12)
ax2.set_ylabel(r"$\bar{p}$", fontsize=12)
ax2.set_title(r"Required Sample Size by MDE and $\bar{p}$ (Binary Outcomes)",
              fontsize=13, fontweight="bold")

# Color bar
cbar = fig2.colorbar(im, ax=ax2, shrink=0.75, pad=0.04)
cbar.set_label("Sample Size\n(per group)", fontsize=9)
cbar.ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))

# Caption explaining the heatmap
caption_text = (
    "Each cell shows the minimum sample size per group needed to detect "
    "the corresponding MDE at the given level of p-bar, assuming a two-sided "
    "test with alpha = 0.05 and 80% power (Equation 5.9). "
    "MDE is defined as (p1 - p0) / p0, where p0 and p1 are the control and "
    "treatment proportions and p-bar = (p0 + p1) / 2. "
    "As p-bar approaches 0.5, the variance of the binary outcome is maximized, "
    "which increases the required sample size. "
    "Smaller MDEs also require larger samples, since detecting a subtler effect "
    "demands more statistical precision. "
    "Gray cells indicate infeasible combinations: the implied p1 would exceed 1 "
    "or p0 would fall below 0, which is impossible for a binary outcome."
)
fig2.text(0.05, -0.02, textwrap.fill(caption_text, width=120),
          fontsize=7, color="grey", ha="left", va="top",
          transform=fig2.transFigure, linespacing=1.4)

fig2.tight_layout(rect=[0, 0.08, 1, 1])

# Save heatmap
heatmap_file = OUTPUT_DIR / "heatmap_exh5.3_binary.pdf"
fig2.savefig(heatmap_file, format="pdf", bbox_inches="tight", dpi=300)
plt.close(fig2)

print(f"✓ Heatmap saved to: {heatmap_file}")


# --- Print summary statistics ------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.3: Summary Statistics (Binary Outcomes)")
print("=" * 80)
print("\nSample sizes at selected p̄ and MDE values:")
print(f"{'p̄':>10} {'MDE':>10} {'Sample Size (per group)':>30}")
print("-" * 80)

# Show a few representative combinations
selected_combos = [
    (0.5, 0.50),  # Mid-range p̄, large MDE
    (0.5, 0.10),  # Mid-range p̄, small MDE
    (0.1, 0.50),  # Low p̄, large MDE
    (0.9, 0.50),  # High p̄, large MDE
]

for p_bar, mde in selected_combos:
    n = minimum_necessary_sample_size(mde, p_bar)
    if np.isnan(n):
        print(f"{p_bar:>10.1f} {mde:>10.2f} {'Infeasible':>30}")
    else:
        print(f"{p_bar:>10.1f} {mde:>10.2f} {n:>30,.1f}")

print("=" * 80)
print()

# =============================================================================
# END OF EXHIBIT 5.3 (BINARY)
# =============================================================================
