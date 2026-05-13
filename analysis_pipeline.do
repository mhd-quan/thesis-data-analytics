/*==============================================================================
  PIPELINE TEST: Live-Streaming Commerce & Impulse Purchase Behavior
  ==============================================================================
  Purpose: Test full Stata 19 analytical pipeline with real panel data.
  Data:    merged_panel.dta (merged T1-T2)

  ==============================================================================*/

clear all
set more off
set seed 2026

* --- Load panel data ---
use "merged_panel.dta", clear
describe, short
summarize

/*----------------------------------------------------------------------
  SECTION 1: DATA PREPARATION & COMPOSITE CONSTRUCTION
----------------------------------------------------------------------*/

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

* Money/Time availability (T1)
egen MA_mean = rowmean(MA1 MA2_r MA3)
egen TA_mean = rowmean(TA1 TA2_r TA3)

* 1.3 Compute T2 exposure composite index
* Step 1: z-scores of components
egen EXP5_T2_z = std(EXP5_T2)
gen ln_EXP2_T2 = ln(EXP2_T2 + 1)
egen ln_EXP2_T2_z = std(ln_EXP2_T2)
egen EXP3_T2_z = std(EXP3_T2)

* Step 2: Weighted composite (0.40, 0.30, 0.30)
gen Exposure_T2 = 0.40 * EXP5_T2_z + 0.30 * ln_EXP2_T2_z + 0.30 * EXP3_T2_z
label var Exposure_T2 "T2 Exposure Composite Index"

* 1.4 Compute T2 mediator composites
egen PS_T2 = rowmean(PS1_T2 PS2_T2 PS3_T2 PS4_T2 PS5_T2)
egen PSI_T2 = rowmean(PSI1_T2 PSI2_T2 PSI3_T2 PSI4_T2 PSI5_T2)
egen EA_T2 = rowmean(EA1_T2 EA2_T2 EA3_T2 EA4_T2)
egen SP_T2 = rowmean(SP1_T2 SP2_T2 SP3_T2 SP4_T2)

* 1.5 Compute T2 robustness DV (Likert composite)
egen IPB_Likert_T2 = rowmean(IPB4_T2 IPB5_T2 IPB6_T2)

* 1.6 T2 time-varying controls
egen MA_T2_mean = rowmean(MA1_T2 MA2_T2_r MA3_T2)
egen TA_T2_mean = rowmean(TA1_T2 TA2_T2_r TA3_T2)

* 1.7 Mean-center moderators for interaction terms
summarize IBT_mean, meanonly
gen IBT_c = IBT_mean - r(mean)
summarize SC_mean, meanonly
gen SC_c = SC_mean - r(mean)

* 1.8 Binary exposure for PSM
summarize Exposure_T2, detail
gen Exposure_binary = (Exposure_T2 >= r(p50))
label var Exposure_binary "High exposure (above median)"

/*----------------------------------------------------------------------
  SECTION 2: DESCRIPTIVE STATISTICS
----------------------------------------------------------------------*/

* 2.1 Table 1 descriptives
dtable age i.gender i.education i.occupation income i.relationship ///
       IBT_mean SC_mean SE_mean SII_mean FOMO_mean ///
       IPB1 Exposure_T2 ///
       PS_T2 PSI_T2 EA_T2 SP_T2 IPB1_T2, ///
       title("Table 1: Descriptive Statistics")

* 2.2 Correlation matrix
correlate Exposure_T2 PS_T2 PSI_T2 EA_T2 SP_T2 IPB1_T2 ///
          IBT_mean SC_mean IPB1

* 2.3 DV distribution check
summarize IPB1_T2, detail
histogram IPB1_T2, discrete frequency ///
    title("Distribution of IPB1_T2 (Count DV)")

/*----------------------------------------------------------------------
  SECTION 3: MEASUREMENT VALIDATION
----------------------------------------------------------------------*/

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

* PS
alpha PS1_T2 PS2_T2 PS3_T2 PS4_T2 PS5_T2, item

* PSI
alpha PSI1_T2 PSI2_T2 PSI3_T2 PSI4_T2 PSI5_T2, item

* EA
alpha EA1_T2 EA2_T2 EA3_T2 EA4_T2, item

* SP
alpha SP1_T2 SP2_T2 SP3_T2 SP4_T2, item

* 3.2 Factor analysis (CFA proxy via EFA)
* T2 Mediators - check 4-factor structure
factor PS1_T2 PS2_T2 PS3_T2 PS4_T2 PS5_T2 ///
       PSI1_T2 PSI2_T2 PSI3_T2 PSI4_T2 PSI5_T2 ///
       EA1_T2 EA2_T2 EA3_T2 EA4_T2 ///
       SP1_T2 SP2_T2 SP3_T2 SP4_T2, ///
       factors(4) pcf
rotate, varimax
estat kmo

/*----------------------------------------------------------------------
  SECTION 4: H1 - PRIMARY REGRESSION (Total Effect)
----------------------------------------------------------------------*/

display _n "=== H1: Total Effect of Exposure on IPB ==="

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

* Compare specifications
estimates table h1_primary h1_likert h1_poisson h1_nbreg, ///
    star(0.10 0.05 0.01) stats(N r2 aic bic)

/*----------------------------------------------------------------------
  SECTION 5: H2a-d - MEDIATION ANALYSIS (Parallel Multiple Mediator)
----------------------------------------------------------------------*/

