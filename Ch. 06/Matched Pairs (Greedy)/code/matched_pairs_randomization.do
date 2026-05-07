// =============================================================================
// Matched-Pairs Randomization
// =============================================================================
// Implements Matched-Pairs Design (also called Pairwise Matching) to assign
// treatment status to observations. This is a limiting case of stratification
// where pairs of similar units are matched based on baseline covariates, and
// then one unit in each pair is randomly assigned to treatment.
//
// The procedure:
// 1. Create outer strata based on discrete/categorical variables
// 2. Within each outer stratum, calculate Mahalanobis distance between all
//    pairs of units using continuous covariates
// 3. Use greedy algorithm to match pairs:
//    - Find the two units with smallest pairwise distance
//    - Randomly assign one to treatment, one to control
//    - Remove both from the pool
//    - Repeat until all units are matched
// 4. If stratum has odd number of units, apply Complete Randomization (CRE)
//    to the unpaired unit


clear all
set more off


// --- Setup -------------------------------------------------------------------
// Set paths relative to script location
local data_dir "../data"
local output_dir "../output"

// Create output directory
capture mkdir "`output_dir'"

// TODO: Set random seed for reproducibility
// Change to any integer for different randomization results
set seed 42


// --- Load Data ---------------------------------------------------------------
// TODO: Replace with your actual dataset filename
use "`data_dir'/unique_data_clean_main_synthetic.dta", clear


// --- User Parameters ---------------------------------------------------------
// TODO: Define categorical variables for outer stratification
// These should be discrete/binary variables like gender, race, location, etc.
local cat_vars "female race_w"

// TODO: Define continuous variables for Mahalanobis distance matching
// These should be numeric variables like test scores, age, income, etc.
// The algorithm will match units with similar values on these variables
local cont_vars "std_cog_pre birthweight std_ncog_pre year"

// Count number of continuous variables
local num_cont : word count `cont_vars'


// --- Preserve Original Order -------------------------------------------------
gen _original_order = _n


// --- Create Outer Strata -----------------------------------------------------
display _newline
display "{hline 80}"
display "MATCHED-PAIRS RANDOMIZATION"
display "{hline 80}"
display ""

// Create stratum ID by combining categorical variables
if "`cat_vars'" != "" {
    // Combine categorical variables into stratum identifier
    egen Stratum_ID = group(`cat_vars'), label
    display "Creating strata using: `cat_vars'"
}
else {
    // Single stratum containing all observations
    gen Stratum_ID = 1
    display "No stratification variables specified - using single stratum"
}

// Initialize output variables
gen Treatment = .
gen Pair_ID = .

// Save original data
tempfile original_data
save `original_data', replace


// --- Process Each Stratum ----------------------------------------------------
display "Processing strata for matching..."

// Get unique strata
levelsof Stratum_ID, local(strata)
local stratum_counter = 0
local global_pair_id = 0

// Temporary files for combining strata
tempfile combined_strata
clear
gen _temp = .
save `combined_strata', replace

