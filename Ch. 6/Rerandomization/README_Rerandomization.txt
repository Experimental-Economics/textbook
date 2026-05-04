##################################################################################################
                        README — Rerandomization (Chapter 6)
##################################################################################################

This folder contains code to implement Rerandomization for your own dataset. Rerandomization
improves covariate balance beyond what is achieved by standard Complete Randomization. The
procedure repeatedly applies Complete Randomization and checks for significant imbalances on
specified baseline covariates. If any covariate shows significant imbalance (p < threshold),
the randomization is rejected and the process repeats.

To use this code with your own data:
  1. Place your dataset in the data/ folder
  2. Edit the script to specify your dataset filename, balance variables, and threshold
  3. Run the script to generate a randomized dataset in the output/ folder

Folder structure:

    code/       Scripts in Python, R, and Stata
    data/       Place your input dataset here
    output/     Randomized dataset (created automatically when you run the scripts)

All three languages produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths (except Stata - see below).


##################################################################################################
                                    Python
##################################################################################################
  File:     code/rerandomization.py

  Requirements: Python 3 with numpy, pandas, and scipy.
  If missing, run in your terminal:    pip install numpy pandas scipy

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit lines 260, 267, 268, and 271 in the script:
       - Line 260: Change the filename to match your dataset
       - Line 267: Specify BALANCE_VARIABLES (all variables to check for balance)
       - Line 268: Specify CONTINUOUS_VARIABLES (subset of balance variables that are continuous)
       - Line 271: Set SIGNIFICANCE_LEVEL (e.g., 0.1 to reject if any p-value < 0.1)
    3. Run from terminal:    python rerandomization.py
       Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/rerandomized_dataset_X_rerandomizations.dta   (X = number of attempts needed)


##################################################################################################
                                       R
##################################################################################################
  File:     code/rerandomization.R

  Requirements: R with haven package.

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit the script to specify:
       - Your dataset filename
       - BALANCE_VARIABLES (all variables to check for balance)
       - CONTINUOUS_VARIABLES (subset that are continuous)
       - SIGNIFICANCE_LEVEL (threshold for rejecting randomizations)
    3. Run in RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
       Or from terminal:    Rscript rerandomization.R

  Output:
    - output/rerandomized_dataset_X_rerandomizations.dta   (X = number of attempts needed)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/rerandomization.do

  Requirements: Stata (no additional packages needed).

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 6/Rerandomization/code"

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit the script to specify:
       - Your dataset filename
       - Balance variables to check
       - Continuous vs. binary variable classifications
       - Significance threshold
    3. In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/rerandomized_dataset_X_rerandomizations.dta   (X = number of attempts needed)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
