# =============================================================================
# Exhibit C&C 1: Multiple Hypothesis Testing using mhtexp2
# =============================================================================
# Implements the multiple hypothesis testing procedure of List, Shaikh, and
# Vayalinkal (2023) for the Karlan and List (2007) charitable giving experiment.
#
# This script provides a self-contained Python translation of the mhtexp2
# procedure, originally implemented in Stata/Mata. It demonstrates various
# multiple testing scenarios:
#   - Multiple outcomes
#   - Multiple subgroups
#   - Multiple treatments
#   - Pairwise treatment comparisons
#   - Full factorial combinations
#
# Each scenario is analyzed with and without covariate adjustment.
#
# Outputs: LaTeX tables (.tex) and HTML tables (.html) for all scenarios
#
# Reference: Chapter 4, Multiple Hypothesis Testing
# Data: Karlan and List (2007), "Does Price Matter in Charitable Giving?"

from pathlib import Path
import numpy as np
import pandas as pd
from itertools import combinations


# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location
SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR.parent / "data"
OUTPUT_DIR = SCRIPT_DIR.parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# --- Parameters --------------------------------------------------------------
B = 3000        # Number of bootstrap samples
STUDENTIZED = True  # Whether to studentize test statistics


# =============================================================================
# PART 1: MHTEXP2 IMPLEMENTATION
# =============================================================================

def _runreg(X, y, Xbar, Xvar, pi_2, pi_1, pi_z, full_n):
    """
    Covariate-adjusted regression for a single (outcome, subgroup, treatment-pair).

    Parameters
    ----------
    X : ndarray, shape (n_sub, 1+K)
        First column is treatment dummy (1=treated, 0=control).
        Remaining columns are covariates (may be absent).
    y : ndarray, shape (n_sub,)
        Outcome vector.
    Xbar : ndarray, shape (K,) or scalar 0
        Mean of covariates in this subgroup (all treatment groups).
    Xvar : ndarray, shape (K, K) or scalar 0
        Variance-covariance of covariates in this subgroup.
    pi_2 : float
        P(treated level & subgroup) / n_total
    pi_1 : float
        P(control level & subgroup) / n_total
    pi_z : float
        P(subgroup) / n_total
    full_n : int
        Size of the subgroup (all treatment groups).

    Returns
    -------
    tuple of (float, float)
        (est_ATE, est_SE)
    """
    D = X[:, 0]
    treated = (D == 1)
    control = (D == 0)
    y1 = y[treated]
    y0 = y[control]

    has_covs = X.shape[1] > 1

    if has_covs:
        Xcov = X[:, 1:]
        X1 = Xcov[treated]
        X0 = Xcov[control]
        # Design matrices with intercept
        DX1 = np.column_stack([np.ones(X1.shape[0]), X1])
        DX0 = np.column_stack([np.ones(X0.shape[0]), X0])

        # OLS: b = (X'X)^{-1} X'y
        b1 = np.linalg.lstsq(DX1, y1, rcond=None)[0]
        b0 = np.linalg.lstsq(DX0, y0, rcond=None)[0]

        bX1 = b1[1:]  # covariate coefficients
        bX0 = b0[1:]

        e1 = y1 - X1 @ bX1
        e0 = y0 - X0 @ bX0
        # Stata quadvariance = sample variance (ddof=1)
        s1 = float(np.var(e1, ddof=1)) if len(e1) > 1 else 0.0
        s0 = float(np.var(e0, ddof=1)) if len(e0) > 1 else 0.0
    else:
        DX1 = np.ones((y1.shape[0], 1))
        DX0 = np.ones((y0.shape[0], 1))
        b1 = np.linalg.lstsq(DX1, y1, rcond=None)[0]
        b0 = np.linalg.lstsq(DX0, y0, rcond=None)[0]
        s1 = float(np.var(y1, ddof=1)) if len(y1) > 1 else 0.0
        s0 = float(np.var(y0, ddof=1)) if len(y0) > 1 else 0.0
        bX1 = np.array([0.0])
        bX0 = np.array([0.0])

    est_ATE = float((b1[0] - b0[0]) + Xbar @ (bX1 - bX0))

    diff_bX = bX1 - bX0
    est_VAR = (1.0 / pi_2) * s1 + (1.0 / pi_1) * s0 + (1.0 / pi_z) * float(diff_bX @ Xvar @ diff_bX)
    est_SE = np.sqrt(max(est_VAR, 0.0))

    return (est_ATE, est_SE)


