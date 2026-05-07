# =============================================================================
# Exhibit 5.6: Simple Rules of Thumb for Sample Size (Clustered Units)
# =============================================================================
# Computes the optimal total number of participants (n*) and optimal number
# of clusters (k*) for cluster-randomized designs using Equation 5.12:
#
# n* = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2 * (1 + (m - 1) * ρ)
#
# where m is the cluster size and ρ is the intra-cluster correlation (ICC).
# The design effect (1 + (m - 1) * ρ) inflates the required sample size
# relative to individual randomization.
#
# Generates LaTeX and HTML tables showing required sample sizes for various
# combinations of cluster size (m) and ICC (ρ).
#
# Reference: Chapter 5, Power Analysis

from pathlib import Path
from math import ceil
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
MDE = 0.5     # Minimum detectable effect (in SD units)
SIGMA = 1.0   # Standard deviation

# Critical values
Z_ALPHA_2 = norm.ppf(1 - ALPHA / 2)  # z_{α/2} for two-sided test
Z_BETA = norm.ppf(POWER)              # z_{β} for power calculation

# Parameter grid
RHO_VALUES = [0, 0.25, 0.50, 0.75, 1.0]  # Intra-cluster correlation (ICC)
CLUSTER_SIZES = [10, 30]                  # Individuals per cluster (m)


# --- Core function -----------------------------------------------------------
def optimal_participants(m: int, rho: float) -> float:
    """
    Compute the optimal total number of participants (n*) for a clustered
    experiment using Equation 5.12 from the textbook:

        n* = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2 * (1 + (m - 1) * rho)

    Parameters
    ----------
    m   : int    — number of individuals per cluster
    rho : float  — intra-cluster correlation coefficient (ICC)

    Returns
    -------
    float — optimal total number of participants (n*)
    """
    return 2 * ((Z_ALPHA_2 + Z_BETA) / MDE) ** 2 * (SIGMA ** 2) * (1 + (m - 1) * rho)


# --- Generate results --------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 5.6: Sample Size Rules of Thumb (Clustered Units)")
print("=" * 80)
print(f"Significance level (α): {ALPHA} (two-sided)")
print(f"Statistical power: {POWER * 100:.0f}%")
print(f"Minimum detectable effect (MDE): {MDE} SD units")
print(f"Critical values: z_α/2 = {Z_ALPHA_2:.3f}, z_β = {Z_BETA:.3f}")
print("-" * 80)
print(f"{'ρ (ICC)':>10} {'m (cluster size)':>20} {'n* (participants)':>25} {'k* (clusters)':>20}")
print("-" * 80)

# Calculate and display results for each combination
for rho in RHO_VALUES:
    for m in CLUSTER_SIZES:
        n_star = optimal_participants(m, rho)
        k_star = n_star / m
        print(f"{rho:>10.2f} {m:>20} {n_star:>25,.2f} {k_star:>20,.2f}")

print("=" * 80)


# --- Build and save LaTeX table ----------------------------------------------
# Format the two-row block for each rho value (one sub-row per cluster size m)
def format_rho_block(rho: float) -> str:
    """Format table rows for a given ρ value with multiple cluster sizes."""
    lines = []
    for i, m in enumerate(CLUSTER_SIZES):
        n_star = optimal_participants(m, rho)
        k_star = n_star / m

        if i == 0:
            # First sub-row: includes the multirow rho label
            lines.append(
                f"    \\multirow{{2}}{{*}}{{{rho:g}}}  &  {m} "
                f"& {n_star:,.2f} $\\approx$ {ceil(n_star):,} "
                f"& {k_star:,.2f} $\\approx$ {ceil(k_star):,} \\\\ \\cline{{2-4}}"
            )
        else:
            # Second sub-row: rho cell is merged, so leave it blank
            lines.append(
                f"    & {m} "
                f"& {n_star:,.2f} $\\approx$ {ceil(n_star):,} "
                f"& {k_star:,.2f} $\\approx$ {ceil(k_star):,} \\\\"
            )

    lines.append("    \\hline")
    return "\n".join(lines)


# Header
header = r"""\begin{table}[h!]
\centering
\renewcommand{\arraystretch}{2}
\begin{tabular}{|>{\centering\arraybackslash}m{1.6cm}|>{\centering\arraybackslash}m{2.0cm}|>{\centering\arraybackslash}m{5.0cm}|>{\centering\arraybackslash}m{5.0cm}|}
    \hline
    \multicolumn{4}{|>{\centering\arraybackslash}m{13.6cm}|}{%
        \textbf{Exhibit 5.6: Simple Rules of Thumb for Sample Size
                 for Clustered Units}} \\
    \hline
    {$\boldsymbol{\rho}$} & {$\mathbf{m}$} & {$\mathbf{n^{*}}$} & {$\mathbf{k^{*}}$} \\
    \hline"""

