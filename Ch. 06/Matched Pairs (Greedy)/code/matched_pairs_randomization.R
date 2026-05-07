# =============================================================================
# Matched-Pairs Randomization
# =============================================================================
# Implements Matched-Pairs Design (also called Pairwise Matching) to assign
# treatment status to observations. This is a limiting case of stratification
# where pairs of similar units are matched based on baseline covariates, and
# then one unit in each pair is randomly assigned to treatment.
#
# The procedure:
# 1. Create outer strata based on discrete/categorical variables
# 2. Within each outer stratum, calculate Mahalanobis distance between all
#    pairs of units using continuous covariates
# 3. Use greedy algorithm to match pairs:
#    - Find the two units with smallest pairwise distance
#    - Randomly assign one to treatment, one to control
#    - Remove both from the pool
#    - Repeat until all units are matched
# 4. If stratum has odd number of units, apply Complete Randomization (CRE)
#    to the unpaired unit

# --- Load Required Packages --------------------------------------------------
if (!require("haven")) install.packages("haven")
library(haven)

# --- Setup -------------------------------------------------------------------
# Automatically resolve paths relative to this script's location
script_dir <- dirname(sys.frame(1)$ofile)
if (length(script_dir) == 0 || script_dir == "") {
  script_dir <- getwd()
}
data_dir <- file.path(dirname(script_dir), "data")
output_dir <- file.path(dirname(script_dir), "output")

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}


# --- Mahalanobis Distance Calculation ----------------------------------------
mahalanobis_distances <- function(data, continuous_vars) {
  #' Calculate pairwise Mahalanobis distances for all observations.
  #'
  #' @param data Data frame containing the continuous variables.
  #' @param continuous_vars Character vector of continuous variable names
  #'        to use for distance calculation.
  #' @return Square distance matrix where element [i,j] is the Mahalanobis
  #'         distance between observation i and observation j.

  # Extract continuous variables as matrix
  X <- as.matrix(data[, continuous_vars, drop = FALSE])
  n <- nrow(X)

  # Calculate covariance matrix
  cov_matrix <- cov(X)

  # Calculate inverse covariance matrix (with conditional regularization)
  # try inv(cov), except: inv(cov + 1e-6*I)
  cov_inv <- tryCatch({
    solve(cov_matrix)
  }, error = function(e) {
    # If singular, add small regularization
    solve(cov_matrix + 1e-6 * diag(ncol(X)))
  })

  # Calculate pairwise Mahalanobis distances
  # For each pair (i,j): distance = sqrt((X[i] - X[j])' * cov_inv * (X[i] - X[j]))
  distances <- matrix(0, nrow = n, ncol = n)

  for (i in 1:n) {
    for (j in 1:n) {
      if (i != j) {
        diff <- X[i, ] - X[j, ]
        distances[i, j] <- sqrt(as.numeric(t(diff) %*% cov_inv %*% diff))
      }
    }
  }

  return(distances)
}