def _find_first_nonzero(v):
    """
    Return 1-based index of first nonzero element, or None.

    Parameters
    ----------
    v : ndarray
        Boolean or numeric array

    Returns
    -------
    int or None
        1-based index of first True/nonzero value, or None if all False/zero
    """
    idx = np.flatnonzero(v)
    if len(idx) == 0:
        return None
    return int(idx[0]) + 1  # 1-based


def mhtexp2(Y, treatment, subgroup=None, combo=None, controls=None,
            bootstrap=3000, studentized=True, seed=0,
            transitivitycheck=True, idbootmat=None):
    """
    Multiple hypothesis testing procedure of List, Shaikh, and Vayalinkal (2023).

    Parameters
    ----------
    Y : DataFrame
        Outcome columns (each column is one outcome variable).
    treatment : Series
        Treatment assignment variable (integer-coded; 0 = control by default).
    subgroup : Series or None
        Subgroup variable. If None, all observations are in one subgroup.
    combo : str or None
        "pairwise" for all pairwise comparisons, or None / "treatmentcontrol"
        for each treatment vs. control (level 0).
    controls : DataFrame or None
        Covariate columns for covariate-adjusted inference.
    bootstrap : int
        Number of bootstrap replications (default 3000).
    studentized : bool
        Whether to studentize test statistics (default True).
    seed : int
        Random seed for bootstrap index matrix (default 0).
    transitivitycheck : bool
        Whether to apply Remark 3.8 transitivity improvement (default True).
    idbootmat : ndarray or None
        Pre-generated bootstrap index matrix, shape (n, B), **1-based** indices
        matching Stata convention. If None, generated internally.

    Returns
    -------
    dict
        Dictionary with keys:
        - 'results' : ndarray, shape (nh, 10)
        - 'results_df' : DataFrame with named columns
    """
    # --- Convert inputs to numpy arrays --------------------------------------
    Y_arr = np.asarray(Y, dtype=float)
    D_arr = np.asarray(treatment, dtype=float).ravel()
    n = Y_arr.shape[0]
    numoc = Y_arr.shape[1]

    if subgroup is not None:
        sub_arr = np.asarray(subgroup, dtype=float).ravel()
    else:
        sub_arr = np.ones(n, dtype=float)

    sub_levels = np.sort(np.unique(sub_arr[~np.isnan(sub_arr)]))
    numsub = len(sub_levels)

    d_levels = np.sort(np.unique(D_arr[~np.isnan(D_arr)]))
    numg = len(d_levels) - 1  # number of treatment groups (excluding control)

    # Build combo matrix (pairs of treatment levels to compare)
    if combo == "pairwise":
        combo_arr = np.array(list(combinations(d_levels.astype(int), 2)), dtype=float)
    else:
        # Each treatment vs control (level 0 = d_levels[0])
        ctrl_level = d_levels[0]
        combo_arr = np.column_stack([
            np.full(numg, ctrl_level),
            d_levels[1:]
        ])
    numpc = combo_arr.shape[0]

    # Build select array — default: all ones (test everything)
    select = np.ones((numoc, numsub, numpc), dtype=int)

    # Covariates
    has_covs = controls is not None and controls.shape[1] > 0
    if has_covs:
        X_arr = np.asarray(controls, dtype=float)
        # DX = treatment column + covariates
        DX_arr = np.column_stack([D_arr, X_arr])
    else:
        X_arr = None
        DX_arr = D_arr.reshape(-1, 1)

    stud = 1.0 if studentized else 0.0
    B = bootstrap

    # --- Bootstrap index matrix (1-based in Stata; convert to 0-based) -------
    if idbootmat is not None:
        # Expect 1-based indices from Stata convention
        idboot = np.asarray(idbootmat, dtype=int) - 1
    else:
        rng = np.random.RandomState(seed)
        idboot = rng.randint(0, n, size=(n, B))

    # =========================================================================
    # Step 1: Run regressions on actual data
    # =========================================================================
    regact = {}    # (i, j, l) -> coefficient
    abregact = {}  # (i, j, l) -> studentized |coeff|

    for i in range(numoc):
        for j_idx, j_val in enumerate(sub_levels):
            sg = (sub_arr == j_val)
            if has_covs:
                cursgX = X_arr[sg]
                barXz = np.mean(cursgX, axis=0)
                varXz = np.cov(cursgX, rowvar=False, ddof=1)
                if varXz.ndim == 0:
                    varXz = np.array([[float(varXz)]])
            else:
                barXz = np.array([0.0])
                varXz = np.array([[0.0]])

            for l in range(numpc):
                c1, c2 = combo_arr[l, 0], combo_arr[l, 1]
                w = sg & ((D_arr == c1) | (D_arr == c2))
                pi_2 = np.sum(sg & (D_arr == c2)) / n
                pi_1 = np.sum(sg & (D_arr == c1)) / n
                pi_z = np.sum(sg) / n

                curDX = DX_arr[w].copy()
                curD = D_arr[w]
                curY = Y_arr[w, i]
                # Replace the treatment column with a dummy for c2
                curDX[:, 0] = (curD == c2).astype(float)

                ate, se = _runreg(curDX, curY, barXz, varXz, pi_2, pi_1, pi_z, int(np.sum(sg)))
                regact[(i, j_idx, l)] = ate
                abregact[(i, j_idx, l)] = abs(ate) / (stud * se + (1.0 - stud))

    # =========================================================================
    # Step 2: Bootstrap loop
    # =========================================================================
    # abregboot[(b, i, j, l)] = re-centered studentized bootstrap stat
    abregboot = np.zeros((B, numoc, numsub, numpc))

    for b in range(B):
        idx = idboot[:, b]
        Yboot = Y_arr[idx]
        subboot = sub_arr[idx]
        Dboot = D_arr[idx]
        DXboot = DX_arr[idx]
        if has_covs:
            Xboot = X_arr[idx]

        for j_oc in range(numoc):
            for k_idx, k_val in enumerate(sub_levels):
                sg = (subboot == k_val)
                if has_covs:
                    cursgX = Xboot[sg]
                    if cursgX.shape[0] > 1:
                        barXz = np.mean(cursgX, axis=0)
                        varXz = np.cov(cursgX, rowvar=False, ddof=1)
                        if varXz.ndim == 0:
                            varXz = np.array([[float(varXz)]])
                    else:
                        barXz = np.zeros(cursgX.shape[1])
                        varXz = np.zeros((cursgX.shape[1], cursgX.shape[1]))
                else:
                    barXz = np.array([0.0])
                    varXz = np.array([[0.0]])

                for l in range(numpc):
                    c1, c2 = combo_arr[l, 0], combo_arr[l, 1]
                    w = sg & ((Dboot == c1) | (Dboot == c2))

                    # NOTE: Mata uses *original* sub for pi computation in bootstrap
                    # Line 237-239: pi_2 = sum(sub :== k :& Dboot :== combo[l,2])/n
                    pi_2 = np.sum((sub_arr == k_val) & (Dboot == c2)) / n
                    pi_1 = np.sum((sub_arr == k_val) & (Dboot == c1)) / n
                    pi_z = np.sum(sub_arr == k_val) / n

                    curDX = DXboot[w].copy()
                    curD = Dboot[w]
                    curY = Yboot[w, j_oc]
                    curDX[:, 0] = (curD == c2).astype(float)

                    # Check that we have observations in both groups
                    if np.sum(curDX[:, 0] == 1) < 2 or np.sum(curDX[:, 0] == 0) < 2:
                        abregboot[b, j_oc, k_idx, l] = 0.0
                        continue

                    try:
                        ate_b, se_b = _runreg(curDX, curY, barXz, varXz, pi_2, pi_1, pi_z, int(np.sum(sg)))
                        denom = stud * se_b + (1.0 - stud)
                        if denom > 0 and np.isfinite(se_b):
                            abregboot[b, j_oc, k_idx, l] = abs(ate_b - regact[(j_oc, k_idx, l)]) / denom
                        else:
                            abregboot[b, j_oc, k_idx, l] = 0.0
                    except Exception:
                        abregboot[b, j_oc, k_idx, l] = 0.0

    # =========================================================================
    # Step 3: Compute p-values (pact and pboot)
    # =========================================================================
    pact = np.zeros((numoc, numsub, numpc))
    pboot = np.zeros((B, numoc, numsub, numpc))

    for i in range(numoc):
        for j in range(numsub):
            for k in range(numpc):
                boot_stats = abregboot[:, i, j, k]  # (B,)
                actual_stat = abregact[(i, j, k)]
                # pact = 1 - (fraction of bootstrap stats >= actual stat)
                pact[i, j, k] = 1.0 - np.sum(boot_stats >= actual_stat) / B
                for l_b in range(B):
                    pboot[l_b, i, j, k] = 1.0 - np.sum(boot_stats >= boot_stats[l_b]) / B

    # =========================================================================
    # Step 4: Single hypothesis p-values (Remark 3.2)
    # =========================================================================
    alphasin = np.zeros((numoc, numsub, numpc))
    for i in range(numoc):
        for j in range(numsub):
            for k in range(numpc):
                ptemp = pboot[:, i, j, k]
                sortp = np.sort(ptemp)[::-1]  # sort descending
                v = (pact[i, j, k] >= sortp)
                idx = _find_first_nonzero(v)
                if idx is None:
                    alphasin[i, j, k] = 1.0
                else:
                    alphasin[i, j, k] = idx / B

    psin = alphasin.copy()

    # =========================================================================
    # Step 5: Build statsall matrix and compute multiple testing p-values
    # =========================================================================
    # Count hypotheses
    nh = 0
    for k in range(numpc):
        nh += int(np.sum(select[:, :, k]))

    # statsall: columns = [counter, outcome, subgroup, treat1, treat2, coeff, psin, pact, pboot_1..pboot_B]
    statsall = np.zeros((nh, 8 + B))
    counter = 0
    for i in range(numoc):
        for j in range(numsub):
            for k in range(numpc):
                if select[i, j, k] == 1:
                    # Use 1-based outcome/subgroup indices for output (matching Stata)
                    statsall[counter, 0] = counter + 1  # 1-based id
                    statsall[counter, 1] = i + 1         # outcome (1-based)
                    statsall[counter, 2] = j + 1         # subgroup (1-based)
                    statsall[counter, 3] = combo_arr[k, 0]  # treatment1
                    statsall[counter, 4] = combo_arr[k, 1]  # treatment2
                    statsall[counter, 5] = regact[(i, j, k)]  # coefficient
                    statsall[counter, 6] = psin[i, j, k]      # single p-value
                    statsall[counter, 7] = pact[i, j, k]      # 1-pvalue actual
                    statsall[counter, 8:] = pboot[:, i, j, k]  # bootstrap pvalues
                    counter += 1

    # Sort by single p-value (column index 6, ascending) — Stata: sort(statsall, 7)
    sort_idx = np.argsort(statsall[:, 6])
    statsrank = statsall[sort_idx].copy()

    alphamul = np.zeros(nh)   # Theorem 3.1
    alphamulm = np.zeros(nh)  # Remark 3.8

    for i in range(nh):
        # Max of 1-p values for remaining hypotheses (rows i..nh-1), columns 8..end
        remaining = statsrank[i:, 8:]
        maxstats = np.max(remaining, axis=0)  # (B,)
        sortmaxstats = np.sort(maxstats)[::-1]

        v = (statsrank[i, 7] >= sortmaxstats)
        idx = _find_first_nonzero(v)
        if idx is None:
            q = 1.0
        else:
            q = idx / B
        alphamul[i] = q

        if i == 0 or not transitivitycheck:
            alphamulm[i] = alphamul[i]
        else:
            # Remark 3.8: transitivity improvement
            sortmaxstatsm = np.zeros(B)
            remaining_ids = statsrank[i:, 0].astype(int)  # 1-based ids

            for j_size in range(len(remaining_ids), 0, -1):
                subsets = list(combinations(remaining_ids, j_size))
                sumcont = 0

                for subset in subsets:
                    subset_arr = np.array(subset)
                    cont = 0

                    for l_prev in range(i):
                        # Get (outcome, subgroup) for hypotheses in this subset
                        # subset ids are 1-based; statsall rows are indexed by id-1
                        subset_rows = subset_arr - 1  # 0-based into statsall
                        tempA = statsall[subset_rows][:, 1:3]  # (outcome, subgroup)
                        tempB = np.tile(statsrank[l_prev, 1:3], (len(subset_rows), 1))

                        # Find hypotheses in subset with same (outcome, subgroup) as the l_prev-th rejected hypothesis
                        match_mask = np.all(tempA == tempB, axis=1)
                        sameocsub = subset_arr[match_mask]

                        if len(sameocsub) >= 2:
                            # Build "tran" — equivalence classes of treatment groups implied by transitivity
                            # Each hypothesis says treat1 == treat2 under the null
                            tran_pairs = []
                            for h_id in sameocsub:
                                row = statsall[h_id - 1]
                                tran_pairs.append((int(row[3]), int(row[4])))

                            # Union-find to merge equivalence classes
                            parent = {}
                            def find(x):
                                while parent.get(x, x) != x:
                                    parent[x] = parent.get(parent[x], parent[x])
                                    x = parent[x]
                                return x
                            def union(a, b):
                                ra, rb = find(a), find(b)
                                if ra != rb:
                                    parent[ra] = rb

                            for a, b in tran_pairs:
                                union(a, b)

                            # Check if the previously rejected hypothesis's treatments
                            # are in the same equivalence class
                            prev_t1 = int(statsrank[l_prev, 3])
                            prev_t2 = int(statsrank[l_prev, 4])
                            if find(prev_t1) == find(prev_t2):
                                cont = 1
                                break
                        elif len(sameocsub) <= 1:
                            cont = 0
                            # Compute critical value from this subset
                            subset_rows_all = subset_arr - 1
                            maxstatsm_sub = np.max(statsall[subset_rows_all][:, 8:], axis=0)
                            sortmaxstatsm = np.maximum(sortmaxstatsm, np.sort(maxstatsm_sub)[::-1])
                            break

                    if cont == 1:
                        # Check if we broke out of the l_prev loop with cont==1
                        pass  # cont already set

                    sumcont += cont
                    if cont == 0:
                        subset_rows_all = subset_arr - 1
                        maxstatsm_sub = np.max(statsall[subset_rows_all][:, 8:], axis=0)
                        sortmaxstatsm = np.maximum(sortmaxstatsm, np.sort(maxstatsm_sub)[::-1])

                if sumcont == 0:
                    break  # smaller subsets won't contradict either

            idx = _find_first_nonzero(statsrank[i, 7] >= sortmaxstatsm)
            if idx is None:
                qm = 1.0
            else:
                qm = idx / B
            alphamulm[i] = qm

    # =========================================================================
    # Step 6: Bonferroni and Holm corrections
    # =========================================================================
    bon = np.minimum(statsrank[:, 6] * nh, 1.0)
    holm = np.minimum(statsrank[:, 6] * np.arange(nh, 0, -1), 1.0)
    # Enforce Holm monotonicity
    for i in range(1, nh):
        if holm[i] < holm[i - 1]:
            holm[i] = holm[i - 1]

    # =========================================================================
    # Step 7: Assemble output
    # =========================================================================
    # output columns: outcome, subgroup, treatment1, treatment2, coefficient,
    #                 Remark3_2, Thm3_1, Remark3_8, Bonf, Holm
    output_unsorted = np.column_stack([
        statsrank[:, 1:7],   # outcome, subgroup, treat1, treat2, coeff, psin(=Remark3_2)
        alphamul,            # Thm3_1
        alphamulm,           # Remark3_8
        bon,                 # Bonf
        holm                 # Holm
    ])
    # Sort back to original order (by column 0 of statsrank = original id)
    orig_order = np.argsort(statsrank[:, 0])
    output = output_unsorted[orig_order]

    col_names = ["outcome", "subgroup", "treatment1", "treatment2",
                 "coefficient", "Remark3_2", "Thm3_1", "Remark3_8", "Bonf", "Holm"]
    results_df = pd.DataFrame(output, columns=col_names)

    return {"results": output, "results_df": results_df}


