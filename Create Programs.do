* Create Programs
capture program drop prog_date_setup
program define prog_date_setup
	foreach stub in `*'{
		gen `stub'_Y=.m
		gen `stub'_MY=.m
		gen `stub'_Flag=0
		}
end

capture program drop prog_labels
program define prog_labels
		
	capture label define Activity ///
		1 "Employment" 2 "Education" 3 "Unemployment" ///
		4 "Homemaking/Caring" 5 "Training" 6 "Other"
		
	capture label define Flag ///
		0 "No Imputation" ///
		1 "Seam Spell"	///
		2 "Imputed, Month in Year" ///
		3 "Imputed, Month and Year" ///
		4 "Truncated across Waves" ///
		5 "Truncated, Month in Year" ///
		6 "Truncated, Month and Year"
		
	label values Activity
end

capture program drop prog_datemiss
program define prog_datemiss
	foreach date in `*'{
		capture drop `date'_Miss
		egen `date'_Miss=rowmiss(`date'_Y `date'_MY)
		}
	tab *_Miss
end

capture program drop prog_mytoy
program define prog_mytoy
	foreach date in `*'{
		replace `date'_Y=year(dofm(`date'_MY)) ///
			if !missing(`date'_MY)
		}
end

capture program drop prog_overlap
program prog_overlap

	foreach i in F L{
		local obs=cond("`i'"=="F","_n<_N","_n>1")
		local op=cond("`i'"=="F","_n+1","_n-1")
		
		capture drop `i'_* 
		gen `i'_Overlap=0
		by NSID (Spell), sort: replace `i'_Overlap=1 if `obs' & Start_MY>=Start_MY[`op'] & End_MY<=End_MY[`op']
		by NSID (Spell), sort: replace `i'_Overlap=2 if `obs' & Start_MY<Start_MY[`op'] & End_MY>End_MY[`op']
		by NSID (Spell), sort: replace `i'_Overlap=3 if `obs' & Start_MY<Start_MY[`op'] & End_MY<=End_MY[`op'] & End_MY>Start_MY[`op']
		by NSID (Spell), sort: replace `i'_Overlap=4 if `obs' & Start_MY>=Start_MY[`op'] & End_MY>End_MY[`op'] & Start_MY<End_MY[`op']
		by NSID (Spell), sort: gen `i'_Start_MY=cond(`obs',Start_MY[`op'],.i)
		by NSID (Spell), sort: gen `i'_End_MY=cond(`obs',End_MY[`op'],.i)
		by NSID (Spell), sort: gen `i'_Wave=cond(`obs',Wave[`op'],.i)
		}
		
end

capture program drop prog_bounds
program define prog_bounds

	capture drop LB UB
	capture drop Reverse

	gen Reverse=-Spell
	gen LB=max(Start_MY,ym(Start_Y,1))
	gen UB=min(Start_MY,ym(Start_Y,12))
	by NSID Wave (Spell), sort: replace LB=LB[_n-1] ///
		if missing(LB) | (!missing(LB[_n-1]) & LB[_n-1]>LB)
	by NSID Wave (Reverse), sort: replace UB=UB[_n-1] ///
		if missing(UB) | (!missing(UB[_n-1]) & UB[_n-1]<UB)
	replace UB=min(UB,Max_IntDate_MY)
	drop Reverse
	
	sort NSID Wave Spell
	format LB UB %tm
end
