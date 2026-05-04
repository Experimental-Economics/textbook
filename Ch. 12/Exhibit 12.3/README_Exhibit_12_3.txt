##################################################################################################
                        README — Exhibit 12.3 (Chapter 12)
                    Selective Attrition Tests for CHECC Data
##################################################################################################

This folder contains code to recreate Exhibit 12.3 from Chapter 12. The scripts test whether
attrition is selectively related to baseline covariates (demographics). Extends Exhibit 12.2
by examining specific demographic variables instead of outcomes.

Methodology: Regress each baseline covariate on four group indicators:
  - π11: treatment × respond
  - π01: control × respond
  - π10: treatment × attrit
  - π00: control × attrit

Covariates tested: female, race_w (white), hl_eng_span (Spanish), birthweight

Hypothesis tests:
  H0^12.2: π10 = π00 & π11 = π01 (attrition same across treatment/control)
  H0^12.3: π10 = π00 = π11 = π01 (all groups have same covariate means)

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
  File:     code/exhibit_12_3.py

  Requirements: Python 3 with pandas and statsmodels.
  If missing, run in your terminal:    pip install pandas statsmodels

  How to run:
    - From a terminal:    python exhibit_12_3.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/Exhibit_12_3_python.tex   (LaTeX table)


##################################################################################################
                                       R
##################################################################################################
  File:     code/exhibit_12_3.R

  Requirements: R with tidyverse, haven, and xtable.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript exhibit_12_3.R

  Output:
    - output/Exhibit_12_3_r.tex   (LaTeX table)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/exhibit_12_3.do

  Requirements: Stata with estout package.
  If missing, run in Stata:    ssc install estout

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 12/Exhibit 12.3/code"

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/Exhibit_12_3_stata.tex   (LaTeX table)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
