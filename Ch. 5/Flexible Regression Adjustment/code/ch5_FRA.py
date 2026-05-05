# =============================================================================
# Flexible Regression Adjustment: Variance Reduction via ML Cross-Fitting
# =============================================================================
# Demonstrates variance reduction in causal inference by using machine learning
# (Random Forest) with cross-fitting to adjust for covariates. Replicates
# Table 7 comparing three estimators on Oregon Health Insurance Experiment data.
#
# Three estimators compared:
#   SM  = Subsample Means (simple difference in means, no covariates)
#   LRA = Linear Regression Adjustment (OLS-based cross-fitting)
#   FRA = Flexible Regression Adjustment (Random Forest-based cross-fitting)
#
# Data: Oregon Health Insurance Experiment (Finkelstein et al., 2016)
#   - Y: ER visit indicator (outcome)
#   - D: Medicaid take-up (endogenous treatment)
#   - W: Lottery treatment assignment (instrument)
#   - Covariates: gender, age, prior health, education, ER visit history
#
# Outputs for each estimator:
#   1. Reduced Form: Impact of W on Y
#   2. First Stage: Impact of W on D
#   3. LATE: Local Average Treatment Effect (IV/Wald estimator)
#
# Cross-fitting validates inference with flexible ML by avoiding overfitting
# bias. Random Forest may take 1-2 minutes to compute.
#
# Reference: Chapter 5, Flexible Regression Adjustment

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import LinearRegression
import os
import warnings
warnings.filterwarnings('ignore')


# =============================================================================
# PART 1: FRA FUNCTIONS
# =============================================================================

# --- Cross-fitted regression adjustment --------------------------------------
# Performs sample-splitting (cross-fitting) to estimate E[Y | X, W=w] for each
# outcome Y and treatment level w. Then constructs "influence function" columns
# that are the building blocks for regression-adjusted estimators.
#
# Inputs:
#   dat            : data frame with outcomes, treatment, and covariates
#   outcome_cols   : names of outcome columns (e.g., ["Y", "D"])
#   treat_col      : name of treatment column (e.g., "W")
#   covariate_cols : names of covariate columns
#   n_folds        : number of cross-fitting folds
#   method         : "linear" (OLS) or "rf" (Random Forest)
#
# Output:
#   Original data frame augmented with columns:
#     m_{outcome}_{treat} : cross-fitted predictions E[Y|X, W=treat]
#     u_{outcome}_{treat} : influence function for E[Y(treat)]
#       -> mean(u) = regression-adjusted estimator for E[Y(treat)]
#       -> var(u)/N = asymptotically valid variance estimate

