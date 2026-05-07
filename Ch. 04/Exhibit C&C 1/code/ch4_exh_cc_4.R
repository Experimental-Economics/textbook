# =============================================================================
# Exhibit C&C 1: Multiple Hypothesis Testing using mhtexp2
# =============================================================================
# Implements the multiple hypothesis testing procedure of List, Shaikh, and
# Vayalinkal (2023) for the Karlan and List (2007) charitable giving experiment.
#
# This script provides a self-contained R translation of the mhtexp2 procedure,
# originally implemented in Stata/Mata. It demonstrates various multiple testing
# scenarios:
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

# --- Setup -------------------------------------------------------------------
rm(list = ls())

# Load required libraries
if (!require("haven", character.only = TRUE, quietly = TRUE)) {
  install.packages("haven", repos = "https://cloud.r-project.org")
  library(haven)
}

# Automatically set working directory to the folder containing this script
# Supports RStudio (Source/Knit), source(), and Rscript from the command line
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
} else if (length(sys.frames()) > 0 && !is.null(sys.frame(1)$ofile)) {
  setwd(dirname(sys.frame(1)$ofile))
} else if (!is.null(commandArgs(trailingOnly = FALSE))) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    setwd(dirname(normalizePath(sub("^--file=", "", file_arg))))
  }
}


# --- Parameters --------------------------------------------------------------
b_samples <- 3000    # Number of bootstrap samples
studentized <- TRUE  # Whether to studentize test statistics


# =============================================================================
# PART 1: MHTEXP2 HELPER FUNCTIONS
# =============================================================================

runreg <- function(X, y, Xbar, Xvar, pi_2, pi_1, pi_z, full_n) {
  #' Covariate-adjusted regression for single hypothesis.
  #'
  #' @param X Matrix with first column = treatment dummy, rest = covariates
  #' @param y Outcome vector
  #' @param Xbar Mean of covariates in subgroup
  #' @param Xvar Variance-covariance matrix of covariates in subgroup
  #' @param pi_2 Proportion of full n that is (treatment level, subgroup)
  #' @param pi_1 Proportion of full n that is (control level, subgroup)
  #' @param pi_z Proportion of full n in subgroup
  #' @param full_n Number of observations in subgroup
  #' @return Vector c(est_ATE, est_SE)

  D <- X[, 1]
  treated <- (D == 1)
  control <- (D == 0)
  y1 <- y[treated]
  y0 <- y[control]

  if (ncol(X) > 1) {
    Xcov <- X[, -1, drop = FALSE]
    X1 <- Xcov[treated, , drop = FALSE]
    X0 <- Xcov[control, , drop = FALSE]
    DX1 <- cbind(1, X1)
    DX0 <- cbind(1, X0)

    b1 <- solve(crossprod(DX1), crossprod(DX1, y1))
    b0 <- solve(crossprod(DX0), crossprod(DX0, y0))

    bX1 <- b1[-1, , drop = FALSE]
    bX0 <- b0[-1, , drop = FALSE]

    e1 <- y1 - X1 %*% bX1
    s1 <- var(as.numeric(e1))

    e0 <- y0 - X0 %*% bX0
    s0 <- var(as.numeric(e0))
  } else {
    s1 <- var(y1)
    s0 <- var(y0)
    bX1 <- matrix(0, nrow = 1, ncol = 1)
    bX0 <- matrix(0, nrow = 1, ncol = 1)
    b1 <- matrix(mean(y1), nrow = 1, ncol = 1)
    b0 <- matrix(mean(y0), nrow = 1, ncol = 1)
  }

  est_ATE <- (b1[1, 1] - b0[1, 1]) + as.numeric(Xbar %*% (bX1 - bX0))
  diff_b <- bX1 - bX0
  est_VAR <- (1 / pi_2) * s1 + (1 / pi_1) * s0 +
    (1 / pi_z) * as.numeric(t(diff_b) %*% Xvar %*% diff_b)
  est_SE <- sqrt(est_VAR)

  return(c(est_ATE, est_SE))
}


nchoosek_vec <- function(V, K) {
  #' Generate all combinations of K elements from vector V.
  #'
  #' @param V Vector of elements
  #' @param K Number of elements per combination
  #' @return Matrix with choose(length(V), K) rows and K columns

  idx <- combn(seq_along(V), K)
  t(apply(idx, 2, function(i) V[i]))
}


