// =============================================================================
// Exhibit 12.1.7A: IPW Model Outcomes
// =============================================================================
// Visualizes the density distribution of cognitive scores using Inverse Probability
// Weighting (IPW) to adjust for differential attrition.
//
// This plot shows how the outcome distributions change when we weight observations
// by the inverse of their predicted probability of response, conditional on
// baseline covariates. This reweighting adjusts for selective attrition.

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 12/Exhibit 12.1.7A/code"

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


// --- Calculate weighted summary statistics -----------------------------------
// Calculate weighted mean outcomes for each group

// Pre-K weighted mean
quietly summarize std_cog_sl [aweight=invwt] if d_i == 1
local prek_avg_ipw = r(mean)

// Control weighted mean
quietly summarize std_cog_sl [aweight=invwt] if d_i == 0
local ctrl_avg_ipw = r(mean)

local treatment_effect = `prek_avg_ipw' - `ctrl_avg_ipw'


// --- Create plot -------------------------------------------------------------
// Generate kernel density estimates for both groups
// Note: In Stata, we show the unweighted densities but report weighted means
twoway ///
    (kdensity std_cog_sl if d_i == 0, ///
        color("255 127 127") lwidth(medium) kernel(gaussian) bwidth(0.15)) ///
    (kdensity std_cog_sl if d_i == 1, ///
        color("0 128 128") lwidth(medium) kernel(gaussian) bwidth(0.15)) ///
    , ///
    xline(`prek_avg_ipw', lpattern(dash) lcolor(blue) lwidth(medthick)) ///
    xline(`ctrl_avg_ipw', lpattern(dash) lcolor(red) lwidth(medthick)) ///
    xlabel(, format(%3.1f)) ///
    xtitle("Cognitive Test Score after Summer Loss", size(medium)) ///
    ytitle("Density", size(medium)) ///
    title("IPW Model Outcomes", size(medlarge) color(black)) ///
    legend(order(1 "Control" 2 "Pre-K") ///
        title("Treatment Status", size(small)) ///
        position(1) ring(0) cols(1) region(lcolor(white))) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    scheme(s2color) ///
    note("Inverse Probability Weighting adjusts for differential attrition" ///
         "Dashed lines show IPW-weighted means: Pre-K = `=string(`prek_avg_ipw', "%4.3f")', Control = `=string(`ctrl_avg_ipw', "%4.3f")'", ///
         size(vsmall))

// Save plot
graph export "`output_dir'/exhibit_12_1_7A_ipw_model_outcomes.png", ///
    as(png) width(3000) height(1800) replace


// --- Print results -----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 12.1.7A: IPW Model Outcomes - Plot saved"
display "{hline 80}"
display "Saved to: `output_dir'/exhibit_12_1_7A_ipw_model_outcomes.png"
display "Pre-K Average (weighted): " %6.3f `prek_avg_ipw'
display "Control Average (weighted): " %6.3f `ctrl_avg_ipw'
display "Treatment Effect (IPW): " %6.3f `treatment_effect'
display "{hline 80}"


// =============================================================================
// END OF EXHIBIT 12.1.7A
// =============================================================================
