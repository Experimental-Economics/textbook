// =============================================================================
// Exhibit 5.3: Simple Rules of Thumb for Sample Size by Minimum Detectable Effect
// Continuous Outcomes
// =============================================================================
// Generates a lookup table showing the minimum sample size per group needed
// to detect various effect sizes (expressed as fractions of a standard deviation)
// for continuous outcomes.
//
// For continuous outcomes, the variance ratio simplifies to 1, so Equation 5.8
// reduces to:  N = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2
//
// Outputs: LaTeX table (.tex) and HTML table (.html)
//
// Reference: Chapter 5, Power Analysis - Equation 5.8

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
// For continuous outcomes the variance ratio simplifies to 1, so Equation 5.8
// reduces to:  N = 2 * ((z_{alpha/2} + z_{beta}) / MDE)^2

// Critical values (alpha = 0.05 two-sided, power = 0.80)
scalar z_alpha2 = invnormal(0.975)
scalar z_beta   = invnormal(0.80)


// --- Parameter grid ----------------------------------------------------------
clear
input double mde str6 mde_label
0.02  "1/50"
0.05  "1/20"
0.10  "1/10"
0.20  "1/5"
0.33  "1/3"
0.50  "1/2"
1.00  "1"
end

// Sample size per group (Equation 5.8)
gen double min_size         = 2 * ((z_alpha2 + z_beta) / mde)^2
gen double ceiling_min_size = ceil(min_size)


// --- Build LaTeX table -------------------------------------------------------

local tex_file "`output_dir'/exhibit_5.3.tex"
file open fh using "`tex_file'", write replace

// Header
file write fh                                                                ///
    "\begin{table}[h!]" _n                                                   ///
    "\centering" _n                                                          ///
    "\renewcommand{\arraystretch}{1.6}" _n                                   ///
    "\begin{tabular}{|>{\centering\arraybackslash}m{7.2cm}|"                 ///
    ">{\centering\arraybackslash}m{5.4cm}|}" _n                             ///
    "    \hline" _n                                                          ///
    "    \multicolumn{2}{|>{\centering\arraybackslash}m{12.6cm}|}{%" _n      ///
    "        \textbf{\normalsize Exhibit 5.3: Simple Rules of Thumb "        ///
    "for Sample Size" _n                                                     ///
    "                 by Minimum Detectable Effect}} \\" _n                  ///
    "    \hline" _n                                                          ///
    "    \footnotesize\textbf{\textit{MDE} (in standard deviation units)} &" ///
    _n                                                                       ///
    "    \footnotesize\textbf{\textit{n} (per cell)} \\" _n                  ///
    "    \hline" _n