find_first_nonzero <- function(v) {
  #' Find index of first nonzero element.
  #'
  #' @param v Numeric or logical vector
  #' @return Integer index of first nonzero/TRUE element, or NULL if all zero

  idx <- which(v != 0)
  if (length(idx) == 0) return(NULL)
  return(idx[1])
}


ismember_rows <- function(A, B) {
  #' Check if rows of A equal corresponding rows of B.
  #'
  #' @param A Matrix
  #' @param B Matrix with same dimensions as A
  #' @return Logical vector of length nrow(A)

  A <- matrix(A, ncol = ncol(A))
  B <- matrix(B, ncol = ncol(B))
  apply(A == B, 1, all)
}


ismember_elements <- function(A, B) {
  #' Check if elements of A are in B.
  #'
  #' @param A Vector
  #' @param B Vector
  #' @return Logical vector of length(A)

  A %in% B
}


# =============================================================================
# PART 2: MAIN MHTEXP2 FUNCTION
# =============================================================================

mhtexp2 <- function(Y, treatment, subgroup = NULL, combo = NULL, controls = NULL,
                    bootstrap = 3000, studentized = TRUE, seed = 0,
                    transitivitycheck = TRUE, idbootmat = NULL) {
  #' Multiple hypothesis testing procedure.
  #'
  #' Implements the procedure of List, Shaikh, and Vayalinkal (2023) with
  #' bootstrap-based inference and transitivity improvements.
  #'
  #' @param Y Matrix or data frame of outcomes
  #' @param treatment Treatment assignment vector
  #' @param subgroup Subgroup indicator (optional)
  #' @param combo "pairwise" for all pairs, or "treatmentcontrol" for vs control
  #' @param controls Matrix or data frame of covariates (optional)
  #' @param bootstrap Number of bootstrap replications
  #' @param studentized Whether to studentize test statistics
  #' @param seed Random seed
  #' @param transitivitycheck Whether to apply Remark 3.8
  #' @param idbootmat Pre-generated bootstrap index matrix (optional)
  #' @return List with results data frame

  # Convert inputs to matrices/vectors
  Y <- as.matrix(Y)
  D <- as.integer(treatment)
  n <- nrow(Y)
  numoc <- ncol(Y)
  stud <- as.integer(studentized)

  # Subgroup vector
  if (is.null(subgroup)) {
    sub <- rep(1L, n)
  } else {
    sub <- as.integer(subgroup)
  }
  numsub <- length(unique(sub[!is.na(sub)]))

  # Number of treatment groups (excluding control = min value)
  treatment_levels <- sort(unique(D))
  numg <- length(treatment_levels) - 1

  # Build combo matrix (treatment comparison pairs)
  if (is.null(combo) || combo == "treatmentcontrol") {
    # Each treatment vs control (0)
    combo_mat <- cbind(rep(treatment_levels[1], numg),
                       treatment_levels[-1])
  } else if (combo == "pairwise") {
    combo_mat <- t(combn(treatment_levels, 2))
  } else {
    stop("INVALID combo: choose either 'pairwise' or 'treatmentcontrol'")
  }
  numpc <- nrow(combo_mat)

  # Build DX matrix (treatment + covariates)
  has_covariates <- !is.null(controls)
  if (has_covariates) {
    controls <- as.matrix(controls)
    DX <- cbind(D, controls)
    X <- controls
  } else {
    DX <- matrix(D, ncol = 1)
    X <- NULL
  }

  # Build select array (all hypotheses included by default)
  select <- array(1L, dim = c(numoc, numsub, numpc))

  # Bootstrap index matrix
  B <- bootstrap
  if (is.null(idbootmat)) {
    set.seed(seed)
    idbootmat <- matrix(sample.int(n, n * B, replace = TRUE), nrow = n, ncol = B)
  }

  # -------------------------------------------------------------------------
  # Step 1: Run regressions on actual data
  # -------------------------------------------------------------------------
  regact   <- array(NA_real_, dim = c(numoc, numsub, numpc))
  abregact <- array(NA_real_, dim = c(numoc, numsub, numpc))

  for (i in seq_len(numoc)) {
    for (j in seq_len(numsub)) {
      sg <- (sub == j)
      if (has_covariates) {
        cursgX <- X[sg, , drop = FALSE]
        barXz <- colMeans(cursgX)
        varXz <- var(cursgX)
      } else {
        barXz <- matrix(0, nrow = 1, ncol = 1)
        varXz <- matrix(0, nrow = 1, ncol = 1)
      }

      for (l in seq_len(numpc)) {
        w <- (sub == j) & (D == combo_mat[l, 1] | D == combo_mat[l, 2])
        pi_2 <- sum(sub == j & D == combo_mat[l, 2]) / n
        pi_1 <- sum(sub == j & D == combo_mat[l, 1]) / n
        pi_z <- sum(sub == j) / n

        curDX <- DX[w, , drop = FALSE]
        curD  <- D[w]
        curY  <- Y[w, i]

        # Replace treatment column with dummy (1 = combo[l,2], 0 = combo[l,1])
        curDX[, 1] <- as.integer(curD == combo_mat[l, 2])

        regres <- runreg(curDX, curY, barXz, varXz, pi_2, pi_1, pi_z, sum(sg))

        regact[i, j, l]   <- regres[1]
        abregact[i, j, l] <- abs(regres[1]) / (stud * regres[2] + (1 - stud))
      }
    }
  }

  # -------------------------------------------------------------------------
  # Step 2: Bootstrap loop
  # -------------------------------------------------------------------------
  cat("\n")
  cat(strrep("=", 80), "\n", sep = "")
  cat("Running bootstrap procedure\n")
  cat(strrep("=", 80), "\n", sep = "")
  cat("Bootstrap iterations: ")

  abregboot <- array(0, dim = c(B, numoc, numsub, numpc))

  for (ib in seq_len(B)) {
    if (ib %% 100 == 0) cat(".")
    if (ib %% 1000 == 0) cat(sprintf(" %d\n", ib))

    idx <- idbootmat[, ib]
    Yboot   <- Y[idx, , drop = FALSE]
    subboot <- sub[idx]
    Dboot   <- D[idx]
    DXboot  <- DX[idx, , drop = FALSE]
    if (has_covariates) {
      Xboot <- X[idx, , drop = FALSE]
    }

    for (jj in seq_len(numoc)) {
      for (kk in seq_len(numsub)) {
        sg <- (subboot == kk)
        if (has_covariates) {
          cursgX <- Xboot[sg, , drop = FALSE]
          barXz <- colMeans(cursgX)
          varXz <- var(cursgX)
        } else {
          barXz <- matrix(0, nrow = 1, ncol = 1)
          varXz <- matrix(0, nrow = 1, ncol = 1)
        }

        for (ll in seq_len(numpc)) {
          w <- (subboot == kk) & (Dboot == combo_mat[ll, 1] | Dboot == combo_mat[ll, 2])
          pi_2 <- sum(sub == kk & Dboot == combo_mat[ll, 2]) / n
          pi_1 <- sum(sub == kk & Dboot == combo_mat[ll, 1]) / n
          pi_z <- sum(sub == kk) / n

          curDX <- DXboot[w, , drop = FALSE]
          curD  <- Dboot[w]
          curY  <- Yboot[w, jj]

          curDX[, 1] <- as.integer(curD == combo_mat[ll, 2])

          regres <- runreg(curDX, curY, barXz, varXz, pi_2, pi_1, pi_z, sum(sg))

          # Re-centered studentized statistic
          abregboot[ib, jj, kk, ll] <-
            abs(regres[1] - regact[jj, kk, ll]) / (stud * regres[2] + (1 - stud))
        }
      }
    }
  }
  cat("\n")
  cat(strrep("=", 80), "\n", sep = "")
  cat("Bootstrap complete\n")
  cat(strrep("=", 80), "\n\n", sep = "")

  # -------------------------------------------------------------------------
  # Step 3: Compute p-values (pact and pboot)
  # -------------------------------------------------------------------------
  pact  <- array(0, dim = c(numoc, numsub, numpc))
  pboot <- array(0, dim = c(B, numoc, numsub, numpc))

  for (i in seq_len(numoc)) {
    for (j in seq_len(numsub)) {
      for (k in seq_len(numpc)) {
        boot_stats <- abregboot[, i, j, k]
        actual_stat <- abregact[i, j, k]

        pact[i, j, k] <- 1 - sum(boot_stats >= actual_stat) / B

        for (lb in seq_len(B)) {
          pboot[lb, i, j, k] <- 1 - sum(boot_stats >= abregboot[lb, i, j, k]) / B
        }
      }
    }
  }

  # -------------------------------------------------------------------------
  # Step 4: Single hypothesis p-values (Remark 3.2)
  # -------------------------------------------------------------------------
  alphasin <- array(0, dim = c(numoc, numsub, numpc))

  for (i in seq_len(numoc)) {
    for (j in seq_len(numsub)) {
      for (k in seq_len(numpc)) {
        ptemp <- pboot[, i, j, k]
        sortp <- sort(ptemp, decreasing = TRUE)
        v <- (pact[i, j, k] >= sortp)
        idx <- find_first_nonzero(v)
        if (is.null(idx)) {
          q <- 1
        } else {
          q <- idx / B
        }
        alphasin[i, j, k] <- q
      }
    }
  }

  psin <- alphasin  # psin = alphasin

  # -------------------------------------------------------------------------
  # Step 5: Build statsall matrix and compute multiple testing p-values
  # -------------------------------------------------------------------------

  # Count total number of hypotheses
  nh <- sum(select)

  # Build statsall matrix: nh rows x (8 + B) columns
  # Columns: id, outcome, subgroup, treat1, treat2, coefficient, psin, pact, pboot[1..B]
  statsall <- matrix(0, nrow = nh, ncol = 8 + B)

  counter <- 1
  for (i in seq_len(numoc)) {
    for (j in seq_len(numsub)) {
      for (k in seq_len(numpc)) {
        if (select[i, j, k] == 1) {
          statsall[counter, ] <- c(
            counter, i, j, combo_mat[k, 1], combo_mat[k, 2],
            regact[i, j, k], psin[i, j, k], pact[i, j, k],
            pboot[, i, j, k]
          )
          counter <- counter + 1
        }
      }
    }
  }

  # Rank by single hypothesis p-value (column 7)
  statsrank <- statsall[order(statsall[, 7]), , drop = FALSE]

  alphamul  <- numeric(nh)
  alphamulm <- numeric(nh)

  for (i in seq_len(nh)) {
    # Max of 1-p values for all remaining hypotheses (rows i:nh) across B bootstrap samples
    remaining_pvals <- statsrank[i:nh, 9:(8 + B), drop = FALSE]
    maxstats <- apply(remaining_pvals, 2, max)
    sortmaxstats <- sort(maxstats, decreasing = TRUE)

    v <- (statsrank[i, 8] >= sortmaxstats)
    idx <- find_first_nonzero(v)
    if (is.null(idx)) {
      q <- 1
    } else {
      q <- idx / B
    }
    alphamul[i] <- q

    # Remark 3.8 (transitivity improvement)
    if (i == 1 || !transitivitycheck) {
      alphamulm[i] <- alphamul[i]
    } else {
      sortmaxstatsm <- rep(0, B)

      for (j in (nh - i + 1):1) {
        # All subsets of remaining hypothesis IDs of size j
        remaining_ids <- statsrank[i:nh, 1]
        if (length(remaining_ids) < j) next

        subset_mat <- nchoosek_vec(remaining_ids, j)
        if (j == 1) subset_mat <- matrix(subset_mat, ncol = 1)

        sumcont <- 0

        for (k_sub in seq_len(nrow(subset_mat))) {
          cont <- 0
          current_subset <- subset_mat[k_sub, ]

          for (l_prev in seq_len(i - 1)) {
            # Get outcome-subgroup pairs for hypotheses in current subset
            tempA <- statsall[current_subset, 2:3, drop = FALSE]
            tempB <- matrix(rep(statsrank[l_prev, 2:3], each = nrow(tempA)),
                            ncol = 2)

            # Find which hypotheses in subset share same outcome+subgroup as l_prev
            same_mask <- (tempA[, 1] == tempB[, 1]) & (tempA[, 2] == tempB[, 2])
            sameocsub <- current_subset[same_mask]

            if (length(sameocsub) >= 1) {
              # Build transitivity cell structure
              tran_pairs <- statsall[sameocsub, 4:5, drop = FALSE]
              tran <- lapply(seq_len(nrow(tran_pairs)), function(r) tran_pairs[r, ])
            }

            if (length(sameocsub) <= 1) {
              cont <- 0
              # Compute maxstatsm from current subset
              sub_pvals <- statsall[current_subset, 9:(8 + B), drop = FALSE]
              maxstatsm_k <- apply(sub_pvals, 2, max)
              sortmaxstatsm <- pmax(sortmaxstatsm,
                                    sort(maxstatsm_k, decreasing = TRUE))
              break
            } else {
              # Merge equivalence classes by transitivity
              tran_merged <- tran
              changed <- TRUE
              while (changed && length(tran_merged) >= 2) {
                changed <- FALSE
                new_merged <- list(tran_merged[[1]])
                for (m in 2:length(tran_merged)) {
                  merged_into <- FALSE
                  for (nn in seq_along(new_merged)) {
                    if (length(intersect(tran_merged[[m]], new_merged[[nn]])) > 0) {
                      new_merged[[nn]] <- unique(c(new_merged[[nn]], tran_merged[[m]]))
                      merged_into <- TRUE
                      break
                    }
                  }
                  if (!merged_into) {
                    new_merged[[length(new_merged) + 1]] <- tran_merged[[m]]
                  }
                }
                if (length(new_merged) < length(tran_merged)) {
                  changed <- TRUE
                }
                tran_merged <- new_merged
              }

              # Check if previously rejected hypothesis's treatment pair
              # is fully contained in any equivalence class
              prev_pair <- statsrank[l_prev, 4:5]
              for (p in seq_along(tran_merged)) {
                if (all(prev_pair %in% tran_merged[[p]])) {
                  cont <- 1
                  break
                }
              }
            }

            if (cont == 1) break
          }

          sumcont <- sumcont + cont

          if (cont == 0) {
            sub_pvals <- statsall[current_subset, 9:(8 + B), drop = FALSE]
            maxstatsm_k <- apply(sub_pvals, 2, max)
            sortmaxstatsm <- pmax(sortmaxstatsm,
                                  sort(maxstatsm_k, decreasing = TRUE))
          }
        }

        if (sumcont == 0) break
      }

      idx <- find_first_nonzero(statsrank[i, 8] >= sortmaxstatsm)
      if (is.null(idx)) {
        qm <- 1
      } else {
        qm <- idx / B
      }
      alphamulm[i] <- qm
    }
  }

  # -------------------------------------------------------------------------
  # Step 6: Bonferroni and Holm corrections
  # -------------------------------------------------------------------------
  bon <- pmin(statsrank[, 7] * nh, 1)
  holm <- pmin(statsrank[, 7] * (nh:1), 1)
  # Enforce Holm monotonicity
  for (i in 2:nh) {
    holm[i] <- max(holm[i], holm[i - 1])
  }

  # -------------------------------------------------------------------------
  # Step 7: Assemble output
  # -------------------------------------------------------------------------
  output <- cbind(statsrank[, 1:7], alphamul, alphamulm, bon, holm)
  # Sort back by original hypothesis ID (column 1)
  output <- output[order(output[, 1]), , drop = FALSE]
  # Drop the ID column
  output <- output[, -1, drop = FALSE]

  colnames(output) <- c("outcome", "subgroup", "treatment1", "treatment2",
                         "coefficient", "Remark3_2", "Thm3_1", "Remark3_8",
                         "Bonf", "Holm")

  results_df <- as.data.frame(output)
  rownames(results_df) <- paste0("r", seq_len(nrow(results_df)))

  return(list(results = results_df))
}


