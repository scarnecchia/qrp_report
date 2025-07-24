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

    /* Type 6 baseline tables contain 1 row per switch and these switches need to be included in all 'by' processing*/
    %if %str("&reporttype") = %str("T6") %then %do;
      %let Switch_s = switchstep;
    %end;
	%else %do;
	  %let Switch_s = ;
	%end;

    ***********************************************************************************************;
    * Create modified baseline dataset with COHORT and MERGEVAR vars to feed into %baseline_aggregate                                
    ***********************************************************************************************;

    %macro assign_cohort_mergevar(cohort=, mergevar=, outdata=, crosscheckfile = , crosscheckvar = ,includenonpregnant=N);
	
        data &outdata.;
            set 
            %if ^%index(&reporttype,T4L1) %then %do;
            input.&baselinefile.
            %end;
            %else %do;
            baseline_preg_labels 
            %end;
            ;
            format cohort mergevar $15. analysisgrp $40. unique_psestimate 3.;
            group=lowcase(group);
            analysisgrp = group;
            runid=lowcase(runid);
            cohort = "&cohort";
            mergevar = "&mergevar";
			unique_psestimate = 1;
        run;
		
		/* Identify unique psestimategrp for L2 reports */
		%if %sysfunc(index(&reporttype.,L2)) > 0 %then %do;
		   proc sql noprint;
		     create table &outdata._ps as
		       select base.*
		   	      ,pscs.psestimategrp
		       from &outdata. as base
		   	left join pscs_masterinputs (where = (missing(subgroup))) as pscs
		   	  on base.runid = pscs.runid
			  and base.analysisgrp = pscs.analysisgrp
		      order by runid, psestimategrp, order;
		   quit;
		   
		   data &outdata.;
		     set &outdata._ps (drop = unique_psestimate); /* Remove default value */
		     length unique_psestimate 3;
		     retain unique_psestimate;
		     by runid psestimategrp order;
		     unique_psestimate +1;
             if missing(psestimategrp) or first.psestimategrp then unique_psestimate = 1;
		   run;
		   
		   proc sort data = &outdata.;
		     by order;
		   run;
        %end;
		
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

			%if "&crosscheckvar" = "milgrp" %then %do;
				data _crosscheck;
				set _crosscheck(in=a)
					_crosscheck(in=b where=(missing(milgrp)=0));
				if a and missing(milgrp)=0 then milgrp=strip(milgrp) || "_eoi";
				else if b then milgrp=strip(milgrp) || "_ref";
				run;			
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
                if (a or b) and not missing(baselinegroupnum) then do;
				    put 'ERROR: (Sentinel) BASELINEGROUPNUM cannot be used with INCLUDENONPREGNANT=Y'; 					
					abort;
				end;
            run;
        %end;        
    %mend;

    /*T1, T3 and T5 cohort is missing and mergevar = 'group'*/
    %if %sysfunc(prxmatch(m/T1|T3|T5/i,&reporttype.)) > 0 %then %do;
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

    /*T2L2, T4L2: cohort is missing and mergevar = 'analysisgrp'*/
    %else %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
        %assign_cohort_mergevar(cohort=, mergevar=analysisgrp, outdata=baselinefile);
    %end;

   /*T4L1: - if group is found in COHORTFILE, then cohort= 'preg' and mergevar = 'group'
           - if group is found in COHORTFILE and INCLUDENONPREGNANT = Y then add new row to include cohort=nopreg and mergevar = 'group'
           - if group is found in MICOHORTFILE then cohort = 'mi' and mergevar = 'group'.*/
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
        
        /* Check to see if profilecovarstoinclude is populated */
        select count(profilecovarstoinclude) into: numprofilecovarstoinclude
        from baselinefile
        where not missing(profilecovarstoinclude);
    quit;

    ***********************************************************************************************;
    * Aggregate baseline tables across DPs                               
    ***********************************************************************************************;

    /*loop through each periodid*/
    %do periodid = %eval(&look_start.) %to %eval(&look_end.);

		/* Defensive: make sure labcharacteristics does not contain any double quotes. This can happen when &look_end. > 1 and it will cause the code to error out */
		%let labcharacteristics= %qsysfunc(compress((&labcharacteristics),%str((%"))));

        /*loop through each DP*/
        %do dps = 1 %to %eval(&num_dp.);
            %let dpsiteid = %scan(&random_dplist., &dps.);
			%let maskedid = %scan(&masked_dplist, &dps);

            %baseline_aggregate(dpsiteid = &dpsiteid.,
								maskedid = &maskedid.,
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

		%output_datasets(dataset=_baseline_agg_&periodid., outlib=msocdata, 
		%if %index(&reporttype., L2)>0 %then %do; name=adjusted_baseline_&periodid. %end;
		%else %do; name=baseline_&periodid. %end;);
		
        ***********************************************************************************************;
        * Reformat L1 tables to mimic L2 format                             
        ***********************************************************************************************;

        %if %sysfunc(prxmatch(m/T1|T3|T5|T2L1|T4L1|T6/i,&reporttype.)) > 0 %then %do;

            /*split std metrics out so they can be remerged as separate column*/
            /*remove _MEAN and _STD prefix from metvar, add vartype, table, weight variables*/
            /*NOTE: additional metrics (AD, SD, %) computed in %baseline_compute()*/
            data _temp_mean_count
                 _temp_std(keep=metvar group1 cohort order dp: &Switch_s);
                set alldptable1_&periodid.;
                format vartype $30.;
         
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

            /*put maximum number of switches into macro variable switch_counter*/
            %if %str("&reporttype") = %str("T6") %then %do; 
			  proc sql noprint;
	            select max(switchstep) into: switch_counter from alldptable1_&periodid. where upcase(metvar) = 'N_EPISODES' ;
	          quit;
			%end;

			proc datasets nowarn noprint lib= work;
			  delete alldptable1_&periodid. baseline_preg_labels;
			quit;

            proc sort data=_temp_mean_count;
                by order metvar vartype &Switch_s;
            run;

            proc sort data=baselinefile;
                by order baselinegroupnum;
            run;

            %macro reformatL1baseline(switch = );

                /*to restrict type 6 switching tables*/
                %let switch_where = ;
                %if %str("&reporttype") = %str("T6")  %then %do;
                    %let switch_where = and switchstep = &switch;
                %end;

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
                            call symputx('baselinegroupnum', baselinegroupnum);

                            /*if includenonpregnant = Y, group1=preg and group2=nonpreg*/                            
                            *if baselinegroupnum is specified, group1 = baselinegroupnum = 1 and group2 = baselinegroupnum = 2;
                            /*otherwise, group2 will not be populated*/
                            if upcase(includenonpregnant) = 'Y' then do;
                                call symputx('group1where',"and cohort='preg'");
                                call symputx('group2where',"and cohort='nopreg'");
                                call symputx('createcompcolumns', 'Y');
                            end;                            
                            else if missing(baselinegroupnum)=0 then do;
                                call symputx('group1where','and group1="&analysisgrp"');
                                call symputx('createcompcolumns', 'Y');
                            end;
                            else do;
                                call symputx('group1where',"");
                                call symputx('group2where',"");
                                call symputx('createcompcolumns', 'N');
                            end;
                        end;
                        /*if baselinegroupnum is specified, a 2nd row will exist in the file*/
                        if _n_ = 2 then do;
                        if missing(baselinegroupnum)=0 then do;
                            call symputx('group2where','and group1="&analysisgrp2"');
                            call symputx('analysisgrp2',analysisgrp);
                        end;
                        end;
                    run;

                    %let totallabcovar = 0;
                    %let labunitcovars=;
                    %let checklabvars=;
                    %if %length(&labcharacteristics) > 0 %then %do;
                    /* Computations for lab covariates will only occur correctly for ones specified in
                       the LABCHARACTERISTICS parameter. Other lab covariates will be carried through but 
                       will not be included in final table 1 dataset */

                        /* Count the number of lab covariates requested in LABCHARACTERISTICS parameter */
                        %let totallabcovar = %sysfunc(countw(&labcharacteristics));
                        /* Find and match all the lab unit related lab covariates, put in list */
                        proc sql noprint;
                            select distinct metvar 
                            into :labunitcovars separated by ' ' 
                            from _temp_mean_count
                            where order=&b 
                            %do i = 1 %to &totallabcovar;
                                %let lab = %scan(&labcharacteristics,&i);
                                %if &i = 1 %then %do; and %end; %else %do; or %end; 
                                index(metvar,cats("N_","&lab","LBUNIT")) 
                            %end; 
                            ;

                            /* Check if data actually has lab variables */
                            select distinct metvar 
                            into :checklabvars separated by ' '
                            from _temp_mean_count
                            where order=&b and prxmatch('/LBUNIT|LBRES/',metvar) > 0;
                        quit;

                        /* Count up the unique number of lab covariates with units to loop through later */
                        %if %length(&labunitcovars) > 0 %then %let totallabunits = %sysfunc(countw(&labunitcovars));
                        %else %let totallabunits = 0;
                    %end;

                    /* Assigns and extracts various rows from _temp_mean_count */
                    %macro assigndataset(wherevalue=, var=, varname=, group=);
                                _temp_mean_count(keep=order group1 cohort metvar &Switch_s dp:
                                where=(order=&b. and &wherevalue &group &switch_where )
                                /*rename dp to &varname._&var*/
                                %do d =1 %to %eval(&num_dp.);
                                rename=dp&d.=&varname._&var.&d.
                                %end; )
                    %mend assigndataset;

					/*only rows containing N_EPISODES and PATIENT - will become weights in final dataset*/
                    data _temp_totalcounts&b.&switch.; 
                        merge /*EOI*/
                            %assigndataset(wherevalue=%str(metvar in ("N_EPISODES")), var=exp, varname=n_episodes, group=&group1where)
                            %assigndataset(wherevalue=%str(metvar in ("PATIENT")), var=exp, varname=n_patients, group=&group1where)

                            /* If lab covariates are requested, loop through and assign covariate count for categorical labs */
                            %if &totallabcovar > 0 and %length(&checklabvars) > 0 %then %do;
                                %do labcount = 1 %to &totallabcovar;
                                    %let lab = %scan(&labcharacteristics,&labcount);
                                    %assigndataset(wherevalue=%str(upcase(metvar) = "&lab"), var=exp, varname=n_&lab, group=&group1where)
                                %end;

                                /* Loop through unique number of lab covariates with units for numeric labs */
                                %do labunitcount = 1 %to &totallabunits;
                                    %let labunitvar = %scan(&labunitcovars,&labunitcount);
                                    %assigndataset(wherevalue=%str(index(metvar,"&labunitvar")), var=exp, varname=&labunitvar, group=&group1where)
                                %end;
                            %end; /* totallabcovar > 0 */

                            %if &createcompcolumns = Y %then %do;
                               /*REF*/
                                %assigndataset(wherevalue=%str(metvar in ("N_EPISODES")), var=comp, varname=n_episodes, group=&group2where)
                                %assigndataset(wherevalue=%str(metvar in ("PATIENT")), var=comp, varname=n_patients, group=&group2where)

                            /* If lab covariates are requested, loop through and assign covariate count for categorical labs */
                               %if &totallabcovar > 0 and %length(&checklabvars) > 0 %then %do;
                                    %do labcount = 1 %to &totallabcovar;
                                        %let lab = %scan(&labcharacteristics,&labcount);
                                        %assigndataset(wherevalue=%str(upcase(metvar) = "&lab"), var=comp, varname=n_&lab, group=&group2where)
                                    %end;
                                    /* Loop through unique number of lab covariates with units for numeric labs */
                                    %do labunitcount = 1 %to &totallabunits;
                                        %let labunitvar = %scan(&labunitcovars,&labunitcount);
                                        %assigndataset(wherevalue=%str(index(metvar,"&labunitvar")), var=comp, varname=&labunitvar, group=&group2where)
                                    %end;
                                %end; /* totallabcovar > 0 */
                            %end;
                                ;
                       by order &Switch_s;
                       keep order n_: &Switch_s;
                    run;

					/*merge GROUP1 and GROUP2*/
                    data _temp_mean_count&b.&switch.;
                       merge _temp_mean_count(where=(order=&b. &group1where. &switch_where)
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
                        by order metvar vartype &Switch_s;
                    run;
          
                    /*merge in std*/
                    proc sql noprint;
                        create table _temp_formatted_&b.&switch. as
                        select x.*
                               %do d = 1 %to %eval(&num_dp.);
                                   , y.dp&d. as exp_std&d.
                                   %if &createcompcolumns = Y %then %do;
                                   , z.dp&d. as comp_std&d.
                                   %end;
                               %end;
                        from _temp_mean_count&b.&switch. as x
                        left join _temp_std(where=(order=&b. &group1where. &switch_where.)) as y
                        on x.metvar = y.metvar
						%if %str("&reporttype") = %str("T6") %then %do;
                          and x.switchstep = y.switchstep
						%end;
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
                        /* Store results for lab covariates in array - one array for categorical, one for continuous */
                        %if &totallabcovar > 0 and %length(&checklabvars) > 0 %then %do;
                            %do labcount = 1 %to &totallabcovar;
                                %let lab = %scan(&labcharacteristics,&labcount);
                            array n&lab._&var.{&num_dp.} n_&lab._&var.1-n_&lab._&var.&num_dp.; 
                            %end;
                            %do labunitcount = 1 %to &totallabunits;
                                %let labunitvar = %scan(&labunitcovars,&labunitcount);
                            array &labunitvar._&var.{&num_dp.} &labunitvar._&var.1-&labunitvar._&var.&num_dp.; 
                            %end;
                        %end;
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
                            /* Assign weights for lab covariates */
                            %if &totallabcovar > 0 and %length(&checklabvars) > 0 %then %do;
                                %do labcount = 1 %to &totallabcovar;
                                    %let lab = %scan(&labcharacteristics,&labcount);
                                    else if prxmatch("/^N_&lab.$/",prxchange('s/(LBRES).*//',-1,metvar)) and vartype='dichotomous' then do; 
                                        &var.var1(&var) = n&lab._&var.(&var);
                                        &var.var2(&var.) = n&lab._&var.(&var);
                                    end;
                                %end;

                                /* Extract the covar value and unit associated, store in separate macro variables */
                                %do labunitcount = 1 %to &totallabunits;
                                    %let labunitvar = %scan(&labunitcovars,&labunitcount);
                                    %let labcovar = %scan(%sysfunc(prxchange(s/(LBUNIT).*//,-1,&labunitvar)),-1,%str(_));
                                    %let labunit = %sysfunc(prxchange(s/^[^_]*_[^_]*_//,-1,&labunitvar));
                                    else if metvar = cats("&labcovar","LBRES_","&labunit") and vartype='continuous' then do; 
                                        &var.var1(&var) = &labunitvar._&var.(&var);
                                        &var.var2(&var.) =&labunitvar._&var.(&var);
                                    end;
                                %end;
                            %end;
                            else do;
                                &var.var1(&var.) = nepis_&var.(&var.);
                                &var.var2(&var.) = nepis_&var.(&var.);
                            end;

                            /*percent*/
                            if vartype = 'dichotomous' then do;
                                if missing(&var.mean(&var.)) and &var.mean(&var.) ne .R then &var.mean(&var.) = 0;
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

					/* Defensive: check if _temp_totalcounts&b.&switch. contains variables beginning with n_covar for the drop condition below */
					%let num_n_covar_vars=0;

					proc contents data=_temp_totalcounts&b.&switch. out=_temp_content noprint;
					quit;
					
					proc sql noprint;
					select count(*) into :num_n_covar_vars 
					from _temp_content
					where substr(upcase(name),1,7)="N_COVAR";
					quit;

                    data _temp_table1_reformat&b.&switch.;
                        merge _temp_formatted_&b.&switch.
                              _temp_totalcounts&b.&switch.;
                        by order;
                        format group2 $40. table weight $30.;

                        /*For ReportType = T1, T3, T2L1, T4L1, T5, set table = Unadjusted*/
                        /*For ReportType = T6 set table = Switchstep_0, Switchstep_1 or Switchstep_2*/
                        /*weight = 'Unweighted for all ReportType*/
                        weight = 'Unweighted';
						%if %str("&reporttype") = %str("T6") %then %do; 
                          table = "Switchstep_&switch.";
						%end;
						%else %do;
                          table = 'Unadjusted';
                        %end;

                        %if &createcompcolumns = Y %then %do;
                            %if "&includenonpregnant" = "Y" %then %do;
                                group1 = "preg";
                                group2 = "nopreg";
                            %end;                            
                            %else %if %length(&baselinegroupnum.) >0 %then %do;
                                group1 = "&analysisgrp";
                                group2 = "&analysisgrp2";
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

                        drop n_episodes: n_patients: %if &totallabcovar > 0 and %length(&checklabvars) > 0 and &num_n_covar_vars. > 0 %then %do; n_covar: %end;;
                    run;

                    /*use set to avoid missing var warnings*/
                    %if %eval(&b.=1) %then %do;
                        data alldptable1_&periodid.&switch.;
                            set _temp_table1_reformat&b.&switch.;
                        run;
                    %end;
                    %else %do;
                        data alldptable1_&periodid.&switch.;
                            set alldptable1_&periodid.&switch.
                                _temp_table1_reformat&b.&switch.;
                        run;
                    %end;
                %end;

            %mend reformatL1baseline;

            /*For ReportType = T1, T3, T2L1, T4L1, and T5, call %reformatL1baseline one time*/
            /*For ReportType = T6, call %reformatL1baseline once for each switch and stack datasets*/
            %if %str("&reporttype") = %str("T6") %then %do; 
                %do switch_count = 0 %to &switch_counter;
		          %reformatL1baseline(switch = &switch_count);
		        %end;

                /*Stack all tables together*/
                data alldptable1_&periodid.;
		          set alldptable1_&periodid.:;
                run;
            %end; 
		    %else %do;
		      %reformatL1baseline();
            %end;

        %end; /*reformat table*/

        ***********************************************************************************************;
        * Determine if DP returns race and hispanic information                       
        ***********************************************************************************************;

        /*total sum of race/hispanic categories across DPs and if stratifybyDP = Y, within DP*/
        %do r = 1 %to &num_dp.;
            %let returnrace&r. = N;
        %end;

        %let compvars = N;

        data _temp_racehispanic;
            set alldptable1_&periodid.(where=(substr(upcase(metvar),1,4)='RACE' | substr(upcase(metvar),1,8)='HISPANIC'));
            if _n_ = 1 then do;
            dsid = open("alldptable1_&periodid.");
                if varnum(dsid,"comp_mean1") ne 0 then call symputx('compvars', 'Y');
            rc= close(dsid);
            end;
            drop rc dsid;
        run;

        %isdata(dataset=_temp_racehispanic);
        %if %eval(&nobs.>0) %then %do;
            data _null_;
                set _temp_racehispanic(keep=metvar exp_: %if "&compvars" = "Y" %then %do; comp_: %end;);
                %do r = 1 %to &num_dp.;
                    if upcase(metvar) not in ('RACE_0', 'HISPANIC_U') then do;
                        if exp_mean&r.>0 %if "&compvars" = "Y" %then %do; | comp_mean&r.>0 %end; then do;
                            call symputx("returnrace&r.", 'Y');
                        end;
                    end;
                %end;
            run;
        %end;

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
  
     ***********************************************************************************************;
    * Aggregate covariate profile tables across DPs                               
    ***********************************************************************************************;

    %if &numprofilecovarstoinclude > 0 %then %do;
        %baseline_profile_createdata;
    %end;

    proc datasets nowarn noprint lib=work;
        delete baselinefile_: _temp_: alldptable1_: _baseline_agg_:;
    quit;

    %end; /*baselinefile input file exists*/

    %put =====> END MACRO: baseline_driver ;

%mend baseline_driver;
