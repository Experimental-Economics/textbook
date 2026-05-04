##################################################################################################
                        README — Exhibit 10.4 (Chapter 10)
            Power Analysis - Within vs. Between Subjects Designs
##################################################################################################

This folder contains code to recreate Exhibit 10.4 from Chapter 10. The scripts conduct Monte
Carlo simulation to compare statistical power between within-subjects and between-subjects
experimental designs.

Data generating process (Equation 10.4):
  Y_it = π₀ + τ*D_it + μ_i + ε_it

Where:
  - Y_it: Outcome for individual i at time t
  - π₀: Baseline mean
  - τ: Treatment effect (varies: 0.05, 0.10, 0.15)
  - D_it: Treatment indicator
  - μ_i: Individual fixed effect (constant across time)
  - ε_it: Random error

IMPORTANT - COMPUTATION TIME:
  The simulation runs 1000 iterations for each combination of treatment effect, sample size,
  and design. On a MacBook Pro M4 Pro:
  - Parallel versions (Python or R, not in Stata): ~5-10 minutes
  - Sequential versions (All languages): ~1 hour

  If parallel processing is not available or fails, consider reducing N_ITERATIONS in the
  script (e.g., to 100 or 200) for faster testing. This will reduce precision but allow
  you to verify the code runs correctly.

Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       (Currently empty - no data required, simulations generate data)
    output/     Generated output files (created automatically when you run the scripts)

All three languages produce similar results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths (except Stata - see below).


##################################################################################################
                                    Python
##################################################################################################
  Files:    code/exhibit_10_4.py            (parallel version - RECOMMENDED)
            code/exhibit_10_4_sequential.py  (sequential version)

  Requirements: Python 3 with numpy, pandas, matplotlib, and scipy.
  If missing, run in your terminal:    pip install numpy pandas matplotlib scipy

  How to run:
    - Parallel version (recommended):    python exhibit_10_4.py
    - Sequential version (slower):       python exhibit_10_4_sequential.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Note: The parallel version uses multiprocessing to speed up computation. If you encounter
  issues with parallel processing, use the sequential version.

  To reduce iterations: Edit line 44 (parallel) or line 43 (sequential)
    Change: N_ITERATIONS = 1000

  Output:
    - output/exhibit_10_4.png          (power curves plot)


##################################################################################################
                                       R
##################################################################################################
  Files:    code/exhibit_10_4.R            (parallel version - RECOMMENDED)
            code/exhibit_10_4_sequential.R  (sequential version)

  Requirements: R with tidyverse and parallel.
  The parallel package is included in base R, so no additional installation needed.

  How to run:
    - Parallel version (recommended):
      In RStudio: open exhibit_10_4.R and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
      From terminal:    Rscript exhibit_10_4.R

    - Sequential version (slower):
      In RStudio: open exhibit_10_4_sequential.R and click "Source".
      From terminal:    Rscript exhibit_10_4_sequential.R

  Note: The parallel version automatically detects available CPU cores using detectCores().

  To reduce iterations: Edit line 56 (parallel) or line 55 (sequential)
    Change: n_iterations <- 1000

  Output:
    - output/exhibit_10_4.png          (power curves plot)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/exhibit_10_4.do

  Requirements: Stata (no additional packages needed).

  Note: The Stata version runs sequentially and will take approximately 1 hour to complete.

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 10/exhibit_10.4/code"

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  To reduce iterations: Edit line 46
    Change: local n_iterations = 1000

  Output:
    - output/exhibit_10_4.png          (power curves plot)
    - output/exhibit_10_4_results.dta  (simulation results data)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
