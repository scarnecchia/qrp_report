****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_aggregate.sas  
* Created (mm/dd/yyyy): 10/20/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro imports and concatenates both Level 1 and Level 2 baseline tables
*
*  Program inputs:                                                                                   
*   - Level 1 tables in the format: [runid]_baseline_[cohort]_[periodid].sas7bdat
*   - Level 2 tables in the format: [runid]_adjusted_baseline_[periodid].sas7bdat
* 
*  Program outputs:                                                                                                                                       
*  	- Dataset where each row represents a baseline metric and each column represents a DP value.
*     Groups in the GROUPTABLE are stacked
* 
*  PARAMETERS:        
*   - dpsiteid: name of DP to import. Will be used as libname
    - dpnumber: number to assign to each DP after transpose
*   - level: 1 or 2
*   - grouptable: name of the dataset that contains groups, runIDs, and infomation pertaining to the 
*     baseline table name to include in the report.
*   - outdata: name of the aggregated dataset
*   - periodid: monitoring period #
*
*
*  Programming Notes:                                                                                
*   - This macro is designed to be called within a loop that loops through each data partner
*
*   - For level 1 requests, the baseline table file name will be dynamically derived using 
*     &dpsiteid as the libname and the file name as: [runid]_baseline_[cohort]_&periodid
*
*   - GROUPTABLE must contain the following variables: GROUP, RUNID, COHORT, and MERGEVAR
*     For level 2 requests, only GROUP and RUNID need to be populated. GROUP will represent the ANALYSISGRP.
*     For level 1 requests, COHORT is optional and will be used to correctly name the associated baseline 
*     table ([runid]_baseline_[cohort]_[periodid].sas7bdat), MERGEVAR is required and is the name of 
*     the key variable in the baseline table (group or analysisgrp)
*
*   - It is assumed the user intends to import and aggregate all groups in the GROUPTABLE input file.
*     The user should restrict this file to only groups with a baseline table prior to executing 
*     this macro.
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro baseline_aggregate(dpsiteid = ,
                          dpnumber = ,
                          level = ,
                          grouptable = ,
                          outdata = ,
                          periodid = );

	%put =====> MACRO CALLED: baseline_aggregate;

    /*********************************************************************************************/
    /* Level 1 baseline tables
    /*********************************************************************************************/

    %if %eval(&level.=1) %then %do;

        /*Use GROUPTABLE to create list of baseline tables and create dataset in statement*/
        data _temp_baseline_tablenames;
            set &GROUPTABLE.;
            format baselinetablename $40.;
            if missing(cohort) then do;
                baselinetablename = lowcase(cats("&dpsiteid..",runid, "_baseline_&periodid"));
            end;
            else do;
                baselinetablename = lowcase(cats("&dpsiteid..",runid, "_baseline_", cohort, "_&periodid"));
            end;
        run;

        proc sql noprint;
            select distinct baselinetablename into: baselinetables separated by ' '
            from _temp_baseline_tablenames;
            select count(distinct baselinetablename) into: num_unique_baseline_tables
            from _temp_baseline_tablenames;
        quit;
        %put Extracting baseline tables: &baselinetables.;

        /*Loop through each baseline table, import, stack groups*/

        %do b = 1 %to %eval(&num_unique_baseline_tables.);
            %let infile = %scan(&baselinetables., &b., ' ');

            /*Ensure table exists: if it does not exist, write error to the log and abort*/
            %if %sysfunc(exist(&infile.))=0 %then %do;
		 		%put ERROR: &infile. does not exist. Program will abort;
			 	%abort; 
		 	%end;

            /*Merge table with GROUPSTABLE and only keep Groups/Analysisgrps in the input file*/
            data _temp_baseline_tablenames&b.;
                set _temp_baseline_tablenames(where=(baselinetablename="&infile."));
                call symputx('mergevar', mergevar);
            run;

            proc sql noprint;
                create table _temp_baseline_tablenum&b. as
                select x.*
                     , y.runid
                     , y.order
                     , y.cohort
                     %if "&mergevar" ne "analysisgrp" %then %do;
                     , y.analysisgrp
                     %end;
                     , y.group as group1
                from &infile. as x,
                     _temp_baseline_tablenames&b. as y
                where x.&mergevar. = y.group;
            quit;
        %end;

        /*Stack baseline tables and transpose*/
        data _temp_baseline_stacked;
            set _temp_baseline_tablenum:;
        run;

        /*Transpose and rename variable holding metrics to DP&DPNUMBER*/
        proc sort data=_temp_baseline_stacked;
            by analysisgrp group1 runid order cohort 
			   %if %str("&reporttype") = %str("T6") %then %do;
                 switchstep
               %end;;
        run;

        proc transpose data=_temp_baseline_stacked out=_temp_baseline_transposed;
            by analysisgrp group1 runid order cohort  ; 
		run;

		%if %str("&reporttype") = %str("T6") %then %do;
		
		 proc contents data = _temp_baseline_transposed out = name noprint;
		 quit;
		 proc sql noprint;
		  select distinct name into: col_list separated by " " from name
          where name like "COL%";
		 quit;

         data _temp_baseline_transposed;
           set _temp_baseline_transposed;
		   %do col_l = 1 %to %sysfunc(countw(&col_list));
		     switchstep_%eval(&col_l -1) = col&col_l;
		   %end;
		 run;

        %end;

        proc datasets library=WORK nowarn nolist;
            modify _temp_baseline_transposed;  
            rename col1=dp&dpnumber.;
            rename _name_ = metvar;
        quit;

        proc sort data=_temp_baseline_transposed;
            by analysisgrp group1 runid order cohort metvar ;
        run;

        /*if DPNUMBER =1 or &outdata does not exist, then output &outdata, else merge into existing outdata*/
        %if %eval(&dpnumber.=1) | %sysfunc(exist(&outdata.))=0 %then %do;
            data &outdata.;
                set _temp_baseline_transposed;
            run;
        %end;
        %else %do;
            data &outdata.;
                merge &outdata.
                      _temp_baseline_transposed(in=a);
                by analysisgrp group1 runid order cohort metvar;
            run;
        %end;

    %end; /*level 1 baseline tables*/


    /*********************************************************************************************/
    /* Level 2 baseline tables
    /*********************************************************************************************/

    %if %eval(&level.=2) %then %do;

        /*Loop through each runID, import, stack analysisgrps*/
				
        proc sql noprint;
            select distinct runid into: unique_baseline_runids separated by ' '
            from &GROUPTABLE.;
            select count(distinct runid) into: num_unique_baseline_runids
            from &GROUPTABLE.;
        quit;

        %do b = 1 %to %eval(&num_unique_baseline_runids.);
            %let runid = %scan(&unique_baseline_runids., &b., ' ');

            /*Ensure table exists: if it does not exist, write error to the log and abort*/
            %if %sysfunc(exist(&dpsiteid..&runid._adjusted_baseline_&periodid.))=0 %then %do;
		 		%put ERROR: &runid._adjusted_baseline_&periodid. for &dpsiteid. does not exist. Program will abort;
			 	%abort; 
		 	%end;

            /*Merge table with GROUPSTABLE and only keep Analysisgrps in the input file*/

            proc sql noprint;
                create table _temp_baseline_tablenum&b. as
                select x.*
                     , y.runid
                     , y.order
                from &dpsiteid..&runid._adjusted_baseline_&periodid. as x,
                     &GROUPTABLE.(where=(runid="&runid.")) as y
                where x.analysisgrp = y.group;
            quit;
        %end;

        /*Stack baseline tables*/
        data _temp_baseline_stacked;
            set _temp_baseline_tablenum:;

            /*defensive: set metvar to uppercase*/
            metvar=upcase(metvar);

            /*replace TOTAL with N_EPISODES and assign vartype to match L1 tables*/
            if metvar = 'TOTAL' then do;
                metvar = 'N_EPISODES';
                vartype = 'dichotomous';
            end;
        run;

        /*Add &DPNUMBER suffix to variables*/
        proc datasets library=work noprint;
                modify _temp_baseline_stacked;    
                rename  exp_mean = exp_mean&dpnumber.
                        exp_std = exp_std&dpnumber.
                        comp_mean = comp_mean&dpnumber.
                        comp_std = comp_std&dpnumber.
                        exp_s2 = exp_s2_&dpnumber.
                        comp_s2 = comp_s2_&dpnumber.
                        ad   = ad&dpnumber.
                        sd   = sd&dpnumber.
                        exp_w = exp_w1_&dpnumber.
                        exp_w2 = exp_w2_&dpnumber.
                        comp_w = comp_w1_&dpnumber.
                        comp_w2 = comp_w2_&dpnumber.;
        quit;

        proc sort data=_temp_baseline_stacked; 
            by analysisgrp runid order table group1 group2 weight vartype metvar;                 
        run;

        /*if DPNUMBER =1 or &outdata does not exist, then output &outdata, else merge into existing outdata*/
        %if %eval(&dpnumber.=1) | %sysfunc(exist(&outdata.))=0 %then %do;
            data &outdata.;
                set _temp_baseline_stacked;
            run;
        %end;
        %else %do;
            data &outdata.;
                merge &outdata.(in=a)
                      _temp_baseline_stacked;
                by analysisgrp runid order table group1 group2 weight vartype metvar; 
            run;
        %end;
			
    %end; /*level 2 baseline tables*/
					
    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _temp_baseline_:;
    quit;
    
	%put =====> END MACRO: baseline_aggregate;

%mend baseline_aggregate;
