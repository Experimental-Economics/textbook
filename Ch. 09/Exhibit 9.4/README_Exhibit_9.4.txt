##################################################################################################
                        README — Exhibit 9.4 (Chapter 9)
              Simple Rules of Thumb for Sample Size Across Various Pre- and Post-Periods
##################################################################################################

This folder contains code to recreate Exhibit 9.4 from Chapter 9, which provides a practical
lookup table for optimal sample sizes in panel data experiments. The table shows how the
required sample size varies with:

  - Total number of periods (4, 8, or 16)
  - Pre-to-post treatment period ratio (1/4 : 3/4, 1/2 : 1/2, or 3/4 : 1/4)

The exhibit helps researchers quickly determine the appropriate sample size for their panel
data design without complex calculations, using standard power analysis parameters (95%
confidence, 80% power, MDE = 0.5 SD).


##################################################################################################
                              FOLDER STRUCTURE
##################################################################################################

    code/       Scripts in Python, R, and Stata
    data/       (Currently empty - no data required, table is calculated analytically)
    output/     Generated LaTeX table (created automatically when you run the scripts)

All three languages produce the same table. You only need to run ONE of them.
The Python and R scripts auto-detect their own location, so there is no need to manually
set a working directory or edit any file paths.

For Stata: You must manually set the working directory to the code/ folder before running
the script, OR Stata will automatically use the directory of the script when you open it.


##################################################################################################
                              PYTHON
##################################################################################################

  File:     code/Exhibit_9.4.py

  Requirements: Python 3 with pandas.
  If missing, run in your terminal:    pip install pandas

  How to run:
    - From a terminal:    python Exhibit_9.4.py
    - Or open the file in your IDE (VS Code, Spyder, PyCharm, etc.) and run it.

  Output:
    - output/Exhibit_9.4_python.tex   (LaTeX table)

  What it does:
    The script defines a function to calculate optimal sample size using the formula
    n* = 2(t_α/2 + t_β)²σ² / (MDE)² × (N_pre + N_post) / (N_pre × N_post). It then
    loops through three total period values (4, 8, 16) and three pre-to-post ratios
    for each, calculating the optimal sample size for all nine combinations. Results
    are displayed in the console and saved as a LaTeX table.


##################################################################################################
                              R
##################################################################################################

  File:     code/Revised_Exhibit_9.4.R

  Requirements: R with the xtable package.
                The package will be installed automatically if missing.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript Revised_Exhibit_9.4.R

  Output:
    - output/Exhibit_9.4_r.tex   (LaTeX table)

  What it does:
    The script defines a function to calculate optimal sample size using the same
    formula as the Python version. It uses nested loops to generate all combinations
    of total periods and ratios, storing results in a list that is combined into a
    dataframe. The table is displayed in the console and exported to LaTeX using
    the xtable package.


##################################################################################################
                              STATA
##################################################################################################

  File:     code/Exhibit_9.4_Stata.do

  Requirements: Stata with the texsave package (optional).
                The script will check for texsave and provide installation instructions
                if it's missing. The table will still display in the console without it.

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 9/Exhibit 9.4/code"

    Alternatively, when you open the .do file in Stata, the working directory is
    automatically set to the location of that file, so you can simply open and run it.

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).
    - Make sure you are in the code/ directory when running.

  Output:
    - output/Exhibit_9.4_stata.tex   (LaTeX table, if texsave is installed)

  What it does:
    The script defines a Stata program called calculate_n_star that computes optimal
    sample size using the formula. It creates an empty dataset with 9 observations,
    then loops through total periods and ratios, calling the program for each
    combination and storing results. The table is displayed using list and optionally
    saved to LaTeX using texsave (if installed).


##################################################################################################
                              MATHEMATICAL FOUNDATION
##################################################################################################

The optimal sample size formula for panel data designs is:

  n* = 2(t_{α/2} + t_β)² × σ² / MDE² × (N_pre + N_post) / (N_pre × N_post)

  Where:
    n*       = Optimal sample size (number of units)
    N_pre    = Number of pre-treatment periods
    N_post   = Number of post-treatment periods
    MDE      = Minimum detectable effect (in standard deviations)
    σ²       = Variance of the outcome (assumed = 1 when MDE is in SD units)
    t_{α/2}  = Critical value for significance level α/2 (two-tailed)
    t_β      = Critical value for power (1 - β)

  Standard parameters used in this exhibit:
    α        = 0.05 (significance level, two-sided)
    power    = 0.80 (1 - β)
    t_{α/2}  = 1.96 (critical value for α/2 = 0.025)
    t_β      = 0.84 (critical value for β = 0.20)
    σ²       = 1.00 (standardized variance)
    MDE      = 0.5  (half a standard deviation)

  Key insight:
    The formula shows that sample size requirements decrease as both the number of
    pre-treatment and post-treatment periods increase. However, the allocation between
    pre and post periods matters: equal allocation (1/2 : 1/2) minimizes the required
    sample size for a given total number of periods.


##################################################################################################
                              TABLE DESCRIPTION
##################################################################################################

  The table contains 9 rows organized by total periods:

    Total Number of Periods: 4
      - Pre-to-Post Ratio: 1/4 : 3/4  →  n* = [calculated]
      - Pre-to-Post Ratio: 1/2 : 1/2  →  n* = [calculated]
      - Pre-to-Post Ratio: 3/4 : 1/4  →  n* = [calculated]

    Total Number of Periods: 8
      - Pre-to-Post Ratio: 1/4 : 3/4  →  n* = [calculated]
      - Pre-to-Post Ratio: 1/2 : 1/2  →  n* = [calculated]
      - Pre-to-Post Ratio: 3/4 : 1/4  →  n* = [calculated]

    Total Number of Periods: 16
      - Pre-to-Post Ratio: 1/4 : 3/4  →  n* = [calculated]
      - Pre-to-Post Ratio: 1/2 : 1/2  →  n* = [calculated]
      - Pre-to-Post Ratio: 3/4 : 1/4  →  n* = [calculated]

  Interpretation:
    - For a given total number of periods, the 1/2 : 1/2 ratio (equal allocation)
      always produces the smallest required sample size
    - Increasing the total number of periods decreases the required sample size
    - The table provides quick reference values for common experimental designs


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
