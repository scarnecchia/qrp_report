****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_profile_createdata.sas  
* Created (mm/dd/yyyy): 04/16/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*   Compute aggregate covariate profile table(s)                                 
*   
*  Program inputs:        
*	-                                                                           
*                                     
*  Program outputs:                                                                                                                                       
*                                                                                                  
*  PARAMETERS:    
*            
*  Programming Notes:                                                                                
*
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
*--------------------------------------------------------------------------------------------------
*  CHANGE LOG: 
*
*   Version   Date       Initials      Comment (reference external documentation when available)
*   -------   --------   --------   ----------------------------------------------------------------
*
***************************************************************************************************;

%macro baseline_profile_createdata;

	/* Read in baseline file and begin looping on order */

	%do b = 1 %to &numbaselinetablegrp;

	%let profilecovarstoinclude=;

	proc sql noprint;
		

	data _null_;
		set baselinefile(where=(order=&b));
		call symputx('analysisgrp', analysisgrp);
		call symputx('runid', runid);
        if upcase(covarsort) not in ('A','O','C') then covarsort = 'C'; /*set C as default*/
        call symputx('covarsort', upcase(covarsort));
        call symputx('cohort', cohort);
        /* Add commas between spaced covariates */
        if not missing(profilecovarstoinclude) then call symputx('profilecovarstoinclude',tranwrd(strip(compbl(profilecovarstoinclude)), ' ',', ');
    run;

    %if %length(&profilecovarstoinclude) > 0 %then %do;
    /* Assign dataset name based on cohort type. Periodid will be looped and added during aggregation */
    %if &cohort = preg %then %let profiledataset = &runid._profile_preg;
    %else %if &cohort = nopreg %then %let profiledataset = &runid._profile_nopreg;
    %else %if &cohort = concomitance %then %let profiledata = &runid._profile_concomitance;
    %else %if &cohort = multevent %then %let profiledata = &runid._profile_multevent;
    %else %if &cohort = overlap %then %let profiledata = &runid._profile_overlap;
    %else %if &cohort = mi %then %let profiledata = &runid._profile_mi;
    %else %if &cohort = an %then %let profiledata = &runid._profile_an;
    %else %let profiledata = &runid._profile;

    /* Aggregate profile datasets */
    %do periodid = &look_start %to &look_end;

    proc sql noprint undo_policy=none;
    	create table &profiledata._&periodid._&dps as
    	select a.*
    	from (
    		%do dps = 1 %to %eval(&num_dp.); 
		    %let dpidsiteid = %scan(&random_dplist,&dps); 
		    %let maskedID = %scan(&masked_dplist,&dps); 
		      %if &dps = 1 %then %do;
    		  select *, "&maskedID" as DP length=4, "&runid" as runid length=5
    		  from &dpidsiteid..&profiledata._&periodid._&dps(keep=group %sysfunc(tranwrd(%quote(%trim(&profilecovarstoinclude)),%str(,),%str( )))) 
    		  %end;
    		  %else %do;
    		  union all 
    		  select *, "&maskedID" as DP length=4, "&runid" as runid length=5
    		  from &dpidsiteid..&profiledata._&periodid._&dps(keep=group %sysfunc(tranwrd(%quote(%trim(&profilecovarstoinclude)),%str(,),%str( )))) 
    		  %end;
    		%end;
    		  where group = "&analysisgrp"
    		  );



%mend baseline_profile_createdata;