##################################################################################################
                        README — Synthetic Data Creation (Chapter 12)
##################################################################################################

This folder contains scripts to generate synthetic CHECC (Chicago Early Childhood Center) data
for use in all Chapter 12 exhibits. These scripts created the synthetic data file that allows
all exhibit code to run safely without using actual participant data.

The synthetic data mimics the structure of the real CHECC dataset with randomized values,
enabling testing and demonstration while protecting participant confidentiality.


##################################################################################################
                                  WHAT THIS DOES
##################################################################################################

Generates 1,000 synthetic observations with 17 variables matching the CHECC data structure:

  - Treatment assignment (prek vs. control)
  - Exclusion criteria (kinderprep, late_randomized)
  - Randomization blocks (block_2012, block_2013)
  - Outcome availability indicators (has_cog_sl, has_cog_pre)
  - Standardized outcome scores (std_cog_sl, std_ncog_sl, std_cog_pre, std_ncog_pre)
  - Demographic covariates (female, race_w, hl_eng_span, birthweight, year)

All three scripts (Python, R, Stata) generate identical synthetic data using random seed 42
for reproducibility.


##################################################################################################
                                    OUTPUT
##################################################################################################

  File:     unique_data_clean_main_synthetic.dta  (Stata format)

  The script automatically distributes this file to all Chapter 12 exhibit folders:
    - Exhibit 12.1.1A through Exhibit 12.1.9A
    - Exhibit 12.2, 12.3, 12.4

  Each exhibit's data/ subfolder receives a copy, enabling all analyses to run immediately.


##################################################################################################
                                    Python
##################################################################################################
  File:     create_synthetic_data.py

  Requirements: Python 3 with pandas.
  If missing, run in your terminal:    pip install pandas

  How to run:
    - From a terminal:    python create_synthetic_data.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - unique_data_clean_main_synthetic.dta (copied to all exhibit data/ folders)
    - Prints summary statistics (treatment distribution, year distribution)


##################################################################################################
                                       R
##################################################################################################
  File:     create_synthetic_data.R

  Requirements: R with haven.
  If missing, run in R:    install.packages("haven")

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript create_synthetic_data.R

  Output:
    - unique_data_clean_main_synthetic.dta (copied to all exhibit data/ folders)
    - Prints summary statistics (treatment distribution, year distribution)


##################################################################################################
                                     Stata
##################################################################################################
  File:     create_synthetic_data.do

  Requirements: Stata (no additional packages needed)

  IMPORTANT - Working Directory:
    You MUST set your working directory to this folder before running the script.
    In Stata:    cd "[your path]/Ch. 12/synthetic data creation"

  How to run:
    - In Stata: open the .do file and click "Do" (or select all and run).

  Output:
    - unique_data_clean_main_synthetic.dta (copied to all exhibit data/ folders)
    - Prints summary statistics (treatment distribution, year distribution)


##################################################################################################
                                    NOTES
##################################################################################################

  - The synthetic data is a RANDOMIZED PLACEHOLDER with no real statistical relationships
  - It serves ONLY for testing code functionality and generating example output
  - All Chapter 12 exhibit scripts use this synthetic data BY DEFAULT
  - To use the actual CHECC data, edit the exhibit scripts to uncomment the line loading
    the real data file (unique_data_clean_main.dta) as indicated in the code comments
  - Running this script will OVERWRITE existing synthetic data files in all exhibit folders

##################################################################################################
