##################################################################################################
                        README — Bernoulli Randomization (Chapter 6)
##################################################################################################

This folder contains code to implement Bernoulli randomization for your own dataset. Each unit
is independently assigned to treatment with probability p and to control with probability 1-p.

This allows the number of treated units to vary randomly (unlike complete randomization which
fixes it). To use this code with your own data:
  1. Place your dataset in the data/ folder
  2. Edit the script to specify your dataset filename and treatment probability
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
  File:     code/bernoulli_randomization.py

  Requirements: Python 3 with numpy and pandas.
  If missing, run in your terminal:    pip install numpy pandas

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit lines 71 and 77 in the script:
       - Line 71: Change the filename to match your dataset
       - Line 77: Set TREATMENT_PROBABILITY (default: 0.5 for equal allocation)
    3. Run from terminal:    python bernoulli_randomization.py
       Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                                       R
##################################################################################################
  File:     code/bernoulli_randomization.R

  Requirements: R with haven package.

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit lines 56 and 62 in the script:
       - Line 56: Change the filename to match your dataset
       - Line 62: Set TREATMENT_PROBABILITY (default: 0.5 for equal allocation)
    3. Run in RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
       Or from terminal:    Rscript bernoulli_randomization.R

  Output:
    - output/randomized_dataset.dta   (dataset with Treatment variable added)


##################################################################################################
                                     Stata
##################################################################################################
  File:     code/bernoulli_randomization.do

  Requirements: Stata (no additional packages needed).

  IMPORTANT - Working Directory:
    You MUST set your working directory to the code/ folder before running this script.
    In Stata:    cd "[your path]/Ch. 6/Bernulli Randomization/code"

  How to use:
    1. Place your dataset in the data/ folder
    2. Edit lines 26 and 35 in the script:
       - Line 26: Set TREATMENT_PROBABILITY (default: 0.5 for equal allocation)
       - Line 35: Change the filename to match your dataset
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