// Loop through each stratum
foreach stratum in `strata' {
    use `original_data', clear
    keep if Stratum_ID == `stratum'

    local n_stratum = _N
    local stratum_counter = `stratum_counter' + 1

    display "  Stratum `stratum_counter' (ID=`stratum'): `n_stratum' observations"

    // Skip if stratum too small
    if `n_stratum' < 1 {
        continue
    }

    // Set per-stratum seed
    // Stata approximation: use stratum counter to modify seed
    local stratum_seed = 42 + `stratum' * 137
    set seed `stratum_seed'

    // If only 1 observation, apply CRE
    if `n_stratum' == 1 {
        gen Treatment_temp = runiformint(0, 1)
        gen Pair_ID_temp = -1
        local unpaired = 1
        local pairs = 0
        display "    -> 0 pairs, 1 unpaired (CRE)"
    }
    else {
        // Rename continuous variables to x1, x2, ... for matching algorithm
        local i = 1
        foreach var of local cont_vars {
            quietly gen x`i' = `var'
            local i = `i' + 1
        }

        // --- CALCULATE COVARIANCE AND DISTANCES ONCE ---
        quietly {
            // Create ID variable
            gen id = _n

            // Calculate covariance matrix ONCE for entire stratum 
            matrix accum M = x*, dev noconstant
            matrix M = M / (_N - 1)

            // Check if matrix is singular and only regularize if needed
            local n_vars : word count `cont_vars'
            scalar det_M = det(M)

            // Only add regularization if matrix is singular (det near 0)
            if abs(det_M) < 1e-10 {
                matrix I = I(`n_vars')
                matrix M = M + 0.000001 * I
            }

            // Generate all pairs of observations
            gen nrids = _N
            expand nrids
            bysort id: gen id2 = _n

            // Create paired variables
            foreach v of varlist id x* {
                gen p_`v' = `v'[nrids * id2]
            }

            drop nrids id2

            // Keep only unique pairs (not both 1-2 and 2-1)
            keep if id < p_id
            gen pair_id = _n
            local n_total_pairs = _N

            // Calculate Mahalanobis distance for each pair ONCE
            tempfile pairs_data
            save `pairs_data', replace

            // Generate blank dataset for distances
            drop if _n > 0
            gen id = .
            gen p_id = .
            gen maha = .
            tempfile distances_data
            save `distances_data', replace

            // Calculate distance for each pair
            forval i = 1/`n_total_pairs' {
                use `pairs_data', clear
                keep if pair_id == `i'

                // Store id and p_id before reshape
                local id_i = id[1]
                local id_j = p_id[1]

                // Reshape to calculate distance
                reshape long x p_x, i(id) j(index)
                sort index

                mkmat x, mat(X)
                mkmat p_x, mat(Y)

                // Mahalanobis distance: sqrt((X-Y)' * inv(M) * (X-Y))
                matrix D1 = (X - Y)' * inv(M) * (X - Y)
                svmat double D1, name(d1)

                // Create result row
                clear
                set obs 1
                gen id = `id_i'
                gen p_id = `id_j'
                gen maha = sqrt(d1[1])

                // Append to distances dataset
                append using `distances_data'
                save `distances_data', replace
            }

            // Clean up: remove empty first row
            drop if id == .
        }

        // Save distance matrix for greedy algorithm
        tempfile full_distances
        save `full_distances', replace

        // --- GREEDY MATCHING ALGORITHM (USING PRE-CALCULATED DISTANCES) ---
        tempfile matched_pairs unmatched_data

        // Get original data for this stratum
        use `original_data', clear
        keep if Stratum_ID == `stratum'
        gen _stratum_id = _n
        gen _available = 1  // Track which units are still available
        save `unmatched_data', replace

        // Initialize matched pairs dataset
        clear
        gen _stratum_id = .
        gen Treatment_temp = .
        gen Pair_ID_temp = .
        save `matched_pairs', replace

        // Track number of pairs matched
        local pair_counter = 0
        local n_remaining = `n_stratum'

        // Continue until fewer than 2 units remain
        while `n_remaining' >= 2 {
            // Get list of available units (using _stratum_id, not reindexed id!)
            use `unmatched_data', clear
            keep if _available == 1

            local n_remaining = _N
            if `n_remaining' < 2 {
                continue, break
            }

            // Get available unit IDs (use _stratum_id to maintain original indices)
            levelsof _stratum_id, local(available_ids)

            // Filter distance matrix to only available units
            use `full_distances', clear
            gen _keep = 0
            foreach i in `available_ids' {
                foreach j in `available_ids' {
                    replace _keep = 1 if (id == `i' & p_id == `j')
                }
            }
            keep if _keep == 1
            drop _keep

            // Find pair with minimum distance
            sort maha
            local best_i = id[1]
            local best_j = p_id[1]

            // Randomly assign treatment to one unit in the pair
            local rand_val = runiform()

            if `rand_val' < 0.5 {
                local treat_unit = `best_i'
                local control_unit = `best_j'
            }
            else {
                local treat_unit = `best_j'
                local control_unit = `best_i'
            }

            // Get original _stratum_id for these units (already have them in treat_unit and control_unit)
            local treat_stratum_id = `treat_unit'
            local control_stratum_id = `control_unit'

            // Add to matched pairs
            clear
            set obs 2
            gen _stratum_id = .
            replace _stratum_id = `treat_stratum_id' in 1
            replace _stratum_id = `control_stratum_id' in 2
            gen Treatment_temp = .
            replace Treatment_temp = 1 in 1
            replace Treatment_temp = 0 in 2
            gen Pair_ID_temp = `global_pair_id'

            append using `matched_pairs'
            save `matched_pairs', replace

            // Mark matched units as unavailable
            use `unmatched_data', clear
            gen id = _n
            replace _available = 0 if id == `best_i' | id == `best_j'
            drop id
            save `unmatched_data', replace

            local pair_counter = `pair_counter' + 1
            local global_pair_id = `global_pair_id' + 1

            // Count remaining available units
            quietly count if _available == 1
            local n_remaining = r(N)
        }

        // Handle unpaired unit (if any) with CRE
        use `unmatched_data', clear
        keep if _available == 1
        if _N == 1 {
            gen Treatment_temp = runiformint(0, 1)
            gen Pair_ID_temp = -1
            append using `matched_pairs'
            save `matched_pairs', replace
            local unpaired = 1
            display "    -> `pair_counter' pairs, 1 unpaired (CRE)"
        }
        else {
            local unpaired = 0
            display "    -> `pair_counter' pairs, 0 unpaired"
        }

        // Restore and merge with original stratum data
        use `original_data', clear
        keep if Stratum_ID == `stratum'
        gen _stratum_id = _n
        merge 1:1 _stratum_id using `matched_pairs', nogenerate
        drop _stratum_id
    }

    // Append to combined dataset
    append using `combined_strata'
    save `combined_strata', replace
}


// --- Restore Original Data and Merge -----------------------------------------
use `original_data', clear
drop Treatment Pair_ID

