********************************************************************************
/*
	LAUNCH PROGRAMME.
		THIS DO FILE SETS UP THE GLOBAL MACROS AND RUNS THE OTHER DO FILES TO
		CREATE ACTIVITY HISTORIES FROM WAVES 4-8 IN NEXT STEPS.
		USES DATA ONLY AVAILABLE THROUGH CLS.
*/
********************************************************************************

* 1. File Paths and Directories
cd "C:\Users\liamj\Documents\Datasets\Next Steps - Wave 1- 8 - 2021-01-14"
global main_fld	"stata\stata13\eul"
global dta_fld	"Projects/Activity Histories/Data"
global act_fld	"stata\stata13\activity_histories"
global do_fld	"Projects/Activity Histories/Code"
global path "wave_XX_activity_history_file_2020"

* 2. Set Maximum Gap to Imputes
global gap			6
global first_wave	4
global last_wave	8

* 3. Create Programs 
do "${do_fld}/Create Programs.do"

* 4. Create Activity Histories
if "RUN"=="RUN"{
	do "${do_fld}/Interview Grid.do"
	do "${do_fld}/Collect Waves 4-6.do"
	do "${do_fld}/Collect Wave 7.do"
	do "${do_fld}/Collect Wave 8.do"
	do "${do_fld}/Clean Activity History.do"
	}

	

************* TO DO ****************
**** 	NEED TO OVERWRITE ANY PREVIOUS SPELLS THAT STARTED AFTER CURRENT ACTIVITY - OTHERWISE IT'LL REVERSE ORDER.
****	NEED TO ADD IN END REASON AND JOB ATTRACTION
****	NEED TO MAKE SURE LAGGED INTERVIEW DATE IS SET TO CORRECT WAVE (PRIOR WAVE OR LAST ELICITED?) - DON'T THINK ITS EVEN USED.
