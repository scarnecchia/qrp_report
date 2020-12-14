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

%macro baseline_compute(reporttype=, numbaselinetablegrp=, num_dp=, stratifybydp=, periodid=);

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
            end;
        run;

        /*for L2 tables - need to reference PS/CS specific files to pull additional parameters*/
        %let ratio = F;
        %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
            data _null_;
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp."));
                if file = 'psmatchfile' then call symputx('ratio',upcase(ratio));
            run;
       %end;


    %end; /*loop through each baseline group*/






					
    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete :;
    quit;
    
	%put =====> END MACRO: baseline_compute;

%mend baseline_compute;
