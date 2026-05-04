# =============================================================================
# Exhibit 6.5: Covariate Balance with CRE in Lalonde (1986; NSW)
# =============================================================================
# Creates a balance table comparing baseline characteristics across treatment and
# control groups in the Lalonde (1986; NSW) dataset using a Completely Randomized
# Experiment (CRE).
#
# Column 1: Covariate name and type (proportion vs. mean)
# Column 2: Control group mean (SD)
# Column 3: Treatment group mean (SD)
# Column 4: Difference of means with p-value
#
# For continuous variables: Uses t-test for difference in means
# For binary/categorical variables: Uses z-test for difference in proportions
#
# Reference: Chapter 6, Exhibit 6.5

from itertools import combinations
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Balance table function --------------------------------------------------
def create_balance_table(data, treatment_col, variables, variable_labels=None, continuous_vars=None):
    """
    Create a balance table comparing baseline characteristics across treatment groups.

    Parameters
    ----------
    data : pd.DataFrame
        DataFrame containing the data.
    treatment_col : str
        Name of the treatment column.
    variables : list
        List of variables to include in the balance table.
    variable_labels : dict, optional
        Dictionary mapping variable names to display labels.
    continuous_vars : list, optional
        List of continuous variables (auto-detected if None).

    Returns
    -------
    pd.DataFrame
        DataFrame with balance table statistics.
    """
    # Validate inputs
    if treatment_col not in data.columns:
        raise ValueError(f"Treatment column '{treatment_col}' not found in data")

    missing_vars = [v for v in variables if v not in data.columns]
    if missing_vars:
        raise ValueError(f"Variables not found in data: {', '.join(missing_vars)}")

    # Auto-detect continuous variables if not specified
    if continuous_vars is None:
        continuous_vars = [v for v in variables if np.issubdtype(data[v].dropna().dtype, np.number)
                           and (data[v].nunique() > 10 or not np.allclose(data[v].dropna(), np.floor(data[v].dropna())))]

    # Set up variable labels
    if variable_labels is None:
        variable_labels = {v: v for v in variables}
    else:
        for v in variables:
            if v not in variable_labels:
                variable_labels[v] = v

    # Get treatment groups
    treatment_groups = data[treatment_col].dropna().unique()
    if len(treatment_groups) < 2:
        raise ValueError("Need at least 2 treatment groups for comparison")

    # Compute group-wise statistics (means, standard deviations, sample sizes)
    summary = []
    for group in treatment_groups:
        group_data = data[data[treatment_col] == group]
        row = {}
        row[treatment_col] = group
        for var in variables:
            vals = group_data[var].dropna()
            row[f"{var}_mean"] = vals.mean()
            row[f"{var}_sd"] = vals.std()
            row[f"{var}_n"] = len(vals)
        summary.append(row)
    summary_stats = pd.DataFrame(summary)

    # Reshape from long to wide format
    long_df = summary_stats.melt(id_vars=[treatment_col], var_name='var_stat', value_name='value')
    long_df[['variable', 'stat']] = long_df['var_stat'].str.extract(r'^(.*)_(mean|sd|n)$')
    wide_df = long_df.pivot_table(index='variable', columns=[treatment_col, 'stat'], values='value').reset_index()
    wide_df.columns = [f"{a}_{b}" if b != '' else a for a, b in wide_df.columns.to_flat_index()]
    wide_df['variable_label'] = wide_df['variable'].map(variable_labels)

    # Compute p-values for pairwise comparisons
    for group1, group2 in combinations(treatment_groups, 2):
        p_vals = []
        for var in wide_df['variable']:
            vals1 = data[data[treatment_col] == group1][var].dropna()
            vals2 = data[data[treatment_col] == group2][var].dropna()

            # Skip if either group has no observations
            if len(vals1) == 0 or len(vals2) == 0:
                p_vals.append(np.nan)
                continue

            # Use t-test for continuous variables
            if var in continuous_vars:
                try:
                    p_val = stats.ttest_ind(vals1, vals2, equal_var=False).pvalue
                except Exception:
                    p_val = np.nan
            # Use z-test for proportions for binary/categorical variables
            else:
                try:
                    p1 = vals1.mean()
                    p2 = vals2.mean()
                    n1 = len(vals1)
                    n2 = len(vals2)
                    se = np.sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
                    if se == 0:
                        p_val = 1.0 if p1 == p2 else 0.0
                    else:
                        z = (p1 - p2) / se
                        p_val = 2 * stats.norm.sf(np.abs(z))
                except Exception:
                    p_val = np.nan
            p_vals.append(p_val)
        wide_df[f"p_val_{group1}_{group2}"] = p_vals

    # Mark continuous variables
    wide_df['continuous'] = wide_df['variable'].apply(lambda v: 1 if v in continuous_vars else 0)

    # Final formatting and column ordering
    cols = ['variable_label'] + [col for col in wide_df.columns if col not in ['variable', 'variable_label', 'continuous']] + ['continuous']
    result = wide_df[cols].sort_values(by='variable_label')
    return result