# --- Greedy Matching Algorithm -----------------------------------------------
greedy_match_pairs <- function(data, distances, seed = NULL) {
  #' Match pairs using greedy algorithm based on pairwise distances.
  #'
  #' Iteratively finds the pair with smallest distance, randomly assigns
  #' treatment/control, and removes both from the pool. If an odd number
  #' of units remains (always 0 or 1), applies Complete Randomization (CRE)
  #' to the unpaired unit.
  #'
  #' @param data Data frame to match.
  #' @param distances Square matrix of pairwise distances.
  #' @param seed Integer random seed for reproducibility (optional).
  #' @return List containing:
  #'   - matched_data: Data frame with 'Treatment' and 'Pair_ID' columns added
  #'   - n_unmatched: Number of units that could not be paired (0 or 1)

  # Set random seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Create copy of data and reset row names to ensure 1-based indexing
  matched_data <- data
  rownames(matched_data) <- NULL  # Reset to 1, 2, 3, ...
  matched_data$Treatment <- -1  # Initialize as unassigned
  matched_data$Pair_ID <- -1    # Initialize as unpaired

  # Track which units are still available for matching
  available <- 1:nrow(matched_data)
  pair_counter <- 0

  # Continue until fewer than 2 units remain
  while (length(available) >= 2) {
    # Create submatrix of distances for available units only
    available_distances <- distances[available, available, drop = FALSE]

    # Set diagonal to infinity to avoid self-matching
    diag(available_distances) <- Inf

    # Find the pair with minimum distance
    min_idx <- which.min(available_distances)
    best_i_local <- ((min_idx - 1) %% nrow(available_distances)) + 1
    best_j_local <- ((min_idx - 1) %/% nrow(available_distances)) + 1

    # Convert local indices back to original indices
    best_i <- available[best_i_local]
    best_j <- available[best_j_local]

    # Randomly assign treatment to one unit in the pair
    if (runif(1) < 0.5) {
      treat_unit <- best_i
      control_unit <- best_j
    } else {
      treat_unit <- best_j
      control_unit <- best_i
    }

    # Assign treatment status and pair ID
    matched_data$Treatment[treat_unit] <- 1
    matched_data$Treatment[control_unit] <- 0
    matched_data$Pair_ID[treat_unit] <- pair_counter
    matched_data$Pair_ID[control_unit] <- pair_counter

    # Remove matched units from available pool
    available <- available[!(available %in% c(best_i, best_j))]

    pair_counter <- pair_counter + 1
  }

  # Handle unmatched units with Complete Randomization
  n_unmatched <- length(available)

  if (n_unmatched > 0) {
    # Apply CRE to unmatched unit(s)
    # For odd stratum: 1 unit remains, randomly assign to treatment or control
    for (unit in available) {
      matched_data$Treatment[unit] <- sample(c(0, 1), 1)
      matched_data$Pair_ID[unit] <- -1  # Mark as unpaired
    }
  }

  return(list(matched_data = matched_data, n_unmatched = n_unmatched))
}


