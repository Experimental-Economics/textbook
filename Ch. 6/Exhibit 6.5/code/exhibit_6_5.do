// =============================================================================
// Exhibit 6.5: Covariate Balance with CRE in Lalonde (1986; NSW)
// =============================================================================
// Creates a balance table comparing baseline characteristics across treatment
// and control groups in the Lalonde (1986; NSW) dataset using a Completely
// Randomized Experiment (CRE).
//
// Column 1: Covariate name and type (proportion vs. mean)
// Column 2: Control group mean (SD)
// Column 3: Treatment group mean (SD)
// Column 4: Difference of means with p-value
//
// For continuous variables: Uses t-test for difference in means
// For binary/categorical variables: Uses z-test for difference in proportions
//
// Reference: Chapter 6, Exhibit 6.5

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 6/Exhibit 6.5/code"

// Define paths relative to the script location
local output_dir "../output"
local data_dir "../data"

// Create the output folder
capture mkdir "`output_dir'"


// --- Balance table program ---------------------------------------------------
capture program drop balance_table
program define balance_table
    syntax varlist, TREATment(varname) CONTinuous(varlist) [SAVEto(string)]

    /*
    Create a balance table comparing treatment groups on baseline covariates.

    Parameters:
    -----------
    varlist : List of variables to include in balance table
    treatment() : Name of the treatment variable
    continuous() : List of continuous variables (others treated as binary)
    saveto() : Optional path to save LaTeX output

    Returns:
    --------
    Displays formatted balance table and optionally saves to LaTeX file
    */

    // Store variable list
    local all_vars `varlist'
    local cont_vars `continuous'
    local treat_var `treatment'

    // Determine binary variables
    local binary_vars : list all_vars - cont_vars

    // Create a temporary file to store results
    tempname results
    tempfile balance_results

    // Initialize results file
    postfile `results' str30 covariate str12 type ///
        control_mean control_sd control_n ///
        treatment_mean treatment_sd treatment_n ///
        difference pvalue ///
        using `balance_results'

    // Loop through all covariates
    foreach var in `all_vars' {
        // Get variable label
        local varlab : variable label `var'
        if "`varlab'" == "" {
            local varlab "`var'"
        }

        // Determine if continuous or binary
        local is_continuous = 0
        foreach cvar in `cont_vars' {
            if "`var'" == "`cvar'" {
                local is_continuous = 1
            }
        }

        // Set type label
        local type = cond(`is_continuous', "Mean", "Proportion")

        // Calculate summary statistics by group
        quietly summarize `var' if `treat_var' == 0
        local control_mean = r(mean)
        local control_sd = r(sd)
        local control_n = r(N)

        quietly summarize `var' if `treat_var' == 1
        local treatment_mean = r(mean)
        local treatment_sd = r(sd)
        local treatment_n = r(N)

        local difference = `control_mean' - `treatment_mean'

        // Perform appropriate statistical test
        if `is_continuous' {
            // Welch's t-test for continuous variables (unequal variances)
            quietly ttest `var', by(`treat_var') unequal
            local pvalue = r(p)
        }
        else {
            // Z-test for proportions (binary variables)
            quietly prtest `var', by(`treat_var')
            local pvalue = r(p)
        }

        // Post results
        post `results' ("`varlab'") ("`type'") ///
            (`control_mean') (`control_sd') (`control_n') ///
            (`treatment_mean') (`treatment_sd') (`treatment_n') ///
            (`difference') (`pvalue')
    }

    // Close postfile
    postclose `results'

    // Preserve current dataset
    preserve

    // Load results
    use `balance_results', clear

    // Display to console
    display _newline
    display "{hline 80}"
    display "EXHIBIT 6.5: Covariate Balance with CRE in Lalonde (1986; NSW)"
    display "{hline 80}"
    display "{txt}{col 1}Covariate{col 27}Type{col 40}Control{col 56}Treatment{col 68}Diff{col 78}p-value"
    display "{txt}{col 40}Mean (SD){col 56}Mean (SD)"
    display "{hline 80}"

    // Display each row
    forvalues i = 1/`=_N' {
        local cov = covariate[`i']
        local typ = type[`i']
        local c_m = control_mean[`i']
        local c_sd = control_sd[`i']
        local t_m = treatment_mean[`i']
        local t_sd = treatment_sd[`i']
        local diff = difference[`i']
        local pval = pvalue[`i']

        // Add significance stars
        local stars = ""
        if `pval' < 0.01 {
            local stars = "**"
        }
        else if `pval' < 0.05 {
            local stars = "*"
        }

        display "{txt}{col 1}`cov'{col 27}`typ'{col 40}" ///
            %6.2f `c_m' " (" %5.2f `c_sd' "){col 56}" ///
            %6.2f `t_m' " (" %5.2f `t_sd' "){col 68}" ///
            %7.2f `diff' "`stars'{col 78}" %6.2f `pval'
    }

    display "{hline 80}"
    local obs_control = control_n[1]
    local obs_treatment = treatment_n[1]
    display "{txt}{col 1}Observations{col 40}" %15.0f `obs_control' "{col 56}" %15.0f `obs_treatment'
    display "{hline 80}"
    display _newline "Note: * p<0.05, ** p<0.01"

    // Save results to LaTeX if requested
    if "`saveto'" != "" {
        // Format results for LaTeX table
        gen latex_control = string(control_mean, "%6.2f") + " (" + string(control_sd, "%5.2f") + ")"
        gen latex_treatment = string(treatment_mean, "%6.2f") + " (" + string(treatment_sd, "%5.2f") + ")"

        // Add significance stars to difference
        gen stars = ""
        replace stars = "**" if pvalue < 0.01
        replace stars = "*" if pvalue >= 0.01 & pvalue < 0.05

        gen latex_difference = string(difference, "%6.2f") + stars
        gen latex_pvalue = string(pvalue, "%6.2f")

        // Keep only needed variables for LaTeX export
        keep covariate type latex_control latex_treatment latex_difference latex_pvalue

        // Rename for LaTeX table headers
        rename covariate Covariate
        rename type Type
        rename latex_control Control_Mean_SD
        rename latex_treatment Treatment_Mean_SD
        rename latex_difference Difference
        rename latex_pvalue p_value

        // Export to LaTeX using texsave or dataout
        // Note: This requires texsave package. Install with: ssc install texsave
        capture which texsave
        if _rc == 0 {
            texsave using "`saveto'", ///
                replace ///
                title("Exhibit 6.5: Covariate Balance with CRE in Lalonde (1986; NSW)") ///
                headerlines("Covariate & Type & Control Mean (SD) & Treatment Mean (SD) & Difference & p-value") ///
                nonames ///
                hlines(1) ///
                footnote("Note: * p<0.05, ** p<0.01")

            display _newline "✓ Saved to: `saveto'"
        }
        else {
            // Fallback: manual LaTeX export
            file open texfile using "`saveto'", write replace
            file write texfile "\begin{table}" _n
            file write texfile "\caption{Covariate Balance with CRE in Lalonde (1986; NSW)}" _n
            file write texfile "\label{tab:exhibit_6_5}" _n
            file write texfile "\begin{tabular}{llllll}" _n
            file write texfile "\toprule" _n
            file write texfile "Covariate & Type & Control Mean (SD) & Treatment Mean (SD) & Difference & p-value \\" "\" _n
            file write texfile "\midrule" _n

            forvalues i = 1/`=_N' {
                local cov = Covariate[`i']
                local typ = Type[`i']
                local c = Control_Mean_SD[`i']
                local t = Treatment_Mean_SD[`i']
                local d = Difference[`i']
                local p = p_value[`i']

                file write texfile "`cov' & `typ' & `c' & `t' & `d' & `p' \\" "\" _n
            }

            file write texfile "\bottomrule" _n
            file write texfile "\end{tabular}" _n
            file write texfile "\end{table}" _n
            file close texfile

            display _newline "✓ Saved to: `saveto'"
            display "  (Note: Install texsave for better formatting: ssc install texsave)"
        }
    }

    // Restore original dataset
    restore
end


// --- Load data ---------------------------------------------------------------
// Load Lalonde (1986) dataset
use "`data_dir'/lalonde2.dta", clear

// Keep only observations with non-missing treatment
keep if !missing(treated)


// --- Label variables ---------------------------------------------------------
label var nodegree "High School Dropout"
label var black "Black"
label var hisp "Hispanic"
label var married "Married"
label var age "Age"
label var educ "Years of Schooling"
label var kids18 "Num. Kids under 18"
label var re74 "Real Earnings 1974"


// --- Generate balance table --------------------------------------------------
// Call the balance_table program
balance_table nodegree black hisp married age educ kids18 re74, ///
    treatment(treated) ///
    continuous(age educ kids18 re74) ///
    saveto("`output_dir'/Exhibit_6_5_stata.tex")


// =============================================================================
// END OF EXHIBIT 6.5
// =============================================================================