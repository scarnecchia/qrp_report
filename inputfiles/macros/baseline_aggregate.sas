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
                          maskedid = ,
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

            /*If lab covariates specified, create comma separated list to ensure they exist in data */
            %let checkbaselinelabvars=;
            %if %length(&labcharacteristics) > 0 %then %do;
                proc contents data = &infile noprint out=_labvarsname(keep=name);
                run;

                %create_comma_charlist(inlist=&labcharacteristics, outlist=labcharscomma);
                
                /* Check to see if specified lab covariates exist */
                proc sql noprint;
                select name 
                into :checkbaselinelabvars 
                from _labvarsname
                where upper(name) in (&labcharscomma);
                quit;
            %end;

            proc sql noprint;
                create table _temp_baseline_tablenum&b. as
                select x.*
                     , y.runid
                     , y.order
                     , y.cohort
                    %if %length(&labcharacteristics) > 0 and %length(&checkbaselinelabvars) > 0 %then %do;
                        %do labvars = 1 %to %sysfunc(countw(&labcharacteristics));
                        %let labvar = %scan(&labcharacteristics,&labvars);
                        , n_episodes - &labvar as &labvar._notestrecord label="No test record"
                        %end;
                    %end;
                     %if "&mergevar" ne "analysisgrp" %then %do;
                     , y.analysisgrp
                     %end;
                     , y.group as group1
                from &infile. as x,
                     _temp_baseline_tablenames&b. as y
                where x.&mergevar. = y.group;
            quit;
        %end;

        /*Stack baseline tables*/
        data _temp_baseline_stacked;
            set _temp_baseline_tablenum:;
        run;

		/*if stratifying by data partner and collapse_vars = race, recode values 1-10 to Unknown*/
		%if "&stratifybydp." = "Y" and "&collapse_vars." = "race" %then %do;
            /*confirm race vars exist on dataset*/
            proc contents noprint data = _temp_baseline_stacked 
                                   out = content_out;
            run;

            proc sql noprint;
    		    select count(name) into :race_cats 
    		    from content_out
    		    where lowcase(name) like 'race_%';
            quit; 

            proc datasets nowarn noprint lib=work;
                delete content_out;
            quit;

            %if %eval(&race_cats>0) %then %do;

                /*type 6 - if any switch is collapsed, collapse all switches*/
                proc sort data=_temp_baseline_stacked;
                    by order %if &reporttype.=T6 %then %do; descending switchstep %end;;
                run;

                %let collapse_comparator = N;

                data _temp_baseline_stacked(drop=recode_:);
                    missing R;
                    set _temp_baseline_stacked;
                    by order;

                    /* Remove 0 from list and count */
                    %let race_cats_nozero = %sysfunc(tranwrd(&race_cats,0,%str()));
                    %let race_cats_count = %sysfunc(countw(&race_cats_nozero));

                    /*Recode*/
                    if first.order then do;
                        %do c_r = 1 %to &race_cats_count;
                            %let race_value = %scan(&race_cats_nozero,&c_r);
                        recode_&race_value. = 'N'; /*to track if another anchor switch or cohort collapsed*/
        		        if 1 <= race_&race_value <= 10 then do;
                            race_0 = sum(race_0, race_&race_value.);
                            /*set recoded value to special missing value to track in code and final table*/
                            race_&race_value. = .R;
                            recode_&race_value. = 'Y';
                        end;
                        retain recode_&race_value.;
                        %end;             
                    end;
                    else do;
                        %do c_r = 1 %to &race_cats_count;
                            %let race_value = %scan(&race_cats_nozero,&c_r);
        		        if 1 <= race_&race_value <= 10 | recode_&race_value. = 'Y' then do;
                            race_0 = sum(race_0, race_&race_value.);
                            /*set recoded value to special missing value to track in code and final table*/
                            race_&race_value. = .R;
                            recode_&race_value. = 'Y';
                            retain recode_&race_value.;
                        end;
                        %end;
                        /*mark if comparator cohort*/
                        %if &reporttype. ne T6 %then %do; call symputx('collapse_comparator', 'Y'); %end;
                    end;
                run; 

                %if &collapse_comparator = Y %then %do;
                /*if there is a comparator cohort, need to recode other group if a row has been collapsed in 1 group.
                  This is not needed for Type 6 because the at each switch, the # of patients will inherantly decrease, 
                  whereas for comparator cohorts this is not the case */
                    proc sort data=_temp_baseline_stacked out=_temp_baseline_stacked;
                        by order descending &mergevar.;
                    run;

                    data _temp_baseline_stacked(drop=recode_:);
                        set _temp_baseline_stacked;
                        by order;

                       /*Determine if other cohort was recoded*/
                        if first.order then do;
                            %do c_r = 1 %to &race_cats_count;
                                %let race_value = %scan(&race_cats_nozero,&c_r);
                            recode_&race_value. = 'N';
            		        if race_&race_value =.R then do;
                                recode_&race_value. = 'Y';
                            end;
                            retain recode_&race_value.;
                            %end;             
                        end;
                        else do;
                            %do c_r = 1 %to &race_cats_count;
                                %let race_value = %scan(&race_cats_nozero,&c_r);
            		        if recode_&race_value. = 'Y' then do;
                                race_0 = sum(race_0, race_&race_value.);
                                /*set recoded value to special missing value to track in code and final table*/
                                race_&race_value. = .R;
                            end;
                            %end;
                        end;
                    run; 
                %end;
            %end; /*race exists on dataset*/
        %end; /*collapse race categories*/

        /*Transpose and rename variable holding metrics to DP&DPNUMBER*/
        proc sort data=_temp_baseline_stacked;
            by analysisgrp group1 runid order cohort &switch_s;
        run;
		
		/*Determine the total number of episodes on the stacked dataset. A value of 0 indicates a default baseline table*/
		proc sql noprint;
		  select sum(n_episodes) into: total_episodes 
		  from _temp_baseline_stacked;
		quit;

        proc transpose data=_temp_baseline_stacked out=_temp_baseline_transposed;
            by analysisgrp group1 runid order cohort &switch_s; 
		run;

        proc datasets library=WORK nowarn nolist;
            modify _temp_baseline_transposed;  
            rename col1=dp&dpnumber.;
            rename _name_ = metvar;
        quit;

        proc sort data=_temp_baseline_transposed;
            by analysisgrp group1 runid order cohort metvar &switch_s;
        run;
		
		/* Change case of metvar from n_episodes to N_episodes for baseline datasets that have 0 total N_episodes */
		%if &total_episodes. = 0 %then %do;
		   data _temp_baseline_transposed;
		     set _temp_baseline_transposed;
             length _label_ $&baselinelabellength;
			 if metvar = 'n_episodes' then metvar = 'N_episodes';
             /* Initialize _label_ variable when there are no patients in the cohort */
            _label_='';
		   run;
		%end;

        /*if DPNUMBER =1 or &outdata does not exist, then output &outdata, else merge into existing outdata*/
        %if %eval(&dpnumber.=1) | %sysfunc(exist(&outdata.))=0 %then %do;
            data &outdata.;
                set _temp_baseline_transposed;
            run;
            data _baseline_agg_&periodid.;
                set _temp_baseline_stacked;
				length dpidsiteid $6;
                dpidsiteid = "&maskedid."; 
            run;
        %end;
        %else %do;
            data &outdata.;
                length metvar $32;
                merge &outdata.
                      _temp_baseline_transposed(in=a);
                by analysisgrp group1 runid order cohort metvar &switch_s;
            run;
            data _baseline_agg_&periodid.;
                set _baseline_agg_&periodid.
				    _temp_baseline_stacked (in=b);
                if b then dpidsiteid = "&maskedid.";  
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
                     , &periodid as monitoringperiod length=3
                from &dpsiteid..&runid._adjusted_baseline_&periodid. as x,
                     &GROUPTABLE.(where=(runid="&runid.")) as y
                where x.analysisgrp = y.group;
            quit;

			/* Get lab covariate labels from L1 baseline table variables */
			%if %length(&labcharacteristics) > 0 %then %do;
				data _temp_baseline_labcovars_&b.;
				set &dpsiteid..&runid._baseline_&periodid.(obs=1);
				run;
			%end;
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
                if exp_mean=. then exp_mean = 0;
                if comp_mean=. then comp_mean = 0;
            end;
        run;

		/* If lab covariates specified, create comma separated list to ensure they exist in data */
		%let checkbaselinelabvars=;
		%if %length(&labcharacteristics) > 0 %then %do;
			data _temp_baseline_labcovars;
			set _temp_baseline_labcovars_:;
			run;

		    proc contents data = _temp_baseline_labcovars noprint out=_labvarsname(keep=name label);
		    run;

		    %create_comma_charlist(inlist=&labcharacteristics, outlist=labcharscomma);
		    
		    /* Check to see if specified lab covariates exist */
		    proc sql noprint;
		    select name 
		    into :checkbaselinelabvars 
		    from _labvarsname
		    where upper(name) in (&labcharscomma);
		    quit;
		%end;

		%if %length(&labcharacteristics) > 0 and %length(&checkbaselinelabvars) > 0 %then %do;
			
			/* Compute Lab No Test Record observation */
			proc sort data=_temp_baseline_stacked;
			by analysisgrp group1 group2 table weight subgroup subgroupcat vartype runid order monitoringperiod;
			run;
			
			proc transpose data=_temp_baseline_stacked(where=(/* Restrict to Unweighted cohort */ weight="Unweighted" and vartype="dichotomous" and 
															 (metvar in:("COVAR") or metvar="N_EPISODES")))
						   out=_temp_baseline_stacked_trans;
			by analysisgrp group1 group2 table weight subgroup subgroupcat vartype runid order monitoringperiod;
			id metvar;
			run;

			data _temp_baseline_stacked_trans;
			set _temp_baseline_stacked_trans;	
		    %do labvars = 1 %to %sysfunc(countw(&labcharacteristics));
		    %let labvar = %scan(&labcharacteristics,&labvars);
				* Computation should be revised for Weighted cohort;
				if index(_name_, "w") > 0 or index(metvar, "w2") > 0 then  &labvar._NOTESTRECORD = &labvar;
		    	else &labvar._NOTESTRECORD = n_episodes - &labvar;
		    %end;
		    run;              

			proc transpose data=_temp_baseline_stacked_trans
						   out=_temp_baseline_stacked_trans(rename=_NAME_=metvar);
			by analysisgrp group1 group2 table weight subgroup subgroupcat vartype runid order monitoringperiod;
			id _NAME_;
			run;	

			data _temp_baseline_stacked;		
			set _temp_baseline_stacked
				_temp_baseline_stacked_trans(where=(index(metvar, "_NOTESTRECORD") > 0));
			run;

			proc sort data=_temp_baseline_stacked;
			by metvar;
			run;

			* Get lab covariate labels;
			data _labvarsname;
			set _labvarsname;
			format metvar $30.;
			name=upcase(name);
			if index(name,"COVAR")>0;
			metvar=tranwrd(name, "MEAN_", "");
			metvar=strip(tranwrd(metvar, "STD_", ""));
			drop name;
			run;

			proc sort nodupkey data=_labvarsname;
			by metvar;
			run;

			data _temp_baseline_stacked(rename=label=_label_);
			merge _temp_baseline_stacked
				  _labvarsname;
			by metvar;
			if index(metvar, "_NOTESTRECORD")>0 then do;
				label="No test record";

				* Computation should be revised in the future for Weighted cohort;
				exp_S2=exp_std*(1-exp_std);
				comp_S2=comp_std*(1-comp_std);		
		        ad=exp_std-comp_std;        
		        if sum(exp_S2,comp_S2)>0 then sd=(exp_std-comp_std)/sqrt((exp_S2+comp_S2)/2);
			end;
			run;		
		%end;

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
            by analysisgrp runid order table group1 group2 weight subgroup subgroupcat vartype metvar;                 
        run;

        /*if DPNUMBER =1 or &outdata does not exist, then output &outdata, else merge into existing outdata*/
        %if %eval(&dpnumber.=1) | %sysfunc(exist(&outdata.))=0 %then %do;
            data &outdata. (drop=dpidsiteid) 
			     _baseline_agg_&periodid. (rename=(exp_mean&dpnumber.=exp_mean
												   exp_std&dpnumber.=exp_std
												   comp_mean&dpnumber.=comp_mean
												   comp_std&dpnumber.=comp_std
												   exp_s2_&dpnumber.=exp_s2
												   comp_s2_&dpnumber.=comp_s2
												   ad&dpnumber.=ad
												   sd&dpnumber.=sd
												   exp_w1_&dpnumber.=exp_w
												   exp_w2_&dpnumber.=exp_w2
												   comp_w1_&dpnumber.=comp_w
												   comp_w2_&dpnumber.=comp_w2));
                set _temp_baseline_stacked;
				length dpidsiteid $6 monitoringperiod 3;
                dpidsiteid = "&maskedid."; 
                monitoringperiod=&periodid;
            run;
        %end;
        %else %do;
            data &outdata.;
                merge &outdata.(in=a)
                      _temp_baseline_stacked;
                by analysisgrp runid order table group1 group2 weight subgroup subgroupcat vartype metvar; 
            run;
            data _baseline_agg_&periodid.;
                set _baseline_agg_&periodid.
				    _temp_baseline_stacked (in=b rename=(exp_mean&dpnumber.=exp_mean
													     exp_std&dpnumber.=exp_std
						  							     comp_mean&dpnumber.=comp_mean
													     comp_std&dpnumber.=comp_std
													     exp_s2_&dpnumber.=exp_s2
													     comp_s2_&dpnumber.=comp_s2
													     ad&dpnumber.=ad
													     sd&dpnumber.=sd
													     exp_w1_&dpnumber.=exp_w
													     exp_w2_&dpnumber.=exp_w2
													     comp_w1_&dpnumber.=comp_w
													     comp_w2_&dpnumber.=comp_w2));
                if b then do;
                dpidsiteid = "&maskedid.";
                monitoringperiod=&periodid;
                end;  
            run;
        %end;
		
        proc sort data=_baseline_agg_&periodid.; 
            by dpidsiteid analysisgrp runid order table group1 group2 weight subgroup subgroupcat vartype metvar;                 
        run;
			
    %end; /*level 2 baseline tables*/
						
    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _temp_baseline_:;
    quit;
    
	%put =====> END MACRO: baseline_aggregate;

%mend baseline_aggregate;
