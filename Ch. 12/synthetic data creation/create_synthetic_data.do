// =============================================================================
// Synthetic Data Creation for Chapter 12
// =============================================================================
// Creates synthetic CHECC data for testing and demonstration purposes.
// This script generates 1000 observations with the same structure as the
// original CHECC dataset but with randomized values.
//
// Output: unique_data_clean_main_synthetic.dta (Stata format)

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/synthetic data creation"

// Set random seed for reproducibility
set seed 42

// Define all exhibit folders (add new exhibits here if needed)
local exhibit_folders "Exhibit 12.1.1A" "Exhibit 12.1.2A" "Exhibit 12.1.3A" ///
                      "Exhibit 12.1.4A" "Exhibit 12.1.5A" "Exhibit 12.1.6A" ///
                      "Exhibit 12.1.7A" "Exhibit 12.1.8A" "Exhibit 12.1.9A" ///
                      "Exhibit 12.2" "Exhibit 12.3" "Exhibit 12.4"


// --- Generate synthetic data -------------------------------------------------
// Sample size
local N = 1000
set obs `N'

// Treatment assignment
gen treatment = "control"
replace treatment = "prek" if runiform() > 0.5

// Exclusion criteria
gen kinderprep = rbinomial(1, 0.2)
gen late_randomized = rbinomial(1, 0.2)

// Block identifiers (stored as strings)
gen block_2012 = ""
gen block_2013 = ""
foreach var of varlist block_2012 block_2013 {
    local rand = runiform()
    replace `var' = "" if `rand' < 0.2
    replace `var' = "A" if `rand' >= 0.2 & `rand' < 0.4
    replace `var' = "B" if `rand' >= 0.4 & `rand' < 0.6
    replace `var' = "C" if `rand' >= 0.6 & `rand' < 0.8
    replace `var' = "D" if `rand' >= 0.8
}

// Outcome availability indicators
gen has_cog_sl = rbinomial(1, 0.7)
gen has_cog_pre = rbinomial(1, 0.7)

// Outcome variables (standardized cognitive and non-cognitive scores)
gen std_cog_sl = rnormal(0, 1)
gen std_ncog_sl = rnormal(0, 1)
gen std_cog_pre = rnormal(0, 1)
gen std_ncog_pre = rnormal(0, 1)

// Set missing values where has_cog_sl = 0
replace std_cog_sl = . if has_cog_sl == 0

// Set missing values where has_cog_pre = 0
replace std_cog_pre = . if has_cog_pre == 0

// Demographic covariates
gen female = rbinomial(1, 0.5)
gen race_w = rbinomial(1, 0.7)
gen hl_eng_span = rbinomial(1, 0.7)

// Birthweight (discrete values)
gen birthweight = .
gen rand_bw = runiform()
replace birthweight = 1.0 if rand_bw < 0.3
replace birthweight = 1.5 if rand_bw >= 0.3 & rand_bw < 0.5
replace birthweight = 2.0 if rand_bw >= 0.5 & rand_bw < 0.8
replace birthweight = 3.0 if rand_bw >= 0.8
drop rand_bw

// Year indicator
gen year = floor(runiform() * 8 + 2011)


// --- Save output -------------------------------------------------------------
// Save as Stata file to all exhibit data folders
display _newline "Saving synthetic data to all exhibit folders..."

foreach exhibit of local exhibit_folders {
    local data_dir "../`exhibit'/data"
    capture mkdir "`data_dir'"
    save "`data_dir'/unique_data_clean_main_synthetic.dta", replace
    display "  ✓ `exhibit'/data/unique_data_clean_main_synthetic.dta"
}

// Print summary statistics
display _newline(2) "{hline 80}"
display "SYNTHETIC DATA SUMMARY"
display "{hline 80}"
display "Total observations: " _N

display _newline "Treatment distribution:"
tabulate treatment

display _newline "Year distribution:"
tabulate year

display "{hline 80}"

// =============================================================================
// END OF SYNTHETIC DATA CREATION
// =============================================================================
