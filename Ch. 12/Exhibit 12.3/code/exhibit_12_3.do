// =============================================================================
// Exhibit 12.3: Selective Attrition Tests for CHECC Data
// =============================================================================
// Tests whether attrition is selectively related to baseline covariates (demographics).
// Extends Exhibit 12.2 by examining specific demographic variables instead of outcomes.
//
// Methodology: Regress each baseline covariate on four group indicators:
//   - π11: treatment × respond
//   - π01: control × respond
//   - π10: treatment × attrit
//   - π00: control × attrit
//
// Covariates tested: female, race_w (white), hl_eng_span (Spanish), birthweight
//
// Hypothesis tests:
//   H0^12.2: π10 = π00 & π11 = π01 (attrition same across treatment/control)
//   H0^12.3: π10 = π00 = π11 = π01 (all groups have same covariate means)

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.3/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"


// --- Load and filter data ----------------------------------------------------
// Load synthetic data (for testing/demonstration)
use "`data_dir'/unique_data_clean_main_synthetic.dta", clear
// To use actual CHECC data, comment out the line above and uncomment the line below:
// use "`data_dir'/unique_data_clean_main.dta", clear

// Convert year to numeric (may be stored as string)
destring year, replace force

// Apply filters: year >= 2012, treatment in {control, prek}, exclude kinderprep
// and late randomized, require baseline cognitive score
keep if year >= 2012
keep if inlist(treatment, "control", "prek")
keep if kinderprep == 0
keep if late_randomized == 0
keep if has_cog_pre != 0

// Create block variable (prioritize 2012 block, fallback to 2013)
gen block = block_2012
replace block = block_2013 if block_2012 == ""

// Set summer loss cognitive score to missing when not observed
replace std_cog_sl = . if has_cog_sl == 0

// Treatment indicator: 1 if pre-K, 0 if control
gen d_i = (treatment == "prek")

// Response indicator: 1 if outcome observed, 0 if attrited
gen r_i = !missing(std_cog_sl)


// --- Create group indicators -------------------------------------------------
// Four mutually exclusive groups based on treatment and response status
gen pi11 = d_i * r_i
gen pi01 = (1 - d_i) * r_i
gen pi10 = d_i * (1 - r_i)
gen pi00 = (1 - d_i) * (1 - r_i)


// --- Estimate models for each covariate -------------------------------------
// Define list of covariates to test
local covariates female race_w hl_eng_span birthweight
local covariate_labels "Female" "White" "Spanish" "Birthweight"

// Store number of observations
local n_obs = _N

// Initialize storage for results
tempname results
matrix `results' = J(4, 10, .)
matrix colnames `results' = pi11 se_pi11 pi01 se_pi01 pi10 se_pi10 pi00 se_pi00 p_12_2 p_12_3

local row = 1
foreach var of local covariates {
    // Fit robust linear regression
    quietly reg `var' pi11 pi01 pi10 pi00, noconstant robust

    // Store coefficients and standard errors
    matrix `results'[`row', 1] = _b[pi11]
    matrix `results'[`row', 2] = _se[pi11]
    matrix `results'[`row', 3] = _b[pi01]
    matrix `results'[`row', 4] = _se[pi01]
    matrix `results'[`row', 5] = _b[pi10]
    matrix `results'[`row', 6] = _se[pi10]
    matrix `results'[`row', 7] = _b[pi00]
    matrix `results'[`row', 8] = _se[pi00]

    // H0^12.2: π10 = π00 & π11 = π01
    quietly test (pi10 = pi00) (pi11 = pi01)
    matrix `results'[`row', 9] = r(p)

    // H0^12.3: π10 = π00 = π11 = π01
    quietly test (pi10 = pi00) (pi10 = pi11) (pi10 = pi01)
    matrix `results'[`row', 10] = r(p)

    local row = `row' + 1
}


// --- Print results -----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 12.3: Selective Attrition Tests for CHECC Data"
display "{hline 80}"
display "Variable" _col(16) "π11" _col(28) "π01" _col(40) "π10" _col(52) "π00" _col(64) "H0^12.2" _col(74) "H0^12.3"
display "{hline 80}"

// Display results for each covariate
local row = 1
local label_num = 1
foreach var of local covariates {
    local label : word `label_num' of `covariate_labels'

    // Coefficients
    display "`label'" ///
        _col(16) %11.3f `results'[`row', 1] ///
        _col(28) %11.3f `results'[`row', 3] ///
        _col(40) %11.3f `results'[`row', 5] ///
        _col(52) %11.3f `results'[`row', 7] ///
        _col(64) %9.3f `results'[`row', 9] ///
        _col(74) %9.3f `results'[`row', 10]

    // Standard errors
    display "(SE)" ///
        _col(16) "(" %9.3f `results'[`row', 2] ")" ///
        _col(28) "(" %9.3f `results'[`row', 4] ")" ///
        _col(40) "(" %9.3f `results'[`row', 6] ")" ///
        _col(52) "(" %9.3f `results'[`row', 8] ")"

    local row = `row' + 1
    local label_num = `label_num' + 1
}

display "Observations" _col(16) %11.0f `n_obs'
display "{hline 80}"


// --- Save output to LaTeX ----------------------------------------------------
// Store models for esttab
local row = 1
foreach var of local covariates {
    quietly reg `var' pi11 pi01 pi10 pi00, noconstant robust
    eststo model`row'
    local row = `row' + 1
}

// Export LaTeX table
esttab model1 model2 model3 model4 using "`output_dir'/Exhibit_12_3_stata.tex", ///
    replace ///
    b(3) se(3) ///
    booktabs ///
    coeflabels(pi11 "$\pi_{11}$" pi01 "$\pi_{01}$" pi10 "$\pi_{10}$" pi00 "$\pi_{00}$") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.3: Selective Attrition Tests for CHECC Data") ///
    nonumbers ///
    mtitles("Female" "White" "Spanish" "Birthweight") ///
    addnote("Robust standard errors in parentheses" ///
            "Regressions include no intercept (noconstant)" ///
            "Tests whether demographic characteristics differ across attrition groups")

display _newline "Saved to: `output_dir'/Exhibit_12_3_stata.tex"


// =============================================================================
// END OF EXHIBIT 12.3
// =============================================================================
