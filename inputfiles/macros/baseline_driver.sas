****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_driver.sas  
* Created (mm/dd/yyyy): 11/30/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of L1 and L2 baseline tables (Table 1s)
*                                        
*  Program inputs:                                                                                   
*
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
***************************************************************************************************;

%macro baseline_driver();

    %put =====> MACRO CALLED: baseline_driver;

    %isdata(dataset=input.&baselinefile.);
    %if %eval(&nobs.>0) %then %do;

    ***********************************************************************************************;
    * Create modified baseline dataset with COHORT and MERGEVAR vars to feed into %baseline_aggregate                                
    ***********************************************************************************************;

    %macro assign_cohort_mergevar(cohort=, mergevar=, outdata=, crosscheckfile = , crosscheckvar = ,includenonpregnant=N);

        data &outdata.;
            set input.&baselinefile.;
            format cohort mergevar analysisgrp $15.;
            group=lowcase(group);
            analysisgrp = group;
            runid=lowcase(runid);
            cohort = "&cohort";
            mergevar = "&mergevar";
        run;

        /*Only keep rows where group found in selected input file*/
        %if %str("&crosscheckfile") ne %str("") %then %do;

            /*dummy _crosscheck file*/
            data _crosscheck;
                format &crosscheckvar. $40. runid $5.;
                call missing(&crosscheckvar., runid);
            run;

            %do r=1 %to &numrunid.;
                %let runid = %scan(&runidlist., &r.);
                %isdata(dataset=infolder.&&&runid._&crosscheckfile);
                %if %eval(&nobs.>0) %then %do;
                    data _crosscheck&r.;
                        set infolder.&&&runid._&crosscheckfile(keep=&crosscheckvar.);
                        &crosscheckvar. = lowcase(&crosscheckvar.);
                        length runid $5.;
                        runid = "&runid.";
                    run;

                    proc append base=_crosscheck data=_crosscheck&r. force; run;
                %end;
            %end;

            proc sql noprint undo_policy=none;
                create table &outdata. as 
                select x.*
                from &outdata. as x,
                 _crosscheck as y
                where x.group = y.&crosscheckvar. and x.runid = y.runid;
            quit;

            proc datasets nowarn noprint lib=work;
            delete _crosscheck:;
            quit;
        %end;

        %if &includenonpregnant = Y %then %do;
            data &outdata.;
                set &outdata.(where=(upcase(includenonpregnant)='N'))
                    &outdata.(in=a where=(upcase(includenonpregnant)='Y'))
                    &outdata.(in=b where=(upcase(includenonpregnant)='Y'));
                if a then do;
                    cohort = "nopreg";
                    analysisgrp = group;
                end;
                if b then do;
                    analysisgrp = group;
                end;
            run;
        %end;

        %if "&crosscheckvar" = "milgrp" %then %do;
            data &outdata.;
                set &outdata.(in=a)
                    &outdata.(in=b);
                format analysisgrp $40.;
                if a then group = cats(group, '_eoi');
                if b then group = cats(group, '_ref');
            run;
        %end;
    %mend;

    /*T1 and T5 cohort is missing and mergevar = 'group'*/
    %if %sysfunc(prxmatch(m/T1|T5/i,&reporttype.)) > 0 %then %do;
        %assign_cohort_mergevar(cohort=, mergevar=group, outdata=baselinefile);
    %end;

    /*T2L1: - if group found in COHORTFILE, then cohort is missing and mergevar = 'group'
            - if group found in MULTEVENTFILE, then cohort = 'multevent' and mergevar = 'analysisgrp'
            - if group found in OVERLAPFILE, then cohort = 'overlap' and mergevar = 'analysisgrp'
            - if group found in CONCFILE, then cohort = 'concomitance' and mergevar = 'analysisgrp' */
    %else %if %str("&reporttype") = %str("T2L1") %then %do;
        %assign_cohort_mergevar(cohort=, mergevar=group, outdata=baselinefile_1, crosscheckfile = cohortfile, crosscheckvar=cohortgrp);
        %assign_cohort_mergevar(cohort=multevent, mergevar=analysisgrp, outdata=baselinefile_2, crosscheckfile = multeventfile, crosscheckvar=analysisgrp);
        %assign_cohort_mergevar(cohort=overlap, mergevar=analysisgrp, outdata=baselinefile_3, crosscheckfile = overlapfile, crosscheckvar=analysisgrp);
        %assign_cohort_mergevar(cohort=concomitance, mergevar=analysisgrp, outdata=baselinefile_4, crosscheckfile = concfile, crosscheckvar=analysisgrp);

        data baselinefile;
            set baselinefile_:;
        run;
    %end;

    /*T2L2 and T4L2: cohort is missing and mergevar = 'analysisgrp'*/
    %else %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
        %assign_cohort_mergevar(cohort=, mergevar=analysisgrp, outdata=baselinefile);
    %end;

   /*T4L1: - if group is found in COHORTFILE, then cohort= 'preg' and mergevar = 'group'
           - if group is found in COHORTFILE and INCLUDENONPREGNANT = Y then add new row to include cohort=nopreg and mergevar = 'group'
           - if group is found in MICOHORTFILE then cohort = 'mi' and mergevar = 'group'. Convert group to <group>_eoi and add new <group>_ref row */
    %else %if %str("&reporttype") = %str("T4L1") %then %do;
        %assign_cohort_mergevar(cohort=preg, mergevar=group, outdata=baselinefile_1, crosscheckfile = cohortfile, crosscheckvar=cohortgrp, includenonpregnant=Y);
        %assign_cohort_mergevar(cohort=mi, mergevar=group, outdata=baselinefile_2, crosscheckfile = micohortfile, crosscheckvar=milgrp);

        data baselinefile;
            set baselinefile_:;
        run;
    %end;

    /*T6: cohort is 'switchepisodes' and mergevar = 'analysisgrp'*/
    %else %if %str("&reporttype") = %str("T6") %then %do;
