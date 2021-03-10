****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_output.sas  
* Created (mm/dd/yyyy): 03/10/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of Baseline Characteristics Tables proc report output
*                                        
*  Program inputs:                                                                                   
*   - table1_&periodid.
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:                                                                       
*            
*  Programming Notes:         
*   Utility macro %baseline_procreport created to execute the proc report for each baseline table 
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro baseline_output();

    %put =====> MACRO CALLED: baseline_output;

    %if %eval(&numbaselinetablegrp.>0) %then %do;

    /*********************************************************************************************/
    /*   proc report                                                                             */
    /*********************************************************************************************/  

    %macro baseline_procreport(characteristiclabel =,
                               grp1_label=, grp1_var1=, grp1_var2=, 
                               grp2_label=, grp2_var1=, grp2_var2=, 
                               grp3_label=, grp3_var1=, grp3_var2=,
                               computebalance = );

/*        %if &destination. = excel %then %do;*/
        ods excel options(sheet_name="Table 1&tableletter." tab_color = "lightgreen");
/*        %end;*/
        ods proclabel = "Table 1&tableletter.";
/*        proc report data=repdata.table1&tableletter. nofs nowd spanrows split='*'*/
/*            style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'*/
/*		    style(report)=[rules=none frame=box cellpadding =1.75pt];*/
/**/
/*        run;*/
    %mend;


        /*counter for determining table letter*/
        %let tablecount = 1;

        /*loop through each baseline table*/
        %do b = 1 %to &numbaselinetablegrp.;
            %let analysisgrp = ;
            %let analysisgrp2 = ;
            %let baselinegroupnum = ;
            %let pregnancylabel = ;
            %let includenonpregnant = N;

            /*for L2 tables - need to reference PS/CS specific files to pull additional parameters*/
            %let ratio = F;
            %let psfile = ;
            %let weightlabel = ;
            %let weightscheme = ;
            %let pstrim = ;
            %let percentiles=;
            %let ratiolabel = ;
            %let caliperlabel = ;
            %let truncationlabel = ;
            %let psestimategrp = ;
            %let unadjusted = ;

            data _null_;
                set baselinefile(where=(order=&b.));
                if _n_ = 1 then do;
                    call symputx('analysisgrp', analysisgrp);
                    call symputx('runid', runid);
                    call symputx('cohort', cohort);
                    call symputx('unique_psestimate',unique_psestimate);
                    %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
                    if cohort in ('preg', 'nopreg') then do;
                        if upcase(includenonpregnant) = 'Y' then call symput('pregnancylabel', ' Pregnancy Cohort and Non-Pregnancy Cohort');
                        else call symput('pregnancylabel', ' Pregnancy Cohort');
                    end;
                    call symputx('includenonpregnant', upcase(includenonpregnant));
                    %end;
                    if missing(baselinegroupnum)=0 then call symputx('baselinegroupnum', baselinegroupnum);
                end;
                /*if baselinegroupnum is specified, a 2nd row will exist in the file*/
                if _n_ = 2 then do;
                    if missing(baselinegroupnum)=0 then do;
                        call symputx('analysisgrp2',analysisgrp);
                    end;
                end;
            run;
         
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            data _null_;
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp." and covarnum=0));
                call symputx('psfile', strip(file));
                call symputx('psestimategrp', psestimategrp);
                call symput('unadjusted', 'Unadjusted '); /*for unadjusted table label*/

                if file = 'psmatchfile' then do;
                    call symputx('ratio',upcase(ratio));
                    if upcase(ratio)='F' then call symputx("ratiolabel",'Fixed Ratio 1:'||strip(put(ceiling, 8.)));
                    if upcase(ratio)='V' then call symputx("ratiolabel",'Variable Ratio 1:'||strip(put(ceiling, 8.)));
                    call symputx("caliperlabel", cat(', Caliper: ', caliper));
                end;
                if file = 'stratificationfile' then do;
                    call symputx('pstrim', pstrim);
                    call symputx('percentiles', percentiles);
                    if missing(strataweight) =0 then call symputx('weightscheme', strataweight);
        	        if upcase(strataweight)= 'ATE' or missing(strataweight) then call symputx("weightlabel","Average Treatment Effect (ATE)");
                    else if upcase(strataweight)= 'ATT' then call symputx("weightlabel","Average Treatment Effect in the Treated (ATT)");
                end;
                if file = 'iptwfile' then do;
                    if upcase(ipweight)= 'ATE' then call symputx("weightlabel","Average Treatment Effect (ATE)");
                    else if upcase(ipweight)= 'ATES' then call symputx("weightlabel","Average Treatment Effect, Stabilized (ATES)");
                    else if upcase(ipweight)= 'ATT' then call symputx("weightlabel","Average Treatment Effect in the Treated (ATT)");
                    call symputx('truncationlabel',strip(put(truncweight, best.))||'%');
                end;
            run;
            %end;

            /*determine if only 1 baseline table and set &tablecount to 0. Will occur if all the following are true:
            - 1 monitoring period
            - DP stratification = N
            - max(order) in baselinefile = 1
            - if reporttype = T2L2/T4L2 - then analysis must be covariate stratification*/
            %if %eval(&b.=1) & %eval(&look_start.) = %eval(&look_end.) & &stratifybydp. = N & %eval(&numbaselinetablegrp.=1) %then %do;
                %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) = 0 %then %do;
                    %let tablecount = 0;
                %end;
                %else %do;
                    %if &psfile. = covstratfile %then %let tablecount = 0;
                %end;
            %end;

            /*Assign labels*/
            %let baselinelabel = ;
            %let grouplabel = &analysisgrp.;
            %let psestimatelabel = &psestimategrp.;
            %if %length(&baselinegroupnum.)>0 %then %do;
            %let grouplabel2 = &analysisgrp2.;
            %end;

            %isdata(dataset=labelfile);
            %if %eval(&nobs.>0) %then %do;
                data _null_;
                    set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid"))
                        %if %length(&baselinegroupnum.)>0 %then %do;
                        labelfile(in=b where=(group="&analysisgrp2" and runid = "&runid"))
                        %end; 
                        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                        labelfile(in=c where=(group="&psestimategrp" and runid = "&runid"))
                        %end; 
                        %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
                        labelfile(in=d where=(group="&" and runid = "&runid"))
                        labelfile(in=e where=(group="&" and runid = "&runid"))
                        labelfile(in=f where=(group="&" and runid = "&runid"))
                        %end; ;


                    if a then do;
                        if labeltype = 'grouplabel' then call symputx('grouplabel',label);
                        if labeltype = 'baselinelabel' then call symputx('baselinelabel',cat(', ',strip(label), ','));
                    end;
                    %if %length(&baselinegroupnum.)>0 %then %do;
                    if b then do;
                        if labeltype = 'grouplabel' then call symputx('grouplabel2',label);
                    end;
                    %end;
                    %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 & &psfile. ne covstratfile %then %do;
                    if c then do;
                        if labeltype = 'grouplabel' then call symputx('psestimatelabel',label);
                    end;
                    %end;
                run;
            %end;

            %let captionlabel = %bquote(&grouplabel.&pregnancylabel&baselinelabel.);
            %if %length(&baselinegroupnum.)>0 %then %do;
            %let captionlabel = %bquote(&grouplabel.&pregnancylabel and &grouplabel2.&pregnancylabel&baselinelabel.);
            %end;
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) >0 & &psfile. ne covstratfile %then %do;
            %let captionlabel = %bquote(&psestimatelabel.);
            %end;         

            /*1 block of code for both aggregate and DP tables*/
            %macro baselinereport(table);
                %if %eval(&unique_psestimate.) = 1 %then %do;
                 %tableletter(); 
                 %baseline_procreport()
                %end;

                /*For L2 tables - up to 2 additional adjusted tables*/
                %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                    /*PS Match Adjusted*/
                    %if &psfile. = psmatchfile %then %do;
                    %tableletter(); 
                    %baseline_procreport()
                    %end;

                    /*Unweighted - IPTW and PS Stratum*/
                    %if (&psfile. = iptwfile & %eval(&unique_psestimate.) = 1) | (&psfile. = stratificationfile & ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") & %eval(&pstrim.>=0)) %then %do;
                    %tableletter(); 
                    %baseline_procreport()
                    %end;

                    /*Weighted - IPTW, PS Stratum, PS Stratification*/
                    %if &psfile. = iptwfile | &psfile. = stratificationfile %then %do;
                        %if &psfile. = iptwfile %then %let stratumtitle = (Inverse Probability of Treatment Weighted, Trimmed, &table.), Weight: &weightlabel., Truncation: &truncationlabel.;
                        %else %if "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %let stratumtitle = (Propensity Score Stratum Weighted, Trimmed, &table.), Percentiles: &percentiles., Weight: &weightlabel.;
                        %else %let stratumtitle =(Propensity Score Stratified, &table.), Percentiles: &percentiles.;
                        %tableletter(); 
                        %baseline_procreport()
                    %end;
                %end; /*Additional L2 tables*/
            %mend;

            /*loop through each periodid*/
            %do periodid = %eval(&look_start.) %to %eval(&look_end.);
                /*Aggregated*/
                %baselinereport(Aggregated);
       
                /*Output seperate table for each Data Partner - loop through each DP*/
                %if &stratifybydp. = Y %then %do;    
                    %do dps = 1 %to %eval(&num_dp.);
        		        %let maskedID = %scan(&masked_dplist,&dps); 
                        %if %eval(&unique_psestimate.) = 1 %then %do;
                            %baselinereport(&maskedid.);
                        %end;
                    %end;
                %end; /*DP stratification*/
            %end; /*loop through each periodid*/
        %end; /*loop through each row in baselinefile*/
    %end; /*include baseline tables */

    %put =====> END MACRO: baseline_output ;

%mend baseline_output;
