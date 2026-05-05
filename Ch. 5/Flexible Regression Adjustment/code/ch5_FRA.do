// =============================================================================
// Flexible Regression Adjustment (FRA): Variance Reduction via ML Cross-Fitting
// =============================================================================
// Demonstrates variance reduction from flexible covariate adjustment using
// machine learning methods with cross-fitting. Replicates Table 7 from Chapter 5.
//
// Compares three estimators on Oregon Health Insurance Experiment (OHIE) data
// (Finkelstein et al., 2016):
//
//   SM  = Subsample Means (simple difference in means, no covariates)
//   LRA = Linear Regression Adjustment (OLS-based cross-fitting)
//   FRA = Flexible Regression Adjustment (Random Forest-based cross-fitting)
//
// For each estimator, three parameters are estimated:
//   1. Reduced Form: Impact of treatment assignment (W) on ER visits (Y)
//   2. First Stage: Impact of treatment assignment (W) on Medicaid take-up (D)
//   3. LATE: Local Average Treatment Effect using Wald estimator (RF / FS)
//
// The cross-fitting approach avoids overfitting by splitting the sample into
// folds, fitting models on other folds, and predicting on held-out data. This
// ensures valid asymptotic inference while allowing flexible functional forms.
//
// NOTE: Random Forest fitting may take several minutes to complete depending
// on sample size and number of covariates.
//
// Self-contained: All FRA logic is embedded below (no external .ado needed).
// The "rforest" package is auto-installed if missing.
//
// Outputs: LaTeX table (.tex) and styled HTML table (.html)
//
// Reference: Chapter 5, Power Analysis
// Data: Oregon Health Insurance Experiment (Finkelstein et al., 2016)
// =============================================================================


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 5/Flexible Regression Adjustment/code"

clear all
set seed 623

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"

// Auto-install rforest if not available
capture which rforest
if _rc != 0 {
    display "Installing rforest package..."
    ssc install rforest, replace
}


// =============================================================================
// PART 1: FRA PROGRAM (EMBEDDED)
// =============================================================================
// Cross-fitted regression adjustment. Performs sample-splitting to estimate
// E[Y | X, W=w] for each outcome Y and treatment level w, then constructs
// influence function columns for regression-adjusted estimators.
//
// Usage:
//   fra_run outcome_vars, treat(treatvar) covariates(covar_list)
//         nfolds(#) seed(#) method(linear|rf)
//
// Creates columns:
//   m_{outcome}_{treat_level} : cross-fitted predictions
//   u_{outcome}_{treat_level} : influence function values

