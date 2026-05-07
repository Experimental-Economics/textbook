##################################################################################################
                        README — Complete Randomization (Chapter 6)
##################################################################################################

This folder contains code to implement Complete Randomization for your own dataset. Exactly
half of the observations are assigned to treatment, with the remaining assigned to control.
If the sample size is odd, the extra observation is randomly assigned to either treatment
or control.

To use this code with your own data:
  1. Place your dataset in the data/ folder
  2. Edit the script to specify your dataset filename
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
  File:     code/complete_randomization.py

  Requirements: Python 3 with numpy and pandas.
  If missing, run in your terminal:    pip install numpy pandas

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit line 83 in the script:
       - Change the filename to match your dataset
    3. Run from terminal:    python complete_randomization.py
       Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                                       R
##################################################################################################
  File:     code/complete_randomization.R

  Requirements: R with haven package.

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit the script to change the filename to match your dataset
    3. Run in RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
       Or from terminal:    Rscript complete_randomization.R

  Output:
    - output/randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/complete_randomization.do

  Requirements: Stata (no additional packages needed).

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 6/Complete Randomization/code"

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit the script to change the filename to match your dataset
    3. In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - output/randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.

##################################################################################################
