// =============================================================================
// Exhibit 5.1.1A: Power Analysis for Logistic Dose-Response Model
// =============================================================================
// Simulates statistical power for detecting linear and quadratic treatment
// effects in a binary outcome model with discrete dose levels (0-5).
//
// The data-generating process follows a logistic dose-response model:
//   Y_i(d) ~ Bernoulli(p_i(d))
//   p_i(d) = 1 / (1 + exp(-(-1.75 + 0.40*d + 0.05*d^2)))
//
// The simulation estimates power curves for both the linear (β₁) and quadratic
// (β₂) coefficients across sample sizes ranging from 100 to 3,000, with 1,000
// iterations per sample size.
//
// NOTE: This script contains both demonstration code (single instance) and
// the full simulation study. The full simulation may take several minutes.
//
// Reference: Chapter 5, Power Analysis
// Output: PNG plot showing power curves for linear and quadratic coefficients

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 5/Exhibit 5.1.1A/code"

// Define paths relative to the script location
local output_dir "../output"

// Create the output folder
capture mkdir "`output_dir'"

// Set random seed for reproducibility
set seed 52649583


// --- Parameters --------------------------------------------------------------
// Design inputs
local N 10000
// ^ Size of overall population subject to randomization
// ^ We will vary this later as part of the simulation study

// Discrete treatment/dose support
local support_of_treatment "0 1 2 3 4 5"

// Causal/structural model parameters
// Y_i(D)|D = d ~ Bernoulli(p_i(d))
// p_i = 1 / (1 + exp(-(-1.75 + 0.40 * d + 0.05 * d^2)))
local pref_intercept -1.75
local pref_linear_loading 0.40
local pref_quad_loading 0.05

// Calculate potential probabilities for each dose level
forvalues d = 0/5 {
    local potential_probs_`d' = 1 / (1 + exp(-(`pref_intercept' + `pref_linear_loading' * `d' + `pref_quad_loading' * `d'^2)))
}


// =============================================================================
// PART 1: DEMONSTRATION - Single Instance of Size N
// =============================================================================
// This section constructs a single dataset to demonstrate that the model
// recovers the assumed coefficients. This is not part of the power simulation.

// --- Data construction -------------------------------------------------------
set obs `N'
gen unit_id = _n
gen double dose = floor(runiform() * 6)
gen double dose_squared = dose^2

// Generate potential outcomes for each dose level
forvalues i = 0/5 {
    gen Y_`i' = rbinomial(1, `potential_probs_`i'')
}

// Construct observed outcome via observation equation:
// Y_i = Σ_d Y_i(d) * 1[D_i = d]
gen observed_outcome = 0
forvalues i = 0/5 {
    replace observed_outcome = Y_`i' if dose == `i'
}

// NOTE: There appears to be no error component in the observation equation,
// but we are not taking a design-based perspective -- the functional form of
// the structural error (logit) is built in.
// For further discussion, see:
//   Freedman (2008). "Randomization Does Not Justify Logistic Regression."
//   Statistical Science, Vol. 23, No. 2, 237–249.
//   https://doi.org/10.1214/08-STS262


// --- Verify model recovery ---------------------------------------------------
// Checking that we recover our assumed model coefficients (within CI)
display _newline
display "{hline 80}"
display "DEMONSTRATION: Verifying Model Recovery"
display "{hline 80}"
display "Expected coefficients:"
display "  Intercept:  " %6.2f `pref_intercept'
display "  Linear:     " %6.2f `pref_linear_loading'
display "  Quadratic:  " %6.2f `pref_quad_loading'
display "{hline 80}"

glm observed_outcome dose dose_squared, family(binomial) link(logit)


// =============================================================================
// PART 2: POWER SIMULATION
// =============================================================================
// Simulate statistical power: performing the experiment many times to estimate
// the probability of correctly rejecting the null hypothesis.
//
// Thought experiment:
// - We know that the null is false by construction.
// - We ask: with repeated experiments, would we (correctly) reject the null
//   at least 80% (literature standard) of the time by using our 95% CI?
//
// We vary the sample size to understand how statistical power changes with N.

clear all

// --- Simulation parameters ---------------------------------------------------
// Recall design and causal inputs from above
local support_of_treatment "0 1 2 3 4 5"

local pref_intercept -1.75
local pref_linear_loading 0.40
local pref_quad_loading 0.05

forvalues d = 0/5 {
    local potential_probs_`d' = 1 / (1 + exp(-(`pref_intercept' + `pref_linear_loading' * `d' + `pref_quad_loading' * `d'^2)))
}

// Sample sizes to test
local sample_sizes 100 200 300 400 500 600 700 800 900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000 2100 2200 2300 2400 2500 2600 2700 2800 2900 3000

// Iterations per sample size
local iters_per_sample_size 1000


// --- Initialize results matrix -----------------------------------------------
matrix results = J(30, 2, .)
matrix colnames results = "Linear" "Quadratic"
matrix rownames results = `sample_sizes'


