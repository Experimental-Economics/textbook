##################################################################################################
                        README — PSP Tables and Figures (Chapter 15)
                        Post-Study Probability (PSP) Analysis Tables
##################################################################################################

This folder contains code to generate multiple PSP tables from Chapter 15. The scripts create
comprehensive LaTeX tables showing how Post-Study Probability (PSP) varies across different
parameter combinations including:

  - Prior probabilities (π)
  - Statistical power levels (1 - β)
  - Significance levels (α)
  - Number of tests/replications
  - Distance from the null hypothesis

The following exhibits are generated:

  - EXHIBIT 15.2   PSP Across Different Priors
  - EXHIBIT 15.3   PSP Changes with Power and Priors
  - EXHIBIT 15.4   PSP Across Different Levels of Significance, Power, and Priors
  - EXHIBIT 15.5   PSP With and Without a Statistically Significant Finding
  - EXHIBIT 15.6   PSP Across Different Power, Stat Sig Level, Prior, and Number of Tests
  - EXHIBIT 15.8   PSP with Various Distance Levels


##################################################################################################
                              FOLDER STRUCTURE
##################################################################################################

    code/       Scripts in Python, R, and Stata
    data/       (Currently empty - no data required, all tables are calculated analytically)
    output/     Generated LaTeX tables (created automatically when you run the scripts)

All three languages produce the same tables. You only need to run ONE of them.
The Python and R scripts auto-detect their own location, so there is no need to manually
set a working directory or edit any file paths.

For Stata: You must manually set the working directory to the code/ folder before running
the script, OR Stata will automatically use the directory of the script when you open it.


##################################################################################################
                              PYTHON
##################################################################################################

  File:     code/Chapter 15.py

  Requirements: Python 3 with numpy, pandas, scipy, and tabulate.
  If missing, run in your terminal:    pip install numpy pandas scipy tabulate

  How to run:
    - From a terminal:    python "Chapter 15.py"
    - Or open the file in your IDE (VS Code, Spyder, PyCharm, etc.) and run it.

  Output:
    The script generates multiple LaTeX (.tex) files in the output/ folder:
    - Exhibit_15_2_python.tex
    - Exhibit_15_3_python.tex
    - Exhibit_15_4_alpha_0.05_python.tex
    - Exhibit_15_4_alpha_0.005_python.tex
    - Exhibit_15_5_reject_NULL_python.tex
    - Exhibit_15_5_NULL_python.tex
    - Exhibit_15_6_power_0.80_python.tex
    - Exhibit_15_6_power_0.50_python.tex
    - Exhibit_15_8_distance_0.00_python.tex
    - Exhibit_15_8_distance_0.10_python.tex
    - Exhibit_15_8_distance_0.25_python.tex
    - Exhibit_15_8_distance_0.50_python.tex

  What it does:
    The script defines functions for each exhibit that compute PSP based on different
    equations from Chapter 15. Each function calculates PSP values across a grid of
    parameters and returns formatted pandas DataFrames. Tables are displayed in the
    console using the tabulate library and saved as LaTeX files.


##################################################################################################
                              R
##################################################################################################

  File:     code/Chapter 15.R

  Requirements: R with the xtable package.
                The package will be installed automatically if missing.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript "Chapter 15.R"

  Output:
    The script generates multiple LaTeX (.tex) files in the output/ folder:
    - Exhibit_15_2_r.tex
    - Exhibit_15_3_r.tex
    - Exhibit_15_4_alpha_0.050_r.tex
    - Exhibit_15_4_alpha_0.005_r.tex
    - Exhibit_15_5_reject_NULL_r.tex
    - Exhibit_15_5_NULL_r.tex
    - Exhibit_15_6_power_0.80_r.tex
    - Exhibit_15_6_power_0.50_r.tex
    - Exhibit_15_8_distance_0.00_r.tex
    - Exhibit_15_8_distance_0.10_r.tex
    - Exhibit_15_8_distance_0.25_r.tex
    - Exhibit_15_8_distance_0.50_r.tex

  What it does:
    The script defines functions for each exhibit that compute PSP using base R matrix
    operations and vectorized calculations. Results are formatted as data frames or
    matrices, printed to the console, and saved as LaTeX tables using the xtable package.


##################################################################################################
                              STATA
