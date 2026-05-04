# =============================================================================
# Exhibit 9.4: Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods
# =============================================================================

from pathlib import Path
import pandas as pd


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Core function -----------------------------------------------------------
def calculate_n_star(N_pre: int, N_post: int, MDE: float,
                     t_alpha_2: float, t_beta: float) -> float:
    """
    Calculate optimal sample size using the formula for panel data designs.

    Parameters
    ----------
    N_pre : int
        Number of pre-treatment periods.
    N_post : int
        Number of post-treatment periods.
    MDE : float
        Minimum detectable effect in standard deviations.
    t_alpha_2 : float
        Critical value for two-tailed test at alpha/2.
    t_beta : float
        Critical value for power (1 - beta).

    Returns
    -------
    float
        Optimal sample size n* = 2(t_α/2 + t_β)²σ² / (MDE)² * (N_pre + N_post) / (N_pre * N_post)

    Assumes σ² = 1 (standardized).
    """
    numerator = 2 * (t_alpha_2 + t_beta) ** 2 * (N_pre + N_post)
    denominator = (MDE) ** 2 * N_pre * N_post
    return numerator / denominator


# --- Parameters --------------------------------------------------------------
MDE = 0.5           # Standard deviations
t_alpha_2 = 1.96    # For 95% confidence (two-tailed)
t_beta = 0.84       # For 80% power


# --- Generate table data -----------------------------------------------------
results = []

for total_periods in [4, 8, 16]:
    # Three allocation ratios for each total period count
    ratios = [
        (total_periods // 4, 3 * total_periods // 4),  # 1/4 : 3/4
        (total_periods // 2, total_periods // 2),      # 1/2 : 1/2
        (3 * total_periods // 4, total_periods // 4)   # 3/4 : 1/4
    ]

    ratio_strings = ['1/4 : 3/4', '1/2 : 1/2', '3/4 : 1/4']

    for (N_pre, N_post), ratio_str in zip(ratios, ratio_strings):
        # Calculate n* using the formula
        n_star = calculate_n_star(N_pre, N_post, MDE, t_alpha_2, t_beta)

        results.append({
            'Total Number of Periods': total_periods,
            'Pre-to-Post Ratio': ratio_str,
            'n*': round(n_star)
        })

df = pd.DataFrame(results)

# Preview
print("Exhibit 9.4: Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods\n")
print(df.to_string(index=False))
print("\nCalculated using formula with MDE = 0.5 SD, 95% confidence, 80% power")


# --- Save output -------------------------------------------------------------
# Save to LaTeX table
latex_output = df.to_latex(
    index=False,
    caption="Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods",
    label="tab:exhibit_9_4"
)

tex_file = OUTPUT_DIR / "Exhibit_9.4_python.tex"
tex_file.write_text(latex_output, encoding='utf-8')
print(f"\nSaved to: {tex_file}")
