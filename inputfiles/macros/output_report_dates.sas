****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: output_report_dates.sas  
* Created (mm/dd/yyyy): 11/30/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates a formatted start and end date to use in report titles
*
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*    Three or more macro variables:
*     - startdateformatted
*     - enddateformatted 
*     - enddate1formatted - enddate&nformatted
*
*
*  PARAMETERS:                                                                       
*            
*  Programming Notes:          
*   The algorithm for determining each date:
*     - The query period start date is equal to the startdate parameter from the monitoring file
*     - The query period end date is the max of all DP end dates. Except when FUPENDDATE is populated
*       and FUPENDDATE is earlier than the max of the DP end dates
*     - The query period end date is also calculated for each monitoring period, which can either be
*       the FUPENDDATE of that period when populated, or the max of all DP end dates.
*. 
*
*   Both dates are formatted to "Month Day, Year" - January 1, 2010
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro output_report_dates();

    %put =====> MACRO CALLED: output_report_dates ;

    /*Determine the max DP End Date*/
    proc sql noprint;
        select max(input(dpmaxdate,date9.)) into: maxdpenddate
        from output.dpinfo;
    quit;
    %put maximum dp_maxdate: &maxdpenddate;

    /*Determine minimum start date and maximum FUPENDDATE from all monitoring files*/
    data _monitoring;
        set 
        %do r=1 %to &numrunid.;
            %let runid = %scan(&runidlist., &r.);
            infolder.&&&runid._monitoringfile(where=(periodid>=&look_start. and periodid<=&look_end.))
        %end;
        ;
    run;

    /* Check if more than one run (monitoring file) specified */
    %if &numrunid > 1 and %eval(&look_end-&look_start) > 0 %then %do;

    /* Check if dates are unique across monitoring files */
    proc sort data = _monitoring out=_monitoring_dups uniqueout=_monitoring_unique nouniquekey;
        by startdate fupenddate;
    run;

    %isdata(dataset=_monitoring_unique);
    %if %eval(&nobs) > 0 %then %do;
    %put ERROR: (Sentinel) You cannot use different monitoring files with more than one period;
    %abort;
    %end;

    %end;

    /* loop through looks */
    %do n = &look_start %to &look_end;
    %global enddate&n.formatted;

    proc sql noprint;
        select min(startdate) into: minstartdate
        from _monitoring;
        select max(fupenddate) into: maxfupenddate
        from _monitoring
        where missing(fupenddate)=0 and periodid=&n;
    quit;

    /*Assign final formatted dates*/
    data _null_;
        call symputx('startdateformatted', put(&minstartdate.,WORDDATE.));
        call symputx('enddateformatted', put(min(&maxfupenddate.,&maxdpenddate.) ,WORDDATE.));
        call symputx("enddate&n.formatted", put(min(&maxfupenddate.,&maxdpenddate.) ,WORDDATE.), 'G');
        call symputx('enddate', min(&maxfupenddate.,&maxdpenddate.));
    run;

    /*Assign min and max years*/
    %let minqueryyear = %sysfunc(year(&minstartdate.));
    %let maxqueryyear = %sysfunc(year(&enddate.));

    %put study start date = &startdateformatted.;
    %put study end date for period &n = &&enddate&n.formatted.;

    %end;

    /*Add DPENDDATE to output.dpinfo as the earliest of: DPMAXDATE and Query End Date*/
    data output.dpinfo(rename=dpmindate1=dpmindate);
        set output.dpinfo;
        format dpenddate dpmindate1 $10.;
        dpenddate = put(min(&maxfupenddate., input(dpmaxdate,date9.)), mmddyy10.);
        /*format dpmindate*/
        dpmindate1 = put(input(dpmindate,date9.), mmddyy10.);
        drop dpmindate;
    run;

    proc datasets nowarn noprint lib=work;
        delete _monitoring:;
    quit;

    %put =====> MACRO ENDED: output_report_dates ;

%mend output_report_dates;
