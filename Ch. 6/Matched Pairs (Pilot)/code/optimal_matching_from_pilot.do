// =============================================================================
// Optimal Matched-Pairs Randomization Using Pilot Study
// =============================================================================
// Implements optimal matched-pairs randomization based on Bai (2022) framework
// for minimizing mean-squared error. Uses pilot study regression to estimate
// expected outcomes g_i = E[Y_i(1) + Y_i(0) | X_i] for main sample, then creates
// matched pairs by sorting on g_i and pairing adjacent units.
//
// Steps:
//   1. Load pilot data (with Treatment and Outcome from previous randomization)
//   2. Run regression on pilot to estimate relationship between covariates and outcomes
//   3. For main sample: predict outcomes under D=0 and D=1
//   4. Calculate g_hat = g_0 + g_1 for each unit
//   5. Sort main sample by g_hat
//   6. Create matched pairs from sorted data (pair adjacent units)
//   7. Within each pair, randomly assign treatment
//
// Section 6.3.5.1: Efficient Matching Minimizing Mean-Squared Error

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 6/Matched Pairs (Pilot)/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"


// --- Parameters --------------------------------------------------------------
// TODO: Set random seed for reproducibility
local RANDOM_SEED = 42

// TODO: Specify control variables to use in g_i estimation
// These should be the covariates available in your dataset
// IMPORTANT: Must match the control variables used in the pilot regression
local CONTROL_VARS "female race_w birthweight std_ncog_pre year"


// --- Initialize random state -------------------------------------------------
set seed `RANDOM_SEED'


// --- Load pilot data and estimate g_i model ---------------------------------
// TODO: Specify the pilot data file
// This file should contain:
//   - Treatment variable (0/1 or binary)
//   - Outcome variable (continuous)
//   - All control variables specified in CONTROL_VARS
use "`output_dir'/pilot_sample_with_treatment_and_outcome.dta", clear

// Drop observations with missing controls
foreach var of varlist Treatment Outcome `CONTROL_VARS' {
    drop if missing(`var')
}

// USER CUSTOMIZATION: Modify regression specification if desired
// You can add interaction effects, polynomials, or other transformations
// Example: gen female_x_racew = female * race_w
// Example: gen birthweight_sq = birthweight^2
// Example: regress Outcome Treatment `CONTROL_VARS' female_x_racew birthweight_sq
// Run regression: Outcome ~ Treatment + Controls
regress Outcome Treatment `CONTROL_VARS'

// Store regression coefficients and other statistics
local r2_pilot = e(r2)
local r2_adj_pilot = e(r2_a)
local coef_treatment = _b[Treatment]
local pval_treatment = 2*ttail(e(df_r), abs(_b[Treatment]/_se[Treatment]))

// Store coefficients for prediction
matrix b_pilot = e(b)


// --- Load main sample and estimate g_0 and g_1 ------------------------------
// TODO: Specify the main sample data file
// This file should contain:
//   - All control variables specified in CONTROL_VARS
//   - NO Treatment variable (will be assigned by this script)
use "`output_dir'/main_sample.dta", clear

// Generate row ID to track original indices
gen original_index = _n

// Drop observations with missing controls
foreach var of varlist `CONTROL_VARS' {
    drop if missing(`var')
}

// Count complete cases
local n_complete = _N

// USER CUSTOMIZATION: If you modified the regression specification above,
// you must apply the SAME transformations here for prediction
// Example: If you added gen female_x_racew = female * race_w to regression,
//          you must also generate it here and add to g_0 and g_1 calculations
// Predict under D=0 (Treatment=0)
gen Treatment = 0

// Calculate predicted values using stored coefficients
// Extract coefficients from matrix (order: Treatment, female, race_w, birthweight, std_ncog_pre, year, _cons)
gen double g_0 = b_pilot[1, colnumb(b_pilot, "_cons")]
replace g_0 = g_0 + b_pilot[1, colnumb(b_pilot, "Treatment")] * Treatment
replace g_0 = g_0 + b_pilot[1, colnumb(b_pilot, "female")] * female
replace g_0 = g_0 + b_pilot[1, colnumb(b_pilot, "race_w")] * race_w
replace g_0 = g_0 + b_pilot[1, colnumb(b_pilot, "birthweight")] * birthweight
replace g_0 = g_0 + b_pilot[1, colnumb(b_pilot, "std_ncog_pre")] * std_ncog_pre
replace g_0 = g_0 + b_pilot[1, colnumb(b_pilot, "year")] * year

// Predict under D=1 (Treatment=1)
replace Treatment = 1

gen double g_1 = b_pilot[1, colnumb(b_pilot, "_cons")]
replace g_1 = g_1 + b_pilot[1, colnumb(b_pilot, "Treatment")] * Treatment
replace g_1 = g_1 + b_pilot[1, colnumb(b_pilot, "female")] * female
replace g_1 = g_1 + b_pilot[1, colnumb(b_pilot, "race_w")] * race_w
replace g_1 = g_1 + b_pilot[1, colnumb(b_pilot, "birthweight")] * birthweight
replace g_1 = g_1 + b_pilot[1, colnumb(b_pilot, "std_ncog_pre")] * std_ncog_pre
replace g_1 = g_1 + b_pilot[1, colnumb(b_pilot, "year")] * year

// Calculate g_hat = g_0 + g_1
gen double g_hat = g_0 + g_1

