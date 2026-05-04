##################################################################################################
                        README — Exhibit 12.1.7A (Chapter 12)
                            IPW Model Outcomes
##################################################################################################

This folder contains code to recreate Exhibit 12.1.7A from Chapter 12. The scripts visualize
the density distribution of cognitive scores using Inverse Probability Weighting (IPW) to
adjust for differential attrition.

This plot shows how the outcome distributions change when we weight observations by the
inverse of their predicted probability of response, conditional on baseline covariates.
This reweighting adjusts for selective attrition.

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
  File:     code/exhibit_12_1_7A.py

  Requirements: Python 3 with pandas, matplotlib, seaborn, and statsmodels.
  If missing, run in your terminal:    pip install pandas matplotlib seaborn statsmodels

  How to run:
    - From a terminal:    python exhibit_12_1_7A.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/exhibit_12_1_7A_ipw_model_outcomes.png   (kernel density plot)


##################################################################################################
                                       R
##################################################################################################
  File:     code/exhibit_12_1_7A.R

  Requirements: R with tidyverse, haven, and ggplot2.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript exhibit_12_1_7A.R

  Output:
    - output/exhibit_12_1_7A_ipw_model_outcomes.png   (kernel density plot)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/exhibit_12_1_7A.do

  Requirements: Stata (no additional packages needed).

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 12/Exhibit 12.1.7A/code"

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/exhibit_12_1_7A_ipw_model_outcomes.png   (kernel density plot)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
