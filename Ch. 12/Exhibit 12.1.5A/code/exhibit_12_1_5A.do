// =============================================================================
// Exhibit 12.1.5A: ATEs: Default and IPW
// =============================================================================
// Compares treatment effects between default model and Inverse Probability
// Weighting (IPW) approach.
// Column 1: Default model (available cases only)
// Column 2: Inverse Probability Weighting (IPW) model
//
// IPW adjusts for differential attrition by weighting observations by the inverse
// of their predicted probability of response, conditional on baseline covariates.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.1.5A/code"

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


// --- Estimate propensity scores ----------------------------------------------
// Fit logistic regression models to predict response probability by treatment group

// Propensity score for treatment group (d_i == 1)
quietly logit r_i female race_w hl_eng_span birthweight if d_i == 1
predict prob_d1 if d_i == 1, pr

// Propensity score for control group (d_i == 0)
quietly logit r_i female race_w hl_eng_span birthweight if d_i == 0
predict prob_d0 if d_i == 0, pr


// --- Create IPW dataset ------------------------------------------------------
// Combine predicted probabilities into single variable
gen prob = prob_d1 if d_i == 1
replace prob = prob_d0 if d_i == 0

// Calculate inverse probability weights
gen invwt = 1 / prob


// --- Estimate models ---------------------------------------------------------
// Column 1: Default model (available cases only, no weighting)
eststo model1: reg std_cog_sl d_i if r_i == 1

// Column 2: Inverse Probability Weighted model
eststo model2: reg std_cog_sl d_i [aweight=invwt]


// --- Save output -------------------------------------------------------------
// Export LaTeX table
esttab model1 model2 using "`output_dir'/Exhibit_12_1_5A_stata.tex", ///
    replace ///
    b(3) se(3) ///
    booktabs ///
    coeflabels(d_i "Pre-K" _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.1.5A: ATEs: Default and IPW") ///
    nonumbers ///
    mtitles("Default Model" "IPW") ///
    addnote("Column 1: Default model (available cases only)" ///
            "Column 2: Inverse Probability Weighting (IPW) model" ///
            "IPW weights based on predicted response probability from logistic regression" ///
            "Covariates: female, race\_w, hl\_eng\_span, birthweight" ///
            "Standard errors in parentheses")

// Display results to console
esttab model1 model2, ///
    b(3) se(3) ///
    coeflabels(d_i "Pre-K" _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.1.5A: ATEs: Default and IPW") ///
    nonumbers ///
    mtitles("Default" "IPW")

display "Saved to: `output_dir'/Exhibit_12_1_5A_stata.tex"


// =============================================================================
// END OF EXHIBIT 12.1.5A
// =============================================================================
