********************************************************************************
/*
	CLEAN ACTIVITY HISTORY.
		CLEANS DATA IN EACH WAVE.
*/
********************************************************************************

* 1. Append Data Together
use "${act_fld}/Wave ${first_wave}", clear
local j = $first_wave +1
forval i=`j'/$last_wave{
	append using "${act_fld}/Wave `i'"
	}
sort NSID Wave Spell
order NSID Wave Spell
save "${act_fld}/Activity Histories", replace


* 2. Merge with Interview Grid
preserve
	use "${act_fld}/Interview Grid", clear
	reshape long IntDate_MY, i(NSID) j(Wave)
	encode NSID, gen(XX)
	xtset XX Wave
	gen L_IntDate_MY=L.IntDate_MY
	replace L_IntDate_MY=.i if L_IntDate_MY==.
	drop XX
	format *MY %tm
	tempfile Temp
	save "`Temp'", replace
restore
merge m:1 NSID Wave using "`Temp'", nogen keep(match master)


* 3. Create Interview Date Range
gen Min_IntDate_MY=IntDate_MY
gen Max_IntDate_MY=IntDate_MY
forval i=$first_wave/$last_wave{
	sum IntDate_MY if Wave==`i'
	replace Min_IntDate_MY=`r(min)' if missing(Min_IntDate_MY) & Wave==`i'
	replace Max_IntDate_MY=`r(min)' if missing(Max_IntDate_MY) & Wave==`i'
	}
format *MY %tm