# =============================================================================
# PART 3: EXPORT HELPER FUNCTIONS
# =============================================================================

prepare_table <- function(results) {
  #' Prepare display-ready copy of results.
  #'
  #' @param results Output from mhtexp2()
  #' @return Data frame with renamed columns

  tbl <- results$results
  safe_names <- c(
    "Remark3_2" = "Rmk 3.2", "Thm3_1" = "Thm 3.1",
    "Remark3_8" = "Rmk 3.8", "Bonf" = "Bonferroni"
  )
  for (old in names(safe_names)) {
    if (old %in% colnames(tbl)) colnames(tbl)[colnames(tbl) == old] <- safe_names[old]
  }
  tbl
}


results_to_latex <- function(results, filepath, caption, label) {
  #' Export results to LaTeX file.
  #'
  #' @param results Output from mhtexp2()
  #' @param filepath Output file path
  #' @param caption Table caption
  #' @param label LaTeX label

  tbl <- prepare_table(results)
  dir.create(dirname(filepath), showWarnings = FALSE, recursive = TRUE)

  col_names <- colnames(tbl)
  col_names_tex <- gsub("_", "\\\\_", col_names)

  lines <- character()
  lines <- c(lines, "\\begin{table}[htbp]\\centering")
  lines <- c(lines, sprintf("\\caption{%s}", caption))
  ncols <- ncol(tbl)
  lines <- c(lines, sprintf("\\begin{tabular}{l*{%d}{c}}", ncols))
  lines <- c(lines, "\\toprule")

  # Header row
  header <- paste0("            &", paste0(sprintf("%12s", col_names_tex), collapse = "&"), "\\\\")
  lines <- c(lines, header)
  lines <- c(lines, "\\midrule")

  # Data rows
  for (r in seq_len(nrow(tbl))) {
    rname <- rownames(tbl)[r]
    vals <- sprintf("%12.4f", as.numeric(tbl[r, ]))
    row_str <- paste0(sprintf("%-12s", rname), "&", paste0(vals, collapse = "&"), "\\\\")
    lines <- c(lines, row_str)
  }

  lines <- c(lines, "\\bottomrule")
  lines <- c(lines, "\\end{tabular}")
  lines <- c(lines, "\\end{table}")

  writeLines(lines, filepath)
}