// Data rows
local n_rows = _N
forvalues i = 1/`n_rows' {
    local lbl   = mde_label[`i']
    local nval  = string(min_size[`i'], "%12.1fc")
    local nceil = string(ceiling_min_size[`i'], "%12.0fc")

    file write fh                                                            ///
        "    \footnotesize $`lbl'$ & "                                       ///
        "\footnotesize `nval' $\approx$ `nceil'  \\" _n                      ///
        "    \hline" _n
}

// Footer with caption
file write fh                                                                ///
    "    \multicolumn{2}{|>{\centering\arraybackslash}m{12.6cm}|}{%" _n      ///
    "        \scriptsize\textit{Note:} Each row shows the minimum sample "   ///
    "size per group" _n                                                      ///
    "        needed to detect the corresponding MDE (in standard deviation " ///
    "units), assuming" _n                                                    ///
    "        a two-sided test with $\alpha = 0.05$ and 80\% power." _n       ///
    "        Based on Equation~5.8: $n = 2\left(\frac{z_{\alpha/2} + "      ///
    "z_{\beta}}" _n                                                          ///
    "        {\textit{MDE}}\right)^{2}$.} \\" _n                             ///
    "    \hline" _n                                                          ///
    "\end{tabular}" _n                                                       ///
    "\end{table}" _n

file close fh


// --- Console output ----------------------------------------------------------
display _newline
display "{hline 80}"
display "EXHIBIT 5.3: Sample Size Rules of Thumb (Continuous Outcomes)"
display "{hline 80}"
display " MDE (SD units)        n (per cell)"
display "{hline 80}"

local n_rows = _N
forvalues i = 1/`n_rows' {
    local lbl   = mde_label[`i']
    local nceil = string(ceiling_min_size[`i'], "%12.0fc")
    display "     `lbl'                  `nceil'"
}

display "{hline 80}"
display "Note: alpha = 0.05 (two-sided), power = 0.80"
display "{hline 80}"


// --- Build HTML table --------------------------------------------------------

local html_file "`output_dir'/exhibit_5.3.html"
file open fh using "`html_file'", write replace

// Head and style
file write fh                                                                ///
    `"<!DOCTYPE html>"' _n                                                   ///
    `"<html>"' _n                                                            ///
    `"<head>"' _n                                                            ///
    `"<meta charset="utf-8">"' _n                                            ///
    `"<title>Exhibit 5.3</title>"' _n                                        ///
    `"<style>"' _n                                                           ///
    `"    body { font-family: 'Helvetica Neue', Arial, sans-serif; "'        ///
    `"margin: 40px; color: #2c3e50; }"' _n                                   ///
    `"    h2 { text-align: center; font-size: 18px; margin-bottom: 4px; }"' _n ///
    `"    table { border-collapse: collapse; margin: 20px auto; }"' _n       ///
    `"    th { background-color: #1a3e82; color: white; padding: 10px 24px;"' ///
    _n                                                                       ///
    `"         font-size: 13px; text-align: center; }"' _n                   ///
    `"    td { padding: 8px 24px; text-align: center; font-size: 13px;"' _n  ///
    `"         border-bottom: 1px solid #ddd; }"' _n                         ///
    `"    tr:hover { background-color: #f0f4fb; }"' _n                       ///
    `"    .note { max-width: 600px; margin: 12px auto; font-size: 11px;"' _n ///
    `"            color: #666; text-align: center; line-height: 1.5; }"' _n  ///
    `"</style>"' _n                                                          ///
    `"</head>"' _n                                                           ///
    `"<body>"' _n                                                            ///
    `"<h2>Exhibit 5.3: Simple Rules of Thumb for Sample Size<br>"' _n        ///
    `"by Minimum Detectable Effect</h2>"' _n                                 ///
    `"<table>"' _n                                                           ///
    `"<thead>"' _n                                                           ///
    `"  <tr><th>MDE (in SD units)</th><th>n (per cell)</th></tr>"' _n        ///
    `"</thead>"' _n                                                          ///
    `"<tbody>"' _n

// Data rows
forvalues i = 1/`n_rows' {
    local lbl   = mde_label[`i']
    local nval  = string(min_size[`i'], "%12.1fc")
    local nceil = string(ceiling_min_size[`i'], "%12.0fc")

    file write fh                                                            ///
        `"  <tr><td>`lbl'</td><td>`nval' &asymp; `nceil'</td></tr>"' _n
}

// Footer with note
file write fh                                                                ///
    `"</tbody>"' _n                                                          ///
    `"</table>"' _n                                                          ///
    `"<p class="note"><em>Note:</em> Each row shows the minimum sample "'    ///
    `"size per group needed to detect the corresponding MDE (in standard "'  ///
    `"deviation units), assuming a two-sided test with &alpha; = 0.05 and "' ///
    `"80% power. Based on Equation 5.8: n = 2 &middot; "'                   ///
    `"((z<sub>&alpha;/2</sub> + z<sub>&beta;</sub>) / MDE)&sup2;.</p>"' _n   ///
    `"</body>"' _n                                                           ///
    `"</html>"' _n

file close fh

display _newline
display "Saved to: `tex_file'"
display "Saved to: `html_file'"


// =============================================================================
// END OF EXHIBIT 5.3 (CONTINUOUS OUTCOMES)
// =============================================================================
