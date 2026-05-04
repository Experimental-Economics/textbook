// =============================================================================
// Rerandomization
// =============================================================================
// Implements Rerandomization to improve covariate balance beyond what is
// achieved by standard Complete Randomization. The procedure repeatedly applies
// Complete Randomization and checks for significant imbalances on specified
// baseline covariates. If any covariate shows significant imbalance (p < threshold),
// the randomization is rejected and the process repeats.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 6/Rerandomization/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"


// --- Parameters --------------------------------------------------------------
// Set random seed for reproducibility
// set seed 42

// Set significance level for balance tests
local SIGNIFICANCE_LEVEL = 0.1

// Maximum number of rerandomization attempts
local MAX_ATTEMPTS = 1000


// --- Load data ---------------------------------------------------------------
// Load input dataset
// TODO: Replace 'unique_data_clean_main_synthetic.dta' with your actual dataset filename
use "`data_dir'/unique_data_clean_main_synthetic.dta", clear


// --- Define balance variables ------------------------------------------------
// Variables to check for balance
// Categorical variables (will use proportion tests)
local CATEGORICAL_VARS "female race_w hl_eng_span"

// Continuous variables (will use t-tests)
local CONTINUOUS_VARS "std_cog_pre std_ncog_pre birthweight"

// Combine all balance variables
local BALANCE_VARS "`CATEGORICAL_VARS' `CONTINUOUS_VARS'"


// --- Rerandomization loop ----------------------------------------------------
// Initialize
local balanced = 0
local num_attempts = 0

// Save original data
preserve

while `balanced' == 0 & `num_attempts' < `MAX_ATTEMPTS' {

    // Restore original data for each attempt
    restore, preserve

    // Increment attempt counter
    local num_attempts = `num_attempts' + 1

    // --- Apply Complete Randomization ----------------------------------------
    // Create temporary variable to preserve original order
    gen _temp_order = _n

    // Generate random uniform variable for shuffling
    gen _random = runiform()

    // Sort by random variable to shuffle the dataset
    sort _random

    // Calculate split point
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

    // Assign treatment
    gen Treatment = 0
    replace Treatment = 1 if _n <= `n_treatment'

    // Restore original order
    sort _temp_order
    drop _temp_order _random

    // --- Check balance -------------------------------------------------------
    local all_balanced = 1
    local min_pval = 1

    // Check each balance variable
    foreach var of local BALANCE_VARS {

        // Determine if continuous or categorical
        local is_continuous = 0
        foreach cvar of local CONTINUOUS_VARS {
            if "`var'" == "`cvar'" {
                local is_continuous = 1
            }
        }

        if `is_continuous' == 1 {
            // Use t-test for continuous variables
            quietly ttest `var', by(Treatment) unequal
            local pval = r(p)
        }
        else {
            // Use proportion test for categorical variables
            quietly proportion `var', over(Treatment)

            // Calculate z-test for difference in proportions manually
            quietly mean `var' if Treatment == 0
            local p0 = r(table)[1,1]
            quietly count if Treatment == 0
            local n0 = r(N)

            quietly mean `var' if Treatment == 1
            local p1 = r(table)[1,1]
            quietly count if Treatment == 1
            local n1 = r(N)

            // Calculate standard error and z-statistic
            local se = sqrt(`p0'*(1-`p0')/`n0' + `p1'*(1-`p1')/`n1')
            if `se' > 0 {
                local z = abs(`p0' - `p1') / `se'
                local pval = 2 * normal(-abs(`z'))
            }
            else {
                local pval = 1
            }
        }

        // Store p-value for final reporting
        local pval_`var' = `pval'

        // Update minimum p-value
        if `pval' < `min_pval' {
            local min_pval = `pval'
        }

        // Check if this variable is balanced
        if `pval' < `SIGNIFICANCE_LEVEL' {
            local all_balanced = 0
        }
    }

    // Check if all variables are balanced
    if `all_balanced' == 1 {
        local balanced = 1
        restore, not
    }
}

// Check if we found a balanced randomization
if `balanced' == 0 {
    display as error "Failed to achieve balance after `MAX_ATTEMPTS' attempts."
    display as error "Consider relaxing the significance level or reducing the number of balance variables."
    exit 1
}


// --- Print summary statistics ------------------------------------------------
// Count observations by treatment status
quietly count
local n_total = r(N)

quietly count if Treatment == 1
local n_treatment = r(N)

quietly count if Treatment == 0
local n_control = r(N)

local actual_proportion = `n_treatment' / `n_total'

display _newline
display "{hline 80}"
display "RERANDOMIZATION SUMMARY"
display "{hline 80}"
display "Significance threshold:            " %6.3f `SIGNIFICANCE_LEVEL'
display "Number of rerandomizations:        " %9.0fc `num_attempts'
display "Balance variables checked:         " %9.0fc `: word count `BALANCE_VARS''
display "Total observations:                " %9.0fc `n_total'
display "Assigned to treatment:             " %9.0fc `n_treatment'
display "Assigned to control:               " %9.0fc `n_control'
display "Treatment proportion:              " %6.3f `actual_proportion'
display "{hline 80}"

// Print balance check results
display _newline
display "Final Balance Check (p-values):"
display "{hline 80}"
display "{ralign 20:Variable} {ralign 15:Type} {ralign 12:p-value} {ralign 10:Status}"
display "{hline 80}"

foreach var of local BALANCE_VARS {
    // Determine if continuous or categorical
    local is_continuous = 0
    foreach cvar of local CONTINUOUS_VARS {
        if "`var'" == "`cvar'" {
            local is_continuous = 1
        }
    }

    if `is_continuous' == 1 {
        local var_type "Continuous"
    }
    else {
        local var_type "Binary"
    }

    local pval = `pval_`var''

    if `pval' >= `SIGNIFICANCE_LEVEL' {
        local status "Balanced"
    }
    else {
        local status "IMBALANCED"
    }

    display "{ralign 20:`var'} {ralign 15:`var_type'} " %12.4f `pval' " {ralign 10:`status'}"
}

display "{hline 80}"
display "Minimum p-value: " %6.4f `min_pval'
display "{hline 80}"
display _newline
display "Note: Rerandomization improves covariate balance by rejecting randomizations"
display "      with any p-value below `SIGNIFICANCE_LEVEL'. Standard errors and confidence"
display "      intervals should be adjusted to account for the rerandomization procedure."


// --- Save randomized dataset -------------------------------------------------
// Save to output directory with number of rerandomizations in filename
local output_file "`output_dir'/rerandomized_dataset_`num_attempts'_attempts.dta"
save "`output_file'", replace

display _newline
display "Saved to: `output_file'"
display _newline


// =============================================================================
// END OF RERANDOMIZATION
// =============================================================================