display _n "=== H2: Parallel Mediation ==="

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
    
    * Outcome model (b-paths)
    quietly regress IPB1_T2 Exposure_T2 PS_T2 PSI_T2 EA_T2 SP_T2 ///
                    IPB1 IBT_mean SC_mean age i.gender MA_T2_mean TA_T2_mean MOOD1_T2
    local b1 = _b[PS_T2]
    local b2 = _b[PSI_T2]
    local b3 = _b[EA_T2]
    local b4 = _b[SP_T2]
    local cprime = _b[Exposure_T2]
    
    * Indirect effects
    return scalar ind_ps = `a1' * `b1'
    return scalar ind_psi = `a2' * `b2'
    return scalar ind_ea = `a3' * `b3'
    return scalar ind_sp = `a4' * `b4'
    return scalar total_indirect = `a1'*`b1' + `a2'*`b2' + `a3'*`b3' + `a4'*`b4'
    return scalar direct = `cprime'
    return scalar total = `cprime' + `a1'*`b1' + `a2'*`b2' + `a3'*`b3' + `a4'*`b4'
    
    * Contrasts
    return scalar contrast_ps_psi = `a1'*`b1' - `a2'*`b2'
    return scalar contrast_ps_ea = `a1'*`b1' - `a3'*`b3'
    return scalar contrast_psi_sp = `a2'*`b2' - `a4'*`b4'
end

bootstrap r(ind_ps) r(ind_psi) r(ind_ea) r(ind_sp) ///
          r(total_indirect) r(direct) r(total) ///
          r(contrast_ps_psi) r(contrast_ps_ea) r(contrast_psi_sp), ///
          reps(5000) seed(2026): boot_mediation

estat bootstrap, percentile

/*----------------------------------------------------------------------
  SECTION 6: H3a-b - MODERATED MEDIATION
----------------------------------------------------------------------*/

display _n "=== H3a: IBT moderates b-paths ==="

* 6.1 H3a: IBT moderates mediator → IPB paths
regress IPB1_T2 c.Exposure_T2 ///
        c.PS_T2##c.IBT_c c.PSI_T2##c.IBT_c ///
        c.EA_T2##c.IBT_c c.SP_T2##c.IBT_c ///
        IPB1 SC_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store h3a

* Probe interactions at +/- 1 SD IBT
summarize IBT_c
local ibt_lo = -r(sd)
local ibt_hi = r(sd)
margins, dydx(PS_T2) at(IBT_c = (`ibt_lo' `ibt_hi'))
margins, dydx(PSI_T2) at(IBT_c = (`ibt_lo' `ibt_hi'))

display _n "=== H3b: Self-Control moderates b-paths ==="

* 6.2 H3b: SC moderates mediator → IPB paths
regress IPB1_T2 c.Exposure_T2 ///
        c.PS_T2##c.SC_c c.PSI_T2##c.SC_c ///
        c.EA_T2##c.SC_c c.SP_T2##c.SC_c ///
        IPB1 IBT_mean age i.gender ///
        MA_T2_mean TA_T2_mean MOOD1_T2, ///
        vce(robust)
estimates store h3b

/*----------------------------------------------------------------------
  SECTION 7: ROBUSTNESS - PROPENSITY SCORE MATCHING
----------------------------------------------------------------------*/

display _n "=== Robustness: PSM ==="

* 7.1 Standard PSM (binary exposure)
teffects psmatch (IPB1_T2) ///
    (Exposure_binary IBT_mean SC_mean SE_mean SII_mean ///
     age i.gender i.education i.occupation income i.relationship IPB1 FOMO_mean), ///
    atet nn(1) caliper(0.2)

* Balance diagnostics
tebalance summarize
tebalance density

/*----------------------------------------------------------------------
  SECTION 8: ROBUSTNESS - E-VALUE SENSITIVITY ANALYSIS
----------------------------------------------------------------------*/

display _n "=== Robustness: E-value ==="

* Compute E-value from primary regression coefficient
* Using point estimate and CI lower bound from H1
estimates restore h1_primary
local b_exp = _b[Exposure_T2]
local se_exp = _se[Exposure_T2]
local ci_lo = `b_exp' - 1.96 * `se_exp'

* E-value formula (for continuous outcome, approximate via RR conversion)
* RR ≈ exp(0.91 * beta / SD_Y) per VanderWeele & Ding (2017)
quietly summarize IPB1_T2
local sd_y = r(sd)
local RR = exp(0.91 * `b_exp' / `sd_y')
local E_point = `RR' + sqrt(`RR' * (`RR' - 1))
local RR_lo = exp(0.91 * `ci_lo' / `sd_y')
local E_ci = `RR_lo' + sqrt(`RR_lo' * (`RR_lo' - 1))

display "E-value (point estimate): " %6.3f `E_point'
display "E-value (CI lower bound): " %6.3f `E_ci'

/*----------------------------------------------------------------------
  SECTION 9: ATTRITION ANALYSIS
----------------------------------------------------------------------*/

display _n "=== Attrition Analysis ==="

/* NOTE: Attrition analysis requires a separate T1-only dataset with a
   completed_t2 indicator. Uncomment and adapt once that file is prepared.

preserve
use "t1_with_attrition.dta", clear

* Compare on key T1 variables
foreach v in age IBT1 SC1 SE1 EXP5 IPB1 {
    display _n "`v':"
    ttest `v', by(completed_t2)
}

tabulate gender completed_t2, chi2
tabulate education completed_t2, chi2
restore
*/
display "Attrition analysis skipped — requires T1-only file with completed_t2 flag."

/*----------------------------------------------------------------------
  SECTION 10: COMMON METHOD VARIANCE
----------------------------------------------------------------------*/

display _n "=== CMV: Marker Variable Check ==="

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

display _n "=== PIPELINE TEST COMPLETE ==="
display "All commands executed successfully."
display "Ready for real data substitution."
