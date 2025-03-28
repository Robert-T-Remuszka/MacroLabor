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

******** SECOND SAMPLE SELECTION *******
keep if (ForeverSingle | ForeverMarried) & T >= 4
order HhId PerId year RelToHead Age Gender MaritalStat ForeverMarried ForeverSingle T
sort year HhId PerId

/********************************************************************************************
ESTIMATION
********************************************************************************************/
xtset PerId year