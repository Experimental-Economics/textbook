##################################################################################################
                        README — Stratified Randomization (Chapter 6)
##################################################################################################

This folder contains code to implement Stratified Randomization (also called Block Randomization)
for your own dataset. The procedure partitions the sample into strata based on specified baseline
covariates, then applies Complete Randomization within each stratum. This ensures balance on the
stratification variables and can improve precision of treatment effect estimates.

Categorical variables are split by their unique values. Continuous variables are split at the
median into two groups: <= median and > median.

To use this code with your own data:
  1. Place your dataset in the data/ folder
  2. Edit the script to specify your dataset filename and stratification variables
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
  File:     code/stratified_randomization.py

  Requirements: Python 3 with numpy and pandas.
  If missing, run in your terminal:    pip install numpy pandas

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit lines 216, 223, and 224 in the script:
       - Line 216: Change the filename to match your dataset
       - Line 223: Specify CATEGORICAL_VARIABLES (e.g., ['female', 'race_w'])
       - Line 224: Specify CONTINUOUS_VARIABLES (e.g., ['age', 'baseline_score'])
    3. Run from terminal:    python stratified_randomization.py
       Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/stratified_randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                                       R
##################################################################################################
  File:     code/stratified_randomization.R

  Requirements: R with haven package.

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit the script to specify:
       - Your dataset filename
       - CATEGORICAL_VARIABLES (e.g., c('female', 'race_w'))
       - CONTINUOUS_VARIABLES (e.g., c('age', 'baseline_score'))
    3. Run in RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
       Or from terminal:    Rscript stratified_randomization.R

  Output:
    - output/stratified_randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/stratified_randomization.do

  Requirements: Stata (no additional packages needed).

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 6/Stratified Randomization/code"

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit the script to specify:
       - Your dataset filename
       - Categorical stratification variables
       - Continuous stratification variables
    3. In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/stratified_randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
