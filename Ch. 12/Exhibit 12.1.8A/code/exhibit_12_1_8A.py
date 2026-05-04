# =============================================================================
# Exhibit 12.1.8A: Lee Bounds (Upper)
# =============================================================================
# Implements Lee (2009) bounds for treatment effects with differential attrition.
# Upper bound: Trims observations from top of control group distribution.
#
# Lee bounds address selective attrition by trimming the distribution with higher
# response rates to match the response rate of the group with lower response.
# The upper bound trims from the top of the control distribution, providing an
# optimistic estimate of the treatment effect.
#
# Reference: Lee, D. S. (2009). Training, Wages, and Sample Selection: Estimating
# Sharp Bounds on Treatment Effects. The Review of Economic Studies, 76(3), 1071-1102.

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


# --- Load and filter data ----------------------------------------------------
# Load synthetic data (for testing/demonstration)
data_12_1_8A = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_1_8A = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")




data_12_1_8A['year'] = pd.to_numeric(data_12_1_8A['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_1_8A = data_12_1_8A[
    (data_12_1_8A['year'] >= 2012) &
    ((data_12_1_8A['treatment'] == 'control') |
     (data_12_1_8A['treatment'] == 'prek')) &
    (data_12_1_8A['kinderprep'] == 0) &
    (data_12_1_8A['late_randomized'] == 0) &
    (data_12_1_8A['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_1_8A['block'] = cleaned_data_12_1_8A.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_1_8A['std_cog_sl'] = cleaned_data_12_1_8A['std_cog_sl'].where(
    cleaned_data_12_1_8A['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_1_8A['d_i'] = (cleaned_data_12_1_8A['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_1_8A['r_i'] = cleaned_data_12_1_8A['std_cog_sl'].notna().astype(int)


# --- Calculate trimming parameters -------------------------------------------
# Calculate response rates by treatment group
response_rate_control = cleaned_data_12_1_8A.loc[
    cleaned_data_12_1_8A['d_i'] == 0, 'r_i'
].mean()
response_rate_prek = cleaned_data_12_1_8A.loc[
    cleaned_data_12_1_8A['d_i'] == 1, 'r_i'
].mean()

# Calculate fraction to trim from control group (group with lower response rate)
trimming_fraction = (response_rate_prek - response_rate_control) / response_rate_prek


# --- Apply Lee bounds trimming (upper) ---------------------------------------
# Upper bound: Trim from top of control distribution
# Find quantile threshold for trimming
quantile_threshold = cleaned_data_12_1_8A.loc[
    cleaned_data_12_1_8A['d_i'] == 0, 'std_cog_sl'
].quantile(1 - trimming_fraction)

# Keep control observations below threshold (trim top)
control_trimmed = cleaned_data_12_1_8A[
    (cleaned_data_12_1_8A['d_i'] == 0) &
    (cleaned_data_12_1_8A['std_cog_sl'] < quantile_threshold)
]

# Combine trimmed control group with full treatment group
upper_bound_data = pd.concat(
    [control_trimmed, cleaned_data_12_1_8A[cleaned_data_12_1_8A['d_i'] == 1]],
    ignore_index=True
)


# --- Calculate summary statistics --------------------------------------------
prek_avg_upper = upper_bound_data.loc[
    upper_bound_data['d_i'] == 1, 'std_cog_sl'
].mean(skipna=True)
ctrl_avg_upper = upper_bound_data.loc[
    upper_bound_data['d_i'] == 0, 'std_cog_sl'
].mean(skipna=True)


# --- Create plot -------------------------------------------------------------
plt.figure(figsize=(10, 6))

# Kernel density plot with separate distributions by treatment status
# Colors: Control (d_i=0) -> lightcoral, Pre-K (d_i=1) -> teal
sns.kdeplot(
    data=upper_bound_data,
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
plt.axvline(x=prek_avg_upper, color='blue', linestyle='--', linewidth=0.8,
            label=f'Pre-K Mean: {prek_avg_upper:.3f}')
plt.axvline(x=ctrl_avg_upper, color='red', linestyle='--', linewidth=0.8,
            label=f'Control Mean (trimmed): {ctrl_avg_upper:.3f}')

# Labels and title
plt.xlabel('Cognitive Test Score after Summer Loss', fontsize=11)
plt.ylabel('Density', fontsize=11)
plt.title('Lee Bounds (Upper)', fontsize=13, fontweight='bold')

# Create custom legend to match colors
handles = [
    plt.Rectangle((0, 0), 1, 1, fc='lightcoral', alpha=0.4),
    plt.Rectangle((0, 0), 1, 1, fc='teal', alpha=0.4)
]
plt.legend(handles, ['Control (trimmed)', 'Pre-K'], title='Treatment Status', loc='best')

# Save plot
output_file = OUTPUT_DIR / 'exhibit_12_1_8A_lee_bounds_upper.png'
plt.savefig(output_file, dpi=300, bbox_inches='tight')
plt.close()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.1.8A: Lee Bounds (Upper) - Plot saved")
print("=" * 80)
print(f"Saved to: {output_file}")
print(f"Response Rate (Control): {response_rate_control:.3f}")
print(f"Response Rate (Pre-K): {response_rate_prek:.3f}")
print(f"Trimming Fraction: {trimming_fraction:.3f}")
print(f"Pre-K Average: {prek_avg_upper:.3f}")
print(f"Control Average (trimmed): {ctrl_avg_upper:.3f}")
print(f"Treatment Effect (Upper Bound): {prek_avg_upper - ctrl_avg_upper:.3f}")
print("=" * 80)

# =============================================================================
# END OF EXHIBIT 12.1.8A
# =============================================================================
