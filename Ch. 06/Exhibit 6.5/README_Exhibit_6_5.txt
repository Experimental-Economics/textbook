##################################################################################################
                        README — Exhibit 6.5 (Chapter 6)
            Covariate Balance with CRE in Lalonde (1986; NSW)
##################################################################################################

This folder contains code to recreate Exhibit 6.5 from Chapter 6. The scripts create a balance
table comparing baseline characteristics across treatment and control groups in the Lalonde
(1986; NSW) dataset using a Completely Randomized Experiment (CRE).

Column 1: Covariate name and type (proportion vs. mean)
Column 2: Control group mean (SD)
Column 3: Treatment group mean (SD)
Column 4: Difference of means with p-value

Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       Lalonde (NSW) dataset
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths (except Stata - see below).


##################################################################################################
                                    DATA
##################################################################################################

  File:     data/lalonde2.dta

  This file contains data from the Lalonde (1986) National Supported Work (NSW) demonstration.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/exhibit_6_5.py

  Requirements: Python 3 with numpy, pandas, and scipy.
  If missing, run in your terminal:    pip install numpy pandas scipy

  How to run:
    - From a terminal:    python exhibit_6_5.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/Exhibit_6_5_python.tex   (LaTeX table)


##################################################################################################
                                       R
##################################################################################################
  File:     code/exhibit_6_5.R

  Requirements: R with tidyverse, haven, and xtable.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript exhibit_6_5.R

  Output:
    - output/Exhibit_6_5_r.tex   (LaTeX table)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/exhibit_6_5.do

  Requirements: Stata with estout package.
  If missing, run in Stata:    ssc install estout

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 6/Exhibit 6.5/code"

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/Exhibit_6_5_stata.tex   (LaTeX table)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
