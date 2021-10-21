****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_createdata_t6.sas  
* Created (mm/dd/yyyy): 10/20/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro aggregates censoring table data for type6
*                                        
*  Program inputs:   
*   - agg_t6censor.sas7bdat                                                                                
*   - agg_switchplota.sas7bdat
*   - agg_switchplotb.sas7bdat  
*   
*  Program outputs:             
*   - [table].sas7bdat
*
*  PARAMETERS:
*   - table: table ID from tablefile
*   - censordataset: input dataset
*   - censorreason: list of censor reasons from tablefile
*   - levelid: levelid1 from tablefile
*   - groupvar: variable used to differentiate groups (group or analysisgrp)
*   - dayvar: variable used to indicate each day
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

%macro censortable_createdata_t6(table=, censordataset=, censorreason=, levelid=, groupvar=, dayvar=);

    %put =====> MACRO CALLED: censortable_createdata_t6;

    /*--------------------------------------------------------------------------------------------*/
    /* Dataset exists                                                                             */
    /*--------------------------------------------------------------------------------------------*/
    %isdata(dataset=&censordataset.);
    %if %eval(&nobs.>0) %then %do;
    
    /*--------------------------------------------------------------------------------------------*/
    /* Aggregate data across all DPs and stack DP data                                            */
    /*--------------------------------------------------------------------------------------------*/

    proc means data=&censordataset.(where=(level="&levelid")) noprint nway;
        var &censorreason.;
        class &groupvar. &dayvar. / missing;
        output out=sum_censor(drop=_:) sum=;
    run;

    %if &stratifybydp. = Y %then %do;
        data sum_censor;
            set &censordataset.(where=(level="&levelid") keep=&censorreason. &groupvar. &dayvar. dpidsiteid)
                sum_censor(in=a);
                if a then dpidsiteid = 'ALL';
        run;
    %end;

    /*--------------------------------------------------------------------------------------------*/
    /* Statistics for each censor reason                                                          */
    /*--------------------------------------------------------------------------------------------*/

    %do cr =1 %to %sysfunc(countw(&censorreason.));
        %let reason = %scan(&censorreason., &cr.);

        proc means data=sum_censor nway missing noprint ;
            var &dayvar.;
            class &groupvar. %if &stratifybydp. = Y %then %do; dpidsiteid %end; ;
            freq &reason.;
            output out=_censor&cr.(drop = _:) N = n
                                              mean = mean 
                                              std = std
                                              min = min
                                              p1  = p1
                                              p5  = p5
                                              p10 = p10
                                              p25 = p25
                                              median = median 
                                              q3 = p75
                                              p90 = p90
                                              p95 = p95
                                              p99 = p99
                                              max = max;
        run;

        %if %eval(&cr.=1) %then %do;
            data _stacked;
                set _censor&cr.;
                %if &stratifybydp. = N %then %do;
                length dpidsiteid $6;
                dpidsiteid = 'ALL';
                %end;
                length censorreason $32.;
                censorreason = "&reason.";
            run;
        %end;
        %else %do;
            data _stacked;
                set _stacked _censor&cr.(in=a);
                if a then do;
                %if &stratifybydp. = N %then %do;
                length dpidsiteid $6;
                dpidsiteid = 'ALL';
                %end;
                length censorreason $32.;
                censorreason = "&reason.";
                end;
            run;
         %end;
    %end; /*loop through each censor reason*/

    /*--------------------------------------------------------------------------------------------*/
    /* Missing value indicators and format variables                                              */
    /*--------------------------------------------------------------------------------------------*/

    /*total count in cohort*/

    data output._stacked&table.; set _stacked; run;


    /*--------------------------------------------------------------------------------------------*/
    /* Apply labels and sort                                                                      */
    /*--------------------------------------------------------------------------------------------*/


    /*--------------------------------------------------------------------------------------------*/
    /* Clean up                                                                                   */
    /*--------------------------------------------------------------------------------------------*/

    proc datasets lib=work nowarn nolist noprint;
       delete sum_censor;
    quit;



    %end; /*dataset exists*/

    proc datasets lib=work nowarn nolist noprint;
       delete _censor_tablefile ;
    quit;

   %put =====> END MACRO: censortable_createdata_t6;

%mend censortable_createdata_t6;
