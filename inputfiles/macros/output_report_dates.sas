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
*    Two macro variables:
*     - startdateformatted
*     - enddateformatted 
*
*  PARAMETERS:                                                                       
*            
*  Programming Notes:          
*   The algorithm for determining each date:
*     - The query period start date is equal to the startdate parameter from the monitoring file
*     - The query period end date is the max of all DP end dates. Except when FUPENDDATE is populated
*       and FUPENDDATE is earlier than the max of the DP end dates
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

    proc sql noprint;
        select min(startdate) into: minstartdate
        from _monitoring;
        select max(fupenddate) into: maxfupenddate
        from _monitoring
        where missing(fupenddate)=0;
    quit;

    /*Assign final formatted dates*/
    data _null_;
        call symputx('startdateformatted', put(&minstartdate.,WORDDATE.));
        call symputx('enddateformatted', put(min(&maxfupenddate.,&maxdpenddate.) ,WORDDATE.));
        call symputx('enddate', min(&maxfupenddate.,&maxdpenddate.));
    run;

    /*Assign min and max years*/
    %let minqueryyear = %sysfunc(year(&minstartdate.));
    %let maxqueryyear = %sysfunc(year(&enddate.));

    %put study start date = &startdateformatted.;
    %put study end date = &enddateformatted.;

    proc datasets nowarn noprint lib=work;
        delete _monitoring;
    quit;

    %put =====> MACRO ENDED: output_report_dates ;

%mend output_report_dates;