results_to_html <- function(results, filepath, caption) {
  #' Export results to HTML file.
  #'
  #' @param results Output from mhtexp2()
  #' @param filepath Output file path
  #' @param caption Table title

  tbl <- prepare_table(results)
  dir.create(dirname(filepath), showWarnings = FALSE, recursive = TRUE)

  col_names <- colnames(tbl)
  row_names <- rownames(tbl)

  # Build HTML
  header <- paste0("<th>", col_names, "</th>", collapse = "")
  rows <- vapply(seq_len(nrow(tbl)), function(r) {
    cells <- paste0("<td>", sprintf("%.4f", as.numeric(tbl[r, ])), "</td>", collapse = "")
    paste0("    <tr><td>", row_names[r], "</td>", cells, "</tr>")
  }, character(1))

  html <- paste0(
    "<!DOCTYPE html>\n<html>\n<head>\n",
    "<meta charset=\"utf-8\">\n",
    sprintf("<title>%s</title>\n", caption),
    "<style>\n",
    "  body { font-family: Arial, sans-serif; margin: 40px; }\n",
    "  h2 { font-size: 1.2em; }\n",
    "  .results-table { border-collapse: collapse; font-size: 0.9em; }\n",
    "  .results-table th, .results-table td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }\n",
    "  .results-table th { background-color: #f2f2f2; }\n",
    "</style>\n",
    "</head>\n<body>\n",
    sprintf("<h2>%s</h2>\n", caption),
    "<table class=\"results-table\">\n",
    "  <thead>\n    <tr><th></th>", header, "</tr>\n  </thead>\n",
    "  <tbody>\n", paste(rows, collapse = "\n"), "\n  </tbody>\n",
    "</table>\n",
    "</body>\n</html>\n"
  )
  writeLines(html, filepath)
}


