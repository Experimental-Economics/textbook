// =============================================================================
// Exhibit 5.3: Simple Rules of Thumb for Sample Size by Minimum Detectable Effect
// Binary Outcomes
// =============================================================================
// Generates visualizations (line plot and heatmap) showing the minimum sample
// size per group needed to detect various relative effect sizes for binary
// outcomes, across different baseline probabilities (p-bar).
//
// MDE is defined as the relative change: (p1 - p0) / p0
// where p-bar = (p0 + p1) / 2 is the average probability.
//
// Infeasible combinations (where p1 > 1 or p0 < 0) are marked as missing.
//
// Outputs: Line plot (.pdf) and heatmap (.pdf)
//
// Reference: Chapter 5, Power Analysis - Equation 5.9

clear all
set more off


// --- Setup -------------------------------------------------------------------
// Automatically set working directory to the folder containing this .do file.

local dofile_path "`c(filename)'"

if `"`dofile_path'"' != "" {
    local code_dir = subinstr(`"`dofile_path'"', "\", "/", .)
    local code_dir = reverse(substr(reverse("`code_dir'"), ///
                     strpos(reverse("`code_dir'"), "/") + 1, .))
    quietly cd "`code_dir'"
}

// Create the output folder one level up from code/
local output_dir "../output"
capture mkdir "`output_dir'"


// --- Core program ------------------------------------------------------------
// Computes the minimum sample size *per group* needed to detect a given
// relative MDE at the specified average proportion (p_bar).
//
//   mde_level : relative minimum detectable effect, (p1 - p0) / p0
//   p_bar     : average proportion across treatment and control, (p0 + p1) / 2
//
// Returns the required N per group, or missing (.) when the implied p0 or p1
// falls outside [0, 1] (infeasible for a binary outcome).
//
// Based on Equation 5.9 in the textbook.

capture program drop min_sample_size
program define min_sample_size, rclass

    args mde_level p_bar

    // Derive p0 and p1 from the two-equation system:
    //   p_bar = (p0 + p1) / 2   and   mde_level = (p1 - p0) / p0
    local p0 = (2 * `p_bar') / (2 + `mde_level')
    local p1 = (2 * (1 + `mde_level') * `p_bar') / (2 + `mde_level')

    // Critical values (alpha = 0.05 two-sided, power = 0.80)
    local z_alpha2 = invnormal(1 - 0.05 / 2)
    local z_beta   = invnormal(0.80)

    // Feasibility check
    if (`p1' > 1 | `p0' < 0) {
        return scalar N = .
        exit
    }

    // Sample size per group (Equation 5.9)
    local N = (`z_alpha2' * sqrt(2 * `p_bar' * (1 - `p_bar')) + ///
               `z_beta'   * sqrt(`p0' * (1 - `p0') + `p1' * (1 - `p1')))^2 / (`mde_level'^2)

    return scalar N = `N'

end


// --- Parameter grid ----------------------------------------------------------
local mde_levels   0.01 0.02 0.05 0.10 0.20 0.33 0.50
local p_bar_levels 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9

// Count combinations to size the dataset
local n_mde   : word count `mde_levels'
local n_pbar  : word count `p_bar_levels'
local n_total = `n_mde' * `n_pbar'

// Build dataset with every (p_bar, mde) combination
clear
quietly set obs `n_total'
gen double p_bar           = .
gen double mde             = .
gen double min_sample_size = .

local row = 1
foreach pb of local p_bar_levels {
    foreach m of local mde_levels {
        quietly replace p_bar = `pb' in `row'
        quietly replace mde   = `m'  in `row'

        quietly min_sample_size `m' `pb'
        quietly replace min_sample_size = r(N) in `row'

        local row = `row' + 1
    }
}


// --- Plot 1: Line graph -----------------------------------------------------
// Build one connected-line layer per MDE level, overlaid in a single twoway.