def FRA(dat, outcome_cols=['Y'], treat_col='W', covariate_cols=['X1', 'X2', 'X3'],
        n_folds=2, method='', ML_func=None, num_trees=300, random_state=None):
    """
    Perform Flexible Regression Adjustment Pre-Processing

    Parameters:
    -----------
    dat : pd.DataFrame
        Data frame with outcomes, treatments, and covariates
    outcome_cols : list
        Column names for outcomes of interest
    treat_col : str
        Column name of treatment
    covariate_cols : list
        Column names of covariates
    n_folds : int
        Number of folds for sample splitting
    method : str
        Regression method used ('linear', 'rf', 'gbm')
    ML_func : callable
        Custom ML model supplied by user. Should have fit() and predict() methods.
    num_trees : int
        Number of trees for ensemble methods
    random_state : int
        Random seed for reproducibility

    Returns:
    --------
    pd.DataFrame
        Original dataframe with extra columns:
        - 'm_{outcome}_{treatment}': fitted conditional expectation E[outcome | X, treatment]
        - 'u_{outcome}_{treatment}': influence function for mean potential outcome
    """
    dat = dat.copy()

    # Set random seed if provided
    if random_state is not None:
        np.random.seed(random_state)

    # Split sample to ensure balance in treatment status across samples
    dat['order'] = np.random.permutation(len(dat))
    dat = dat.sort_values([treat_col, 'order']).reset_index(drop=True)

    fold_col = np.tile(np.arange(n_folds), int(np.ceil(len(dat) / n_folds)))[:len(dat)]
    dat['fold'] = fold_col

    # Get unique treatment levels
    treat_levels = dat[treat_col].unique()

    # Perform Cross-fitting
    if method == 'linear':
        for y in outcome_cols:
            for treat in treat_levels:
                col_name = f'm_{y}_{treat}'
                dat[col_name] = 0.0

                for f in range(n_folds):
                    # Fit OLS model using data from folds except current fold
                    train_data = dat[(dat['fold'] != f) & (dat[treat_col] == treat)]
                    test_data = dat[dat['fold'] == f]

                    X_train = train_data[covariate_cols]
                    y_train = train_data[y]
                    X_test = test_data[covariate_cols]

                    model = LinearRegression()
                    model.fit(X_train, y_train)

                    dat.loc[dat['fold'] == f, col_name] = model.predict(X_test)

    elif method == 'rf':
        for y in outcome_cols:
            for treat in treat_levels:
                col_name = f'm_{y}_{treat}'
                dat[col_name] = 0.0

                for f in range(n_folds):
                    train_data = dat[(dat['fold'] != f) & (dat[treat_col] == treat)]
                    test_data = dat[dat['fold'] == f]

                    X_train = train_data[covariate_cols]
                    y_train = train_data[y]
                    X_test = test_data[covariate_cols]

                    model = RandomForestRegressor(n_estimators=num_trees, random_state=random_state)
                    model.fit(X_train, y_train)

                    dat.loc[dat['fold'] == f, col_name] = model.predict(X_test)

    elif method == 'gbm':
        for y in outcome_cols:
            for treat in treat_levels:
                col_name = f'm_{y}_{treat}'
                dat[col_name] = 0.0

                for f in range(n_folds):
                    train_data = dat[(dat['fold'] != f) & (dat[treat_col] == treat)]
                    test_data = dat[dat['fold'] == f]

                    X_train = train_data[covariate_cols]
                    y_train = train_data[y]
                    X_test = test_data[covariate_cols]

                    model = GradientBoostingRegressor(
                        n_estimators=num_trees,
                        max_depth=2,
                        learning_rate=0.05,
                        random_state=random_state
                    )
                    model.fit(X_train, y_train)

                    dat.loc[dat['fold'] == f, col_name] = model.predict(X_test)

    elif ML_func is not None:
        for y in outcome_cols:
            for treat in treat_levels:
                col_name = f'm_{y}_{treat}'
                dat[col_name] = 0.0

                for f in range(n_folds):
                    train_data = dat[(dat['fold'] != f) & (dat[treat_col] == treat)]
                    test_data = dat[dat['fold'] == f]

                    X_train = train_data[covariate_cols]
                    y_train = train_data[y]
                    X_test = test_data[covariate_cols]

                    model = ML_func()
                    model.fit(X_train, y_train)

                    dat.loc[dat['fold'] == f, col_name] = model.predict(X_test)

    else:
        raise ValueError("Method must be in ['linear', 'rf', 'gbm'] or custom method must be supplied")

    # Create influence function columns
    for treat in treat_levels:
        prop_treat = (dat[treat_col] == treat).mean()

        for y in outcome_cols:
            u_col = f'u_{y}_{treat}'
            m_col = f'm_{y}_{treat}'

            dat[u_col] = np.where(
                dat[treat_col] == treat,
                (1 / prop_treat) * (dat[y] - dat[m_col]),
                0
            ) + dat[m_col]

    return dat


# --- Estimate ATE -----------------------------------------------------------
# ATE = E[Y(1)] - E[Y(0)]
# Uses the influence function columns from FRA to compute point estimate
# and standard error.

