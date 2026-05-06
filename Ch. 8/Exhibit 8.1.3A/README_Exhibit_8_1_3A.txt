##################################################################################################
                        README — Exhibit 8.1.3A (Chapter 8)
        A Comparison of Mediation Analysis Methods: Parental Beliefs
##################################################################################################

This folder contains code to recreate Exhibit 8.1.3A from Chapter 8. The scripts compare
different mediation analysis methods to examine the relationship between home visiting
programs, parental beliefs, and outcomes (parental investments and child outcomes).

The methods available:
  1. Baron and Kenny (1986) - Traditional approach with Sobel test (Python & R)
  2. Interaction Model - Imai et al. (2010a), Kraemer et al. (2008) (Python & R)
  3. Non-parametric Model - Imai et al. (2010a) with GAM smoothing splines (R only)

IMPORTANT: Python implements only methods 1-2. For the full 3-method comparison including
the Non-parametric Model with GAM smoothing, use the R implementation.

For each method, the exhibit reports:
  - AIE (Average Indirect Effect): Effect mediated through parental beliefs
  - ADE (Average Direct Effect): Direct effect of treatment
  - ATE (Average Total Effect): Total effect of treatment

Mediation equations:
  - M_i = α + λ_dm*D_i + X_i'δ + v_i                              (A8.1.4)
  - Y_i = ρ + λ_dy*D_i + λ_my*M_i + λ_dmy*D_i*M_i + X_i'δ + ε_i  (A8.1.8)

where:
  - D_i: Treatment indicator (Home Visiting Program)
  - M_i: Mediator (Parental Beliefs)
  - Y_i: Outcome (Parental Investments or Child Outcome)
  - λ_dmy: Interaction term between treatment and mediator

Folder structure:

    code/       Scripts in Python and R (Stata not available for this exhibit)
    data/       TMP (Tulsa Maternal Parenting) dataset
    output/     Generated output files (created automatically when you run the scripts)

Python and R produce the same results. You only need to run ONE of them.
The scripts auto-detect their own location, so there is no need to manually set a
working directory or edit any file paths.


##################################################################################################
                                    DATA
##################################################################################################

  File:     data/TMPdata_de-identified.dta

  This dataset contains de-identified data from the Tulsa Maternal Parenting (TMP) study.


##################################################################################################
                                    Python
##################################################################################################
  File:     code/Exhibit_8.1.3A.py

  Requirements: Python 3 with numpy, pandas, scipy, and statsmodels.
  If missing, run in your terminal:    pip install numpy pandas scipy statsmodels

  How to run:
    - From a terminal:    python Exhibit_8.1.3A.py
    - Or open the file in your IDE (VS Code, Spyder, etc.) and run it.

  Output:
    - output/Exhibit_8_1_3A_python.tex   (LaTeX table with 2 methods)

  Note:
    - Implements Baron and Kenny with Sobel test (deterministic)
    - Implements Interaction Model with bootstrap (1000 replications)
    - Does NOT implement Non-parametric Model (use R for this)
    - Random seed set to 1234 for reproducibility

  Limitation:
    Python's statsmodels.Mediation class does not support GAM models, so the
    Non-parametric Model with smoothing splines cannot be implemented. For the
    full 3-method comparison, please use the R implementation.


##################################################################################################
                                       R
##################################################################################################
  File:     code/Exhibit_8.1.3A.R

  Requirements: R with mediation, mgcv, dplyr, and knitr packages.
  The script will automatically install missing packages when run.

  How to run:
    - In RStudio: open the file and click "Source" (or Ctrl+Shift+S / Cmd+Shift+S).
    - From a terminal:    Rscript Exhibit_8.1.3A.R

  Output:
    - output/Exhibit_8_1_3A_r.tex   (LaTeX table with all 3 methods)

  Note:
    - Implements ALL THREE methods (Baron and Kenny, Interaction, Non-parametric)
    - Uses mediation package with boot=TRUE and sims=1000 for bootstrap inference
    - Uses mgcv::gam with s(M, bs="cr") for Non-parametric Model with cubic regression splines
    - Random seed can be set to 1234 for reproducibility (uncomment set.seed(1234) on line 45)

  RECOMMENDED: Use R for the complete analysis with all 3 methods.


##################################################################################################
                                     Stata
##################################################################################################

  Stata implementation is NOT available for this exhibit due to mediation package limitations.


##################################################################################################
                              VIEWING THE OUTPUT
##################################################################################################

  - .pdf files    Open with any PDF viewer (Adobe Reader, Preview, browser, etc.)
  - .html files   Open in any web browser (Chrome, Firefox, Edge, Safari, etc.)
  - .tex files    Copy and paste the contents into a LaTeX editor (Overleaf, TeXShop,
                  etc.) to compile and view the formatted table.


##################################################################################################
                                    NOTES
##################################################################################################

  Significance levels:
    *** p < 0.001
    **  p < 0.01
    *   p < 0.05
    .   p < 0.1

  Uncertainty estimates:
    - Baron and Kenny: Standard errors in parentheses (calculated via Sobel test)
    - Interaction Model: Bootstrap confidence intervals in brackets (1000 simulations)
    - Non-parametric Model: Bootstrap confidence intervals in brackets (1000 simulations)

  Key differences between methods:
    1. Baron and Kenny assumes no treatment-mediator interaction (λ_dmy = 0)
    2. Interaction Model relaxes the no-interaction assumption (parametric linear model)
    3. Non-parametric Model uses GAM to allow flexible, non-linear relationships

##################################################################################################