preserve
    quietly drop if missing(min_sample_size)

    // Build the twoway command: one (connected ...) per MDE value
    local line_cmd ""
    local legend_order ""
    local i = 1
    foreach m of local mde_levels {
        local line_cmd `line_cmd' ///
            (connected min_sample_size p_bar if abs(mde - `m') < 0.001, sort)
        local legend_order `legend_order' `i' "MDE = `m'"
        local i = `i' + 1
    }

    twoway `line_cmd',                                                      ///
        xtitle("{stSerif:{it:p}}")                                          ///
        ytitle("Minimum Sample Size (per group)")                           ///
        title("Minimum Sample Size vs. p-bar for Different MDE Levels",     ///
              size(medium))                                                 ///
        xlabel(0.1(0.1)0.9)                                                ///
        ylabel(, format(%12.0fc))                                           ///
        legend(order(`legend_order') cols(1) size(vsmall) position(3))      ///
        graphregion(color(white)) plotregion(color(white))                  ///
        scheme(s2color)

    graph export "`output_dir'/lineplot_exh5.3_binary.pdf", as(pdf) replace

    display _newline
    display "{hline 80}"
    display "EXHIBIT 5.3: Sample Size for Binary Outcomes - Line Plot Saved"
    display "{hline 80}"
    display "Saved to: `output_dir'/lineplot_exh5.3_binary.pdf"
    display "{hline 80}"
restore


// --- Plot 2: Heatmap --------------------------------------------------------
// Stata has no built-in heatmap, so we construct one using:
//   - scatteri polygons for colored tiles
//   - scatter with mlabel for the cell text overlay

preserve
    quietly drop if missing(min_sample_size)

    // Create numeric grid indices for tile positioning
    egen pbar_id = group(p_bar)
    egen mde_id  = group(mde)

    // Format cell labels (matching the R rounding logic)
    gen str20 label = ""
    quietly replace label = string(min_sample_size, "%12.0fc")  if min_sample_size >= 1000
    quietly replace label = string(min_sample_size, "%12.1fc")  if min_sample_size >= 100 & min_sample_size < 1000
    quietly replace label = string(min_sample_size, "%12.2fc")  if min_sample_size >= 10  & min_sample_size < 100
    quietly replace label = string(min_sample_size, "%12.3fc")  if min_sample_size < 10
    quietly replace label = strtrim(label)

    // Normalize sample size to [0, 1] for color interpolation
    quietly summarize min_sample_size, meanonly
    local ss_min = r(min)
    local ss_max = r(max)
    gen double norm_ss = (min_sample_size - `ss_min') / (`ss_max' - `ss_min')

    // Map normalized value to RGB between light blue and dark blue
    //   Low:  #dce6f7 = (220, 230, 247)
    //   High: #1a3e82 = ( 26,  62, 130)
    gen int clr_r = round(220 - norm_ss * (220 - 26))
    gen int clr_g = round(230 - norm_ss * (230 - 62))
    gen int clr_b = round(247 - norm_ss * (247 - 130))

    // Build one colored-tile polygon per cell
    local tile_cmd ""
    local n_obs = _N

    forvalues i = 1/`n_obs' {
        local x  = mde_id[`i']
        local y  = pbar_id[`i']
        local cr = clr_r[`i']
        local cg = clr_g[`i']
        local cb = clr_b[`i']

        local x0 = `x' - 0.48
        local x1 = `x' + 0.48
        local y0 = `y' - 0.48
        local y1 = `y' + 0.48

        local tile_cmd `tile_cmd' ///
            (scatteri `y0' `x0' `y1' `x0' `y1' `x1' `y0' `x1' `y0' `x0', ///
             recast(area) fcolor("`cr' `cg' `cb'") lcolor(white) lwidth(thin))
    }

    // Collect axis labels
    local x_labels ""
    local xi = 1
    foreach v of local mde_levels {
        local x_labels `x_labels' `xi' "`v'"
        local xi = `xi' + 1
    }

    local y_labels ""
    local yi = 1
    foreach v of local p_bar_levels {
        local y_labels `y_labels' `yi' "`v'"
        local yi = `yi' + 1
    }

    // Draw tiles + overlay scatter with cell labels
    twoway `tile_cmd'                                                        ///
        (scatter pbar_id mde_id, msymbol(none) mlabel(label)                 ///
         mlabcolor(black) mlabsize(vsmall) mlabposition(0)),                 ///
        xtitle("MDE")                                                        ///
        ytitle("{stSerif:{it:p}}")                                           ///
        title("Required Sample Size by MDE and p-bar (Binary Outcomes)",     ///
              size(medium))                                                  ///
        xlabel(`x_labels', nogrid)                                           ///
        ylabel(`y_labels', nogrid angle(0))                                  ///
        legend(off)                                                          ///
        graphregion(color(white)) plotregion(color(white))                   ///
        scheme(s2color)                                                      ///
        note("Each cell shows the minimum sample size per group needed to"   ///
             "detect the corresponding MDE at the given p-bar, assuming a"   ///
             "two-sided test with {&alpha} = 0.05 and 80% power (Eq. 5.9)." ///
             "MDE is defined as (p1 - p0) / p0, where p-bar = (p0 + p1)/2." ///
             "Gray cells indicate infeasible combinations (p1 > 1 or p0 < 0).", ///
             size(vsmall) color(gs8))

    graph export "`output_dir'/heatmap_exh5.3_binary.pdf", as(pdf) replace

    display _newline
    display "{hline 80}"
    display "EXHIBIT 5.3: Sample Size for Binary Outcomes - Heatmap Saved"
    display "{hline 80}"
    display "Saved to: `output_dir'/heatmap_exh5.3_binary.pdf"
    display "Note: Gray cells indicate infeasible combinations (p1 > 1 or p0 < 0)"
    display "{hline 80}"
restore


// =============================================================================
// END OF EXHIBIT 5.3 (BINARY OUTCOMES)
// =============================================================================