merge 1:1 _original_order using `combined_strata', nogenerate
rename Treatment_temp Treatment
rename Pair_ID_temp Pair_ID

// Restore original order
sort _original_order
drop _original_order


// --- Print Summary Statistics ------------------------------------------------
quietly {
    count
    local n_total = r(N)

    count if Treatment == 1
    local n_treatment = r(N)

    count if Treatment == 0
    local n_control = r(N)

    count if Pair_ID >= 0
    local n_paired = r(N)

    count if Pair_ID == -1
    local n_unpaired = r(N)

    egen n_pairs = max(Pair_ID)
    local n_pairs = n_pairs[1] + 1
    drop n_pairs
}

display ""
display "{hline 80}"
display "SUMMARY"
display "{hline 80}"
if "`cat_vars'" != "" {
    display "Categorical variables (outer strata): `cat_vars'"
}
display "Continuous variables (matching):      `cont_vars'"
display "Total observations:                   " %9.0fc `n_total'
display "Matched pairs:                        " %9.0fc `n_pairs'
display "  - Paired units:                     " %9.0fc `n_paired'
display "  - Unpaired units (CRE):             " %9.0fc `n_unpaired'
display "Assigned to treatment:                " %9.0fc `n_treatment'
display "Assigned to control:                  " %9.0fc `n_control'
display "{hline 80}"
display ""

