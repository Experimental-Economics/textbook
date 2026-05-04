// =============================================================================
// Chapter 15: Post-Study Probability (PSP) Tables and Figures
// Generates Exhibits 15.2, 15.3, 15.4, 15.5, 15.6, and 15.8
// =============================================================================

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 15/PSP Tables and figures/code"

// Define paths relative to the script location
local output_dir "../output"

// Create the output folder
capture mkdir "`output_dir'"

// Check if estout (and thus esttab) is installed
capture which esttab
if _rc {
    ssc install estout
}


// =============================================================================
// EXHIBIT 15.2: PSP Across Different Priors
// =============================================================================
// PSP is calculated based on Equation 15.1 (Chapter 15)
// Reference: https://onlinelibrary.wiley.com/doi/epdf/10.1111/ecoj.12527 (pg 211)

// Setting necessary values for alpha, beta and prior
scalar beta = 0
scalar alpha = 0.05
local pi_list "0.0001 0.001 0.01 0.05 0.1 0.2 0.3 0.4 0.5"

// Creating matrix
matrix A = J(`=wordcount("`pi_list'")', 7, .)
matrix colnames A = "Prior" "Power" "Significance" "True Null Rejections" "False Null Rejections" "Total Null Rejections" "PSP"

local i = 1
foreach var of local pi_list {
    matrix A[`i', 1] = `var'                                    // Prior column
    matrix A[`i', 2] = 1                                        // Power column
    matrix A[`i', 3] = alpha                                    // Significance column
    matrix A[`i', 4] = round((1 - beta) * `var', 0.0001)       // True Null Rejections column
    matrix A[`i', 5] = round(alpha * (1 - `var'), 0.0001)      // False Null Rejections column
    matrix A[`i', 6] = round((1 - beta) * `var' + alpha * (1 - `var'), 0.0001)  // Total Null Rejections column
    matrix A[`i', 7] = (1 - beta) * `var'/((1 - beta) * `var' + alpha * (1 - `var'))  // PSP column
    local i = `i' + 1
}

// Displaying matrix
display _newline(2) "{hline 80}"
display "EXHIBIT 15.2: PSP Across Different Priors"
display "{hline 80}"
matlist A, names(columns) aligncolnames(lalign) cspec(|%9.4f|%5.0f| %9.2f | %9.4f | %9.4f | %9.4f | %9.4f |) rspec(-----------)

// Saving matrix to .tex file
esttab matrix(A, fmt(4)) using "`output_dir'/Exhibit_15_2_stata.tex", replace title(Exhibit 15.2) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_2_stata.tex"


// =============================================================================
// EXHIBIT 15.3: PSP Changes with Power and Priors
// =============================================================================
// PSP is calculated based on Equation 15.1 (Chapter 15)
// Reference: https://onlinelibrary.wiley.com/doi/epdf/10.1111/ecoj.12527 (pg. 211)

// Setting necessary values for beta and power
local beta1 = 0.2
local beta2 = 0.5
local pow_list "0.01 0.02 0.05 0.10 0.20 0.30 0.40 0.50"
local beta1_100 = `beta1' * 100
local beta2_100 = `beta2' * 100

// Creating matrix
matrix B = J(`=wordcount("`pow_list'")', 3, 1)
matrix colnames B = "Power" "PSP_`beta1_100'" "PSP_`beta2_100'"
matrix rownames B = "1" "2" "3" "4" "5" "6" "7" "8"

local i = 1
foreach var of local pow_list {
    matrix B[`i', 1] = `var'                                    // Power column
    forvalues j=1/2{
        matrix B[`i', `j'+1] = round(((1 - `beta`j'') * `var') / ((1 - `beta`j'') * `var' + alpha * (1 - `var')), 0.01)  // PSP columns
    }
    local i = `i' + 1
}

// Displaying matrix
display _newline(2) "{hline 80}"
display "EXHIBIT 15.3: PSP Changes with Power and Priors"
display "{hline 80}"
matlist B, names(columns) format(%9.2f)

// Saving matrix to .txt
esttab matrix(B, fmt(2)) using "`output_dir'/Exhibit_15_3_stata.tex", replace title(Exhibit 15.3) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_3_stata.tex"


// =============================================================================
// EXHIBIT 15.4: PSP Across Different Levels of Significance, Power, and Priors
// =============================================================================
// PSP is calculated based on Equation 15.1 (Chapter 15)

// Setting necessary values for power, prior and alpha
local pow_list "0.20 0.30 0.50 0.70 0.80"
local pi_list "0.01 0.02 0.05 0.10 0.20 0.30 0.40 0.50"
local alpha_list "0.05 0.005"

// Creating matrices for different alpha values (alpha = 0.05 and alpha = 0.005)
local count = 1
foreach alpha of local alpha_list{
    matrix E_`count' = J(`=wordcount("`pi_list'")', `=wordcount("`pow_list'")', .)
    matrix colnames E_`count' = `pow_list'
    matrix rownames E_`count' = `pi_list'
    local row = 1
    foreach pi of local pi_list {                               // Looping through each row
        local col = 1
        foreach pow of local pow_list {                         // Looping through each column
            local numerator = `pow' * `pi'
            local denom = `numerator' + `alpha' * (1 - `pi')
            matrix E_`count'[`row', `col'] = round(`numerator' / `denom', 0.01)
            local col = `col' + 1
        }
        local row = `row' + 1
    }

    // Displaying matrices
    display _newline(2) "{hline 80}"
    display "EXHIBIT 15.4: PSP at alpha = " %4.3f `alpha'
    display "{hline 80}"
    matlist E_`count', format(%9.2f)

    local count = `count' + 1
}

// Saving matrices to .txt
esttab matrix(E_1, fmt(2)) using "`output_dir'/Exhibit_15_4_alpha_0.050_stata.tex", replace title(Exhibit 15.4, alpha = 0.05) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_4_alpha_0.050_stata.tex"
esttab matrix(E_2, fmt(2)) using "`output_dir'/Exhibit_15_4_alpha_0.005_stata.tex", replace title(Exhibit 15.4, alpha = 0.005) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_4_alpha_0.005_stata.tex"


// =============================================================================
// EXHIBIT 15.5: PSP With and Without a Statistically Significant Finding
// =============================================================================
// PSP(reject NULL) in top panel is derived from Equation 15.1 (Chapter 15)
// PSP(NULL) in bottom panel is derived from Equation 15.4 (Chapter 15)

// Setting necessary values for power and prior
local pow_list "0.20 0.30 0.50 0.70 0.80"
local pi_list "0.01 0.02 0.05 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 0.99"
local count_list "1 2"

// Creating matrices for PSP(reject NULL) and PSP(NULL)
foreach count of local count_list{
    matrix F_`count' = J(`=wordcount("`pi_list'")', `=wordcount("`pow_list'")', .)
    matrix colnames F_`count' = `pow_list'
    matrix rownames F_`count' = `pi_list'
    local row = 1
    foreach pi of local pi_list {                               // Looping through each row
        local col = 1
        foreach pow of local pow_list {                         // Looping through each column
            if `count' == 1 {
                // PSP when rejecting null (Equation 15.1)
                local numerator = `pow' * `pi'
                local denom = `numerator' + alpha * (1 - `pi')
                matrix F_`count'[`row', `col'] = round(`numerator' / `denom', 0.01)
            }
            else {
                // PSP when not rejecting null (Equation 15.4)
                local numerator = (1 - alpha) * (1 - `pi')
                local denom = (1 - `pow') * `pi' + `numerator'
                matrix F_`count'[`row', `col'] = round(1 - `numerator' / `denom', 0.01)
            }
            local col = `col' + 1
        }
        local row = `row' + 1
    }

    // Displaying matrices
    if `count' == 1 {
        local caption "EXHIBIT 15.5: PSP(reject NULL)"
    }
    else {
        local caption "EXHIBIT 15.5: PSP(NULL)"
    }

    display _newline(2) "{hline 80}"
    display "`caption'"
    display "{hline 80}"
    matlist F_`count', format(%9.2f)
}

// Saving matrices to .txt
esttab matrix(F_1, fmt(2)) using "`output_dir'/Exhibit_15_5_reject_NULL_stata.tex", replace title(Exhibit 15.5, PSP(reject NULL)) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_5_reject_NULL_stata.tex"
esttab matrix(F_2, fmt(2)) using "`output_dir'/Exhibit_15_5_NULL_stata.tex", replace title(Exhibit 15.5, PSP(NULL)) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_5_NULL_stata.tex"


// =============================================================================
// EXHIBIT 15.6: PSP Across Different Power, Stat Sig Level, Prior, and Number of Tests
// =============================================================================
// PSP is calculated based on Equation 15.5 (Chapter 15)
// Assumes n = i

// Store necessary value parameters
local num_list = "1 2 3 4"
local alpha = 0.05
local beta_1 = 0.2      // Power = 0.80
local beta_2 = 0.5      // Power = 0.50
local pi_list "0.01 0.02 0.05 0.10 0.20 0.30 0.40 0.50"

// Creating matrices for different power levels (0.80 and 0.50)
forvalues j=1/2{
    matrix C_`j' = J(`=wordcount("`pi_list'")', `=wordcount("`num_list'")', .)
    matrix colnames C_`j' = "i = 0" "i = 1" "i = 2" "i = 3"
    matrix rownames C_`j' = `pi_list'
    local k = 1
    foreach var in `pi_list' {                                  // Looping through each row
        forvalues r = 1/4 {
            local sum_beta = binomialp(`r', `r', (1 - `beta_`j''))
            local sum_alpha = binomialp(`r', `r', `alpha')
            local nominator_`r' = `var' * `sum_beta' / (`var' * `sum_beta' + (1 - `var') * `sum_alpha')
            matrix C_`j'[`k', `r'] = `nominator_`r''
        }

        local k = `k' + 1
    }

    // Displaying matrices
    if `j' == 1 {
        local caption "EXHIBIT 15.6: PSP for Power = 0.80"
    }
    else {
        local caption "EXHIBIT 15.6: PSP for Power = 0.50"
    }

    display _newline(2) "{hline 80}"
    display "`caption'"
    display "{hline 80}"
    matlist C_`j', format(%9.2f)
}

// Saving matrices to .txt
esttab matrix(C_1, fmt(2)) using "`output_dir'/Exhibit_15_6_power_0.80_stata.tex", replace title(Exhibit 15.6, Power = 0.80) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_6_power_0.80_stata.tex"
esttab matrix(C_2, fmt(2)) using "`output_dir'/Exhibit_15_6_power_0.50_stata.tex", replace title(Exhibit 15.6, Power = 0.50) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_6_power_0.50_stata.tex"


// =============================================================================
// EXHIBIT 15.8: PSP with Various Distance Levels
// =============================================================================
// PSP is calculated based on Equation 15.6 (Chapter 15)

// Setting necessary values for domain distance, power and pi
local distance = "0.00 0.10 0.25 0.50"
local pow_list "0.20 0.30 0.50 0.70 0.80"
local pi_list "0.01 0.05 0.10 0.20 0.30 0.40 0.50"

// Creating matrices for different values of distance
local count = 1
foreach di of local distance{
    matrix D_`count' = J(`=wordcount("`pi_list'")', `=wordcount("`pow_list'")', .)
    matrix colnames D_`count' = `pow_list'
    matrix rownames D_`count' = `pi_list'
    local row = 1
    foreach pi of local pi_list {                               // Looping through each row (pi)
        local col = 1
        foreach pow of local pow_list {                         // Looping through each column (power)
            local numerator = `pow' * `pi' + (1 - `pow') * `pi' * `di'
            local denom = `numerator' + (alpha + (1 - alpha) * `di') * (1 - `pi')
            matrix D_`count'[`row', `col'] = round(`numerator' / `denom', 0.01)
            local col = `col' + 1
        }
        local row = `row' + 1
    }

    // Displaying matrices
    display _newline(2) "{hline 80}"
    display "EXHIBIT 15.8: PSP at Distance = " %4.2f `di'
    display "{hline 80}"
    matlist D_`count', format(%9.2f)

    local count = `count' + 1
}

// Saving matrices to .txt
esttab matrix(D_1, fmt(2)) using "`output_dir'/Exhibit_15_8_distance_0.00_stata.tex", replace title(Exhibit 15.8, Distance = 0.00) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_8_distance_0.00_stata.tex"
esttab matrix(D_2, fmt(2)) using "`output_dir'/Exhibit_15_8_distance_0.10_stata.tex", replace title(Exhibit 15.8, Distance = 0.10) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_8_distance_0.10_stata.tex"
esttab matrix(D_3, fmt(2)) using "`output_dir'/Exhibit_15_8_distance_0.25_stata.tex", replace title(Exhibit 15.8, Distance = 0.25) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_8_distance_0.25_stata.tex"
esttab matrix(D_4, fmt(2)) using "`output_dir'/Exhibit_15_8_distance_0.50_stata.tex", replace title(Exhibit 15.8, Distance = 0.50) nomtitles
display _newline "Saved to: `output_dir'/Exhibit_15_8_distance_0.50_stata.tex"
