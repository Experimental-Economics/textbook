// =============================================================================
// Exhibit 5.6: Simple Rules of Thumb for Sample Size for Clustered Units
// =============================================================================
// Generates a lookup table showing how intra-cluster correlation (ICC) affects
// the required sample size for cluster-randomized designs.
//
// The design effect multiplies the standard sample size by (1 + (m-1)*rho),
// where m is the cluster size and rho is the ICC.
//
// For each rho value, the table shows:
//   n* = optimal total number of participants
//   k* = n*/m = optimal number of clusters
//
// Assumes: alpha = 0.05 (two-sided), power = 80%, MDE = 0.5*sigma
//
// Outputs: LaTeX table (.tex) and HTML table (.html)
//
// Reference: Chapter 5, Power Analysis - Equation 5.12

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


// --- Core computation -------------------------------------------------------
// Equation 5.12:  n* = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2 * (1 + (m-1)*rho)
//
//   n* = optimal total number of participants
//   k* = n*/m = optimal number of clusters of size m
//
// Constants: alpha = 0.05 (two-sided), power = 80%, MDE = 0.5 SD, sigma = 1

scalar z_alpha2 = invnormal(0.975)
scalar z_beta   = invnormal(0.80)
scalar mde_val  = 0.5
scalar sigma    = 1


// --- Parameter grid ----------------------------------------------------------
clear
input double rho
0
0.25
0.50
0.75
1.00
end

// Compute n* and k* for cluster sizes m = 10 and m = 30
foreach m in 10 30 {
    gen double n_star_`m'    = 2 * ((z_alpha2 + z_beta) / mde_val)^2 * sigma^2 * (1 + (`m' - 1) * rho)
    gen double k_star_`m'    = n_star_`m' / `m'
    gen double n_star_`m'_c  = ceil(n_star_`m')
    gen double k_star_`m'_c  = ceil(k_star_`m')
}


// --- Build LaTeX table -------------------------------------------------------

local tex_file "`output_dir'/exhibit_5.6.tex"
file open fh using "`tex_file'", write replace

// Header
file write fh                                                                ///
    "\begin{table}[h!]" _n                                                   ///
    "\centering" _n                                                          ///
    "\renewcommand{\arraystretch}{2}" _n                                     ///
    "\begin{tabular}{|>{\centering\arraybackslash}m{1.6cm}|"                 ///
    ">{\centering\arraybackslash}m{2.0cm}|"                                  ///
    ">{\centering\arraybackslash}m{5.0cm}|"                                  ///
    ">{\centering\arraybackslash}m{5.0cm}|}" _n                              ///
    "    \hline" _n                                                          ///
    "    \multicolumn{4}{|>{\centering\arraybackslash}m{13.6cm}|}{%" _n      ///
    "        \textbf{Exhibit 5.6: Simple Rules of Thumb for Sample Size" _n  ///
    "                 for Clustered Units}} \\" _n                           ///
    "    \hline" _n                                                          ///
    "    {`=char(36)'\boldsymbol{\rho}`=char(36)'} & "                       ///
    "{`=char(36)'\mathbf{m}`=char(36)'} & "                                  ///
    "{`=char(36)'\mathbf{n^{*}}`=char(36)'} & "                              ///
    "{`=char(36)'\mathbf{k^{*}}`=char(36)'} \\" _n                           ///
    "    \hline" _n