# =============================================================================
# PART 2: EXPORT HELPER FUNCTIONS
# =============================================================================

def _prepare_table(results):
    """
    Prepare a display-ready copy of the results DataFrame.

    Parameters
    ----------
    results : dict
        Output from mhtexp2()

    Returns
    -------
    DataFrame
        Formatted table with all numeric values as strings
    """
    tbl = results["results_df"].copy()
    num_cols = ["outcome", "subgroup", "treatment1", "treatment2",
                "coefficient", "Remark3_2", "Thm3_1", "Remark3_8", "Bonf", "Holm"]
    for col in num_cols:
        if col in tbl.columns:
            tbl[col] = tbl[col].map(lambda x: f"{x:.4f}" if pd.notna(x) else "")
    return tbl


def results_to_latex(results, filepath, caption, label=None):
    """
    Export results to a LaTeX file matching the Stata esttab/booktabs format.

    Parameters
    ----------
    results : dict
        Output from mhtexp2()
    filepath : str or Path
        Output file path
    caption : str
        Table caption
    label : str or None
        LaTeX label for cross-referencing (optional)
    """
    tbl = _prepare_table(results)
    nrows = len(tbl)
    ncols = len(tbl.columns)

    lines = []
    lines.append(r"\begin{table}[htbp]\centering")
    lines.append(rf"\caption{{{caption}}}")
    lines.append(r"\begin{tabular}{l*{" + str(ncols) + r"}{c}}")
    lines.append(r"\toprule")

    # Header row
    header_parts = ["            "]
    for col in tbl.columns:
        escaped = col.replace("_", r"\_")
        header_parts.append(f"&{escaped:>12s}")
    lines.append("".join(header_parts) + r"\\")
    lines.append(r"\midrule")

    # Data rows
    for idx in range(nrows):
        row_label = f"r{idx + 1}"
        parts = [f"{row_label:<12s}"]
        for col in tbl.columns:
            parts.append(f"&{str(tbl.iloc[idx][col]):>12s}")
        lines.append("".join(parts) + r"\\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")

    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    filepath.write_text("\n".join(lines) + "\n")


