// =============================================================================
// Exhibit 9.4: Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods
// =============================================================================

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 9/Exhibit 9.4/code"

// Define paths relative to the script location
local output_dir "../output"

// Create the output folder
capture mkdir "`output_dir'"


// --- Core program ------------------------------------------------------------
// Calculates optimal sample size using the formula for panel data designs.
//
//   N_pre     : number of pre-treatment periods
//   N_post    : number of post-treatment periods
//   MDE       : minimum detectable effect in standard deviations
//   t_alpha_2 : critical value for two-tailed test at alpha/2
//   t_beta    : critical value for power (1 - beta)
//
// Returns the required n* = 2(t_α/2 + t_β)²σ² / (MDE)² * (N_pre + N_post) / (N_pre * N_post)
//
// Assumes σ² = 1 (standardized).

capture program drop calculate_n_star
program define calculate_n_star, rclass
    args N_pre N_post MDE t_alpha_2 t_beta

    local numerator = 2 * (`t_alpha_2' + `t_beta')^2 * (`N_pre' + `N_post')
    local denominator = (`MDE')^2 * `N_pre' * `N_post'
    local n_star = `numerator' / `denominator'

    return scalar n_star = `n_star'
end


// --- Parameters --------------------------------------------------------------
local MDE = 0.5          // Standard deviations
local t_alpha_2 = 1.96   // For 95% confidence (two-tailed)
local t_beta = 0.84      // For 80% power


// --- Generate table data -----------------------------------------------------
// Create empty dataset
clear
set obs 9

// Generate variables
gen total_periods = .
gen ratio_str = ""
gen n_star = .

// Counter for observations
local row = 1

// Loop through total periods
foreach total_periods in 4 8 16 {

    // Calculate pre and post periods for each ratio
    local pre_1 = floor(`total_periods' / 4)
    local post_1 = floor(3 * `total_periods' / 4)

    local pre_2 = floor(`total_periods' / 2)
    local post_2 = floor(`total_periods' / 2)

    local pre_3 = floor(3 * `total_periods' / 4)
    local post_3 = floor(`total_periods' / 4)

    // Ratio 1: 1/4 : 3/4
    calculate_n_star `pre_1' `post_1' `MDE' `t_alpha_2' `t_beta'
    replace total_periods = `total_periods' in `row'
    replace ratio_str = "1/4 : 3/4" in `row'
    replace n_star = round(r(n_star)) in `row'
    local row = `row' + 1

    // Ratio 2: 1/2 : 1/2
    calculate_n_star `pre_2' `post_2' `MDE' `t_alpha_2' `t_beta'
    replace total_periods = `total_periods' in `row'
    replace ratio_str = "1/2 : 1/2" in `row'
    replace n_star = round(r(n_star)) in `row'
    local row = `row' + 1

    // Ratio 3: 3/4 : 1/4
    calculate_n_star `pre_3' `post_3' `MDE' `t_alpha_2' `t_beta'
    replace total_periods = `total_periods' in `row'
    replace ratio_str = "3/4 : 1/4" in `row'
    replace n_star = round(r(n_star)) in `row'
    local row = `row' + 1
}

// Rename variables for display
rename total_periods Total_Number_of_Periods
rename ratio_str Pre_to_Post_Ratio

// Preview
display _newline "Exhibit 9.4: Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods" _newline
list Total_Number_of_Periods Pre_to_Post_Ratio n_star, noobs separator(0) clean
display _newline "Calculated using formula with MDE = 0.5 SD, 95% confidence, 80% power"


// --- Save output -------------------------------------------------------------
// Check if texsave is installed
capture which texsave

if _rc == 0 {
    // texsave is available, use it
    texsave Total_Number_of_Periods Pre_to_Post_Ratio n_star ///
        using "`output_dir'/Exhibit_9.4_stata.tex", replace ///
        title("Exhibit 9.4: Simple Rules of Thumb for Sample Size") ///
        nonames
    display _newline "Saved to: `output_dir'/Exhibit_9.4_stata.tex"
}
else {
    display as error _newline "texsave command not found. To install, run: ssc install texsave"
    display "Table data is displayed above but not saved to LaTeX."
}
