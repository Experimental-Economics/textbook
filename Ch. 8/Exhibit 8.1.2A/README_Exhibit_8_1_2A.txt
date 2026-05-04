##################################################################################################
                        README — Exhibit 8.1.2A (Chapter 8)
            Baron and Kenny Mediation Analysis: Parental Beliefs
##################################################################################################

This folder contains code to recreate Exhibit 8.1.2A from Chapter 8. The scripts conduct
mediation analysis using the Baron and Kenny framework to examine the relationship between
home visiting programs, parental beliefs, and outcomes (parental investments and child outcomes).

Implements the Baron and Kenny approach with three regression equations:
  - M_i = α + λ_dm*D_i + X_i'δ + v_i                    (A8.1.4)
  - Y_i = θ + λ_dy*D_i + X_i'δ + ω_i                    (A8.1.5)
  - Y_i = μ + λ_dy*D_i + λ_my*M_i + X_i'δ + ε_i        (A8.1.6)

where:
  - D_i: Treatment indicator (Home Visiting Program)
  - M_i: Mediator (Parental Beliefs)
  - Y_i: Outcome (Parental Investments or Child Outcome)

Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       TMP (Tulsa Maternal Parenting) dataset
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths (except Stata - see below).


##################################################################################################
                                    DATA
##################################################################################################

  File:     data/TMPdata_de-identified.dta
            data/TMPdata_de-identified.csv

  This dataset contains de-identified data from the Tulsa Maternal Parenting (TMP) study.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/Exhibit_8.1.2A.py

  Requirements: Python 3 with numpy, pandas, scipy, and statsmodels.
  If missing, run in your terminal:    pip install numpy pandas scipy statsmodels

  How to run:
    - From a terminal:    python Exhibit_8.1.2A.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/Exhibit_8_1_2A_python.tex   (LaTeX table)


##################################################################################################
                                       R
##################################################################################################
  File:     code/exhibit_8_1_2A.R

  Requirements: R with haven package.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript exhibit_8_1_2A.R

  Output:
    - output/Exhibit_8_1_2A_r.tex   (LaTeX table)

  Note: There is also an Appendix_8.1.R file that implements additional mediation methods
  using the mediation package with bootstrapping. This is a more advanced implementation.


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/exhibit_8_1_2A.do

  Requirements: Stata with estout package.
  If missing, run in Stata:    ssc install estout

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 8/Exhibit 8.1.2A/code"

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/Exhibit_8_1_2A_stata.tex   (LaTeX table)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