# Data rows
body_blocks = [format_rho_block(rho) for rho in RHO_VALUES]

# Footer with caption
footer = r"""
    \multicolumn{4}{|>{\centering\arraybackslash}m{13.6cm}|}{%
        \scriptsize\textit{Note:} $n^{*}$ is the optimal total number of
        participants and $k^{*} = n^{*}/m$ is the optimal number of clusters,
        each of size $m$. Assumes a two-sided test with $\alpha = 0.05$,
        80\% power, MDE $ = 0.5\sigma$, and intra-cluster correlation $\rho$.
        Based on Equation~5.12.} \\
    \hline
\end{tabular}
\end{table}"""

latex_table = header + "\n" + "\n".join(body_blocks) + footer

# Save LaTeX output
tex_file = OUTPUT_DIR / "exhibit_5.6.tex"
tex_file.write_text(latex_table, encoding="utf-8")
print(f"\n✓ Saved LaTeX table to: {tex_file}")


# --- Build and save HTML table -----------------------------------------------
# Compute all results into a list of dicts for the HTML table
html_rows = []
for rho in RHO_VALUES:
    for i, m in enumerate(CLUSTER_SIZES):
        n_star = optimal_participants(m, rho)
        k_star = n_star / m
        html_rows.append({
            "rho": rho,
            "m": m,
            "n_star": f"{n_star:,.2f} &asymp; {ceil(n_star):,}",
            "k_star": f"{k_star:,.2f} &asymp; {ceil(k_star):,}",
            "first_in_group": (i == 0),
        })

html_style = """
<style>
    body { font-family: 'Helvetica Neue', Arial, sans-serif; margin: 40px; color: #2c3e50; }
    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }
    table { border-collapse: collapse; margin: 20px auto; }
    th { background-color: #1a3e82; color: white; padding: 10px 20px;
         font-size: 13px; text-align: center; }
    td { padding: 8px 20px; text-align: center; font-size: 13px;
         border-bottom: 1px solid #ddd; }
    tr:hover { background-color: #f0f4fb; }
    .group-top td { border-top: 2px solid #999; }
    .note { max-width: 650px; margin: 12px auto; font-size: 11px;
            color: #666; text-align: center; line-height: 1.5; }
</style>
"""

# Build HTML rows with rowspan for rho
tbody_lines = []
for row in html_rows:
    cls = ' class="group-top"' if row["first_in_group"] else ""
    rho_cell = (
        f'<td rowspan="2">{row["rho"]:g}</td>' if row["first_in_group"] else ""
    )
    tbody_lines.append(
        f"      <tr{cls}>{rho_cell}"
        f"<td>{row['m']}</td>"
        f"<td>{row['n_star']}</td>"
        f"<td>{row['k_star']}</td></tr>"
    )

note = (
    '<p class="note"><em>Note:</em> n* is the optimal total number of '
    "participants and k* = n*/m is the optimal number of clusters, each of "
    "size m. Assumes a two-sided test with &alpha; = 0.05, 80% power, "
    "MDE = 0.5&sigma;, and intra-cluster correlation &rho;. "
    "Based on Equation 5.12.</p>"
)

html_content = (
    "<!DOCTYPE html>\n<html>\n<head>\n<meta charset='utf-8'>\n"
    "<title>Exhibit 5.6</title>\n" + html_style +
    "</head>\n<body>\n"
    "<h2>Exhibit 5.6: Simple Rules of Thumb for Sample Size<br>"
    "for Clustered Units</h2>\n"
    "<table>\n"
    "    <thead>\n"
    "      <tr><th>&rho;</th><th>m</th><th>n*</th><th>k*</th></tr>\n"
    "    </thead>\n"
    "    <tbody>\n"
    + "\n".join(tbody_lines) + "\n"
    "    </tbody>\n"
    "</table>\n"
    + note +
    "\n</body>\n</html>"
)

# Save HTML output
html_file = OUTPUT_DIR / "exhibit_5.6.html"
html_file.write_text(html_content, encoding="utf-8")
print(f"✓ Saved HTML table to: {html_file}\n")

# =============================================================================
# END OF EXHIBIT 5.6
# =============================================================================
