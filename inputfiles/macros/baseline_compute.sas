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
                call symputx("total_unadjusted_exp_episodes", total_exp_episodes);

                %if "&includecomp" = "Y" %then %do;
        	        total_comp_episodes = sum(of comp_mean1-comp_mean&num_dp.);
                    call symputx("total_unadjusted_comp_episodes", total_comp_episodes); 
                %end;

                %do a = 1 %to &num_dp.;
                    call symputx("n_unadjusted_episodes_exp&a", exp_mean&a);  
                    %if "&includecomp" = "Y" %then %do;
                    call symputx("n_unadjusted_episodes_comp&a", comp_mean&a); 
                    %end;
                %end;
            end;

            /*Number of Patients*/
            else if metvar = 'PATIENT' then do;
    	        total_exp_patients = sum(of exp_mean1-exp_mean&num_dp.);
                call symputx("total_unadjusted_exp_patients", total_exp_patients); 

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
                    set &datain.(where=(upcase(metvar)='N_EPISODES' and table = "&table." and weight = "&weight" and order=&b.));
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

            data &dataout.;
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
                            - L2: 100% for unadjusted, compute % out of unadjusted totalfor adjusted tables;
                    if index(metvar, 'SEX') >0 | index(metvar, 'RACE') >0 | index(metvar, 'HISPANIC') >0 then do;
                        if ^missing(eoi_a) and (total_exp_patients gt 0) then eoi_b = eoi_a/total_exp_patients;
                        %if "&includecomp" = "Y" %then %do;
                        if ^missing(ref_a) and (total_comp_patients gt 0) then ref_b = ref_a/total_comp_patients;
                        %end;
                    end;
                    else if metvar in ('N_EPISODES', 'PATIENT') then do;
                        eoi_b = .;
                        ref_b = .;
                        %if "&table" = "Unadjusted" & %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
                            eoi_b = 1;
                            %if "&includecomp" = "Y" %then %do;
                            ref_b = 1;
                            %end;
                        %end;
                        %else %do; /*L2 only*/
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

                    drop exp_mean_num comp_mean_num exp_std_sum comp_std_sum;
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
            run;

        %mend baselinecomputemetrics;

        ***********************************************************************************************;
        * Compute aggregated tables                     
        ***********************************************************************************************;

        /*All - unweighted*/
        %baselinecomputemetrics(table=Unadjusted, weight=Unweighted, dataout=baseline_aggregatetab1);

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


        ***********************************************************************************************;
        * Stack and save final table                   
        ***********************************************************************************************;
        %if %eval(&b.=1) %then %do;
            data &dataout.;
                set baseline_aggregatetab:;
            run;
        %end;
        %else %do;
            data &dataout.;
                set &dataout. baseline_aggregatetab:;
            run;
        %end;

        /*Clean up*/
        proc datasets nowarn noprint lib=work;
            delete baseline_aggregatetab:;
        quit;
        

    %end; /*loop through each baseline group*/






					
   
	%put =====> END MACRO: baseline_compute;

%mend baseline_compute;
