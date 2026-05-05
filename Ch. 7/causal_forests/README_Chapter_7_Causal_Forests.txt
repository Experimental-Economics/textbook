##################################################################################################
                        README — Chapter 7: Causal Forests
                      Heterogeneous Treatment Effects (U-Program)
##################################################################################################

This folder contains code to estimate Conditional Average Treatment Effects (CATEs) using
causal forests for Chapter 7. The analysis examines the heterogeneous effects of Math
curriculum allocation on disciplinary infractions during the 16-17 academic year.

The causal forest procedure estimates individual-level treatment effects theta(X_i) by:
  1. Drawing subsamples from the data
  2. Splitting each subsample into training and estimation samples (honest splitting)
  3. Using the training sample to build the tree structure
  4. Using the estimation sample to calculate treatment effects within each leaf
  5. Averaging predictions across all trees (2000 trees)

Output: Cumulative distribution function (CDF) plots showing the distribution of estimated
individual treatment effects across all students.

Folder structure:

    code/       Scripts in Python and R (Stata implementation unavailable)
    data/       U-Program dataset (u_program_data.csv)
    output/     Generated PNG plots (created automatically when you run the scripts)


##################################################################################################
                                    DATA
##################################################################################################

  File:     data/u_program_data.csv

  Contains U-Program data with:
    - Pre-treatment characteristics (ScanQuest scores, demographics, school variables)
    - Treatment assignment (Math, control, or other curricula)
    - Post-treatment outcomes (disciplinary infractions by quarter)

  The scripts filter to Math vs. control groups and remove observations with >5% missing data.
  Complete case analysis: 478 out of 504 observations are used.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/ch7_causal_forest_u_program.py

  Algorithm: Generalized Random Forests via econml.grf.CausalForest
    - Implements the GRF algorithm from Athey, Tibshirani, and Wager (2019)
    - SAME algorithm as R's grf package
    - Solves local moment equation: E[(Y - <theta(x), T> - beta(x)) (T;1) | X=x] = 0
    - Uses honest splitting (50/50 train/estimation split within each tree)
    - Builds 2000 trees with 50% subsampling per tree
    - Results should be comparable to R implementation

  Requirements: Python 3 with pandas, numpy, matplotlib, econml, and statsmodels.
  If missing, run in your terminal:
      pip install pandas numpy matplotlib econml statsmodels

  How to run:
    - From a terminal:    python ch7_causal_forest_u_program.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/ch7_causal_forest_cate_cumulative_py.png


##################################################################################################
                                       R
##################################################################################################
  File:     code/ch7_causal_forest_u_program.R

  Algorithm: Generalized Random Forests via grf::causal_forest
    - Original implementation by Athey, Tibshirani, and Wager (2019)
    - Uses honest splitting with 50% sample fraction per tree
    - Builds 2000 trees by default
    - This is the canonical reference implementation

  Requirements: R with tidyverse, readr, and grf packages.
  If missing, run in R:
      install.packages(c("tidyverse", "readr", "grf"))

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript ch7_causal_forest_u_program.R

  Output:
    - output/ch7_causal_forest_cate_cumulative_r.png


##################################################################################################
                                     Stata
##################################################################################################

  STATUS: Stata implementation is NOT available for this analysis.

##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  Both scripts generate PNG image files showing the cumulative distribution function of
  estimated individual treatment effects (CATEs).

  - .png files    Open with any image viewer or web browser.
                  The plot shows:
                    X-axis: CATE (Conditional Average Treatment Effect)
                    Y-axis: Cumulative Relative Frequency
