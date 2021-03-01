****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_tableofcontents.sas  
* Created (mm/dd/yyyy): 02/09/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro createas a dataset with 1 row per table and figure that is used as the 
*          report table of contents
*                                        
*  Program inputs:                                                                                   
*
*  Program outputs:          
*   -tableofcontents: dataset containing table of contents 
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

%macro create_tableofcontents();

    %put =====> MACRO CALLED: create_tableofcontents;

    /*********************************************************************************************/
    /* Utility macro to add row to tableofcontents file                                          */
    /*********************************************************************************************/
    %macro addtotoc(tabnum=, caption=);
    data tableofcontents;
        set tableofcontents end=eof;
        output;
        if eof then do;
            tabnum = "&tabnum.";
            caption = "&caption.";
            output;
        end;
    run;
    %mend;

    /*********************************************************************************************/
    /* Initialize empty table and table number                                                   */
    /*********************************************************************************************/
    data tableofcontents;
        length tabnum $25 caption $500;
        call missing(tabnum, caption);
    run;

    %let number = 1;

    /*********************************************************************************************/
    /* Build table of contents                                                                   */
    /*********************************************************************************************/

    /*****************/
    /* Glossary rows */
    /*****************/
    
        *tbd;

    /******************/
    /* Baseline Table */
    /******************/
    
    %if %eval(&numbaselinetablegrp.>0) %then %do;

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
            %macro baselinetoc(table);
                %if %eval(&unique_psestimate.) = 1 %then %do;
                 %tableletter(); 
                 %addtotoc(tabnum=Table 1&tableletter., 
                 caption=%quote(&unadjusted.Baseline Characteristics of &captionlabel. (&table.) in the Sentinel Distributed Database from &startdateformatted. to &&enddate&periodid.formatted.));
                %end;

                /*For L2 tables - up to 2 additional adjusted tables*/
                %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                    /*PS Match Adjusted*/
                    %if &psfile. = psmatchfile %then %do;
                    %tableletter(); 
                    %addtotoc(tabnum=Table 1&tableletter., 
                    caption=%quote(Adjusted Baseline Characteristics of &grouplabel. (Propensity Score Matched, &table.), &ratiolabel.&caliperlabel., in the Sentinel Distributed Database from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;

                    /*Unweighted - IPTW and PS Stratum*/
                    %if (&psfile. = iptwfile & %eval(&unique_psestimate.) = 1) | (&psfile. = stratificationfile & ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") & %eval(&pstrim.>=0)) %then %do;
                    %tableletter(); 
                    %addtotoc(tabnum=Table 1&tableletter., 
                     caption=%quote(Unweighted Baseline Characteristics of &grouplabel. (Unweighted, Trimmed, &table.) in the Sentinel Distributed Database from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;

                    /*Weighted - IPTW, PS Stratum, PS Stratification*/
                    %if &psfile. = iptwfile | &psfile. = stratificationfile %then %do;
                        %if &psfile. = iptwfile %then %let stratumtitle = (Inverse Probability of Treatment Weighted, Trimmed, &table.), Weight: &weightlabel., Truncation: &truncationlabel.;
                        %else %if "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %let stratumtitle = (Propensity Score Stratum Weighted, Trimmed, &table.), Percentiles: &percentiles., Weight: &weightlabel.;
                        %else %let stratumtitle =(Propensity Score Stratified, &table.), Percentiles: &percentiles.;
                        %tableletter(); 
                        %addtotoc(tabnum=Table 1&tableletter., 
                        caption=%quote(Weighted Baseline Characteristics of &grouplabel. &stratumtitle., in the Sentinel Distributed Database from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;
                %end; /*Additional L2 tables*/
            %mend;

            /*loop through each periodid*/
            %do periodid = %eval(&look_start.) %to %eval(&look_end.);
                /*Aggregated*/
                %baselinetoc(Aggregated);
       
                /*Output seperate table for each Data Partner - loop through each DP*/
                %if &stratifybydp. = Y %then %do;    
                    %do dps = 1 %to %eval(&num_dp.);
        		        %let maskedID = %scan(&masked_dplist,&dps); 
                        %if %eval(&unique_psestimate.) = 1 %then %do;
                            %baselinetoc(&maskedid.);
                        %end;
                    %end;
                %end; /*DP stratification*/
            %end; /*loop through each periodid*/
        %end; /*loop through each row in baselinefile*/
    %end; /*include baseline tables in toc*/

  /*********************************************************************************************/
  /*   Figures                                                                                 */
  /*********************************************************************************************/  

    %isdata(dataset=figurefile);
    %if %eval(&nobs.>0) %then %do;

        %let figurenum = 1; /* Add +1 for additional figure types that are requested */
        %let tablecount = 1;

        /*F2: Forest Plots*/
        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 and %sysfunc(prxmatch(m/F2/i,&figurelist.)) > 0 %then %do;

        %if %sysfunc(prxmatch(m/T2L2/i,&reporttype.)) > 0 %then %let ForestRatioTitle = Hazard Ratios (HR);
        %else %let ForestRatioTitle = Odds Ratios (OR);

        %do j = %eval(&look_start) %to %eval(&look_end);
            %do plot = 1 %to 7;
            %let forest_title = ;
            data _null_;
            set forest_&j(where=(plotorder=&plot));
              call symputx("forest_title",forest_title);
            run;

            %if %length(&forest_title) > 0 %then %do;
            %tableletter();
            %addtotoc(tabnum=Figure &figurenum.&tableletter.,
            caption=%quote(Figure &figurenum.&tableletter.. Forest Plot of &ForestRatioTitle and 95% Confidence Intervals (CI) for &forest_title))
            %end; /* Forest title exists */
            %end; /* loop plots */
        %end; /* loop periods */

        %end; /*Forest plots */

    %end; /* Figure file */

    /*********************/
    /* Remove empty rows */
    /*********************/
    data tableofcontents;
       set tableofcontents;
       if missing(tabnum)=0;
    run;

    %put =====> END MACRO: create_tableofcontents ;

%mend create_tableofcontents;
