##################################################################################################
                        README — Appendix 9.2 (Chapter 9)
                   Optimal Experimental Design for Panel Data
##################################################################################################

This folder contains code to recreate the figures from Appendix 9.2 of Chapter 9, which
illustrate optimal sample size calculations for panel data experiments. The figures demonstrate
how the required sample size varies with:

  - The ratio of pre-treatment to post-treatment periods
  - The number of pre-treatment periods
  - Autocorrelation structure (AR1 coefficient)

Two figures are generated:

  - FIGURE A (McKenzie 2012):  Optimal sample size as a function of pre/post period ratio
                                for different numbers of pre-treatment periods (m = 1, 5, 10)

  - FIGURE B (Burlig et al. 2020):  Optimal sample size as a function of AR1 coefficient
                                     for different numbers of post-treatment periods (r = 2, 5, 8)


##################################################################################################
                              FOLDER STRUCTURE
##################################################################################################

    code/       Scripts in Python, R, and Stata
    data/       Input CSV files with simulation data
    output/     Generated figure files (created automatically when you run the scripts)

All three languages produce the same figures. You only need to run ONE of them.
The Python and R scripts auto-detect their own location, so there is no need to manually
set a working directory or edit any file paths.

For Stata: You must manually set the working directory to the code/ folder before running
the script, OR Stata will automatically use the directory of the script when you open it.


##################################################################################################
                              PYTHON
##################################################################################################

  File:     code/9.2.1a_Python.py

  Requirements: Python 3 with numpy, pandas, and matplotlib.
  If missing, run in your terminal:    pip install numpy pandas matplotlib

  How to run:
    - From a terminal:    python 9.2.1a_Python.py
    - Or open the file in your IDE (VS Code, Spyder, PyCharm, etc.) and run it.

  Output:
    - output/paneldata-figA-McKenzie2012.jpg   (Figure A)
    - output/paneldata-figB-Burlig2020.jpg     (Figure B)

  What it does:
    The script loads simulation data from CSV files in the data/ folder and computes
    optimal sample sizes using the formula from McKenzie (2012). For Figure A, it plots
    n* versus the pre/post period ratio for three different values of m (pre-treatment
    periods). For Figure B, it plots n* versus the AR1 coefficient for three different
    values of r (post-treatment periods). If the Burlig data file is missing, it creates
    a simple fallback plot.


##################################################################################################
                              R
##################################################################################################

  File:     code/Exhibit9.2.1A.R

  Requirements: R with ggplot2 and dplyr packages.
                These packages will be installed automatically if missing.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript Exhibit9.2.1A.R

  Output:
    - output/paneldata-figA-McKenzie2012.jpg   (Figure A)
    - output/paneldata-figB-Burlig2020.jpg     (Figure B)

  What it does:
    The script uses ggplot2 to create publication-quality figures. It reads simulation
    data from CSV files, computes optimal sample sizes, and creates line plots with
    custom styling. The script includes a custom theme function (theme_stata) that
    provides consistent formatting across both figures. If the Burlig data file is
    missing, it generates a fallback plot with synthetic data.


##################################################################################################
                              STATA
##################################################################################################

  File:     code/Exhibit9.2.1a_Stata.do

  Requirements: Stata (no additional packages needed).

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 9/Appendix 9.2/code"

    Alternatively, when you open the .do file in Stata, the working directory is
    automatically set to the location of that file, so you can simply open and run it.

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).
    - Make sure you are in the code/ directory when running.

  Output:
    - output/paneldata-figA-McKenzie2012.jpg   (Figure A)
    - output/paneldata-figB-Burlig2020.jpg     (Figure B)

  What it does:
    The script uses Stata's twoway graphics to create line plots. For Figure A, it
    imports the McKenzie simulation data and plots optimal sample size versus the
    pre/post period ratio. For Figure B, it first attempts to load pre-generated data.
    If that file doesn't exist, it tries to use the pc_dd_analytic command (if installed).
    If that also fails, it creates a simple fallback plot with synthetic data. The script
    uses Stata's s1mono scheme for consistent grayscale styling.


##################################################################################################
                              MATHEMATICAL FOUNDATION
##################################################################################################

The optimal sample size formula is based on McKenzie (2012):

  n* = C × (m + r) / (m × r)

  Where:
    n*  = Optimal sample size (number of units)
    m   = Number of pre-treatment periods
    r   = Number of post-treatment periods
    C   = Constant from power calculation

  The constant C is defined as:
    C = 2 × (t_{α/2} + t_β)² × σ² / MDE²

  With standard parameters:
    α       = 0.05 (significance level, two-sided)
    power   = 0.80 (1 - β)
    t_{α/2} = 1.96 (critical value for α/2)
    t_β     = 0.84 (critical value for β)
    σ²      = 1.00 (variance)
    MDE     = 0.5  (minimum detectable effect)

  This yields C ≈ 62.72

  Key insight:
    The optimal ratio m/r depends on the relative costs of adding pre-treatment versus
    post-treatment periods. When costs are equal, the optimal design has more pre-treatment
    periods than post-treatment periods, as this improves precision through better control
    for baseline differences.


##################################################################################################
                              FIGURE DESCRIPTIONS
##################################################################################################

  FIGURE A: McKenzie (2012)
    Shows how optimal sample size n* varies with the ratio of pre-treatment to post-treatment
    periods (m/r). Three lines represent different numbers of pre-treatment periods:
    - m = 1  (black line)
    - m = 5  (gray line)
    - m = 10 (light gray line)

    X-axis: Pre/Post (m/r) period ratio, ranging from 0 to 10
    Y-axis: Optimal Sample Size (n*), ranging from 0 to 130

    Interpretation: For a fixed number of pre-treatment periods, increasing the ratio m/r
    (i.e., having relatively fewer post-treatment periods) increases the required sample
    size. More pre-treatment periods (higher m) reduce the required sample size across
    all ratios.


  FIGURE B: Burlig et al. (2020)
    Shows how optimal sample size n* varies with the AR1 autocorrelation coefficient (γ)
    for different numbers of post-treatment periods. Three lines represent:
    - r = 2  (black line)
    - r = 5  (gray line)
    - r = 8  (light gray line)

    X-axis: AR1(γ), ranging from 0 to 1
    Y-axis: Optimal Sample Size (n*), ranging from 0 to 150

    Interpretation: Higher autocorrelation (higher γ) generally requires larger sample
    sizes to achieve the same power, as observations are more correlated over time.
    More post-treatment periods (higher r) reduce the required sample size for any
    given level of autocorrelation.


##################################################################################################
                              DATA FILES
##################################################################################################

  Required input files (located in data/ folder):

  1. mckenzie2012-simulation.csv
     Contains simulation results with columns:
     - m      : number of pre-treatment periods
     - r      : number of post-treatment periods
     - ratio  : m/r ratio
     Used for Figure A

  2. paneldata-r-variation.csv (optional for Figure B)
     Contains simulation results with columns:
     - ar1   : AR1 autocorrelation coefficient
     - post  : number of post-treatment periods (r)
     - n     : optimal sample size
     Used for Figure B

  If paneldata-r-variation.csv is missing, all three scripts include fallback code to
  generate a simplified version of Figure B.


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