# --- Matched-Pairs Randomization Function ------------------------------------
matched_pairs_randomize <- function(data, categorical_vars = NULL,
                                   continuous_vars = NULL, seed = NULL) {
  #' Assign treatment status using Matched-Pairs Randomization.
  #'
  #' Creates outer strata based on categorical variables, then matches pairs
  #' within each stratum using Mahalanobis distance on continuous variables.
  #' Uses greedy algorithm to find best matches and randomly assigns treatment
  #' within each pair.
  #'
  #' @param data Data frame to which treatment will be assigned.
  #' @param categorical_vars Character vector of categorical variable names
  #'        to create outer strata (optional).
  #' @param continuous_vars Character vector of continuous variable names
  #'        for Mahalanobis distance calculation (required).
  #' @param seed Integer random seed for reproducibility (optional).
  #' @return Data frame with 'Treatment' variable (1 = treatment, 0 = control),
  #'         'Pair_ID' variable (unique ID for each matched pair, -1 = unpaired),
  #'         and 'Stratum_ID' variable (identifies outer strata).

  # Validate inputs
  if (is.null(continuous_vars) || length(continuous_vars) == 0) {
    stop("Must provide at least one continuous variable for matching")
  }

  if (is.null(categorical_vars)) {
    categorical_vars <- c()
  }

  # Validate that all variables exist in the dataset
  all_vars <- c(categorical_vars, continuous_vars)
  missing_vars <- all_vars[!(all_vars %in% names(data))]
  if (length(missing_vars) > 0) {
    stop(paste("Variables not found in data:", paste(missing_vars, collapse = ", ")))
  }

  # Create copy to avoid modifying original
  randomized_data <- data
  randomized_data$`_original_order` <- 1:nrow(randomized_data)

  # Create outer strata based on categorical variables
  if (length(categorical_vars) > 0) {
    # Combine categorical variables to create stratum identifier
    randomized_data$Stratum_ID <- do.call(paste,
                                          c(randomized_data[, categorical_vars, drop = FALSE],
                                            sep = "_"))
    strata_list <- split(randomized_data, randomized_data$Stratum_ID)
  } else {
    # Single stratum containing all observations
    randomized_data$Stratum_ID <- "0"
    strata_list <- list("0" = randomized_data)
  }

  # Initialize output columns
  randomized_data$Treatment <- -1
  randomized_data$Pair_ID <- -1

  # Process each stratum
  matched_strata <- list()
  total_unmatched <- 0
  pair_id_offset <- 0

  for (stratum_id in names(strata_list)) {
    stratum_data <- strata_list[[stratum_id]]

    # Use different seed for each stratum if seed is provided
    # Seed + hash(str(stratum_id)) % 10000
    if (!is.null(seed)) {
      # Simple hash: sum of character codes modulo 10000
      stratum_hash <- sum(utf8ToInt(stratum_id)) %% 10000
      stratum_seed <- seed + stratum_hash
    } else {
      stratum_seed <- NULL
    }

    # Handle empty strata
    if (nrow(stratum_data) < 1) {
      next
    }

    # Handle single-observation strata - apply CRE
    if (nrow(stratum_data) == 1) {
      if (!is.null(stratum_seed)) {
        set.seed(stratum_seed)
      }
      stratum_matched <- stratum_data
      stratum_matched$Treatment <- sample(c(0, 1), 1)
      stratum_matched$Pair_ID <- -1
      matched_strata[[stratum_id]] <- stratum_matched
      total_unmatched <- total_unmatched + 1
      next
    }

    # Calculate Mahalanobis distances within this stratum
    distances <- mahalanobis_distances(stratum_data, continuous_vars)

    # Match pairs using greedy algorithm
    result <- greedy_match_pairs(stratum_data, distances, seed = stratum_seed)
    stratum_matched <- result$matched_data
    n_unmatched <- result$n_unmatched

    # Adjust Pair_ID to be globally unique
    stratum_matched$Pair_ID[stratum_matched$Pair_ID >= 0] <-
      stratum_matched$Pair_ID[stratum_matched$Pair_ID >= 0] + pair_id_offset

    max_pair_id <- max(stratum_matched$Pair_ID[stratum_matched$Pair_ID >= 0], -1)
    if (max_pair_id >= 0) {
      pair_id_offset <- max_pair_id + 1  # Set to next available ID (not +=)
    }

    matched_strata[[stratum_id]] <- stratum_matched
    total_unmatched <- total_unmatched + n_unmatched
  }

  # Combine all strata
  combined_data <- do.call(rbind, matched_strata)

  # Restore original order
  combined_data <- combined_data[order(combined_data$`_original_order`), ]
  combined_data$`_original_order` <- NULL
  rownames(combined_data) <- NULL

  return(combined_data)
}


# --- Load Data ---------------------------------------------------------------
# Load input dataset
# TODO: Replace with your actual dataset filename
input_file <- file.path(data_dir, "unique_data_clean_main_synthetic.dta")
data <- haven::read_dta(input_file)


# --- Apply Matched-Pairs Randomization ---------------------------------------
# TODO: Define variables for matching
# Categorical variables create outer strata (discrete/binary variables)
# These should be variables like gender, race, location, etc.
CATEGORICAL_VARIABLES <- c("female", "race_w")

# TODO: Continuous variables used for Mahalanobis distance calculation
# These should be numeric variables like test scores, age, income, etc.
# The algorithm will match units with similar values on these variables
CONTINUOUS_VARIABLES <- c("std_cog_pre", "birthweight", "std_ncog_pre", "year")

# TODO: Set random seed for reproducibility
# Change to any integer for different randomization results
randomized_data <- matched_pairs_randomize(
  data = data,
  categorical_vars = CATEGORICAL_VARIABLES,
  continuous_vars = CONTINUOUS_VARIABLES,
  seed = 42
)