capture program drop fra_run
program define fra_run
    version 16
    syntax varlist, treat(varname) covariates(varlist) nfolds(integer) ///
                    seed(integer) method(string)

    local outcome_cols `varlist'

    // --- Step 1: Create balanced folds ---------------------------------------
    qui set seed `seed'
    qui gen _rand = runiformint(0, _N)
    qui sort `treat' _rand
    qui gen _fold = mod(_n - 1, `nfolds') + 1
    qui drop _rand

    // Get treatment levels
    qui levelsof `treat', local(treat_levels)

    // --- Step 2: Cross-fitting -----------------------------------------------
    foreach y of local outcome_cols {
        foreach w_val of local treat_levels {

            qui gen m_`y'_`w_val' = .

            forvalues f = 1/`nfolds' {

                if "`method'" == "linear" {
                    qui reg `y' `covariates' ///
                        if _fold != `f' & `treat' == `w_val'
                    qui predict _mhat if _fold == `f'
                }
                else if "`method'" == "rf" {
                    qui rforest `y' `covariates' ///
                        if _fold != `f' & `treat' == `w_val', ///
                        type(reg)
                    qui predict _mhat if _fold == `f'
                }
                else {
                    display as error "method must be 'linear' or 'rf'"
                    exit 198
                }

                qui replace m_`y'_`w_val' = _mhat if _fold == `f'
                qui drop _mhat
            }
        }
    }

    // --- Step 3: Construct influence functions -------------------------------
    foreach w_val of local treat_levels {
        qui count if `treat' == `w_val'
        local n_w = r(N)
        qui count
        local n_total = r(N)
        local prop_w = `n_w' / `n_total'

        foreach y of local outcome_cols {
            qui gen u_`y'_`w_val' = ///
                cond(`treat' == `w_val', ///
                     (1/`prop_w') * (`y' - m_`y'_`w_val'), ///
                     0) ///
                + m_`y'_`w_val'
        }
    }

    // Clean up helper columns
    qui drop _fold
end


// =============================================================================
// PART 2: LOAD AND PREPARE DATA
// =============================================================================

// --- Load data ---------------------------------------------------------------
// y = ER visit indicator, d = Medicaid take-up, w = treatment assignment
// Covariates: gender, age, prior health, education, ER visit counts
import delimited "`data_dir'/OHIE_data.csv", clear

// Drop observations with any missing values across all variables.
// Some columns contain "NA" strings, which makes Stata import them
// as string variables. Drop those rows, then destring.
qui ds
foreach v in `r(varlist)' {
    capture confirm numeric variable `v'
    if _rc == 0 {
        qui drop if missing(`v')
    }
    else {
        qui drop if `v' == "NA" | `v' == "" | missing(`v')
    }
}

// Convert y from string "TRUE"/"FALSE" to numeric 0/1
gen y_num = (y == "TRUE")
drop y
rename y_num y

// Destring any remaining string variables that are now purely numeric
qui ds, has(type string)
if "`r(varlist)'" != "" {
    destring `r(varlist)', replace
}

// Reorder so y is first
order y d w

// Display sample size
qui count
local N = r(N)
display "Sample size after dropping NAs: `N'"

// Identify covariates: all variables except y, d, w
unab allvars : _all
local covariates ""
foreach v of local allvars {
    if !inlist("`v'", "y", "d", "w") {
        local covariates "`covariates' `v'"
    }
}
local covariates = strtrim("`covariates'")
display "Covariates: `covariates'"


// =============================================================================
// PART 3: RUN ESTIMATORS
// =============================================================================

// --- SM (Subsample Means) ----------------------------------------------------
// Simple difference in means -- no covariates, no adjustment.

// SM ATE for y (reduced form)
qui sum y if w == 1
local y1_mean = r(mean)
local y1_var  = r(Var)
local y1_n    = r(N)
qui sum y if w == 0
local y0_mean = r(mean)
local y0_var  = r(Var)
local y0_n    = r(N)

local sm_er_pe = `y1_mean' - `y0_mean'
local sm_er_se = sqrt(`y1_var'/`y1_n' + `y0_var'/`y0_n')

// SM ATE for d (first stage)
qui sum d if w == 1
local d1_mean = r(mean)
local d1_var  = r(Var)
local d1_n    = r(N)
qui sum d if w == 0
local d0_mean = r(mean)
local d0_var  = r(Var)
local d0_n    = r(N)

local sm_d_pe = `d1_mean' - `d0_mean'
local sm_d_se = sqrt(`d1_var'/`d1_n' + `d0_var'/`d0_n')

// SM LATE (Wald estimator with delta method SE)
local sm_late_pe = `sm_er_pe' / `sm_d_pe'

// Delta method for SM LATE SE
preserve
    qui keep y d w
    gen u_num   = (y - `y1_mean') if w == 1
    qui replace u_num   = -(y - `y0_mean') if w == 0
    gen u_denom = (d - `d1_mean') if w == 1
    qui replace u_denom = -(d - `d0_mean') if w == 0

    qui correlate u_num u_denom, covariance
    matrix VCV_raw = r(C)
    local var_num   = VCV_raw[1,1]
    local var_denom = VCV_raw[2,2]
    local cov_nd    = VCV_raw[1,2]

    local vcv11 = `var_num'   / `N'
    local vcv12 = `cov_nd'    / `N'
    local vcv22 = `var_denom' / `N'

    local g1 = 1 / `sm_d_pe'
    local g2 = -`sm_er_pe' / (`sm_d_pe'^2)

    local sm_late_se = sqrt(`g1'^2 * `vcv11' + 2*`g1'*`g2'*`vcv12' + `g2'^2 * `vcv22')
restore

display " "
display "SM results:"
display "  ER Visits:        PE = " %9.4f `sm_er_pe'   "  SE = " %9.4f `sm_er_se'
display "  Medicaid Take-Up: PE = " %9.4f `sm_d_pe'    "  SE = " %9.4f `sm_d_se'
display "  LATE:             PE = " %9.4f `sm_late_pe'  "  SE = " %9.4f `sm_late_se'


// --- LRA (Linear Regression Adjustment, 10 folds) ---------------------------
display " "
display "Running LRA (Linear, 10 folds)..."
preserve
    fra_run y d, treat(w) covariates(`covariates') nfolds(10) seed(623) method(linear)

    // ATE for y (reduced form)
    gen u_y = u_y_1 - u_y_0
    qui sum u_y
    local lra_er_pe = r(mean)
    local lra_er_se = r(sd) / sqrt(r(N))

    // ATE for d (first stage)
    gen u_d = u_d_1 - u_d_0
    qui sum u_d
    local lra_d_pe = r(mean)
    local lra_d_se = r(sd) / sqrt(r(N))

    // LATE (delta method)
    qui sum u_y
    local mean_num = r(mean)
    qui sum u_d
    local mean_denom = r(mean)
    local lra_late_pe = `mean_num' / `mean_denom'

    qui correlate u_y u_d, covariance
    matrix VCV_raw = r(C)
    local var_num   = VCV_raw[1,1]
    local var_denom = VCV_raw[2,2]
    local cov_nd    = VCV_raw[1,2]

    local vcv11 = `var_num'   / `N'
    local vcv12 = `cov_nd'    / `N'
    local vcv22 = `var_denom' / `N'

    local g1 = 1 / `mean_denom'
    local g2 = -`mean_num' / (`mean_denom'^2)
    local lra_late_se = sqrt(`g1'^2 * `vcv11' + 2*`g1'*`g2'*`vcv12' + `g2'^2 * `vcv22')
restore

display "LRA results:"
display "  ER Visits:        PE = " %9.4f `lra_er_pe'   "  SE = " %9.4f `lra_er_se'
display "  Medicaid Take-Up: PE = " %9.4f `lra_d_pe'    "  SE = " %9.4f `lra_d_se'
display "  LATE:             PE = " %9.4f `lra_late_pe'  "  SE = " %9.4f `lra_late_se'


// --- FRA (Random Forest, 3 folds) -------------------------------------------
display " "
display "Running FRA (Random Forest, 3 folds)..."
preserve
    fra_run y d, treat(w) covariates(`covariates') nfolds(3) seed(623) method(rf)

    // ATE for y (reduced form)
    gen u_y = u_y_1 - u_y_0
    qui sum u_y
    local fra_er_pe = r(mean)
    local fra_er_se = r(sd) / sqrt(r(N))

    // ATE for d (first stage)
    gen u_d = u_d_1 - u_d_0
    qui sum u_d
    local fra_d_pe = r(mean)
    local fra_d_se = r(sd) / sqrt(r(N))

    // LATE (delta method)
    qui sum u_y
    local mean_num = r(mean)
    qui sum u_d
    local mean_denom = r(mean)
    local fra_late_pe = `mean_num' / `mean_denom'

    qui correlate u_y u_d, covariance
    matrix VCV_raw = r(C)
    local var_num   = VCV_raw[1,1]
    local var_denom = VCV_raw[2,2]
    local cov_nd    = VCV_raw[1,2]

    local vcv11 = `var_num'   / `N'
    local vcv12 = `cov_nd'    / `N'
    local vcv22 = `var_denom' / `N'

    local g1 = 1 / `mean_denom'
    local g2 = -`mean_num' / (`mean_denom'^2)
    local fra_late_se = sqrt(`g1'^2 * `vcv11' + 2*`g1'*`g2'*`vcv12' + `g2'^2 * `vcv22')
restore

display "FRA results:"
display "  ER Visits:        PE = " %9.4f `fra_er_pe'   "  SE = " %9.4f `fra_er_se'
display "  Medicaid Take-Up: PE = " %9.4f `fra_d_pe'    "  SE = " %9.4f `fra_d_se'
display "  LATE:             PE = " %9.4f `fra_late_pe'  "  SE = " %9.4f `fra_late_se'


// =============================================================================
// PART 4: DISPLAY AND EXPORT TABLE 7
// =============================================================================

// --- Console output ----------------------------------------------------------
display " "
display "--- Table 7: Variance Reduction for OHIE ---"
display %~20s "" %~12s "SM" %~12s "LRA" %~12s "FRA"

// Pre-build SE strings with parentheses (display cannot concatenate inline)
local sm_er_se_d  "(`= string(`sm_er_se', "%9.4f")')"
local lra_er_se_d "(`= string(`lra_er_se', "%9.4f")')"
local fra_er_se_d "(`= string(`fra_er_se', "%9.4f")')"
local sm_d_se_d   "(`= string(`sm_d_se', "%9.4f")')"
local lra_d_se_d  "(`= string(`lra_d_se', "%9.4f")')"
local fra_d_se_d  "(`= string(`fra_d_se', "%9.4f")')"
local sm_lt_se_d  "(`= string(`sm_late_se', "%9.4f")')"
local lra_lt_se_d "(`= string(`lra_late_se', "%9.4f")')"
local fra_lt_se_d "(`= string(`fra_late_se', "%9.4f")')"

// Row 1: ER Visits
display %~20s "ER Visits" ///
    %~12s string(`sm_er_pe', "%9.4f") ///
    %~12s string(`lra_er_pe', "%9.4f") ///
    %~12s string(`fra_er_pe', "%9.4f")
display %~20s "" %~12s "`sm_er_se_d'" %~12s "`lra_er_se_d'" %~12s "`fra_er_se_d'"

// Row 2: Medicaid Take-Up
display %~20s "Medicaid Take-Up" ///
    %~12s string(`sm_d_pe', "%9.4f") ///
    %~12s string(`lra_d_pe', "%9.4f") ///
    %~12s string(`fra_d_pe', "%9.4f")
display %~20s "" %~12s "`sm_d_se_d'" %~12s "`lra_d_se_d'" %~12s "`fra_d_se_d'"

// Row 3: LATE
display %~20s "LATE" ///
    %~12s string(`sm_late_pe', "%9.4f") ///
    %~12s string(`lra_late_pe', "%9.4f") ///
    %~12s string(`fra_late_pe', "%9.4f")
display %~20s "" %~12s "`sm_lt_se_d'" %~12s "`lra_lt_se_d'" %~12s "`fra_lt_se_d'"

// Format N with comma
local N_fmt : display %12.0fc `N'
local N_fmt = strtrim("`N_fmt'")
display "N = `N_fmt'"


// --- LaTeX output ------------------------------------------------------------
local tex_file "`output_dir'/table_7_OHIE.tex"

// Format all cells
local sm_er_pe_f   : display %9.4f `sm_er_pe'
local sm_er_se_f   : display %9.4f `sm_er_se'
local lra_er_pe_f  : display %9.4f `lra_er_pe'
local lra_er_se_f  : display %9.4f `lra_er_se'
local fra_er_pe_f  : display %9.4f `fra_er_pe'
local fra_er_se_f  : display %9.4f `fra_er_se'
local sm_d_pe_f    : display %9.4f `sm_d_pe'
local sm_d_se_f    : display %9.4f `sm_d_se'
local lra_d_pe_f   : display %9.4f `lra_d_pe'
local lra_d_se_f   : display %9.4f `lra_d_se'
local fra_d_pe_f   : display %9.4f `fra_d_pe'
local fra_d_se_f   : display %9.4f `fra_d_se'
local sm_late_pe_f : display %9.4f `sm_late_pe'
local sm_late_se_f : display %9.4f `sm_late_se'
local lra_late_pe_f: display %9.4f `lra_late_pe'
local lra_late_se_f: display %9.4f `lra_late_se'
local fra_late_pe_f: display %9.4f `fra_late_pe'
local fra_late_se_f: display %9.4f `fra_late_se'

// Trim whitespace from formatted numbers
foreach v in sm_er_pe_f sm_er_se_f lra_er_pe_f lra_er_se_f fra_er_pe_f fra_er_se_f ///
             sm_d_pe_f sm_d_se_f lra_d_pe_f lra_d_se_f fra_d_pe_f fra_d_se_f ///
             sm_late_pe_f sm_late_se_f lra_late_pe_f lra_late_se_f fra_late_pe_f fra_late_se_f {
    local `v' = strtrim("``v''")
}

capture file close texf
file open texf using "`tex_file'", write replace

file write texf "\begin{table}[h!]" _n
file write texf "\centering" _n
file write texf "\renewcommand{\arraystretch}{1.5}" _n
file write texf "\begin{tabular}{l c c c}" _n
file write texf "    \hline\hline" _n
file write texf "    & \textbf{SM} & \textbf{LRA} & \textbf{FRA} \\" _n
file write texf "    \hline" _n
// ER Visits
file write texf "    ER Visits & `sm_er_pe_f' & `lra_er_pe_f' & `fra_er_pe_f' \\" _n
file write texf "    & (`sm_er_se_f') & (`lra_er_se_f') & (`fra_er_se_f') \\" _n
file write texf "    \hline" _n
// Medicaid Take-Up
file write texf "    Medicaid Take-Up & `sm_d_pe_f' & `lra_d_pe_f' & `fra_d_pe_f' \\" _n
file write texf "    & (`sm_d_se_f') & (`lra_d_se_f') & (`fra_d_se_f') \\" _n
file write texf "    \hline" _n
// LATE
file write texf "    LATE & `sm_late_pe_f' & `lra_late_pe_f' & `fra_late_pe_f' \\" _n
file write texf "    & (`sm_late_se_f') & (`lra_late_se_f') & (`fra_late_se_f') \\" _n
file write texf "    \hline" _n
// Notes
file write texf "    \multicolumn{4}{l}{\scriptsize\textit{Note:} Point estimates with standard errors in parentheses.} \\" _n
file write texf "    \multicolumn{4}{l}{\scriptsize SM = Subsample Means, LRA = Linear Regression Adjustment,} \\" _n
file write texf `"    \multicolumn{4}{l}{\scriptsize FRA = Flexible Regression Adjustment (Random Forest). \$N = `N_fmt'\$.} \\"' _n
file write texf "    \hline\hline" _n
file write texf "\end{tabular}" _n
file write texf "\caption{Variance Reduction for OHIE (Table 7)}" _n
file write texf "\end{table}"

file close texf
display " "
display "Saved to: `tex_file'"


// --- HTML output -------------------------------------------------------------
local html_file "`output_dir'/table_7_OHIE.html"

capture file close htmlf
file open htmlf using "`html_file'", write replace

file write htmlf `"<!DOCTYPE html>"' _n
file write htmlf `"<html>"' _n
file write htmlf `"<head>"' _n
file write htmlf `"<meta charset="utf-8">"' _n
file write htmlf `"<title>Table 7: OHIE</title>"' _n
file write htmlf `"<style>"' _n
file write htmlf `"    body { font-family: "Helvetica Neue", Arial, sans-serif; margin: 40px; color: #2c3e50; }"' _n
file write htmlf `"    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }"' _n
file write htmlf `"    table { border-collapse: collapse; margin: 20px auto; }"' _n
file write htmlf `"    th { background-color: #1a3e82; color: white; padding: 10px 24px;"' _n
file write htmlf `"         font-size: 13px; text-align: center; }"' _n
file write htmlf `"    td { padding: 6px 24px; text-align: center; font-size: 13px; }"' _n
file write htmlf `"    .pe-row td { border-top: 1px solid #ddd; padding-bottom: 2px; }"' _n
file write htmlf `"    .pe-row td:first-child { text-align: left; font-weight: 500; }"' _n
file write htmlf `"    .se-row td { color: #666; padding-top: 0; padding-bottom: 8px; }"' _n
file write htmlf `"    .se-row td:first-child { text-align: left; }"' _n
file write htmlf `"    tr:hover td { background-color: #f0f4fb; }"' _n
file write htmlf `"    .note { max-width: 650px; margin: 12px auto; font-size: 11px;"' _n
file write htmlf `"            color: #666; text-align: center; line-height: 1.5; }"' _n
file write htmlf `"</style>"' _n
file write htmlf `"</head>"' _n
file write htmlf `"<body>"' _n
file write htmlf `"<h2>Table 7: Variance Reduction for OHIE</h2>"' _n
file write htmlf `"<table>"' _n
file write htmlf `"    <thead>"' _n
file write htmlf `"      <tr><th></th><th>SM</th><th>LRA</th><th>FRA</th></tr>"' _n
file write htmlf `"    </thead>"' _n
file write htmlf `"    <tbody>"' _n
// ER Visits
file write htmlf `"      <tr class="pe-row"><td>ER Visits</td>"' ///
    `"<td>`sm_er_pe_f'</td><td>`lra_er_pe_f'</td><td>`fra_er_pe_f'</td></tr>"' _n
file write htmlf `"      <tr class="se-row"><td></td>"' ///
    `"<td>(`sm_er_se_f')</td><td>(`lra_er_se_f')</td><td>(`fra_er_se_f')</td></tr>"' _n
// Medicaid Take-Up
file write htmlf `"      <tr class="pe-row"><td>Medicaid Take-Up</td>"' ///
    `"<td>`sm_d_pe_f'</td><td>`lra_d_pe_f'</td><td>`fra_d_pe_f'</td></tr>"' _n
file write htmlf `"      <tr class="se-row"><td></td>"' ///
    `"<td>(`sm_d_se_f')</td><td>(`lra_d_se_f')</td><td>(`fra_d_se_f')</td></tr>"' _n
// LATE
file write htmlf `"      <tr class="pe-row"><td>LATE</td>"' ///
    `"<td>`sm_late_pe_f'</td><td>`lra_late_pe_f'</td><td>`fra_late_pe_f'</td></tr>"' _n
file write htmlf `"      <tr class="se-row"><td></td>"' ///
    `"<td>(`sm_late_se_f')</td><td>(`lra_late_se_f')</td><td>(`fra_late_se_f')</td></tr>"' _n
file write htmlf `"    </tbody>"' _n
file write htmlf `"</table>"' _n
file write htmlf `"<p class="note"><em>Note:</em> Point estimates with standard errors in "' ///
    `"parentheses. SM = Subsample Means (simple difference in means), "' ///
    `"LRA = Linear Regression Adjustment (OLS with cross-fitting), "' ///
    `"FRA = Flexible Regression Adjustment (Random Forest with cross-fitting). "' ///
    `"N = `N_fmt'.</p>"' _n
file write htmlf `"</body>"' _n
file write htmlf `"</html>"'

file close htmlf
display "Saved to: `html_file'"
display " "
display "Done."


// =============================================================================
// END OF FLEXIBLE REGRESSION ADJUSTMENT
// =============================================================================
