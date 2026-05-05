##################################################################################################
                        README — Exhibit 5.7 (Chapter 5)
              Multiple Hypothesis Testing (MHT) and Statistical Power
##################################################################################################

This folder contains code to recreate Exhibit 5.7 from Chapter 5. The scripts compute
the required sample size (per group) for 1–10 hypothesis tests under three Bonferroni-
based correction strategies:

  - No Adjustment:         standard alpha and power
  - FWE Adjustment:        alpha / k  (controls family-wise error rate)
  - FWE + FWP Adjustment:  alpha / k  and  power^(1/k)
                           (controls both family-wise error and power)

The output is a line plot showing how sample size grows with the number of hypotheses
when using an MDE of 0.5 standard deviations, alpha = 0.05, and 80% power.

Folder structure:

    code/       Scripts in Python, R, and Stata
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/Exhibit_5.7.py

  Requirements: Python 3 with numpy, matplotlib, and statsmodels.
  If missing, run in your terminal:    pip install numpy matplotlib statsmodels

  How to run:
    - From a terminal:    python Exhibit_5.7.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/exhibit_5.7.png  (line plot)


##################################################################################################
                                       R
##################################################################################################
  File:     code/Exhibit_5.7.R

  Requirements: R with ggplot2 and pwr (installed automatically if missing).

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript Exhibit_5.7.R

  Output:
    - output/exhibit_5.7.png  (line plot)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/Exhibit_5.7.do

  Requirements: Stata (no additional packages needed).

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/exhibit_5.7.png  (line plot)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .png files    Open with any image viewer or web browser.

##################################################################################################