# --- Print Summary Statistics ------------------------------------------------
n_total <- nrow(randomized_data)
n_treatment <- sum(randomized_data$Treatment == 1)
n_control <- sum(randomized_data$Treatment == 0)
n_paired <- sum(randomized_data$Pair_ID >= 0)
n_unpaired <- sum(randomized_data$Pair_ID == -1)
n_pairs <- length(unique(randomized_data$Pair_ID[randomized_data$Pair_ID >= 0]))

cat("\n")
cat(strrep("=", 80), "\n")
cat("MATCHED-PAIRS RANDOMIZATION SUMMARY\n")
cat(strrep("=", 80), "\n")
if (length(CATEGORICAL_VARIABLES) > 0) {
  cat(sprintf("Categorical variables (outer strata): %s\n",
              paste(CATEGORICAL_VARIABLES, collapse = ", ")))
}
cat(sprintf("Continuous variables (matching):      %s\n",
            paste(CONTINUOUS_VARIABLES, collapse = ", ")))
cat(sprintf("Total observations:                   %s\n", format(n_total, big.mark = ",")))
cat(sprintf("Matched pairs:                        %s\n", format(n_pairs, big.mark = ",")))
cat(sprintf("  - Paired units:                     %s\n", format(n_paired, big.mark = ",")))
cat(sprintf("  - Unpaired units (CRE):             %s\n", format(n_unpaired, big.mark = ",")))
cat(sprintf("Assigned to treatment:                %s\n", format(n_treatment, big.mark = ",")))
cat(sprintf("Assigned to control:                  %s\n", format(n_control, big.mark = ",")))
cat(strrep("-", 80), "\n")

# Summary by strata
if (length(CATEGORICAL_VARIABLES) > 0) {
  cat("\nMatching Summary by Stratum:\n")
  cat(strrep("-", 80), "\n")

  strata_summary <- aggregate(
    cbind(Pair_ID, Treatment) ~ Stratum_ID,
    data = randomized_data,
    FUN = function(x) c(
      n_pairs = sum(x >= 0) / 2,
      n_unpaired = sum(x == -1),
      n_treat = sum(x == 1),
      n_ctrl = sum(x == 0)
    )
  )

  for (i in 1:nrow(strata_summary)) {
    stratum_id <- strata_summary$Stratum_ID[i]
    stratum_subset <- randomized_data[randomized_data$Stratum_ID == stratum_id, ]

    n_pairs_stratum <- sum(stratum_subset$Pair_ID >= 0) / 2
    n_treat <- sum(stratum_subset$Treatment == 1)
    n_ctrl <- sum(stratum_subset$Treatment == 0)
    n_unpaired_stratum <- sum(stratum_subset$Pair_ID == -1)

    cat(sprintf("\nStratum: %s\n", stratum_id))
    cat(sprintf("  Pairs:      %s\n", format(n_pairs_stratum, big.mark = ",")))
    cat(sprintf("  Treatment:  %s\n", format(n_treat, big.mark = ",")))
    cat(sprintf("  Control:    %s\n", format(n_ctrl, big.mark = ",")))
    if (n_unpaired_stratum > 0) {
      cat(sprintf("  Unpaired (CRE): %s\n", format(n_unpaired_stratum, big.mark = ",")))
    }
  }
}

cat("\n")
cat(strrep("=", 80), "\n")
cat("\nNote: Matched-pairs design creates pairs of similar units based on\n")
cat("      Mahalanobis distance using continuous variables. Within outer strata\n")
cat("      defined by categorical variables, pairs are matched using a greedy\n")
cat("      algorithm (smallest distance first), and treatment is randomly assigned\n")
cat("      within each pair.\n")
cat("\n")
cat("      Units in strata with odd sizes cannot be paired. These unpaired units\n")
cat("      are assigned to treatment or control using Complete Randomization (CRE).\n")
cat("      They have Pair_ID = -1 to distinguish them from paired units.\n")


# --- Validation: Check Each Pair has 1 Treatment and 1 Control ---------------
cat("\n")
cat(strrep("=", 80), "\n")
cat("PAIR VALIDATION\n")
cat(strrep("=", 80), "\n")

