********************************************************************************
/*
	COLLECT WAVES 4-6.
		COLLECTS CURRENT ACTIVITY AND ACTIVITY HISTORY DATA FROM WAVES 4-6 IN
		PREPARATION FOR CLEANING.
*/
********************************************************************************

tempfile Temp
forval wave=4/6{
* 1. Current Activity
	* Load Data and Rename Variables
	if `wave'==4{
		use NSID W4MainAct* W4ActSt* W4SepChckYP W4OldSkuleYP using ///
			"${main_fld}/wave_four_lsype_young_person_september_2009", clear
		}
	if `wave'==5{
		use NSID W5actYP W5ActSt* using ///
			"${main_fld}/wave_five_lsype_young_person_march_2010", clear
		}
	if `wave'==6{
		use NSID W6TCurrentAct W6ActSt* W6SchToUniYP using ///
			"${main_fld}/lsype_wave_six_young_person_file_october_2010", clear
		}		
	rename W`wave'* *
	rename *YP *
	numlabel, add
	
	* Create Activity Variable
	gen Spell=0
	gen Activity=.m
	if `wave'==4{
		replace Activity=1 if MainAct==2 | MainAct2==3
		replace Activity=2 if MainAct==1
		replace Activity=3 if MainAct2==1
		replace Activity=4 if MainAct2==2
		replace Activity=5 if inlist(MainAct,3,4)
		replace Activity=6 if MainAct2==4
		}
	if `wave'==5{
		replace Activity=1 if act==2
		replace Activity=2 if act==1
		replace Activity=3 if act==5
		replace Activity=4 if act==6
		replace Activity=5 if inlist(act,3,4)
		replace Activity=6 if act==7		
		}
	if `wave'==6{
		replace Activity=1 if TCurrentAct==3
		replace Activity=2 if inlist(TCurrentAct,1,2)
		replace Activity=3 if inlist(TCurrentAct,8,9)
		replace Activity=4 if TCurrentAct==7
		replace Activity=5 if inlist(TCurrentAct,4,5,10,11)
		replace Activity=6 if TCurrentAct==6
		}
	prog_labels `wave'	
	drop if missing(Activity)
	
	* Gather Start Dates
		* Set Equal To Baseline if Before Boundary
	prog_date_setup Start	
	if `wave'==4{
		replace Start_Y=ActStY+2005 if inlist(ActStY,1,2)
		replace Start_MY=ym(ActStY+2005,ActStM) ///
			if inlist(ActStY,1,2) & inrange(ActStM,1,12)
			
		replace Start_Y=2006 if OldSkule==1 | SepChck==1	
		replace Start_MY=ym(2006,9) if OldSkule==1 | SepChck==1
		replace Start_Flag=1 if OldSkule==1 | SepChck==1
		}
	if `wave'>4{
		replace Start_Y=ActStY+1999+`wave' if inrange(ActStY,2,4)
		replace Start_MY=ym(ActStY+1999+`wave',ActStM) ///
			if inrange(ActStY,2,4) & inrange(ActStM,1,12)
			
		replace Start_Y=2000+`wave' if ActStY==1
		replace Start_MY=ym(2000+`wave',12) if ActStY==1
		replace Start_Flag=1 if ActStY==1
		}
	if `wave'== 6 replace Start_MY = ym(2008, 6) if SchToUni==1
	
	* Format And Save
	keep NSID Activity Spell Start*
	format *MY %tm	
	gen Wave=`wave'
	save "`Temp'", replace
	
	
* 2. Activity History
	* Set Up Macros to Open File and use JHSt?DK variable.
	if `wave'==4{
		local num four
		local letter M
		}
	if `wave'==5{
		local num five
		local letter Y
		}
	if `wave'==6{
		local num six
		local letter Y
		}
	
	* Open File and Clean
	local file: subinstr global path "XX" "`num'"
	use "`file'", clear
	rename nsid NSID
	rename W`wave'* *
	rename Activity*teration, lower 
	keep NSID-JHSt`letter'DK
	recode JH* (-91=.i)
	recode JH* (min/0=.m)	
	numlabel, add
	ds NSID, not
	format `r(varlist)' %9.0g
	
	
	* Drop if missing all activity history information in spell
	egen XX=rowmiss(JHAct JHStY JHStM JHSt`letter'DK)
	drop if XX==4
	drop XX	
	
	* Add in spell where Spells is not continuos 
	gen Spell=activityiteration	
	by NSID (Spell), sort: ///
		gen XX=Spell-cond(_n==1,0,Spell[_n-1])
	expand XX, gen(YY)
	replace Spell=Spell-1 if YY==1
	recode JH* (min/max=.m) if YY==1
	drop XX YY
	
	* Gather Activity Information
	gen Activity=.m
	if `wave'==4{
		replace Activity=1 if inlist(JHAct,2,7)
		replace Activity=2 if JHAct==1
		replace Activity=3 if JHAct==5
		replace Activity=4 if JHAct==6
		replace Activity=5 if inlist(JHAct,3,4)
		replace Activity=6 if inlist(JHAct,8,9,10)
		}
	if `wave'==5{
		replace Activity=1 if inlist(JHAct,2,7,14)
		replace Activity=2 if inlist(JHAct,1,13)
		replace Activity=3 if JHAct==5
		replace Activity=4 if JHAct==6
		replace Activity=5 if inlist(JHAct,3,4)
		replace Activity=6 if inlist(JHAct,8,9,10,11,12,16)	
		}
	if `wave'==6{
		replace Activity=1 if (JHAct==1 & !inrange(JHWrk,3,5)) | JHOth==7
		replace Activity=2 if JHAct==2
		replace Activity=3 if JHOth==1
		replace Activity=4 if inlist(JHOth,2,8,13)
		replace Activity=5 if inrange(JHWrk,3,5) | JHAct==3 | JHOth==11
		replace Activity=6 if JHAct==4 & !inlist(JHOth,1,2,8,11,13)
		}
	prog_labels `wave'
	
	* Generate Start Dates
	prog_date_setup Start
	if `wave'==4{
		replace Start_Y=JHStY if !missing(JHStY)
		replace Start_MY=ym(JHStY,JHStM) if !missing(JHStY) & !missing(JHStM)

		replace Start_Flag=1 if JHStMDK==1
		replace Start_Y=2006 if JHStMDK==1
		replace Start_MY=ym(2006,9) if JHStMDK==1
		}
	if `wave'>4{
		replace Start_Y=JHStY+1999+`wave' if inrange(JHStY,2,4)
		replace Start_MY=ym(JHStY+1999+`wave',JHStM) ///
			if inrange(JHStY,2,4) & inrange(JHStM,1,12)

		replace Start_Y=2000+`wave' if JHStY==1
		replace Start_MY=ym(2000+`wave',12) if JHStY==1
		replace Start_Flag=1 if JHStY==1
		}
	
	* Format Dataset
	keep NSID Activity Spell Start*
	gen Wave=`wave'
	append using "`Temp'"
	sort NSID Activity
	ds NSID, not
	format `r(varlist)' %7.0g	
	format *MY %tm
	by NSID (Spell), sort: replace Spell=_N+1-_n
	save "${act_fld}/Wave `wave'", replace
	}
