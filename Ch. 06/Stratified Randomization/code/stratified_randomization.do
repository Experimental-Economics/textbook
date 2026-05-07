// =============================================================================
// Stratified Randomization
// =============================================================================
// Implements Stratified Randomization (also called Block Randomization) to assign
// treatment status within strata defined by baseline covariates. This ensures
// balance on the stratification variables and can improve precision of treatment
// effect estimates.
//
// The procedure:
// 1. Partition the sample into strata based on specified covariates
// 2. Apply Complete Randomization within each stratum
// 3. Combine the randomized strata back together

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 6/Stratified Randomization/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"


// --- Parameters --------------------------------------------------------------
// Set random seed for reproducibility
// set seed 42


// --- Load data ---------------------------------------------------------------
// Load input dataset
// TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
use "`data_dir'/unique_data_clean_main_synthetic.dta", clear


// --- Define stratification variables ----------------------------------------
// Categorical variables: will split by unique values
local CATEGORICAL_VARS "female race_w"

// Continuous variables: will split at median
local CONTINUOUS_VARS "std_cog_pre birthweight"


// --- Create stratification groups -------------------------------------------
// Create temporary variable to preserve original order
gen _original_order = _n

// For continuous variables, create binary indicators (above/below median)
foreach var of local CONTINUOUS_VARS {
    quietly summarize `var', detail
    local median_`var' = r(p50)
    gen _strata_`var' = (`var' > r(p50))
    label variable _strata_`var' "`var' > median"
}

// Create combined strata identifier
// Combine all categorical and created continuous strata variables
local strata_vars "`CATEGORICAL_VARS'"
foreach var of local CONTINUOUS_VARS {
    local strata_vars "`strata_vars' _strata_`var'"
}

// Generate unique stratum ID
egen _stratum_id = group(`strata_vars'), missing


// --- Apply Complete Randomization within each stratum -----------------------
// Generate random variable for shuffling within strata
gen _random = runiform()

// Sort by stratum and random variable
sort _stratum_id _random

// Within each stratum, assign treatment to first half
by _stratum_id: gen _n_in_stratum = _n
by _stratum_id: gen _N_in_stratum = _N

// Calculate treatment assignment within each stratum
by _stratum_id: gen _n_half = floor(_N / 2)

// If odd stratum size, randomly assign extra observation
gen _extra_to_treatment = .
by _stratum_id: replace _extra_to_treatment = (runiform() < 0.5) if _n == 1

// Determine number to assign to treatment in each stratum
by _stratum_id: gen _n_treatment = _n_half + _extra_to_treatment * mod(_N, 2) if _n == 1
by _stratum_id: egen _stratum_n_treatment = max(_n_treatment)

// Assign treatment
gen Treatment = (_n_in_stratum <= _stratum_n_treatment)

// Restore original order
sort _original_order


// --- Print summary statistics ------------------------------------------------
// Overall counts
quietly count
local n_total = r(N)

quietly count if Treatment == 1
local n_treatment = r(N)

quietly count if Treatment == 0
local n_control = r(N)

local actual_proportion = `n_treatment' / `n_total'

display _newline
display "{hline 80}"
display "STRATIFIED RANDOMIZATION SUMMARY"
display "{hline 80}"

// Display stratification variables
if "`CATEGORICAL_VARS'" != "" {
    display "Categorical variables:             `CATEGORICAL_VARS'"
}
if "`CONTINUOUS_VARS'" != "" {
    display "Continuous variables (median split): `CONTINUOUS_VARS'"
}

display "Total observations:                " %9.0fc `n_total'
display "Assigned to treatment:             " %9.0fc `n_treatment'
display "Assigned to control:               " %9.0fc `n_control'
display "Treatment proportion:              " %6.3f `actual_proportion'
display "{hline 80}"

// Balance by stratification variables
display _newline
display "Balance by Stratification Variables:"
display "{hline 80}"

// Display balance for categorical variables
foreach var of local CATEGORICAL_VARS {
    display _newline
    display "`var' (categorical):"
    tabulate `var' Treatment, row
}

// Display balance for continuous variables (median split)
foreach var of local CONTINUOUS_VARS {
    quietly summarize `var', detail
    local median_val = r(p50)
    display _newline
    display "`var' (continuous, median = " %6.2f `median_val' "):"
    tabulate _strata_`var' Treatment, row
}

display _newline
display "{hline 80}"
display _newline
display "Note: Stratified randomization ensures exact balance on stratification"
display "      variables by applying Complete Randomization within each stratum."
display "      Continuous variables are split at the median calculated from the full dataset."


// --- Clean up temporary variables --------------------------------------------
drop _original_order _random _n_in_stratum _N_in_stratum _n_half ///
     _extra_to_treatment _n_treatment _stratum_n_treatment _stratum_id

// Drop continuous strata indicators
foreach var of local CONTINUOUS_VARS {
    drop _strata_`var'
}


// --- Save randomized dataset -------------------------------------------------
// Save to output directory
save "`output_dir'/stratified_randomized_dataset.dta", replace

display _newline
display "Saved to: `output_dir'/stratified_randomized_dataset.dta"
display _newline


// =============================================================================
// END OF STRATIFIED RANDOMIZATION
// =============================================================================
