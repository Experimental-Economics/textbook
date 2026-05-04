// =============================================================================
// Exhibit 12.1.1A: ATEs With and Without Available Case Analysis
// =============================================================================
// Compares treatment effects with and without available case analysis.
// Columns 1-2: Without controls
// Columns 3-4: With controls (female, race_w, hl_eng_span, birthweight)
//
// Reference: Chapter 12, Addressing Attrition

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.1.1A/code"

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


// --- Estimate models ---------------------------------------------------------
// Column 1: Default model without controls (full data, includes missing outcomes)
eststo model1: reg std_cog_sl d_i

// Column 2: Available case analysis without controls (only observed outcomes)
eststo model2: reg std_cog_sl d_i if r_i == 1

// Column 3: Default model with controls (full data)
eststo model3: reg std_cog_sl d_i female race_w hl_eng_span birthweight

// Column 4: Available case analysis with controls (only observed outcomes)
eststo model4: reg std_cog_sl d_i female race_w hl_eng_span birthweight if r_i == 1


// --- Save output -------------------------------------------------------------
// Export LaTeX table
esttab model1 model2 model3 model4 using "`output_dir'/Exhibit_12_1_1A_stata.tex", ///
    replace ///
    b(3) se(3) ///
    booktabs ///
    nomtitles ///
    mgroups("Without Controls" "With Controls", ///
        pattern(1 0 1 0) ///
        prefix(\multicolumn{@span}{c}{) suffix(}) ///
        span erepeat(\cmidrule(lr){@span})) ///
    coeflabels(d_i "Pre-K" _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.1.1A: ATEs With and Without Available Case Analysis") ///
    nonumbers ///
    addnote("Columns 1-2: Without controls" ///
            "Columns 3-4: With controls (female, race\_w, hl\_eng\_span, birthweight)" ///
            "Standard errors in parentheses")

// Display results to console
esttab model1 model2 model3 model4, ///
    b(3) se(3) ///
    nomtitles ///
    coeflabels(d_i "Pre-K" _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.1.1A: ATEs With and Without Available Case Analysis") ///
    nonumbers

display "Saved to: `output_dir'/Exhibit_12_1_1A_stata.tex"


// =============================================================================
// END OF EXHIBIT 12.1.1A
// =============================================================================