# --- Load data ---------------------------------------------------------------
# Load Lalonde (1986) dataset
lalonde2 = pd.read_stata(DATA_DIR / "lalonde2.dta")


# --- Generate balance table --------------------------------------------------
# Create balance table comparing treatment and control groups on baseline covariates
balance_table = create_balance_table(
    data=lalonde2,
    treatment_col="treated",
    variables=["nodegree", "black", "hisp", "married", "age", "educ", "kids18", "re74"],
    variable_labels={
        "nodegree": "High School Dropout",
        "black": "Black",
        "hisp": "Hispanic",
        "married": "Married",
        "age": "Age",
        "educ": "Years of Schooling",
        "kids18": "Num. Kids under 18",
        "re74": "Real Earnings 1974"
    },
    continuous_vars=["age", "educ", "kids18", "re74"]
)

# Reorder rows to match desired covariate order
desired_order = [
    "High School Dropout",
    "Black",
    "Hispanic",
    "Married",
    "Age",
    "Years of Schooling",
    "Num. Kids under 18",
    "Real Earnings 1974"
]
balance_table = balance_table.set_index("variable_label").loc[desired_order].reset_index()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 6.5: Covariate Balance with CRE in Lalonde (1986; NSW)")
print("=" * 80)
print(f"{'Covariate':<25} {'Type':<12} {'Control':<15} {'Treatment':<15} {'Diff':<12} {'p-value':<10}")
print(f"{'':25} {'':12} {'Mean (SD)':<15} {'Mean (SD)':<15} {'':12} {'':10}")
print("-" * 80)

for i in range(len(balance_table)):
    row = balance_table.iloc[i]
    covariate = row["variable_label"]
    is_continuous = int(row["continuous"]) == 1
    type_ = "Mean" if is_continuous else "Proportion"

    control_mean = row["0_mean"]
    control_sd = row["0_sd"]
    treatment_mean = row["1_mean"]
    treatment_sd = row["1_sd"]
    diff = control_mean - treatment_mean
    pval = row["p_val_1_0"]

    # Add significance stars
    if pd.isna(pval):
        stars = ""
    elif pval < 0.01:
        stars = "**"
    elif pval < 0.05:
        stars = "*"
    else:
        stars = ""

    print(f"{covariate:<25} {type_:<12} {control_mean:>6.2f} ({control_sd:>5.2f}) "
          f"{treatment_mean:>6.2f} ({treatment_sd:>5.2f}) {diff:>8.2f}{stars:<4} {pval:>8.2f}")

print("-" * 80)
print(f"{'Observations':<25} {'':<12} {int(balance_table.iloc[0]['0_n']):>15} {int(balance_table.iloc[0]['1_n']):>15}")
print("=" * 80)
print("\nNote: * p<0.05, ** p<0.01")


# --- Save results to LaTeX ---------------------------------------------------
# Create formatted table for LaTeX output
latex_data = []
for i in range(len(balance_table)):
    row = balance_table.iloc[i]
    covariate = row["variable_label"]
    is_continuous = int(row["continuous"]) == 1
    type_ = "Mean" if is_continuous else "Proportion"

    control_mean = row["0_mean"]
    control_sd = row["0_sd"]
    treatment_mean = row["1_mean"]
    treatment_sd = row["1_sd"]
    diff = control_mean - treatment_mean
    pval = row["p_val_1_0"]

    # Add significance stars
    if pd.isna(pval):
        stars = ""
    elif pval < 0.01:
        stars = "**"
    elif pval < 0.05:
        stars = "*"
    else:
        stars = ""

    # Format for LaTeX
    latex_data.append({
        'Covariate': covariate,
        'Type': type_,
        'Control Mean (SD)': f"{control_mean:.2f} ({control_sd:.2f})",
        'Treatment Mean (SD)': f"{treatment_mean:.2f} ({treatment_sd:.2f})",
        'Difference': f"{diff:.2f}{stars}",
        'p-value': f"{pval:.2f}"
    })

results_table = pd.DataFrame(latex_data)

# Save to LaTeX
tex_file = OUTPUT_DIR / "Exhibit_6_5_python.tex"
results_table.to_latex(
    tex_file,
    index=False,
    escape=False,
    caption="Covariate Balance with CRE in Lalonde (1986; NSW)",
    label="tab:exhibit_6_5"
)

print(f"\n✓ Saved to: {tex_file}\n")

# =============================================================================
# END OF EXHIBIT 6.5
# =============================================================================
