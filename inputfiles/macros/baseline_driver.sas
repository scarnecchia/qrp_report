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
            format cohort mergevar $15. analysisgrp $40.;
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

    /*T6: cohort is 'switch' and mergevar = 'analysisgrp'*/
    %else %if %str("&reporttype") = %str("T6") %then %do;
        %assign_cohort_mergevar(cohort=switch, mergevar=analysisgrp, outdata=baselinefile);
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

        %if %sysfunc(prxmatch(m/T1|T5|T2L1|T4L1|T6/i,&reporttype.)) > 0 %then %do;

            %macro reformatL1baseline();
                /*split std metrics out so they can be remerged as separate column*/
                /*remove _MEAN and _STD prefix from metvar, add vartype, table, weight variables*/

                /*NOTE: additional metrics (AD, SD, %) computed in %baseline_compute()*/
                data _temp_mean_count
                     _temp_std(keep=metvar group1 cohort order dp:
                       %if %str("&reporttype") = %str("T6") %then %do;
			            Switchstep
			           %end;);
                    set alldptable1_&periodid.;
                    format vartype $30.;

                    /*defensive: set metvar to uppercase*/
                    metvar=upcase(metvar);
             
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

                proc sort data=_temp_mean_count;
                    by order metvar vartype 
                    %if %str("&reporttype") = %str("T6") %then %do;
			          Switchstep
			        %end;;
                run;

                /*loop through each ORDER value to build new table*/
                %do b = 1 %to %eval(&numbaselinetablegrp.);
                    data _null_;
                        set baselinefile(where=(order=&b.));
                        if _n_ = 1 then do;
                            %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2") %then %do;
                            call symputx('includenonpregnant', upcase(includenonpregnant));
                            %end;
                            %else %do;
                            call symputx('includenonpregnant', 'N');
                            %end;
                            call symputx('cohortvalue', cohort);
                            call symputx('analysisgrp', analysisgrp);
                            call symputx('computebalance', upcase(computebalance));

                            /*if includenonpregnant = Y, group1=preg and group2=nonpreg*/
                            /*when cohort = mi, group1= _eoi and group2=_ref*/
                            /*otherwise, group2 will not be populated*/
                            if upcase(includenonpregnant) = 'Y' then do;
                                call symputx('group1where',"and cohort='preg'");
                                call symputx('group2where',"and cohort='nopreg'");
                                call symputx('createcompcolumns', 'Y');
                            end;
                            else if cohort = "mi" then do;
                                call symputx('group1where',"and substr(group1, length(group1)-3, length(group1))='_eoi'");
                                call symputx('group2where',"and substr(group1, length(group1)-3, length(group1))='_ref'");
                                call symputx('createcompcolumns', 'Y');
                            end;
                            else do;
                                call symputx('group1where',"");
                                call symputx('group2where',"");
                                call symputx('createcompcolumns', 'N');
                            end;
                        end;
                    run;

					/*only rows containing N_EPISODES and PATIENT - will become weights in final dataset*/
                    data _temp_totalcounts&b.;
                        merge /*EOI*/
                            _temp_mean_count(keep=order group1 cohort metvar dp: 
							    %if %str("&reporttype") = %str("T6") %then %do;
			                      Switchstep
			                    %end;
                                where=(order=&b. and metvar in ('N_EPISODES') &group1where.)
                                /*rename dp to n_episodes_exp*/
                                %do d =1 %to %eval(&num_dp.);
                                rename=dp&d.=n_episodes_exp&d.
                                %end; )
                            _temp_mean_count(keep=order group1 cohort metvar dp: 
							  %if %str("&reporttype") = %str("T6") %then %do;
			                    Switchstep
			                  %end;
                              where=(order=&b. and metvar in ('PATIENT') &group1where.)
                               /*rename dp to n_patients_exp*/
                               %do d =1 %to %eval(&num_dp.);
                               rename=dp&d.=n_patients_exp&d.
                               %end; )

                            %if &createcompcolumns = Y %then %do;
                               /*REF*/
                               _temp_mean_count(keep=order group1 cohort metvar dp: 
							     %if %str("&reporttype") = %str("T6") %then %do;
			                      Switchstep
			                    %end;
                                 where=(order=&b. and metvar in ('N_EPISODES') &group2where.)
                               /*rename dp to n_episodes_comp*/
                               %do d =1 %to %eval(&num_dp.);
                               rename=dp&d.=n_episodes_comp&d.
                               %end; )
                               _temp_mean_count(keep=order group1 cohort metvar dp:
							    %if %str("&reporttype") = %str("T6") %then %do;
			                     Switchstep
			                    %end;
                                where=(order=&b. and metvar in ('PATIENT') &group2where.)
                               /*rename dp to n_patients_comp*/
                               %do d =1 %to %eval(&num_dp.);
                               rename=dp&d.=n_patients_comp&d.
                               %end; )
                            %end;
                                ;
                        by order 
                          %if %str("&reporttype") = %str("T6") %then %do;
			                Switchstep
			              %end;;
                        keep order n_: 
                             %if %str("&reporttype") = %str("T6") %then %do;
			                   Switchstep
			                 %end;;
                    run;

					/*merge GROUP1 and GROUP2*/
                    data _temp_mean_count&b.;
                       merge _temp_mean_count(where=(order=&b. &group1where.)
                                /*rename dp to exp_mean*/
                                %do d =1 %to %eval(&num_dp.);
                                rename=dp&d.=exp_mean&d.
                                %end; )
                        %if &createcompcolumns = Y %then %do;
                            _temp_mean_count(where=(order=&b. &group2where.)
                                /*rename dp to exp_mean*/
                                %do d =1 %to %eval(&num_dp.);
                                rename=dp&d.=comp_mean&d.
                                %end; )
                        %end; ;
                        by order metvar vartype  
                           %if %str("&reporttype") = %str("T6") %then %do;
			                 Switchstep
			               %end;;
                    run;
          
                    /*merge in std*/
                    proc sql noprint;
                        create table _temp_formatted_&b. as
                        select x.*
                               %do d = 1 %to %eval(&num_dp.);
                                   , y.dp&d. as exp_std&d.
                                   %if &createcompcolumns = Y %then %do;
                                   , z.dp&d. as comp_std&d.
                                   %end;
                               %end;
                        from _temp_mean_count&b. as x
                        left join _temp_std(where=(order=&b. &group1where.)) as y
                        on x.metvar = y.metvar
                        %if &createcompcolumns = Y %then %do;
                        left join _temp_std(where=(order=&b. &group2where.)) as z
                        on x.metvar = z.metvar
                        %end;
                        ;
                    quit;

                    %macro assignexpcompvar(var=);
                        array &var.var1{&num_dp.} &var._w1_1-&var._w1_&num_dp.;
                        array &var.var2{&num_dp.} &var._w2_1-&var._w2_&num_dp.;
                        array nepis_&var.{&num_dp.} n_episodes_&var.1-n_episodes_&var.&num_dp.;
                        array npat_&var.{&num_dp.} n_patients_&var.1-n_patients_&var.&num_dp.;
                        array &var.mean{&num_dp.} &var._mean1-&var._mean&num_dp.;
                        array &var.std{&num_dp.} &var._std1-&var._std&num_dp.;
                        array &var.s2{&num_dp.} &var._s2_1-&var._s2_&num_dp.;

                        do &var. = 1 to &num_dp.;
                            /*initalize new vars to missing*/
                            &var.var1(&var.) = .;
                            &var.var2(&var.) = .;
                            &var.s2(&var.) = .;
                           
                            /*weights*/
                            if substr(metvar,1,4) = 'SEX_' | substr(metvar,1,5) = 'RACE_' | substr(metvar,1,9) = 'HISPANIC_' then do;
                                &var.var1(&var.) = npat_&var.(&var.);
                                &var.var2(&var.) = npat_&var.(&var.);
                            end;
                            else do;
                                &var.var1(&var.) = nepis_&var.(&var.);
                                &var.var2(&var.) = nepis_&var.(&var.);
                            end;

                            /*percent*/
                            if vartype = 'dichotomous' then do;
                                if missing(&var.mean(&var.)) then &var.mean(&var.) = 0;
                                if &var.var1(&var.)>0 then &var.std(&var.) = &var.mean(&var.) / &var.var1(&var.);
                                else if &var.var1(&var.)=0 then &var.std(&var.) = 0;
                                if &var.std(&var.)>0 then &var.s2(&var.)=&var.std(&var.)*(1-&var.std(&var.));
                                else &var.s2(&var.) = 0;
                            end;

                            /*s2*/
                            else if vartype = 'continuous' then do;
                                if &var.std(&var.)>0 then &var.s2(&var.) = &var.std(&var.)*&var.std(&var.);
                                else &var.s2(&var.) = 0;
                            end;
                        end;
                        drop &var.;
                    %mend;

                    data _temp_table1_reformat&b.;
                        merge _temp_formatted_&b.
                              _temp_totalcounts&b.;
                        by order;
                        format group2 $40. table weight $30.;

                        /*table = Unadjusted*/
                        /*weight = 'Unweighted*/
                        table = 'Unadjusted';
                        weight = 'Unweighted';

                        %if &createcompcolumns = Y %then %do;
                            %if "&includenonpregnant" = "Y" %then %do;
                                group1 = "preg";
                                group2 = "nopreg";
                            %end;
                            %else %if %str("&cohortvalue") = %str("mi") %then %do;
                                group1 = cats("&analysisgrp", "_eoi");
                                group2 = cats("&analysisgrp", "_ref");
                            %end;
                        %end;
                        %else %do;
                            call missing(group2);
                        %end;

                        /*assign weights: 
                          - COMP vars missing when no group2 value and for PATIENT/N_EPISODES rows
                          - weights - patient count for sex, race, and hispanic because % is patient based
                          - weights - episode count for all other metrics because metric is episode based */

                        /*compute %, sd2 columns, and AD/SD when computebalance = Y*/
                        %assignexpcompvar(var=exp);
                        %if &createcompcolumns = Y %then %do;
                        %assignexpcompvar(var=comp);
                        %end;

                        /*AD and SD*/
                        %if &computebalance = Y & &createcompcolumns = Y %then %do;

                        array abdiff{&num_dp.} ad1-ad&num_dp.;
                        array stdiff{&num_dp.} sd1-sd&num_dp.;

                        do i= 1 to &num_dp.;
                            abdiff(i)=.;
                            stdiff(i)=.;

                            if vartype = 'dichotomous' then do;
                                abdiff(i)=expstd(i)-compstd(i);
                                if sum(exps2(i),comps2(i))>0 then stdiff(i)=(expstd(i)-compstd(i))/sqrt((exps2(i)+comps2(i))/2);
                            end;
                            if vartype = 'continuous' then do;
                                abdiff(i)=expmean(i)-compmean(i);
                                if sum(expstd(i),compstd(i))>0 then stdiff(i)=(expmean(i)-compmean(i))/sqrt(((expstd(i)*expstd(i))+(compstd(i)*compstd(i)))/2);
                            end;
                        end;
                        drop i;
                        %end;

                        drop n_episodes: n_patients:;
                    run;

                    /*use set to avoid missing var warnings*/
                    %if %eval(&b.=1) %then %do;
                        data alldptable1_&periodid.;
                            set _temp_table1_reformat&b.;
                        run;
                    %end;
                    %else %do;
                        data alldptable1_&periodid.;
                            set alldptable1_&periodid.
                                _temp_table1_reformat&b.;
                        run;
                    %end;
                %end;

            %mend reformatL1baseline;
            %reformatL1baseline();

        %end; /*reformat table*/

        ***********************************************************************************************;
        * Compute Aggregate metrics and format DP metrics                       
        ***********************************************************************************************;

        %baseline_compute(datain=alldptable1_&periodid.,
                          dataout=table1_&periodid.,
                          reporttype =&reporttype.,
                          numbaselinetablegrp = &numbaselinetablegrp.,
                          num_dp = &num_dp.,
                          stratifybydp = &stratifybydp.,
                          periodid = &periodid.);
        

    %end; /*loop through periodid*/

    proc datasets nowarn noprint lib=work;
        delete baselinefile_: _temp_: alldptable1_:;
    quit;

    %end; /*baselinefile input file exists*/

    %put =====> END MACRO: baseline_driver ;

%mend baseline_driver;
