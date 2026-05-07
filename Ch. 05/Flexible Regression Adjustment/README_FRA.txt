##################################################################################################
                        README — Flexible Regression Adjustment (Chapter 5)
                  Replication of Table 7: Variance Reduction for OHIE
##################################################################################################

This folder contains code to replicate Table 7 from Chapter 5, which compares three
estimators on Oregon Health Insurance Experiment (OHIE) data (Finkelstein et al., 2016):

  SM  = Subsample Means (simple difference in means, no covariates)
  LRA = Linear Regression Adjustment (OLS-based cross-fitting)
  FRA = Flexible Regression Adjustment (Random Forest-based cross-fitting)

For each estimator, the scripts compute:

  - Reduced form:     Impact of lottery assignment (W) on ER visits (Y)
  - First stage:      Impact of lottery assignment (W) on Medicaid take-up (D)
  - LATE:             Local Average Treatment Effect via Wald/IV estimator

The key idea behind regression adjustment is to use covariates (pre-treatment ER visit
counts, demographics, etc.) to reduce the variance of the treatment effect estimate.
Cross-fitting (sample splitting) ensures valid inference even when using flexible ML
methods like Random Forests.

Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       OHIE dataset (OHIE_data.csv)
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths.


##################################################################################################
                                    DATA
##################################################################################################

  File:     data/OHIE_data.csv

  This CSV contains individual-level data from the Oregon Health Insurance Experiment:

    Y   = ER visit indicator (TRUE/FALSE)
    D   = Medicaid take-up (0/1)
    W   = Treatment assignment from the lottery (0/1)
    Remaining columns = Pre-treatment covariates (prior ER visits, demographics, etc.)

  Observations with missing values are dropped at runtime (the scripts handle this
  automatically). After cleaning, the sample has approximately 24,600 observations.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/ch5_FRA.py

  Requirements: Python 3 with numpy, pandas, and scikit-learn.
  If missing, run in your terminal:    pip install numpy pandas scikit-learn

  How to run:
    - From a terminal:    python ch5_FRA.py
    - Or open the file in your IDE (VS Code, Spyder, PyCharm, etc.) and run it.

  What it does:
    1. Defines the FRA cross-fitting functions (FRA, FRA_ATE, FRA_LATE) and simple
       difference-in-means estimators (SM_ATE, SM_LATE).
    2. Loads the OHIE data, runs all three estimators (SM, LRA, FRA), and prints
       a formatted Table 7 to the console.
    3. Exports the table as LaTeX and HTML.

  Output:
    - output/table_7_OHIE.tex   (LaTeX table)
    - output/table_7_OHIE.html  (HTML table — open in any browser)

  Note: The Random Forest estimator may take a minute or two to run depending on
  your machine.


##################################################################################################
                                       R
##################################################################################################
  File:     code/ch5_FRA.R

  Requirements: R with dplyr, readr, and randomForest.
  All three are installed automatically if missing.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript ch5_FRA.R

  What it does:
    1. Defines the FRA cross-fitting functions (FRA, FRA_ATE, FRA_LATE) and simple
       difference-in-means estimators (SM_ATE, SM_LATE).
    2. Loads the OHIE data, runs all three estimators (SM, LRA, FRA), and prints
       a formatted Table 7 to the console.
    3. Exports the table as LaTeX and HTML.

  Output:
    - output/table_7_OHIE.tex   (LaTeX table)
    - output/table_7_OHIE.html  (HTML table — open in any browser)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/ch5_FRA.do

  Requirements: Stata 16 or later. The "rforest" package is required for the Random
  Forest estimator and is installed automatically if missing (via ssc install).

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  What it does:
    1. Defines the fra_run program (embedded in the do-file — no external .ado
       file is needed) that performs cross-fitted regression adjustment.
    2. Loads the OHIE data, runs all three estimators (SM, LRA, FRA), and prints
       a formatted Table 7 to the console.
    3. Exports the table as LaTeX and HTML.

  Output:
    - output/table_7_OHIE.tex   (LaTeX table)
    - output/table_7_OHIE.html  (HTML table — open in any browser)

  Note: The .ado file (ch5_FRA.ado) in the code/ folder is a standalone version of
  the FRA program for general use, but it is NOT required to run ch5_FRA.do.
  The do-file is fully self-contained.


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
