// =============================================================================
// Exhibit C&C 1: Multiple Hypothesis Testing using mhtexp2
// =============================================================================
// Implements the multiple hypothesis testing procedure of List, Shaikh, and
// Vayalinkal (2023) for the Karlan and List (2007) charitable giving experiment.
//
// This script demonstrates various multiple testing scenarios using the mhtexp2
// package, which implements Studentized bootstrap inference with family-wise
// error rate (FWER) control:
//
//   - Multiple outcomes (4 different donation measures)
//   - Multiple subgroups (4 political affinity groups)
//   - Multiple treatments (4 matching ratios)
//   - Pairwise treatment comparisons (with transitivity improvements)
//   - Full factorial combinations
//
// The mhtexp2 procedure implements:
//   - Bootstrap inference with studentized test statistics (re-centered)
//   - Single hypothesis correction (Remark 3.2)
//   - Multiple hypothesis corrections (Theorem 3.1):
//       * Bonferroni correction
//       * Holm's stepdown procedure
//   - Pairwise comparison transitivity improvements (Remark 3.8)
//
// Prerequisites:
//   1. Install the mhtexp2 package from https://github.com/vayalinkal/mhtexp2
//      Download mhtexp2.ado and mhtexp2.sthlp and place them in your personal
//      ado directory (type "sysdir" in Stata to find it, typically:
//        - Windows: C:\Users\<username>\ado\personal\
//        - Mac/Linux: ~/ado/personal/
//   2. Set your working directory to this script's folder before running
//
// Reference: Chapter 4, Multiple Hypothesis Testing
// Output: LaTeX and HTML tables for each testing scenario

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 4/Exhibit C&C 1/code"

// Define paths relative to the script location
local data_dir "../data"
local output_dir "../output"

// Create the output folder
capture mkdir "`output_dir'"


// --- Parameters --------------------------------------------------------------
// Bootstrap parameters
local B 3000          // Number of bootstrap samples
local stu 1           // Studentization (1 = yes, 0 = no)

// Control variables for regression adjustment
local controls female pwhite pblack page18_39 ave_hh_sz years couple dormant nonlit cases


// --- Package Verification ----------------------------------------------------
// Verify that mhtexp2 is installed
capture which mhtexp2
if _rc {
    display as error "ERROR: mhtexp2 not found."
    display as error "Download from https://github.com/vayalinkal/mhtexp2"
    display as error "and place mhtexp2.ado in your personal ado directory (type: sysdir)"
    error 111
}

// Verify that esttab is installed (for LaTeX export)
capture which esttab
if _rc {
    display "Installing esttab from SSC..."
    ssc install estout
}


// --- Data Loading and Preparation --------------------------------------------
use "`data_dir'/karlan_list_2007.dta", clear

// Sort variables and generate observation ID
// NOTE: This specific sort order ensures reproducibility with previous analyses
sort amount ask1 control ratio sizeno female askd1 cases ratio3 size100 ///
     ltmedmra close25 freq ask2 treatment size years redcty askd2 nonlit ///
     size25 mrm2 red0 amountchange hpa ask3 ask gave couple bluecty askd3 ///
     ratio2 size50 dormant blue0

gen newid = _n


// --- Generate Subgroup Variable ----------------------------------------------
// Create political affinity groups based on county and state colors
// (red = Republican-leaning, blue = Democratic-leaning)
// Using boolean arithmetic formula from replication package

gen groupid = (redcty==1 & red0==1) + (redcty==0 & red0==1)*2 + ///
              (redcty==0 & red0==0)*3 + (redcty==1 & red0==0)*4
replace groupid = . if groupid == 0

label define groupid_lbl ///
    1 "Red county in red state" ///
    2 "Blue county in red state" ///
    3 "Blue county in blue state" ///
    4 "Red county in blue state"

label values groupid groupid_lbl


// --- Generate Matched Amount Variable ----------------------------------------
// Convert amount to matched amount based on the ratio treatment
// ratio is coded as: 0 = control (1:1, no matching)
//                    1 = 2:1 matching (amount × 2)
//                    2 = 3:1 matching (amount × 3)
//                    3 = 4:1 matching (amount × 4)
// Using formula: amountmat = amount × (1 + ratio)

gen amountmat = amount * (1 + ratio)


// --- Clean Missing Data ------------------------------------------------------
// Drop observations missing any control variables or subgroup variable
local allvars `controls' groupid

foreach v in `allvars' {
    drop if `v' == .
}

local sN = _N
display "Sample size after removing missing data: " `sN'