# =============================================================================
# PART 4: DATA PREPARATION
# =============================================================================

# --- Load data ---------------------------------------------------------------
cat(strrep("=", 80), "\n", sep = "")
cat("LOADING AND PREPARING DATA\n")
cat(strrep("=", 80), "\n", sep = "")

df <- haven::read_dta("../data/karlan_list_2007.dta")
cat(sprintf("✓ Loaded data: ../data/karlan_list_2007.dta\n"))
cat(sprintf("  Initial sample size: %d\n", nrow(df)))

# --- Data preparation --------------------------------------------------------
# Sort and generate id (matching exact Stata sort order)
# This specific sort order ensures reproducibility with the replication package
sort_cols <- c(
  "amount", "ask1", "control", "ratio", "sizeno", "female", "askd1", "cases",
  "ratio3", "size100", "ltmedmra", "close25", "freq", "ask2", "treatment",
  "size", "years", "redcty", "askd2", "nonlit", "size25", "mrm2", "red0",
  "amountchange", "hpa", "ask3", "ask", "gave", "couple", "bluecty", "askd3",
  "ratio2", "size50", "dormant", "blue0"
)
df <- df[do.call(order, df[sort_cols]), ]
df$newid <- seq_len(nrow(df))

# Generate groupid variable
# Using boolean arithmetic formula from replication package
df$groupid <- (
  as.integer(df$redcty == 1 & df$red0 == 1) * 1 +
  as.integer(df$redcty == 0 & df$red0 == 1) * 2 +
  as.integer(df$redcty == 0 & df$red0 == 0) * 3 +
  as.integer(df$redcty == 1 & df$red0 == 0) * 4
)
df$groupid[df$groupid == 0] <- NA
# Group labels: 1=Red cty/red state, 2=Blue cty/red state, 3=Blue cty/blue state, 4=Red cty/blue state

