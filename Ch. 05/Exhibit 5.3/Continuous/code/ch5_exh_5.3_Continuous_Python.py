# =============================================================================
# Exhibit 5.3: Simple Rules of Thumb for Sample Size (Continuous Outcomes)
# =============================================================================
# Computes the minimum sample size per group needed to detect a given Minimum
# Detectable Effect (MDE) for continuous outcomes using Equation 5.8:
#
# n = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2
#
# Assumes two-sided test with α = 0.05, power = 80%, and variance ratio = 1.
# Generates LaTeX and HTML tables showing required sample sizes for various
# MDE levels (in standard deviation units).
#
# Reference: Chapter 5, Power Analysis

from pathlib import Path
from fractions import Fraction
from math import ceil
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

# MDE levels to compute (in standard deviation units)
MDE_LEVELS = [1/50, 1/20, 1/10, 1/5, 1/3, 1/2, 1]


# --- Core function -----------------------------------------------------------
def minimum_necessary_sample_size(mde_level: float) -> float:
    """
    Compute the minimum sample size *per group* needed to detect a given MDE
    (in standard deviation units) for a continuous outcome.

    For continuous outcomes the variance ratio simplifies to 1, so Equation 5.8
    reduces to:  N = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2

    Parameters
    ----------
    mde_level : float
        Minimum detectable effect in standard deviation units.

    Returns
    -------
    float
        Required N per group.
    """
    return 2 * ((Z_ALPHA_2 + Z_BETA) / mde_level) ** 2


# --- Generate results --------------------------------------------------------
# Calculate sample sizes for each MDE level
results = []
for mde in MDE_LEVELS:
    n = minimum_necessary_sample_size(mde)
    mde_frac = str(Fraction(mde).limit_denominator())
    results.append({
        'mde': mde,
        'mde_frac': mde_frac,
        'n_exact': n,
        'n_rounded': ceil(n)
    })


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.3: Sample Size Rules of Thumb (Continuous Outcomes)")
print("=" * 80)
print(f"Significance level (α): {ALPHA} (two-sided)")
print(f"Statistical power: {POWER * 100:.0f}%")
print(f"Critical values: z_α/2 = {Z_ALPHA_2:.3f}, z_β = {Z_BETA:.3f}")
print("-" * 80)
print(f"{'MDE (SD units)':>20} {'Sample Size (per group)':>30}")
print("-" * 80)
for r in results:
    print(f"{r['mde_frac']:>20} {r['n_exact']:>20,.1f} ≈ {r['n_rounded']:>8,}")
print("=" * 80)


# --- Build and save LaTeX table ----------------------------------------------
def format_row(mde: float) -> str:
    """Format one data row of the LaTeX table."""
    n = minimum_necessary_sample_size(mde)
    mde_frac = str(Fraction(mde).limit_denominator())
    return (
        f"    \\footnotesize ${mde_frac}$ & "
        f"\\footnotesize {n:,.1f} $\\approx$ {ceil(n):,}  \\\\"
    )

# Header
header = r"""\begin{table}[h!]
\centering
\renewcommand{\arraystretch}{1.6}
\begin{tabular}{|>{\centering\arraybackslash}m{7.2cm}|>{\centering\arraybackslash}m{5.4cm}|}
    \hline
    \multicolumn{2}{|>{\centering\arraybackslash}m{12.6cm}|}{%
        \textbf{\normalsize Exhibit 5.3: Simple Rules of Thumb for Sample Size
                 by Minimum Detectable Effect}} \\
    \hline
    \footnotesize\textbf{\textit{MDE} (in standard deviation units)} &
    \footnotesize\textbf{\textit{n} (per cell)} \\
    \hline"""

# Data rows
body_lines = []
for mde in MDE_LEVELS:
    body_lines.append(format_row(mde))
    body_lines.append("    \\hline")

# Footer with caption
footer = r"""
    \multicolumn{2}{|>{\centering\arraybackslash}m{12.6cm}|}{%
        \scriptsize\textit{Note:} Each row shows the minimum sample size per group
        needed to detect the corresponding MDE (in standard deviation units), assuming
        a two-sided test with $\alpha = 0.05$ and 80\% power.
        Based on Equation~5.8: $n = 2\left(\frac{z_{\alpha/2} + z_{\beta}}
        {\textit{MDE}}\right)^{2}$.} \\
    \hline
\end{tabular}
\end{table}"""

latex_table = header + "\n" + "\n".join(body_lines) + footer

# Save LaTeX output
tex_file = OUTPUT_DIR / "exhibit_5.3.tex"
tex_file.write_text(latex_table, encoding="utf-8")
print(f"\n✓ Saved LaTeX table to: {tex_file}")


# --- Build and save HTML table -----------------------------------------------
# Build a simple styled HTML table using pandas
df_rows = []
for r in results:
    df_rows.append({
        "MDE (in SD units)": r['mde_frac'],
        "n (per cell)": f"{r['n_exact']:,.1f} ≈ {r['n_rounded']:,}"
    })

df = pd.DataFrame(df_rows)

html_style = """
<style>
    body { font-family: 'Helvetica Neue', Arial, sans-serif; margin: 40px; color: #2c3e50; }
    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }
    table { border-collapse: collapse; margin: 20px auto; }
    th { background-color: #1a3e82; color: white; padding: 10px 24px;
         font-size: 13px; text-align: center; }
    td { padding: 8px 24px; text-align: center; font-size: 13px;
         border-bottom: 1px solid #ddd; }
    tr:hover { background-color: #f0f4fb; }
    .note { max-width: 600px; margin: 12px auto; font-size: 11px;
            color: #666; text-align: center; line-height: 1.5; }
</style>
"""

note = (
    '<p class="note"><em>Note:</em> Each row shows the minimum sample size per group '
    "needed to detect the corresponding MDE (in standard deviation units), assuming "
    "a two-sided test with α = 0.05 and 80% power. "
    "Based on Equation 5.8: n = 2 · ((z<sub>α/2</sub> + z<sub>β</sub>) / MDE)².</p>"
)

html_content = (
    "<!DOCTYPE html>\n<html>\n<head>\n<meta charset='utf-8'>\n"
    "<title>Exhibit 5.3</title>\n" + html_style +
    "</head>\n<body>\n"
    "<h2>Exhibit 5.3: Simple Rules of Thumb for Sample Size<br>"
    "by Minimum Detectable Effect</h2>\n"
    + df.to_html(index=False, border=0, classes="exhibit")
    + note
    + "\n</body>\n</html>"
)

html_file = OUTPUT_DIR / "exhibit_5.3.html"
html_file.write_text(html_content, encoding="utf-8")
print(f"✓ Saved HTML table to: {html_file}\n")

# =============================================================================
# END OF EXHIBIT 5.3 (CONTINUOUS)
# =============================================================================
