# =============================================================================
# Exhibit 15.1.1A: PSP as a Function of Number of Replications
# Generates two-panel figure showing PSP under different replication scenarios
# =============================================================================

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from scipy.special import comb


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Configure matplotlib
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Arial'],
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'grid.color': '#dddddd',
    'grid.alpha': 0.2
})


# --- Core functions ----------------------------------------------------------
def calculate_psp_unbiased(r: int, beta: float, n: int, alpha: float, pi: float) -> float:
    """
    Calculate PSP for unbiased replication.

    Parameters
    ----------
    r : int
        Number of successful replications.
    beta : float
        Type II error rate (1 - power).
    n : int
        Total number of replication attempts.
    alpha : float
        Significance level.
    pi : float
        Prior probability that the hypothesis is true.

    Returns
    -------
    float
        Post-study probability for unbiased replication.

    Based on binomial probabilities under true and false hypotheses.
    """
    b_true = comb(n, r, exact=True) * (1 - beta)**r * beta**(n - r)
    b_false = comb(n, r, exact=True) * alpha**r * (1 - alpha)**(n - r)
    return (b_true * pi) / (b_true * pi + b_false * (1 - pi))


def calculate_psp_sympathetic(r: int, beta: float, n: int, alpha: float, pi: float, v: float) -> float:
    """
    Calculate PSP for sympathetic replication.

    Parameters
    ----------
    r : int
        Number of successful replications.
    beta : float
        Type II error rate (1 - power).
    n : int
        Total number of replication attempts.
    alpha : float
        Significance level.
    pi : float
        Prior probability that the hypothesis is true.
    v : float
        Sympathetic bias parameter.

    Returns
    -------
    float
        Post-study probability for sympathetic replication.

    Based on Equation A15.1.3 with pure sympathetic bias v.
    """
    # For sympathetic: successful replication probability is (1-beta) + beta*v
    p_success_true = (1 - beta) + beta * v
    p_success_false = alpha + (1 - alpha) * v

    b_true = comb(n, r, exact=True) * p_success_true**r * (1 - p_success_true)**(n - r)
    b_false = comb(n, r, exact=True) * p_success_false**r * (1 - p_success_false)**(n - r)

    psp = (pi * b_true) / (pi * b_true + (1 - pi) * b_false)
    return psp


def calculate_psp_adversarial(r: int, beta: float, n: int, alpha: float, pi: float, omega: float) -> float:
    """
    Calculate PSP for adversarial replication.

    Parameters
    ----------
    r : int
        Number of successful replications.
    beta : float
        Type II error rate (1 - power).
    n : int
        Total number of replication attempts.
    alpha : float
        Significance level.
    pi : float
        Prior probability that the hypothesis is true.
    omega : float
        Adversarial bias parameter.

    Returns
    -------
    float
        Post-study probability for adversarial replication.

    Adversarial replication reduces success probability by factor (1 - omega).
    """
    gamma1 = (1 - beta) * (1 - omega)
    gamma2 = alpha * (1 - omega)

    b_true = comb(n, r, exact=True) * gamma1**r * (1 - gamma1)**(n - r)
    b_false = comb(n, r, exact=True) * gamma2**r * (1 - gamma2)**(n - r)
    return (b_true * pi) / (b_true * pi + b_false * (1 - pi))


def calculate_psp_heterogeneous(r: int, beta: float, n: int, alpha: float, pi: float,
                                  v: float, omega: float, phi: float, psi: float) -> float:
    """
    Calculate PSP for heterogeneous replication.

    Parameters
    ----------
    r : int
        Number of successful replications.
    beta : float
        Type II error rate (1 - power).
    n : int
        Total number of replication attempts.
    alpha : float
        Significance level.
    pi : float
        Prior probability that the hypothesis is true.
    v : float
        Sympathetic bias parameter.
    omega : float
        Adversarial bias parameter.
    phi : float
        Fraction of sympathetic replicators.
    psi : float
        Fraction of adversarial replicators.

    Returns
    -------
    float
        Post-study probability for heterogeneous replication.

    Based on Equation A15.1.5: weighted mixture of phi fraction sympathetic,
    psi fraction adversarial, and (1-phi-psi) fraction neutral.
    """
    # Chi_1: probability of success when true, weighted by researcher types
    chi1 = (phi * ((1 - beta) + beta * v) +
            psi * ((1 - beta) * (1 - omega)) +
            (1 - phi - psi) * (1 - beta))

    # Chi_2: probability of success when false, weighted by researcher types
    chi2 = (phi * (alpha + (1 - alpha) * v) +
            psi * (alpha * (1 - omega)) +
            (1 - phi - psi) * alpha)

    b_chi1 = comb(n, r, exact=True) * chi1**r * (1 - chi1)**(n - r)
    b_chi2 = comb(n, r, exact=True) * chi2**r * (1 - chi2)**(n - r)

    psp = (pi * b_chi1) / (pi * b_chi1 + (1 - pi) * b_chi2)
    return psp


# --- Parameters --------------------------------------------------------------
ALPHA = 0.05
N = 10
V = 0.3
OMEGA = 0.4
PI = 0.5
PHI = 0.33
PSI = 0.33

