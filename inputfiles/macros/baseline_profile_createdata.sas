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
        /*Use GROUPTABLE to create list of baseline tables and create dataset in statement*/

        /*loop through each DP*/
        %do dps = 1 %to %eval(&num_dp.);
            %let dpsiteid = %scan(&random_dplist., &dps.);

        data _temp_profile_tablenames;
            set baselinefile;
            length profiletablename $40.;
            if missing(cohort) then do;
                profiletablename = lowcase(cats("&dpsiteid..",runid, "_profile_&periodid"));
            end;
            else do;
                profiletablename = lowcase(cats("&dpsiteid..",runid, "_profile_", cohort, "_&periodid"));
            end;
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
            data _temp_profile_tablenames&b.;
                set _temp_profile_tablenames(where=(profiletablename="&profiletable."));
                call symputx('mergevar', mergevar);
            run;

            proc sql noprint;
                create table _temp_profile_tablenum&b. as
                select x.*
                     , y.profiletablename
                     , y.runid
                     , y.order
                     , y.cohort
                     , y.profilecovarstoinclude
                     , y.covarsort
                     %if "&mergevar" ne "analysisgrp" %then %do;
                     , y.analysisgrp
                     %end;
                     , y.group as group1
                from &profiletable as x,
                     _temp_profile_tablenames&b. as y
                where x.&mergevar. = y.group;
            quit;

            proc sql noprint;
                select distinct order 
                into :profileorders separated by ' '
                from _temp_profile_tablenum&b.;
            quit;

            %do c = 1 %to %sysfunc(countw(&profileorders));
                %let profileorder = %scan(&profileorders,&c);

                data _temp_profilegroup&c;
                    set _temp_profile_tablenum&b.(where=(order=&profileorder));
                    if lowcase(strip(profilecovarstoinclude)) = 'all' then profilecovarstoinclude = 'covar:';
                    call symputx('profilecovarsnocomma', compress(profilecovarstoinclude,','));
                run;

                proc means data=_temp_profilegroup&c nway missing noprint;
                    var npts n_episodes;
                    class profiletablename runid group order &profilecovarsnocomma;
                    output out=sum_agg_profile&c(drop=_:)   
                    sum(npts n_episodes)=sum_npts sum_nepisodes;
                run;

            %end;

            data _temp_agg_group_profile&b;
                set sum_agg_profile:;
            run;
        %end;
        %end;
    %end;

    /*Stack profile tables*/
    data final_agg_profile;
        set _temp_agg_group_profile:;
    run;

%mend baseline_profile_createdata;