def FRA_ATE(dat_with_FRA, outcome_col='Y', treat_lvl=1, ctrl_lvl=0):
    """
    Estimate Average Treatment Effect after Full Regression Adjustment Pre-processing

    Parameters:
    -----------
    dat_with_FRA : pd.DataFrame
        Dataframe with regression adjusted columns
    outcome_col : str
        Name of outcome whose ATE is being estimated
    treat_lvl : int/str
        Value of W corresponding to "treatment"
    ctrl_lvl : int/str
        Value of W corresponding to "control"

    Returns:
    --------
    np.array
        Vector with [point estimate, standard error]
    """
    u_treat = dat_with_FRA[f'u_{outcome_col}_{treat_lvl}']
    u_ctrl = dat_with_FRA[f'u_{outcome_col}_{ctrl_lvl}']
    u = u_treat - u_ctrl

    point_estimate = u.mean()
    standard_error = u.std() / np.sqrt(len(u))

    return np.array([point_estimate, standard_error])


# --- Estimate LATE -----------------------------------------------------------
# LATE = E[Y(1) - Y(0)] / E[D(1) - D(0)]
# Uses the delta method for standard errors of the Wald (IV) estimator.

def FRA_LATE(dat_with_FRA, outcome_col='Y', endog_col='D', treat_lvl=1, ctrl_lvl=0):
    """
    Estimate local average treatment effect when experiment assignment W is instrument for treatment
    using regression-adjusted Wald-style estimator

    Parameters:
    -----------
    dat_with_FRA : pd.DataFrame
        Dataframe with regression adjusted columns
    outcome_col : str
        Name of outcome whose LATE is being estimated
    endog_col : str
        Treatment, which experiment assignment instruments for
    treat_lvl : int/str
        Value of W corresponding to "treatment"
    ctrl_lvl : int/str
        Value of W corresponding to "control"

    Returns:
    --------
    np.array
        Vector with [point estimate, standard error]
    """
    u_num = (dat_with_FRA[f'u_{outcome_col}_{treat_lvl}'] -
             dat_with_FRA[f'u_{outcome_col}_{ctrl_lvl}'])
    u_denom = (dat_with_FRA[f'u_{endog_col}_{treat_lvl}'] -
               dat_with_FRA[f'u_{endog_col}_{ctrl_lvl}'])

    pe = u_num.mean() / u_denom.mean()

    # Compute variance-covariance matrix
    VCV = np.array([
        [u_num.var(), u_num.cov(u_denom)],
        [u_num.cov(u_denom), u_denom.var()]
    ]) / len(dat_with_FRA)

    # Delta method
    D = np.array([1 / u_denom.mean(), -u_num.mean() / (u_denom.mean() ** 2)])
    se = np.sqrt(D @ VCV @ D)

    return np.array([pe, se])


def FRA_theta(param_func, dat_with_FRA, outcome_treats):
    """
    Estimate function of potential outcome means after regression adjustment

    Parameters:
    -----------
    param_func : callable
        Function of potential outcome means being estimated
    dat_with_FRA : pd.DataFrame
        Dataframe with regression adjusted columns
    outcome_treats : list
        Vector of strings of the form '{outcome name}_{treatment name}'

    Returns:
    --------
    np.array
        Vector with [point estimate, standard error]
    """
    input_cols = [f'u_{ot}' for ot in outcome_treats]

    # Compute variance-covariance matrix
    VCV = dat_with_FRA[input_cols].cov().values
    m = dat_with_FRA[input_cols].mean().values

    # Numerical gradient (simple finite difference)
    eps = 1e-8
    D = np.zeros(len(m))
    f0 = param_func(m)

    for i in range(len(m)):
        m_plus = m.copy()
        m_plus[i] += eps
        D[i] = (param_func(m_plus) - f0) / eps

    pe = f0
    se = np.sqrt((1 / len(dat_with_FRA)) * D @ VCV @ D)

    return np.array([pe, se])


# --- Subsample Means (SM) estimator -----------------------------------------
# Simple difference in means -- no covariates, no adjustment.