def results_to_html(results, filepath, caption):
    """
    Export results to an HTML file matching the Stata format.

    Parameters
    ----------
    results : dict
        Output from mhtexp2()
    filepath : str or Path
        Output file path
    caption : str
        Table title
    """
    tbl = _prepare_table(results)
    nrows = len(tbl)

    lines = []
    lines.append("<!DOCTYPE html>")
    lines.append("<html>")
    lines.append("<head>")
    lines.append('<meta charset="utf-8">')
    lines.append(f"<title>{caption}</title>")
    lines.append("<style>")
    lines.append("  body { font-family: Arial, sans-serif; margin: 40px; }")
    lines.append("  h2 { font-size: 1.2em; }")
    lines.append("  .results-table { border-collapse: collapse; font-size: 0.9em; }")
    lines.append("  .results-table th, .results-table td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }")
    lines.append("  .results-table th { background-color: #f2f2f2; }")
    lines.append("</style>")
    lines.append("</head>")
    lines.append("<body>")
    lines.append(f"<h2>{caption}</h2>")
    lines.append('<table class="results-table">')

    # Header
    lines.append("  <thead><tr><th></th>")
    for col in tbl.columns:
        lines.append(f"<th>{col}</th>")
    lines.append("</tr></thead>")

    # Body
    lines.append("  <tbody>")
    for idx in range(nrows):
        row_label = f"r{idx + 1}"
        parts = [f"    <tr><td>{row_label}</td>"]
        for col in tbl.columns:
            parts.append(f"<td>{tbl.iloc[idx][col]}</td>")
        parts.append("</tr>")
        lines.append("".join(parts))
    lines.append("  </tbody>")
    lines.append("</table>")
    lines.append("</body>")
    lines.append("</html>")

    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    filepath.write_text("\n".join(lines) + "\n")