// --- Pregenerate Bootstrap Matrix --------------------------------------------
// Pre-generate the bootstrap index matrix to save computation time
// This uses the same seed and procedure as the default mhtexp2 options
mata: mata mlib index
mata: rseed(0)
mata: idbootmat = runiformint(`sN', `B', 1, `sN')


// =============================================================================
// HELPER PROGRAM: Export Results Matrix to HTML
// =============================================================================
capture program drop results_to_html
program define results_to_html
    syntax , filepath(string) caption(string)

    // Get matrix dimensions and names
    local nrows = rowsof(results)
    local ncols = colsof(results)
    local colnames : colfullnames results
    local rownames : rowfullnames results

    // Write HTML file
    tempname fh
    file open `fh' using "`filepath'", write replace
    file write `fh' `"<!DOCTYPE html>"' _n
    file write `fh' `"<html>"' _n
    file write `fh' `"<head>"' _n
    file write `fh' `"<meta charset="utf-8">"' _n
    file write `fh' `"<title>`caption'</title>"' _n
    file write `fh' `"<style>"' _n
    file write `fh' `"  body { font-family: Arial, sans-serif; margin: 40px; }"' _n
    file write `fh' `"  h2 { font-size: 1.2em; }"' _n
    file write `fh' `"  .results-table { border-collapse: collapse; font-size: 0.9em; }"' _n
    file write `fh' `"  .results-table th, .results-table td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }"' _n
    file write `fh' `"  .results-table th { background-color: #f2f2f2; }"' _n
    file write `fh' `"</style>"' _n
    file write `fh' `"</head>"' _n
    file write `fh' `"<body>"' _n
    file write `fh' `"<h2>`caption'</h2>"' _n
    file write `fh' `"<table class="results-table">"' _n

    // Header row
    file write `fh' `"  <thead><tr><th></th>"' _n
    foreach c of local colnames {
        file write `fh' `"<th>`c'</th>"' _n
    }
    file write `fh' `"</tr></thead>"' _n

    // Data rows
    file write `fh' `"  <tbody>"' _n
    forvalues i = 1/`nrows' {
        local rname : word `i' of `rownames'
        file write `fh' `"    <tr><td>`rname'</td>"' _n
        forvalues j = 1/`ncols' {
            local val = results[`i', `j']
            local val : display %9.4f `val'
            local val = strtrim("`val'")
            file write `fh' `"<td>`val'</td>"' _n
        }
        file write `fh' `"</tr>"' _n
    }
    file write `fh' `"  </tbody>"' _n
    file write `fh' `"</table>"' _n
    file write `fh' `"</body>"' _n
    file write `fh' `"</html>"' _n
    file close `fh'
    display `"  -> Saved: `filepath'"'
end


// =============================================================================
// PART 1: MULTIPLE OUTCOMES
// =============================================================================
// Test for treatment effects across 4 different donation outcome measures:
//   - gave:         binary indicator (donated or not)
//   - amount:       donation amount
//   - amountmat:    matched donation amount
//   - amountchange: change in donation amount from previous year

display _newline
display "{hline 80}"
display "ANALYSIS 1: Multiple Outcomes"
display "{hline 80}"
display "Testing treatment effects across 4 donation outcome measures..."
display "{hline 80}"

// Without controls
mhtexp2 gave amount amountmat amountchange, ///
    treatment(treatment) ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_outcomes.tex", replace ///
    title("Multiple Outcomes") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_outcomes.html") ///
    caption("Multiple Outcomes")