def SM_ATE(dat, outcome_col='Y', treat_col='W', treat_lvl=1, ctrl_lvl=0):
    """
    Subsample Means ATE estimator (simple difference in means).

    Parameters:
    -----------
    dat : pd.DataFrame
    outcome_col : str
    treat_col : str
    treat_lvl : int/str
    ctrl_lvl : int/str

    Returns:
    --------
    np.array  [point estimate, standard error]
    """
    y1 = dat.loc[dat[treat_col] == treat_lvl, outcome_col]
    y0 = dat.loc[dat[treat_col] == ctrl_lvl, outcome_col]

    pe = y1.mean() - y0.mean()
    se = np.sqrt(y1.var() / len(y1) + y0.var() / len(y0))
    return np.array([pe, se])


def SM_LATE(dat, outcome_col='Y', endog_col='D', treat_col='W',
            treat_lvl=1, ctrl_lvl=0):
    """
    Subsample Means LATE estimator (Wald / IV via delta method).

    Parameters:
    -----------
    dat : pd.DataFrame
    outcome_col : str
    endog_col : str
    treat_col : str
    treat_lvl : int/str
    ctrl_lvl : int/str

    Returns:
    --------
    np.array  [point estimate, standard error]
    """
    rf = SM_ATE(dat, outcome_col, treat_col, treat_lvl, ctrl_lvl)  # reduced form
    fs = SM_ATE(dat, endog_col,  treat_col, treat_lvl, ctrl_lvl)   # first stage

    pe = rf[0] / fs[0]

    # Delta method
    y1 = dat.loc[dat[treat_col] == treat_lvl, outcome_col].values
    y0 = dat.loc[dat[treat_col] == ctrl_lvl, outcome_col].values
    d1 = dat.loc[dat[treat_col] == treat_lvl, endog_col].values
    d0 = dat.loc[dat[treat_col] == ctrl_lvl, endog_col].values

    u_num   = np.concatenate([y1 - y1.mean(), -(y0 - y0.mean())])
    u_denom = np.concatenate([d1 - d1.mean(), -(d0 - d0.mean())])
    n = len(dat)
    VCV = np.array([
        [np.var(u_num, ddof=1),              np.cov(u_num, u_denom, ddof=1)[0, 1]],
        [np.cov(u_num, u_denom, ddof=1)[0, 1], np.var(u_denom, ddof=1)]
    ]) / n
    D_vec = np.array([1 / fs[0], -rf[0] / fs[0]**2])
    se = np.sqrt(D_vec @ VCV @ D_vec)

    return np.array([pe, se])


# =============================================================================
# PART 2: REPLICATE TABLE 7 ON OHIE DATA
# =============================================================================

