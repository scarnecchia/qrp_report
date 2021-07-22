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
        1) F1: t2followuptime = Kaplan-Meier Estimate of Event of Interest Not Occurring
        2) F2: t2followuptime = Reasons for End of Follow-Up by Group (1-CDF)
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

    /*Assign user censoring criteria labels*/
    %isdata(dataset=labelfile);
    %if %eval(&nobs.>0) %then %do;
        data _null_;
            set labelfile(where=(labeltype='censorlabel'));
            call symputx(cats(labelvar,'_label'), label);
        run;
    %end;

    /*Square groups*/
    proc sql noprint;
        create table _squaregroup as
        select group, runid, 0 as day
        from groupsfile
        order by runid, group;
    quit;

    /*loop through each figure*/
    %do f = 1 %to %sysfunc(countw(&figurelist.));
        %let figure = %scan(&figurelist., &f.);

        data _null_;
            set figurefile(where=(figure="&figure"));
            call symputx('levelid1', levelid1);
            call symputx('censordisplay', censordisplay);

            /*Assign dataset*/
            if dataset = 't1censor' then call symputx('dataset', 'agg_t1censor');
            else if dataset = 't2censor' then call symputx('dataset', 'agg_t2censor');
            else if dataset = 't2followuptime' then call symputx('dataset', 'agg_t2followuptime');
            else if dataset = 't5censor' then call symputx('dataset', 'agg_t5censor');

            /*Assign figure to produce*/
            if dataset='t2followuptime' and figure = 'F1' then call symputx('curve', 'KM');
            else call symputx('curve', 'CDF');

            /*Determine whether to transpose dataset from stacked by group to a wide dataset*/
            if (dataset='t2followuptime' and figure = 'F1') | (dataset='t5censor' and figure = 'F5') then call symputx('transposedata', 'Y');
            else call symputx('transposedata', 'N');
        run;
            
        %if &reporttype. = T1 | &reporttype. = T2L1 %then %do;
        %figure_cdf_km_createdata(dataset=&dataset., 
                                  curve=&curve., 
                                  whereclause=%str(level = "&levelid1." and group in (&includegroupinfigure)), 
                                  dayvar=censdays_value,
                                  includegroups=&includegroupinfigure.,
                                  includevars=&censordisplay.,
                                  transposedata=&transposedata.,
                                  figure = &figure.);
        %end;
        %else %if &reporttype. = T5 %then %do;
            /*Figure F5 selects 1 censoring reason from F4, so if figuref4 exists and 
              censoring reason selected in F4 then can subset that dataset, else need to execute %figure_cdf_km_createdata()*/
            %isdata(dataset=figuref4); /*will only exist if F4 has been created*/
            %if %eval(&nobs.>0) %then %do;
                %let censordisplayf4 = ;
                data _null_;
                    set figurefile(where=(figure="F4"));
                    call symputx('censordisplayf4', censordisplay);
                run;

                %if %index(&censordisplayf4., &censordisplay.)>0 %then %do;
                    data figure&figure.;
                        set figuref4;
                        %do g = 1 %to %sysfunc(countw(&includegroupinfigure.));
                            if group = %scan(&includegroupinfigure., &g.) then groupnum = &g.;
                        %end;
                        keep day group: episodes_atrisk: cdf_&censordisplay.;
                    run;
                    %let transposedata = T;
                %end;

                %goto createfigure;
            %end;
            %else %do;
                %createfigure:
                %figure_cdf_km_createdata(dataset=&dataset., 
                                      curve=&curve., 
                                      whereclause=%str(level = "&levelid1." and group in (&includegroupinfigure) and episodenum = 1), 
                                      dayvar=episodelength,
                                      includegroups=&includegroupinfigure.,
                                      includevars=&censordisplay.,
                                      transposedata=&transposedata.,
                                      figure = &figure.);
            %end;
        %end; /*T5*/

    %end; /*loop through figures*/

    proc datasets nowarn noprint lib=work;
        delete _squaregroup;
    quit;

    %end; /*figurefile exists*/

    %put =====> END MACRO: figure_l1_driver ;

%mend figure_l1_driver;
