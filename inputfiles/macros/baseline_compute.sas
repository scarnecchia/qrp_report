****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_compute.sas  
* Created (mm/dd/yyyy): 12/11/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The computes aggregated baseline metrics and applies labels for each row of table
*
*  Program inputs:                                                                                   
*   - Aggregated baseline table with the following variables:
*       - group1, group2 (optional)
*       - order
*       - metvar
*       - vartype
*       - switchstep (if reporttype = T6)
*       - exp_mean1-exp_mean&num_dp
*       - exp_std1-exp_std&num_dp
*       - exp_s2_1-exp_s2_&num_dp
*       - exp_w1_1-exp_w1_&num_dp
*       - exp_w2_1-exp_w2_&num_dp
*       - comp_mean1-comp_mean&num_dp (if group2 populated)
*       - comp_std1-comp_std&num_dp (if group2 populated)
*       - comp_s2_1-comp_s2_&num_dp (if group2 populated)
*       - comp_w1_1-comp_w1_&num_dp (if group2 populated)
*       - comp_w2_1-comp_w2_&num_dp (if group2 populated)
*       - ad1-ad_&num_dp and sd1-sd_&num_dp (if group 2 populated and covar balance computed)
*       - weight, table, subgroup, subgroupcat (if reporttype = T2L2 or T4L2)
*
*  Program outputs:                                                                                                                                       
*  	- Dataset with additional aggregated columns
* 
*  PARAMETERS:    
*   - datain: input dataset name
*   - dataout: output dataset name
*   - reporttype: Report type (type + level)
*   - numbaselinetablegrp: number of baseline table groups
*   - num_dp: number of data partners
*   - stratifybydp: Y/N to format DP specific metrics
*   - periodid: monitoring period #
*
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

