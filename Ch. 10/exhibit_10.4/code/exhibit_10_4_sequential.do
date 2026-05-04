// =============================================================================
// Exhibit 10.4: Power Analysis - Within vs. Between Subjects Designs
// =============================================================================
// Conducts Monte Carlo simulation to compare statistical power between
// within-subjects and between-subjects experimental designs.
//
// Data generating process (Equation 10.4):
// Y_it = π₀ + τ*D_it + μ_i + ε_it
//
// Where:
// - Y_it: Outcome for individual i at time t
// - π₀: Baseline mean
// - τ: Treatment effect (varies: 0.05, 0.10, 0.15)
// - D_it: Treatment indicator
// - μ_i: Individual fixed effect (constant across time)
// - ε_it: Random error
//
// Reference: Chapter 10, Experimental Design

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 10/exhibit_10.4/code"

// Define paths relative to the script location
local output_dir "../output"

// Create the output folder
capture mkdir "`output_dir'"

// Set random seed for replication
// set seed 123


// --- Parameters --------------------------------------------------------------
local treatment_effects "0.05 0.10 0.15"
local baseline_mean = 0.37
local individual_sd = sqrt(0.09)
local error_sd = sqrt(0.02)
local time_periods = 2
local sample_size_min = 10
local sample_size_max = 400
local n_iterations = 1000
local alpha_level = 0.05


