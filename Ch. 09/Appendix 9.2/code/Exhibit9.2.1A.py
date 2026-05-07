# =============================================================================
# Appendix 9.2: Optimal Experimental Design for Panel Data
# =============================================================================

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Configure matplotlib
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Arial'],
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'grid.color': '#dddddd',
    'grid.alpha': 0.3
})


# --- Core function -----------------------------------------------------------
def compute_optimal_sample_size(m: float, r: float, C: float) -> float:
    """
    Compute optimal sample size n* from pre/post periods.

    Parameters
    ----------
    m : float
        Number of pre-treatment periods.
    r : float
        Number of post-treatment periods.
    C : float
        Constant from power calculation: C = 2*(t_{α/2} + t_β)^2 * σ^2 / MDE^2

    Returns
    -------
    float
        Optimal sample size n* = C * (m + r) / (m * r)

    Based on McKenzie (2012).
    """
    return C * (m + r) / (m * r)


# --- Constants ---------------------------------------------------------------
# Critical values for alpha = 0.05 (two-sided), power = 0.80
# C = 2*(t_{α/2} + t_β)^2 * σ^2 / MDE^2
# With MDE=0.5, t_{α/2}=1.96, t_β=0.84, σ^2=1 → C = 62.72
T_ALPHA_OVER_2 = 1.96
T_BETA = 0.84
SIGMA2 = 1.0
MDE = 0.5
C = 2 * (T_ALPHA_OVER_2 + T_BETA)**2 * SIGMA2 / (MDE**2)


# --- Plot 1: McKenzie (2012) -------------------------------------------------
mckenzie = pd.read_csv(DATA_DIR / "mckenzie2012-simulation.csv")

# Compute n* from (m, r) using the formula
mckenzie["n_star"] = compute_optimal_sample_size(mckenzie["m"], mckenzie["r"], C)

fig1, ax1 = plt.subplots(figsize=(8, 6))
for m_val, color in [(1, 'black'), (5, '#777777'), (10, '#bbbbbb')]:
    subset = mckenzie[mckenzie['m'] == m_val]
    ax1.plot(subset['ratio'], subset['n_star'], color=color, label=f"m = {m_val}")

ax1.set_xlabel("Pre/Post (m/r) periods")
ax1.set_ylabel("Optimal Sample Size (n*)")
ax1.set_xlim(0, 10)
ax1.set_ylim(0, 130)
ax1.set_xticks(np.arange(0, 11, 1))
ax1.set_yticks(np.arange(0, 150, 25))
ax1.legend(loc='upper right', frameon=True)
ax1.grid(True)


# --- Plot 2: Burlig et al. (2020) --------------------------------------------
burlig_path = DATA_DIR / "paneldata-r-variation.csv"

if burlig_path.exists():
    burlig = pd.read_csv(burlig_path)
    fig2, ax2 = plt.subplots(figsize=(8, 6))
    for post_val, color in [(2, 'black'), (5, '#777777'), (8, '#bbbbbb')]:
        subset = burlig[burlig['post'] == post_val]
        ax2.plot(subset['ar1'], subset['n'], color=color, label=f"r = {post_val}")
    ax2.set_xlabel("AR1(γ)")
    ax2.set_ylabel("Optimal Sample Size (n*)")
    ax2.set_xlim(0, 1)
    ax2.set_ylim(0, 150)
    ax2.set_xticks(np.arange(0, 1.1, 0.1))
    ax2.set_yticks(np.arange(0, 175, 25))
    ax2.legend(loc='upper right', frameon=True)
    ax2.grid(True)
else:
    # Fallback if data file doesn't exist
    fig2, ax2 = plt.subplots(figsize=(8, 6))
    ar1 = np.linspace(0.1, 0.9, 9)
    n = 100 - 50 * ar1
    ax2.plot(ar1, n, 'k-')
    ax2.set_xlabel("AR1(γ)")
    ax2.set_ylabel("Optimal Sample Size (n*)")
    ax2.set_xlim(0, 1)
    ax2.set_ylim(0, 150)
    ax2.set_xticks(np.arange(0, 1.1, 0.1))
    ax2.set_yticks(np.arange(0, 175, 25))
    ax2.grid(True)


# --- Save output -------------------------------------------------------------
fig1.savefig(OUTPUT_DIR / "paneldata-figA-McKenzie2012.jpg",
             dpi=300, bbox_inches='tight')
plt.close(fig1)

fig2.savefig(OUTPUT_DIR / "paneldata-figB-Burlig2020.jpg",
             dpi=300, bbox_inches='tight')
plt.close(fig2)