# Generate amountmat variable
# ratio is coded as: 0 = control (1:1, no matching)
#                    1 = 2:1 matching (amount × 2)
#                    2 = 3:1 matching (amount × 3)
#                    3 = 4:1 matching (amount × 4)
# Using formula: amountmat = amount × (1 + ratio)
df$amountmat <- df$amount * (1 + df$ratio)

# Drop observations with missing controls
control_vars <- c("female", "pwhite", "pblack", "page18_39", "ave_hh_sz",
                   "years", "couple", "dormant", "nonlit", "cases", "groupid")
df <- df[complete.cases(df[, control_vars]), ]

cat(sprintf("  Final sample size: %d\n", nrow(df)))
cat(strrep("=", 80), "\n\n", sep = "")


# --- Define analysis inputs --------------------------------------------------
outcomes <- c("gave", "amount", "amountmat", "amountchange")
controls_matrix <- df[, control_vars[control_vars != "groupid"]]

# Pre-generate bootstrap index matrix (matching Stata seed = 0)
set.seed(0)
idbootmat <- matrix(sample.int(nrow(df), nrow(df) * b_samples, replace = TRUE),
                    nrow = nrow(df), ncol = b_samples)


# =============================================================================
# PART 5: MULTIPLE HYPOTHESIS TESTING ANALYSES
# =============================================================================