##################################################################################################

  File:     code/Chapter 15.do

  Requirements: Stata with the estout package (for esttab command).
                The script will automatically install estout if it's missing.

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 15/PSP Tables and figures/code"

    Alternatively, when you open the .do file in Stata, the working directory is
    automatically set to the location of that file, so you can simply open and run it.

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).
    - Make sure you are in the code/ directory when running.

  Output:
    The script generates multiple LaTeX (.tex) files in the output/ folder:
    - Exhibit_15_2_stata.tex
    - Exhibit_15_3_stata.tex
    - Exhibit_15_4_alpha_0.050_stata.tex
    - Exhibit_15_4_alpha_0.005_stata.tex
    - Exhibit_15_5_reject_NULL_stata.tex
    - Exhibit_15_5_NULL_stata.tex
    - Exhibit_15_6_power_0.80_stata.tex
    - Exhibit_15_6_power_0.50_stata.tex
    - Exhibit_15_8_distance_0.00_stata.tex
    - Exhibit_15_8_distance_0.10_stata.tex
    - Exhibit_15_8_distance_0.25_stata.tex
    - Exhibit_15_8_distance_0.50_stata.tex

  What it does:
    The script creates matrices for each exhibit using nested loops to compute PSP values
    across parameter grids. Matrices are displayed using matlist and exported to LaTeX
    using the esttab command. Stata automatically checks for and installs the estout
    package if needed.


##################################################################################################
                              MATHEMATICAL FOUNDATION
##################################################################################################

All exhibits are based on analytical formulas from Chapter 15:

  Equation 15.1: PSP for single test with significance
    PSP = [(1-β) × π] / [(1-β) × π + α × (1-π)]

  Equation 15.4: PSP when null is NOT rejected
    PSP = 1 - [(1-α) × (1-π)] / [(1-β) × π + (1-α) × (1-π)]

  Equation 15.5: PSP for multiple tests (binomial probabilities)
    PSP = [π × B(i|n, 1-β)] / [π × B(i|n, 1-β) + (1-π) × B(i|n, α)]

  Equation 15.6: PSP accounting for distance from null
    Numerator = (1-β) × π + β × π × d
    Denominator = Numerator + [α + (1-α) × d] × (1-π)

  Where:
    π   = Prior probability that the hypothesis is true
    β   = Type II error rate (Power = 1 - β)
    α   = Significance level (Type I error rate)
    d   = Distance from null (proportion of marginally significant results)
    n   = Number of tests
    i   = Number of successful tests
    B(i|n, p) = Binomial probability mass function


##################################################################################################
                              EXHIBIT DESCRIPTIONS
##################################################################################################

  EXHIBIT 15.2: PSP Across Different Priors
    Shows how PSP varies with prior probability (π) when power = 1.0 and α = 0.05.
    Demonstrates the importance of prior beliefs in interpreting statistical significance.

  EXHIBIT 15.3: PSP Changes with Power and Priors
    Compares PSP for two power levels (0.80 and 0.50) across different priors.
    Illustrates how statistical power affects the interpretation of significant results.

  EXHIBIT 15.4: PSP Across Different Levels of Significance, Power, and Priors
    Two panels for α = 0.05 and α = 0.005, showing PSP across power × prior grid.
    Demonstrates the trade-offs between significance level, power, and prior beliefs.

  EXHIBIT 15.5: PSP With and Without a Statistically Significant Finding
    Two panels:
    - Panel 1: PSP when null is rejected (significant finding)
    - Panel 2: PSP when null is NOT rejected (non-significant finding)
    Shows that failing to reject the null can still provide valuable information.

  EXHIBIT 15.6: PSP Across Different Power, Stat Sig Level, Prior, and Number of Tests
    Two panels for power = 0.80 and 0.50, showing PSP for i = 1, 2, 3, 4 successes.
    Uses binomial distribution to account for multiple testing scenarios.

  EXHIBIT 15.8: PSP with Various Distance Levels
    Four panels for distance d = 0.00, 0.10, 0.25, 0.50 from the null hypothesis.
    Accounts for the possibility of marginally significant or near-threshold results.


##################################################################################################
                              PARAMETER VALUES USED
##################################################################################################

  Common parameters across exhibits:
    - α (alpha) = 0.05 (or 0.005 for Exhibit 15.4)
    - β (beta) varies by exhibit (typically 0.2 for power=0.80, or 0.5 for power=0.50)
    - π (prior) ranges from 0.01 to 0.99 depending on exhibit

  Exhibit-specific parameters:
    - Exhibit 15.2: π from 0.0001 to 0.5, β = 0
    - Exhibit 15.3: π from 0.01 to 0.5, β = [0.2, 0.5]
    - Exhibit 15.4: π from 0.01 to 0.5, power from 0.2 to 0.8, α = [0.05, 0.005]
    - Exhibit 15.5: π from 0.01 to 0.99, power from 0.2 to 0.8
    - Exhibit 15.6: π from 0.01 to 0.5, i from 1 to 4, β = [0.2, 0.5]
    - Exhibit 15.8: π from 0.01 to 0.5, power from 0.2 to 0.8, d = [0, 0.1, 0.25, 0.5]


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
