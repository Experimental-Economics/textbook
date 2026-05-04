// =============================================================================
// Exhibit 12.1.2A: ATEs and Horowitz and Manski Bounds
// =============================================================================
// Compares default model with upper and lower bounds from Horowitz & Manski (2000).
// Column 1: Default model (no attrition adjustment)
// Column 2: Upper bound (best-case scenario for treatment effect)
// Column 3: Lower bound (worst-case scenario for treatment effect)
//
// Reference: Horowitz, J. L., & Manski, C. F. (2000). Nonparametric Analysis
// of Randomized Experiments with Missing Covariate and Outcome Data.
// Journal of the American Statistical Association, 95(449), 77-84.

clear all
set more off

// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.1.2A/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"

// --- Parameters --------------------------------------------------------------
// Bounds for outcome variable (standardized cognitive test scores)
local UPPER_BOUND = 3
local LOWER_BOUND = -3


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


// --- Create bounding variables -----------------------------------------------
// Upper bound: Assign best outcome to treatment attritors, worst to control attritors
// This maximizes the treatment effect estimate
gen std_cog_sl_upper = std_cog_sl
replace std_cog_sl_upper = `UPPER_BOUND' if r_i == 0 & d_i == 1
replace std_cog_sl_upper = `LOWER_BOUND' if r_i == 0 & d_i == 0

// Lower bound: Assign worst outcome to treatment attritors, best to control attritors
// This minimizes the treatment effect estimate
gen std_cog_sl_lower = std_cog_sl
replace std_cog_sl_lower = `LOWER_BOUND' if r_i == 0 & d_i == 1
replace std_cog_sl_lower = `UPPER_BOUND' if r_i == 0 & d_i == 0


// --- Estimate models ---------------------------------------------------------
// Column 1: Default model (available cases only, no bounding)
eststo model1: reg std_cog_sl d_i if r_i == 1

// Column 2: Horowitz & Manski upper bound
eststo model2: reg std_cog_sl_upper d_i

// Column 3: Horowitz & Manski lower bound
eststo model3: reg std_cog_sl_lower d_i


// --- Save output -------------------------------------------------------------
// Export LaTeX table
esttab model1 model2 model3 using "`output_dir'/Exhibit_12_1_2A_stata.tex", ///
    replace ///
    b(3) se(3) ///
    booktabs ///
    coeflabels(d_i "Pre-K" _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.1.2A: ATEs and Horowitz and Manski Bounds") ///
    nonumbers ///
    mtitles("Default Model" "H\&M Upper Bound" "H\&M Lower Bound") ///
    addnote("Column 1: Default model (no attrition adjustment)" ///
            "Column 2: Upper bound (best-case scenario for treatment effect)" ///
            "Column 3: Lower bound (worst-case scenario for treatment effect)" ///
            "Bounds set at ±3 for standardized cognitive test scores" ///
            "Standard errors in parentheses")

// Display results to console
esttab model1 model2 model3, ///
    b(3) se(3) ///
    coeflabels(d_i "Pre-K" _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.1.2A: ATEs and Horowitz and Manski Bounds") ///
    nonumbers ///
    mtitles("Default" "Upper" "Lower")

display "Saved to: `output_dir'/Exhibit_12_1_2A_stata.tex"


// =============================================================================
// END OF EXHIBIT 12.1.2A
// =============================================================================