cat(strrep("=", 80), "\n", sep = "")
cat("RUNNING MULTIPLE HYPOTHESIS TESTS\n")
cat(strrep("=", 80), "\n", sep = "")
cat(sprintf("Bootstrap samples: %d\n", b_samples))
cat(sprintf("Studentized: %s\n", studentized))
cat(strrep("=", 80), "\n", sep = "")

# --- Multiple outcomes --------------------------------------------------------
cat("\n--- Multiple Outcomes (without controls) ---\n")
results_outcomes <- mhtexp2(
  Y = df[, outcomes],
  treatment = df$treatment,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_outcomes$results)

cat("\n--- Multiple Outcomes (with controls) ---\n")
results_outcomes_ctrl <- mhtexp2(
  Y = df[, outcomes],
  treatment = df$treatment,
  controls = controls_matrix,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_outcomes_ctrl$results)

# --- Multiple subgroups -------------------------------------------------------
cat("\n--- Multiple Subgroups (without controls) ---\n")
results_subgroup <- mhtexp2(
  Y = df[, "gave", drop = FALSE],
  treatment = df$treatment,
  subgroup = df$groupid,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_subgroup$results)

cat("\n--- Multiple Subgroups (with controls) ---\n")
results_subgroup_ctrl <- mhtexp2(
  Y = df[, "gave", drop = FALSE],
  treatment = df$treatment,
  subgroup = df$groupid,
  controls = controls_matrix,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_subgroup_ctrl$results)

# --- Multiple treatments ------------------------------------------------------
cat("\n--- Multiple Treatments (without controls) ---\n")
results_treat <- mhtexp2(
  Y = df[, "amount", drop = FALSE],
  treatment = df$ratio,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_treat$results)

cat("\n--- Multiple Treatments (with controls) ---\n")
results_treat_ctrl <- mhtexp2(
  Y = df[, "amount", drop = FALSE],
  treatment = df$ratio,
  controls = controls_matrix,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_treat_ctrl$results)

# --- Multiple treatments, pairwise comparisons --------------------------------
cat("\n--- Multiple Treatments, Pairwise (without controls) ---\n")
results_pairwise <- mhtexp2(
  Y = df[, "amount", drop = FALSE],
  treatment = df$ratio,
  combo = "pairwise",
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_pairwise$results)

cat("\n--- Multiple Treatments, Pairwise (with controls) ---\n")
results_pairwise_ctrl <- mhtexp2(
  Y = df[, "amount", drop = FALSE],
  treatment = df$ratio,
  combo = "pairwise",
  controls = controls_matrix,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_pairwise_ctrl$results)

# --- Multiple outcomes, subgroups, and treatments -----------------------------
cat("\n--- Full: Outcomes + Subgroups + Treatments (without controls) ---\n")
results_full <- mhtexp2(
  Y = df[, outcomes],
  treatment = df$ratio,
  subgroup = df$groupid,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_full$results)

