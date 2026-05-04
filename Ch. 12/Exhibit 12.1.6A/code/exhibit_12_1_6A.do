// =============================================================================
// Exhibit 12.1.6A: Default Model Outcomes
// =============================================================================
// Visualizes the density distribution of cognitive scores for the default model
// using kernel density plots. Shows available cases only (those who did not attrit).
//
// This plot provides a baseline view of the observed outcome distributions
// without any attrition adjustment. It includes only participants for whom
// we have observed post-treatment outcomes.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.1.6A/code"

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


// --- Filter for available cases ---------------------------------------------
// Default model uses only observed cases (no imputation or weighting)
keep if r_i == 1


// --- Calculate summary statistics --------------------------------------------
// Calculate mean outcomes for each group (available cases only)
quietly summarize std_cog_sl if d_i == 1
local prek_avg_default = r(mean)
local prek_n = r(N)

quietly summarize std_cog_sl if d_i == 0
local ctrl_avg_default = r(mean)
local ctrl_n = r(N)

local treatment_effect = `prek_avg_default' - `ctrl_avg_default'


// --- Create plot -------------------------------------------------------------
// Generate kernel density estimates for both groups
twoway ///
    (kdensity std_cog_sl if d_i == 0, ///
        color("255 127 127") lwidth(medium) kernel(gaussian) bwidth(0.15)) ///
    (kdensity std_cog_sl if d_i == 1, ///
        color("0 128 128") lwidth(medium) kernel(gaussian) bwidth(0.15)) ///
    , ///
    xline(`prek_avg_default', lpattern(dash) lcolor(blue) lwidth(medthick)) ///
    xline(`ctrl_avg_default', lpattern(dash) lcolor(red) lwidth(medthick)) ///
    xlabel(, format(%3.1f)) ///
    xtitle("Cognitive Test Score after Summer Loss", size(medium)) ///
    ytitle("Density", size(medium)) ///
    title("Default Model Outcomes", size(medlarge) color(black)) ///
    legend(order(1 "Control" 2 "Pre-K") ///
        title("Treatment Status", size(small)) ///
        position(1) ring(0) cols(1) region(lcolor(white))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2color) ///
    note("Available cases only (no attrition adjustment)" ///
         "Dashed lines show group means: Pre-K = `=string(`prek_avg_default', "%4.3f")' (n=`prek_n'), Control = `=string(`ctrl_avg_default', "%4.3f")' (n=`ctrl_n')", ///
         size(vsmall))

// Save plot
graph export "`output_dir'/exhibit_12_1_6A_default_model_outcomes.png", ///
    as(png) width(3000) height(1800) replace


// --- Print results -----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 12.1.6A: Default Model Outcomes - Plot saved"
display "{hline 80}"
display "Saved to: `output_dir'/exhibit_12_1_6A_default_model_outcomes.png"
display "Pre-K Average: " %6.3f `prek_avg_default'
display "Control Average: " %6.3f `ctrl_avg_default'
display "Treatment Effect: " %6.3f `treatment_effect'
display "Sample Size (Pre-K): " %6.0f `prek_n'
display "Sample Size (Control): " %6.0f `ctrl_n'
display "{hline 80}"


// =============================================================================
// END OF EXHIBIT 12.1.6A
// =============================================================================