// Calculate summary statistics
quietly summarize g_hat
local mean_g_hat = r(mean)
local sd_g_hat = r(sd)
local min_g_hat = r(min)
local max_g_hat = r(max)

// Clean up temporary variables
drop Treatment


// --- Sort by g_hat and create matched pairs ---------------------------------
// Sort by g_hat (increasing order)
sort g_hat

// Create pairs from adjacent units in sorted order
local n_units = _N
local n_pairs = floor(`n_units' / 2)
local n_unpaired = mod(`n_units', 2)

// Initialize treatment and pair ID columns
gen Treatment_Final = -1
gen Pair_ID = -1

// Create pairs from adjacent units
local pair_id = 0
local i = 1
while `i' <= 2 * `n_pairs' {
    local j = `i' + 1

    // Randomly assign treatment within pair
    local random_flip = runiform()
    if `random_flip' < 0.5 {
        replace Treatment_Final = 1 in `i'
        replace Treatment_Final = 0 in `j'
    }
    else {
        replace Treatment_Final = 0 in `i'
        replace Treatment_Final = 1 in `j'
    }

    // Assign same pair ID
    replace Pair_ID = `pair_id' in `i'
    replace Pair_ID = `pair_id' in `j'

    local pair_id = `pair_id' + 1
    local i = `i' + 2
}

// Handle unpaired unit (if odd number of units)
if `n_unpaired' > 0 {
    local last_obs = _N
    local random_treatment = floor(runiform() * 2)
    replace Treatment_Final = `random_treatment' in `last_obs'
    replace Pair_ID = -1 in `last_obs'
}


// --- Validate matching quality -----------------------------------------------
// Calculate within-pair differences in g_hat
preserve
keep if Pair_ID >= 0

// Keep only necessary variables for reshaping
keep Pair_ID g_hat

// Create pair-level dataset
bysort Pair_ID: gen pair_size = _N
keep if pair_size == 2

bysort Pair_ID: gen unit_in_pair = _n
reshape wide g_hat, i(Pair_ID) j(unit_in_pair)

gen g_hat_diff = abs(g_hat1 - g_hat2)
gen g_hat_mean = (g_hat1 + g_hat2) / 2

// Calculate summary statistics
quietly summarize g_hat_diff
local mean_diff = r(mean)
local median_diff = r(p50)
local max_diff = r(max)
local min_diff = r(min)

restore

// Calculate what the mean difference would be under random pairing
local random_diff_mean = `sd_g_hat' * sqrt(2)
local reduction = 100 * (1 - `mean_diff' / `random_diff_mean')


// --- Save results ------------------------------------------------------------
// Rename Treatment_Final to Treatment
rename Treatment_Final Treatment

// TODO: Specify output file name
// This file will contain the main sample with Treatment and Pair_ID assigned
save "`output_dir'/optimal_matched_main_sample.dta", replace

// Count treated and control
quietly count if Treatment == 1
local n_treated = r(N)
quietly count if Treatment == 0
local n_control = r(N)


// --- Print results -----------------------------------------------------------
display _newline
display "{hline 80}"
display "OPTIMAL MATCHED-PAIRS RANDOMIZATION FROM PILOT STUDY"
display "{hline 80}"

display _newline "PILOT REGRESSION RESULTS"
display "{hline 80}"
display "  R-squared:            " %7.4f `r2_pilot'
display "  Adj. R-squared:       " %7.4f `r2_adj_pilot'
display "  Treatment coef:       " %7.4f `coef_treatment'
display "  Treatment p-value:    " %7.4f `pval_treatment'

display _newline "ESTIMATED g_hat STATISTICS"
display "{hline 80}"
display "  Sample size:          " `n_complete'
display "  Mean:                 " %7.4f `mean_g_hat'
display "  Std:                  " %7.4f `sd_g_hat'
display "  Min:                  " %7.4f `min_g_hat'
display "  Max:                  " %7.4f `max_g_hat'

display _newline "MATCHED PAIRS STATISTICS"
display "{hline 80}"
display "  Total units:          " `n_units'
display "  Matched pairs:        " `n_pairs'
display "  Unpaired units:       " `n_unpaired'
display "  Pairing rate:         " %4.1f (100 * `n_pairs' * 2 / `n_units') "%"

display _newline "WITHIN-PAIR g_hat DIFFERENCES"
display "{hline 80}"
display "  Mean:                 " %7.6f `mean_diff'
display "  Median:               " %7.6f `median_diff'
display "  Max:                  " %7.6f `max_diff'
display "  Min:                  " %7.6f `min_diff'

display _newline "COMPARISON TO RANDOM PAIRING"
display "{hline 80}"
display "  Expected diff (random):  " %7.6f `random_diff_mean'
display "  Achieved diff (optimal): " %7.6f `mean_diff'
display "  Reduction:               " %7.1f `reduction' "%"

display _newline "TREATMENT ASSIGNMENT"
display "{hline 80}"
display "  Treated:              " `n_treated' " (" %4.1f (100 * `n_treated' / `n_units') "%)"
display "  Control:              " `n_control' " (" %4.1f (100 * `n_control' / `n_units') "%)"

display _newline
display "{hline 80}"
display "OPTIMAL MATCHING COMPLETE"
display "{hline 80}"
display _newline "Saved to: `output_dir'/optimal_matched_main_sample.dta" _newline


// =============================================================================
// END OF OPTIMAL MATCHING SCRIPT
// =============================================================================
