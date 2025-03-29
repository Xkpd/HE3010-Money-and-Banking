clear all
cd "/Users/xingkun/Desktop/HE3010 Money and Banking/project/HE3010-Money-and-Banking"

// ------------------------------------ IMPORT CLEANED DATA ------------------------------------
import delimited "data/uob_clean.csv", clear
gen bank = "UOB"
tempfile uob
save `uob', replace

import delimited "data/ocbc_clean.csv", clear
gen bank = "OCBC"
rename totalassetsthousandsusd totalassets
rename totaloperatingexpensesthousandsu totaloperatingexpenses
tempfile ocbc
save `ocbc', replace

import delimited "data/dbs_clean.csv", clear
rename totalassetsthousandsusd totalassets
rename totaloperatingexpensesthousandsu totaloperatingexpenses
gen bank = "DBS"
tempfile dbs
save `dbs', replace

// ------------------------------------ COMBINE BANK DATA ------------------------------------
use `dbs', clear
append using `ocbc'
append using `uob'
rename v1 date
gen date_num = date(date, "DMY")       // Convert string to Stata date
gen year = year(date_num)              // Extract 4-digit year
drop date_num
drop date

tempfile all_banks
save `all_banks', replace

// ------------------------------------ IMPORT PAYMENT DATA ------------------------------------
import excel "data/Retail_Payment_Analysis.xlsx", sheet("Raw Data") firstrow clear

gen Category = ""
replace Category = "BNDP" if ///
    inlist(Instrument, "ATM Withdrawals", "CNP Card Payments (Credit)", "CNP Card Payments (Debit)", "FAST", "Inter-bank GIRO") | ///
    inlist(Instrument, "POS Card Payments (Credit)", "POS Card Payments (Debit)", "Singapore Dollar Cheque Clearing", "Stored Value Facilities", "US Dollar Cheque Clearing")


collapse (sum) Value, by(Year Category)
reshape wide Value, i(Year) j(Category) string
rename ValueBNDP bank_involved

gen LNBDP = ln(bank_involved)
keep Year LNBDP
destring Year, replace
rename Year year
tempfile payment
save `payment', replace

// ------------------------------------ MERGE & GENERATE VARIABLES ------------------------------------
use `all_banks', clear
merge m:1 year using `payment', keep(match) nogen

// Clean and rename variables for regression
rename totalassets total_assets
rename totalequitytotalassets equity_ratio
rename totaloperatingexpenses operating_expenses
rename returnonaverageassetsroaa roa
rename returnonaverageequityroae roe
rename netinterestmarginaveragetotalear nim // ∟ Net interest margin (average total earning assets) (%)

destring total_assets operating_expenses equity_ratio roa, replace ignore(",%")

gen SIZE = ln(total_assets)
gen RISK = equity_ratio / total_assets
gen COST = operating_expenses / total_assets
gen ROA = roa / 100
gen ROE = roe / 100
gen NIM = nim / 100

encode bank, gen(bank_id)
xtset bank_id year

foreach var in SIZE RISK COST LNBDP {
    gen d_`var' = `var' - L.`var'
}
// ------------------------------------ ROA ------------------------------------


gen ROA_lag1 = L.ROA
gen ROA_lag2 = L2.ROA
gen d_ROA = ROA - ROA_lag1
gen d_ROA_lag1 = ROA_lag1 - ROA_lag2


drop if missing(d_ROA, d_ROA_lag1, d_SIZE, d_RISK, d_COST, d_LNBDP, ROA_lag2)

// ------------------------------------ RUN REGRESSION ROA ------------------------------------

* If xtabond2 is available:
* ssc install xtabond2
* xtabond2 d_ROA L.d_ROA d_SIZE d_RISK d_COST d_LNBDP, ///
*     gmm(L.d_ROA, lag(2 2)) iv(d_SIZE d_RISK d_COST d_LNBDP) ///
*     robust noleveleq

eststo clear  // Clear any previously stored estimates

xtdpdsys d_ROA d_SIZE d_RISK d_COST d_LNBDP, lags(1) vce(robust)
eststo sys_roa  // Store DIFF-GMM results for ROA

* Alternative: 2SLS
ivregress 2sls d_ROA d_SIZE d_RISK d_COST d_LNBDP (d_ROA_lag1 = ROA_lag2), robust
eststo diff_roa 

// ------------------------------------ ROE ------------------------------------


gen ROE_lag1 = L.ROE
gen ROE_lag2 = L2.ROE
gen d_ROE = ROE - ROE_lag1
gen d_ROE_lag1 = ROE_lag1 - ROE_lag2


drop if missing(d_ROE, d_ROE_lag1, d_SIZE, d_RISK, d_COST, d_LNBDP, ROE_lag2)

// ------------------------------------ RUN REGRESSION ROE ------------------------------------

* If xtabond2 is available:
* ssc install xtabond2
* xtabond2 d_ROA L.d_ROA d_SIZE d_RISK d_COST d_LNBDP, ///
*     gmm(L.d_ROA, lag(2 2)) iv(d_SIZE d_RISK d_COST d_LNBDP) ///
*     robust noleveleq

xtdpdsys d_ROE d_SIZE d_RISK d_COST d_LNBDP, lags(1) vce(robust)
eststo sys_roe

* Alternative: 2SLS
ivregress 2sls d_ROE d_SIZE d_RISK d_COST d_LNBDP (d_ROE_lag1 = ROE_lag2), robust
eststo diff_roe

// ------------------------------------ NIM ------------------------------------


gen NIM_lag1 = L.NIM
gen NIM_lag2 = L2.NIM
gen d_NIM = NIM - NIM_lag1
gen d_NIM_lag1 = NIM_lag1 - NIM_lag2


drop if missing(d_NIM, d_NIM_lag1, d_SIZE, d_RISK, d_COST, d_LNBDP, NIM_lag2)

// ------------------------------------ RUN REGRESSION NIM ------------------------------------

* If xtabond2 is available:
* ssc install xtabond2
* xtabond2 d_ROA L.d_ROA d_SIZE d_RISK d_COST d_LNBDP, ///
*     gmm(L.d_ROA, lag(2 2)) iv(d_SIZE d_RISK d_COST d_LNBDP) ///
*     robust noleveleq

xtdpdsys d_NIM d_SIZE d_RISK d_COST d_LNBDP, lags(1) vce(robust)
eststo sys_nim

* Alternative: 2SLS
ivregress 2sls d_NIM d_SIZE d_RISK d_COST d_LNBDP (d_NIM_lag1 = NIM_lag2), robust
eststo diff_nim


//--------------------------------combining regression --------------------------------------
esttab diff_roa sys_roa diff_roe sys_roe diff_nim sys_nim ///
    using "Table3.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    label varlabels(_cons "Constant") ///
    title("Table 3: Outputs of DIFF-GMM models") ///
    keep( d_ROA_lag1 d_ROE_lag1  d_NIM_lag1 d_SIZE d_RISK d_COST d_LNBDP ///
          _cons)