%macro baseline_compute(datain=, dataout=, reporttype=, numbaselinetablegrp=, num_dp=, stratifybydp=, periodid=);

	%put =====> MACRO CALLED: baseline_compute;

    /* Create a labels dataset for subgroup header creation */
    data init_labels;
        length label $&baselinelabellength sortorder1 sortorder2 3 sortorder3 sortorder4 8;
        grouper='Demographic Characteristics';
        sortorder1=3;
        sortorder2=0;
        sortorder3=0;
        sortorder4=0;
        label='Age';
        output;
        sortorder1=4;
        label='Sex';
        output;
        sortorder1=5;
        label='Race';
        output;
        sortorder1=6;
        label='Hispanic origin';
        output;
        sortorder1=8;
        label='Year';
        output;
    run;

    ***********************************************************************************************;
    * Loop through each requested baseline table in BASELINEFILE                            
    ***********************************************************************************************;
    %do b = 1 %to %eval(&numbaselinetablegrp.);
	   
        data _null_;
            set baselinefile(where=(order=&b.));
            if _n_ = 1 then do;
                call symputx('analysisgrp', analysisgrp);
                call symputx('runid', runid);
                if upcase(covarsort) not in ('A','O','C') then covarsort = 'C'; /*set C as default*/
                call symputx('covarsort', upcase(covarsort));
                call symputx('cohort', cohort);
				call symputx('unique_psestimate',unique_psestimate);
                /*computebalance defaults to Y for L2 tables*/
                %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
                call symputx('computebalance', 'Y');
                %end;
                %else %do;
                call symputx('computebalance', upcase(computebalance));
                %end;

                /*initialize to dummy value if missing*/
                if missing(healthchar) then call symputx('healthchar', 'missing');
                else call symputx('healthchar', upcase(healthchar));
                if missing(medproduse) then call symputx('medproduse', 'missing');
                else call symputx('medproduse', upcase(medproduse));
                if missing(UtilizationIntensity) then call symputx('UtilizationIntensity', 'missing');
                else call symputx('UtilizationIntensity', upcase(UtilizationIntensity));
                if missing(labcharacteristics) then call symputx('labcharacteristics','missing');
                else call symputx('labcharacteristics',upcase(labcharacteristics));				

                /*type 4 pregnancy specific parameters*/
                %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2")  %then %do;
                call symputx('pregnancychar', upcase(pregnancychar));
                call symputx('outputinfantchar', strip(upcase(outputinfantchar)));
                call symputx('exposurechar', upcase(exposurechar));
                call symputx('includenonpregnant', strip(upcase(includenonpregnant)));
                %end;
                %else %do;
                call symputx('outputinfantchar', 'N');
                call symputx('includenonpregnant', 'N');
                %end;

                /*initialize switch_count (used for type 6)*/
                call symputx('switch_count',0);
                /* initialize switch_counter(# of switches) */
                call symputx('switch_counter',0);

                /*if reporttype = T2L2, T4L2, or cohort = mi or includenonpreggroup = Y,
                  or BASELINEGROUPNUM is specified then include COMP columns*/
                if "&reporttype."="T2L2" | "&reporttype."="T4L2" | upcase(computebalance)= 'Y' |
                   upcase(includenonpregnant) = 'Y' | cohort = "mi" | missing(baselinegroupnum)=0 then do;
                   call symputx('includecomp', 'Y');
                end;
                else do;
                   call symputx('includecomp', 'N');
                end;
            end;
			if _n_ = 2 then do;
              if missing(baselinegroupnum)=0 then do;
                call symputx('analysisgrp2',analysisgrp);
              end;
            end;
        run;
        %put creating baseline table for &analysisgrp;

        /*for L2 tables - need to reference PS/CS specific files to pull additional parameters*/
        %let ratio = F;
        %let psfile = ;
        %let weightscheme = ;
        %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
            data _null_;
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp." and missing(subgroup)));
                call symputx('psfile', strip(file));
                call symputx('psestimategrp', psestimategrp);
                %if %str("&reporttype") = %str("T2L2") %then %do;
                call symputx('eoi', strip(eoi));	
                %end;
                %if %str("&reporttype") = %str("T4L2") %then %do;
                call symputx('eoi', strip(groupname));	
                %end;
 
                if file = 'psmatchfile' then call symputx('ratio',upcase(ratio));
                if file = 'stratificationfile' then call symputx("weightscheme",strip(upcase(strataweight)));
            run;
		%end;

        ***********************************************************************************************;
        * Execute %baseline_expand_parameters()              
        ***********************************************************************************************;
        %baseline_expand_parameters(var =medproduse);
        %baseline_expand_parameters(var =healthchar);
        %baseline_expand_parameters(var =UtilizationIntensity);
        %baseline_expand_parameters(var =labcharacteristics);
        %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2") %then %do;
        %baseline_expand_parameters(var =pregnancychar);
        %baseline_expand_parameters(var =exposurechar);
        %end;

        %let covarlistlength = %length(&healthchar.,&medproduse., &labcharacteristics., &UtilizationIntensity);

        *************************************************************
        * Processing - need to:
            - determine cohortgrp associated with EOI cohort
            - extract cohort specific demographic values
            - extract cohortdef
        ************************************************************;

        %let cohortgrp = ;
        /*L1*/
        %if %sysfunc(prxmatch(m/T1|T5/i,&reporttype.)) > 0 %then %do;
            %let cohortgrp = &analysisgrp.;
        %end;
        %else %if %sysfunc(prxmatch(m/T2L1/i,&reporttype.)) > 0 %then %do;
            %if %str("&cohort") = %str("") %then %do;
                %let cohortgrp = &analysisgrp;
            %end;
            %if %str("&cohort") = %str("multevent") %then %do;
                data _null_;
                    set infolder.&&&runid._multeventfile(where=(analysisgrp in ("&analysisgrp" %if &includecomp. = Y %then %do; "&analysisgrp2" %end;)));
                    if analysisgrp = "&analysisgrp" then call symputx('cohortgrp', strip(primary));
					%if &includecomp. = Y %then %do; 
					else if analysisgrp = "&analysisgrp2" then call symputx('cohortgrp2', strip(primary));
					%end;
                run;
            %end;
            %if %str("&cohort") = %str("overlap") %then %do;
                data _null_;
                    set infolder.&&&runid._overlapfile(where=(analysisgrp in ("&analysisgrp" %if &includecomp. = Y %then %do; "&analysisgrp2" %end;)));
                    if analysisgrp = "&analysisgrp" then call symputx('cohortgrp', strip(primary));
					%if &includecomp. = Y %then %do; 
					else if analysisgrp = "&analysisgrp2" then call symputx('cohortgrp2', strip(primary));
					%end;
                run;
            %end;
            %if %str("&cohort") = %str("concomitance") %then %do;
                data _null_;
                    set infolder.&&&runid._concfile(where=(analysisgrp in ("&analysisgrp" %if &includecomp. = Y %then %do; "&analysisgrp2" %end;)));
                    if analysisgrp = "&analysisgrp" then call symputx('cohortgrp', strip(primary));
					%if &includecomp. = Y %then %do;
					else if analysisgrp = "&analysisgrp2" then call symputx('cohortgrp2', strip(primary));
					%end;
                run;
            %end;
        %end;
        %else %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do; 
            %if %str("&cohort") = %str("preg") | %str("&cohort") = %str("nopreg") %then %do;
                %let cohortgrp = &analysisgrp;
            %end;
            %if %str("&cohort") = %str("mi") %then %do;
                data _null_;
                    set infolder.&&&runid._micohortfile(where=(milgrp="&analysisgrp"));
                    call symputx('cohortgrp', strip(groupname));
                run;            
            %end;
        %end;

        /*L2*/
        %else %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;          
            *T2: EOI group = cohortgrp - assigned to EOI above;
            *T4: EOI group = groupname - assigned to EOI above;
             %let cohortgrp = &eoi;
        %end;

        /*T6*/
		%else %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
            data _null_;
			    set infolder.&&&runid._treatmentpathways (where=((analysisgrp="&analysisgrp." and switchevalstep = 0)));
                call symputx('cohortgrp', strip(group));
            run;
        %end;

        /*Extract agegroup, sex, race, and hispanic requirements*/
        data _tempcohort;
            set master_cohortfile(where=(runid="&runid." and cohortgrp="&cohortgrp"));
            if missing(agestrat) then call symputx("agestrat", "00-01 02-04 05-09 10-14 15-18 19-21 22-44 45-64 65-74 75+");
            else call symputx("agestrat", upcase(agestrat));
            if missing(sex) then call symputx("sex", "'F', 'M', 'O'");
            else call symputx("sex", upcase(sex));
            if missing(race) then call symputx("race", "'0', '1', '2', '3', '4', '5'");
            else call symputx("race", upcase(race));
            if missing(hispanic) then call symputx("hispanic", "'Y', 'N', 'U'");
            else call symputx("hispanic", upcase(hispanic));
        run;
        %create_comma_charlist(inlist=&agestrat, outlist=agestrat1);

        /*Extract cohortdef - for L2 queries always 01, for T5 always 04*/
        %if %str("&reporttype") = %str("T1") %then %do;
		   proc sql noprint;
		     select distinct(t1cohortdef) 
		     into: cohortdef separated by ' '
		     from infolder.&&&runid._type1file(where=(group in ("&cohortgrp." %if &includecomp. = Y %then %do; "&analysisgrp2." %end;)));
		   quit;
        %end;
        %else %if %sysfunc(prxmatch(m/T2L1/i,&reporttype.)) > 0 %then %do;
			%if %str("&cohort") = %str("concomitance") %then %do;
				proc sql noprint;
				 select distinct(conccohortdef)
				 into: cohortdef separated by ' '
				 from infolder.&&&runid._concfile (where=(analysisgrp in ("&analysisgrp." %if &includecomp. = Y %then %do; "&analysisgrp2." %end;)));
				quit;
			%end;
			%else %do;
				proc sql noprint;
				 select distinct(t2cohortdef)
				 into: cohortdef separated by ' '
				 from infolder.&&&runid._type2file (where=(group in ("&cohortgrp." %if &includecomp. = Y %then %do; 
														             %if %str("&cohort") = %str("") %then %do; "&analysisgrp2." %end;
														             %else %do; "&cohortgrp2." %end;
												    %end;)));
				quit;
			%end;
        %end;
        %else %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do; 
            data _null_;
                set infolder.&&&runid._type4file(where=(group="&cohortgrp."));
				call symputx("cohortdef", strip(t4cohortdef));
            run;
        %end;
        %else %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            %let cohortdef = 01;
        %end;
        %else %if %str("&reporttype") = %str("T5") %then %do;
            %let cohortdef = 04;
        %end;
		%else %if %str("&reporttype") = %str("T6") %then %do;
		   data _null_;
              set infolder.&&&runid._treatmentpathways (where=(analysisgrp="&analysisgrp."));
              call symputx('cohortdef', strip(switchcohortdef));
            run;
        %end;
		
		/* Add cohortdef and comorbidscore to baselinefile */
		data baselinefile;
		  length comorbidscore gestationalage $1 cohortdef $5;
		  set baselinefile;
		  if order=&b. then do;
		    if index(upcase(healthchar),'COMORBIDSCORE') > 0 or index(upcase(medproduse),'COMORBIDSCORE') or index(upcase(utilizationintensity),'COMORBIDSCORE')
			  then comorbidscore = "Y";
		      else comorbidscore = "N";
			if index(upcase(pregnancychar),'GA_BIRTH') > 0 or index(upcase(exposurechar),'GA_FIRST') > 0 then gestationalage = "Y";
		      else gestationalage = "N";
		    cohortdef = "&cohortdef.";
		  end;
		run;

        ***********************************************************************************************
        * Put total number of patients and episodes in macro variables and compute overall totals
        **********************************************************************************************;
		* Initialize macro variables to make them available within the scope of this macro;
		%let total_unadjusted_exp_episodes=0;
		%let total_Switchstep_0_exp_episodes=0;
		%let total_unadjusted_comp_episodes=0;
		%let n_switchstep_0_episodes_exp=0;
		%let n_unadjusted_episodes_exp=0;
		%let total_unadjusted_exp_patients=0;
		%let total_unadjusted_comp_patients=0;
		%let total_unadjusted_exp_patients=0;
		%let total_unadjusted_comp_patients=0;
		%let total_adjusted_exp_episodes=0;
		%let total_adjusted_exp_patients=0;
		%let total_adjusted_comp_episodes=0;
		%let total_adjusted_comp_patients=0;
		%let total_Switchstep_0_exp_patients=0;

		%do a = 1 %to &num_dp.;
		      %let n_switchstep_0_episodes_exp&a=0;
		      %let n_unadjusted_episodes_exp&a=0;
		      %let n_unadjusted_episodes_comp&a=0;
		      %let n_unadjusted_patients_exp&a=0;
		      %let n_unadjusted_patients_comp&a=0;
		      %let n_adjusted_episodes_exp&a=0;
		      %let n_adjusted_episodes_comp&a=0;
		%end;

		%macro baselinecomputetotals(subgroup=, subgroupcat=);
	        data _null_; 
	            set &datain.(where=(metvar in ('PATIENT', 'N_EPISODES') and table ne 'Adjusted' and order=&b.
	                           %if %str("&reporttype") = %str("T6") %then %do; and switchstep = 0 %end;
							   %if %str("&reporttype") = %str("T2L2") or %str("&reporttype") = %str("T4L2") %then %do;
							    and subgroup="&subgroup." and subgroupcat="&subgroupcat."
							   %end;));
	        
	            total_exp_episodes = 0;
	            total_exp_patients = 0;
	            %if "&includecomp" = "Y" %then %do;
	            total_comp_episodes = 0;
	            total_comp_patients = 0;
	            %end;

	            /*Number of Episodes*/
	            if metvar = 'N_EPISODES' then do;
	                total_exp_episodes = sum(of exp_mean1-exp_mean&num_dp.);
	                call symputx("total_unadjusted_exp_episodes", total_exp_episodes);
				    %if %str("&reporttype") = %str("T6") %then %do;
			        call symputx("total_Switchstep_0_exp_episodes", total_exp_episodes);
	                %end;

	                %if "&includecomp" = "Y" %then %do;
	                total_comp_episodes = sum(of comp_mean1-comp_mean&num_dp.);
	                call symputx("total_unadjusted_comp_episodes", total_comp_episodes); 
	                %end;

	                %do a = 1 %to &num_dp.;
	    			    %if %str("&reporttype") = %str("T6") %then %do;
	                      call symputx("n_switchstep_0_episodes_exp&a", exp_mean&a);
	                    %end;
	                    %else %do;
	                      call symputx("n_unadjusted_episodes_exp&a", exp_mean&a); 
	                    %end; 
	                    %if "&includecomp" = "Y" %then %do;
	                      call symputx("n_unadjusted_episodes_comp&a", comp_mean&a); 
	                    %end;
	                %end;
	            end;

	            /*Number of Patients*/
	            else if metvar = 'PATIENT' then do;
	                total_exp_patients = sum(of exp_mean1-exp_mean&num_dp.);
	                call symputx("total_unadjusted_exp_patients", total_exp_patients); 
				    %if %str("&reporttype") = %str("T6") %then %do;
				    call symputx("total_Switchstep_0_exp_patients", total_exp_patients);
	                %end;

	                %if "&includecomp" = "Y" %then %do;
	                  total_comp_patients = sum(of comp_mean1-comp_mean&num_dp.);
	                  call symputx("total_unadjusted_comp_patients", total_comp_patients);
	                %end;

	                %do a = 1 %to &num_dp.;
	                  call symputx("n_unadjusted_patients_exp&a", exp_mean&a); 
	                  %if "&includecomp" = "Y" %then %do;
	                    call symputx("n_unadjusted_patients_comp&a", comp_mean&a);
	                  %end;
	                %end;
	            end;

	            /*For L2 queries = number of patients is not computed since cohortdef = 01 (equal to number of episodes)*/
	            if "&reporttype."="T2L2" | "&reporttype."="T4L2" then call symputx("total_unadjusted_exp_patients", total_exp_episodes);
	            %if "&includecomp" = "Y" %then %do;
	            if "&reporttype."="T2L2" | "&reporttype."="T4L2" then call symputx("total_unadjusted_comp_patients", total_comp_episodes);
	            %end;
	        run;

	        %put total number of unadjusted group1 episodes for order=&b.:  &total_unadjusted_exp_episodes.;
	        %put total number of unadjusted group1 patients for order=&b.:  &total_unadjusted_exp_patients.;
	        %if "&includecomp" = "Y" %then %do;
	            %put total number of unadjusted group2 episodes for order=&b.:  &total_unadjusted_comp_episodes.;
	            %put total number of unadjusted group2 patients for order=&b.:  &total_unadjusted_comp_patients.;
	        %end;
		%mend baselinecomputetotals;
		%baselinecomputetotals();

	    ***********************************************************************************************;
        * Macro computes pooled metrics                         
        ***********************************************************************************************;
        %macro baselinecomputemetrics(table=, weight=, dataout=, labelout=, suffix=);  
         
			* Recompute totals for subgroup. Overall already computed above;
			%if (%str("&reporttype") = %str("T2L2") or %str("&reporttype") = %str("T4L2")) and %str("&subgroup") ne %str("") %then %do;
				%baselinecomputetotals(subgroup=%str(&subgroup.), subgroupcat=%str(&subgroupcat.));
			%end;

            /*Put total number of episodes into a macro variable for Adjusted tables - note: L2 only*/
            %if "&table." = "Adjusted" %then %do;

                data _null_; 
                    set &datain.(where=(upcase(metvar)= %if &weight. = Unweighted %then %do; 'N_EPISODES' %end; %else %do; 'TOTAL_WEIGHTED' %end; and table = "&table." and weight = "&weight" and order=&b.
								 %if %str("&reporttype") = %str("T2L2") or %str("&reporttype") = %str("T4L2") %then %do;
							    	and subgroup="&subgroup." and subgroupcat="&subgroupcat."
							   	 %end;));
                    %do a = 1 %to &num_dp.;
                        call symputx("n_adjusted_episodes_exp&a", exp_mean&a); 
                        call symputx("n_adjusted_episodes_comp&a", comp_mean&a); 
                    %end;

                    /*recompute total episodes for loop*/
                    total_exp_episodes = sum(of exp_mean1-exp_mean&num_dp.);
                    call symputx("total_adjusted_exp_episodes", total_exp_episodes); 
                    call symputx("total_adjusted_exp_patients", total_exp_episodes); /*Defensive for sex/race/hispanic computation*/
                    total_comp_episodes = sum(of comp_mean1-comp_mean&num_dp.);
                    call symputx("total_adjusted_comp_episodes", total_comp_episodes); 
                    call symputx("total_adjusted_comp_patients", total_comp_episodes); /*Defensive for sex/race/hispanic computation*/
                run;

                %put total number of adjusted group1 episodes for order=&b.:  &total_adjusted_exp_episodes.;
                %put total number of adjusted group1 patients for order=&b.:  &total_adjusted_exp_patients.;
                %put total number of adjusted group2 episodes for order=&b.:  &total_adjusted_comp_episodes.;
                %put total number of adjusted group2 patients for order=&b.:  &total_adjusted_comp_patients.;

            %end;

            /*For T6 tables, put total number of episodes and patients in macro variable for current switch step
              and total number of episodes for prior switch*/
			%if %str("&reporttype") = %str("T6") and &switch_count > 0 %then %do;
                data _null_; 
                    set &datain.(where=(upcase(metvar) in ('PATIENT', 'N_EPISODES') and order=&b. and switchstep = &switch_count));
                    
					/*Number of Episodes*/
                    if metvar = 'N_EPISODES' then do;
                      %do a = 1 %to &num_dp.;
                        call symputx("n_&table._episodes_exp&a", exp_mean&a); 
                      %end;
					  /*recompute total episodes for loop*/
                      total_exp_episodes = sum(of exp_mean1-exp_mean&num_dp.);
                      call symputx("total_&table._exp_episodes", total_exp_episodes); 
                    end;

					/*Number of Patients*/
                    else if metvar = 'PATIENT' then do;
					  %do a = 1 %to &num_dp.;
                        call symputx("n_&table._patients_exp&a", exp_mean&a); 
                      %end;
					  /*recompute total patients for loop*/
                      total_exp_patients = sum(of exp_mean1-exp_mean&num_dp.);
                      call symputx("total_&table._exp_patients", total_exp_patients); 
                    end;
                run;
				
				data _null_; 
                    set &datain.(where=(upcase(metvar)='N_EPISODES' and order=&b. and switchstep = %eval(&switch_count-1)));
                    %do a = 1 %to &num_dp.;
					    %let s_b = %eval(&switch_count-1);
                        call symputx("n_Switchstep_&s_b._episodes_exp&a", exp_mean&a); 
                    %end;
					/*recompute total episodes for loop*/
                    total_exp_episodes = sum(of exp_mean1-exp_mean&num_dp.);
                    call symputx("total_Switchstep_&s_b._exp_episodes", total_exp_episodes); 
                    call symputx("total_Switchstep_&s_b._exp_patients", total_exp_episodes); /*Defensive for sex/race/hispanic computation*/
                run;
                
				%put total number of switch &switch_count. episodes for order=&b.: &&total_switchstep_&switch_count._exp_episodes.;
                %put total number of switch &switch_count. patients for order=&b.: &&total_switchstep_&switch_count._exp_patients.;
            %end;

            /*if requested, collapse race categories when stratifybydp = N*/
            %if "&stratifybydp." = "N" and "&collapse_vars." = "race" %then %do;
                data race_data;
                    set &datain.(keep=table weight order metvar exp_mean: %if "&includecomp" = "Y" %then %do; comp_mean: %end;
                        where=(table="&table" and weight = "&weight" and order=&b. and metvar in ('RACE_1', 'RACE_2', 'RACE_3', 'RACE_4', 'RACE_5')
						%if %str("&reporttype") = %str("T2L2") or %str("&reporttype") = %str("T4L2") %then %do;
					    	and subgroup="&subgroup." and subgroupcat="&subgroupcat."
					    %end;));
                    /*compute aggregate sum*/
                    exp_mean0=max(0,sum(of exp_mean1-exp_mean&num_dp.));
    				%if "&includecomp" = "Y" %then %do; 
                    comp_mean0=max(0,sum(of comp_mean1-comp_mean&num_dp.));
                    %end;
                run;

                /*Assign macro variable that will hold the count to add to and subtract from totals*/
                %do c_r = 1 %to 5;
                    %let race&c_r._exp = 0;
                    %let race&c_r._comp = 0;
                %end;

                data _null_;
                    set race_data(keep=metvar exp_mean0 %if "&includecomp" = "Y" %then %do; comp_mean0 %end;);
                    %do c_r = 1 %to 5;
                        if metvar = "RACE_&c_r." then do;
                            if 1 <= exp_mean0 <= 10 %if "&includecomp" = "Y" %then %do; | 1 <= comp_mean0 <= 10 %end;
                                /*collapse if other anchor date is collapsed*/
                                %if &reporttype.=T6 %then %do;
                                    | "&&t6base_collapse&c_r." ="Y"
                                %end;
                            then do;
                                call symputx("race&c_r._exp", exp_mean0);
        				        %if "&includecomp" = "Y" %then %do; 
                                call symputx("race&c_r._comp", comp_mean0);
                                %end;
                                %if &reporttype.=T6 %then %do;
                                call symputx("t6base_collapse&c_r.", "Y");
                                %end;
                            end;
                        end;
                    %end;
                run;

                proc datasets nowarn noprint lib=work;
                    delete race_data;
                quit;
    	    %end; /*collapse_vars = race and stratifybydp = N*/

            data &dataout.&suffix.; 
			    missing R;
                length metvar $32;
                set &datain.(where=(table="&table" and weight = "&weight" and order=&b.
							 %if %str("&reporttype") = %str("T2L2") or %str("&reporttype") = %str("T4L2") %then %do;
							    and subgroup="&subgroup." and subgroupcat="&subgroupcat."
							 %end;));

				%if %str("&reporttype") = %str("T2L2") or %str("&reporttype") = %str("T4L2") %then %do;
					format subgroup subgroupcat $11.;
					subgroup="&subgroup.";
					subgroupcat="&subgroupcat.";
				%end;

                /*set up total count variables and arrays*/
                total_exp_episodes = &&total_&table._exp_episodes.; /*Sum of episodes in group1*/ 
                total_exp_patients = &&total_&table._exp_patients.; /*Sum of patients in group1*/ 
                agg_exp_w = 0; /*Sum of weights*/
                agg_exp_w2 = 0;
                array num_exp(&num_dp.) exp_mean1-exp_mean&num_dp.;
                array std_exp(&num_dp.) exp_std1-exp_std&num_dp.;
                array exp_s2(&num_dp.) exp_s2_1-exp_s2_&num_dp.;
                array exp_w(&num_dp.) exp_w1_1-exp_w1_&num_dp.;
                array exp_w2(&num_dp.) exp_w2_1-exp_w2_&num_dp.;

                %if "&includecomp" = "Y" %then %do;
                total_comp_episodes = &&total_&table._comp_episodes.; /*Sum of episodes in group2*/ 
                total_comp_patients = &&total_&table._comp_patients.; /*Sum of patients in group2*/
                agg_comp_w = 0;
                agg_comp_w2 = 0; 
                array num_comp(&num_dp.) comp_mean1-comp_mean&num_dp.;
                array std_comp(&num_dp.) comp_std1-comp_std&num_dp.; 
                array comp_s2(&num_dp.) comp_s2_1-comp_s2_&num_dp.;
                array comp_w(&num_dp.) comp_w1_1-comp_w1_&num_dp.;
                array comp_w2(&num_dp.) comp_w2_1-comp_w2_&num_dp.;
                %end;

                %if "&weight" = "Weighted" %then %do;
                    agg_v_exp = 0; /*Needed to compute SD for variable adjusted analysis*/
                    agg_v_comp = 0;
                    agg_sw_exp = 0; /*Needed to compute SD for variable adjusted analysis*/
                    agg_sw_comp = 0;

                    array vk_exp(&num_dp.) vk_exp_1-vk_exp_&num_dp.;
                    array vk_comp(&num_dp.) vk_comp_1-vk_comp_&num_dp.;
                %end;

               /*Aggregate weights*/
                agg_exp_w = sum(of exp_w1_1-exp_w1_&num_dp.); /*Sum of weights - exposed group*/
                agg_exp_w2 = sum(of exp_w2_1-exp_w2_&num_dp.); /*Sum of squared weights - exposed group*/

                %if "&includecomp" = "Y" %then %do;
                agg_comp_w = sum(of comp_w1_1-comp_w1_&num_dp.); /*Sum of weights - comparison group*/
                agg_comp_w2 = sum(of comp_w2_1-comp_w2_&num_dp.); /*Sum of squared weights - comparison group*/
                %end;

                /*Computations for weighted SD*/
                %if "&weight" = "Weighted" %then %do;
                    do i = 1 to &num_dp.;
                        if (exp_w(i)) > 0 then vk_exp(i) =  ( (exp_w(i)**2) - exp_w2(i)) / exp_w(i);
                        if (comp_w(i)) > 0 then vk_comp(i) =  ( (comp_w(i)**2) - comp_w2(i)) / comp_w(i);
                        if vk_exp(i)>0 then agg_v_exp  = agg_v_exp +  vk_exp(i); /*denominator of Sw2 for SD calculation*/
                        if vk_comp(i)>0 then agg_v_comp  = agg_v_comp +  vk_comp(i); /*denominator of Sw2 for SD calculation*/
                    end;
                %end;

                /* Character variables - format exposed and comparison groups when DP stratification is requested */
                %if "&stratifybydp" = "Y" %then %do;
                %do i = 1 %to &num_dp;
                if lowcase(vartype) = 'dichotomous' then do;

                    /*if 0 patients in a category, set to 0*/
                    if exp_mean&i. = . and exp_mean&i. ne .R then exp_mean&i. = 0;
                    if exp_std&i. = . then exp_std&i. = 0;

                    /*format as character*/
                    exp_mean&i._char = compress(put(exp_mean&i,comma12.));
                    exp_std&i._char = compress(put(exp_std&i,percent10.1));
                    if metvar = 'PATIENT' then do;
                        /*patient row always N/A for L1 queries, for L2, % is computed except if 0 patients*/
                        %if %sysfunc(prxmatch(m/T1|T2L1|T4L1|T5|T6/i,&reporttype.)) %then %do;
                        exp_std&i._char = 'N/A';
                        %end;
                        if exp_mean&i = 0 then exp_std&i._char = 'N/A';
                    end;
                    else if metvar = 'N_EPISODES' then do;
                        if exp_mean&i = 0 then do;
                            %if %index(&reporttype,T6) and "&table" ^= "Switchstep_0" %then %do;
                            exp_std&i._char = '0.0%';
                            %end;
                            %else %do;
                            exp_std&i._char = 'NaN';
                            %end;
                        end;
                    end;
                    else do;
                        /* For lab categories, set to N/A when one category does not exist across DPs */
                        /* Controls lab specific formatting for dichotomous rows - will need changing in future */
                        if prxmatch("/(LBUNIT|LBRES)/",metvar) then do; 
                            if &&&n_&table._episodes_exp&i > 0 and exp_mean&i = 0 then do;
                                exp_mean&i._char = 'NaN';                        
                                exp_std&i._char = 'NaN';    
                            end;                    
                        end;
                        /*set to . if no patients in cohort*/
                        if exp_mean&i = 0 and &&&n_&table._episodes_exp&i = 0 then do;
                            exp_mean&i._char = '.';
                            exp_std&i._char = '.';
                        end;
                    end;

                    %if "&includecomp" = "Y" %then %do;
                    /*if 0 patients in a category, set to 0*/
                    if comp_mean&i. = . and comp_mean&i. ne .R then comp_mean&i. = 0;
                    if comp_std&i. = . then comp_std&i. = 0;

                    comp_mean&i._char = compress(put(comp_mean&i,comma12.));
                    comp_std&i._char = compress(put(comp_std&i,percent10.1));
                    if metvar = 'PATIENT' then do;
                        %if %sysfunc(prxmatch(m/T1|T2L1|T4L1|T5|T6/i,&reporttype.)) %then %do;
                        comp_std&i._char = 'N/A';
                        %end;
                        if comp_mean&i = 0 then comp_std&i._char = 'N/A';
                    end;
                    else if metvar = 'N_EPISODES' then do;
                        if comp_mean&i = 0 then do;
                        %if %index(&reporttype,T6) and "&table" ^= "Switchstep_0" %then %do;
                        comp_std&i._char = '0.0%';
                        %end;
                        %else %do;
                        comp_std&i._char = 'NaN';
                        %end;
                        end;
                    end;
                    else do;
                        /* For lab categories, set to N/A when one category does not exist across DPs */
                        /* Controls lab specific formatting for dichotomous rows - will need changing in future */
                        if prxmatch("/(LBUNIT|LBRES)/",metvar) then do; 
                            if &&&n_&table._episodes_comp&i > 0 and comp_mean&i = 0 then do;
                                comp_mean&i._char = 'NaN';                        
                                comp_std&i._char = 'NaN';     
                            end;                   
                        end;
                        /*set to . if no patients in cohort*/
                        if comp_mean&i = 0 and &&&n_&table._episodes_comp&i = 0 then do; 
                            comp_mean&i._char = '.';
                            comp_std&i._char = '.';
                        end;
                    end;
                    %end;
                end;
                else do;
                    /*continuous metrics*/
                    exp_mean&i._char = compress(put(exp_mean&i,comma12.1));
                    exp_std&i._char = compress(put(exp_std&i,comma12.1));
                    if exp_mean&i = 0 and exp_std&i = 0 and &&&n_&table._episodes_exp&i = 0 then do;
                        exp_mean&i._char = '.';
                        exp_std&i._char = '.';
                    end;

                    if exp_mean&i > 0 and exp_std&i = . then exp_std&i._char = 'NaN';
					
                    %if ^%sysfunc(prxmatch(m/T1|T2L1|T4L1|T5|T6/i,&reporttype.))  %then %do;
                    if exp_std&i = 0 and &&&n_&table._episodes_exp&i > 0 then exp_std&i._char = 'NaN';
                    %end;
                    %else %do;
                    if exp_mean&i = 0 and missing(exp_std&i) and prxmatch('/LBRES/', metvar) then exp_std&i._char='NaN';

                    if (exp_mean&i = 0 and exp_std&i = 0) or (missing(exp_mean&i) and missing(exp_std&i)) then do;
                        if &&&n_&table._episodes_exp&i > 0 and ^prxmatch('/LBRES/', metvar) then do;
                        exp_mean&i._char = '0.0';
                        exp_std&i._char = 'NaN';
                        end;
                        /* Controls lab specific formatting for lab specific rows - will need changing in future */
                        else if &&&n_&table._episodes_exp&i > 0 and prxmatch('/LBUNIT|LBRES/',metvar) then do;
                            if exp_w1_&i. <= 0 then do; 
                            exp_mean&i._char = 'NaN';
                            exp_std&i._char = 'NaN';
                            end;
                            else if exp_w1_&i > 0 and prxmatch('/LBRES/', metvar) then do;
                            exp_mean&i._char = '0.0';
                            exp_std&i._char = 'NaN';
                            end;
                        end;
                        else do;
                        exp_mean&i._char = '.';
                        exp_std&i._char = '.';
                        end;
                    end;
                    %end;
                    %if "&includecomp" = "Y" %then %do;
                    comp_mean&i._char = compress(put(comp_mean&i,comma12.1));
                    comp_std&i._char = compress(put(comp_std&i,comma12.1));

                    if comp_mean&i = 0 and comp_std&i = 0 and &&&n_&table._episodes_comp&i = 0 then do;
                        comp_mean&i._char = '.';
                        comp_std&i._char = '.';
                    end;

                    if comp_mean&i > 0 and comp_std&i = . then comp_std&i._char = 'NaN';
					
                    %if ^%sysfunc(prxmatch(m/T1|T2L1|T4L1|T5|T6/i,&reporttype.)) %then %do;
                    if comp_std&i = 0 and &&&n_&table._episodes_comp&i > 0 then comp_std&i._char = 'NaN';
                    %end;
                    %else %do;
                    if comp_mean&i = 0 and missing(comp_std&i) and prxmatch('/LBRES/', metvar) then comp_std&i._char='NaN';
                    if (comp_mean&i = 0 and comp_std&i = 0) or (missing(comp_mean&i) and missing(comp_std&i)) then do;
                        if &&&n_&table._episodes_comp&i > 0 then do;
                        comp_mean&i._char = '0.0';
                        comp_std&i._char = 'NaN';
                        end;
                        /* Controls lab specific formatting for continuous rows - will need changing in future */
                        else if &&&n_&table._episodes_comp&i > 0 and prxmatch('/LBUNIT|LBRES/',metvar) then do;
                            if comp_w1_&i. <= 0 then do; 
                            comp_mean&i._char = 'NaN';
                            comp_std&i._char = 'NaN';
                            end;
                            else if comp_w1_&i. > 0 and prxmatch('/LBRES/', metvar) then do; 
                            comp_mean&i._char = '0.0';
                            comp_std&i._char = 'NaN';
                            end;
                        end;
                        else do;
                        comp_mean&i._char = '.';
                        comp_std&i._char = '.';
                        end;
                    end;
                    %end;
                    %end;
                end;
                %end;
                %end;

                /*Aggregate dichotomous variables*/
                if lowcase(vartype) = 'dichotomous' then do;
                    exp_mean0=max(0,sum(of exp_mean1-exp_mean&num_dp.)); /*Aggregated numerator in the exposed group*/
                    %if "&includecomp" = "Y" %then %do;
                        comp_mean0=max(0,sum(of comp_mean1-comp_mean&num_dp.));/*Aggregated numerator in the comparison group*/ 
                    %end;

                    /*collapse race*/
                    %if &collapse_vars = race %then %do;
                        if metvar in ('RACE_0', 'RACE_1', 'RACE_2', 'RACE_3', 'RACE_4', 'RACE_5') then do;
                            %if &stratifybydp.=N %then %do;
                                %do c_r = 1 %to 5;
                                    %if %eval(&&race&c_r._exp >0) | %eval(&&race&c_r._comp >0) %then %do;
                                        if metvar = "RACE_&c_r." then do;
                                            exp_mean0 = .R;
                                            %if "&includecomp" = "Y" %then %do;
                                            comp_mean0 = .R;
                                            %end;
                                        end;
                                    %end;
                                %end;
                                if metvar = "RACE_0" then do;
                                    exp_mean0 = sum(exp_mean0 %do c_r = 1 %to 5; ,&&race&c_r._exp %end;);
                                    %if "&includecomp" = "Y" %then %do;
                                    comp_mean0 = sum(comp_mean0 %do c_r = 1 %to 5; ,&&race&c_r._comp %end;);
                                    %end;
                                end;
                            %end;

                            /*if every DP collapses a race category, mark in aggregate table*/
                            %else %if stratifybydp.=Y %then %do;
                                if %do r = 1 %to &num_dp.; exp_mean&r.= .R %if &r. ne &num_dp. %then %do; and %end; %end; then do;
                                    exp_mean0 = .R;
                                end;
                                %if "&includecomp" = "Y" %then %do;
                                if %do r = 1 %to &num_dp.; comp_mean&r.= .R %if &r. ne &num_dp. %then %do; and %end; %end; then do;
                                    comp_mean0 = .R;
                                end;
                               %end;
                            %end;
                        end;
                    %end;

                    exp_mean0_char=compress(put(exp_mean0,comma12.)); /* Character copy of exposed group */
                    %if "&includecomp" = "Y" %then %do;
                        comp_mean0_char=compress(put(comp_mean0,comma12.)); /* Character copy of reference group */
                    %end;

                    %if "&weight" = "Weighted" %then %do;
                    do i = 1 to &num_dp.;
                        if metvar not in ('N_EPISODES', 'PATIENT') then do;
                            if num_exp(i) > 0 then agg_sw_exp = agg_sw_exp + (exp_s2(i)*vk_exp(i)) ; /*Numerator of Sw2 for SD calculation*/
                            if num_comp(i) > 0 then agg_sw_comp = agg_sw_comp + (comp_s2(i)*vk_comp(i));
                        end;
                    end;
                    %end;

                    /*initialize to 0*/
                    exp_std0 = 0;
                    %if "&includecomp" = "Y" %then %do;
                    comp_std0 = 0;
                    %end;

                    ** Calculate aggregated percent: 
                       - Denominator for sex, race, and Hispanic is total number of patients
                       - Denominator for other metrics is total number of episodes 
                       - Total Episodes/Patients: for unadjusted tables:
                            - L1: do not fill in %, 
                            - L2: 100% for unadjusted, compute % out of unadjusted total for adjusted tables
					        - T6 switching: 100% for switch step 0, compute % of out prior switch total for switch step 1 and switch step 2;
                    if prxmatch('/RACE*|HISPANIC*|SEX*/',metvar) > 0 then do;
                        if ^missing(exp_mean0) and (total_exp_patients gt 0) then exp_std0 = divide(exp_mean0,total_exp_patients);
                        exp_std0_char=compress(put(exp_std0,percent10.1)); 
                        if exp_mean0 > 0 and total_exp_patients = 0 then exp_std0_char = 'NaN';
                        if missing(exp_mean0) or exp_mean0 = 0 then do;
                            if total_exp_patients <= 0 then do; 
                            exp_mean0_char = '.';
                            exp_std0_char = '.';
                            end;
                        end;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(comp_mean0) and (total_comp_patients gt 0) then comp_std0 = divide(comp_mean0,total_comp_patients);
                        comp_std0_char=compress(put(comp_std0,percent10.1)); 
                        if comp_mean0 > 0 and total_comp_patients = 0 then comp_std0_char = 'NaN';
                        if missing(comp_mean0) or comp_mean0 = 0 then do;
                            if total_comp_patients <= 0 then do;
                            comp_mean0_char = '.';
                            comp_std0_char = '.';
                            end;
                        end;
                        %end;
                    end;
                    else if metvar in ('N_EPISODES', 'PATIENT') then do;
                        exp_std0 = .;
                        comp_std0 = .;
                        %if ("&table" = "Unadjusted" & %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2")) 
                          | ("&table" ="Switchstep_0") %then %do;
                            exp_std0 = 1;
                            if metvar = 'PATIENT' then exp_std0_char = 'N/A';
                            if metvar = 'N_EPISODES' then do;
                                exp_std0_char=compress(put(exp_std0,percent10.1));
                                if exp_mean0 = 0 then exp_std0_char = 'NaN';
                            end;
                            %if "&includecomp" = "Y" %then %do;
                            comp_std0 = 1;
                            if metvar = 'PATIENT' then comp_std0_char = 'N/A';
                            if metvar = 'N_EPISODES' then do;
                                comp_std0_char=compress(put(comp_std0,percent10.1));
                                if comp_mean0 = 0 then comp_std0_char = 'NaN';
                            end;
                            %end;
                        %end;
						%else %if %str("&reporttype") = %str("T6") and &switch_count > 0  %then %do;
						  %let switch_b = %eval(&switch_count.-1);
                          if metvar = 'PATIENT' then exp_std0_char = 'N/A';
						  if metvar = 'N_EPISODES' then do;
                            if ^missing(exp_mean0) and (total_exp_episodes gt 0) then do;
                            exp_std0 = divide(exp_mean0,&&total_Switchstep_&switch_b._exp_episodes);
                            exp_std0_char = compress(put(exp_std0,percent10.1));
                            end;
                            if exp_mean0 > 0 and &&total_Switchstep_&switch_b._exp_episodes = 0 then exp_std0_char = 'NaN';
                            %if "&table" = "Switchstep_0" %then %do;
                            if &&total_Switchstep_&switch_b._exp_episodes = 0 then exp_std0_char = 'NaN';
                            %end;
                            %else %if "&table" = "Switchstep_1" %then %do;
                            if &&total_Switchstep_&switch_b._exp_episodes = 0 then exp_std0_char = 'NaN';
                            else if &&total_Switchstep_&switch_b._exp_episodes > 0 and exp_mean0 = 0 then exp_std0_char = '0.0%';
                            %end;
                            %else %if "&table" = "Switchstep_2" %then %do;
                            if &&total_Switchstep_&switch_b._exp_episodes = 0 then exp_std0_char = 'NaN';
                            else if &&total_Switchstep_&switch_b._exp_episodes > 0 and exp_mean0 = 0 then exp_std0_char = '0.0%';
                            %end;
						    %if "&stratifybydp" = "Y" %then %do;
						      %do nu_d = 1 %to &num_dp.;
							    if ^missing(exp_mean&nu_d.) and (total_exp_episodes gt 0) then do;
                                exp_std&nu_d. = divide(exp_mean&nu_d.,&&&n_Switchstep_&switch_b._episodes_exp&nu_d.);
                                exp_std&nu_d._char = compress(put(exp_std&nu_d.,percent10.1));
                                end;
                            %if "&table" = "Switchstep_0" %then %do;
                            if &&&n_Switchstep_&switch_b._episodes_exp&nu_d. = 0 then exp_std&nu_d._char = 'NaN';
                            %end;
                            %else %if "&table" = "Switchstep_1" %then %do;
                            if &&&n_Switchstep_&switch_b._episodes_exp&nu_d. = 0 then exp_std&nu_d._char = 'NaN';
                            else if &&&n_Switchstep_&switch_b._episodes_exp&nu_d. > 0 and exp_mean&nu_d = 0 then exp_std&nu_d._char = '0.0%';
                            %end;
                            %else %if "&table" = "Switchstep_2" %then %do;
                            if &&total_Switchstep_&switch_b._exp_episodes = 0 then exp_std&nu_d._char = 'NaN';
                            else if &&&n_Switchstep_&switch_b._episodes_exp&nu_d. > 0 and exp_mean&nu_d = 0 then exp_std&nu_d._char = '0.0%';
                            %end;
							  %end;
                            %end;
						  end;
						%end;
						%else %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
                          if ^missing(exp_mean0) and (total_exp_episodes gt 0) then do; 
                          exp_std0 = divide(exp_mean0,&total_unadjusted_exp_episodes.);
                          exp_std0_char = compress(put(exp_std0,percent10.1));
                          end;
                          if exp_mean0 > 0 and &total_unadjusted_exp_episodes. = 0 then exp_std0_char = 'NaN';
                          if missing(exp_mean0) or exp_mean0 = 0 then exp_std0_char = 'NaN';
                          if missing(exp_std0) or exp_mean0 = 0 then exp_std0_char = 'NaN';
                          %if "&includecomp" = "Y" %then %do;
                            if ^missing(comp_mean0) and (total_comp_episodes gt 0) then comp_std0 = divide(comp_mean0,&total_unadjusted_comp_episodes.);
                            comp_std0_char = compress(put(comp_std0,percent10.1));
                            if comp_mean0 > 0 and &total_unadjusted_comp_episodes. = 0 then comp_std0_char = 'NaN';
                            if missing(comp_mean0) or comp_mean0 = 0 then comp_std0_char = 'NaN';
                            if missing(comp_std0) or comp_std0 = 0 then comp_std0_char = 'NaN';
                          %end;
						%end;
                        %else %if %sysfunc(prxmatch(m/T1|T2L1|T4L1|T5/i,&reporttype.)) %then %do;
                        if ^missing(exp_mean0) and (total_exp_episodes >= 0) then do;
                        exp_std0 = divide(exp_mean0,&total_unadjusted_exp_episodes.);
                        if metvar = 'PATIENT' and total_exp_episodes >= 0 then exp_std0_char = 'N/A';
                        if metvar = 'N_EPISODES' then do;
                            exp_std0_char = compress(put(exp_std0,percent10.1));
                            if missing(exp_std0) then exp_std0_char = 'NaN';
                        end;
                        end;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(comp_mean0) and (total_comp_episodes >= 0) then do;
                        comp_std0 = divide(comp_mean0,&total_unadjusted_comp_episodes.);   
                        if metvar = 'PATIENT' and total_comp_episodes >= 0 then comp_std0_char = 'N/A';
                        if metvar = 'N_EPISODES' then do;
                            comp_std0_char = compress(put(comp_std0,percent10.1));
                            if missing(comp_std0) then comp_std0_char = 'NaN';
                        end;
                        end;
                        %end;
                        %end;
                    end;
                    /* Calculate lab covariate percentages */
                    else if prxmatch("/(LBUNIT|LBRES)/",metvar) then do; 
                        if ^missing(exp_mean0) and (total_exp_episodes gt 0) then exp_std0 = divide(exp_mean0,agg_exp_w);
                        if missing(exp_mean0) then exp_std0 = .;
                        exp_std0_char = compress(put(exp_std0,percent10.1));
                        if exp_mean0 > 0 and total_exp_episodes = 0 then exp_std0_char = 'NaN';
                        if exp_mean0 > 0 and exp_std0 = 0 then exp_std0_char='NaN';
                        if missing(exp_mean0) or exp_mean0=0 then do;
                            if agg_exp_w <= 0 then exp_std0_char = 'NaN';
                            if total_exp_patients <= 0 then do;
                                exp_mean0_char = '.'; 
                                exp_std0_char = '.';
                            end;
                        end;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(comp_mean0) and (total_comp_episodes gt 0) then comp_std0 = divide(comp_mean0,agg_comp_w);
                        if missing(comp_mean0) then comp_std0 = .;
                        comp_std0_char = compress(put(comp_std0,percent10.1));
                        if comp_mean0 > 0 and total_comp_episodes = 0 then comp_std0_char = 'NaN';
                        if comp_mean0 > 0 and comp_std0 = 0 then comp_std0_char = 'NaN';
                        if missing(comp_mean0) or comp_mean0=0 then do;
                            if agg_comp_w <= 0 then exp_std0_char = 'NaN';
                            if total_comp_patients <= 0 then do;
                                comp_mean0_char='.';
                                comp_std0_char = '.';
                            end;
                        end;
                        %end;
                    end;
                    else do;
                        if ^missing(exp_mean0) and (total_exp_episodes gt 0) then exp_std0 = divide(exp_mean0,agg_exp_w);
                        if missing(exp_mean0) then exp_std0 = .;
                        exp_std0_char = compress(put(exp_std0,percent10.1));
                        if exp_mean0 > 0 and total_exp_episodes = 0 then exp_std0_char = 'NaN';
                        if missing(exp_mean0) or exp_mean0=0 then do;
                            if total_exp_patients <= 0 then do;
                                exp_mean0_char = '.';
                                exp_std0_char = '.';
                            end;
                        end;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(comp_mean0) and (total_comp_episodes gt 0) then comp_std0 = divide(comp_mean0,agg_comp_w);
                        if missing(comp_mean0) then comp_std0 = .;
                        comp_std0_char = compress(put(comp_std0,percent10.1));
                        if comp_mean0 > 0 and total_comp_episodes = 0 then comp_std0_char = 'NaN';
                        if missing(comp_mean0) or comp_mean0=0 then do;
                            if total_comp_patients <= 0 then do;
                                comp_mean0_char='.';
                                comp_std0_char = '.';
                            end;
                        end;
                        %end;
                    end;

                    %if "&includecomp" = "Y" & "&computebalance." = "Y" %then %do;
                        if metvar not in ('N_EPISODES', 'PATIENT') then do; /*AD/SD not computed for total rows*/
                            ad0 = 100*divide(exp_mean0,agg_exp_w) - 100*divide(comp_mean0,agg_comp_w);
                            ad0_char=compress(put(ad0,8.3));

                            /*standardized difference*/
                            a = divide(exp_mean0,agg_exp_w);
                            b = divide(comp_mean0,agg_comp_w);
                            %if "&weight" = "Weighted" %then %do; /*Weighted Adjusted*/  
                                stw = divide(agg_sw_exp,agg_v_exp);
                                scw = divide(agg_sw_comp,agg_v_comp);
                                c = sqrt(divide(stw+scw, 2));
                            %end;
                            %else %do; /*Unweighted*/
                                c = sqrt(divide(a*(1-a) + b*(1-b), 2));
                            %end;
                            /*SD*/
                            if (total_exp_episodes > 0) AND (total_comp_episodes > 0) AND (c>0) then sd0 = divide((a-b),c);
                            else sd0 = .;
                            sd0_char=compress(put(sd0,8.3));
							if exp_mean0 = 0 or comp_mean0 = 0 or exp_mean0 = . or comp_mean0 = . then do;
                                ad0_char = 'NaN';
                                sd0_char = 'NaN';
							end;
							if total_exp_episodes > 0 and total_comp_episodes > 0 and missing(sd0) then sd0_char = 'NaN';
                            if total_exp_episodes = 0 and total_comp_episodes = 0 and (ad0 = 0 or missing(ad0)) then do;
                                sd0_char = '.';
                                ad0_char = '.';
                            end;
                        end;
                        else do;
                        ad0=.;
                        sd0=.;
                        ad0_char='N/A';
                        sd0_char='N/A';
                        end;
                        %if "&stratifybydp" = "Y" %then %do;
                            %do i =1 %to &num_dp.;
                            if missing(ad&i.)=0 then ad&i. = ad&i.*100;
                            %end;
                        %end;
                    %end;

                    /*round exp_mean0 and exp_std0 - will be a decimal for weighted tables*/
                    if exp_mean0 ne .R then exp_mean0 = round(exp_mean0, 1);
                    %if "&includecomp" = "Y" %then %do;
                    if comp_mean0 ne .R then comp_mean0 = round(comp_mean0, 1);
                    %end;
                    %if "&stratifybydp" = "Y" %then %do;
                        %do i =1 %to &num_dp.;
						    if exp_mean&i. ne .R then exp_mean&i. = round(exp_mean&i., 1);
                            if comp_mean&i. ne .R then comp_mean&i. = round(comp_mean&i., 1);
                        %end;
                    %end;
                end;

                /*Aggregate continuous variables*/
                if lowcase(vartype) = 'continuous' and metvar ne 'MAHALANOBIS' then do;
                    count = 0;
                    exp_mean_num = 0; 
                    exp_std_sum = 0; /*Weighted sum for std calculation in the exposed group*/
                    %if "&includecomp" = "Y" %then %do;
                    comp_mean_num = 0; 
                    comp_std_sum = 0;/*Weighted sum for std calculation in the comparison group*/
                    %end;

                    do i = 1 to &num_dp.;
                        if ^missing(num_exp(i)) and ^missing(exp_w(i)) then exp_mean_num = exp_mean_num + (num_exp(i)*exp_w(i));
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(num_comp(i)) and ^missing(comp_w(i)) then comp_mean_num = comp_mean_num + (num_comp(i)*comp_w(i));
                        %end;

                        %if "&weight" = "Weighted" %then %do;
                            if num_exp(i) and exp_s2(i)>= 0 then agg_sw_exp = agg_sw_exp + ( (exp_s2(i))*(vk_exp(i))); /*Numerator of Sw2 for SD calculation*/
                            if num_comp(i) and comp_s2(i)>= 0 then agg_sw_comp = agg_sw_comp + ( (comp_s2(i))*(vk_comp(i))); 
                        %end;
                        %else %do;
                            ** Get weighted Std Dev for pooled Standard Deviation calculation  ** ;
                            if ^missing(std_exp(i)) then exp_std_sum = exp_std_sum + (std_exp(i)**2)*(exp_w(i) - 1);
                            ** Count number of data partners with a value - for pooled std dev calculation  ** ;
                            if ^missing(std_exp(i)) then count = count + 1 ;
                            %if "&includecomp" = "Y" %then %do;
                            if ^missing(std_comp(i)) then comp_std_sum = comp_std_sum + (std_comp(i)**2)*(comp_w(i) - 1);
                            %end;
                        %end;
                    end;
                        
                    if ^missing(exp_mean_num) AND (agg_exp_w gt 0) then exp_mean0 = divide(exp_mean_num,agg_exp_w) ;
                    exp_mean0_char = compress(put(exp_mean0,comma12.1));
                    if exp_mean_num > 0 and agg_exp_w = 0 then exp_mean0_char = 'NaN';
                    if prxmatch('/LBRES/',metvar) and total_exp_episodes > 0 and missing(exp_mean0) and missing(agg_exp_w) then exp_mean0_char = 'NaN';
                    if missing(exp_mean_num) then exp_mean0_char = '.';
                    %if "&includecomp" = "Y" %then %do;
                    if ^missing(comp_mean_num) AND (agg_comp_w gt 0) then comp_mean0 = divide(comp_mean_num,agg_comp_w) ;
                    comp_mean0_char = compress(put(comp_mean0,comma12.1));
                    if comp_mean_num > 0 and agg_comp_w = 0 then comp_mean0_char = 'NaN';
                    if prxmatch('/LBRES/',metvar) and total_comp_episodes > 0 and missing(comp_mean0) and missing(agg_comp_w) then comp_mean0_char = 'NaN';
                    if missing(comp_mean_num) then comp_mean0_char = '.';
                    %end;            

                    %if "&weight" = "Weighted" %then %do;
                        if ^missing(agg_sw_exp) AND (agg_v_exp gt 0) then exp_std0 = sqrt(divide(agg_sw_exp,agg_v_exp)) ;
                        exp_std0_char = compress(put(exp_std0,comma12.1));
                        if exp_mean0 = 0 and exp_std0 = 0 then exp_std0_char = 'NaN'; 
                        if agg_sw_exp > 0 and agg_v_exp = 0 then exp_std0_char = 'NaN';
                        if missing(agg_sw_exp) then exp_std0_char = '.';
                        if ^missing(agg_sw_comp) AND (agg_v_comp gt 0) then comp_std0 = sqrt(divide(agg_sw_comp,agg_v_comp)) ;
                        comp_std0_char = compress(put(comp_std0,comma12.1));
                        if comp_mean0 = 0 and comp_std0 = 0 then comp_std0_char = 'NaN'; 
                        if agg_sw_comp > 0 and agg_v_comp = 0 then comp_std0_char = 'NaN';
                        if missing(agg_sw_comp) then comp_std0_char = '.';
                    %end;
                    %else %do;
                        if ^missing(exp_std_sum) AND (agg_exp_w gt 0) then exp_std0 = sqrt(divide(exp_std_sum,(agg_exp_w - count))) ;
                        exp_std0_char = compress(put(exp_std0,comma12.1));
                        if exp_mean0 = 0 and exp_std0 = 0 then exp_std0_char = 'NaN'; 
                        if exp_mean0 > 0 and exp_std0 = . then exp_std0_char = 'NaN'; 
                        if exp_std_sum > 0 and total_exp_episodes - count = 0 then exp_std0_char = 'NaN';
                        if missing(exp_std_sum) then exp_std0_char = '.';
                        if prxmatch('/LBRES/',metvar) and total_exp_episodes > 0 and missing(exp_std0) and missing(agg_exp_w) then exp_std0_char = 'NaN';
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(comp_std_sum) AND (agg_comp_w gt 0) then comp_std0 = sqrt(divide(comp_std_sum,(agg_comp_w - count)));
                        comp_std0_char = compress(put(comp_std0,comma12.1));
                        if comp_mean0 = 0 and comp_std0 = 0 then comp_std0_char = 'NaN'; 
                        if comp_mean0 > 0 and comp_std0 = . then comp_std0_char = 'NaN'; 
                        if comp_std_sum > 0 and total_comp_episodes - count = 0 then comp_std0_char = 'NaN';
                        if missing(comp_std_sum) then comp_std0_char = '.';
                        if prxmatch('/LBRES/',metvar) and total_comp_episodes > 0 and missing(comp_std0) and missing(agg_comp_w) then comp_std0_char = 'NaN';
                        %end;
                    %end;

                    %if "&includecomp" = "Y" & "&computebalance." = "Y" %then %do;
                        ad0 = exp_mean0 - comp_mean0;
                        ad0_char = compress(put(ad0,8.3));
                        %if "&weight" = "Weighted" %then %do; /*Weighted SD*/
                            /*standardized difference*/
                            a = exp_mean0 - comp_mean0;
                            stw = divide(agg_sw_exp,agg_v_exp);
                            scw = divide(agg_sw_comp,agg_v_comp);
                            c = sqrt(divide((stw + scw),2));
                            if (^missing(a)) AND (c>0) then sd0 = divide(a,c);
                            else sd0 = .;
                            sd0_char = compress(put(sd0,8.3));
							if total_exp_episodes > 0 and total_comp_episodes > 0 and missing(sd0) then sd0_char = 'NaN';
                            if total_exp_episodes = 0 and total_comp_episodes = 0 and (ad0 = 0 or missing(ad0)) then do;
                                sd0_char = '.';
                                ad0_char = '.';
                            end;
                        %end;
                        %else %do; /*unweighted SD*/
                            if (exp_std0 > 0) AND (comp_std0 > 0) then sd0 = divide((exp_mean0 - comp_mean0), (sqrt(divide((exp_std0*exp_std0 + comp_std0*comp_std0),2))));
                            else sd0 = .;
                            sd0_char=compress(put(sd0,8.3));
							if exp_mean0 = 0 or comp_mean0 = 0 or exp_mean0 = . or comp_mean0 = . then do;
                                ad0_char = 'NaN';
                                sd0_char = 'NaN';
							end;
							if total_exp_episodes > 0 and total_comp_episodes > 0 and missing(sd0) then sd0_char = 'NaN';
                            if total_exp_episodes = 0 and total_comp_episodes = 0 and (ad0 = 0 or missing(ad0)) then do;
                                sd0_char = '.';
                                ad0_char = '.';
                            end;
                        %end;
                    %end;
                    drop exp_mean_num exp_std_sum %if "&includecomp" = "Y" %then %do; comp_mean_num comp_std_sum %end; ;
                end;

                /*reformat DP specific vars*/
                %if "&stratifybydp" = "Y" & "&computebalance." = "Y" %then %do;
                    %do i = 1 %to &num_dp.;
                        ad&i._char = strip(compress(put(ad&i., 8.3)));
                        sd&i._char = strip(compress(put(sd&i., 8.3)));
                
                        if metvar ne 'MAHALANOBIS' then do;
                          if metvar in ('N_EPISODES', 'TOTAL_WEIGHTED', 'PATIENT') then do;
                                ad&i._char = 'N/A';
                                sd&i._char = 'N/A';
                                if metvar = 'TOTAL_WEIGHTED' then do;
                                    comp_std&i._char = 'N/A';
                                    exp_std&i._char = 'N/A';
                                end;
                          end;
                          else do;
						  if exp_mean&i. = 0 or comp_mean&i = 0 or exp_mean&i. = . or comp_mean&i = . then do;
                                ad&i._char = 'NaN';
                                sd&i._char = 'NaN';
						  end;
						  if exp_mean&i. > 0 and comp_mean&i > 0 and missing(sd&i.) then sd&i._char = 'NaN';
                          if &&&n_&table._episodes_exp&i = 0 and &&&n_&table._episodes_comp&i = 0 and ad&i = 0 then do;
                                ad&i._char = '.';
                                sd&i._char = '.';
                          end;
                          end;
                        end;
                    %end;
                %end;

                /*update race and hispanic rows*/
                /*set to '.' race/hispanic if information if not returned at a DP
                   - if at least 1 DP returns race or hispanic, no need to reassign to '.' */
                if prxmatch('/RACE*|HISPANIC*/',metvar) > 0 and metvar not in ('RACE_0', 'HISPANIC_U') then do;
                   if %do r = 1 %to &num_dp.; "&&returnrace&r." = "N" %if &r. ne &num_dp. %then %do; and %end; %end; then do;
                        exp_mean0_char = '.';
                        exp_std0_char = '.';
                        %if "&includecomp" = "Y" %then %do;
                        comp_mean0_char = '.';
                        comp_std0_char = '.';
                        %end;
                        %if "&computebalance." = "Y" %then %do;
                        ad0_char = '.';
                        sd0_char = '.';
                        %end;
                    end;
                    /*reassign for each DP*/
                    %if "&stratifybydp" = "Y" %then %do;
                    %do i =1 %to &num_dp.;
                        %if &&returnrace&i. = N %then %do;
                            exp_mean&i._char = '.';
                            exp_std&i._char = '.';
                            %if "&includecomp" = "Y" %then %do;
                            comp_mean&i._char = '.';
                            comp_std&i._char = '.';
                            %end;
                            %if "&computebalance." = "Y" %then %do;
                            ad&i._char = '.';
                            sd&i._char = '.';
                            %end;
                        %end;
                    %end;
                    %end;
                end;
               
                keep metvar %if %quote(&labcharacteristics) ^= %str("missing") %then %do;  _label_ %end; analysisgrp order vartype weight table exp_mean0 exp_std0 exp_mean0_char exp_std0_char
                    %if "&stratifybydp" = "Y" %then %do; exp_mean: exp_std: %end;
                    %if "&includecomp" = "Y" %then %do; comp_mean0 comp_std0 comp_mean0_char comp_std0_char
                      %if "&stratifybydp" = "Y" %then %do; comp_mean: comp_std:
                        %if "&computebalance." = "Y" %then %do; ad: sd: %end;
                      %end;   
                      %else %do;
                        %if "&computebalance." = "Y" %then %do; ad0: sd0: %end;
                      %end;
                    %end; 
                    %if &reporttype=T2L2 %then %do;
                    monitoringperiod
                    %end;
					%if &reporttype=T2L2 or &reporttype=T4L2 %then %do;
					subgroup subgroupcat
					%end;
                    ;

                /*Removing unweighted total row for IPTW and PS stratum weighted table 1. Will use TOTAL_WEIGHTED row*/
                %if (&psfile. = iptwfile | "&weightscheme." = "ATE" | "&weightscheme." = "ATT") and "&weight" = "Weighted" %then %do; 
                    if metvar = 'N_EPISODES' then delete;
                    if MetVar = 'TOTAL_WEIGHTED' then do;
                        exp_std0 = .;
                        comp_std0 = .;
                        comp_std0_char = 'N/A';
                        exp_std0_char = 'N/A';
                        ad0 = .;
                        sd0 = .;
                        if exp_mean0 > 0 or comp_mean0 > 0 then do;
                        ad0_char = 'N/A';
                        sd0_char = 'N/A';
                        end;
                        else do;
                        ad0_char = '.';
                        sd0_char = '.';
                        end;
                    end;
                %end;

                /* Remove TOTAL_WEIGHTED row for unweighted PS stratification */
                %if ((&psfile. = stratificationfile and "&weightscheme." = "") | (&psfile. = psmatchfile and "&ratio" = "V" )) %then %do;
                    if MetVar = 'TOTAL_WEIGHTED' then delete;
                %end;

				/*Removing FOLLOWUPTIME/EVENT rows*/
                if index(MetVar,'FOLLOWUP') > 0 or index(MetVar,'EVENT') > 0 then delete;
            run;

            data &labelout&suffix.;
                set init_labels %if %quote(&labcharacteristics) ^= %str("missing") %then %do; 
                                    covarname(in=b keep=cov_varname studyname where=(upcase(cov_varname) in (&labcharacteristics))) 
                                %end;;
                length analysisgrp $40 table weight $30;
				%if %str("&reporttype") = %str("T2L2") or %str("&reporttype") = %str("T4L2") %then %do;
					format subgroup subgroupcat $11.;
					subgroup="&subgroup.";
					subgroupcat="&subgroupcat.";
				%end;
                %if %quote(&labcharacteristics) ^= %str("missing") %then %do; 
                 if b then do;
                    grouper='Laboratory Characteristics';
                    sortorder1=14;
                    %if %str("&covarsort") = %str("C") %then %do;
                    sortorder2=input(compress(cov_varname,,'AF'),4.);
                    %end;
                    %else %if %str("&covarsort") = %str("O") %then %do;
                    length covarorderlist $&covarlistlength.;
                    covarorderlist = compress(tranwrd(resolve('&labcharacteristics.'), '"', ""));    
                    sortorder2 = findw(compress(covarorderlist), compress(upcase(cov_varname)), ',','e');
                    %end;                 
                    sortorder3=-1;
                    sortorder4=-1;
                    label=studyname;
                    drop studyname;
                end;
                %end;
                order=&b;
                analysisgrp="&analysisgrp.";
                table="&table";
                weight="&weight";
            run;

        %mend baselinecomputemetrics;

        ***********************************************************************************************;
        * Compute aggregated tables                     
        ***********************************************************************************************;

		* Process L2 subgroups;
		%let numsubgroups=0;
		%let subgroup=;
		%let subgroupcat=;
		%let suffix=;

		%if &reporttype. = T2L2 or &reporttype. = T4L2 %then %do;
			proc sort nodupkey data=Pscs_masterinputs(where=(analysisgrp="&analysisgrp." and runid="&runid." and not missing(subgroup))) 
							   out=_subgroups(keep=runid analysisgrp subgroup subgroupcat);
			by runid analysisgrp subgroup subgroupcat;
			run;

			data _subgroups;
			set _subgroups;
			by runid analysisgrp subgroup subgroupcat;
			if _N_=1 then subgroupnum=0;
			if first.subgroup then do;
				subgroupnum = subgroupnum + 1;
				subgroupcatnum = 0;
			end;			
			subgroupcatnum = subgroupcatnum + 1;
			retain subgroupnum subgroupcatnum;
			run;

			proc sql noprint;
			select count(*) into :numsubgroups from _subgroups;
			quit;
		%end;
		
		%do sub=0 %to &numsubgroups.;

			%if &sub. > 0 %then %do;
				data _null_;
				set _subgroups;
				if _N_=&sub.;
				call symputx("SubGroup",lowcase(strip(subgroup)));
	            call symputx("SubgroupCat",upcase(strip(subgroupcat)));
				call symputx("suffix", "_" || strip(put(subgroupnum,best.)) || "_" || strip(put(subgroupcatnum,best.)));
				run;

                /*reset unique_psestimate for subgroups because subgroup data may vary with the same PSESTIMATEGRP due to
                  using the post-trimmed/matchedinfull population*/
                %let unique_psestimate = 1;
			%end;

	        /*Types 1-5: unweighted*/
			%if %str("&reporttype") ne %str("T6") and %eval(&unique_psestimate.) = 1 %then %do;
	          %baselinecomputemetrics(table=Unadjusted, weight=Unweighted, dataout=baseline_aggregatetab1, labelout=baseline_labels0, suffix=&suffix.);
	        %end;

	        /*L2 tables*/
            /*PS Match: Fixed ratio matching is unweighted, variable ratio matching is weighted*/
            %if &psfile. = psmatchfile %then %do;
                %if "&ratio" = "F" %then %do;
                %baselinecomputemetrics(table=Adjusted, weight=Unweighted, dataout=baseline_aggregatetab2, labelout=baseline_labels2, suffix=&suffix.);
                %end;
                %if "&ratio" = "V" %then %do;
                %baselinecomputemetrics(table=Adjusted, weight=Weighted, dataout=baseline_aggregatetab3, labelout=baseline_labels3, suffix=&suffix.);
                %end;
            %end;

            /*PS Stratification: Unweighted for PS Stratum weighted analysis and Weighted table*/
            %if &psfile. = stratificationfile %then %do;
                %if ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") %then %do;
    		    %baselinecomputemetrics(table=Adjusted, weight=Unweighted, dataout=baseline_aggregatetab4, labelout=baseline_labels4, suffix=&suffix.);
    		    %end;
                %baselinecomputemetrics(table=Adjusted, weight=Weighted, dataout=baseline_aggregatetab5, labelout=baseline_labels5, suffix=&suffix.);
            %end;

            /*IPTW: Adjusted cohort - Unweighted and Weighted */
            %if &psfile. = iptwfile %then %do;
    		    %if %eval(&unique_psestimate.) = 1 %then %do;
                %baselinecomputemetrics(table=Adjusted, weight=Unweighted, dataout=baseline_aggregatetab6, labelout=baseline_labels6, suffix=&suffix.);
    			%end;
                %baselinecomputemetrics(table=Adjusted, weight=Weighted, dataout=baseline_aggregatetab7, labelout=baseline_labels7, suffix=&suffix.);
            %end;
		%end;

        /*Type 6 switching tables*/
        %if %str("&reporttype") = %str("T6") %then %do;
            proc sql noprint;
		        select max(switchstep) into: switch_counter
                from &datain.(keep=switchstep metvar order)
                where metvar = 'N_EPISODES' and order =&b.;
            quit;

            /*initialize race collapsing vars*/
            %if &collapse_vars = race & &stratifybydp = N %then %do;
                %do c_r = 1 %to 5;
                %let t6base_collapse&c_r. = N;
                %end;
            %end;
        
            /*call macro for switch 2, switch 1, and then index date in order to record if race category in subseqent switches are collapsed*/
            %do switch_count = &switch_counter %to 0 %by -1;
                %baselinecomputemetrics(table=Switchstep_&switch_count., weight=Unweighted, dataout=baseline_aggregatetab&switch_count., labelout=baseline_labels&switch_count.);
            %end;
        %end;
		
        /*stack all tables*/
        data baseline_aggregate_prelabel;
            set baseline_aggregatetab:;
        run;

        ***********************************************************************************************;
        * Derive labels for covariates      
        ***********************************************************************************************;

        %isdata(dataset=covarname);
        %if %eval(&nobs.>0) %then %do;
			%let includecovars = Y;

            /*if covarsort = A, then alphabetize by covarlabel*/
            %if %str("&covarsort") = %str("A") %then %do;
            proc sort data=covarname sortseq=linguistic (numeric_collation=on);
                by studyname;
            run;
            %end;

            data covarname_baseline; 
                length covarlabel $&baselinelabellength.;
                set covarname(where=(runid="&runid.")); 
                %if %str("&covarsort") = %str("A") %then %do;
                by studyname;
                alphabeticalorder = _n_;
                %end;
                covarlabel = studyname;
                drop covarnum studyname;
            run;

            data baseline_aggregate_prelabel;
                length cov_varname $8;
                set baseline_aggregate_prelabel;
                /* Create covar merging variable */
                if index(metvar,'COVAR') then cov_varname=prxchange('s/^[^_]*_//',-1,prxchange('s/(LBRES|LBUNIT|_NOTESTRECORD).*//i',-1,lowcase(metvar)));
            run;

            proc sort data=covarname_baseline; 
                by cov_varname; 
            run;

            proc sort data=baseline_aggregate_prelabel;
                by cov_varname;
            run;
        %end;

        ***********************************************************************************************;
        * Apply user defined inclusion parameters and assign 1) row labels and 2) row headers          
        ***********************************************************************************************;

        /*utility macro to assign label, grouper, sortorder1, sortorder2, sortorder3 and sortorder4 */
        %macro assignbaselinevars(label=, grouper=, sortorder1 = , sortorder2=, sortorder3=, sortorder4=);
            %if %length(&label)>0 %then %do; label= &label; %end;
            %if %length(&grouper)>0 %then %do; grouper= &grouper; %end;
            %if %length(&sortorder1)>0 %then %do; sortorder1=&sortorder1.; %end;
            %if %length(&sortorder2)>0 %then %do; sortorder2=&sortorder2.; %end;
            %if %length(&sortorder3)>0 %then %do; sortorder3=&sortorder3.; %end;
            %if %length(&sortorder4)>0 %then %do; sortorder4=&sortorder4.; %end;
        %mend;

        data baseline_aggregatelabels;
            length metvar $32 label $&baselinelabellength grouper $60 sortorder1 sortorder2 3 sortorder3 sortorder4 8;

            /* Initialize sortorder3 and sortorder4 */
            sortorder3=.;
            sortorder4=.;

            %if "&includecovars" = "Y" %then %do;
                merge baseline_aggregate_prelabel (in=a) covarname_baseline;
                by cov_varname;
                if a;
            %end;
            %else %do;
                set baseline_aggregate_prelabel;
                length covarlabel $&baselinelabellength;
                call missing(covarlabel);
            %end;

            /***************************/
            /* Patient Characteristics */
            /***************************/
            %if %index(&reporttype,T4) %then %let grouperlabel = Mother;
            %else %let grouperlabel = Patient;
            if MetVar = 'PATIENT' %if %index(&reporttype,L2) %then %do; or (Metvar = 'N_EPISODES' and &cohortdef=01) %end; then do;
            %assignbaselinevars(label="Unique patients", grouper="&grouperlabel Characteristics", sortorder1 = 1, sortorder2=1);
            end;
            %if %str("&cohort") ^= %str("mi") %then %do;
            else if MetVar = 'N_EPISODES' and prxmatch('m/02|03/i',"&cohortdef.") > 0  then do; /*Only keep N_EPISODES if cohortdef = 02, 03*/
            %assignbaselinevars(label="Episodes", grouper="&grouperlabel Characteristics", sortorder1 = 1, sortorder2=2);
            end;
            %end;
            else if MetVar = 'TOTAL_WEIGHTED' then do;
            %assignbaselinevars(label="Weighted patients", grouper="&grouperlabel Characteristics", sortorder1 = 1, sortorder2=3);
            end;

            /**************************/
            /* Infant Characteristics */
            /**************************/
            %if "&outputinfantchar" = "Y" %then %do;
                else if MetVar = 'BIRTH_ENROLL' then do;
                %assignbaselinevars(label="Enrollment time after birth (days)", grouper="Infant Characteristics", sortorder1 = 1, sortorder2=4);
                end;
                else if MetVar = 'ENROLL_DIFF' then do;
                %assignbaselinevars(label="Difference between date of birth and date of enrollment (days)", grouper="Infant Characteristics", sortorder1 = 1, sortorder2=5);
                end;
            %end;

            /*******************************/
            /* Demographic Characteristics */
            /*******************************/
                /*age*/
                else if index(upcase(MetVar),'AGE') > 0 then do;
                    if MetVar = 'AGE' then do;
                    %assignbaselinevars(label="Age (years)", grouper="Demographic Characteristics", sortorder1 = 2, sortorder2=1);
                    end;
                    else do; 
                        /*Sortorder2 assigned after merging in agegroupnum values below*/
                        /*Convert AGEXX_XX to agestrat format*/
                        /*remove agegroups not requested in cohortfile*/
                        if countc(MetVar, '_') = 0 then agegroup = compress(substr(MetVar, 4)) ||'+'; 
                        else agegroup =compress(translate(substr(MetVar, 4),'-','_')); 
                        if upcase(agegroup) in (&agestrat1.) then do;
                        %assignbaselinevars(label=put(agegroup, $agegroupfmt.), grouper="Demographic Characteristics", sortorder1 = 3, sortorder2=1);
                        end;
                        else delete;
                    end;
                end;

                /*sex - only keep F if type 4 and remove rows not requested in cohortfile*/
                else if MetVar in ('SEX_F') and 'F' in (&sex.) then do;
                %assignbaselinevars(label=put('F', $sexfmt.), grouper="Demographic Characteristics", sortorder1 = 4, sortorder2=input(put('F', sexsort.),1.));
                end;
                else if MetVar in ('SEX_M') and 'M' in (&sex.) then do; 
                    %if %str("&reporttype") ne %str("T4L1") & %str("&reporttype") ne %str("T4L2") %then %do;
                        %assignbaselinevars(label=put('M', $sexfmt.), grouper="Demographic Characteristics", sortorder1 = 4, sortorder2=input(put('M', sexsort.),1.));
                    %end;
                end;
                else if MetVar in ('SEX_O') and 'O' in (&sex.) then do;
                    %if %str("&reporttype") ne %str("T4L1") & %str("&reporttype") ne %str("T4L2") %then %do;
                    %assignbaselinevars(label=put('O', $sexfmt.), grouper="Demographic Characteristics", sortorder1 = 4, sortorder2=input(put('O', sexsort.),1.));
                    %end;
                end;

                /*race - remove rows not requested in cohortfile*/
                else if MetVar in ('RACE_1') and '1' in (&race.) then do; 
                %assignbaselinevars(label=put('1', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=input(put('1', racesort.),1.));
                end;
                else if MetVar in ('RACE_2') and '2' in (&race.) then do; 
                %assignbaselinevars(label=put('2', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=input(put('2', racesort.),1.));
                end;
                else if MetVar in ('RACE_3') and '3' in (&race.) then do; 
                %assignbaselinevars(label=put('3', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=input(put('3', racesort.),1.));
                end;
                else if MetVar in ('RACE_4') and '4' in (&race.) then do; 
                %assignbaselinevars(label=put('4', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=input(put('4', racesort.),1.));
                end;
                else if MetVar in ('RACE_0') and '0' in (&race.) then do; 
                %assignbaselinevars(label=put('0', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=input(put('0', racesort.),1.));
                end;
                else if MetVar in ('RACE_5') and '5' in (&race.) then do; 
                %assignbaselinevars(label=put('5', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=input(put('5', racesort.),1.));
                end;

                /*hispanic - remove rows not requested in cohortfile*/
                else if substr(MetVar, 1,10) = 'HISPANIC_Y' and 'Y' in (&hispanic.) then do; 
                %assignbaselinevars(label=put('Y', $hispanicfmt.), grouper="Demographic Characteristics", sortorder1 = 6, sortorder2=input(put('Y', hispanicsort.),1.));
                end;
                else if substr(MetVar, 1,10) = 'HISPANIC_N' and 'N' in (&hispanic.) then do; 
                %assignbaselinevars(label=put('N', $hispanicfmt.), grouper="Demographic Characteristics", sortorder1 = 6, sortorder2=input(put('N', hispanicsort.),1.));
                end;
                else if substr(MetVar, 1,10) = 'HISPANIC_U' and 'U' in (&hispanic.) then do; 
                %assignbaselinevars(label=put('U', $hispanicfmt.), grouper="Demographic Characteristics", sortorder1 = 6, sortorder2=input(put('U', hispanicsort.),1.));
                end;

                /*year*/
                else if index((MetVar),'YEAR') > 0 then do;
                %assignbaselinevars(label=compress(substr(MetVar,6)), grouper="Demographic Characteristics", sortorder1 = 8, sortorder2=input(compress(substr(MetVar,6)),4.));
                end;

            /*******************************************************************/
            /* Type 4 - Pregnancy Characteristics and Exposure Characteristics */
            /*******************************************************************/
            %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2") %then %do;
                else if metvar in (&pregnancychar.) then do;      
                    if MetVar= 'PREPOSTIND_PRE' then do;
                    %assignbaselinevars(label=put('PRE', $prepostindfmt.), grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=input(put('PRE', prepostindsort.),1.));
                    end;
                    if MetVar= 'PREPOSTIND_TERM' then do;
                    %assignbaselinevars(label=put('TERM', $prepostindfmt.), grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=input(put('TERM', prepostindsort.),1.));
                    end;
                    if MetVar= 'PREPOSTIND_POST' then do;
                    %assignbaselinevars(label=put('POST', $prepostindfmt.), grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=input(put('POST', prepostindsort.),1.));
                    end;
                    if MetVar= 'PREPOSTIND_NONE' then do;
                    %assignbaselinevars(label=put('NONE', $prepostindfmt.), grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=input(put('NONE', prepostindsort.),1.));
                    end;
                    if MetVar= 'GA_BIRTH' then do;
                    %assignbaselinevars(label="Gestational age at delivery", grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=5);
                    end;
                end; 
                else if metvar in (&exposurechar.) then do;      
                    if MetVar= 'GA_FIRST' then do;
                    %assignbaselinevars(label="Gestational age of first exposure (weeks)", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=1);
                    end;
                    if MetVar= 'ADJUSTEDDISP_PRE' then do;
                    %assignbaselinevars(label="Mean number of dispensings in pre-pregnancy period", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=2);
                    end;
                    if MetVar= 'ADJUSTEDDISP_T1' then do;
                    %assignbaselinevars(label="Mean number of dispensings in first trimester", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=3);
                    end;
                    if MetVar= 'ADJUSTEDDISP_T2' then do;
                    %assignbaselinevars(label="Mean number of dispensings in second trimester", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=4);
                    end;
                    if MetVar= 'ADJUSTEDDISP_T3' then do;
                    %assignbaselinevars(label="Mean number of dispensings in third trimester", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=5);
                    end;
                    if MetVar= 'EXP_T1' then do;
                    %assignbaselinevars(label="Exposed during first trimester", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=6);
                    end;
                    if MetVar= 'EXP_T2' then do;
                    %assignbaselinevars(label="Exposed during second trimester", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=7);
                    end;
                    if MetVar= 'EXP_T3' then do;
                    %assignbaselinevars(label="Exposed during third trimester", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=8);
                    end;
                    if MetVar= 'EXP_PRE' then do;
                    %assignbaselinevars(label="Exposed during user-defined pre-pregnancy period", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=9);
                    end;
                end;
            %end;

            /*********************************************************************************************/
            /* Lab Characteristics                                                                       */
            /*********************************************************************************************/
            %if %quote(&labcharacteristics) ^= %str("missing") %then %do;
            else if prxchange('s/^[^_]*_//',-1,prxchange('s/(LBRES|LBUNIT|_NOTESTRECORD).*//i',-1,metvar)) in (&labcharacteristics) then do;
                /* Character lab covariates with test record row */
                if metvar in (&labcharacteristics) and metvar in (&charlabslist) then do; 
                %assignbaselinevars(label="Test record", grouper="Laboratory Characteristics", sortorder1=14, sortorder2=, sortorder3=0, sortorder4=0);
                end;
                /* Character lab covariates for all rows without start|end unit */
                if index(metvar,'LBRES') and vartype = 'dichotomous' and ^index(_label_,'|') then do; 
                %assignbaselinevars(label=put(scan(metvar,-1,'_'), $charlabfmt.), grouper="Laboratory Characteristics", sortorder1=14, sortorder2=, sortorder3=input(put(scan(metvar,-1,'_'), charlabsort.),8.), sortorder4=input(put(scan(metvar,-1,'_'), charlabsort.),8.));
                end;
                /* Character lab covariates for rows with start|end unit */
                if index(metvar,'LBRES') and vartype = 'dichotomous' and index(_label_,'|') then do; 
                %assignbaselinevars(label=_label_, grouper="Laboratory Characteristics", sortorder1=14, sortorder2=, sortorder3=input(scan(_label_,1,'|'),8.)+5, sortorder4=input(scan(scan(_label_,1,' '),-1,'|'),8.)+5);
                end;
                /* For Numeric labs - Test record row */
                if prxmatch('/^N_/',metvar) and prxmatch('/LBUNIT/',metvar) then do;
                    if strip(_label_) = 'UNKNOWN' then do; 
                    %assignbaselinevars(label="Test records with missing or unknown units", grouper="Laboratory Characteristics", sortorder1=14, sortorder2=, sortorder3=99, sortorder4=99);
                    end;
                    else do;
                    %assignbaselinevars(label=cat("Test record in ",strip(_label_)), grouper="Laboratory Characteristics",sortorder1=14, sortorder2=, sortorder3=rank(strip(_label_)), sortorder4=rank(strip(_label_)));
                    end;
                end;
                /* Numeric labs for all rows with units */
                if index(metvar,'LBRES') and vartype = 'continuous' then do; 
                    if ^index(metvar,'UNKNOWN') then do;
                    %assignbaselinevars(label="Mean, standard deviation", grouper="Laboratory Characteristics", sortorder1=14, sortorder2=, sortorder3=rank(strip(_label_))+1, sortorder4=rank(strip(_label_))+1);
                    end;
                    else do; 
                    %assignbaselinevars(label="Mean, standard deviation", grouper="Laboratory Characteristics", sortorder1=14, sortorder2=, sortorder3=100, sortorder4=100);
                    end;
                end;
                /* All lab covariates with no test record row */ 
                if prxmatch('/NOTESTRECORD/',metvar) then do; 
                %assignbaselinevars(label="No test record", grouper="Laboratory Characteristics", sortorder1=14, sortorder2=, sortorder3=99999999, sortorder4=99999999);
                end;
                if sortorder1=14 then do;
                    *Assign sort order using covarsort parameter;
                    %if %str("&covarsort") = %str("A") %then %do;
                    %assignbaselinevars(label=, grouper=, sortorder1 =, sortorder2=alphabeticalorder, sortorder3=, sortorder4=);
                    %end;
                    %else %if %str("&covarsort") = %str("C") %then %do;
                    %assignbaselinevars(label=, grouper=, sortorder1 =, sortorder2=input(compress(prxchange('s/^[^_]*_//',-1,prxchange('s/(LBRES|LBUNIT|_NOTESTRECORD).*//i',-1,metvar)),,'A'),4.), sortorder3=, sortorder4=);
                    %end;
                    %else %if %str("&covarsort") = %str("O") %then %do;
                    length covarorderlist $&covarlistlength.;
                    covarorderlist = compress(tranwrd(resolve('&labcharacteristics.'), '"', ""));                     
                    %assignbaselinevars(label=, grouper=, sortorder1 =, sortorder2=findw(compress(covarorderlist), compress(prxchange('s/^[^_]*_//',-1,prxchange('s/(LBRES|LBUNIT|_NOTESTRECORD).*//i',-1,metvar))), ',','e'), sortorder3=, sortorder4=);
                    %end;
                end;
            end;
            %end;

            /*********************************************************************************************/
            /* Medical Product Use, Health Characteristics, Health Service Utilization Intensity Metrics */
            /*********************************************************************************************/
            else if metvar in (&healthchar.,&medproduse.,&UtilizationIntensity.) then do;   
                /*Assign grouper and sortorder1*/
                if metvar in (&healthchar.) then do;
                %assignbaselinevars(label=, grouper="Health Characteristics", sortorder1 = 12, sortorder2=);
                end;
                if metvar in (&medproduse.) then do;
                %assignbaselinevars(label=, grouper="Medical Product Use", sortorder1 = 13, sortorder2=);
                end;
                if metvar in (&UtilizationIntensity.) then do;
                %assignbaselinevars(label=, grouper="Health Service Utilization Intensity Metrics", sortorder1 = 15, sortorder2=);
                end;

                /*Assign labels and sortorder2*/
                if metvar = 'COMORBIDSCORE' then do;
                %assignbaselinevars(label="Charlson/Elixhauser combined comorbidity score", grouper=, sortorder1 =, sortorder2=0);
                end;
                if metvar = 'NUMAV' then do;
                %assignbaselinevars(label="Mean number of ambulatory encounters", grouper=, sortorder1 =, sortorder2=2000);
                end;
                if metvar = 'NUMED' then do;
                %assignbaselinevars(label="Mean number of emergency room encounters", grouper=, sortorder1 =, sortorder2=2001);
                end;
                if metvar = 'NUMIP' then do;
                %assignbaselinevars(label="Mean number of inpatient hospital encounters", grouper=, sortorder1 =, sortorder2=2002);
                end;
                if metvar = 'NUMIS' then do;
                %assignbaselinevars(label="Mean number of non-acute institutional encounters", grouper=, sortorder1 =, sortorder2=2003);
                end;
                if metvar = 'NUMOA' then do;
                %assignbaselinevars(label="Mean number of other ambulatory encounters", grouper=, sortorder1 =, sortorder2=2004);
                end;
                if metvar = 'NUMRX' then do;
                %assignbaselinevars(label="Mean number of filled prescriptions", grouper=, sortorder1 =, sortorder2=2005);
                end;
                if metvar = 'NUMGENERIC' then do;
                %assignbaselinevars(label="Mean number of generics dispensed", grouper=, sortorder1 =, sortorder2=2006);
                end;
                if metvar = 'NUMCLASS' then do;
                %assignbaselinevars(label="Mean number of unique drug classes dispensed", grouper=, sortorder1 =, sortorder2=2007);
                end;
                if substr(metvar,1,5)='COVAR' then do;
                    *Assign sort order using covarsort parameter;
                    %if %str("&covarsort") = %str("A") %then %do;
                    %assignbaselinevars(label=covarlabel, grouper=, sortorder1 =, sortorder2=alphabeticalorder);
                    %end;
                    %else %if %str("&covarsort") = %str("C") %then %do;
                    %assignbaselinevars(label=covarlabel, grouper=, sortorder1 =, sortorder2=input(substr(metvar,6),4.));
                    %end;
                    %else %if %str("&covarsort") = %str("O") %then %do;
                    length covarorderlist $&covarlistlength.;
                    covarorderlist = compress(tranwrd(resolve('&healthchar.,&medproduse.,&UtilizationIntensity'), '"', ""));                     
                    %assignbaselinevars(label=covarlabel, grouper=, sortorder1 =, sortorder2=findw(compress(covarorderlist), compress(metvar), ',','e'));
                    %end;
                end;
            end;
            
            if missing(label) then delete;

            keep analysisgrp order table weight metvar vartype label agegroup sortorder1 sortorder2 sortorder3 sortorder4 grouper exp_mean0 exp_std0 exp_mean0_char exp_std0_char
                %if "&stratifybydp" = "Y" %then %do; exp_mean: exp_std: %end;
                %if "&includecomp" = "Y" %then %do; comp_mean0 comp_std0 comp_mean0_char comp_std0_char
                  %if "&stratifybydp" = "Y" %then %do; comp_mean: comp_std:
                    %if "&computebalance." = "Y" %then %do; ad: sd: %end;
                  %end;   
                  %else %do;
                    %if "&computebalance." = "Y" %then %do; ad0: sd0: %end;
                  %end;
                %end; 
                %if &reporttype=T2L2 %then %do;
                monitoringperiod
                %end;
				%if &reporttype=T2L2 or &reporttype=T4L2 %then %do;
				subgroup subgroupcat
				%end;
                ;
        run;

        /*Merge in agefmtsort to correctly update sortorder*/
        proc sql noprint;
            create table baseline_aggregatefinal as
            select x.*, y.agegroupnum
            from baseline_aggregatelabels as x
            left join agefmtsort(where=(cohortgrp="&cohortgrp" and runid="&runid.")) as y
            on x.agegroup=y.agegroup;
        quit;

        data baseline_aggregatefinal;
            set baseline_aggregatefinal;
                if sortorder1 =3 then do;
                    sortorder2 = agegroupnum;
                end;
            drop agegroup agegroupnum;
        run;

        /* Merge in alphabetical sortorder into baseline labels dataset */
        %if %str("&covarsort") = %str("A") and %quote(&labcharacteristics) ^= %str("missing") %then %do;
            %do labelcounter = &switch_counter %to 0 %by -1;
            proc sql noprint undo_policy=none; 
                create table baseline_labels&labelcounter. as 
                select a.*, b.alphabeticalorder as sortorder2 length=3
                from baseline_labels&labelcounter.(drop=sortorder2) a 
                left join covarname_baseline b
                on a.cov_varname = b.cov_varname;
            quit;
            %end;
        %end;

        data baseline_aggregatefinal;
            set baseline_aggregatefinal baseline_labels:(keep=label sortorder1 sortorder2 sortorder3 sortorder4 grouper analysisgrp table weight order
                                                        %if %index(&reporttype,L2) %then %do; subgroup subgroupcat %end;);
        run;

        /*Final sort*/;
        proc sort data=baseline_aggregatefinal;
            by %if &reporttype. = T2L2 or &reporttype. = T4L2 %then %do; subgroup subgroupcat %end; table weight sortorder1 sortorder2 sortorder3 sortorder4;
        run;

        ***********************************************************************************************;
        * Stack and save final table                   
        ***********************************************************************************************;
        %if %eval(&b.=1) %then %do;
            data &dataout.;
                set baseline_aggregatefinal;
            run;
        %end;
        %else %do;
            data &dataout.;
                set &dataout. baseline_aggregatefinal;
            run;
        %end;

        /*Clean up*/
        proc datasets nowarn noprint lib=work;
            delete baseline_aggregatetab: baseline_aggregatelabels baseline_aggregatefinal baseline_aggregate_prelabel baseline_labels: covarname_baseline _tempcohort;
        quit;

        %symdel agestrat1;

    %end; /*loop through each baseline group*/
   
	%put =====> END MACRO: baseline_compute;

%mend baseline_compute;