if __name__ == "__main__":

    # --- Setup ---------------------------------------------------------------
    # Automatically detect script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.normpath(os.path.join(script_dir, '..', 'output'))
    os.makedirs(output_dir, exist_ok=True)

    # --- Load data -----------------------------------------------------------
    # Y = ER visit indicator, D = Medicaid take-up, W = treatment assignment
    # Covariates: gender, age, prior health, education, ER visit counts
    data_path = os.path.normpath(os.path.join(script_dir, '..', 'data', 'OHIE_data.csv'))
    dat = pd.read_csv(data_path).dropna()
    dat['Y'] = dat['Y'].astype(int)

    print(f"Sample size after dropping NAs: {len(dat)}")

    # All columns after Y, D, W are covariates
    covariate_cols = [c for c in dat.columns if c not in ('Y', 'D', 'W')]

    # --- Run estimators ------------------------------------------------------
    np.random.seed(623)

    print("Running FRA (Random Forest, 3 folds)... ", end="", flush=True)
    dat_fra = FRA(dat, outcome_cols=['Y', 'D'],
                  covariate_cols=covariate_cols, method='rf', n_folds=3)
    print("done.")

    print("Running LRA (Linear, 10 folds)... ", end="", flush=True)
    dat_lra = FRA(dat, outcome_cols=['Y', 'D'],
                  covariate_cols=covariate_cols, method='linear', n_folds=10)
    print("done.")

    # --- Collect results for Table 7 -----------------------------------------
    # Row 1: Reduced form -- impact of treatment assignment (W) on ER visits (Y)
    sm_er  = SM_ATE(dat, outcome_col='Y')
    lra_er = FRA_ATE(dat_lra, outcome_col='Y')
    fra_er = FRA_ATE(dat_fra, outcome_col='Y')

    # Row 2: First stage -- impact of treatment assignment (W) on Medicaid take-up (D)
    sm_d  = SM_ATE(dat, outcome_col='D')
    lra_d = FRA_ATE(dat_lra, outcome_col='D')
    fra_d = FRA_ATE(dat_fra, outcome_col='D')

    # Row 3: LATE -- Wald estimator (reduced form / first stage)
    sm_late  = SM_LATE(dat)
    lra_late = FRA_LATE(dat_lra)
    fra_late = FRA_LATE(dat_fra)

    # Organize into a table for display
    table7 = pd.DataFrame({
        'Parameter':  ['ER Visits', 'Medicaid Take-Up', 'LATE'],
        'SM_pe':  [sm_er[0],  sm_d[0],  sm_late[0]],
        'SM_se':  [sm_er[1],  sm_d[1],  sm_late[1]],
        'LRA_pe': [lra_er[0], lra_d[0], lra_late[0]],
        'LRA_se': [lra_er[1], lra_d[1], lra_late[1]],
        'FRA_pe': [fra_er[0], fra_d[0], fra_late[0]],
        'FRA_se': [fra_er[1], fra_d[1], fra_late[1]],
    })

    # Print to console
    print("\n--- Table 7: Variance Reduction for OHIE ---")
    print(f"{'':20s} {'SM':>12s} {'LRA':>12s} {'FRA':>12s}")
    for _, row in table7.iterrows():
        print(f"{row['Parameter']:20s} {row['SM_pe']:12.4f} {row['LRA_pe']:12.4f} {row['FRA_pe']:12.4f}")
        sm_se  = f"({row['SM_se']:.4f})"
        lra_se = f"({row['LRA_se']:.4f})"
        fra_se = f"({row['FRA_se']:.4f})"
        print(f"{'':20s} {sm_se:>12s} {lra_se:>12s} {fra_se:>12s}")
    print(f"N = {len(dat):,}")


    # =============================================================================
    # PART 3: EXPORT TABLE 7
    # =============================================================================

    # Helper: format a point estimate + SE pair for a table cell
    def fmt_cell(pe, se, pe_digits=4, se_digits=4):
        return {
            'pe': f"{pe:.{pe_digits}f}",
            'se': f"{se:.{se_digits}f}",
        }

    # --- LaTeX output --------------------------------------------------------
    def format_tex_row(label, sm, lra, fra, pe_dig=4, se_dig=4):
        s = fmt_cell(sm[0],  sm[1],  pe_dig, se_dig)
        l = fmt_cell(lra[0], lra[1], pe_dig, se_dig)
        f = fmt_cell(fra[0], fra[1], pe_dig, se_dig)
        return (
            f"    {label} & {s['pe']} & {l['pe']} & {f['pe']} \\\\\n"
            f"    & ({s['se']}) & ({l['se']}) & ({f['se']}) \\\\\n"
            f"    \\hline"
        )

    tex_rows = "\n".join([
        format_tex_row("ER Visits",        sm_er,   lra_er,   fra_er),
        format_tex_row("Medicaid Take-Up", sm_d,    lra_d,    fra_d),
        format_tex_row("LATE",             sm_late, lra_late, fra_late),
    ])

    n_fmt = f"{len(dat):,}"
    latex_table = (
        "\\begin{table}[h!]\n"
        "\\centering\n"
        "\\renewcommand{\\arraystretch}{1.5}\n"
        "\\begin{tabular}{l c c c}\n"
        "    \\hline\\hline\n"
        "    & \\textbf{SM} & \\textbf{LRA} & \\textbf{FRA} \\\\\n"
        "    \\hline\n"
        f"{tex_rows}\n"
        "    \\hline\n"
        "    \\multicolumn{4}{l}{\\scriptsize\\textit{Note:} Point estimates with standard errors in parentheses.} \\\\\n"
        "    \\multicolumn{4}{l}{\\scriptsize SM = Subsample Means, LRA = Linear Regression Adjustment,} \\\\\n"
        f"    \\multicolumn{{4}}{{l}}{{\\scriptsize FRA = Flexible Regression Adjustment (Random Forest). $N = {n_fmt}$.}} \\\\\n"
        "    \\hline\\hline\n"
        "\\end{tabular}\n"
        "\\caption{Variance Reduction for OHIE (Table 7)}\n"
        "\\end{table}"
    )

    tex_file = os.path.join(output_dir, "table_7_OHIE.tex")
    with open(tex_file, 'w') as fh:
        fh.write(latex_table)
    print(f"\nSaved to: {tex_file}")

    # --- HTML output ---------------------------------------------------------
    def format_html_row(label, sm, lra, fra, pe_dig=4, se_dig=4):
        s = fmt_cell(sm[0],  sm[1],  pe_dig, se_dig)
        l = fmt_cell(lra[0], lra[1], pe_dig, se_dig)
        f = fmt_cell(fra[0], fra[1], pe_dig, se_dig)
        return (
            f'      <tr class="pe-row"><td>{label}</td>'
            f"<td>{s['pe']}</td><td>{l['pe']}</td><td>{f['pe']}</td></tr>\n"
            f'      <tr class="se-row"><td></td>'
            f"<td>({s['se']})</td><td>({l['se']})</td><td>({f['se']})</td></tr>"
        )

    html_rows = "\n".join([
        format_html_row("ER Visits",        sm_er,   lra_er,   fra_er),
        format_html_row("Medicaid Take-Up", sm_d,    lra_d,    fra_d),
        format_html_row("LATE",             sm_late, lra_late, fra_late),
    ])

    html_content = (
        '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n'
        '<title>Table 7: OHIE</title>\n'
        '<style>\n'
        '    body { font-family: "Helvetica Neue", Arial, sans-serif; margin: 40px; color: #2c3e50; }\n'
        '    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }\n'
        '    table { border-collapse: collapse; margin: 20px auto; }\n'
        '    th { background-color: #1a3e82; color: white; padding: 10px 24px;\n'
        '         font-size: 13px; text-align: center; }\n'
        '    td { padding: 6px 24px; text-align: center; font-size: 13px; }\n'
        '    .pe-row td { border-top: 1px solid #ddd; padding-bottom: 2px; }\n'
        '    .pe-row td:first-child { text-align: left; font-weight: 500; }\n'
        '    .se-row td { color: #666; padding-top: 0; padding-bottom: 8px; }\n'
        '    .se-row td:first-child { text-align: left; }\n'
        '    tr:hover td { background-color: #f0f4fb; }\n'
        '    .note { max-width: 650px; margin: 12px auto; font-size: 11px;\n'
        '            color: #666; text-align: center; line-height: 1.5; }\n'
        '</style>\n'
        '</head>\n<body>\n'
        '<h2>Table 7: Variance Reduction for OHIE</h2>\n'
        '<table>\n'
        '    <thead>\n'
        '      <tr><th></th><th>SM</th><th>LRA</th><th>FRA</th></tr>\n'
        '    </thead>\n'
        '    <tbody>\n'
        f'{html_rows}\n'
        '    </tbody>\n'
        '</table>\n'
        '<p class="note"><em>Note:</em> Point estimates with standard errors in '
        'parentheses. SM = Subsample Means (simple difference in means), '
        'LRA = Linear Regression Adjustment (OLS with cross-fitting), '
        'FRA = Flexible Regression Adjustment (Random Forest with cross-fitting). '
        f'N = {n_fmt}.</p>\n'
        '</body>\n</html>'
    )

    html_file = os.path.join(output_dir, "table_7_OHIE.html")
    with open(html_file, 'w') as fh:
        fh.write(html_content)
    print(f"Saved to: {html_file}")