cat("\n--- Full: Outcomes + Subgroups + Treatments (with controls) ---\n")
results_full_ctrl <- mhtexp2(
  Y = df[, outcomes],
  treatment = df$ratio,
  subgroup = df$groupid,
  controls = controls_matrix,
  bootstrap = b_samples,
  studentized = studentized,
  idbootmat = idbootmat
)
print(results_full_ctrl$results)


# =============================================================================
# PART 6: EXPORT RESULTS
# =============================================================================

cat("\n")
cat(strrep("=", 80), "\n", sep = "")
cat("EXPORTING RESULTS\n")
cat(strrep("=", 80), "\n", sep = "")

output_dir <- "../output"

# --- Export all results to LaTeX ----------------------------------------------
results_to_latex(results_outcomes, file.path(output_dir, "tab_outcomes.tex"),
    "Multiple Outcomes", "tab:outcomes")
results_to_latex(results_outcomes_ctrl, file.path(output_dir, "tab_outcomes_ctrl.tex"),
    "Multiple Outcomes (with Controls)", "tab:outcomes_ctrl")
results_to_latex(results_subgroup, file.path(output_dir, "tab_subgroups.tex"),
    "Multiple Subgroups", "tab:subgroups")
results_to_latex(results_subgroup_ctrl, file.path(output_dir, "tab_subgroups_ctrl.tex"),
    "Multiple Subgroups (with Controls)", "tab:subgroups_ctrl")
results_to_latex(results_treat, file.path(output_dir, "tab_treatments.tex"),
    "Multiple Treatments", "tab:treatments")
results_to_latex(results_treat_ctrl, file.path(output_dir, "tab_treatments_ctrl.tex"),
    "Multiple Treatments (with Controls)", "tab:treatments_ctrl")
results_to_latex(results_pairwise, file.path(output_dir, "tab_pairwise.tex"),
    "Multiple Treatments -- Pairwise", "tab:pairwise")
results_to_latex(results_pairwise_ctrl, file.path(output_dir, "tab_pairwise_ctrl.tex"),
    "Multiple Treatments -- Pairwise (with Controls)", "tab:pairwise_ctrl")
results_to_latex(results_full, file.path(output_dir, "tab_full.tex"),
    "Multiple Outcomes, Subgroups, and Treatments", "tab:full")
results_to_latex(results_full_ctrl, file.path(output_dir, "tab_full_ctrl.tex"),
    "Multiple Outcomes, Subgroups, and Treatments (with Controls)", "tab:full_ctrl")

# --- Export all results to HTML -----------------------------------------------
results_to_html(results_outcomes, file.path(output_dir, "tab_outcomes.html"),
    "Multiple Outcomes")
results_to_html(results_outcomes_ctrl, file.path(output_dir, "tab_outcomes_ctrl.html"),
    "Multiple Outcomes (with Controls)")
results_to_html(results_subgroup, file.path(output_dir, "tab_subgroups.html"),
    "Multiple Subgroups")
results_to_html(results_subgroup_ctrl, file.path(output_dir, "tab_subgroups_ctrl.html"),
    "Multiple Subgroups (with Controls)")
results_to_html(results_treat, file.path(output_dir, "tab_treatments.html"),
    "Multiple Treatments")
results_to_html(results_treat_ctrl, file.path(output_dir, "tab_treatments_ctrl.html"),
    "Multiple Treatments (with Controls)")
results_to_html(results_pairwise, file.path(output_dir, "tab_pairwise.html"),
    "Multiple Treatments -- Pairwise")
results_to_html(results_pairwise_ctrl, file.path(output_dir, "tab_pairwise_ctrl.html"),
    "Multiple Treatments -- Pairwise (with Controls)")
results_to_html(results_full, file.path(output_dir, "tab_full.html"),
    "Multiple Outcomes, Subgroups, and Treatments")
results_to_html(results_full_ctrl, file.path(output_dir, "tab_full_ctrl.html"),
    "Multiple Outcomes, Subgroups, and Treatments (with Controls)")

cat("\n✓ All LaTeX tables saved to:", output_dir, "\n")
cat("✓ All HTML tables saved to:", output_dir, "\n")
cat(strrep("=", 80), "\n", sep = "")


# =============================================================================
# END OF EXHIBIT C&C 1
# =============================================================================
