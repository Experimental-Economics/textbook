// =============================================================================
// Exhibit 12.1.9A: Lee Bounds (Lower)
// =============================================================================
// Implements Lee (2009) bounds for treatment effects with differential attrition.
// Lower bound: Trims observations from bottom of control group distribution.
//
// Lee bounds address selective attrition by trimming the distribution with higher
// response rates to match the response rate of the group with lower response.
// The lower bound trims from the bottom of the control distribution, providing a
// pessimistic estimate of the treatment effect.
//
// Reference: Lee, D. S. (2009). Training, Wages, and Sample Selection: Estimating
// Sharp Bounds on Treatment Effects. The Review of Economic Studies, 76(3), 1071-1102.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.1.9A/code"

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


// --- Calculate trimming parameters -------------------------------------------
// Calculate response rates by treatment group
quietly summarize r_i if d_i == 0
local response_rate_control = r(mean)

quietly summarize r_i if d_i == 1
local response_rate_prek = r(mean)

// Calculate fraction to trim from control group (group with lower response rate)
local trimming_fraction = (`response_rate_prek' - `response_rate_control') / `response_rate_prek'


// --- Apply Lee bounds trimming (lower) ---------------------------------------
// Lower bound: Trim from bottom of control distribution
// Find quantile threshold for trimming (trimming_fraction percentile)
_pctile std_cog_sl if d_i == 0, percentiles(`=100*`trimming_fraction'')
local quantile_threshold = r(r1)

// Create indicator for observations to keep after trimming
gen keep_lower = 1

// For control group: Keep observations above threshold (trim bottom)
replace keep_lower = 0 if d_i == 0 & std_cog_sl <= `quantile_threshold' & !missing(std_cog_sl)

// Keep only non-trimmed observations for analysis
preserve
keep if keep_lower == 1


// --- Calculate summary statistics --------------------------------------------
quietly summarize std_cog_sl if d_i == 1
local prek_avg_lower = r(mean)

quietly summarize std_cog_sl if d_i == 0
local ctrl_avg_lower = r(mean)

local treatment_effect = `prek_avg_lower' - `ctrl_avg_lower'


// --- Create plot -------------------------------------------------------------
// Generate kernel density estimates for both groups
twoway ///
    (kdensity std_cog_sl if d_i == 0, ///
        color("255 127 127") lwidth(medium) kernel(gaussian) bwidth(0.15)) ///
    (kdensity std_cog_sl if d_i == 1, ///
        color("0 128 128") lwidth(medium) kernel(gaussian) bwidth(0.15)) ///
    , ///
    xline(`prek_avg_lower', lpattern(dash) lcolor(blue) lwidth(medthick)) ///
    xline(`ctrl_avg_lower', lpattern(dash) lcolor(red) lwidth(medthick)) ///
    xlabel(, format(%3.1f)) ///
    xtitle("Cognitive Test Score after Summer Loss", size(medium)) ///
    ytitle("Density", size(medium)) ///
    title("Lee Bounds (Lower)", size(medlarge) color(black)) ///
    legend(order(1 "Control (trimmed)" 2 "Pre-K") ///
        title("Treatment Status", size(small)) ///
        position(1) ring(0) cols(1) region(lcolor(white))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2color) ///
    note("Lower bound: Trimmed `=string(`trimming_fraction'*100, "%4.1f")'% from bottom of control distribution" ///
         "Response rates: Control = `=string(`response_rate_control', "%4.3f")', Pre-K = `=string(`response_rate_prek', "%4.3f")'" ///
         "Dashed lines: Pre-K = `=string(`prek_avg_lower', "%4.3f")', Control (trimmed) = `=string(`ctrl_avg_lower', "%4.3f")'", ///
         size(vsmall))

// Save plot
graph export "`output_dir'/exhibit_12_1_9A_lee_bounds_lower.png", ///
    as(png) width(3000) height(1800) replace

restore


// --- Print results -----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 12.1.9A: Lee Bounds (Lower) - Plot saved"
display "{hline 80}"
display "Saved to: `output_dir'/exhibit_12_1_9A_lee_bounds_lower.png"
display "Response Rate (Control): " %6.3f `response_rate_control'
display "Response Rate (Pre-K): " %6.3f `response_rate_prek'
display "Trimming Fraction: " %6.3f `trimming_fraction'
display "Pre-K Average: " %6.3f `prek_avg_lower'
display "Control Average (trimmed): " %6.3f `ctrl_avg_lower'
display "Treatment Effect (Lower Bound): " %6.3f `treatment_effect'
display "{hline 80}"


// =============================================================================
// END OF EXHIBIT 12.1.9A
// =============================================================================
