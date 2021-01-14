********************************************************************************
/*
	COLLECT WAVE 8.
		COLLECTS CURRENT ACTIVITY AND ACTIVITY HISTORY DATA FROM WAVES 8 IN
		PREPARATION FOR CLEANING.
*/
********************************************************************************

* 0. Common Activity Definition
capture program drop prog_activityw8
program define prog_activityw8
	args activity
	
	gen Activity=.m
	replace Activity=1 if inrange(`activity',1,4)
	replace Activity=2 if inrange(`activity',6,7)
	replace Activity=3 if `activity'==5
	replace Activity=4 if `activity'==13
	replace Activity=5 if inlist(`activity',8,11,12)
	replace Activity=6 if inlist(`activity',9,10,14)

	prog_labels
end

* 1. Current Activity
use NSID W8DACTIVITY W8STARTM W8STARTY using ///
	"${main_fld}/ns8_2015_main_interview", clear
rename W8* *
numlabel, add

gen Wave=8
gen Spell=0
prog_activityw8 DACTIVITY

prog_date_setup Start	
replace Start_Y=STARTY if inrange(STARTY,1990,2016)
replace Start_MY=ym(STARTY,STARTM) ///
	if inrange(STARTY,1990,2016) & inrange(STARTM,1,12)
	
keep NSID Wave Spell Activity Start*
format *MY %tm
compress
tempfile Temp
save "`Temp'", replace


* 2. Activity History
use NSID W8HISTID W8HISTSTPM W8HISTSTPY W8DACTIVITYP ///
	using "${main_fld}/ns8_2015_activity_history", clear
rename W8* *
numlabel, add

gen Wave=8
gen Spell=HISTID
prog_activityw8 DACTIVITYP

prog_date_setup Start	
replace Start_Y=HISTSTPY if inrange(HISTSTPY,1990,2016)
replace Start_MY=ym(HISTSTPY,HISTSTPM) ///
	if inrange(HISTSTPY,1990,2016) & inrange(HISTSTPM,1,12)
	
keep NSID Wave Activity Start*
format *MY %tm
compress
append using "`Temp'"


* 3. Combine
by NSID Wave (Spell), sort: replace Spell=_N+1+ _n
sort NSID Spell
save "${act_fld}/Wave 8", replace
