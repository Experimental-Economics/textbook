// =============================================================================
// Exhibit 12.4: Determinants of Attrition Tests
// =============================================================================
// Tests which baseline characteristics predict attrition (non-response).
// This analysis identifies which covariates are associated with the probability
// of having an observed outcome in the second period.
//
// Methodology: Regress response indicator (r_i) on treatment status and baseline
// covariates using robust standard errors (HC2).
//
// Covariates: treatment (d_i), female, race_w, hl_eng_span, birthweight, std_cog_pre

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.4/code"

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


// --- Estimate attrition model ------------------------------------------------
// Regress response indicator on treatment and baseline covariates
eststo model1: reg r_i d_i female race_w hl_eng_span birthweight std_cog_pre, robust


// --- Save output -------------------------------------------------------------
// Export LaTeX table
esttab model1 using "`output_dir'/Exhibit_12_4_stata.tex", ///
    replace ///
    b(3) se(3) ///
    booktabs ///
    nomtitles ///
    coeflabels(d_i "Treatment (Pre-K)" ///
               female "Female" ///
               race_w "White" ///
               hl_eng_span "Home Language English" ///
               birthweight "Birthweight" ///
               std_cog_pre "Baseline Cognitive Score" ///
               _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.4: Determinants of Attrition Tests") ///
    nonumbers ///
    addnote("Dependent variable: Response indicator (r\_i = 1 if outcome observed)" ///
            "Robust standard errors in parentheses" ///
            "Tests which baseline characteristics predict attrition")

// Display results to console
esttab model1, ///
    b(3) se(3) ///
    nomtitles ///
    coeflabels(d_i "Treatment" ///
               female "Female" ///
               race_w "White" ///
               hl_eng_span "Home Language English" ///
               birthweight "Birthweight" ///
               std_cog_pre "Baseline Cog" ///
               _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.4: Determinants of Attrition Tests") ///
    nonumbers

display _newline "Saved to: `output_dir'/Exhibit_12_4_stata.tex"


// =============================================================================
// END OF EXHIBIT 12.4
// =============================================================================