// Summary by strata
if "`cat_vars'" != "" {
    display "Matching Summary by Stratum:"
    display "{hline 80}"

    quietly levelsof Stratum_ID, local(strata)
    foreach stratum in `strata' {
        quietly {
            count if Stratum_ID == `stratum'
            local n_stratum = r(N)

            count if Stratum_ID == `stratum' & Pair_ID >= 0
            local n_paired_stratum = r(N)
            local n_pairs_stratum = `n_paired_stratum' / 2

            count if Stratum_ID == `stratum' & Treatment == 1
            local n_treat = r(N)

            count if Stratum_ID == `stratum' & Treatment == 0
            local n_control = r(N)

            count if Stratum_ID == `stratum' & Pair_ID == -1
            local n_unpaired_stratum = r(N)
        }

        display ""
        display "Stratum: `stratum'"
        display "  Pairs:      " %5.0f `n_pairs_stratum'
        display "  Treatment:  " %5.0f `n_treat'
        display "  Control:    " %5.0f `n_control'
        if `n_unpaired_stratum' > 0 {
            display "  Unpaired (CRE): " %5.0f `n_unpaired_stratum'
        }
    }
    display ""
}

display "{hline 80}"
display ""
display "Note: Matched-pairs design creates pairs of similar units based on"
display "      Mahalanobis distance using continuous variables. Within outer strata"
display "      defined by categorical variables, pairs are matched using a greedy"
display "      algorithm (smallest distance first), and treatment is randomly assigned"
display "      within each pair."
display ""
display "      Units in strata with odd sizes cannot be paired. These unpaired units"
display "      are assigned to treatment or control using Complete Randomization (CRE)."
display "      They have Pair_ID = -1 to distinguish them from paired units."
display ""


// --- Validation: Check Each Pair has 1 Treatment and 1 Control ---------------
display ""
display "{hline 80}"
display "PAIR VALIDATION"
display "{hline 80}"

// Check pairs (exclude unpaired units with Pair_ID == -1)
quietly {
    count if Pair_ID >= 0
    local n_paired = r(N)

    if `n_paired' > 0 {
        // Check pair sizes
        egen tag_pair = tag(Pair_ID) if Pair_ID >= 0
        egen pair_size = count(Pair_ID), by(Pair_ID)

        count if tag_pair == 1 & pair_size != 2
        local bad_size = r(N)

        // Check treatment assignment
        egen treatment_sum = total(Treatment), by(Pair_ID)
        count if tag_pair == 1 & treatment_sum != 1
        local bad_treatment = r(N)

        // Count unique pairs
        count if tag_pair == 1
        local n_pairs = r(N)

        drop tag_pair pair_size treatment_sum
    }
    else {
        local n_pairs = 0
        local bad_size = 0
        local bad_treatment = 0
    }
}

if `n_paired' > 0 {
    if `bad_size' > 0 {
        display "❌ ERROR: Found " `bad_size' " pairs with size != 2"
    }
    else {
        display "✓ All " `n_pairs' " pairs have exactly 2 units"
    }

    if `bad_treatment' > 0 {
        display "❌ ERROR: Found " `bad_treatment' " pairs without 1 treatment + 1 control"
    }
    else {
        display "✓ All " `n_pairs' " pairs have exactly 1 treatment and 1 control"
    }
}
else {
    display "⚠ No paired units found"
}

display "{hline 80}"
display ""


// --- Balance Table for Debugging ---------------------------------------------
display ""
display "{hline 80}"
display "BALANCE TABLE (for debugging)"
display "{hline 80}"
display ""

// Get all variables to check (categorical + continuous)
local balance_vars "`cat_vars' `cont_vars'"

display "Balance across covariates:"
display "{hline 80}"
display _col(1) "Variable" _col(21) "Treat" _col(32) "Control" _col(43) "Diff" _col(54) "Std_Diff" _col(65) "p-value"
display "{hline 80}"

foreach var of local balance_vars {
    quietly {
        // Calculate means
        summarize `var' if Treatment == 1
        local mean_treat = r(mean)

        summarize `var' if Treatment == 0
        local mean_control = r(mean)

        local diff = `mean_treat' - `mean_control'

        // Calculate standardized difference
        summarize `var' if Treatment == 1
        local var_treat = r(Var)

        summarize `var' if Treatment == 0
        local var_control = r(Var)

        local pooled_sd = sqrt((`var_treat' + `var_control') / 2)
        local std_diff = `diff' / `pooled_sd'

        // Simple t-test
        ttest `var', by(Treatment)
        local p_value = r(p)
    }

    // Significance stars
    local sig = ""
    if `p_value' < 0.001 {
        local sig = "***"
    }
    else if `p_value' < 0.01 {
        local sig = "**"
    }
    else if `p_value' < 0.05 {
        local sig = "*"
    }

    display _col(1) "`var'" _col(21) %9.3f `mean_treat' _col(32) %9.3f `mean_control' ///
            _col(43) %9.3f `diff' _col(54) %9.3f `std_diff' _col(65) %9.4f `p_value' " `sig'"
}

display "{hline 80}"
display ""
display "Note: * p<0.05, ** p<0.01, *** p<0.001"
display "Standardized difference > 0.1 may indicate imbalance"
display "{hline 80}"
display ""


// --- Save Randomized Dataset -------------------------------------------------
// TODO: Replace with your desired output filename
save "`output_dir'/matched_pairs_randomized_dataset.dta", replace
display "✓ Saved to: `output_dir'/matched_pairs_randomized_dataset.dta"
display ""


// =============================================================================
// END OF MATCHED-PAIRS RANDOMIZATION
// =============================================================================
