# =============================================================================
# Exhibit 12.1.6A: Default Model Outcomes
# =============================================================================
# Visualizes the density distribution of cognitive scores for the default model
# using kernel density plots. Shows available cases only (those who did not attrit).
#
# This plot provides a baseline view of the observed outcome distributions
# without any attrition adjustment. It includes only participants for whom
# we have observed post-treatment outcomes.

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
data_12_1_6A = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_1_6A = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")



data_12_1_6A['year'] = pd.to_numeric(data_12_1_6A['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_1_6A = data_12_1_6A[
    (data_12_1_6A['year'] >= 2012) &
    ((data_12_1_6A['treatment'] == 'control') |
     (data_12_1_6A['treatment'] == 'prek')) &
    (data_12_1_6A['kinderprep'] == 0) &
    (data_12_1_6A['late_randomized'] == 0) &
    (data_12_1_6A['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_1_6A['block'] = cleaned_data_12_1_6A.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_1_6A['std_cog_sl'] = cleaned_data_12_1_6A['std_cog_sl'].where(
    cleaned_data_12_1_6A['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_1_6A['d_i'] = (cleaned_data_12_1_6A['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_1_6A['r_i'] = cleaned_data_12_1_6A['std_cog_sl'].notna().astype(int)


# --- Filter for available cases ---------------------------------------------
# Default model uses only observed cases (no imputation or weighting)
filtered_data_12_1_6A = cleaned_data_12_1_6A[cleaned_data_12_1_6A['r_i'] == 1]


# --- Calculate summary statistics --------------------------------------------
# Calculate mean outcomes for each group (available cases only)
prek_avg_default = filtered_data_12_1_6A[
    filtered_data_12_1_6A['d_i'] == 1
]['std_cog_sl'].mean(skipna=True)
ctrl_avg_default = filtered_data_12_1_6A[
    filtered_data_12_1_6A['d_i'] == 0
]['std_cog_sl'].mean(skipna=True)


# --- Create plot -------------------------------------------------------------
plt.figure(figsize=(10, 6))

# Kernel density plot with separate distributions by treatment status
# Colors: Control (d_i=0) -> lightcoral, Pre-K (d_i=1) -> teal
sns.kdeplot(
    data=filtered_data_12_1_6A,
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
plt.axvline(x=prek_avg_default, color='blue', linestyle='--', linewidth=0.8,
            label=f'Pre-K Mean: {prek_avg_default:.3f}')
plt.axvline(x=ctrl_avg_default, color='red', linestyle='--', linewidth=0.8,
            label=f'Control Mean: {ctrl_avg_default:.3f}')

# Labels and title
plt.xlabel('Cognitive Test Score after Summer Loss', fontsize=11)
plt.ylabel('Density', fontsize=11)
plt.title('Default Model Outcomes', fontsize=13, fontweight='bold')

# Create custom legend to match colors
handles = [
    plt.Rectangle((0, 0), 1, 1, fc='lightcoral', alpha=0.4),
    plt.Rectangle((0, 0), 1, 1, fc='teal', alpha=0.4)
]
plt.legend(handles, ['Control', 'Pre-K'], title='Treatment Status', loc='best')

# Save plot
output_file = OUTPUT_DIR / 'exhibit_12_1_6A_default_model_outcomes.png'
plt.savefig(output_file, dpi=300, bbox_inches='tight')
plt.close()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.1.6A: Default Model Outcomes - Plot saved")
print("=" * 80)
print(f"Saved to: {output_file}")
print(f"Pre-K Average: {prek_avg_default:.3f}")
print(f"Control Average: {ctrl_avg_default:.3f}")
print(f"Treatment Effect: {prek_avg_default - ctrl_avg_default:.3f}")
print(f"Sample Size (Pre-K): {(filtered_data_12_1_6A['d_i'] == 1).sum()}")
print(f"Sample Size (Control): {(filtered_data_12_1_6A['d_i'] == 0).sum()}")
print("=" * 80)

# =============================================================================
# END OF EXHIBIT 12.1.6A
# =============================================================================
