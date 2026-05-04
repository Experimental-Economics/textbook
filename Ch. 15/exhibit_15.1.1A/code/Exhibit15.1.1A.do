// =============================================================================
// Exhibit 15.1.1A: PSP as a Function of Number of Replications
// Generates two-panel figure showing PSP under different replication scenarios
// =============================================================================

clear all
set more off


// --- Setup -------------------------------------------------------------------
// IMPORTANT: Set your working directory to the folder containing this script
// In Stata: cd "[your path]/Ch. 15/exhibit_15.1.1A/code"

// Define paths relative to the script location
local output_dir "../output"

// Create the output folder
capture mkdir "`output_dir'"


// --- Parameters --------------------------------------------------------------
scalar alpha = 0.05
scalar n = 10
scalar v = 0.3
scalar omega = 0.4
scalar pi0 = 0.5
scalar phi = 0.33
scalar psi = 0.33

// Create dataset with replication values (1 to 10)
clear
set obs 10
gen r = _n


// --- Core functions ----------------------------------------------------------
// Computes PSP for unbiased replication.
//
// Inputs:
//   r       : Variable containing number of successful replications
//   beta    : Type II error rate (1 - power)
//   varname : Name for output variable
//
// Based on binomial probabilities under true and false hypotheses.

program define calc_psp_unbiased
    args r beta varname

    quietly {
        gen b_true = comb(n, `r') * (1 - `beta')^`r' * `beta'^(n - `r')
        gen b_false = comb(n, `r') * alpha^`r' * (1 - alpha)^(n - `r')
        gen `varname' = (b_true * pi0) / (b_true * pi0 + b_false * (1 - pi0))
        drop b_true b_false
    }
end


// Computes PSP for sympathetic replication.
//
// Inputs:
//   r       : Variable containing number of successful replications
//   beta    : Type II error rate (1 - power)
//   varname : Name for output variable
//
// Based on Equation A15.1.3 with pure sympathetic bias v.
// Successful replication probability is (1-beta) + beta*v.

program define calc_psp_sympathetic
    args r beta varname

    quietly {
        gen p_success_true = (1 - `beta') + `beta' * v
        gen p_success_false = alpha + (1 - alpha) * v
        gen b_true = comb(n, `r') * p_success_true^`r' * (1 - p_success_true)^(n - `r')
        gen b_false = comb(n, `r') * p_success_false^`r' * (1 - p_success_false)^(n - `r')
        gen `varname' = (pi0 * b_true) / (pi0 * b_true + (1 - pi0) * b_false)
        drop p_success_true p_success_false b_true b_false
    }
end


// Computes PSP for adversarial replication.
//
// Inputs:
//   r       : Variable containing number of successful replications
//   beta    : Type II error rate (1 - power)
//   varname : Name for output variable
//
// Adversarial replication reduces success probability by factor (1 - omega).

program define calc_psp_adversarial
    args r beta varname

    quietly {
        gen gamma1 = (1 - `beta') * (1 - omega)
        gen gamma2 = alpha * (1 - omega)
        gen b_true = comb(n, `r') * gamma1^`r' * (1 - gamma1)^(n - `r')
        gen b_false = comb(n, `r') * gamma2^`r' * (1 - gamma2)^(n - `r')
        gen `varname' = (b_true * pi0) / (b_true * pi0 + b_false * (1 - pi0))
        drop gamma1 gamma2 b_true b_false
    }
end


// Computes PSP for heterogeneous replication.
//
// Inputs:
//   r       : Variable containing number of successful replications
//   beta    : Type II error rate (1 - power)
//   varname : Name for output variable
//
// Based on Equation A15.1.5: weighted mixture of phi fraction sympathetic,
// psi fraction adversarial, and (1-phi-psi) fraction neutral.

program define calc_psp_heterogeneous
    args r beta varname

    quietly {
        gen chi1 = phi * ((1 - `beta') + `beta' * v) + ///
                   psi * ((1 - `beta') * (1 - omega)) + ///
                   (1 - phi - psi) * (1 - `beta')
        gen chi2 = phi * (alpha + (1 - alpha) * v) + ///
                   psi * (alpha * (1 - omega)) + ///
                   (1 - phi - psi) * alpha
        gen b_chi1 = comb(n, `r') * chi1^`r' * (1 - chi1)^(n - `r')
        gen b_chi2 = comb(n, `r') * chi2^`r' * (1 - chi2)^(n - `r')
        gen `varname' = (pi0 * b_chi1) / (pi0 * b_chi1 + (1 - pi0) * b_chi2)
        drop chi1 chi2 b_chi1 b_chi2
    }
end


// --- Compute PSP values ------------------------------------------------------
// Calculate PSP values for beta = 0.3
calc_psp_adversarial r 0.3 psp_adv_03
calc_psp_unbiased r 0.3 psp_unb_03
calc_psp_heterogeneous r 0.3 psp_het_03
calc_psp_sympathetic r 0.3 psp_symp_03

// Calculate PSP values for beta = 0.8
calc_psp_adversarial r 0.8 psp_adv_08
calc_psp_unbiased r 0.8 psp_unb_08
calc_psp_heterogeneous r 0.8 psp_het_08
calc_psp_sympathetic r 0.8 psp_symp_08


// --- Plot generation ---------------------------------------------------------
// Create two-panel graph with left panel (beta = 0.3) and right panel (beta = 0.8)

#delimit ;
graph twoway
    (connected psp_symp_03 r,
        lpattern(longdash) lwidth(medium) lcolor(gs8)
        msize(medium) msymbol(diamond) mcolor(gs8) mfcolor(white) mlwidth(thin))
    (connected psp_adv_03 r,
        lpattern(shortdash) lwidth(medium) lcolor(black)
        msize(medium) msymbol(square) mcolor(black) mfcolor(white) mlwidth(thin))
    (connected psp_unb_03 r,
        lpattern(solid) lwidth(medthick) lcolor(black)
        msize(medium) msymbol(circle) mcolor(black) mfcolor(black))
    (connected psp_het_03 r,
        lpattern(dot) lwidth(medium) lcolor(gs6)
        msize(medium) msymbol(triangle) mcolor(gs6) mfcolor(white) mlwidth(thin)),
    xlabel(1(1)10, labsize(small))
    ylabel(0(0.25)1, labsize(small) angle(0) format(%3.2f))
    xtitle("Number of successful replications out of 10 attempts", size(small))
    ytitle("PSP{subscript:rep}", size(small))
    xscale(range(0.8 10.2))
    yscale(range(0 1))
    title("{&beta} = 0.3", size(medium) position(6) ring(5))
    legend(order(2 "Adversarial" 3 "Unbiased" 4 "Heterogeneous" 1 "Sympathetic")
        position(5) ring(0) cols(1) size(vsmall) region(lcolor(white) fcolor(none))
        symxsize(5) rowgap(0.5))
    graphregion(color(white) margin(small))
    plotregion(lcolor(black) margin(small) style(none))
    name(panel1, replace)
    ;

graph twoway
    (connected psp_symp_08 r,
        lpattern(longdash) lwidth(medium) lcolor(gs8)
        msize(medium) msymbol(diamond) mcolor(gs8) mfcolor(white) mlwidth(thin))
    (connected psp_adv_08 r,
        lpattern(shortdash) lwidth(medium) lcolor(black)
        msize(medium) msymbol(square) mcolor(black) mfcolor(white) mlwidth(thin))
    (connected psp_unb_08 r,
        lpattern(solid) lwidth(medthick) lcolor(black)
        msize(medium) msymbol(circle) mcolor(black) mfcolor(black))
    (connected psp_het_08 r,
        lpattern(dot) lwidth(medium) lcolor(gs6)
        msize(medium) msymbol(triangle) mcolor(gs6) mfcolor(white) mlwidth(thin)),
    xlabel(1(1)10, labsize(small))
    ylabel(0(0.25)1, labsize(small) angle(0) format(%3.2f))
    xtitle("Number of successful replications out of 10 attempts", size(small))
    ytitle("PSP{subscript:rep}", size(small))
    xscale(range(0.8 10.2))
    yscale(range(0 1))
    title("{&beta} = 0.8", size(medium) position(6) ring(5))
    legend(order(2 "Adversarial" 3 "Unbiased" 4 "Heterogeneous" 1 "Sympathetic")
        position(5) ring(0) cols(1) size(vsmall) region(lcolor(white) fcolor(none))
        symxsize(5) rowgap(0.5))
    graphregion(color(white) margin(small))
    plotregion(lcolor(black) margin(small) style(none))
    name(panel2, replace)
    ;

// Combine the two panels
graph combine panel1 panel2,
    cols(2) imargin(small)
    title("Exhibit 15.1.1A: {it:PSP} as a Function of Number of Replications out of 10 Attempts",
        size(medium) span position(12))
    graphregion(color(white) margin(small))
    ;
#delimit cr


// --- Save output -------------------------------------------------------------
graph export "`output_dir'/Exhibit15_1_1A_Stata.png", as(png) replace width(4200) height(2100)
display "Saved to: `output_dir'/Exhibit15_1_1A_Stata.png"
