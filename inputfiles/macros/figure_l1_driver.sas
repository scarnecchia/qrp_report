****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_l1_driver.sas  
* Created (mm/dd/yyyy): 07/14/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of L1 figures
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

%macro figure_l1_driver();

    %put =====> MACRO CALLED: figure_l1_driver;

    /**********************************************************************************************
     T1: 1 figure: 
        1) F1: t1censor = Reasons for End of Observable Data by Group (1-CDF)
     T2L1: 3 figures:
        1) F1: t2followuptime = Reasons for End of Follow-Up by Group (1-CDF)
        2) F2: t2followuptime = Kaplan-Meier Estimate of Event of Interest Not Occurring
        3) F3: t2censor = Reasons for End of Observable Data by Group (1-CDF)
     T5: 2 figures:
        1) F1 (not yet implemented)
        2) F2 (not yet implemented)
        3) F3 (not yet implemented)
        4) F4: t5censor = Reasons for End of First Treatment Episode by Group
        5) F5: t5censor = End of First Treatment Episode due to [Censoring Reason] by Group 
    /***********************************************************************************************/

    %isdata(dataset=figurefile);
    %if %eval(&nobs>0) %then %do;

    /*loop through each figure*/
    %do f = 1 %to %sysfunc(countw(&figurelist.));
        %let figure = %scan(&figurelist., &f.);

        data _null_;
            set figurefile(where=(figure="&figure"));
            call symputx('levelid1', levelid1);
            call symputx('censordisplay', censordisplay);

            /*Assign dataset*/
            if dataset = 't1censor' then call symputx('dataset', 'agg_t1censor');
            if dataset = 't2censor' then call symputx('dataset', 'agg_t2censor');
            if dataset = 't2followuptime' then call symputx('dataset', 'agg_t2followuptime');
            if dataset = 't5censor' then call symputx('dataset', 'agg_t5censor');

            /*Assign figure to produce*/
            if dataset='t2followuptime' and figure = 'F2' then call symputx('curve', 'KM');
            else call symputx('curve', '1-CDF');
        run;
            
        %if &reporttype. = T1 | &reporttype. = T2L1 %then %do;
        %figure_cdf_km_createdata(dataset=&dataset., 
                                  curve=&curve., 
                                  whereclause=%str(level = "&levelid1." and group in (&includegroupinfigure)), 
                                  dayvar=censdays_value,
                                  includegroups=&includegroupinfigure.,
                                  includevars=&censordisplay.,
                                  figure = &figure.);
        %end;
        %else %if &reporttype. = T5 %then %do;
            %if &figure. = F4 %then %do;
            %figure_cdf_km_createdata(dataset=&dataset., 
                                      curve=&curve., 
                                      whereclause=%str(level = "&levelid1." and group in (&includegroupinfigure) and episodenum = 1), 
                                      dayvar=episodelength,
                                      includegroups=&includegroupinfigure.,
                                      includevars=&censordisplay.,
                                      figure = &figure.);
            %end;
            %if &figure. = F5 %then %do;
                /*if figuref4 exists, can subset that dataset, else need to execute %figure_cdf_km_createdata()*/
                %isdata(dataset=figuref4);
                data _null_;
                    set figurefile(where=(figure="F4"));
                    call symputx('censordisplayf4', censordisplay);
                run;

                %if %eval(&nobs.>0) %then %do;

                %end;
                %else %do;


                %end;
           %end;
        %end; /*T5*/

    %end; /*loop through figures*/

    %end; /*figurefile exists*/

    %put =====> END MACRO: figure_l1_driver ;

%mend figure_l1_driver;
