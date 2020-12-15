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
*   - datain: input dataset 
*   - reporttype
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

%macro baseline_compute(datain=, reporttype=, numbaselinetablegrp=, num_dp=, stratifybydp=, periodid=);

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
                call symputx('covarsort', upcase(covarsort));
                call symputx('healthchar', upcase(healthchar));
                /*computebalance defaults to Y for L2 tables*/
                %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
                call symputx('computebalance', 'Y');
                %end;
                %else %do;
                call symputx('computebalance', upcase(computebalance));
                %end;
                
                call symputx('medproduse', upcase(medproduse));
                call symputx('UtilizationIntensity', upcase(UtilizationIntensity));

                /*type 4 pregnancy specific parameters*/
                %if %str("&reporttype") = %str("T4L1") | %str("&reporttype") = %str("T4L2") %then %do;
                call symputx('pregnancychar', upcase(pregnancychar));
                call symputx('exposurechar', upcase(exposurechar));
                call symputx('ouputinfantchar', upcase(ouputinfantchar));
                call symputx('exposurechar', upcase(exposurechar));
                call symputx('includenonpregnant', upcase(includenonpregnant));
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

        /*for L2 tables - need to reference PS/CS specific files to pull additional parameters*/
        %let ratio = F;
        %let psfile = ;
        %let weightscheme = ;
        %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
            data _null_;
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp."));
                call symputx('psfile', file);

                if file = 'psmatchfile' then call symputx('ratio',upcase(ratio));
                if file = 'stratificationfile' then call symputx("weightscheme",strip(upcase(strataweight)));
            run;
       %end;
       
       /*Put total number of patients and episodes in macro variables and compute overall totals*/
        data _null_; 
            set &datain.(where=(metvar in ('PATIENT', 'N_EPISODES') and table = 'Unadjusted' and order=&b.));
        
            total_exp_episodes = 0;
            total_exp_patients = 0;
            %if "&includecomp" = "Y" %then %do;
            total_comp_episodes = 0;
            total_comp_patients = 0;
            %end;

            /*Number of Episodes*/
            if metvar = 'N_EPISODES' then do;
    	        total_exp_episodes = sum(of exp_mean1-exp_mean&num_dp.);
                call symputx("total_exp_episodes", total_exp_episodes); /*FORMERLY TOTEPIS*/

                %if "&includecomp" = "Y" %then %do;
        	        total_comp_episodes = sum(of comp_mean1-comp_mean&num_dp.);
                    call symputx("total_comp_episodes", total_comp_episodes); 
                %end;

                %do a = 1 %to &num_dp.;
                    call symputx("n_episodes_exp&a", exp_mean&a); /*FORMERLY TOTEXP&a*/ /*EPIS_DP&a.*/
                    %if "&includecomp" = "Y" %then %do;
                    call symputx("n_episodes_comp&a", comp_mean&a); /*FORMERLY TOTCOMP&a*/ 
                    %end;
                %end;
            end;

            /*Number of Patients*/
            else if metvar = 'PATIENT' then do;
    	        total_exp_patients = sum(of exp_mean1-exp_mean&num_dp.);
                call symputx("total_exp_patients", total_exp_patients); /*FORMERLY TOTPTS*/

                %if "&includecomp" = "Y" %then %do;
        	        total_comp_patients = sum(of comp_mean1-comp_mean&num_dp.);
                    call symputx("total_comp_patients", total_comp_patients); /*FORMERLY TOTPTS*/
                %end;

                %do a = 1 %to &num_dp.;
                    call symputx("n_patients_exp&a", exp_mean&a); /*FORMERLY TOTEXP&a*/ /*EPIS_DP&a.*/
                    %if "&includecomp" = "Y" %then %do;
                    call symputx("n_patients_comp&a", comp_mean&a); /*FORMERLY TOTCOMP&a*/ 
                    %end;
                %end;
            end;

            /*For L2 queries = number of patients is not computed since cohortdef = 01 (equal to number of episodes)*/
            if "&reporttype."="T2L2" | "&reporttype."="T4L2" then call symputx("total_exp_patients", total_exp_episodes);
            %if "&includecomp" = "Y" %then %do;
            if "&reporttype."="T2L2" | "&reporttype."="T4L2" then call symputx("total_comp_patients", total_comp_episodes);
            %end;
        run;

        %put total number of group1 episodes for order=&b.:  &total_exp_episodes.;
        %put total number of group1 patients for order=&b.:  &total_exp_patients.;
        %if "&includecomp" = "Y" %then %do;
        %put total number of group2 episodes for order=&b.:  &total_comp_episodes.;
        %put total number of group2 patients for order=&b.:  &total_comp_patients.;
        %end;

        ***********************************************************************************************;
        * Macro computes pooled metrics                         
        ***********************************************************************************************;
     
    %end; /*loop through each baseline group*/






					
    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete :;
    quit;
    
	%put =====> END MACRO: baseline_compute;

%mend baseline_compute;