// With controls
mhtexp2 gave amount amountmat amountchange, ///
    treatment(treatment) ///
    controls(`controls') ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_outcomes_ctrl.tex", replace ///
    title("Multiple Outcomes (with Controls)") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_outcomes_ctrl.html") ///
    caption("Multiple Outcomes (with Controls)")


// =============================================================================
// PART 2: MULTIPLE SUBGROUPS
// =============================================================================
// Test for treatment effects across 4 political affinity subgroups

display _newline
display "{hline 80}"
display "ANALYSIS 2: Multiple Subgroups"
display "{hline 80}"
display "Testing treatment effects across 4 political affinity groups..."
display "{hline 80}"

// Without controls
mhtexp2 gave, ///
    treatment(treatment) ///
    subgroup(groupid) ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_subgroups.tex", replace ///
    title("Multiple Subgroups") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_subgroups.html") ///
    caption("Multiple Subgroups")

// With controls
mhtexp2 gave, ///
    treatment(treatment) ///
    subgroup(groupid) ///
    controls(`controls') ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_subgroups_ctrl.tex", replace ///
    title("Multiple Subgroups (with Controls)") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_subgroups_ctrl.html") ///
    caption("Multiple Subgroups (with Controls)")


// =============================================================================
// PART 3: MULTIPLE TREATMENTS
// =============================================================================
// Test for effects of 4 different matching ratios on donation amount

display _newline
display "{hline 80}"
display "ANALYSIS 3: Multiple Treatments"
display "{hline 80}"
display "Testing effects of 4 matching ratios on donation amount..."
display "{hline 80}"

// Without controls
mhtexp2 amount, ///
    treatment(ratio) ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_treatments.tex", replace ///
    title("Multiple Treatments") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_treatments.html") ///
    caption("Multiple Treatments")

// With controls
mhtexp2 amount, ///
    treatment(ratio) ///
    controls(`controls') ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_treatments_ctrl.tex", replace ///
    title("Multiple Treatments (with Controls)") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_treatments_ctrl.html") ///
    caption("Multiple Treatments (with Controls)")


// =============================================================================
// PART 4: PAIRWISE TREATMENT COMPARISONS
// =============================================================================
// Test all pairwise differences between matching ratios
// Uses transitivity improvements from Remark 3.8

display _newline
display "{hline 80}"
display "ANALYSIS 4: Pairwise Treatment Comparisons"
display "{hline 80}"
display "Testing all pairwise differences between matching ratios..."
display "Using transitivity improvements (Remark 3.8)"
display "{hline 80}"

// Without controls
mhtexp2 amount, ///
    treatment(ratio) ///
    combo("pairwise") ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_pairwise.tex", replace ///
    title("Multiple Treatments -- Pairwise") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_pairwise.html") ///
    caption("Multiple Treatments -- Pairwise")

// With controls
mhtexp2 amount, ///
    treatment(ratio) ///
    combo("pairwise") ///
    controls(`controls') ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_pairwise_ctrl.tex", replace ///
    title("Multiple Treatments -- Pairwise (with Controls)") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_pairwise_ctrl.html") ///
    caption("Multiple Treatments -- Pairwise (with Controls)")


// =============================================================================
// PART 5: FULL FACTORIAL ANALYSIS
// =============================================================================
// Test all combinations of outcomes, subgroups, and treatments
// This is the most comprehensive analysis, combining all dimensions

display _newline
display "{hline 80}"
display "ANALYSIS 5: Full Factorial (Outcomes × Subgroups × Treatments)"
display "{hline 80}"
display "Testing all combinations of 4 outcomes, 4 subgroups, and 4 treatments..."
display "{hline 80}"

// Without controls
mhtexp2 gave amount amountmat amountchange, ///
    subgroup(groupid) ///
    treatment(ratio) ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_full.tex", replace ///
    title("Multiple Outcomes, Subgroups, and Treatments") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_full.html") ///
    caption("Multiple Outcomes, Subgroups, and Treatments")

// With controls
mhtexp2 gave amount amountmat amountchange, ///
    subgroup(groupid) ///
    treatment(ratio) ///
    controls(`controls') ///
    studentized(`stu') ///
    bootstrap(`B') ///
    idbootmat(idbootmat)

esttab matrix(results, fmt(4)) using "`output_dir'/tab_full_ctrl.tex", replace ///
    title("Multiple Outcomes, Subgroups, and Treatments (with Controls)") booktabs

results_to_html, ///
    filepath("`output_dir'/tab_full_ctrl.html") ///
    caption("Multiple Outcomes, Subgroups, and Treatments (with Controls)")


// --- Summary Output ----------------------------------------------------------
display _newline
display "{hline 80}"
display "ALL ANALYSES COMPLETE"
display "{hline 80}"
display "Generated 10 sets of results (5 scenarios × 2 specifications):"
display ""
display "  1. Multiple Outcomes (4 donation measures)"
display "  2. Multiple Subgroups (4 political affinity groups)"
display "  3. Multiple Treatments (4 matching ratios)"
display "  4. Pairwise Comparisons (6 pairwise treatment contrasts)"
display "  5. Full Factorial (4 outcomes × 4 subgroups × 4 treatments)"
display ""
display "Each scenario estimated with and without regression adjustment controls."
display ""
display "Output files saved to: `output_dir'/"
display "  - LaTeX tables: tab_*.tex (10 files)"
display "  - HTML tables:  tab_*.html (10 files)"
display "{hline 80}"


// =============================================================================
// END OF EXHIBIT C&C 1
// =============================================================================
