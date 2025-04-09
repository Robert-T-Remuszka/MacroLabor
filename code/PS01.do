clear all
do Globals

* Sample selection - variables defined below in `cleaning' section
loc samp inrange(year, 1978, 1997)   ///
    & !SeoFlag                        /// Drop low income oversample
    & inlist(RelToHead,1,2)           /// Head or Partner
    & !FemaleHead                     /// Drop households headed by female
    & inlist(MaritalStat, 1, 2)       /// Only those who are married or single
    & inrange(Age, 30, 65)
    

/********************************************************************************************
CLEANING
********************************************************************************************/
use "$data/pequiv_long.dta", clear

* Person identifier
ren x11101LL PerId
ren x11102 HhId
ren d11105 RelToHead
ren d11101 Age
ren d11102LL Gender
gen FemaleHead = RelToHead == 1 & Gender == 2
ren d11104 MaritalStat

* Create Seo Flag
ren x11104 Seo                        // Seo identifier variable
gen SeoFlag = Seo == 12               // 1 if in the oversample, 0 else

* Create college indicator
gen Coll = d11109 > 12 & !mi(d11109)  // At least some college indicator
replace Coll = . if mi(d11109)

* Income - Trying to follow the BPP appendix as closely as possible here
ren i11101 HhPreGovInc
ren i11104 HhIncAssets
gen HhIncLessAsset = HhPreGovInc - HhIncAssets
gen BppAssumedRate = HhIncLessAsset / HhPreGovInc
ren i11111 HhFederalTaxes
gen HhAdjFedTaxes = BppAssumedRate * HhFederalTaxes
gen HhInc = HhIncLessAsset - HhAdjFedTaxes            // After-tax adjusted income, after 1991 not available
ren i11113 HhPostGovInc_Taxsim
replace HhInc = HhPostGovInc_Taxsim if mi(HhInc)      // now we have a constitent series

* Import the CPI from Fred
frame create FredData
frame FredData {
    import fred CPIAUCSL, clear aggr(a, avg)
    gen year = yofd(daten)
    ren CPIAU cpi
}

frlink m:1 year, frame(FredData)
frget cpi, from(FredData)
drop FredData
frame drop FredData

* Real income 
gen HhInc_Real = HhInc * 100 / cpi

* Num children in hh
ren d11107 NumChildren

* Race
ren d11112LL Race

* State of residence
ren l11101 State

* Employment status
ren e11102 EmpStat

* Year of birth
gen Yob = year - Age

******* FIRST SAMPLE SELECTION *******
keep if `samp'

* We want to drop those who went from single to married in the sample
gen Married = MaritalStat == 1
gen Single = MaritalStat == 2
egen YearsMarried = total(Married), by(PerId)
egen YearsSingle = total(Single), by(PerId)
bys PerId (year): gen ForeverSingle = YearsSingle == _N // They'll find love one day! :(
bys PerId  (year): gen ForeverMarried = YearsMarried == _N

* How long is the person in the panel for?
bys PerId (year): gen T = _N

* Keep only heads of household
keep if RelToHead == 1

*********************************** SECOND SAMPLE SELECTION ********************************
keep if ForeverMarried & T >= 4
order HhId PerId year RelToHead Age Gender MaritalStat ForeverMarried ForeverSingle T
sort year HhId PerId

/*********************************** THIRD SAMPLE SELECTION ********************************
Further drop those who are
1. Less than or equal to 0 income

Then, on the resulting distribution of income drop those,
2. Between the 1st and 99th percentile of the resulting distribution at leat four times

Note: I choose 4 time because we need at least 4 observations to estimate the moments of the
income process.

3. Drop those who were an outlier even once: outlier def less than p1 or greater than p99
*/
drop if HhInc_Real <= 0
loc lowercut 1
loc uppercut 99
egen p`lowercut' = pctile(HhInc_Real), p(`lowercut')
egen p`uppercut' = pctile(HhInc_Real), p(`uppercut')
egen IncomeCriteria_count = total(HhInc_Real > p`lowercut' & HhInc_Real < p`uppercut'), by(PerId)
keep if IncomeCriteria_count >= 4
drop p`lowercut' p`uppercut'

loc outlier_lower 1
loc outlier_upper 99
egen p`outlier_lower' = pctile(HhInc_Real), p(`outlier_lower')
egen p`outlier_upper' = pctile(HhInc_Real), p(`outlier_upper')
egen Outlier = total((HhInc_Real < p`outlier_lower' | HhInc_Real > p`outlier_upper') & !mi(HhInc_Real)), by(PerId)
drop if Outlier

gen logY = log(HhInc_Real)

* Save this data for future problem sets
save "$data/PSID_Analysis_Sample.dta", replace
/********************************************************************************************
ESTIMATION
********************************************************************************************/
loc rho = 0.97 // If you set this to 1 you are back to BPP
xtset PerId year
sort PerId year
gen year2 = year^2
loc residvars /*i.year i.Yob*/ year year2 i.Coll i.NumChildren i.Race i.State i.EmpStat

* Calculate residual income
reg logY `residvars'
predict double y, resid

* Generate pseudo first difference of resid income
gen dy = y - `rho' * l.y

* Generate leads and lags of the pseudo first diff
foreach h of numlist -1/1 {

    if `h' < 0 {
        loc lag = -1 * `h'
        gen dy_lag`lag' = l`lag'.dy
    }
    if `h' > 0 {
        gen dy_lead`h' = f`h'.dy
    }

}

* Estimate variance transitory shock
di "***************************************************"
di "              VARIANCE OF TRANSITORY SHOCK"
di "***************************************************"
qui corr dy dy_lead1, c
di -`r(cov_12)'/`rho'

* Estimate variance of persistent shock
di "***************************************************"
di "              VARIANCE OF PERMANENT SHOCK"
di "***************************************************"
gen ThreePeriodSum = `rho'^2 * dy_lag1 + `rho' * dy + dy_lead1
qui corr dy ThreePeriodSum, c
di `r(cov_12)'/`rho'