// --- Run simulation ----------------------------------------------------------
// NOTE: This may take several minutes to complete
display _newline
display "{hline 80}"
display "SIMULATION: Estimating Power Curves"
display "{hline 80}"
display "Running `iters_per_sample_size' iterations for each of 30 sample sizes..."
display "{hline 80}"

foreach sample_size of local sample_sizes {
    local total_reject_dose = 0
    local total_reject_dose_sqrt = 0

    forvalues iter = 1/`iters_per_sample_size' {
        // Generate data for this iteration
        set obs `sample_size'
        gen unit_id = _n
        gen double dose = floor(runiform() * 6)
        gen double dose_squared = dose^2

        forvalues i = 0/5 {
            gen Y_`i' = rbinomial(1, `potential_probs_`i'')
        }

        gen observed_outcome = 0
        forvalues i = 0/5 {
            replace observed_outcome = Y_`i' if dose == `i'
        }

        // Fit logistic regression
        quietly glm observed_outcome dose dose_squared, family(binomial) link(logit)

        // Compute two-sided p-values
        local p_val_dose = 2 * (normal(-abs(_b[dose] / _se[dose])))
        local p_val_dose_sqrt = 2 * (normal(-abs(_b[dose_squared] / _se[dose_squared])))

        // Check for rejection at alpha = 0.05
        if `p_val_dose' <= 0.05 {
            local total_reject_dose = `total_reject_dose' + 1
        }
        if `p_val_dose_sqrt' <= 0.05 {
            local total_reject_dose_sqrt = `total_reject_dose_sqrt' + 1
        }

        // Progress reporting
        if mod(`iter', 100) == 0 {
            display "  N = " %4.0f `sample_size' ": Completed iteration " %4.0f `iter' " of `iters_per_sample_size'"
        }

        // Clean up for next iteration
        drop unit_id dose dose_squared observed_outcome Y_0 Y_1 Y_2 Y_3 Y_4 Y_5
    }

    // Store results: proportion of iterations that rejected
    local row_count = `sample_size' / 100
    matrix results[`row_count', 1] = `total_reject_dose' / `iters_per_sample_size'
    matrix results[`row_count', 2] = `total_reject_dose_sqrt' / `iters_per_sample_size'
}

display "{hline 80}"
display "Simulation complete."
display "{hline 80}"


// --- Prepare results for plotting --------------------------------------------
// Convert matrix to dataset
svmat results, names(col)

gen sample_size = .
forvalues i = 1/30 {
    replace sample_size = `i' * 100 in `i'
}

// Save results for future reference
save "`output_dir'/simulation_results.dta", replace


// --- Create plot -------------------------------------------------------------
// NOTE: This code does not add the model equation to the plot label
// because Stata has limited support for complex equation rendering in graphs.

twoway ///
    (line Linear sample_size, lcolor(black) lwidth(medium) lpattern(solid)) ///
    (line Quadratic sample_size, lcolor(gs10) lwidth(medium) lpattern(solid)) ///
    (function y = 0.80, range(sample_size) lcolor(red) lwidth(medium) lpattern(dash)), ///
    xlabel(, valuelabel) ///
    ylabel(, grid) ///
    xtitle("Sample Size per Iteration (with 1,000 iterations per sample size)") ///
    ytitle("Fraction of Iterations Correctly Rejecting the Null (H₀)") ///
    legend(order(1 "Linear Coefficient ({&beta}₁ = 0.4)" ///
                 2 "Quadratic Coefficient ({&beta}₂ = 0.05)" ///
                 3 "80% power threshold") ///
           pos(6) ring(0)) ///
    graphregion(color(white))


// --- Save output -------------------------------------------------------------
graph export "`output_dir'/simulation-result-stata.png", width(1020) height(600) replace
display _newline
display "Saved to: `output_dir'/simulation-result-stata.png"
display "Saved to: `output_dir'/simulation_results.dta"


// =============================================================================
// END OF EXHIBIT 5.1.1A
// =============================================================================
