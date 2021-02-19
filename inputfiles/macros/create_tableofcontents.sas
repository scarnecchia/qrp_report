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
            tabnum = &tabnum.;
            caption = &caption.;
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

        /*determine if only 1 baseline table and set &tablecount to 0. Will occur if all the following are true:
            - 1 monitoring period
            - DP stratification = N
            - max(order) in baselinefile = 1
            - if reporttype = T2L2/T4L2 - then analysis must be covariate stratification*/
        %if %eval(&look_start.) = %eval(&look_end.) & &stratifybydp. = N & %eval(&numbaselinetablegrp.=1) & %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) = 0 %then %do;
            %let tablecount = 0;
        %end;
        %else %if %eval(&look_start.) = %eval(&look_end.) & &stratifybydp. = N & %eval(&numbaselinetablegrp.=1) & %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            
        %end;

        /*loop through each baseline table*/
        %do b = 1 %to &numbaselinetablegrp.;
            %let analysisgrp = ;
            %let analysisgrp2 = ;
            %let baselinegroupnum = ;
            %let pregnancylabel = ;
            %let includenonpregnant = N;

            data _null_;
                set baselinefile(where=(order=&b.));
                if _n_ = 1 then do;
                    call symputx('analysisgrp', analysisgrp);
                    call symputx('runid', runid);
                    call symputx('cohort', cohort);
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

            /*Assign labels*/
            %let baselinelabel = ;
            %let grouplabel = &analysisgrp.;
            %if %length(&baselinegroupnum.)>0 %then %do;
            %let grouplabel2 = &analysisgrp2.;
            %end;

            %isdata(dataset=labelfile);
            %if %eval(&nobs.>0) %then %do;
                data _null_;
                    set labelfile(in = a where=(group="&analysisgrp" and runid = "&runid"))
                        %if %length(&baselinegroupnum.)>0 %then %do;
                        labelfile(in =b where=(group="&analysisgrp2" and runid = "&runid"))
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
                run;
            %end;

            %let captionlabel = &grouplabel.&pregnancylabel&baselinelabel.;
            %if %length(&baselinegroupnum.)>0 %then %do;
            %let captionlabel = &grouplabel.&pregnancylabel and &grouplabel2.&pregnancylabel&baselinelabel.;
            %end;

            /*loop through each periodid*/
            %do periodid = %eval(&look_start.) %to %eval(&look_end.);

                %tableletter();                             
                %addtotoc(tabnum="Table 1&tableletter.", 
                 caption="Baseline Characteristics of &captionlabel. (Aggregated) in the Sentinel Distributed Database from &startdateformatted. to &&enddate&periodid.formatted.");

                /*Output seperate table for each Data Partner - loop through each DP*/
                %if &stratifybydp. = Y %then %do;    
                    %do dps = 1 %to &numrunid.;
    		         %let maskedID = %scan(&masked_dplist,&dps); 
                     %tableletter();                             
                     %addtotoc(tabnum="Table 1&tableletter.", 
                      caption="Baseline Characteristics of &captionlabel. (&maskedid.) in the Sentinel Distributed Database from &startdateformatted. to &&enddate&periodid.formatted.");
                    %end;
                %end; /*DP stratification*/
            %end; /*loop through each periodid*/
        %end; /*loop through each row in baselinefiel*/
    %end; /*include baseline tables in toc*/







    /*********************/
    /* Remove empty rows */
    /*********************/
    data output.tableofcontents;
       set tableofcontents;
       if missing(tabnum)=0;
    run;

    %put =====> END MACRO: create_tableofcontents ;

%mend create_tableofcontents;
