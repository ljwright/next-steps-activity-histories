********************************************************************************
/*
	COLLECT WAVE 7.
		COLLECTS CURRENT ACTIVITY AND ACTIVITY HISTORY DATA FROM WAVES 7 IN
		PREPARATION FOR CLEANING.
*/
********************************************************************************

* 1. Current Activity
	* Get Current Activity Data
		* Merge with Activity History, Wave 6 and Interview Grid
use NSID W7ActStillYP W7ActContYP W7StillEdChkYP W7TCurrentAct using ///
	"${main_fld}/lsype_w7_nov2011_suppressed", clear
merge 1:1 NSID using "${main_fld}/lsype_wave_six_young_person_file_october_2010", ///
	nogen keep(match master) keepusing(W6TCurrentAct) 
merge 1:1 NSID using "${act_fld}/Interview Grid", ///
	nogen keep(match master) keepusing(*6 *7)
preserve
	local file: subinstr global path "XX" "seven"
	use "`file'", clear
	rename nsid NSID
	keep NSID
	duplicates drop
	tempfile Temp
	save "`Temp'", replace
restore
merge 1:1 NSID using "`Temp'", gen(History)
rename W7* *
rename *YP *
numlabel, add

	* Keep if Still In W6 Activty (Has No Activity History data)
keep if ActStill==1 & History==1

	* Set Up Wave, Spell and Activity
gen Wave=7
gen Spell=1
gen Activity=.m
replace Activity=1 if TCurrentAct==3
replace Activity=2 if inrange(TCurrentAct,1,2)
replace Activity=3 if TCurrentAct==8
replace Activity=4 if TCurrentAct==7
replace Activity=5 if inlist(TCurrentAct,4,5,9,10)
replace Activity=6 if TCurrentAct==6
prog_labels

	* Generate Start Dates
sum IntDate_MY6
gen Start_Y=2009
gen Start_MY=cond(!missing(IntDate_MY6),IntDate_MY6,`r(max)')
gen Start_Flag=cond(!missing(IntDate_MY6),1,2)

	* Format and Save Dataset
keep NSID Wave Spell Activity Start_*
order NSID Wave Spell Activity Start*
format Activity %9.0g
format *MY %tm
compress
save "`Temp'", replace


* 2. Activity History
	* Load Data and Clean
local file: subinstr global path "XX" "seven"
use "`file'", clear
rename nsid NSID
rename W7* *
keep NSID ActivityPeriod TIterationActivity JHStill ActStpY ActStpM
recode JH* (-91=.i)
recode JH* (min/0=.m)
numlabel, add
ds NSID, not
format `r(varlist)' %9.0g
merge m:1 NSID using "${act_fld}/Interview Grid", ///
	nogen keep(match master) keepusing(*6 *7)

	* Generate Wave and Spell
gen Wave=7
by NSID (ActivityPeriod), sort: gen Spell=_n
drop ActivityPeriod

	* Set Up Activity Data
gen Activity=.m
replace Activity=1 if TIterationActivity==3
replace Activity=2 if inlist(TIterationActivity,1,2)
replace Activity=3 if TIterationActivity==8
replace Activity=4 if TIterationActivity==7
replace Activity=5 if inlist(TIterationActivity,4,5,9,10,11)
replace Activity=6 if inlist(TIterationActivity,6,12,13,14)
prog_labels

	* Gather End Date Date
prog_date_setup End
replace End_Y=ActStpY+2008 if inrange(ActStpY,1,2)
replace End_MY=ym(ActStpY+2008,ActStpM) ///
	if inrange(ActStpY,1,2) & inrange(ActStpM,1,12)
replace End_Y=year(dofm(IntDate_MY7)) if JHStill==1
replace End_MY=IntDate_MY7 if JHStill==1

	* Create End Spell if Activity History Ends with JHStill!=1
by NSID (Spell), sort: gen XX=1 if _n==_N & missing(End_MY) & JHStill!=1 
expand 2 if XX==1, gen(YY)
replace Activity=.m if YY==1
replace Spell=Spell+1 if YY==1
drop XX YY
	
	* Create Indicator for If Min(Date)<IntDate_W6
by NSID (Spell), sort: egen XX=min(End_Y)
by NSID (Spell), sort: egen YY=min(End_MY)
gen Pre_IntDate=1 if Spell==1 & ((XX<year(dofm(IntDate_MY6)) & !missing(XX,IntDate_MY6)) ///
	| (YY<IntDate_MY6 & !missing(YY,IntDate_MY6)))
drop XX YY

	* Generate Start Dates
prog_date_setup Start
by NSID (Spell), sort: replace Start_Y=End_Y[_n-1]
by NSID (Spell), sort: replace Start_MY=End_MY[_n-1]

local if if _n==1 & Pre_IntDate!=1 	// INITIAL SPELL HAS KNOWN START DATES IF MIN(DATE)>=INTDATE_W6
by NSID (Spell), sort: replace Start_Y=year(dofm(IntDate_MY6)) `if'
by NSID (Spell), sort: replace Start_MY=IntDate_MY6 `if'
by NSID (Spell), sort: replace Start_Flag=1 `if'

drop End* Pre_IntDate
recode Start_*Y (.=.m)

	* Format and Save Dataset
keep NSID Wave Spell Activity Start*
format *MY %tm
compress
append using "`Temp'"
save "${act_fld}/Wave 7", replace