// Data rows: two sub-rows per rho (m = 10 and m = 30)
local n_rows = _N
forvalues i = 1/`n_rows' {
    local rho_val = rho[`i']

    // m = 10 row (first sub-row with multirow rho label)
    local n10   = string(n_star_10[`i'],   "%12.2fc")
    local n10c  = string(n_star_10_c[`i'], "%12.0fc")
    local k10   = string(k_star_10[`i'],   "%12.2fc")
    local k10c  = string(k_star_10_c[`i'], "%12.0fc")

    file write fh                                                            ///
        "    \multirow{2}{*}{`rho_val'}  &  10 "                             ///
        "& `n10' `=char(36)'\approx`=char(36)' `n10c' "                      ///
        "& `k10' `=char(36)'\approx`=char(36)' `k10c' \\ \cline{2-4}" _n

    // m = 30 row (second sub-row, rho cell merged)
    local n30   = string(n_star_30[`i'],   "%12.2fc")
    local n30c  = string(n_star_30_c[`i'], "%12.0fc")
    local k30   = string(k_star_30[`i'],   "%12.2fc")
    local k30c  = string(k_star_30_c[`i'], "%12.0fc")

    file write fh                                                            ///
        "    & 30 "                                                          ///
        "& `n30' `=char(36)'\approx`=char(36)' `n30c' "                      ///
        "& `k30' `=char(36)'\approx`=char(36)' `k30c' \\" _n                 ///
        "    \hline" _n
}

// Footer with caption
file write fh                                                                ///
    "    \multicolumn{4}{|>{\centering\arraybackslash}m{13.6cm}|}{%" _n      ///
    "        \scriptsize\textit{Note:} `=char(36)'n^{*}`=char(36)' is the "  ///
    "optimal total number of" _n                                             ///
    "        participants and `=char(36)'k^{*} = n^{*}/m`=char(36)' is the " ///
    "optimal number of clusters," _n                                         ///
    "        each of size `=char(36)'m`=char(36)'. Assumes a two-sided test " ///
    "with `=char(36)'\alpha = 0.05`=char(36)'," _n                           ///
    "        80\% power, MDE `=char(36)' = 0.5\sigma`=char(36)', and "       ///
    "intra-cluster correlation "                                             ///
    "`=char(36)'\rho`=char(36)'." _n                                         ///
    "        Based on Equation~5.12.} \\" _n                                 ///
    "    \hline" _n                                                          ///
    "\end{tabular}" _n                                                       ///
    "\end{table}" _n

file close fh


// --- Console output ----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 5.6: Sample Size for Clustered Units"
display "{hline 80}"
display " rho       m        n*                k*"
display "{hline 80}"

local n_rows = _N
forvalues i = 1/`n_rows' {
    local rho_val = rho[`i']
    local n10c  = string(n_star_10_c[`i'], "%12.0fc")
    local k10c  = string(k_star_10_c[`i'], "%12.0fc")
    local n30c  = string(n_star_30_c[`i'], "%12.0fc")
    local k30c  = string(k_star_30_c[`i'], "%12.0fc")

    display " `rho_val'      10       `n10c'          `k10c'"
    display "         30       `n30c'          `k30c'"
}

display "{hline 80}"
display "Note: alpha = 0.05, power = 0.80, MDE = 0.5*sigma"
display "{hline 80}"


// --- Build HTML table --------------------------------------------------------

local html_file "`output_dir'/exhibit_5.6.html"
file open fh using "`html_file'", write replace

// Head and style
file write fh                                                                ///
    `"<!DOCTYPE html>"' _n                                                   ///
    `"<html>"' _n                                                            ///
    `"<head>"' _n                                                            ///
    `"<meta charset="utf-8">"' _n                                            ///
    `"<title>Exhibit 5.6</title>"' _n                                        ///
    `"<style>"' _n                                                           ///
    `"    body { font-family: 'Helvetica Neue', Arial, sans-serif; "'        ///
    `"margin: 40px; color: #2c3e50; }"' _n                                   ///
    `"    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }"' _n ///
    `"    table { border-collapse: collapse; margin: 20px auto; }"' _n       ///
    `"    th { background-color: #1a3e82; color: white; padding: 10px 20px;"' ///
    _n                                                                       ///
    `"         font-size: 13px; text-align: center; }"' _n                   ///
    `"    td { padding: 8px 20px; text-align: center; font-size: 13px;"' _n  ///
    `"         border-bottom: 1px solid #ddd; }"' _n                         ///
    `"    tr:hover { background-color: #f0f4fb; }"' _n                       ///
    `"    .group-top td { border-top: 2px solid #999; }"' _n                 ///
    `"    .note { max-width: 650px; margin: 12px auto; font-size: 11px;"' _n ///
    `"            color: #666; text-align: center; line-height: 1.5; }"' _n  ///
    `"</style>"' _n                                                          ///
    `"</head>"' _n                                                           ///
    `"<body>"' _n                                                            ///
    `"<h2>Exhibit 5.6: Simple Rules of Thumb for Sample Size<br>"' _n        ///
    `"for Clustered Units</h2>"' _n                                          ///
    `"<table>"' _n                                                           ///
    `"<thead>"' _n                                                           ///
    `"  <tr><th>&rho;</th><th>m</th><th>n*</th><th>k*</th></tr>"' _n         ///
    `"</thead>"' _n                                                          ///
    `"<tbody>"' _n

// Data rows with rowspan for rho
forvalues i = 1/`n_rows' {
    local rho_val = rho[`i']

    local n10   = string(n_star_10[`i'],   "%12.2fc")
    local n10c  = string(n_star_10_c[`i'], "%12.0fc")
    local k10   = string(k_star_10[`i'],   "%12.2fc")
    local k10c  = string(k_star_10_c[`i'], "%12.0fc")

    local n30   = string(n_star_30[`i'],   "%12.2fc")
    local n30c  = string(n_star_30_c[`i'], "%12.0fc")
    local k30   = string(k_star_30[`i'],   "%12.2fc")
    local k30c  = string(k_star_30_c[`i'], "%12.0fc")

    // m = 10 row (with rowspan rho cell)
    file write fh                                                            ///
        `"  <tr class="group-top"><td rowspan="2">`rho_val'</td>"'           ///
        `"<td>10</td>"'                                                      ///
        `"<td>`n10' &asymp; `n10c'</td>"'                                    ///
        `"<td>`k10' &asymp; `k10c'</td></tr>"' _n

    // m = 30 row
    file write fh                                                            ///
        `"  <tr><td>30</td>"'                                                ///
        `"<td>`n30' &asymp; `n30c'</td>"'                                    ///
        `"<td>`k30' &asymp; `k30c'</td></tr>"' _n
}

// Footer with note
file write fh                                                                ///
    `"</tbody>"' _n                                                          ///
    `"</table>"' _n                                                          ///
    `"<p class="note"><em>Note:</em> n* is the optimal total number of "'    ///
    `"participants and k* = n*/m is the optimal number of clusters, each "'  ///
    `"of size m. Assumes a two-sided test with &alpha; = 0.05, 80% power, "' ///
    `"MDE = 0.5&sigma;, and intra-cluster correlation &rho;. "'              ///
    `"Based on Equation 5.12.</p>"' _n                                       ///
    `"</body>"' _n                                                           ///
    `"</html>"' _n

file close fh

display _newline
display "Saved to: `tex_file'"
display "Saved to: `html_file'"


// =============================================================================
// END OF EXHIBIT 5.6
// =============================================================================
