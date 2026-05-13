/*==============================================================================
  Live-Streaming Commerce & Impulse Purchase Behavior
  ── Full Analytical Pipeline ──
  ==============================================================================
  Data:         merged_panel.dta  (T1–T2 matched panel, n = 219)
  Attrition:    t1_attrition.dta  (all T1 respondents, n = 497)
  Output:       results/          (log · RTF tables · figures)

  Prerequisite: ssc install estout   (run once)
  ==============================================================================*/

clear all
set more off
set seed 2026

* ━━ Setup ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
capture mkdir "results"
capture log close _all
log using "results/analysis_log.smcl", replace name(main)

display _n "{hline 72}"
display "  Analysis Pipeline — $S_DATE $S_TIME"
display "{hline 72}"

* ━━ Load & Inspect ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
use "merged_panel.dta", clear
describe, short
summarize

/*----------------------------------------------------------------------
  SECTION 1: DATA PREPARATION & COMPOSITE CONSTRUCTION
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 1: Data Preparation"
display "{hline 72}"

* 1.0 Data cleaning — income sentinel value
replace income = . if income == 99

* 1.1 Reverse-code items
* SC reverse items: SC2,3,4,5,7,9,10,12,13
foreach v in SC2 SC3 SC4 SC5 SC7 SC9 SC10 SC12 SC13 {
    gen `v'_r = 8 - `v'
}
* IBT reverse item: IBT8
gen IBT8_r = 8 - IBT8
* MA reverse: MA2, MA2_T2
gen MA2_r = 8 - MA2
gen MA2_T2_r = 8 - MA2_T2
* TA reverse: TA2, TA2_T2
gen TA2_r = 8 - TA2
gen TA2_T2_r = 8 - TA2_T2

* 1.2 Compute scale composites (T1)
* IBT mean (using recoded IBT8)
egen IBT_mean = rowmean(IBT1 IBT2 IBT3 IBT4 IBT5 IBT6 IBT7 IBT8_r IBT9)

* SC mean (using recoded reverse items)
egen SC_mean = rowmean(SC1 SC2_r SC3_r SC4_r SC5_r SC6 SC7_r SC8 SC9_r SC10_r SC11 SC12_r SC13_r)

* SE mean
egen SE_mean = rowmean(SE1 SE2 SE3 SE4)

* SII mean
egen SII_mean = rowmean(SII1 SII2 SII3 SII4)

* FoMO mean
egen FOMO_mean = rowmean(FOMO1 FOMO2 FOMO3)

* 1.3 Compute scale composites (T2)
* Exposure composite (sum of exposure items)
egen Exposure_T2 = rowtotal(EXP1_T2 EXP2_T2 EXP3_T2 EXP4_T2 EXP5_T2 EXP6_T2 EXP7_T2 EXP8_T2)

* Perceived Scarcity
egen PS_T2 = rowmean(PS1_T2 PS2_T2 PS3_T2 PS4_T2 PS5_T2)

* Parasocial Interaction
egen PSI_T2 = rowmean(PSI1_T2 PSI2_T2 PSI3_T2 PSI4_T2 PSI5_T2)

* Emotional Arousal
egen EA_T2 = rowmean(EA1_T2 EA2_T2 EA3_T2 EA4_T2)

* Social Proof
egen SP_T2 = rowmean(SP1_T2 SP2_T2 SP3_T2 SP4_T2)

* IPB Likert composite (items 4-6)
egen IPB_Likert_T2 = rowmean(IPB4_T2 IPB5_T2 IPB6_T2)

* 1.4 Control composites (T2)
egen MA_T2_mean = rowmean(MA1_T2 MA2_T2_r MA3_T2)
egen TA_T2_mean = rowmean(TA1_T2 TA2_T2_r TA3_T2)

* 1.5 Binary exposure indicator (median split for PSM)
summarize Exposure_T2, detail
gen Exposure_binary = (Exposure_T2 > r(p50))

* 1.6 Mean-centre moderators for interaction terms
summarize IBT_mean
gen IBT_c = IBT_mean - r(mean)
summarize SC_mean
gen SC_c = SC_mean - r(mean)

/*----------------------------------------------------------------------
  SECTION 2: DESCRIPTIVE STATISTICS
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 2: Descriptive Statistics"
display "{hline 72}"

* 2.1 Table 1 descriptives → Word
dtable age i.gender i.education i.occupation income i.relationship ///
       IBT_mean SC_mean SE_mean SII_mean FOMO_mean ///
       IPB1 Exposure_T2 ///
       PS_T2 PSI_T2 EA_T2 SP_T2 IPB1_T2, ///
       title("Table 1: Descriptive Statistics") ///
       export("results/Table1_descriptives.docx", replace)

* 2.2 Correlation matrix → Excel
correlate Exposure_T2 PS_T2 PSI_T2 EA_T2 SP_T2 IPB1_T2 ///
          IBT_mean SC_mean IPB1

quietly correlate Exposure_T2 PS_T2 PSI_T2 EA_T2 SP_T2 IPB1_T2 ///
                  IBT_mean SC_mean IPB1
matrix C = r(C)
putexcel set "results/Table2_correlations.xlsx", replace
putexcel A1 = matrix(C), names nformat(number_d2)

* 2.3 DV distribution check
summarize IPB1_T2, detail
histogram IPB1_T2, discrete frequency ///
    title("Distribution of Impulse Purchase Behavior (T2)") ///
    xtitle("Number of impulse purchases") ///
    ytitle("Frequency") ///
    color(navy%70) lcolor(navy)
graph export "results/Fig1_IPB_distribution.png", replace width(1600)

/*----------------------------------------------------------------------
  SECTION 3: MEASUREMENT VALIDATION
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 3: Measurement Validation"
display "{hline 72}"

* 3.1 Cronbach's Alpha
display _n "--- Cronbach's Alpha ---"

* IBT (with reverse-coded IBT8)
alpha IBT1 IBT2 IBT3 IBT4 IBT5 IBT6 IBT7 IBT8_r IBT9, item

* SC (with reverse-coded items)
alpha SC1 SC2_r SC3_r SC4_r SC5_r SC6 SC7_r SC8 SC9_r SC10_r SC11 SC12_r SC13_r, item

* SE
alpha SE1 SE2 SE3 SE4, item

* SII
alpha SII1 SII2 SII3 SII4, item

* FoMO
alpha FOMO1 FOMO2 FOMO3, item

* T2 scales
alpha PS1_T2 PS2_T2 PS3_T2 PS4_T2 PS5_T2, item
alpha PSI1_T2 PSI2_T2 PSI3_T2 PSI4_T2 PSI5_T2, item
alpha EA1_T2 EA2_T2 EA3_T2 EA4_T2, item
alpha SP1_T2 SP2_T2 SP3_T2 SP4_T2, item
alpha IPB4_T2 IPB5_T2 IPB6_T2, item

* 3.2 Exploratory Factor Analysis (T2 mediators)
display _n "--- EFA: T2 Mediators ---"
factor PS1_T2 PS2_T2 PS3_T2 PS4_T2 PS5_T2 ///
       PSI1_T2 PSI2_T2 PSI3_T2 PSI4_T2 PSI5_T2 ///
       EA1_T2 EA2_T2 EA3_T2 EA4_T2 ///
       SP1_T2 SP2_T2 SP3_T2 SP4_T2, ///
       factors(4) pcf
rotate, varimax
estat kmo

/*----------------------------------------------------------------------
  SECTION 4: H1 — TOTAL EFFECT
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 4: H1 — Total Effect of Exposure on IPB"
display "{hline 72}"

* 4.1 Primary specification: ANCOVA with robust SE
regress IPB1_T2 Exposure_T2 IPB1 ///
        IBT_mean SC_mean SE_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store h1_primary

* Check VIF
estat vif

* 4.2 Robustness: Likert composite DV
regress IPB_Likert_T2 Exposure_T2 IPB1 ///
        IBT_mean SC_mean SE_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store h1_likert

* 4.3 Robustness: Poisson regression for count DV
poisson IPB1_T2 Exposure_T2 IPB1 ///
        IBT_mean SC_mean SE_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store h1_poisson

* 4.4 Robustness: Negative binomial
nbreg IPB1_T2 Exposure_T2 IPB1 ///
      IBT_mean SC_mean SE_mean age i.gender ///
      MA_T2_mean TA_T2_mean MOOD1_T2, ///
      vce(robust)
estimates store h1_nbreg

* ── Export Table 3 ──
esttab h1_primary h1_likert h1_poisson h1_nbreg ///
    using "results/Table3_H1_total_effect.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    starlevels(* 0.05 ** 0.01 *** 0.001) ///
    stats(N r2 aic bic, fmt(0 3 1 1) ///
        labels("Observations" "R\super 2" "AIC" "BIC")) ///
    title("Table 3: Total Effect of Exposure on Impulse Purchase Behavior") ///
    mtitles("OLS" "Likert DV" "Poisson" "Neg. Binomial") ///
    addnotes("Robust standard errors in parentheses." ///
             "All models control for T1 baseline (IPB1), personality traits, and demographics." ///
             "{\i * p < .05, ** p < .01, *** p < .001}") ///
    nonotes label

/*----------------------------------------------------------------------
  SECTION 5: H2a–d — PARALLEL MEDIATION
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 5: H2 — Parallel Mediation Analysis"
display "{hline 72}"

* 5.1 a-paths: Exposure → each mediator
foreach med in PS_T2 PSI_T2 EA_T2 SP_T2 {
    regress `med' Exposure_T2 IPB1 IBT_mean SC_mean age i.gender, vce(robust)
    estimates store a_`med'
}

* 5.2 b-paths: All mediators + exposure → IPB (outcome model)
regress IPB1_T2 Exposure_T2 PS_T2 PSI_T2 EA_T2 SP_T2 ///
        IPB1 IBT_mean SC_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store outcome_model

* ── Export Table 4 ──
esttab a_PS_T2 a_PSI_T2 a_EA_T2 a_SP_T2 outcome_model ///
    using "results/Table4_H2_mediation_paths.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    starlevels(* 0.05 ** 0.01 *** 0.001) ///
    stats(N r2, fmt(0 3) labels("Observations" "R\super 2")) ///
    title("Table 4: Mediation Analysis — a-Paths and Outcome Model") ///
    mtitles("a: PS" "a: PSI" "a: EA" "a: SP" "Outcome") ///
    addnotes("Robust standard errors in parentheses." ///
             "a-paths: Exposure → Mediator, controlling for T1 covariates." ///
             "Outcome: All mediators entered simultaneously." ///
             "{\i * p < .05, ** p < .01, *** p < .001}") ///
    nonotes label

* 5.3 Bootstrap indirect effects
capture program drop boot_mediation
program define boot_mediation, rclass
    * a-paths
    quietly regress PS_T2 Exposure_T2 IPB1 IBT_mean SC_mean age i.gender
    local a1 = _b[Exposure_T2]
    quietly regress PSI_T2 Exposure_T2 IPB1 IBT_mean SC_mean age i.gender
    local a2 = _b[Exposure_T2]
    quietly regress EA_T2 Exposure_T2 IPB1 IBT_mean SC_mean age i.gender
    local a3 = _b[Exposure_T2]
    quietly regress SP_T2 Exposure_T2 IPB1 IBT_mean SC_mean age i.gender
    local a4 = _b[Exposure_T2]

    * b-paths (outcome model)
    quietly regress IPB1_T2 Exposure_T2 PS_T2 PSI_T2 EA_T2 SP_T2 ///
            IPB1 IBT_mean SC_mean age i.gender ///
            MA_T2_mean TA_T2_mean MOOD1_T2
    local b1 = _b[PS_T2]
    local b2 = _b[PSI_T2]
    local b3 = _b[EA_T2]
    local b4 = _b[SP_T2]

    * Indirect effects
    return scalar ind_PS  = `a1' * `b1'
    return scalar ind_PSI = `a2' * `b2'
    return scalar ind_EA  = `a3' * `b3'
    return scalar ind_SP  = `a4' * `b4'
    return scalar ind_total = `a1'*`b1' + `a2'*`b2' + `a3'*`b3' + `a4'*`b4'
end

bootstrap ///
    ind_PS  = r(ind_PS)  ///
    ind_PSI = r(ind_PSI) ///
    ind_EA  = r(ind_EA)  ///
    ind_SP  = r(ind_SP)  ///
    ind_total = r(ind_total), ///
    reps(5000) seed(2026) nodots: boot_mediation

estat bootstrap, percentile

* ── Export Table 5 ──
esttab . using "results/Table5_H2_bootstrap_indirect.rtf", replace ///
    cells(b(star fmt(4)) ci_l(fmt(4)) ci_u(fmt(4))) ///
    starlevels(* 0.05 ** 0.01 *** 0.001) ///
    title("Table 5: Bootstrap Indirect Effects (5,000 replications)") ///
    addnotes("Percentile bootstrap 95% confidence intervals." ///
             "Indirect effect significant if CI excludes zero." ///
             "{\i * p < .05, ** p < .01, *** p < .001}") ///
    nonotes label

/*----------------------------------------------------------------------
  SECTION 6: H3a–b — MODERATED MEDIATION
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 6: H3 — Moderated Mediation"
display "{hline 72}"

* 6.1 H3a: IBT moderates mediator → IPB paths
* NOTE: Main effects specified explicitly once; interactions via #
*       (avoids collinearity notes from ## repeating IBT_c)
regress IPB1_T2 c.Exposure_T2 ///
        c.PS_T2 c.PSI_T2 c.EA_T2 c.SP_T2 ///
        c.IBT_c ///
        c.PS_T2#c.IBT_c c.PSI_T2#c.IBT_c ///
        c.EA_T2#c.IBT_c c.SP_T2#c.IBT_c ///
        IPB1 SC_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store h3a

* Probe interactions at ±1 SD IBT
summarize IBT_c
local ibt_lo = -r(sd)
local ibt_hi = r(sd)
margins, dydx(PS_T2) at(IBT_c = (`ibt_lo' `ibt_hi'))
margins, dydx(PSI_T2) at(IBT_c = (`ibt_lo' `ibt_hi'))

display _n "=== H3b: Self-Control moderates b-paths ==="

* 6.2 H3b: SC moderates mediator → IPB paths
regress IPB1_T2 c.Exposure_T2 ///
        c.PS_T2 c.PSI_T2 c.EA_T2 c.SP_T2 ///
        c.SC_c ///
        c.PS_T2#c.SC_c c.PSI_T2#c.SC_c ///
        c.EA_T2#c.SC_c c.SP_T2#c.SC_c ///
        IPB1 IBT_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store h3b

* ── Export Table 6 ──
esttab h3a h3b ///
    using "results/Table6_H3_moderation.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    starlevels(* 0.05 ** 0.01 *** 0.001) ///
    stats(N r2, fmt(0 3) labels("Observations" "R\super 2")) ///
    title("Table 6: Moderated Mediation — Interaction Effects") ///
    mtitles("H3a: IBT Moderator" "H3b: SC Moderator") ///
    addnotes("Robust standard errors in parentheses." ///
             "Moderators are mean-centred; interactions use single # operator." ///
             "{\i * p < .05, ** p < .01, *** p < .001}") ///
    nonotes label

/*----------------------------------------------------------------------
  SECTION 7: ROBUSTNESS — PROPENSITY SCORE ANALYSIS
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 7: Robustness — Propensity Score Methods"
display "{hline 72}"

* 7.1 PSM — Nearest-Neighbour Matching
* All demographics as ordinal to preserve overlap with n = 219
teffects psmatch (IPB1_T2) ///
    (Exposure_binary IBT_mean SC_mean SE_mean SII_mean ///
     age gender education occupation income relationship IPB1 FOMO_mean), ///
    atet nn(1)
estimates store psm_att

* Balance diagnostics
tebalance summarize
tebalance density
graph export "results/Fig2_PSM_balance.png", replace width(1600)

* 7.2 Inverse Probability Weighting (IPW)
teffects ipw (IPB1_T2) ///
    (Exposure_binary IBT_mean SC_mean SE_mean SII_mean ///
     age gender education occupation income relationship IPB1 FOMO_mean), ///
    atet
estimates store ipw_att

* ── Export Table 7 ──
esttab psm_att ipw_att ///
    using "results/Table7_PSM_IPW.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    starlevels(* 0.05 ** 0.01 *** 0.001) ///
    stats(N, fmt(0) labels("Observations")) ///
    title("Table 7: Robustness — PSM and IPW Estimates (ATET)") ///
    mtitles("PSM (NN = 1)" "IPW") ///
    addnotes("ATET: Average Treatment Effect on the Treated." ///
             "Treatment = above-median Exposure (binary)." ///
             "{\i * p < .05, ** p < .01, *** p < .001}") ///
    nonotes label

* 7.3 Generalized Propensity Score (GPS) — Continuous Treatment
* Hirano & Imbens (2004): preserves full variation in Exposure_T2
display _n "=== GPS: Continuous Exposure ==="

* Step 1: Treatment model — E[Exposure_T2 | X]
quietly regress Exposure_T2 IBT_mean SC_mean SE_mean SII_mean ///
    age gender education occupation income relationship IPB1 FOMO_mean
predict double gps_mu, xb
local gps_sigma = e(rmse)
display "Treatment model R² = " %5.3f e(r2) "  σ = " %5.3f `gps_sigma'

* Step 2: GPS = φ(T; μ(X), σ)
gen double gps = normalden(Exposure_T2, gps_mu, `gps_sigma')
label var gps "Generalized Propensity Score"
summarize gps, detail

* Step 3: Dose-response — without vs. with GPS adjustment
regress IPB1_T2 Exposure_T2 ///
    IPB1 IBT_mean SC_mean SE_mean age gender ///
    MA_T2_mean TA_T2_mean MOOD1_T2, vce(robust)
estimates store gps_naive

regress IPB1_T2 Exposure_T2 gps c.Exposure_T2#c.gps ///
    IPB1 IBT_mean SC_mean SE_mean age gender ///
    MA_T2_mean TA_T2_mean MOOD1_T2, vce(robust)
estimates store gps_adjusted

* ── Export Table 8 ──
esttab gps_naive gps_adjusted ///
    using "results/Table8_GPS_dose_response.rtf", replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    starlevels(* 0.05 ** 0.01 *** 0.001) ///
    stats(N r2, fmt(0 3) labels("Observations" "R\super 2")) ///
    title("Table 8: Robustness — Generalized Propensity Score") ///
    mtitles("Without GPS" "GPS-Adjusted") ///
    addnotes("Robust standard errors in parentheses." ///
             "GPS following Hirano & Imbens (2004); normality-based density." ///
             "{\i * p < .05, ** p < .01, *** p < .001}") ///
    nonotes label

* Marginal effect at mean GPS
quietly estimates restore gps_adjusted
margins, dydx(Exposure_T2) atmeans

* Clean up
drop gps_mu gps

/*----------------------------------------------------------------------
  SECTION 8: ROBUSTNESS — E-VALUE SENSITIVITY
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 8: E-Value Sensitivity Analysis"
display "{hline 72}"

* Compute E-value from primary regression coefficient
* Using point estimate and CI lower bound from H1
estimates restore h1_primary
local b_exp = _b[Exposure_T2]
local se_exp = _se[Exposure_T2]
local ci_lo = `b_exp' - 1.96 * `se_exp'

* RR ≈ exp(0.91 * β / SD_Y) per VanderWeele & Ding (2017)
quietly summarize IPB1_T2
local sd_y = r(sd)
local RR = exp(0.91 * `b_exp' / `sd_y')
local E_point = `RR' + sqrt(`RR' * (`RR' - 1))
local RR_lo = exp(0.91 * `ci_lo' / `sd_y')
local E_ci = `RR_lo' + sqrt(`RR_lo' * (`RR_lo' - 1))

display _n "E-value (point estimate): " %6.3f `E_point'
display "E-value (CI lower bound): " %6.3f `E_ci'

/*----------------------------------------------------------------------
  SECTION 9: ATTRITION ANALYSIS
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 9: Attrition Analysis"
display "{hline 72}"

* Load T1-only data with completed_t2 flag
preserve
use "t1_attrition.dta", clear

display _n "Attrition summary:"
tabulate completed_t2

* Compare completers vs. dropouts on key T1 variables
foreach v in age IBT1 SC1 SE1 EXP5 IPB1 {
    display _n "`v':"
    ttest `v', by(completed_t2)
}

tabulate gender completed_t2, chi2
tabulate education completed_t2, chi2
restore

/*----------------------------------------------------------------------
  SECTION 10: COMMON METHOD VARIANCE
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  SECTION 10: Common Method Variance Check"
display "{hline 72}"

* Correlation of marker variable with focal constructs
correlate MV1_T2 PS_T2 PSI_T2 EA_T2 SP_T2 IPB1_T2

* Harman's single-factor test (T2 mediator items)
factor PS1_T2 PS2_T2 PS3_T2 PS4_T2 PS5_T2 ///
       PSI1_T2 PSI2_T2 PSI3_T2 PSI4_T2 PSI5_T2 ///
       EA1_T2 EA2_T2 EA3_T2 EA4_T2 ///
       SP1_T2 SP2_T2 SP3_T2 SP4_T2 ///
       IPB4_T2 IPB5_T2 IPB6_T2, ///
       factors(1) pcf
* Check: first factor should explain < 50% of total variance

/*----------------------------------------------------------------------
  PIPELINE COMPLETE
----------------------------------------------------------------------*/
display _n "{hline 72}"
display "  PIPELINE COMPLETE — $S_DATE $S_TIME"
display "{hline 72}"
display _n "Output directory: results/"
display "  Tables:  Table1–8 (.docx / .xlsx / .rtf)"
display "  Figures: Fig1–2   (.png)"
display "  Log:     analysis_log (.smcl / .pdf / .txt)"

* ── Close log & convert ──
log close main
translate "results/analysis_log.smcl" "results/analysis_log.pdf", replace
translate "results/analysis_log.smcl" "results/analysis_log.txt", replace