/*        %assign_cohort_mergevar(cohort=switchepisodes, mergevar=analysisgrp, outdata=baselinefile);*/
    %end;

    /*Determine number of unique group/analysisgrp baseline tables*/
    proc sql noprint;
        select max(order) into: numbaselinetablegrp
        from baselinefile;
    quit;

    ***********************************************************************************************;
    * Aggregate baseline tables across DPs                               
    ***********************************************************************************************;

    /*loop through each periodid*/
    %do periodid = %eval(&look_start.) %to %eval(&look_end.);

        /*loop through each DP*/
        %do dps = 1 %to %eval(&num_dp.);
            %let dpsiteid = %scan(&random_dplist., &dps.);
            %baseline_aggregate(dpsiteid = &dpsiteid.,
                                  dpnumber = &dps.,
                                  %if %index(&reporttype., L2)>0 %then %do;
                                  level = 2,
                                  %end;
                                  %else %do;
                                  level = 1,
                                  %end;
                                  grouptable = baselinefile,
                                  outdata = alldptable1_&periodid.,
                                  periodid = &periodid.);
        %end;

        ***********************************************************************************************;
        * Reformat L1 tables to mimic L2 format                             
        ***********************************************************************************************;

        %if %sysfunc(prxmatch(m/T1|T5|T2L1|T4L1/i,&reporttype.)) > 0 %then %do;

            %macro reformatL1baseline();
                /*split std metrics out so they can be remerged as separate column*/
                /*remove _MEAN and _STD prefix from metvar, add vartype, table, weight variables*/

                /*NOTE: additional metrics (AD, SD, %) computed in %baseline_compute()*/
                data _temp_mean_count
                     _temp_std(keep=metvar analysisgrp group1 runid order dp:);
                    set alldptable1_&periodid.;
                    format vartype table weight $30.;

                    /*table = Unadjusted*/
                    /*weight = 'Unweighted*/
                    table = 'Unadjusted';
                    weight = 'Unweighted';

                    if substr(metvar,1,4) = 'STD_' then do;
                        metvar = substr(metvar, 5);
                        output _temp_std;
                        vartype = 'continuous';
                    end;
                    else do;
                        if substr(metvar,1,5)='MEAN_' then do;
                            metvar = substr(metvar, 6);
                            vartype ='continuous';
                        end;
                        else do;
                            vartype ='dichotomous';
                        end;
                        output _temp_mean_count;
                    end;
                run;

                proc datasets nowarn noprint lib =work;
                    delete alldptable1_&periodid.;
                quit;

                /*loop through each ORDER value to build new table*/
                %do b = 1 %to %eval(&numbaselinetablegrp.);

                    /*when cohort = mi or nopreg then this will become a pairwise comparison mirroring group1 & group2*/
                    /*else, group1 will be populated and group2 metrics will be missing*/

                    data _temp_baseline&b.;
                        set baselinefile(where=(order=&b.));
                        if _n_ = 1 then do;
                        call symputx('includenonpregnant', upcase(includenonpregnant));
                        call symputx('cohortvalue', cohort);
                        end;
                    run;

                    %if %str("&includenonpregnant") = "Y" | %str("&cohortvalue") = %str("mi") %then %do;



                    %end;
                    %else %do;
                        /*only rows containing N_EPISODES and PATIENT - will become weights in final dataset*/
                        data _temp_totalcounts&b.;
                            merge _temp_mean_count(where=(order=&b. and metvar in ('N_EPISODES'))
                                   /*rename dp to n_episodes*/
                                   %do d =1 %to %eval(&num_dp.);
                                   rename=dp&d.=n_episodes&d.
                                   %end; )
                                  _temp_mean_count(where=(order=&b. and metvar in ('PATIENT'))
                                   /*rename dp to n_patients*/
                                   %do d =1 %to %eval(&num_dp.);
                                   rename=dp&d.=n_patients&d.
                                   %end; );  
                            by runid group1;
                            keep runid group1 n_:;
                        run;

                        data _temp_mean_count&b.;
                            merge _temp_mean_count(where=(order=&b.)
                                    /*rename dp to exp_mean*/
                                    %do d =1 %to %eval(&num_dp.);
                                    rename=dp&d.=exp_mean&d.
                                    %end; )
                            _temp_totalcounts&b.;
                            by runid group1;
                            format group2 $40.;
                            call missing(group2);

                            /*assign weights*/
                            array expvar{&num_dp.} exp_w1_1-exp_w1_&num_dp.;
                            array nepis{&num_dp.} n_episodes1-n_episodes&num_dp.;
                            array npat{&num_dp.} n_patients1-n_patients&num_dp.;
                        
                            do i = 1 to &num_dp.;
                                if metvar in ('N_EPISODES', 'PATIENT') then expvar(i) = .;
                                else if substr(metvar,1,4) = 'SEX_' | substr(metvar,1,5) = 'RACE_' | substr(metvar,1,9) = 'HISPANIC_' 
                                    then expvar(i) = npat(i);
                                else expvar(i) = nepis(i);
                            end;

                            drop i n_episodes: n_patients:;
                        run;

                        /*merge in std*/
                        proc sql noprint;
                            create table _temp_table1_reformat&b. as
                            select x.*
                                   %do d = 1 %to %eval(&num_dp.);
                                   , dp&d. as exp_std&d.
                                   %end;
                            from _temp_mean_count&b. as x
                            left join _temp_std(where=(order=&b.)) as y
                            on x.metvar = y.metvar;
                        quit;

                        proc append base=alldptable1_&periodid. data=_temp_table1_reformat&b.; run;
                    %end;





            

            
                %end;

            %mend reformatL1baseline;
            %reformatL1baseline();

        %end; /*reformat table*/





    %end; /*loop through periodid*/





    data output.alldp;set alldptable1_1; run;

    proc datasets nowarn noprint lib=work;
        delete baselinefile_: _temp_:;
    quit;

    %end; /*baselinefile input file exists*/

    %put =====> END MACRO: baseline_driver ;

%mend baseline_driver;