r_values = np.arange(1, N + 1)


# --- Plot generation ---------------------------------------------------------
# Create figure with two subplots matching the paper layout
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle('Exhibit 15.1.1A: PSP as a Function of Number of Replications out of 10 Attempts',
             fontsize=14, fontweight='bold', y=1.02)


# Left panel: beta = 0.3
beta = 0.3
psp_adversarial = [calculate_psp_adversarial(r, beta, N, ALPHA, PI, OMEGA) for r in r_values]
psp_unbiased = [calculate_psp_unbiased(r, beta, N, ALPHA, PI) for r in r_values]
psp_heterogeneous = [calculate_psp_heterogeneous(r, beta, N, ALPHA, PI, V, OMEGA, PHI, PSI) for r in r_values]
psp_sympathetic = [calculate_psp_sympathetic(r, beta, N, ALPHA, PI, V) for r in r_values]

# Plot lines to match the paper's styling exactly
# Adversarial: square marker, dashed line
ax1.plot(r_values, psp_adversarial, 's--', color='black', linewidth=1.5,
         label='Adversarial', markersize=6, markerfacecolor='white', markeredgecolor='black', markeredgewidth=1.5, zorder=2)
# Unbiased: circle marker, solid line
ax1.plot(r_values, psp_unbiased, 'o-', color='black', linewidth=2,
         label='Unbiased', markersize=6, markerfacecolor='black', zorder=3)
# Heterogeneous: triangle marker, dotted line
ax1.plot(r_values, psp_heterogeneous, '^:', color='gray', linewidth=1.5,
         label='Heterogeneous', markersize=6, markerfacecolor='white', markeredgecolor='gray', markeredgewidth=1.5, zorder=4)
# Sympathetic: diamond marker, dash-dot line
ax1.plot(r_values, psp_sympathetic, 'D-.', color='gray', linewidth=1.5,
         label='Sympathetic', markersize=5, markerfacecolor='white', markeredgecolor='gray', markeredgewidth=1.5, zorder=1)

ax1.set_xlabel('Number of successful replications out of 10 attempts', fontsize=11)
ax1.set_ylabel('PSP_rep', fontsize=11)
ax1.set_ylim(0, 1.05)
ax1.set_xlim(1, 10)
ax1.set_xticks(range(1, 11))
ax1.set_yticks([0, 0.25, 0.5, 0.75, 1])
ax1.text(0.5, -0.25, r'$\beta = 0.3$', transform=ax1.transAxes,
         fontsize=14, ha='center', fontweight='bold')
ax1.legend(loc='lower right', frameon=True, fontsize=10)
ax1.grid(True, alpha=0.2, linestyle='-', linewidth=0.5)


# Right panel: beta = 0.8
beta = 0.8
psp_adversarial = [calculate_psp_adversarial(r, beta, N, ALPHA, PI, OMEGA) for r in r_values]
psp_unbiased = [calculate_psp_unbiased(r, beta, N, ALPHA, PI) for r in r_values]
psp_heterogeneous = [calculate_psp_heterogeneous(r, beta, N, ALPHA, PI, V, OMEGA, PHI, PSI) for r in r_values]
psp_sympathetic = [calculate_psp_sympathetic(r, beta, N, ALPHA, PI, V) for r in r_values]

ax2.plot(r_values, psp_adversarial, 's--', color='black', linewidth=1.5,
         label='Adversarial', markersize=6, markerfacecolor='white', markeredgecolor='black', markeredgewidth=1.5, zorder=2)
ax2.plot(r_values, psp_unbiased, 'o-', color='black', linewidth=2,
         label='Unbiased', markersize=6, markerfacecolor='black', zorder=3)
ax2.plot(r_values, psp_heterogeneous, '^:', color='gray', linewidth=1.5,
         label='Heterogeneous', markersize=6, markerfacecolor='white', markeredgecolor='gray', markeredgewidth=1.5, zorder=4)
ax2.plot(r_values, psp_sympathetic, 'D-.', color='gray', linewidth=1.5,
         label='Sympathetic', markersize=5, markerfacecolor='white', markeredgecolor='gray', markeredgewidth=1.5, zorder=1)

ax2.set_xlabel('Number of successful replications out of 10 attempts', fontsize=11)
ax2.set_ylabel('PSP_rep', fontsize=11)
ax2.set_ylim(0, 1.05)
ax2.set_xlim(1, 10)
ax2.set_xticks(range(1, 11))
ax2.set_yticks([0, 0.25, 0.5, 0.75, 1])
ax2.text(0.5, -0.25, r'$\beta = 0.8$', transform=ax2.transAxes,
         fontsize=14, ha='center', fontweight='bold')
ax2.legend(loc='lower right', frameon=True, fontsize=10)
ax2.grid(True, alpha=0.2, linestyle='-', linewidth=0.5)

plt.tight_layout()


# --- Save output -------------------------------------------------------------
output_file = OUTPUT_DIR / "Exhibit15.1.1A.png"
plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
print(f"Saved to: {output_file}")

# Display the plot
plt.show()
