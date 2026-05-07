##################################################################################################
                        README — Exhibit 5.6 (Chapter 5)
           Simple Rules of Thumb for Sample Size for Clustered Units
##################################################################################################

This folder contains code to recreate Exhibit 5.6 from Chapter 5. The scripts compute
the optimal total number of participants (n*) and optimal number of clusters (k*) for
different values of the intra-cluster correlation coefficient (rho) and cluster sizes
(m = 10, 30) using Equation 5.12 from the textbook.

Folder structure:

    code/       Scripts in Python, R, and Stata
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/Exhibit_5.6.py

  Requirements: Python 3 with scipy.
  If missing, run in your terminal:    pip install scipy

  How to run:
    - From a terminal:    python Exhibit_5.6.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/exhibit_5.6.tex   (LaTeX table)
    - output/exhibit_5.6.html  (HTML table — open in any browser)


##################################################################################################
                                       R
##################################################################################################
  File:     code/Exhibit_5.6.R

  Requirements: R (no additional packages needed).

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript Exhibit_5.6.R

  Output:
    - output/exhibit_5.6.tex   (LaTeX table)
    - output/exhibit_5.6.html  (HTML table — open in any browser)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/Exhibit_5.6.do

  Requirements: Stata (no additional packages needed).

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/exhibit_5.6.tex   (LaTeX table)
    - output/exhibit_5.6.html  (HTML table — open in any browser)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