// --- Initialize results storage ----------------------------------------------
// Create empty dataset to store power analysis results
clear
set obs 0
gen treatment_effect = .
gen sample_size = .
gen design = ""
gen power = .
tempfile results_file
save `results_file', replace


// --- Run simulation ----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 10.4: Power Analysis - Within vs. Between Subjects Designs"
display "{hline 80}"
display _newline

// Loop over treatment effects
foreach tau of local treatment_effects {
    display _newline
    display "Treatment Effect τ = `tau'"
    display "{hline 80}"

    // Loop over sample sizes
    forvalues n_subjects = `sample_size_min'/`sample_size_max' {

        // Loop over designs
        foreach design in "WS" "BS" {
            display "  Design: `design' | N = `n_subjects'"

            // Run iterations to calculate power
            local significant_count = 0

            forvalues iteration = 1/`n_iterations' {

                // --- Generate data -------------------------------------------
                quietly {
                    // Clear and create panel structure
                    clear
                    set obs `=`n_subjects' * `time_periods''
                    gen i = ceil(_n / `time_periods')
                    gen t = mod(_n - 1, `time_periods')

                    // Shuffle data for complete randomization
                    gen random_order = runiform()
                    sort random_order

                    // Get unique subjects after shuffling
                    egen tag = tag(i)
                    gen subject_order = sum(tag)
                    bysort i: gen subject_id = subject_order[1]
                    drop tag subject_order random_order

                    // Determine first half
                    summarize subject_id, meanonly
                    local n_half = floor(r(max) / 2)

                    // Assign treatment based on design (vectorized)
                    if "`design'" == "WS" {
                        // First half: treated in period 0
                        // Second half: treated in period 1
                        gen D = ((subject_id <= `n_half' & t == 0) | ///
                                 (subject_id > `n_half' & t == 1))
                    }
                    else {
                        // First half: always treated
                        // Second half: never treated
                        gen D = (subject_id <= `n_half')
                    }

                    // Sort by i and t
                    sort i t

                    // Generate individual fixed effects (VECTORIZED - much faster!)
                    egen subject_tag = tag(i)
                    gen mu_temp = rnormal(0, `individual_sd') if subject_tag
                    bysort i: egen mu = max(mu_temp)
                    drop subject_tag mu_temp

                    // Generate random errors
                    gen epsilon = rnormal(0, `error_sd')

                    // Generate outcome: Y_it = π₀ + τ*D_it + μ_i + ε_it
                    gen Y = `baseline_mean' + `tau' * D + mu + epsilon

                    // --- Test significance -----------------------------------
                    if "`design'" == "WS" {
                        // Within-subjects: demean to remove individual fixed effects
                        bysort i: egen D_mean = mean(D)
                        bysort i: egen Y_mean = mean(Y)
                        gen D_demeaned = D - D_mean
                        gen Y_demeaned = Y - Y_mean

                        // Check for variation in treatment
                        summarize D_demeaned, meanonly

                        if r(sd) > 0 {
                            // Run regression without intercept
                            reg Y_demeaned D_demeaned, nocons

                            // Get p-value
                            local p_value = 2 * ttail(e(df_r), abs(_b[D_demeaned]/_se[D_demeaned]))

                            // Check if significant
                            if `p_value' < `alpha_level' {
                                local significant_count = `significant_count' + 1
                            }
                        }
                    }
                    else {
                        // Between-subjects: standard regression
                        // Check for variation in treatment
                        summarize D, meanonly

                        if r(sd) > 0 {
                            // Run regression
                            reg Y D

                            // Get p-value
                            test D = 0

                            // Check if significant
                            if r(p) < `alpha_level' {
                                local significant_count = `significant_count' + 1
                            }
                        }
                    }
                }
            }

            // Calculate power for this sample size
            local power = `significant_count' / `n_iterations'

            // Store results
            preserve
            use `results_file', clear
            set obs `=_N + 1'
            replace treatment_effect = `tau' in `=_N'
            replace sample_size = `n_subjects' in `=_N'
            replace design = "`design'" in `=_N'
            replace power = `power' in `=_N'
            save `results_file', replace
            restore
        }
    }
}

// Load final results
use `results_file', clear


// --- Save results data -------------------------------------------------------
save "`output_dir'/exhibit_10_4_results.dta", replace


// --- Create plot -------------------------------------------------------------
display _newline
display "{hline 80}"
display "Creating power curves..."
display "{hline 80}"
display _newline

// Get max sample size for x-axis
quietly summarize sample_size
local max_n = r(max)

// Get unique treatment effects from the data
quietly levelsof treatment_effect, local(treatment_effects)
display "Treatment effects found in data: `treatment_effects'"

// Create separate plots for each treatment effect
local plot_names ""

// Loop through each treatment effect
local i = 1
foreach tau of local treatment_effects {
    display "Creating plot for τ = `tau'..."

    // Create graph name
    local tau_clean = subinstr("`tau'", ".", "_", .)
    local plot_name "tau_`tau_clean'"
    local plot_names "`plot_names'`plot_name' "
    display "  Added `plot_name' to list. Current list: `plot_names'"

    // Create plot for this treatment effect using approximate comparison
    twoway ///
        (line power sample_size if design == "WS" & abs(treatment_effect - `tau') < 0.001, ///
            lcolor(blue) lwidth(medthick) lpattern(solid) sort) ///
        (line power sample_size if design == "BS" & abs(treatment_effect - `tau') < 0.001, ///
            lcolor(red) lwidth(medthick) lpattern(solid) sort) ///
        , ///
        yline(0.8, lpattern(dash) lcolor(gray) lwidth(medium)) ///
        xlabel(0(50)`max_n', format(%9.0f)) ///
        ylabel(0(0.2)1, format(%3.1f)) ///
        xtitle("Number of Subjects", size(medium)) ///
        ytitle("Statistical Power", size(medium)) ///
        title("τ = `: display %4.2f `tau''", size(medlarge) color(black)) ///
        legend(order(1 "Within-Subjects (WS)" 2 "Between-Subjects (BS)") ///
            position(4) ring(0) cols(1) region(lcolor(white)) size(small)) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        scheme(s2color) ///
        name(`plot_name', replace)

    local i = `i' + 1
}

display "Plot names: `plot_names'"

// Combine all plots
display "Combining plots..."
graph combine `plot_names', ///
    rows(1) ///
    xsize(14) ysize(4) ///
    title("Exhibit 10.4: Power Analysis - Within vs. Between Subjects Designs", ///
        size(medlarge)) ///
    graphregion(color(white)) ///
    note("Dashed line indicates 80% power threshold", size(vsmall))

// Save combined plot
display "Saving plot..."
graph export "`output_dir'/exhibit_10_4.png", ///
    as(png) width(5600) height(1600) replace

display _newline
display "✓ Saved to: `output_dir'/exhibit_10_4.png"
display "{hline 80}"


// =============================================================================
// END OF EXHIBIT 10.4
// =============================================================================
