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
*       - switchstep
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
                /*computebalance defaults to Y for L2 tables*/
                %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
                call symputx('computebalance', 'Y');
                %end;
                %else %do;
                call symputx('computebalance', upcase(computebalance));
                %end;

                /*inialize to dummy value if missing*/
                if missing(healthchar) then call symputx('healthchar', 'missing');
                else call symputx('healthchar', upcase(healthchar));
                if missing(medproduse) then call symputx('medproduse', 'missing');
                else call symputx('medproduse', upcase(medproduse));
                if missing(UtilizationIntensity) then call symputx('UtilizationIntensity', 'missing');
                else call symputx('UtilizationIntensity', upcase(UtilizationIntensity));

                /*type 4 pregnancy specific parameters*/
                %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2") %then %do;
                call symputx('pregnancychar', upcase(pregnancychar));
                call symputx('outputinfantchar', strip(upcase(outputinfantchar)));
                call symputx('exposurechar', upcase(exposurechar));
                call symputx('includenonpregnant', strip(upcase(includenonpregnant)));
                %end;
                %else %do;
                call symputx('outputinfantchar', 'N');
                call symputx('includenonpregnant', 'N');
                %end;

                /*if reporttype = T2L2 or T4L2 or cohort = mi or includenonpreggroup = Y then include COMP columns*/
                if "&reporttype."="T2L2" | "&reporttype."="T4L2" | upcase(computebalance)= 'Y' |
                   upcase(includenonpregnant) = 'Y' | cohort = "mi" then do;
                   call symputx('includecomp', 'Y');
                end;
                else do;
                   call symputx('includecomp', 'N');
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
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp."));
                call symputx('psfile', strip(file));

                if file = 'psmatchfile' then call symputx('ratio',upcase(ratio));
                if file = 'stratificationfile' then call symputx("weightscheme",strip(upcase(strataweight)));
            run;
        %end;

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
                    set infolder.&&&runid._multeventfile(where=(analysisgrp="&analysisgrp"));
                    call symputx('cohortgrp', strip(primary));
                run;
            %end;
            %if %str("&cohort") = %str("overlap") %then %do;
                data _null_;
                    set infolder.&&&runid._overlapfile(where=(analysisgrp="&analysisgrp"));
                    call symputx('cohortgrp', strip(primary));
                run;
            %end;
            %if %str("&cohort") = %str("concomitance") %then %do;
                data _null_;
                    set infolder.&&&runid._concfile(where=(analysisgrp="&analysisgrp"));
                    call symputx('cohortgrp', strip(primary));
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
            /*if file = psmatchfile, stratificationfile, iptwfile - then link to psestimationfile*/
            /*if file = covstratfile, pull directly*/
            %if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;
                data _null_;
                    set infolder.&&&runid._&psfile.(where=(analysisgrp="&analysisgrp."));
                    call symputx('psestimategrp', psestimategrp);
                run;
                data _null_;
                    set infolder.&&&runid._psestimationfile(where=(psestimategrp="&psestimategrp."));
                    call symputx('eoi', strip(eoi));
                run;
            %end;
            %else %if &psfile. = covstratfile %then %do;
                data _null_;
                    set infolder.&&&runid._covstratfile(where=(analysisgrp="&analysisgrp."));
                    call symputx('eoi', strip(eoi));
                run;
            %end;

            *T2: EOI group = cohortgrp;
            %if %str("&reporttype") = %str("T2L2") %then %do;
                %let cohortgrp = &eoi;
            %end;
            *T4: After extracting EOI group - need to link to MICOHORTFILE to grab cohortgrp;
            %if %str("&reporttype") = %str("T4L2") %then %do;
                data _null_;
                    set infolder.&&&runid._micohortfile(where=(milgrp=substr("&eoi",1,length("&eoi")-4)));
                    call symputx('cohortgrp', strip(groupname));
                run;
            %end;
        %end;
		%else %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
            data _null_;
			
			  set infolder.&&&runid._treatmentpathways (where=((analysisgrp="&analysisgrp." and switchevalstep = 0)));
                call symputx('cohortgrp', strip(group))
		    ;
            
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
            data _null_;
                set infolder.&&&runid._type1file(where=(group="&cohortgrp."));
                call symputx("cohortdef", strip(t1cohortdef));
            run;
        %end;
        %else %if %sysfunc(prxmatch(m/T2L1/i,&reporttype.)) > 0 %then %do;
            data _null_;
                set infolder.&&&runid._type2file(where=(group="&cohortgrp."));
                call symputx("cohortdef", strip(t2cohortdef));
            run;
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


        ***********************************************************************************************
        * Put total number of patients and episodes in macro variables and compute overall totals
        **********************************************************************************************;
        
           data _null_; 
              set &datain.(where=(metvar in ('PATIENT', 'N_EPISODES') and table ne 'Adjusted' and order=&b.
                           %if %str("&reporttype") = %str("T6") %then %do;
                               and switchstep = 0
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
	    ***********************************************************************************************;
        * Macro computes pooled metrics                         
        ***********************************************************************************************;
      %macro baselinecomputemetrics(table=, weight=, dataout=);  
         
            /*Put total number of episodes into a macro variable for Adjusted tables - note: L2 only*/
            %if "&table." = "Adjusted" %then %do;
                data _null_; 
                    set &datain.(where=(upcase(metvar)='N_EPISODES' and table = "&table." 
                      and weight = "&weight" and order=&b.));
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

			%if %str("&reporttype") = %str("T6") and &switch_count > 0 %then %do;
                data _null_; 
                    set &datain.(where=(upcase(metvar) in ('PATIENT', 'N_EPISODES')  
                      and weight = "&weight" and order=&b. and switchstep = &switch_count));
                    %do a = 1 %to &num_dp.;
                        call symputx("n_&table._episodes_exp&a", exp_mean&a); 
                    %end;

                    /*recompute total episodes for loop*/
                    total_exp_episodes = sum(of exp_mean1-exp_mean&num_dp.);
                    call symputx("total_&table._exp_episodes", total_exp_episodes); 
                    call symputx("total_&table._exp_patients", total_exp_episodes); /*Defensive for sex/race/hispanic computation*/
                run;
				
				data _null_; 
                    set &datain.(where=(upcase(metvar) in ('PATIENT', 'N_EPISODES') 
                      and weight = "&weight" and order=&b. and switchstep = %eval(&switch_count-1)));
                    %do a = 1 %to &num_dp.;
					    %let s_b = %eval(&switch_count-1);
                        call symputx("n_Switchstep_&s_b._episodes_exp&a", exp_mean&a); 
                    %end;
					/*recompute total episodes for loop*/
                    total_exp_episodes = sum(of exp_mean1-exp_mean&num_dp.);
                    call symputx("total_Switchstep_&s_b._exp_episodes", total_exp_episodes); 
                    call symputx("total_Switchstep_&s_b._exp_patients", total_exp_episodes); /*Defensive for sex/race/hispanic computation*/
                run;
            %end;

            data &dataout.; 
                length metvar $30;
                set &datain.(where=(table="&table" and weight = "&weight" and order=&b.));

                format eoi_a 8.1 eoi_b 8.3 %if "&includecomp" = "Y" %then %do; ref_a 8.1 ref_b 8.3 %end; ;

                /*set up total count variables and arrays*/
                total_exp_episodes = "&&total_&table._exp_episodes."; /*Sum of episodes in group1*/ 
                total_exp_patients = "&&total_&table._exp_patients."; /*Sum of patients in group1*/ 
                agg_exp_w = 0; /*Sum of weights*/
                agg_exp_w2 = 0;
                array num_exp(&num_dp.) exp_mean1-exp_mean&num_dp.;
                array std_exp(&num_dp.) exp_std1-exp_std&num_dp.;
                array exp_s2(&num_dp.) exp_s2_1-exp_s2_&num_dp.;
                array exp_w(&num_dp.) exp_w1_1-exp_w1_&num_dp.;
                array exp_w2(&num_dp.) exp_w2_1-exp_w2_&num_dp.;

                %if "&includecomp" = "Y" %then %do;
                total_comp_episodes = "&&total_&table._comp_episodes."; /*Sum of episodes in group2*/ 
                total_comp_patients = "&&total_&table._comp_patients."; /*Sum of patients in group2*/
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

                /*Aggregate dichotomous variables*/
                if lowcase(vartype) = 'dichotomous' then do;
                    eoi_a=max(0,sum(of exp_mean1-exp_mean&num_dp.)); /*Aggregated numerator in the exposed group*/ 
                    %if "&includecomp" = "Y" %then %do;
                    ref_a=max(0,sum(of comp_mean1-comp_mean&num_dp.));/*Aggregated numerator in the comparison group*/
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
                    eoi_b = 0;
                    %if "&includecomp" = "Y" %then %do;
                    ref_b = 0;
                    %end;

                    ** Calculate aggregated percent: 
                       - Denominator for sex, race, and Hispanic is total number of patients
                       - Denominator for other metrics is total number of episodes 
                       - Total Episodes/Patients: for unadjusted tables:
                            - L1: do not fill in %, 
                            - L2: 100% for unadjusted, compute % out of unadjusted totalfor adjusted tables
					        - Switching: Switching allows for baseline to be a portion of the full baseline. 
					          Each of these new baselines need calculated for use in the demoniators.;
                    if index(metvar, 'SEX') >0 | index(metvar, 'RACE') >0 | index(metvar, 'HISPANIC') >0 then do;
                        if ^missing(eoi_a) and (total_exp_patients gt 0) then eoi_b = eoi_a/total_exp_patients;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(ref_a) and (total_comp_patients gt 0) then ref_b = ref_a/total_comp_patients;
                        %end;
                    end;
                    else if metvar in ('N_EPISODES', 'PATIENT') then do;
                        eoi_b = .;
                        ref_b = .;
                        %if ("&table" = "Unadjusted" & %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2")) or
                            ("&table" ="Switchstep_0" or "&table" ="Switchstep_1") %then %do;
                            eoi_b = 1;
                            %if "&includecomp" = "Y" %then %do;
                            ref_b = 1;
                            %end;
                        %end;
						%else %if %str("&reporttype") = %str("T6")  and &switch_count > 0 %then %do;
						  %let switch_b = %eval(&switch_count.-1);
                          if ^missing(eoi_a) and (total_exp_episodes gt 0) then eoi_b = eoi_a/&&total_Switchstep_&switch_b._exp_episodes;
						  %if "&stratifybydp" = "Y" %then %do;
						    %do nu_d = 1 %to &num_dp.;
							  exp_std&nu_d. = exp_mean&nu_d./&&&n_Switchstep_&switch_b._episodes_exp&nu_d.;
							%end;
                          %end;
						%end;
						  
						%else %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
                          if ^missing(eoi_a) and (total_exp_episodes gt 0) then eoi_b = eoi_a/&total_unadjusted_exp_episodes.;
                          %if "&includecomp" = "Y" %then %do;
                            if ^missing(ref_a) and (total_comp_episodes gt 0) then ref_b = ref_a/&total_unadjusted_comp_episodes.;
                          %end;
						%end;
                      end;
                    else do;
                        if ^missing(eoi_a) and (total_exp_episodes gt 0) then eoi_b = eoi_a/total_exp_episodes;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(ref_a) and (total_comp_episodes gt 0) then ref_b = ref_a/total_comp_episodes;
                        %end;
                    end;

                    %if "&includecomp" = "Y" & "&computebalance." = "Y" %then %do;
                        if metvar not in ('N_EPISODES', 'PATIENT') then do; /*AD/SD not computed for total rows*/
                            ad = compress(put((100*(eoi_a/agg_exp_w)) - (100*(ref_a/agg_comp_w)), 8.3)) ;

                            /*standardized difference*/
                            a = (eoi_a/agg_exp_w);
                            b = (ref_a/agg_comp_w);
                            %if "&weight" = "Weighted" %then %do; /*Weighted Adjusted*/  
                                stw = agg_sw_exp / agg_v_exp;
                                scw = agg_sw_comp / agg_v_comp;
                                c = sqrt( (stw + scw) / 2);
                            %end;
                            %else %do; /*Unweighted*/
                                c = sqrt(((a*(1-a)) + (b*(1-b))) / 2);
                            %end;
                            /*SD*/
                            if (eoi_a > 0) AND (ref_a > 0) AND (c>0) then sd = compress(put(((a-b) / c), 8.3));
                            else sd = '-';

                            %if "&stratifybydp" = "Y" %then %do;
                                %do i =1 %to &num_dp.;
                                if missing(ad&i.)=0 then ad&i. = ad&i.*100;
                                %end;
                            %end;
                        end;
                    %end;

                    /*round eoi_a and eoi_b - will be a decimal for weighted tables*/
                    eoi_a = round(eoi_a, 1);
                    %if "&includecomp" = "Y" %then %do;
                    ref_a = round(ref_a, 1);
                    %end;
                    %if "&stratifybydp" = "Y" %then %do;
                        %do i =1 %to &num_dp.;
                            exp_mean&i. = round(exp_mean&i., 1);
                            comp_mean&i. = round(comp_mean&i., 1);
                        %end;
                    %end;
                end;

                /*Aggregate continuous variables*/
                if lowcase(vartype) = 'continuous' and metvar ne 'MAHALANOBIS' then do;
                    /*assign dp specific patient and episode count*/
                    %do a = 1 %to &num_dp.; 
                        exp_episodes&a. = "&&&&n_&table._episodes_exp&a."; /*Total number of patients in the exposed*/
                        %if "&includecomp" = "Y" %then %do;
                        comp_episodes&a. = "&&&&n_&table._episodes_comp&a."; /*Total number of patients in the reference group*/
                        %end;
                    %end;
                    array exp_episodes(&num_dp.) exp_episodes1-exp_episodes&num_dp.;
                    %if "&includecomp" = "Y" %then %do;
                    array comp_episodes(&num_dp.) comp_episodes1-comp_episodes&num_dp.;
                    %end;

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
                            if num_exp(i) & exp_s2(i)>= 0 then agg_sw_exp = agg_sw_exp + ( (exp_s2(i))*(vk_exp(i))); /*Numerator of Sw2 for SD calculation*/
                            if num_comp(i)& comp_s2(i)>= 0 then agg_sw_comp = agg_sw_comp + ( (comp_s2(i))*(vk_comp(i))); 
                        %end;
                        %else %do;
                            ** Get weighted Std Dev for pooled Standard Deviation calculation  ** ;
                            if ^missing(std_exp(i)) then exp_std_sum = exp_std_sum + (std_exp(i)**2)*(exp_episodes(i) - 1);
                            ** Count number of data partners with a value - for pooled std dev calculation  ** ;
                            if ^missing(std_exp(i)) then count = count + 1 ;
                            %if "&includecomp" = "Y" %then %do;
                            if ^missing(std_comp(i)) then comp_std_sum = comp_std_sum + (std_comp(i)**2)*(comp_episodes(i) - 1);
                            %end;
                        %end;
                    end;
                        
                    if ^missing(exp_mean_num) AND (agg_exp_w gt 0) then eoi_a = exp_mean_num/agg_exp_w ;
                    %if "&includecomp" = "Y" %then %do;
                    if ^missing(comp_mean_num) AND (agg_comp_w gt 0) then ref_a = comp_mean_num/agg_comp_w ;
                    %end;            

                    %if "&weight" = "Weighted" %then %do;
                        if ^missing(agg_sw_exp) AND (agg_v_exp gt 0) then eoi_b = sqrt(agg_sw_exp/agg_v_exp) ;
                        if ^missing(agg_sw_comp) AND (agg_v_comp gt 0) then ref_b = sqrt(agg_sw_comp/agg_v_comp) ;
                    %end;
                    %else %do;
                        if ^missing(exp_std_sum) AND (total_exp_episodes gt 0) then eoi_b = sqrt(exp_std_sum/(total_exp_episodes - count)) ;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(comp_std_sum) AND (total_comp_episodes gt 0) then ref_b = sqrt(comp_std_sum/(total_comp_episodes - count));
                        %end;
                    %end;

                    %if "&includecomp" = "Y" & "&computebalance." = "Y" %then %do;
                        ad = compress(put(eoi_a - ref_a, 8.3)) ;

                        %if "&weight" = "Weighted" %then %do; /*Weighted SD*/
                            /*standardized difference*/
                            a = eoi_a - ref_a;
                            stw = agg_sw_exp / agg_v_exp;
                            scw = agg_sw_comp/agg_v_comp;
                            c = sqrt( (stw + scw) / 2);
                            if (^missing(a)) AND (c>0) then sd = compress(put(a/c, 8.3));
                            else sd = '-';
                        %end;
                        %else %do; /*unweighted SD*/
                            if (eoi_b > 0) AND (ref_b > 0) then sd = compress(put((eoi_a - ref_a)/(sqrt((eoi_b*eoi_b + ref_b*ref_b)/2)), 8.3)) ;
                            else sd = '-';
                        %end;
                    %end;

                    drop exp_mean_num exp_std_sum %if "&includecomp" = "Y" %then %do; comp_mean_num comp_std_sum %end; ;
                end;

                /*reformat DP specific vars*/
                %if "&stratifybydp" = "Y" & "&computebalance." = "Y" %then %do;
                    %do i = 1 %to &num_dp.;
                        adchar&i. = strip(compress(put(ad&i., 8.3)));
                        sdchar&i. = strip(compress(put(sd&i., 8.3)));
                
                        if metvar ne 'MAHALANOBIS' then do;
                          if adchar&i. = '.' then adchar&i. = '-';
                          if sdchar&i. = '.' then sdchar&i. = '-';
                        end;
                    %end;
                %end;
                %if "&stratifybydp" = "Y" %then %do;
                    format exp_mean: 8.1 exp_std: 8.3 %if "&includecomp" = "Y" %then %do; comp_mean: 8.1 comp_std: 8.3 %end; ;
                %end;

                keep metvar analysisgrp order vartype weight table eoi_a eoi_b 
                    %if "&stratifybydp" = "Y" %then %do; exp_mean: exp_std: %end;
                    %if "&includecomp" = "Y" %then %do; ref_a ref_b
                      %if "&stratifybydp" = "Y" %then %do; comp_mean: comp_std:
                        %if "&computebalance." = "Y" %then %do; adchar: sdchar: ad sd %end;
                      %end;   
                      %else %do;
                        %if "&computebalance." = "Y" %then %do; ad sd %end;
                      %end;
                    %end; 
                    ;

                /*Removing unweighted total row for IPTW and PS stratum weighted table 1. Will use TOTAL_WEIGHTED row*/
                %if &psfile. = iptwfile | "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %do; 
                    if metvar = 'N_EPISODES' then delete;
                    if MetVar = 'TOTAL_WEIGHTED' then do;
                        eoi_b = .;
                        ref_b = .;
                        ad = '-';
                        sd = '-';
                    end;
                %end;
				/*Removing FOLLOWUPTIME/EVENT rows*/
                 if index(MetVar,'FOLLOWUP') > 0 or index(MetVar,'EVENT') > 0 then delete;
            run;

        %mend baselinecomputemetrics;

        ***********************************************************************************************;
        * Compute aggregated tables                     
        ***********************************************************************************************;
        %let switch_count = 0;
        %if %str("&reporttype") = %str("T6") %then %do;
		   %baselinecomputemetrics(table=Switchstep_0, weight=Unweighted, dataout=baseline_aggregatetab1);
		%end;
        /*All - unweighted*/
		%if %str("&reporttype") ne %str("T6") %then %do;
          %baselinecomputemetrics(table=Unadjusted, weight=Unweighted, dataout=baseline_aggregatetab1);
        %end;
        /*PS Match - Fixed ratio matching is unweighted, variable ratio matching is weighted*/
        %if &psfile. = psmatchfile %then %do;
            %if "&ratio" = "F" %then %do;
            %baselinecomputemetrics(table=Adjusted, weight=Unweighted, dataout=baseline_aggregatetab2);
            %end;
            %if "&ratio" = "V" %then %do;
            %baselinecomputemetrics(table=Adjusted, weight=Weighted, dataout=baseline_aggregatetab3);
            %end;
        %end;

        /*PS Stratification - Unweighted for PS Stratum weighted analysis and Weighted table*/
        %if &psfile. = stratificationfile %then %do;
            %if "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %do;
		    %baselinecomputemetrics(table=Adjusted, weight=Unweighted, dataout=baseline_aggregatetab4);
		    %end;
            %baselinecomputemetrics(table=Adjusted, weight=Weighted, dataout=baseline_aggregatetab5);
        %end;

        /*IPTW - Adjusted cohort - Unweighted and Weighted */
        %if &psfile. = iptwfile %then %do;
            %baselinecomputemetrics(table=Adjusted, weight=Unweighted, dataout=baseline_aggregatetab6);
            %baselinecomputemetrics(table=Adjusted, weight=Weighted, dataout=baseline_aggregatetab7);
        %end;

		%if %str("&reporttype") = %str("T6") %then %do; 

          proc sql noprint;
		    select max(switchstep) into: switch_counter from &datain. where metvar = 'N_EPISODES' and order =&b. ;
		  quit;

          %do switch_count = 1 %to &switch_counter;
		    %baselinecomputemetrics(table=Switchstep_&switch_count., weight=Unweighted, dataout=baseline_aggregatetab%eval(7+&switch_count.));
          %end;
        %end;
		
 
        /*stack all tables*/
        data baseline_aggregate_prelabel;
            set baseline_aggregatetab:;
        run;
		
        ***********************************************************************************************;
        * Execute %baseline_expand_parameters()              
        ***********************************************************************************************;
        %baseline_expand_parameters(var =medproduse);
        %baseline_expand_parameters(var =healthchar);
        %baseline_expand_parameters(var =UtilizationIntensity);
        %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2") %then %do;
        %baseline_expand_parameters(var =pregnancychar);
        %baseline_expand_parameters(var =exposurechar);
        %end;

        %let covarlistlength = %length(&healthchar.,&medproduse.,&UtilizationIntensity);

        ***********************************************************************************************;
        * Derive labels for covariates              
        ***********************************************************************************************;
        %let includecovars = N;
        %let baselinelabellength = 70;

        %isdata(dataset=&&runid._covarname);
        %if %eval(&nobs.>0) %then %do;
            %let includecovars = Y;
            proc sql noprint;
                select max(length(studyname)) into :baselinelabellength
                from &&runid._covarname;
            quit;

            %if %eval(&baselinelabellength. <70) %then %let baselinelabellength = 70;

            /*if covarsort = A, then alphabetize by covarlabel*/
            %if %str("&covarsort") = %str("A") %then %do;
            proc sort data=&&runid._covarname sortseq=linguistic (numeric_collation=on);
                by studyname;
            run;
            %end;

            data covarname_baseline; 
                length MetVar $30 covarlabel $&baselinelabellength.;
                set &&runid._covarname; 
                %if %str("&covarsort") = %str("A") %then %do;
                by studyname;
                alphabeticalorder = _n_;
                %end;
                MetVar = cats("COVAR", covarnum);
                covarlabel = studyname;
                drop covarnum studyname;
            run;

            proc sort data=covarname_baseline; 
                by metvar; 
            run;

            proc sort data=baseline_aggregate_prelabel;
                by metvar;
            run;
        %end;

        ***********************************************************************************************;
        * Apply user defined inclusion parameters and assign 1) row labels and 2) row headers          
        ***********************************************************************************************;

        /*utility macro to assign label, grouper, sortorder, sortorder2*/
        %macro assignbaselinevars(label=, grouper=, sortorder1 = , sortorder2=);
            %if %length(&label)>0 %then %do; label= &label; %end;
            %if %length(&grouper)>0 %then %do; grouper= &grouper; %end;
            %if %length(&sortorder1)>0 %then %do; sortorder1=&sortorder1.; %end;
            %if %length(&sortorder2)>0 %then %do; sortorder2=&sortorder2.; %end;
        %mend;

        data baseline_aggregatelabels;
            length label $&baselinelabellength grouper $60 sortorder1 sortorder2 3;

            %if "&includecovars" = "Y" %then %do;
                merge baseline_aggregate_prelabel (in=a) covarname_baseline;
                by metvar;
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
            if MetVar = 'PATIENT' then do;
            %assignbaselinevars(label="Number of unique patients", grouper="Patient Characteristics", sortorder1 = 1, sortorder2=1);
            end;
            else if MetVar = 'N_EPISODES' and (&cohortdef.=02 | &cohortdef.=03) then do; /*Only keep N_EPISODES if cohortdef = 02, 03*/
            %assignbaselinevars(label="Number of episodes", grouper="Patient Characteristics", sortorder1 = 1, sortorder2=2);
            end;
            else if MetVar = 'TOTAL_WEIGHTED' then do;
            %assignbaselinevars(label="Number of weighted patients", grouper="Patient Characteristics", sortorder1 = 1, sortorder2=3);
            end;

            /*infant characteristics*/
            %if "&outputinfantchar" = "Y" %then %do;
                else if MetVar = 'BIRTH_ENROLL' then do;
                %assignbaselinevars(label="Mean enrollment time after birth", grouper="Patient Characteristics", sortorder1 = 1, sortorder2=4);
                end;
                else if MetVar = 'ENROLL_DIFF' then do;
                %assignbaselinevars(label="Mean difference between date of birth and date of enrollment", grouper="Patient Characteristics", sortorder1 = 1, sortorder2=5);
                end;
            %end;

            /*******************************/
            /* Demographic Characteristics */
            /*******************************/
                /*age*/
                else if index(upcase(MetVar),'AGE') > 0 then do;
                    if MetVar = 'AGE' then do;
                    %assignbaselinevars(label="Mean age (years)", grouper="Demographic Characteristics", sortorder1 = 2, sortorder2=1);
                    end;
                    else do; 
                        /*Sortorder2 assigned after merging in agegroupnum values below*/
                        /*Convert AGEXX_XX to agestrat format*/
                        /*remove agegroups not requested in cohortfile*/
                        if countc(MetVar, '_') = 0 then agegroup = compress(substr(MetVar, 4)) ||'+'; 
                        else agegroup =compress(translate(substr(MetVar, 4),'-','_')); 
                        if upcase(agegroup) in (&agestrat1.) then do;
                        %assignbaselinevars(label=put(agegroup, $agefmt.), grouper="Demographic Characteristics", sortorder1 = 3, sortorder2=1);
                        end;
                        else delete;
                    end;
                end;

                /*sex - only keep F if type 4 and remove rows not requested in cohortfile*/
                else if MetVar in ('FEMALE', 'SEX_F') and 'F' in (&sex.) then do;
                %assignbaselinevars(label=put('F', $sexfmt.), grouper="Demographic Characteristics", sortorder1 = 4, sortorder2=put('F', sexsort.));
                end;
                else if MetVar in ('MALE', 'SEX_M') and 'M' in (&sex.) then do; 
                    %if %str("&reporttype") ne %str("T4L1") & %str("&reporttype") ne %str("T4L2") %then %do;
                        %assignbaselinevars(label=put('M', $sexfmt.), grouper="Demographic Characteristics", sortorder1 = 4, sortorder2=put('M', sexsort.));
                    %end;
                end;
                else if MetVar in ('SEX_OTHER', 'SEX_O') and 'O' in (&sex.) then do;
                    %if %str("&reporttype") ne %str("T4L1") & %str("&reporttype") ne %str("T4L2") %then %do;
                    %assignbaselinevars(label=put('O', $sexfmt.), grouper="Demographic Characteristics", sortorder1 = 4, sortorder2=put('O', sexsort.));
                    %end;
                end;

                /*race - remove rows not requested in cohortfile*/
                else if MetVar in ('AMERICANINDIAN', 'RACE_1') and '1' in (&race.) then do; 
                %assignbaselinevars(label=put('1', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=put('1', racesort.));
                end;
                else if MetVar in ('ASIAN', 'RACE_2') and '2' in (&race.) then do; 
                %assignbaselinevars(label=put('2', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=put('2', racesort.));
                end;
                else if MetVar in ('BLACK', 'RACE_3') and '3' in (&race.) then do; 
                %assignbaselinevars(label=put('3', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=put('3', racesort.));
                end;
                else if MetVar in ('PACIFICISLANDER', 'RACE_4') and '4' in (&race.) then do; 
                %assignbaselinevars(label=put('4', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=put('4', racesort.));
                end;
                else if MetVar in ('RACE_UNKNOWN', 'RACE_0') and '0' in (&race.) then do; 
                %assignbaselinevars(label=put('0', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=put('0', racesort.));
                end;
                else if MetVar in ('WHITE', 'RACE_5') and '5' in (&race.) then do; 
                %assignbaselinevars(label=put('5', $racefmt.), grouper="Demographic Characteristics", sortorder1 = 5, sortorder2=put('5', racesort.));
                end;

                /*hispanic - remove rows not requested in cohortfile*/
                else if substr(MetVar, 1,10) = 'HISPANIC_Y' and 'Y' in (&hispanic.) then do; 
                %assignbaselinevars(label=put('Y', $hispanicfmt.), grouper="Demographic Characteristics", sortorder1 = 6, sortorder2=put('Y', hispanicsort.));
                end;
                else if substr(MetVar, 1,10) = 'HISPANIC_N' and 'N' in (&hispanic.) then do; 
                %assignbaselinevars(label=put('N', $hispanicfmt.), grouper="Demographic Characteristics", sortorder1 = 6, sortorder2=put('N', hispanicsort.));
                end;
                else if substr(MetVar, 1,10) = 'HISPANIC_U' and 'U' in (&hispanic.) then do; 
                %assignbaselinevars(label=put('U', $hispanicfmt.), grouper="Demographic Characteristics", sortorder1 = 6, sortorder2=put('U', hispanicsort.));
                end;

                /*year*/
                else if index((MetVar),'YEAR') > 0 then do;
                %assignbaselinevars(label=compress(substr(MetVar,6)), grouper="Demographic Characteristics", sortorder1 = 8, sortorder2=compress(substr(MetVar,6)));
                end;

            /*******************************************************************/
            /* Type 4 - Pregnancy Characteristics and Exposure Characteristics */
            /*******************************************************************/
            %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2") %then %do;
                else if metvar in (&pregnancychar.) then do;      
                    if MetVar= 'PREPOSTIND_PRE' then do;
                    %assignbaselinevars(label="Preterm", grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=1);
                    end;
                    if MetVar= 'PREPOSTIND_TERM' then do;
                    %assignbaselinevars(label="Term", grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=2);
                    end;
                    if MetVar= 'PREPOSTIND_POST' then do;
                    %assignbaselinevars(label="Postterm", grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=3);
                    end;
                    if MetVar= 'PREPOSTIND_NONE' then do;
                    %assignbaselinevars(label="Unknown term", grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=4);
                    end;
                    if MetVar= 'GA_BIRTH' then do;
                    %assignbaselinevars(label="Mean gestational age at delivery", grouper="Pregnancy Characteristics", sortorder1 = 9, sortorder2=5);
                    end;
                end; 
                else if metvar in (&exposurechar.) then do;      
                    if MetVar= 'GA_FIRST' then do;
                    %assignbaselinevars(label="Mean gestational age of first exposure (weeks)", grouper="Exposure Characteristics", sortorder1 = 10, sortorder2=1);
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
            /* Medical Product Use, Health Characteristics, Health Service Utilization Intensity Metrics */
            /*********************************************************************************************/
            else if metvar in (&healthchar.,&medproduse.,&UtilizationIntensity.) then do;   
                /*Assign grouper and sortorder1*/
                if metvar in (&healthchar.) then do;
                %assignbaselinevars(label=, grouper="Health Characteristics", sortorder1 = 11, sortorder2=);
                end;
                if metvar in (&medproduse.) then do;
                %assignbaselinevars(label=, grouper="Medical Product Use", sortorder1 = 12, sortorder2=);
                end;
                if metvar in (&UtilizationIntensity.) then do;
                %assignbaselinevars(label=, grouper="Health Service Utilization Intensity Metrics", sortorder1 = 13, sortorder2=);
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
                    %assignbaselinevars(label=covarlabel, grouper=, sortorder1 =, sortorder2=substr(metvar,6));
                    %end;
                    %else %if %str("&covarsort") = %str("O") %then %do;
                    length covarorderlist $&covarlistlength.;
                    covarorderlist = compress(tranwrd(resolve('&healthchar.,&medproduse.,&UtilizationIntensity'), '"', ""));                     
                    %assignbaselinevars(label=covarlabel, grouper=, sortorder1 =, sortorder2=findw(compress(covarorderlist), compress(metvar), ',','e'));
                    %end;
                end;
            end;
            
            if missing(label) then delete;

            keep analysisgrp order table weight metvar label agegroup sortorder1 sortorder2 grouper eoi_a eoi_b
                %if "&stratifybydp" = "Y" %then %do; exp_mean: exp_std: %end;
                %if "&includecomp" = "Y" %then %do; ref_a ref_b
                  %if "&stratifybydp" = "Y" %then %do; comp_mean: comp_std:
                    %if "&computebalance." = "Y" %then %do; adchar: sdchar: ad sd %end;
                  %end;   
                  %else %do;
                    %if "&computebalance." = "Y" %then %do; ad sd %end;
                  %end;
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

        /*Final sort*/;
        proc sort data=baseline_aggregatefinal;
            by table weight sortorder1 sortorder2;
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
            delete baseline_aggregatetab: baseline_aggregatelabels baseline_aggregatefinal baseline_aggregate_prelabel covarname_baseline _tempcohort;
        quit;

        %symdel agestrat1;

    %end; /*loop through each baseline group*/
   
	%put =====> END MACRO: baseline_compute;

%mend baseline_compute;