# =============================================================================
# PART 3: DATA PREPARATION
# =============================================================================

# --- Load data ---------------------------------------------------------------
print("=" * 80)
print("LOADING AND PREPARING DATA")
print("=" * 80)

data_file = DATA_DIR / "karlan_list_2007.dta"
df = pd.read_stata(data_file, convert_categoricals=False)
print(f"✓ Loaded data: {data_file}")
print(f"  Initial sample size: {len(df):,}")

# --- Data preparation --------------------------------------------------------
# Sort and generate id (matching exact Stata sort order)
# This specific sort order ensures reproducibility with the replication package
sort_cols = [
    "amount", "ask1", "control", "ratio", "sizeno", "female", "askd1", "cases",
    "ratio3", "size100", "ltmedmra", "close25", "freq", "ask2", "treatment",
    "size", "years", "redcty", "askd2", "nonlit", "size25", "mrm2", "red0",
    "amountchange", "hpa", "ask3", "ask", "gave", "couple", "bluecty", "askd3",
    "ratio2", "size50", "dormant", "blue0"
]
df = df.sort_values(by=sort_cols).reset_index(drop=True)
df["newid"] = df.index + 1

# Generate groupid variable
# Using boolean arithmetic formula from replication package
df["groupid"] = (
    ((df["redcty"] == 1) & (df["red0"] == 1)).astype(int) * 1 +
    ((df["redcty"] == 0) & (df["red0"] == 1)).astype(int) * 2 +
    ((df["redcty"] == 0) & (df["red0"] == 0)).astype(int) * 3 +
    ((df["redcty"] == 1) & (df["red0"] == 0)).astype(int) * 4
)
df.loc[df["groupid"] == 0, "groupid"] = np.nan
# Group labels: 1=Red cty/red state, 2=Blue cty/red state, 3=Blue cty/blue state, 4=Red cty/blue state

