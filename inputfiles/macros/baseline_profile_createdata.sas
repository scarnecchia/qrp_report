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

    /* Aggregate all potential profile datasets */

    %do periodid = %eval(&look_start.) %to %eval(&look_end.);

        /*loop through each DP*/
        %do dps = 1 %to %eval(&num_dp.);
            %let dpsiteid = %scan(&random_dplist., &dps.);
            %let maskedID = %scan(&masked_dplist, &dps); 

        %if &reporttype = T6 %then %do;
        proc sql noprint undo_policy=none;
            create table baselinefile_profile_&dps._&periodid. as 
            select a.*, b.switchstep 
            from baselinefile a 
            inner join alldptable1_&periodid.(where=(metvar = 'PATIENT' and exp_mean&dps > 0)) b
            on a.analysisgrp = b.analysisgrp;
        quit;
        %end;
        %else %do;
        data baselinefile_profile_&dps._&periodid;
            set baselinefile;
            switchstep=.;
        run;
        %end;

        data _temp_profile_tablenames;
            set baselinefile_profile_&dps._&periodid;
            if not missing(profilecovarstoinclude);
            length profiletablename $40.;
            if missing(cohort) then profiletablename = lowcase(cats("&dpsiteid..",runid, "_profile_&periodid"));
            else if cohort = 'switch' then profiletablename = lowcase(cats("&dpsiteid..",runid, "_profile_", cohort, "_", switchstep, "_&periodid"));
            else profiletablename = lowcase(cats("&dpsiteid..",runid, "_profile_", cohort, "_&periodid"));
        run;
            
        proc sql noprint;
            select distinct profiletablename into: profiletables separated by ' '
            from _temp_profile_tablenames;
            select count(distinct profiletablename) into: num_unique_profile_tables
            from _temp_profile_tablenames;
        quit;
        %put Extracting profile tables: &profiletables.;

          /*Loop through each baseline table, import, stack groups*/

        %do b = 1 %to %eval(&num_unique_profile_tables.);
            %let profiletable = %scan(&profiletables., &b., ' ');

            /*Merge table with GROUPSTABLE and only keep Groups/Analysisgrps in the input file*/
            data _temp_profile_tablenames&dps._&b.;
                set _temp_profile_tablenames(where=(profiletablename="&profiletable."));
                call symputx('mergevar', mergevar);
            run;

            proc sql noprint;
                create table _temp_profile_tablenum&dps._&b. as
                select x.*
                     , y.profiletablename
                     , &periodid. as periodid
                     , "&maskedID" as dpidsiteid length=6
                     , y.runid
                     , y.order
                     , y.cohort
                     , y.profilecovarstoinclude
                     , y.covarsort
                     %if "&mergevar" ne "analysisgrp" %then %do;
                     , y.analysisgrp
                     %end;
                     %else %do;
                     , y.analysisgrp as group
                     %end;
                     , y.group as group1
                     %if &reporttype = T6 %then %do;
                     , y.switchstep
                     %end;
                from &profiletable as x,
                     _temp_profile_tablenames&dps._&b. as y
                where x.&mergevar. = y.group;
            quit;

        %end;

        %end; /* DPS */

        /* Stack all DP datasets */
        data stacked_dps;
            set _temp_profile_tablenum:;
        run;

            proc sql noprint;
                select distinct order 
                into :profileorders separated by ' '
                from stacked_dps;
            quit;

            %do c = 1 %to %sysfunc(countw(&profileorders));
                %let profileorder = %scan(&profileorders,&c);

                data _temp_profilegroup_&c;
                    set stacked_dps(where=(order=&profileorder));
                    if lowcase(strip(profilecovarstoinclude)) = 'all' then profilecovarstoinclude = 'covar:';
                    call symputx('profilecovarsnocomma', compress(compbl(tranwrd(profilecovarstoinclude,',',', ')),','));
                run;

                proc means data=_temp_profilegroup_&c. nway missing noprint;
                    var npts n_episodes;
                    class periodid runid group order cohort %if &reporttype = T6 %then %do; switchstep %end; &profilecovarsnocomma;
                    output out=sum_agg_profile_&c(drop=_:)   
                    sum(npts n_episodes)=sum_npts sum_nepisodes;
                run;

                /* Stratified by DP */
                proc means data=_temp_profilegroup_&c. nway missing noprint;
                    var npts n_episodes;
                    class periodid runid dpidsiteid group order cohort %if &reporttype = T6 %then %do; switchstep %end; &profilecovarsnocomma;
                    output out=sum_dp_agg_profile_&c(drop=_:)   
                    sum(npts n_episodes)=sum_npts sum_nepisodes;
                run;
            %end;

        /*Stack profile tables within periodid*/
        data agg_profile_&periodid.;
            set sum_agg_profile:;
            if missing(cohort) then cohort='all';
        run;

        /* Stratified by dp to be used in stacking to other aggregated datasets*/
        data aggregate_dp_profile_&periodid;
            set sum_dp_agg_profile:;
        run;

        /* Rejoin profilecovarstoinclude to use in output macro */
        proc sql noprint undo_policy=none;
            create table agg_profile_&periodid as
            select a.*, b.profilecovarstoinclude 
            from agg_profile_&periodid a
            left join baselinefile b
            on a.group = b.group and a.runid = b.runid;
        quit;
		
	%output_datasets(dataset=aggregate_dp_profile_&periodid, outlib=msocdata, name=profile_&periodid);

    %end; /* periodid */

    /* Stacking periodid datasets together for final aggregation dataset */
    data aggregate_profile;
        set agg_profile:;
    run;

    data all_dp_profile;
        set aggregate_dp_profile:;
    run;

%mend baseline_profile_createdata;