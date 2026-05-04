// =============================================================================
// Exhibit 12.2: GHO (2020) Attrition Tests for CHECC Data
// =============================================================================
// Tests whether attrition is related to baseline characteristics.
// Methodology: Regress baseline outcomes on four group indicators:
//   - π11: treatment × respond
//   - π01: control × respond
//   - π10: treatment × attrit
//   - π00: control × attrit
//
// Column 1: Baseline cognitive score (std_cog_pre)
// Column 2: Baseline non-cognitive score (std_ncog_pre)
//
// Hypothesis tests:
//   H0^12.2: π10 = π00 & π11 = π01 (attrition same across treatment/control)
//   H0^12.3: π10 = π00 = π11 = π01 (all groups have same baseline)
//
// Reference: Ghanem, D., Hirshleifer, S., & Ortiz-Becerra, K. (2020).
// Testing Attrition Bias in Field Experiments. Working Paper.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.2/code"

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


// --- Estimate models ---------------------------------------------------------
// Column 1: Regress baseline cognitive score on group indicators (no intercept)
eststo model1: reg std_cog_pre pi11 pi01 pi10 pi00, noconstant robust

// Store hypothesis test results for cognitive score
// H0^12.2: π10 = π00 & π11 = π01
quietly test (pi10 = pi00) (pi11 = pi01)
local pvalue_cog_12_2 = r(p)
local fstat_cog_12_2 = r(F)

// H0^12.3: π10 = π00 = π11 = π01
quietly test (pi10 = pi00) (pi10 = pi11) (pi10 = pi01)
local pvalue_cog_12_3 = r(p)
local fstat_cog_12_3 = r(F)

// Column 2: Regress baseline non-cognitive score on group indicators (no intercept)
eststo model2: reg std_ncog_pre pi11 pi01 pi10 pi00, noconstant robust

// Store hypothesis test results for non-cognitive score
// H0^12.2: π10 = π00 & π11 = π01
quietly test (pi10 = pi00) (pi11 = pi01)
local pvalue_ncog_12_2 = r(p)
local fstat_ncog_12_2 = r(F)

// H0^12.3: π10 = π00 = π11 = π01
quietly test (pi10 = pi00) (pi10 = pi11) (pi10 = pi01)
local pvalue_ncog_12_3 = r(p)
local fstat_ncog_12_3 = r(F)


// --- Save output -------------------------------------------------------------
// Export LaTeX table
esttab model1 model2 using "`output_dir'/Exhibit_12_2_stata.tex", ///
    replace ///
    b(3) se(3) ///
    booktabs ///
    coeflabels(pi11 "$\pi_{11}$ (Treatment $\times$ Respond)" ///
               pi01 "$\pi_{01}$ (Control $\times$ Respond)" ///
               pi10 "$\pi_{10}$ (Treatment $\times$ Attrit)" ///
               pi00 "$\pi_{00}$ (Control $\times$ Attrit)") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.2: GHO (2020) Attrition Tests for CHECC Data") ///
    nonumbers ///
    mtitles("Cognitive Score" "Non-Cognitive Score") ///
    addnote("Robust standard errors in parentheses" ///
            "Regressions include no intercept (noconstant)" ///
            "Tests whether baseline characteristics differ across attrition groups")

// Display results to console
esttab model1 model2, ///
    b(3) se(3) ///
    coeflabels(pi11 "π11 (Treat×Respond)" ///
               pi01 "π01 (Control×Respond)" ///
               pi10 "π10 (Treat×Attrit)" ///
               pi00 "π00 (Control×Attrit)") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 12.2: GHO (2020) Attrition Tests") ///
    nonumbers ///
    mtitles("Cognitive" "Non-Cog")


// --- Print hypothesis test results -------------------------------------------
display _newline
display "{hline 80}"
display "HYPOTHESIS TEST RESULTS"
display "{hline 80}"
display _newline "Cognitive Score:"
display "  H0^12.2: π10 = π00 & π11 = π01"
display "    F-statistic: " %8.3f `fstat_cog_12_2'
display "    p-value:     " %8.3f `pvalue_cog_12_2'
display _newline "  H0^12.3: π10 = π00 = π11 = π01"
display "    F-statistic: " %8.3f `fstat_cog_12_3'
display "    p-value:     " %8.3f `pvalue_cog_12_3'

display _newline "Non-Cognitive Score:"
display "  H0^12.2: π10 = π00 & π11 = π01"
display "    F-statistic: " %8.3f `fstat_ncog_12_2'
display "    p-value:     " %8.3f `pvalue_ncog_12_2'
display _newline "  H0^12.3: π10 = π00 = π11 = π01"
display "    F-statistic: " %8.3f `fstat_ncog_12_3'
display "    p-value:     " %8.3f `pvalue_ncog_12_3'

display _newline "Saved to: `output_dir'/Exhibit_12_2_stata.tex"


// =============================================================================
// END OF EXHIBIT 12.2
// =============================================================================