# Generate amountmat variable
# ratio is coded as: 0 = control (1:1, no matching)
#                    1 = 2:1 matching (amount × 2)
#                    2 = 3:1 matching (amount × 3)
#                    3 = 4:1 matching (amount × 4)
# Using formula: amountmat = amount × (1 + ratio)
df["amountmat"] = df["amount"] * (1 + df["ratio"])

# Drop observations with missing controls
control_vars = ["female", "pwhite", "pblack", "page18_39", "ave_hh_sz",
                "years", "couple", "dormant", "nonlit", "cases", "groupid"]
df = df.dropna(subset=control_vars).reset_index(drop=True)

print(f"  Final sample size: {len(df):,}")
print("=" * 80)


# --- Define analysis inputs --------------------------------------------------
outcomes = ["gave", "amount", "amountmat", "amountchange"]
controls = df[["female", "pwhite", "pblack", "page18_39", "ave_hh_sz",
               "years", "couple", "dormant", "nonlit", "cases"]]


# =============================================================================
# PART 4: MULTIPLE HYPOTHESIS TESTING ANALYSES
# =============================================================================

print("\n")
print("=" * 80)
print("RUNNING MULTIPLE HYPOTHESIS TESTS")
print("=" * 80)
print(f"Bootstrap samples: {B:,}")
print(f"Studentized: {STUDENTIZED}")
print("=" * 80)

