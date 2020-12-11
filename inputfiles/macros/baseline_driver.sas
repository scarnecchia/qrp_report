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
            format cohort mergevar $15.;
            group=lowcase(group);
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
                set &outdata.(where=(upcase(includenonpregnant)='N')
                    &outdata.(where=(upcase(includenonpregnant)='Y')
                    &outdata.(in=a where=(upcase(includenonpregnant)='Y');
                if a then do;
                    cohort = "nopreg";
                end;
            run;
        %end;

        %if "&crosscheckvar" = "milgrp" %then %do;
            data &outdata.;
                set &outdata.(in=a)
                    &outdata.(in=b);
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

    ***********************************************************************************************;
    * Aggregate baseline tables across DPs                               
    ***********************************************************************************************;

    /*loop through each periodid*/
    %do periodid = %eval(&look_start.) %to %eval(&look_end.);

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

    %end;

    data output.alldp;set alldptable1_1; run;

    proc datasets nowarn noprint lib=work;
        delete baselinefile_:;
    quit;

    %end; /*baselinefile input file exists*/

    %put =====> END MACRO: baseline_driver ;

%mend baseline_driver;
