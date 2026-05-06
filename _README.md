# Experimental Economics: Theory and Practice
## Replication Materials

This repository contains code and data to replicate the exhibits and supplementary materials from:

**John List, 2026. "Experimental Economics: Theory and Practice"

All replication materials have been implemented in three statistical software packages (Python, R, and Stata) to maximize accessibility for researchers. Each implementation has been verified to produce identical or equivalent results.

---

## Verified System Configuration

All code in this repository has been tested and verified to work with the following system configuration:

### Hardware & Operating System
- **Computer**: MacBook Pro M4 Pro
- **Operating System**: macOS Tahoe 26.4.1

### Software
- **Stata**: StataNow 18.5 SE—Standard Edition
- **Python**: 3.11.5 (Anaconda distribution)
  - **Conda**: 23.7.4
  - **Key packages**: pandas 2.1.2, numpy 1.26.1, matplotlib 3.8.1, scipy, statsmodels
- **R**: 4.3.1 (2023-06-16)
  - **Key packages**: tidyverse 2.0.0, haven 2.5.5, xtable 1.8-4, parallel 4.3.1

While the code may work with other versions of these software packages, the configuration above represents the tested and verified environment.

---

## Repository Structure

The repository is organized by **chapter**, with each chapter containing one or more **exhibits** or **supplementary materials**. Each exhibit is self-contained in its own folder with the following standard structure:

```
Ch. X/
├── Exhibit X.X/
│   ├── code/           # Python (.py), R (.R), and Stata (.do) scripts
│   ├── data/           # Input data files (if required)
│   ├── output/         # Generated output (created automatically when scripts run)
│   └── README_*.txt    # Detailed documentation for this specific exhibit
```


## Quick Start

### General Workflow

**IMPORTANT**: To run any exhibit, you must download the **entire exhibit folder** (or the entire chapter) to your local machine. The code relies on the complete folder structure (code/, data/, output/) and uses relative paths to access data files and save outputs. It is recommended to download the entire chapter or repository and work with it locally in your IDE (VS Code, RStudio, Spyder, PyCharm, etc.).

Once you have the files locally:

1. **Navigate** to the chapter and exhibit of interest
2. **Read** the exhibit-specific README file (e.g., `README_Exhibit_9.4.txt`)
3. **Choose** your preferred software (Python, R, or Stata)
4. **Run** the corresponding script in the `code/` folder
5. **View** the generated output in the `output/` folder (created automatically)

You only need to run **ONE** of the three language implementations—they all produce the same results.

### Python

```bash
# Run the Python script directly from the code folder
python3 exhibit_name.py
```

Or open the `.py` file in your IDE (VS Code, Spyder, PyCharm, Jupyter, etc.) and run it.

**Requirements**: Install required packages using:
```bash
pip install pandas numpy matplotlib scipy statsmodels
```

**Note**: Python scripts use `pathlib` to automatically detect their location and set paths dynamically. **You do NOT need to manually navigate (cd) to the code folder or edit file paths** - the script handles this automatically.

### R

```bash
# Run the R script directly from the code folder
Rscript exhibit_name.R
```

Or in **RStudio**: Open the `.R` file and click "Source" (or press `Ctrl+Shift+S` / `Cmd+Shift+S`).

**Requirements**: Most scripts automatically install required packages if they're missing. Common packages include:
```r
install.packages(c("tidyverse", "haven", "xtable"))
```

**Note**: R scripts auto-detect their location and set paths dynamically. **You do NOT need to manually navigate (cd) to the code folder or edit file paths** - the script handles this automatically.

### Stata

**IMPORTANT**: Stata requires you to set your working directory to the `code/` folder before running scripts.

In Stata:
```stata
cd "[your path]/Ch. X/Exhibit X.X/code"
do exhibit_name.do
```

**Requirements**: Some scripts use the `texsave` package. If missing, install with:
```stata
ssc install texsave
```

---

## Output Files

Generated output appears in each exhibit's `output/` folder and may include:

- **LaTeX tables** (.tex) — Copy and paste into LaTeX documents or Overleaf
- **Figures** (.png, .pdf) — Open with any image viewer or PDF reader
- **HTML tables** (.html) — Open in any web browser
- **Data files** (.dta, .csv) — Processed or simulated datasets

---

## Individual Exhibit Documentation

Each exhibit folder contains its own detailed README file with:

- **Purpose and context** — What the exhibit demonstrates
- **Language-specific instructions** — How to run the code in Python, R, and Stata
- **Output descriptions** — What the generated files contain
- **Parameter explanations** — Assumptions and settings used

**Consult the exhibit-specific README** before running code to understand the analysis and any special requirements.

---

## Tips for Success

### Multi-Language Equivalence
All three implementations (Python, R, Stata) are designed to produce **identical or equivalent results**. You can:
- Use whichever software you're most comfortable with
- Cross-check results across languages for verification
- Switch between languages for different exhibits based on your needs

### Working Directories
- **Python and R**: Scripts automatically handle file paths using relative path detection—**no need to manually navigate (cd) to any folder or edit file paths**. Simply run the script from anywhere or open it in your IDE.
- **Stata**: You **must** set your working directory to the `code/` folder before running scripts (using `cd`), or open the `.do` file directly in Stata (which sets the directory automatically)

### Data Files
- Some exhibits include real or synthetic data in the `data/` folder
- Others generate results analytically without requiring input data
- Check the exhibit-specific README to understand data requirements

### Reproducibility
All code has been designed with reproducibility in mind:
- Fixed random seeds where applicable
- Explicit parameter settings
- Clear documentation of assumptions
- Standardized folder structures

---

**Last Updated**: May 2026

**Verified System**: MacBook Pro M4 Pro, macOS Tahoe 26.4.1, StataNow 18.5 SE, Python 3.11.5 (Anaconda/conda 23.7.4), R 4.3.1