# --- Multiple outcomes --------------------------------------------------------
print("\n--- Multiple Outcomes (without controls) ---")
results_outcomes = mhtexp2(
    Y=df[outcomes], treatment=df["treatment"],
    bootstrap=B, studentized=STUDENTIZED
)
print(results_outcomes["results_df"])

print("\n--- Multiple Outcomes (with controls) ---")
results_outcomes_ctrl = mhtexp2(
    Y=df[outcomes], treatment=df["treatment"], controls=controls,
    bootstrap=B, studentized=STUDENTIZED
)
print(results_outcomes_ctrl["results_df"])

# --- Multiple subgroups -------------------------------------------------------
print("\n--- Multiple Subgroups (without controls) ---")
results_subgroup = mhtexp2(
    Y=df[["gave"]], treatment=df["treatment"], subgroup=df["groupid"],
    bootstrap=B, studentized=STUDENTIZED
)
print(results_subgroup["results_df"])

print("\n--- Multiple Subgroups (with controls) ---")
results_subgroup_ctrl = mhtexp2(
    Y=df[["gave"]], treatment=df["treatment"], subgroup=df["groupid"],
    controls=controls, bootstrap=B, studentized=STUDENTIZED
)
print(results_subgroup_ctrl["results_df"])

# --- Multiple treatments ------------------------------------------------------
print("\n--- Multiple Treatments (without controls) ---")
results_treat = mhtexp2(
    Y=df[["amount"]], treatment=df["ratio"],
    bootstrap=B, studentized=STUDENTIZED
)
print(results_treat["results_df"])

print("\n--- Multiple Treatments (with controls) ---")
results_treat_ctrl = mhtexp2(
    Y=df[["amount"]], treatment=df["ratio"], controls=controls,
    bootstrap=B, studentized=STUDENTIZED
)
print(results_treat_ctrl["results_df"])

# --- Multiple treatments, pairwise comparisons --------------------------------
print("\n--- Multiple Treatments, Pairwise (without controls) ---")
results_pairwise = mhtexp2(
    Y=df[["amount"]], treatment=df["ratio"], combo="pairwise",
    bootstrap=B, studentized=STUDENTIZED
)
print(results_pairwise["results_df"])

print("\n--- Multiple Treatments, Pairwise (with controls) ---")
results_pairwise_ctrl = mhtexp2(
    Y=df[["amount"]], treatment=df["ratio"], combo="pairwise",
    controls=controls, bootstrap=B, studentized=STUDENTIZED
)
print(results_pairwise_ctrl["results_df"])

