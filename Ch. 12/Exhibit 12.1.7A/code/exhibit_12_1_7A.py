# =============================================================================
# Exhibit 12.1.7A: IPW Model Outcomes
# =============================================================================
# Visualizes the density distribution of cognitive scores using Inverse Probability
# Weighting (IPW) to adjust for differential attrition.
#
# This plot shows how the outcome distributions change when we weight observations
# by the inverse of their predicted probability of response, conditional on
# baseline covariates. This reweighting adjusts for selective attrition.

from pathlib import Path
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
import statsmodels.api as sm


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location.
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Load and filter data ----------------------------------------------------
# Load synthetic data (for testing/demonstration)
data_12_1_7A = pd.read_stata(DATA_DIR / "unique_data_clean_main_synthetic.dta")
# To use actual CHECC data, comment out the line above and uncomment the line below:
# data_12_1_7A = pd.read_stata(DATA_DIR / "unique_data_clean_main.dta")


data_12_1_7A['year'] = pd.to_numeric(data_12_1_7A['year'], errors='coerce')

# Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
# and late randomized, require baseline cognitive score
cleaned_data_12_1_7A = data_12_1_7A[
    (data_12_1_7A['year'] >= 2012) &
    ((data_12_1_7A['treatment'] == 'control') |
     (data_12_1_7A['treatment'] == 'prek')) &
    (data_12_1_7A['kinderprep'] == 0) &
    (data_12_1_7A['late_randomized'] == 0) &
    (data_12_1_7A['has_cog_pre'] != 0)
].copy()

# Create block variable (prioritize 2012 block, fallback to 2013)
cleaned_data_12_1_7A['block'] = cleaned_data_12_1_7A.apply(
    lambda row: row['block_2012'] if row['block_2012'] != "" else row['block_2013'],
    axis=1
)

# Set summer loss cognitive score to NA when not observed
cleaned_data_12_1_7A['std_cog_sl'] = cleaned_data_12_1_7A['std_cog_sl'].where(
    cleaned_data_12_1_7A['has_cog_sl'] != 0, pd.NA
)

# Treatment indicator: 1 if pre-K, 0 if control
cleaned_data_12_1_7A['d_i'] = (cleaned_data_12_1_7A['treatment'] == "prek").astype(int)

# Response indicator: 1 if outcome observed, 0 if attrited
cleaned_data_12_1_7A['r_i'] = cleaned_data_12_1_7A['std_cog_sl'].notna().astype(int)


# --- Estimate propensity scores ----------------------------------------------
# Fit logistic regression models to predict response probability by treatment group
psreg_d_1_7A = sm.GLM.from_formula(
    'r_i ~ female + race_w + hl_eng_span + birthweight',
    data=cleaned_data_12_1_7A[cleaned_data_12_1_7A['d_i'] == 1],
    family=sm.families.Binomial(link=sm.families.links.Logit())
).fit()

psreg_d_0_7A = sm.GLM.from_formula(
    'r_i ~ female + race_w + hl_eng_span + birthweight',
    data=cleaned_data_12_1_7A[cleaned_data_12_1_7A['d_i'] == 0],
    family=sm.families.Binomial(link=sm.families.links.Logit())
).fit()


# --- Create IPW dataset ------------------------------------------------------
# Predict response probabilities for each treatment group
ipwdata_1_7A = cleaned_data_12_1_7A.loc[cleaned_data_12_1_7A['d_i'] == 1].copy()
ipwdata_1_7A['prob'] = psreg_d_1_7A.predict(ipwdata_1_7A)

ipwdata_0_7A = cleaned_data_12_1_7A.loc[cleaned_data_12_1_7A['d_i'] == 0].copy()
ipwdata_0_7A['prob'] = psreg_d_0_7A.predict(ipwdata_0_7A)

# Combine treatment groups
ipwdata_12_1_7A = pd.concat([ipwdata_0_7A, ipwdata_1_7A])

# Calculate inverse probability weights
ipwdata_12_1_7A['invwt'] = 1 / ipwdata_12_1_7A['prob']


# --- Calculate weighted summary statistics -----------------------------------
# Calculate weighted mean outcomes for each group
prek_data = ipwdata_12_1_7A[ipwdata_12_1_7A['d_i'] == 1]
prek_avg_ipw = (prek_data['std_cog_sl'] * prek_data['invwt']).sum() / prek_data['invwt'].sum()

ctrl_data = ipwdata_12_1_7A[ipwdata_12_1_7A['d_i'] == 0]
ctrl_avg_ipw = (ctrl_data['std_cog_sl'] * ctrl_data['invwt']).sum() / ctrl_data['invwt'].sum()


# --- Create plot -------------------------------------------------------------
plt.figure(figsize=(10, 6))

# Kernel density plot with separate distributions by treatment status
# Colors: Control (d_i=0) -> lightcoral, Pre-K (d_i=1) -> teal
sns.kdeplot(
    data=ipwdata_12_1_7A,
    x='std_cog_sl',
    hue='d_i',
    palette={0: 'lightcoral', 1: 'teal'},
    fill=True,
    alpha=0.4,
    linewidth=0.5,
    bw_adjust=0.5,
    common_norm=False
)

# Add vertical lines at weighted group means
plt.axvline(x=prek_avg_ipw, color='blue', linestyle='--', linewidth=0.8,
            label=f'Pre-K Mean (IPW): {prek_avg_ipw:.3f}')
plt.axvline(x=ctrl_avg_ipw, color='red', linestyle='--', linewidth=0.8,
            label=f'Control Mean (IPW): {ctrl_avg_ipw:.3f}')

# Labels and title
plt.xlabel('Cognitive Test Score after Summer Loss', fontsize=11)
plt.ylabel('Density', fontsize=11)
plt.title('IPW Model Outcomes', fontsize=13, fontweight='bold')

# Create custom legend to match colors
handles = [
    plt.Rectangle((0, 0), 1, 1, fc='lightcoral', alpha=0.4),
    plt.Rectangle((0, 0), 1, 1, fc='teal', alpha=0.4)
]
plt.legend(handles, ['Control', 'Pre-K'], title='Treatment Status', loc='best')

# Save plot
output_file = OUTPUT_DIR / 'exhibit_12_1_7A_ipw_model_outcomes.png'
plt.savefig(output_file, dpi=300, bbox_inches='tight')
plt.close()


# --- Print results -----------------------------------------------------------
print("\n" + "=" * 80)
print("EXHIBIT 12.1.7A: IPW Model Outcomes - Plot saved")
print("=" * 80)
print(f"Saved to: {output_file}")
print(f"Pre-K Average (weighted): {prek_avg_ipw:.3f}")
print(f"Control Average (weighted): {ctrl_avg_ipw:.3f}")
print(f"Treatment Effect (IPW): {prek_avg_ipw - ctrl_avg_ipw:.3f}")
print("=" * 80)

# =============================================================================
# END OF EXHIBIT 12.1.7A
# =============================================================================
