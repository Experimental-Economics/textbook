// =============================================================================
// Complete Randomization
// =============================================================================
// Implements Complete Randomization to assign treatment status to observations
// in a dataset. Exactly n/2 units are assigned to treatment (or n/2 +- 0.5 if n is odd),
// with the remaining units assigned to control.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 6/Complete Randomization /code"

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


// --- Apply Complete randomization --------------------------------------------
// Create temporary variable to preserve original order
gen _temp_order = _n

// Generate random uniform variable for shuffling
gen _random = runiform()

// Sort by random variable to shuffle the dataset
sort _random

// Calculate split point: if odd, randomly assign the extra observation
quietly count
local n_total = r(N)
local n_half = floor(`n_total' / 2)

// If odd sample size, randomly decide which group gets the extra observation
if mod(`n_total', 2) == 1 {
    local extra_to_treatment = runiform() < 0.5
    local n_treatment = `n_half' + `extra_to_treatment'
}
else {
    local n_treatment = `n_half'
}

// Assign treatment to first half, control to second half
gen Treatment = 0
replace Treatment = 1 if _n <= `n_treatment'

// Restore original order
sort _temp_order

// Drop temporary variables
drop _temp_order _random


// --- Print summary statistics ------------------------------------------------
// Count observations by treatment status
quietly count
local n_total = r(N)

quietly count if Treatment == 1
local n_treatment = r(N)

quietly count if Treatment == 0
local n_control = r(N)

local actual_proportion = `n_treatment' / `n_total'
local sample_diff = abs(`n_treatment' - `n_control')

display _newline
display "{hline 80}"
display "COMPLETE RANDOMIZATION SUMMARY"
display "{hline 80}"
display "Total observations:                " %9.0fc `n_total'
display "Assigned to treatment:             " %9.0fc `n_treatment'
display "Assigned to control:               " %9.0fc `n_control'
display "Treatment proportion:              " %6.3f `actual_proportion'
display "Sample size difference:            " %9.0fc `sample_diff'
display "{hline 80}"
display _newline
display "Note: Complete randomization fixes the number of treated units at n/2,"
display "      ensuring balanced group sizes. If n is odd, the extra observation"
display "      is randomly assigned to either treatment or control."


// --- Save randomized dataset -------------------------------------------------
// Save to output directory
// TODO: Replace 'randomized_dataset.dta' with your desired output filename
save "`output_dir'/randomized_dataset.dta", replace

display _newline
display "Saved to: `output_dir'/randomized_dataset.dta"
display _newline


// =============================================================================
// END OF COMPLETE RANDOMIZATION
// =============================================================================
