// =============================================================================
// Bernoulli Randomization
// =============================================================================
// Implements Bernoulli randomization to assign treatment status to observations
// in a dataset. Each unit is independently assigned to treatment with probability p
// and to control with probability 1-p.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 6/Bernulli Randomization/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"


// --- Parameters --------------------------------------------------------------
// Set treatment probability (default: 0.5 for equal allocation)
local TREATMENT_PROBABILITY = 0.5

// Set random seed for reproducibility
// set seed 42


// --- Load data ---------------------------------------------------------------
// Load input dataset
// TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
use "`data_dir'/unique_data_clean_main_synthetic.dta", clear


// --- Apply Bernoulli randomization -------------------------------------------
// Generate random uniform draws between 0 and 1
// Assign treatment if random draw < probability
gen random_draw = runiform()
gen Treatment = (random_draw < `TREATMENT_PROBABILITY')

// Drop temporary variable
drop random_draw


// --- Print summary statistics ------------------------------------------------
// Count observations by treatment status
quietly count
local n_total = r(N)

quietly count if Treatment == 1
local n_treatment = r(N)

quietly count if Treatment == 0
local n_control = r(N)

local actual_proportion = `n_treatment' / `n_total'
local expected_treated = `n_total' * `TREATMENT_PROBABILITY'

display _newline
display "{hline 80}"
display "BERNOULLI RANDOMIZATION SUMMARY"
display "{hline 80}"
display "Treatment probability (p):        " %6.3f `TREATMENT_PROBABILITY'
display "Total observations:                " %9.0fc `n_total'
display "Assigned to treatment:             " %9.0fc `n_treatment'
display "Assigned to control:               " %9.0fc `n_control'
display "Actual treatment proportion:       " %6.3f `actual_proportion'
display "Expected number treated (n*p):     " %9.1f `expected_treated'
display "{hline 80}"


// --- Save randomized dataset -------------------------------------------------
// Save to output directory
// TODO: Replace 'randomized_dataset.dta' with your desired output filename
save "`output_dir'/randomized_dataset.dta", replace

display _newline
display "Saved to: `output_dir'/randomized_dataset.dta"
display _newline


// =============================================================================
// END OF BERNOULLI RANDOMIZATION
// =============================================================================