# --- Multiple outcomes, subgroups, and treatments -----------------------------
print("\n--- Full: Outcomes + Subgroups + Treatments (without controls) ---")
results_full = mhtexp2(
    Y=df[outcomes], treatment=df["ratio"], subgroup=df["groupid"],
    bootstrap=B, studentized=STUDENTIZED
)
print(results_full["results_df"])

print("\n--- Full: Outcomes + Subgroups + Treatments (with controls) ---")
results_full_ctrl = mhtexp2(
    Y=df[outcomes], treatment=df["ratio"], subgroup=df["groupid"],
    controls=controls, bootstrap=B, studentized=STUDENTIZED
)
print(results_full_ctrl["results_df"])


# =============================================================================
# PART 5: EXPORT RESULTS
# =============================================================================

print("\n")
print("=" * 80)
print("EXPORTING RESULTS")
print("=" * 80)

# --- Export all results to LaTeX ----------------------------------------------
results_to_latex(results_outcomes, OUTPUT_DIR / "tab_outcomes.tex",
    "Multiple Outcomes")
results_to_latex(results_outcomes_ctrl, OUTPUT_DIR / "tab_outcomes_ctrl.tex",
    "Multiple Outcomes (with Controls)")
results_to_latex(results_subgroup, OUTPUT_DIR / "tab_subgroups.tex",
    "Multiple Subgroups")
results_to_latex(results_subgroup_ctrl, OUTPUT_DIR / "tab_subgroups_ctrl.tex",
    "Multiple Subgroups (with Controls)")
results_to_latex(results_treat, OUTPUT_DIR / "tab_treatments.tex",
    "Multiple Treatments")
results_to_latex(results_treat_ctrl, OUTPUT_DIR / "tab_treatments_ctrl.tex",
    "Multiple Treatments (with Controls)")
results_to_latex(results_pairwise, OUTPUT_DIR / "tab_pairwise.tex",
    "Multiple Treatments -- Pairwise")
results_to_latex(results_pairwise_ctrl, OUTPUT_DIR / "tab_pairwise_ctrl.tex",
    "Multiple Treatments -- Pairwise (with Controls)")
results_to_latex(results_full, OUTPUT_DIR / "tab_full.tex",
    "Multiple Outcomes, Subgroups, and Treatments")
results_to_latex(results_full_ctrl, OUTPUT_DIR / "tab_full_ctrl.tex",
    "Multiple Outcomes, Subgroups, and Treatments (with Controls)")

# --- Export all results to HTML -----------------------------------------------
results_to_html(results_outcomes, OUTPUT_DIR / "tab_outcomes.html",
    "Multiple Outcomes")
results_to_html(results_outcomes_ctrl, OUTPUT_DIR / "tab_outcomes_ctrl.html",
    "Multiple Outcomes (with Controls)")
results_to_html(results_subgroup, OUTPUT_DIR / "tab_subgroups.html",
    "Multiple Subgroups")
results_to_html(results_subgroup_ctrl, OUTPUT_DIR / "tab_subgroups_ctrl.html",
    "Multiple Subgroups (with Controls)")
results_to_html(results_treat, OUTPUT_DIR / "tab_treatments.html",
    "Multiple Treatments")
results_to_html(results_treat_ctrl, OUTPUT_DIR / "tab_treatments_ctrl.html",
    "Multiple Treatments (with Controls)")
results_to_html(results_pairwise, OUTPUT_DIR / "tab_pairwise.html",
    "Multiple Treatments -- Pairwise")
results_to_html(results_pairwise_ctrl, OUTPUT_DIR / "tab_pairwise_ctrl.html",
    "Multiple Treatments -- Pairwise (with Controls)")
results_to_html(results_full, OUTPUT_DIR / "tab_full.html",
    "Multiple Outcomes, Subgroups, and Treatments")
results_to_html(results_full_ctrl, OUTPUT_DIR / "tab_full_ctrl.html",
    "Multiple Outcomes, Subgroups, and Treatments (with Controls)")

print("\n✓ All LaTeX tables saved to:", OUTPUT_DIR)
print("✓ All HTML tables saved to:", OUTPUT_DIR)
print("=" * 80)


# =============================================================================
# END OF EXHIBIT C&C 1
# =============================================================================
