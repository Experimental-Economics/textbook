##################################################################################################
                        README — Exhibit 5.3 (Chapter 5)
           Simple Rules of Thumb for Sample Size by Minimum Detectable Effect
##################################################################################################

This folder contains code to recreate Exhibit 5.3 from Chapter 5 for two types of outcomes:

  - Continuous outcomes  -->  Final_Codes/Ch. 5/Exhibit 5.3/Continuous/
  - Binary outcomes      -->  Final_Codes/Ch. 5/Exhibit 5.3/Binary/

Each subfolder has the same structure:

    code/       Scripts in Python, R, and Stata
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths.


##################################################################################################
                              CONTINUOUS OUTCOMES
##################################################################################################

The continuous-outcome scripts compute the minimum sample size per group using Equation 5.8:

    n = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2

They output a LaTeX table (.tex) and a styled HTML table (.html) to the output/ folder.

--------------------------
  Python
--------------------------
  File:     Continuous/code/ch5_exh_5.3_Continuous_Python.py

  Requirements: Python 3 with scipy and pandas.
  If missing, run in your terminal:    pip install scipy pandas

  How to run:
    - From a terminal:    python ch5_exh_5.3_Continuous_Python.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - Continuous/output/exhibit_5.3.tex   (LaTeX table)
    - Continuous/output/exhibit_5.3.html  (HTML table — open in any browser)

--------------------------
  R
--------------------------
  File:     Continuous/code/ch5_exh_5.3_Continuous_R.R

  Requirements: R with the MASS package (installed automatically if missing).

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript ch5_exh_5.3_Continuous_R.R

  Output:
    - Continuous/output/exhibit_5.3.tex   (LaTeX table)
    - Continuous/output/exhibit_5.3.html  (HTML table — open in any browser)

--------------------------
  Stata
--------------------------
  File:     Continuous/code/ch5_exh_5.3_Continuous_Stata.do

  Requirements: Stata (no additional packages needed).

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - Continuous/output/exhibit_5.3.tex   (LaTeX table)
    - Continuous/output/exhibit_5.3.html  (HTML table — open in any browser)


##################################################################################################
                                BINARY OUTCOMES
##################################################################################################

The binary-outcome scripts compute the minimum sample size per group using Equation 5.9,
which accounts for the variance of binary proportions. Unlike the continuous case, sample
size depends on both the MDE level and p-bar (the average of the control and treatment
proportions). The scripts produce two plots: a line graph and a heatmap.

--------------------------
  Python
--------------------------
  File:     Binary/code/ch5_exh_5.3_Binary_Python.py

  Requirements: Python 3 with numpy, pandas, scipy, and matplotlib.
  If missing, run in your terminal:    pip install numpy pandas scipy matplotlib

  How to run:
    - From a terminal:    python ch5_exh_5.3_Binary_Python.py
    - Or open the file in your IDE and run it.

  Output:
    - Binary/output/lineplot_exh5.3_binary.pdf   (line graph)
    - Binary/output/heatmap_exh5.3_binary.pdf    (heatmap)

--------------------------
  R
--------------------------
  File:     Binary/code/ch5_exh_5.3_Binary_R.R

  Requirements: R with ggplot2, dplyr, latex2exp, scales, and stringr
                (all installed automatically if missing).

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript ch5_exh_5.3_Binary_R.R

  Output:
    - Binary/output/lineplot_exh5.3_binary.pdf   (line graph)
    - Binary/output/heatmap_exh5.3_binary.pdf    (heatmap)

--------------------------
  Stata
--------------------------
  File:     Binary/code/ch5_exh_5.3_Binary_Stata.do

  Requirements: Stata (no additional packages needed).

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - Binary/output/lineplot_exh5.3_binary.pdf   (line graph)
    - Binary/output/heatmap_exh5.3_binary.pdf    (heatmap)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
