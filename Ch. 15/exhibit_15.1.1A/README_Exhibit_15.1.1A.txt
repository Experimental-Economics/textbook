##################################################################################################
                        README — Exhibit 15.1.1A (Chapter 15)
                   PSP as a Function of Number of Replications
##################################################################################################

This folder contains code to recreate Exhibit 15.1.1A from Chapter 15, which visualizes
Post-Study Probability (PSP) under different replication scenarios.

The exhibit generates a two-panel figure showing how PSP changes with the number of successful
replications (out of 10 attempts) for four replication types:

  - Unbiased replication      (no bias in either direction, A15.1.2)
  - Adversarial replication   (replicators skeptical, try to disprove findings, A15.1.4)
  - Sympathetic replication   (replicators supportive, try to confirm findings, A15.1.3)
  - Heterogeneous replication (mixture of unbiased, adversarial, and sympathetic, A15.1.5)

The left panel shows results for β = 0.3 (high power), and the right panel for β = 0.8 (low power).


##################################################################################################
                              FOLDER STRUCTURE
##################################################################################################

    code/       Scripts in Python, R, and Stata
    data/       (Currently empty - no data required for this exhibit)
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce the same figure. You only need to run ONE of them.
The Python and R scripts auto-detect their own location, so there is no need to manually
set a working directory or edit any file paths.

For Stata: You must manually set the working directory to the code/ folder before running
the script, OR Stata will automatically use the directory of the script when you open it.


##################################################################################################
                              PYTHON
##################################################################################################

  File:     code/Exhbit15.1.1A.py

  Requirements: Python 3 with numpy, scipy, and matplotlib.
  If missing, run in your terminal:    pip install numpy scipy matplotlib

  How to run:
    - From a terminal:    python Exhbit15.1.1A.py
    - Or open the file in your IDE (VS Code, Spyder, PyCharm, etc.) and run it.

  Output:
    - output/Exhibit15.1.1A.png   (two-panel figure, PNG format)

  What it does:
    The script defines four functions to calculate PSP under different replication
    scenarios, then generates a two-panel matplotlib figure with custom styling to
    match the published exhibit. The plot shows PSP on the y-axis (0 to 1) versus
    the number of successful replications (1 to 10) on the x-axis.


##################################################################################################
                              R
##################################################################################################

  File:     code/Exhbit15.1.1A.R

  Requirements: R (no additional packages needed - uses base R graphics)

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript Exhbit15.1.1A.R

  Output:
    - output/Exhibit15.1.1A_R.png   (two-panel figure, PNG format)

  What it does:
    The script defines four functions to calculate PSP under different replication
    scenarios, then uses base R graphics (par, plot, lines, legend) to create a
    two-panel figure. The script uses png() device for high-resolution output
    (300 dpi).


##################################################################################################
                              STATA
##################################################################################################

  File:     code/Exhibit15.1.1A.do

  Requirements: Stata (no additional packages needed).

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 15/exhibit_15.1.1A/code"

    Alternatively, when you open the .do file in Stata, the working directory is
    automatically set to the location of that file, so you can simply open and run it.

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).
    - Make sure you are in the code/ directory when running.

  Output:
    - output/Exhibit15_1_1A_Stata.png   (two-panel figure, PNG format)

  What it does:
    The script defines four Stata programs to calculate PSP under different replication
    scenarios. It creates the data in memory (10 observations for r = 1 to 10), computes
    PSP values for all scenarios and both beta values (0.3 and 0.8), then uses graph twoway
    with connected plots to create each panel. The two panels are combined using graph combine.


##################################################################################################
                              TECHNICAL DETAILS
##################################################################################################

  Parameters (consistent across all implementations):
    - alpha = 0.05    (significance level)
    - n = 10          (total number of replication attempts)
    - v = 0.3         (sympathetic bias parameter)
    - omega = 0.4     (adversarial bias parameter)
    - pi = 0.5        (prior probability that hypothesis is true)
    - phi = 0.33      (fraction of sympathetic replicators in heterogeneous case)
    - psi = 0.33      (fraction of adversarial replicators in heterogeneous case)
    - beta = 0.3 or 0.8 (Type II error rate, varies by panel)

  Mathematical foundation:
    The PSP calculations are based on Bayesian updating using binomial probabilities
    under true and false hypotheses. Different replication types modify the success
    probabilities:
    - Unbiased: standard binomial with power (1-β) and Type I error (α)
    - Sympathetic: increases success probability by adding bias term v
    - Adversarial: decreases success probability by factor (1-ω)
    - Heterogeneous: weighted mixture of all three types

  References:
    - See Chapter 15 and Appendix A15.1 for detailed derivations
    - Equations A15.1.2 (unbiased), A15.1.3 (sympathetic), A15.1.4 (adversarial),
      and A15.1.5 (heterogeneous)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################