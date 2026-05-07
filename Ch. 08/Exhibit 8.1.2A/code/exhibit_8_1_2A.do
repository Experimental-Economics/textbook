// =============================================================================
// Exhibit 8.1.2A: Baron and Kenny Mediation Analysis: Parental Beliefs
// =============================================================================
// Conducts mediation analysis using the Baron and Kenny framework to examine
// the relationship between home visiting programs, parental beliefs, and outcomes
// (parental investments and child outcomes).
//
// Implements the Baron and Kenny approach with three regression equations:
// - M_i = α + λ_dm*D_i + X_i'δ + v_i                    (A8.1.4)
// - Y_i = θ + λ_dy*D_i + X_i'δ + ω_i                    (A8.1.5)
// - Y_i = μ + λ_dy*D_i + λ_my*M_i + X_i'δ + ε_i        (A8.1.6)
//
// where:
// - D_i: Treatment indicator (Home Visiting Program)
// - M_i: Mediator (Parental Beliefs)
// - Y_i: Outcome (Parental Investments or Child Outcome)
//
// Reference: Chapter 8, Section 8.3.1, Mediation Analysis

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 8/Exhibit 8.1.2A/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"


// --- Load data ---------------------------------------------------------------
use "`data_dir'/TMPdata_de-identified.dta", clear

// Keep only needed variables and rename for clarity
keep speak22_A2_sd Treated cvc_A2_sd ctc_A2_sd
rename speak22_A2_sd M
rename Treated D
rename cvc_A2_sd Y_child
rename ctc_A2_sd Y_invest


// --- Step 1: Regression of Y on D (without mediator) ------------------------
// Equation A8.1.5: Y_i = θ + λ_dy*D_i + ω_i
eststo model_child: quietly reg Y_child D
eststo model_invest: quietly reg Y_invest D


// --- Step 2: Regression of M on D -------------------------------------------
// Equation A8.1.4: M_i = α + λ_dm*D_i + v_i
eststo model_m: quietly reg M D


// --- Step 3: Regression of Y on M, controlling for D ------------------------
// Equation A8.1.6: Y_i = μ + λ_dy*D_i + λ_my*M_i + ε_i
eststo model_childm: quietly reg Y_child M D
eststo model_investm: quietly reg Y_invest M D


// --- Step 4: Sobel test for mediation ---------------------------------------
// Calculate Sobel test for Parental Investments
// Extract coefficients
quietly reg M D
local i_coef_a = _b[D]
local i_var_a = _se[D]^2

quietly reg Y_invest M D
local i_coef_b = _b[M]
local i_var_b = _se[M]^2

// Calculate indirect effect and standard error
local i_indirect = `i_coef_a' * `i_coef_b'
local i_se_indirect = sqrt(`i_coef_a'^2 * `i_var_b' + `i_coef_b'^2 * `i_var_a')
local i_z = `i_indirect' / `i_se_indirect'
local i_p = 2 * (1 - normal(abs(`i_z')))

// Calculate Sobel test for Child Outcome
quietly reg Y_child M D
local c_coef_b = _b[M]
local c_var_b = _se[M]^2

local c_indirect = `i_coef_a' * `c_coef_b'
local c_se_indirect = sqrt(`i_coef_a'^2 * `c_var_b' + `c_coef_b'^2 * `i_var_a')
local c_z = `c_indirect' / `c_se_indirect'
local c_p = 2 * (1 - normal(abs(`c_z')))


// --- Print results -----------------------------------------------------------
display ""
display "{hline 80}"
display "EXHIBIT 8.1.2A: Baron and Kenny Mediation Analysis: Parental Beliefs"
display "{hline 80}"
display ""

display "(1) Parental Beliefs: M ~ D"
display "{hline 80}"
eststo model_m
estimates replay model_m
display ""

display "(2) Parental Investments: Y_invest ~ D (no mediator)"
display "{hline 80}"
estimates replay model_invest
display ""

display "(3) Parental Investments: Y_invest ~ M + D (with mediator)"
display "{hline 80}"
estimates replay model_investm
display ""

display "(4) Child Outcome: Y_child ~ D (no mediator)"
display "{hline 80}"
estimates replay model_child
display ""

display "(5) Child Outcome: Y_child ~ M + D (with mediator)"
display "{hline 80}"
estimates replay model_childm
display ""

display "Sobel Test Results"
display "{hline 80}"
display "Parental Investments: z = " %5.2f `i_z' ", p = " %6.4f `i_p'
display "Child Outcome: z = " %5.2f `c_z' ", p = " %6.4f `c_p'
display ""


// --- Save results to LaTeX ---------------------------------------------------
// Create matrix for table results
matrix results = J(5, 5, .)

// Extract coefficients and standard errors
quietly reg M D
matrix results[3,1] = _b[D]
matrix results[4,1] = _se[D]

quietly reg Y_invest D
matrix results[3,2] = _b[D]
matrix results[4,2] = _se[D]

quietly reg Y_invest M D
matrix results[1,3] = _b[M]
matrix results[2,3] = _se[M]
matrix results[3,3] = _b[D]
matrix results[4,3] = _se[D]
matrix results[5,3] = `i_z'

quietly reg Y_child D
matrix results[3,4] = _b[D]
matrix results[4,4] = _se[D]

quietly reg Y_child M D
matrix results[1,5] = _b[M]
matrix results[2,5] = _se[M]
matrix results[3,5] = _b[D]
matrix results[4,5] = _se[D]
matrix results[5,5] = `c_z'

// Row and column names
matrix rownames results = "Parental_Beliefs" "SE_Beliefs" ///
                          "Home_Visiting" "SE_Program" "Sobel_z"
matrix colnames results = "M_on_D" "Y_invest_D" "Y_invest_MD" ///
                          "Y_child_D" "Y_child_MD"

// Alternative approach: Use esttab for cleaner output
// Note: This creates a formatted table but doesn't include Sobel test
esttab model_m model_invest model_investm model_child model_childm ///
    using "`output_dir'/Exhibit_8_1_2A_stata.tex", ///
    replace ///
    b(3) se(3) ///
    booktabs ///
    nomtitles ///
    coeflabels(M "Parental Beliefs" D "Home Visiting Program" _cons "Constant") ///
    stats(N r2, fmt(%9.0fc %9.3f) labels("Observations" "R-squared")) ///
    title("Exhibit 8.1.2A: Baron and Kenny Mediation Analysis: Parental Beliefs") ///
    nonumbers ///
    mtitles("(1) Beliefs" "(2) Investments" "(3) Investments" "(4) Child" "(5) Child") ///
    addnote("Column 1: Parental Beliefs ~ Treatment" ///
            "Columns 2-3: Parental Investments without/with mediator" ///
            "Columns 4-5: Child Outcome without/with mediator" ///
            "Sobel z-test (Investments): `=string(`i_z', "%5.2f")'" ///
            "Sobel z-test (Child Outcome): `=string(`c_z', "%5.2f")'" ///
            "Standard errors in parentheses")

display "Saved to: `output_dir'/Exhibit_8_1_2A_stata.tex"


// =============================================================================
// END OF EXHIBIT 8.1.2A
// =============================================================================