# Check pairs (exclude unpaired units with Pair_ID == -1)
paired_data <- randomized_data[randomized_data$Pair_ID >= 0, ]

if (nrow(paired_data) > 0) {
  # Group by Pair_ID and check treatment assignment
  pair_check <- aggregate(
    cbind(Treatment, Count = Treatment) ~ Pair_ID,
    data = paired_data,
    FUN = function(x) c(Treatment_Sum = sum(x), Pair_Size = length(x))
  )

  # Extract the aggregated values
  treatment_sums <- sapply(pair_check$Treatment, function(x) x[1])
  pair_sizes <- sapply(pair_check$Count, function(x) x[2])

  # Each pair should have exactly 2 units
  bad_size <- sum(pair_sizes != 2)
  if (bad_size > 0) {
    cat(sprintf("❌ ERROR: Found %d pairs with size != 2\n", bad_size))
  } else {
    cat(sprintf("✓ All %d pairs have exactly 2 units\n", nrow(pair_check)))
  }

  # Each pair should have sum(Treatment) == 1 (one 1, one 0)
  bad_treatment <- sum(treatment_sums != 1)
  if (bad_treatment > 0) {
    cat(sprintf("❌ ERROR: Found %d pairs without 1 treatment + 1 control\n", bad_treatment))
  } else {
    cat(sprintf("✓ All %d pairs have exactly 1 treatment and 1 control\n", nrow(pair_check)))
  }
} else {
  cat("⚠ No paired units found\n")
}

cat(strrep("=", 80), "\n")


# --- Balance Table for Debugging ---------------------------------------------
cat("\n")
cat(strrep("=", 80), "\n")
cat("BALANCE TABLE (for debugging)\n")
cat(strrep("=", 80), "\n")

# Get all variables to check (categorical + continuous)
balance_vars <- c(CATEGORICAL_VARIABLES, CONTINUOUS_VARIABLES)

# Calculate means by treatment group
treatment_data <- randomized_data[randomized_data$Treatment == 1, ]
control_data <- randomized_data[randomized_data$Treatment == 0, ]

cat("\nBalance across covariates:\n")
cat(strrep("-", 80), "\n")
cat(sprintf("%-20s %-10s %-10s %-10s %-10s %-10s\n",
            "Variable", "Treat", "Control", "Diff", "Std_Diff", "p-value"))
cat(strrep("-", 80), "\n")

for (var in balance_vars) {
  mean_treat <- mean(treatment_data[[var]], na.rm = TRUE)
  mean_control <- mean(control_data[[var]], na.rm = TRUE)
  diff <- mean_treat - mean_control

  # Calculate standardized difference
  pooled_sd <- sqrt((var(treatment_data[[var]], na.rm = TRUE) +
                     var(control_data[[var]], na.rm = TRUE)) / 2)
  std_diff <- if (pooled_sd > 0) diff / pooled_sd else 0

  # Simple t-test
  t_test <- t.test(treatment_data[[var]], control_data[[var]])
  p_value <- t_test$p.value

  # Significance stars
  sig <- if (p_value < 0.001) "***" else if (p_value < 0.01) "**" else if (p_value < 0.05) "*" else ""

  cat(sprintf("%-20s %-10.3f %-10.3f %-10.3f %-10.3f %-10.4f %s\n",
              var, mean_treat, mean_control, diff, std_diff, p_value, sig))
}

cat(strrep("-", 80), "\n")
cat("\nNote: * p<0.05, ** p<0.01, *** p<0.001\n")
cat("Standardized difference > 0.1 may indicate imbalance\n")
cat(strrep("=", 80), "\n")
cat("\n")


# --- Save Randomized Dataset -------------------------------------------------
# Save to output directory
# TODO: Replace with your desired output filename
output_file <- file.path(output_dir, "matched_pairs_randomized_dataset.dta")
haven::write_dta(randomized_data, output_file)

cat(sprintf("\n✓ Saved to: %s\n\n", output_file))

# =============================================================================
# END OF MATCHED-PAIRS RANDOMIZATION
# =============================================================================
