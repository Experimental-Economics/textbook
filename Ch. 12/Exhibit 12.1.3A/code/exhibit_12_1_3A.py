# =============================================================================
# Exhibit 12.1.3A: Horowitz and Manski Bounds (Lower)
# =============================================================================
# Visualizes the lower bound scenario for treatment effects using kernel density plots.
# Lower bound: worst case for treatment (assign -3), best case for control (assign +3)
#
# This plot shows the distribution of outcomes under the pessimistic bounding
# assumption where all treatment attritors had the worst possible outcome and
# all control attritors had the best possible outcome. This provides a lower
# bound on the treatment effect.
#
# Reference: Horowitz, J. L., & Manski, C. F. (2000). Nonparametric Analysis
# of Randomized Experiments with Missing Covariate and Outcome Data.
# Journal of the American Statistical Association, 95(449), 77-84.

from pathlib import Path
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Parameters --------------------------------------------------------------
# Bounds for outcome variable (standardized cognitive test scores)
UPPER_BOUND = 3
LOWER_BOUND = -3


# --- Load and filter data ----------------------------------------------------
# Load synthetic data (for testing/demonstration)
data_12_1_3A = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_1_3A = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")


data_12_1_3A['year'] = pd.to_numeric(data_12_1_3A['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_1_3A = data_12_1_3A[
    (data_12_1_3A['year'] >= 2012) &
    ((data_12_1_3A['treatment'] == 'control') |
     (data_12_1_3A['treatment'] == 'prek')) &
    (data_12_1_3A['kinderprep'] == 0) &
    (data_12_1_3A['late_randomized'] == 0) &
    (data_12_1_3A['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_1_3A['block'] = cleaned_data_12_1_3A.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_1_3A['std_cog_sl'] = cleaned_data_12_1_3A['std_cog_sl'].where(
    cleaned_data_12_1_3A['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_1_3A['d_i'] = (cleaned_data_12_1_3A['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_1_3A['r_i'] = cleaned_data_12_1_3A['std_cog_sl'].notna().astype(int)


# --- Create lower bound dataset ----------------------------------------------
# Lower bound: Assign worst outcome to treatment attritors, best to control attritors
# This minimizes the treatment effect estimate
lower_bound_data_12_1_3A = cleaned_data_12_1_3A.copy()
lower_bound_data_12_1_3A.loc[
    (lower_bound_data_12_1_3A['r_i'] == 0) & (lower_bound_data_12_1_3A['d_i'] == 1),
    'std_cog_sl'
] = LOWER_BOUND
lower_bound_data_12_1_3A.loc[
    (lower_bound_data_12_1_3A['r_i'] == 0) & (lower_bound_data_12_1_3A['d_i'] == 0),
    'std_cog_sl'
] = UPPER_BOUND


# --- Calculate summary statistics --------------------------------------------
# Calculate mean outcomes for each group under lower bound scenario
prek_avg_lower = lower_bound_data_12_1_3A[
    lower_bound_data_12_1_3A['d_i'] == 1
]['std_cog_sl'].mean()
ctrl_avg_lower = lower_bound_data_12_1_3A[
    lower_bound_data_12_1_3A['d_i'] == 0
]['std_cog_sl'].mean()


# --- Create plot -------------------------------------------------------------
plt.figure(figsize=(10, 6))

# Kernel density plot with separate distributions by treatment status
# Colors: Control (d_i=0) -> lightcoral, Pre-K (d_i=1) -> teal
sns.kdeplot(
    data=lower_bound_data_12_1_3A,
    x='std_cog_sl',
    hue='d_i',
    palette={0: 'lightcoral', 1: 'teal'},
    fill=True,
    alpha=0.4,
    linewidth=0.5,
    bw_adjust=0.5,
    common_norm=False
)

# Add vertical lines at group means
plt.axvline(x=prek_avg_lower, color='blue', linestyle='--', linewidth=0.8,
            label=f'Pre-K Mean: {prek_avg_lower:.3f}')
plt.axvline(x=ctrl_avg_lower, color='red', linestyle='--', linewidth=0.8,
            label=f'Control Mean: {ctrl_avg_lower:.3f}')

# Labels and title
plt.xlabel('Cognitive Test Score after Summer Loss', fontsize=11)
plt.ylabel('Density', fontsize=11)
plt.title('Horowitz and Manski Bounds (Lower)', fontsize=13, fontweight='bold')

# Create custom legend to match colors
handles = [
    plt.Rectangle((0, 0), 1, 1, fc='lightcoral', alpha=0.4),
    plt.Rectangle((0, 0), 1, 1, fc='teal', alpha=0.4)
]
plt.legend(handles, ['Control', 'Pre-K'], title='Treatment Status', loc='best')

# Save plot
output_file = OUTPUT_DIR / 'exhibit_12_1_3A_hm_bounds_lower.png'
plt.savefig(output_file, dpi=300, bbox_inches='tight')
plt.close()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.1.3A: Horowitz and Manski Bounds (Lower) - Plot saved")
print("=" * 80)
print(f"Saved to: {output_file}")
print(f"Pre-K Average: {prek_avg_lower:.3f}")
print(f"Control Average: {ctrl_avg_lower:.3f}")
print(f"Treatment Effect (Lower Bound): {prek_avg_lower - ctrl_avg_lower:.3f}")
print("=" * 80)

# =============================================================================
# END OF EXHIBIT 12.1.3A
# =============================================================================
