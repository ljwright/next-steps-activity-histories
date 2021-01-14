********************************************************************************
/*
	INTERVIEW GRID.
		CREATES DATASET CONTAINING INTERVIEW DATES FROM WAVES 4-7
*/
********************************************************************************

tempfile Temp
forval i=4/8{
	if `i'==4	local file "wave_four_lsype_young_person_september_2009"
	if `i'==5	local file "wave_five_lsype_young_person_march_2010"
	if `i'==6	local file "lsype_wave_six_young_person_file_october_2010"
	if `i'==7	local file "lsype_w7_nov2011_suppressed"
	if `i'==8	local file "ns8_2015_main_interview"
	
	if `i'<8	use NSID *nt*onth using "${main_fld}/`file'", clear
	if `i'==8	use NSID W8INT* using "${main_fld}/`file'", clear
	rename W`i'* *
	rename *, lower
	rename nsid NSID
	
	gen Wave=`i'
	if `i'<8	gen IntDate_MY=cond(inrange(intmonth,1,12),ym(`i'+2003,intmonth),.m)
	if `i'==8	gen IntDate_MY=ym(intyear,intmth) ///
		if inrange(intmth,1,12) & inrange(intyear,2015,2016)
	
	keep NSID IntDate_MY Wave
	capture append using "`Temp'"
	save "`Temp'", replace
	}
format IntDate_MY %tm
reshape wide IntDate_MY, i(NSID) j(Wave)
recode IntDate_MY* (.=.i)
save "${act_fld}/Interview Grid", replace
