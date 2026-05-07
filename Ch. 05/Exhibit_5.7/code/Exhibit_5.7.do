// =============================================================================
// Exhibit 5.7: Multiple Hypothesis Testing (MHT) and Statistical Power
// =============================================================================
// Demonstrates how sample size requirements grow with the number of hypothesis
// tests when using Bonferroni corrections to control family-wise error rates.
//
// Three correction strategies are compared:
//   1. No Adjustment: standard alpha and power (no MHT correction)
//   2. FWE Adjustment: Bonferroni-corrected alpha (alpha / k)
//   3. FWE + FWP Adjustment: corrected alpha AND corrected power (power^(1/k))
//
// Shows sample size inflation as the number of hypotheses increases from 1 to 10.
//
// Output: PNG plot showing sample size curves for each correction strategy
//
// Reference: Chapter 5, Power Analysis

clear all
set more off
set seed 52649583


// --- Setup -------------------------------------------------------------------
// Automatically set working directory to the folder containing this .do file.

local dofile_path "`c(filename)'"

if `"`dofile_path'"' != "" {
    local code_dir = subinstr(`"`dofile_path'"', "\", "/", .)
    local code_dir = reverse(substr(reverse("`code_dir'"), ///
                     strpos(reverse("`code_dir'"), "/") + 1, .))
    quietly cd "`code_dir'"
}

// Create the output folder one level up from code/
local output_dir "../output"
capture mkdir "`output_dir'"


// --- Parameters --------------------------------------------------------------
local mde_sds  0.5    // effect size in SD units
local alpha    0.05   // significance level (uncorrected)
local power    0.80   // statistical power (uncorrected)
local max_hypo 10     // maximum number of hypothesis tests


// --- Compute sample sizes ----------------------------------------------------
// For each number of hypotheses k = 1..max_hypo, compute required sample size
// per group under three Bonferroni-based correction strategies:
//
//   No Adjustment:        standard alpha and power
//   FWE Adjustment:       alpha / k
//   FWE + FWP Adjustment: alpha / k  and  power^(1/k)

quietly set obs `max_hypo'
gen int hypotheses = _n

gen double no_adj  = .
gen double fwe     = .
gen double fwe_fwp = .

forvalues k = 1/`max_hypo' {

    // No adjustment
    quietly power twomeans 0 `mde_sds', alpha(`alpha') power(`power')
    quietly replace no_adj = r(N1) in `k'

    // FWE only: Bonferroni-corrected alpha
    local alpha_fwe = `alpha' / `k'
    quietly power twomeans 0 `mde_sds', alpha(`alpha_fwe') power(`power')
    quietly replace fwe = r(N1) in `k'

    // FWE + FWP: corrected alpha AND corrected power
    local power_fwp = `power' ^ (1 / `k')
    quietly power twomeans 0 `mde_sds', alpha(`alpha_fwe') power(`power_fwp')
    quietly replace fwe_fwp = r(N1) in `k'
}


// --- Plot --------------------------------------------------------------------
twoway (line no_adj  hypotheses, lcolor(gs13) lwidth(medthick))              ///
       (line fwe     hypotheses, lcolor(gs10) lwidth(medthick))              ///
       (line fwe_fwp hypotheses, lcolor(gs0)  lwidth(medthick)),             ///
    xtitle("Number of Outcomes / Hypothesis Tests per Experimental Unit")    ///
    ytitle("Total Sample Size Required (Given Inputs)")                      ///
    xlabel(1(1)10)                                                           ///
    ylabel(50(25)200, format(%9.0fc))                                        ///
    legend(order(1 "No Adjustment"                                           ///
                 2 "FWE Adjustment"                                          ///
                 3 "FWE + FWP Adjustment")                                   ///
           ring(0) position(11) cols(1) size(small))                         ///
    graphregion(color(white)) plotregion(color(white))                       ///
    scheme(s2color)


// --- Save output -------------------------------------------------------------
graph export "`output_dir'/exhibit_5.7.png", as(png) width(3000) replace


// --- Console output ----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 5.7: Multiple Hypothesis Testing and Sample Size Inflation"
display "{hline 80}"
display " # Hypotheses    No Adj    FWE Adj    FWE+FWP Adj"
display "{hline 80}"

forvalues k = 1/`max_hypo' {
    local n_no  = string(no_adj[`k'],  "%8.0f")
    local n_fwe = string(fwe[`k'],     "%8.0f")
    local n_fwp = string(fwe_fwp[`k'], "%8.0f")
    display "      `k'          `n_no'      `n_fwe'         `n_fwp'"
}

display "{hline 80}"
display "Note: MDE = 0.5 SD, alpha = 0.05, power = 0.80"
display "      Sample size inflation increases with number of tests"
display "{hline 80}"
display _newline
display "Saved to: `output_dir'/exhibit_5.7.png"


// =============================================================================
// END OF EXHIBIT 5.7
// =============================================================================
