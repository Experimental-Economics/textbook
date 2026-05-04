// =============================================================================
// Exhibit 12.1.4A: Horowitz and Manski Bounds (Upper)
// =============================================================================
// Visualizes the upper bound scenario for treatment effects using kernel density plots.
// Upper bound: best case for treatment (assign +3), worst case for control (assign -3)
//
// This plot shows the distribution of outcomes under the optimistic bounding
// assumption where all treatment attritors had the best possible outcome and
// all control attritors had the worst possible outcome. This provides an upper
// bound on the treatment effect.
//
// Reference: Horowitz, J. L., & Manski, C. F. (2000). Nonparametric Analysis
// of Randomized Experiments with Missing Covariate and Outcome Data.
// Journal of the American Statistical Association, 95(449), 77-84.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.1.4A/code"

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


// --- Create upper bound variable ---------------------------------------------
// Upper bound: Assign best outcome to treatment attritors, worst to control attritors
// This maximizes the treatment effect estimate
gen std_cog_sl_upper = std_cog_sl
replace std_cog_sl_upper = `UPPER_BOUND' if r_i == 0 & d_i == 1
replace std_cog_sl_upper = `LOWER_BOUND' if r_i == 0 & d_i == 0


// --- Calculate summary statistics --------------------------------------------
// Calculate mean outcomes for each group under upper bound scenario
quietly summarize std_cog_sl_upper if d_i == 1
local prek_avg_upper = r(mean)

quietly summarize std_cog_sl_upper if d_i == 0
local ctrl_avg_upper = r(mean)

local treatment_effect = `prek_avg_upper' - `ctrl_avg_upper'


// --- Create plot -------------------------------------------------------------
// Generate kernel density estimates for both groups
twoway ///
    (kdensity std_cog_sl_upper if d_i == 0, ///
        color("255 127 127") lwidth(medium) kernel(gaussian) bwidth(0.3)) ///
    (kdensity std_cog_sl_upper if d_i == 1, ///
        color("0 128 128") lwidth(medium) kernel(gaussian) bwidth(0.3)) ///
    , ///
    xline(`prek_avg_upper', lpattern(dash) lcolor(blue) lwidth(medthick)) ///
    xline(`ctrl_avg_upper', lpattern(dash) lcolor(red) lwidth(medthick)) ///
    xlabel(, format(%3.1f)) ///
    xtitle("Cognitive Test Score after Summer Loss", size(medium)) ///
    ytitle("Density", size(medium)) ///
    title("Horowitz and Manski Bounds (Upper)", size(medlarge) color(black)) ///
    legend(order(1 "Control" 2 "Pre-K") ///
        title("Treatment Status", size(small)) ///
        position(1) ring(0) cols(1) region(lcolor(white))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2color) ///
    note("Upper bound: Treatment attritors assigned +3, Control attritors assigned {&minus}3" ///
         "Dashed lines show group means: Pre-K = `=string(`prek_avg_upper', "%4.3f")', Control = `=string(`ctrl_avg_upper', "%4.3f")'", ///
         size(vsmall))

// Save plot
graph export "`output_dir'/exhibit_12_1_4A_hm_bounds_upper.png", ///
    as(png) width(3000) height(1800) replace


// --- Print results -----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 12.1.4A: Horowitz and Manski Bounds (Upper) - Plot saved"
display "{hline 80}"
display "Saved to: `output_dir'/exhibit_12_1_4A_hm_bounds_upper.png"
display "Pre-K Average: " %6.3f `prek_avg_upper'
display "Control Average: " %6.3f `ctrl_avg_upper'
display "Treatment Effect (Upper Bound): " %6.3f `treatment_effect'
display "{hline 80}"


// =============================================================================
// END OF EXHIBIT 12.1.4A
// =============================================================================
