##################################################################################################
                  README — Optimal Matched-Pairs Randomization from Pilot Study
                         Based on Bai (2022) - Minimizing Mean-Squared Error
##################################################################################################

This folder contains code to implement OPTIMAL matched-pairs randomization using a pilot study
to estimate expected outcomes. This approach minimizes mean-squared error by pairing units with
similar predicted outcomes, improving upon standard greedy matching methods.

The key insight: Use a pilot experiment to estimate g_i = E[Y_i(1) + Y_i(0) | X_i] for each
unit, then match units with similar g_i values. This minimizes the variance of treatment effect
estimates.

Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       Input dataset files
    output/     Generated output files (created automatically when you run the scripts)

Python, R, and Stata all use identical algorithms and will produce the same matching pairs
(within random variation due to different RNG implementations). You only need to run ONE.
The scripts auto-detect their own location, so there is no need to manually set a working
directory or edit any file paths.


##################################################################################################
                                  ALGORITHM OVERVIEW
##################################################################################################

  Steps:
    1. Load pilot data with Treatment and Outcome variables
    2. Run regression on pilot: Outcome ~ Treatment + Controls
    3. For each unit in main sample:
       - Predict outcome under D=0 (control): g_0
       - Predict outcome under D=1 (treatment): g_1
       - Calculate g_hat = g_0 + g_1
    4. Sort all units by g_hat in increasing order
    5. Create pairs from adjacent units in sorted list
    6. Within each pair, randomly assign one to treatment, one to control


##################################################################################################
                                  REQUIRED INPUT FILES
##################################################################################################

  1. Pilot Sample (with Treatment and Outcome)
     File: output/pilot_sample_with_treatment_and_outcome.dta

     Must contain:
       - Treatment variable (0/1 or binary)
       - Outcome variable (continuous)
       - All control variables you want to use for prediction

     This file is the result of a pilot experiment where treatment was randomly assigned
     and outcomes were measured. The regression on this data estimates the relationship
     between covariates and outcomes.

  2. Main Sample (without Treatment)
     File: output/main_sample.dta

     Must contain:
       - All control variables (same as in pilot)
       - NO Treatment variable (will be assigned by this script)

     This is the larger sample for which you want to assign treatment using optimal matching.


##################################################################################################
                                USER CUSTOMIZATION
##################################################################################################

All three scripts have clearly marked "TODO" sections. You need to modify:

  1. CONTROL_VARS (Lines ~38-41)
     List of control variables to use in g_i estimation
     Example (Python):  CONTROL_VARS = ['female', 'race_w', 'birthweight', 'std_ncog_pre', 'year']
     Example (R):       control_vars <- c("female", "race_w", "birthweight", "std_ncog_pre", "year")
     Example (Stata):   local CONTROL_VARS "female race_w birthweight std_ncog_pre year"

     ⚠️ IMPORTANT: These must match the control variables used in your pilot regression
     ⚠️ All variables must exist in both pilot and main sample data

  2. Pilot Data File Path (Lines ~48-56)
     Default: output/pilot_sample_with_treatment_and_outcome.dta
     Change if your pilot data is stored elsewhere

  3. Main Sample File Path (Lines ~69-81)
     Default: output/main_sample.dta
     Change if your main sample data is stored elsewhere

  4. Output File Name (Lines ~169-217)
     Default: output/optimal_matched_main_sample.dta
     Change if you want a different output filename

  5. Random Seed (Lines ~35-36)
     Default: 42
     Change to any integer for different randomization results

  6. Regression Specification (Lines ~61-69)
     Default: Linear regression with Treatment + Controls
     You can modify the regression to include:
       - Interaction effects (e.g., female × race_w)
       - Polynomial terms (e.g., birthweight²)
       - Other transformations as needed
     See comments in scripts for examples in each language


##################################################################################################
                                       Python
##################################################################################################
  File:     code/optimal_matching_from_pilot.py

  Requirements: Python 3 with numpy, pandas, and statsmodels.
  If missing, run:    pip install numpy pandas statsmodels

  How to run:
    - From terminal:    python optimal_matching_from_pilot.py
    - Or open in your IDE (VS Code, PyCharm, etc.) and run

  Output:
    - output/optimal_matched_main_sample.dta (with Treatment, Pair_ID, g_hat, g_0, g_1)
    - Console output with detailed statistics including:
        * Pilot regression R²
        * g_hat statistics (mean, std, min, max)
        * Number of pairs created
        * Within-pair g_hat differences
        * Comparison to random pairing (~99.6% reduction)


##################################################################################################
                                          R
##################################################################################################
  File:     code/optimal_matching_from_pilot.R

  Requirements: R with tidyverse and haven packages.
  If missing, run:    install.packages(c("tidyverse", "haven"))

  How to run:
    - From R console:    source("code/optimal_matching_from_pilot.R")
    - From terminal:     Rscript code/optimal_matching_from_pilot.R
    - Or open in RStudio and click "Source"

  Output:
    - output/optimal_matched_main_sample.dta (with Treatment, Pair_ID, g_hat, g_0, g_1)
    - Console output with detailed statistics


##################################################################################################
                                        Stata
##################################################################################################
  File:     code/optimal_matching_from_pilot.do

  Requirements: Stata (no additional packages required).

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run)
    - The script uses relative paths and will auto-detect correct locations

  Output:
    - output/optimal_matched_main_sample.dta (with Treatment, Pair_ID, g_hat, g_0, g_1)
    - Console output with detailed statistics


##################################################################################################
                                   OUTPUT VARIABLES
##################################################################################################

  The output file (optimal_matched_main_sample.dta) contains all original variables plus:

  Treatment:      Binary indicator (0 = Control, 1 = Treatment)
                  - Randomly assigned within matched pairs
                  - For unpaired unit (if odd N), assigned via Complete Randomization (CRE)

  Pair_ID:        Unique identifier for each matched pair
                  - Non-negative integers (0, 1, 2, ...) for paired units
                  - Value of -1 for unpaired unit (if N is odd)

  g_hat:          Estimated g_i = E[Y_i(1) + Y_i(0) | X_i]
                  - Sum of predicted outcomes under both treatment conditions
                  - Used for sorting and creating optimal pairs

  g_0:            Predicted outcome under D=0 (control condition)
                  - E[Y_i(0) | X_i]

  g_1:            Predicted outcome under D=1 (treatment condition)
                  - E[Y_i(1) | X_i]


##################################################################################################
                                   EXAMPLE OUTPUT
##################################################################################################

  Typical results (from test with N=900):

    PILOT REGRESSION RESULTS
    --------------------------------------------------------------------------------
      R-squared:            0.3706
      Adj. R-squared:       0.3300
      Treatment coef:        1.0200
      Treatment p-value:     0.0000

    MATCHED PAIRS STATISTICS
    --------------------------------------------------------------------------------
      Total units:          900
      Matched pairs:        450
      Unpaired units:       0
      Pairing rate:         100.0%

    WITHIN-PAIR g_hat DIFFERENCES
    --------------------------------------------------------------------------------
      Mean:                 0.004951
      Median:               0.002406
      Max:                  0.098163
      Min:                  0.000002

    COMPARISON TO RANDOM PAIRING
    --------------------------------------------------------------------------------
      Expected diff (random):  1.290123
      Achieved diff (optimal): 0.004951
      Reduction:                  99.6%

  This shows the optimal matching achieves 99.6% reduction in within-pair differences
  compared to random pairing!


##################################################################################################