* 4. Remove Non-Chronological Waves
local i Start
gen XX=0
foreach j in Y MY{
	gen YY=cond(missing(`i'_`j'),1,0)
	by NSID Wave YY (Spell), sort: replace XX=1 if /*
		*/ `i'_`j'>`i'_`j'[_n+1] & !missing(`i'_`j', `i'_`j'[_n+1])
	drop YY
	}
by NSID Wave (Spell), sort: egen NonChron=max(XX)
drop XX

by NSID Wave (Spell), sort: egen XX=max(Start_MY==.m)
drop if NonChron==1 & XX==1		// WASTEFUL - ONLY DO IF THERE IS MISSING Y OR MULTIPLE OBS IN Y WHERE THERE IS A MISSING M. HOWEVER, ONLY DROP 16 OBSERVATIONS.
drop XX

by NSID Wave (Start_MY Spell), sort: replace Spell=_n if NonChron==1
sort NSID Wave Spell
drop NonChron


* 5. Drop if After Maximum Possible Interview Date
gen XX=.
replace XX=1 if Start_Y>year(dofm(Max_IntDate_MY)) & !missing(Start_Y,Max_IntDate_MY)
replace XX=1 if Start_MY>Max_IntDate_MY & !missing(Start_MY,Max_IntDate_MY)
by NSID Wave (Spell), sort: replace XX=XX[_n-1] if missing(XX)
drop if XX==1
drop XX


* 6. Generate Bounds and Overwrite Where Implied in Gap
prog_bounds
replace Start_MY=LB if LB==UB & missing(Start_MY) & !missing(LB,UB)		// SHOULD MEAN THAT CAN REMOVE UNIFORMATIVE MISSING=1 AS JANUARY/DECEMBERS WILL BE REPLACED.
replace Start_Y=year(dofm(LB)) if year(dofm(LB))==year(dofm(UB)) ///
	& missing(Start_Y) & !missing(LB,UB)


* 7. Split Gaps between Spells if Gap>${gap}.
	* Setting Gap=1 solves problem where I truncate in next month/previous month where 1 month spell followed by spell with missing dates!
forval i=1/2{
	prog_bounds
	gen Gap=UB-LB
	prog_datemiss Start
	gen XX=1 if Gap<$gap & Start_Miss==`i'
	by NSID Wave LB UB (Spell), sort: replace Start_MY=LB+(_n/(_N+1))*Gap if XX==1
	replace Start_Flag=`i'+1 if XX==1
	drop LB UB XX Gap
}

	
* 8. Collapse Same Activities into single spell. 
	* Multiple Spells Can be Collapsed where... 
		* Same activity, and
		* First Activity has some date data, and
		* Last spell has some known end date data (from next spell or interview date)
prog_datemiss Start
sum Spell
forval i=1/`r(max)'{
	by NSID Wave (Spell), sort: gen XX=1 if Activity!=Activity[_n-1]
	by NSID Wave (Spell), sort: gen YY=sum(XX)
	by NSID Wave YY (Spell), sort: gen ZZ=_n if Start_Miss<2
	by NSID Wave YY (Spell), sort: egen AA=min(ZZ)
	by NSID Wave YY (Spell), sort: gen BB=(AA<=_n)		// FIRST SPELL WITH DATE DATA.
	by NSID Wave (Spell), sort: replace BB=1 if Activity!=Activity[_n-1]
	by NSID Wave (Spell), sort: gen CC=sum(BB)
	by NSID Wave (Spell), sort: gen DD=cond(_n<_N,Start_Miss[_n+1],0) // END DATE HAS SOME INFORMATION
	by NSID Wave CC (Spell), sort: gen EE=_n if DD<2
	by NSID Wave CC (Spell), sort: egen FF=max(EE)
	by NSID Wave CC (Spell), sort: gen GG=(FF>_n)
	by NSID Wave (Spell), sort: replace GG=1 if Activity!=Activity[_n-1]
	keep if GG==1
	drop XX-GG
	}
by NSID Wave (Spell), sort: replace Spell=_n

* 9. Create Indicator for whether spell provides useful dates. 
	* Informative if...
prog_datemiss Start
		* Has Complete Data
gen Inform=(Start_Miss==0)
		* Final Spell & Year Precedes Possible Interview Date
by NSID Wave (Spell), sort: replace Inform=1 ///
	if _n==_N & Start_Y<year(dofm(Min_IntDate_MY)) & Start_Miss==1
		* Followed by Spell in Other Year
by NSID Wave (Spell), sort: replace Inform=1 ///
	if _n<_N & Start_Miss==1 & Start_Y<Start_Y[_n+1] & Start_Miss[_n+1]<2
		* Preceded by Spell in Other Year
by NSID Wave (Spell), sort: replace Inform=1 ///
	if _n<_N & Start_Miss==1 & Start_Y>Start_Y[_n-1] & Start_Miss[_n-1]<2	

replace Start_Y=.m if Inform==0 // SET TO FULL MISSING WHERE UNIFORMATIVE.


* 10. Create End Dates
by NSID Wave (Spell), sort: gen End_Y=cond(_n<_N,Start_Y[_n+1],year(dofm(IntDate_MY)))
by NSID Wave (Spell), sort: gen End_MY=cond(_n<_N,Start_MY[_n+1],IntDate_MY)
by NSID Wave (Spell), sort: gen End_Flag=cond(_n<_N,0,1)

	* Replace at Min_IntDate_MY if Interview Date in Previous Year & Missing Interview Date
local if "if _n==_N & Start_Miss==1 & Start_Y<year(dofm(Min_IntDate_MY)) & missing(IntDate_MY)"
by NSID Wave (Spell), sort: replace End_Y=year(dofm(Min_IntDate_MY)) `if'
by NSID Wave (Spell), sort: replace End_MY=Min_IntDate_MY `if'
by NSID Wave (Spell), sort: replace End_Flag=2 `if'
prog_datemiss Start End


* 11. Keep Spells Where Minimum Timeframe Is Known. 
	* Timeframe known if...	
		* Has Complete Data
gen Keep=(Start_Miss==0)	
		* Final Spell and Interview Date Known
by NSID Wave (Spell), sort: replace Keep=1 ///
	if _n==_N & !missing(IntDate_MY)
		* Final Spell and Interview Date in Different Year
by NSID Wave (Spell), sort: replace Keep=1 ///
	if _n==_N & Start_Miss==1 & Start_Y<year(dofm(Min_IntDate_MY))
		* Succeeded by Spell with Full Dates
by NSID Wave (Spell), sort: replace Keep=1 ///
	if Start_Miss[_n+1]==0
		* Succeeded by Spell from Different Year
by NSID Wave (Spell), sort: replace Keep=1 ///
	if Start_Miss==1 & Start_Y<Start_Y[_n+1] & Start_Miss[_n+1]<2

drop if Keep==0
drop Keep Inform


* 12. Replace Start and End Dates where missing
prog_datemiss Start End

	* Start Dates
gen XX=1 if Start_Y==End_Y & Start_Miss==1 & End_Miss<2
replace Start_MY=End_MY-1 if XX==1
replace Start_Flag=5 if XX==1
drop XX

gen XX=1 if Start_Y<End_Y & Start_Miss==1 & End_Miss<2
replace Start_MY=ym(Start_Y,12) if XX==1
replace Start_Flag=5 if XX==1
drop XX

gen XX=1 if Start_Miss==2 & End_Miss==0
replace Start_MY=End_MY-1 if XX==1
replace Start_Flag=6 if XX==1
drop XX

prog_mytoy Start End 
prog_datemiss Start End


	* End Dates
gen XX=1 if Start_Y==End_Y & Start_Miss<2 & End_Miss==1
replace End_MY=Start_MY+1 if XX==1
replace End_Flag=5 if XX==1
drop XX

gen XX=1 if Start_Y<End_Y & Start_Miss<2 & End_Miss==1
replace End_MY=ym(End_Y,1) if Start_Y<End_Y & Start_Miss<2 & End_Miss==1
replace End_Flag=5 if XX==1
drop XX

gen XX=1 if Start_Miss==0 & End_Miss==2
replace End_MY=Start_MY+1 if XX==1
replace End_Flag=5 if XX==1
drop XX

prog_mytoy Start End
prog_datemiss Start End

drop *Miss *_IntDate* *_Y
by NSID Wave (Spell), sort: replace Spell=_n
order NSID Wave Spell Activity Start_MY End_MY IntDate_MY *Flag
format *MY %tm
compress

* 13. Collapse Similar Spells Within Wave
gen XX=End_MY
by NSID Wave (Spell), sort: gen YY=cond(_n<_N,Start_MY[_n+1],End_MY)
by NSID Wave (Spell), sort: gen ZZ=cond(_n<_N,Start_Flag[_n+1],End_Flag)
expand 2 if YY>XX, gen(AA)
replace Activity=.m if AA==1
replace Start_MY=XX if AA==1
replace End_MY=YY if AA==1
replace Start_Flag=End_Flag if AA==1
replace End_Flag=ZZ if AA==1
by NSID Wave (Spell AA), sort: replace Spell=_n

drop XX-AA
by NSID Wave (Spell), sort: gen XX=1 if Activity!=Activity[_n-1]
by NSID Wave (Spell), sort: gen YY=sum(XX)
by NSID Wave YY (Spell), sort: replace End_MY=End_MY[_N]
by NSID Wave YY (Spell), sort: replace End_Flag=End_Flag[_N]
by NSID Wave YY (Spell), sort: keep if _n==1
drop XX YY


* 14. Merge Across Waves
	* Requires !missing(Activity) and Start_MY<End_MY
drop if missing(Activity)
replace End_MY=IntDate_MY if End_MY>IntDate_MY & !missing(End_MY,IntDate_MY)
drop if Start_MY>=End_MY	
by NSID (Start_MY End_MY), sort: replace Spell=_n

	* Prefer earliest wave where overlap.
local overlap (inrange(F_Overlap,1,4) & Wave>F_Wave & !missing(F_Wave)) ///
			  | (inrange(L_Overlap,1,4) & Wave>L_Wave & !missing(L_Wave))
prog_overlap
count if `overlap'
local i=`r(N)'
while `i'>0{
	foreach k in F L{
		prog_overlap
		
		drop if `k'_Overlap==1 & Wave>`k'_Wave & !missing(`k'_Wave)

		expand 2 if `k'_Overlap==2 & Wave>`k'_Wave & !missing(`k'_Wave), gen(XX)
		replace End_MY=`k'_Start_MY if `k'_Overlap==2 & Wave>`k'_Wave & !missing(`k'_Wave) & XX==0
		replace End_Flag=4 if `k'_Overlap==2 & Wave>`k'_Wave & !missing(`k'_Wave) & XX==0
		replace Start_MY=`k'_End_MY if `k'_Overlap==2 & Wave>`k'_Wave & !missing(`k'_Wave) & XX==1
		replace Start_Flag=4 if `k'_Overlap==2 & Wave>`k'_Wave & !missing(`k'_Wave) & XX==1
		drop XX

		replace End_MY=`k'_Start_MY if `k'_Overlap==3 & Wave>`k'_Wave & !missing(`k'_Wave)
		replace End_Flag=4 if `k'_Overlap==3 & Wave>`k'_Wave & !missing(`k'_Wave)
		
		replace Start_MY=`k'_End_MY if `k'_Overlap==4 & Wave>`k'_Wave & !missing(`k'_Wave)
		replace Start_Flag=4 if `k'_Overlap==3 & Wave>`k'_Wave & !missing(`k'_Wave)

		by NSID (Start_MY End_MY Wave Spell), sort: replace Spell=_n
		drop F_* L_*
		}			
	
	prog_overlap
	count if `overlap'
	local i=`r(N)'
	drop F_* L_*
	}
drop Wave


* 15. Format and Save Data
sort NSID Spell
order NSID Spell
prog_labels
label values Activity Activity
label values *Flag Flag
format Activity *Flag %9.0g
numlabel, add
save "${act_fld}/Activity Histories", replace


forval i=$first_wave/$last_wave {
	rm "${act_fld}/Wave `i'.dta"
	}