##################################################################################################
                        README — Exhibit 12.1.2A (Chapter 12)
                        ATEs and Horowitz and Manski Bounds
##################################################################################################

This folder contains code to recreate Exhibit 12.1.2A from Chapter 12. The scripts compare
the default model with upper and lower bounds from Horowitz & Manski (2000).

Column 1: Default model (no attrition adjustment)
Column 2: Upper bound (best-case scenario for treatment effect)
Column 3: Lower bound (worst-case scenario for treatment effect)

Reference: Horowitz, J. L., & Manski, C. F. (2000). Nonparametric Analysis of Randomized
Experiments with Missing Covariate and Outcome Data. Journal of the American Statistical
Association, 95(449), 77-84.

Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       CHECC dataset files
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths (except Stata - see below).


##################################################################################################
                                    DATA
##################################################################################################

  IMPORTANT NOTE: The original CHECC data (unique_data_clean_main.dta) is NOT included
  in this folder but can be requested. The dataset reference is maintained in the code
  for compatibility.

  File:     data/unique_data_clean_main_synthetic.dta  (synthetic data for testing)
            data/unique_data_clean_main.dta            (actual CHECC data - NOT INCLUDED)

  By default, scripts use the synthetic data. To use the actual CHECC data (if obtained),
  edit the script to comment/uncomment the appropriate line as indicated in the code comments.

  NOTE: Because synthetic data is used by default, the produced graphs and functions will
  NOT match the textbook exactly. Results will approximate the patterns but differ in
  specific values.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/exhibit_12_1_2A.py

  Requirements: Python 3 with pandas and statsmodels.
  If missing, run in your terminal:    pip install pandas statsmodels

  How to run:
    - From a terminal:    python exhibit_12_1_2A.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/Exhibit_12_1_2A_python.tex   (LaTeX table)


##################################################################################################
                                       R
##################################################################################################
  File:     code/exhibit_12_1_2A.R

  Requirements: R with tidyverse, haven, and xtable.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript exhibit_12_1_2A.R

  Output:
    - output/Exhibit_12_1_2A_r.tex   (LaTeX table)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/exhibit_12_1_2A.do

  Requirements: Stata with estout package.
  If missing, run in Stata:    ssc install estout

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 12/Exhibit 12.1.2A/code"

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/Exhibit_12_1_2A_stata.tex   (LaTeX table)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
