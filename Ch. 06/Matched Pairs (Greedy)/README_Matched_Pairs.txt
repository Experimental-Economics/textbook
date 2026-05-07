##################################################################################################
                        README — Matched-Pairs Randomization (Chapter 6)
                              Experimental Design Implementation
##################################################################################################

This is a limiting case of stratification where pairs of similar units are
matched based on baseline covariates, and then one unit in each pair is randomly assigned to
treatment.

The procedure:
  1. Create outer strata based on discrete/categorical variables
  2. Within each outer stratum, calculate Mahalanobis distance between all pairs of units
     using continuous covariates
  3. Use greedy algorithm to match pairs:
     - Find the two units with smallest pairwise distance
     - Randomly assign one to treatment, one to control
     - Remove both from the pool
     - Repeat until all units are matched
  4. If stratum has odd number of units, apply Complete Randomization (CRE) to the
     unpaired unit


Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       CHECC dataset files
    output/     Generated output files (created automatically when you run the scripts)

Python, R, and Stata all use identical algorithms and will produce matching results
(within random variation due to different RNG implementations). You only need to run ONE.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths.


##################################################################################################
                                    DATA
##################################################################################################

  File:     data/unique_data_clean_main_synthetic.dta  (synthetic data for testing)
  
  Please add your own data to run the randomization for your experiement.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/matched_pairs_randomization.py

  Requirements: Python 3 with numpy and pandas.
  If missing, run in your terminal:    pip install numpy pandas

  How to run:
    - From a terminal:    python matched_pairs_randomization.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  User Parameters (lines 324-328):
    - CATEGORICAL_VARIABLES: Variables for outer stratification (e.g., ['female', 'race_w'])
    - CONTINUOUS_VARIABLES: Variables for Mahalanobis distance matching
                            (e.g., ['std_cog_pre', 'birthweight', 'std_ncog_pre', 'year'])
    - seed: Set to 42 for reproducibility

  Output:
    - output/matched_pairs_randomized_dataset.dta   (Randomized dataset with Treatment,
                                                     Pair_ID, and Stratum_ID variables)
    - Console output with detailed summary statistics

  Performance:
    - Uses vectorized numpy operations for efficiency (~30-120x faster than loops)
    - Handles large datasets efficiently with optimized Mahalanobis distance calculation


##################################################################################################
                                       R
##################################################################################################
  File:     code/matched_pairs_randomization.R

  Requirements: R with haven package.
  If missing, the script will automatically install it on first run.

  How to run:
    - From R console:    source("code/matched_pairs_randomization.R")
    - From terminal:     Rscript code/matched_pairs_randomization.R
    - Or open the file in RStudio and click "Source".

  User Parameters (lines 310-314):
    - CATEGORICAL_VARIABLES: Variables for outer stratification (e.g., c("female", "race_w"))
    - CONTINUOUS_VARIABLES: Variables for Mahalanobis distance matching
                            (e.g., c("std_cog_pre", "birthweight", "std_ncog_pre", "year"))
    - seed: Set to 42 for reproducibility (in matched_pairs_randomize call)

  Output:
    - output/matched_pairs_randomized_dataset.dta   (Randomized dataset with Treatment,
                                                     Pair_ID, and Stratum_ID variables)
    - Console output with detailed summary statistics

  Algorithm:
    - Uses same logic as Python implementation
    - Conditional regularization for covariance matrix
    - Greedy matching with pre-calculated distance matrix


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/matched_pairs_randomization.do

  Requirements: Stata (no additional packages required).

  IMPORTANT - Working Directory:
    The script uses relative paths. Simply run the .do file from any location and it will
    automatically detect the correct paths relative to the script location.

  User Parameters (lines 47-51):
    - cat_vars: Variables for outer stratification (e.g., "female race_w")
    - cont_vars: Variables for Mahalanobis distance matching
                 (e.g., "std_cog_pre birthweight std_ncog_pre year")

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/matched_pairs_randomized_dataset.dta   (Randomized dataset with Treatment,
                                                     Pair_ID, and Stratum_ID variables)
    - Console output with detailed summary statistics


##################################################################################################
                              OUTPUT VARIABLES
##################################################################################################

  The randomized dataset includes three key variables:

  Treatment:      Binary indicator (0 = Control, 1 = Treatment)
                  - Randomly assigned within matched pairs
                  - For unpaired units, assigned via Complete Randomization (CRE)

  Pair_ID:        Unique identifier for each matched pair
                  - Non-negative integers (0, 1, 2, ...) for paired units
                  - Value of -1 for unpaired units (those assigned via CRE)

  Stratum_ID:     Identifier for outer strata
                  - Created by combining categorical variables
                  - All matching occurs within strata


##################################################################################################
                              USER CUSTOMIZATION
##################################################################################################

To use these scripts with your own dataset, modify the following marked sections:

1. Data file path:
   - Python:  Line ~314 — input_file = DATA_DIR / "your_dataset.dta"
   - R:       Line ~296 — input_file <- file.path(data_dir, "your_dataset.dta")
   - Stata:   Line ~41  — use "`data_dir'/your_dataset.dta", clear

2. Categorical variables (for outer stratification):
   - Python:  Lines ~320-323 — CATEGORICAL_VARIABLES
   - R:       Lines ~302-305 — CATEGORICAL_VARIABLES
   - Stata:   Lines ~45-47   — local cat_vars

3. Continuous variables (for Mahalanobis distance matching):
   - Python:  Lines ~325-328 — CONTINUOUS_VARIABLES
   - R:       Lines ~307-310 — CONTINUOUS_VARIABLES
   - Stata:   Lines ~49-52   — local cont_vars

4. Random seed (for reproducibility):
   - Python:  Line ~318 — seed=42
   - R:       Line ~318 — seed = 42
   - Stata:   Line ~36  — set seed 42

5. Output file name:
   - Python:  Line ~488 — output_file = OUTPUT_DIR / "your_output.dta"
   - R:       Line ~486 — output_file <- file.path(output_dir, "your_output.dta")
   - Stata:   Line ~583 — save "`output_dir'/your_output.dta", replace

All customization points are marked with "TODO:" comments in the code.


##################################################################################################
                              ALGORITHM DETAILS
##################################################################################################

  Outer Stratification:
    - Creates strata by combining categorical variables (e.g., female × race)
    - Ensures matching only occurs between similar units on discrete characteristics
    - Each stratum is processed independently

  Mahalanobis Distance:
    - Measures similarity between units using continuous covariates
    - Accounts for covariance structure of the variables
    - Formula: sqrt((X_i - X_j)' * Σ^(-1) * (X_i - X_j))
      where Σ is the covariance matrix of continuous variables

  Greedy Matching Algorithm:
    1. Calculate pairwise Mahalanobis distances for all units in stratum
    2. Find the pair with minimum distance
    3. Randomly assign one unit to treatment, the other to control
    4. Remove both units from the pool
    5. Repeat steps 2-4 until fewer than 2 units remain

  Handling Unmatched Units:
    - Strata with odd numbers of observations will have 1 unpaired unit
    - These units cannot be matched (no pair available)
    - Solution: Apply Complete Randomization (CRE) to assign treatment
    - Marked with Pair_ID = -1 to distinguish from paired units


##################################################################################################
                              SUMMARY OUTPUT
##################################################################################################

  The scripts provide detailed output including:
    - Total number of observations
    - Number of matched pairs
    - Number of paired vs unpaired units
    - Treatment vs control assignment counts
    - Summary statistics by stratum:
        * Number of pairs per stratum
        * Treatment/control counts per stratum
        * Number of unpaired units per stratum (if any)

##################################################################################################
