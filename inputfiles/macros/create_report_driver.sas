****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_report_driver.sas  
* Created (mm/dd/yyyy): 01/29/2025
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of all QRP reports
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

%macro create_report_driver();

***************************************************************************************************;
* Initialize global macro variables and librairies, and read in REPORT_PARAMETERS input file                                  
***************************************************************************************************;

    %put =====> MACRO CALLED: create_report_driver;
	
	%isdata(dataset=input.report_parameters);
    %if %eval(&nobs<1) %then %do;
        %put ERROR: (Sentinel) REPORT_PARAMETERS file is missing. Make sure file placed in the inputfiles folder;
        %abort;
    %end;

	/*Count number of reports and parameters*/
	proc contents data=input.report_parameters noprint out=report_param_content;
	quit;

	proc sql noprint;
    select count(*) into: numreports
    from report_param_content
    where substr(upcase(name),1,6) = 'REPORT';

    select count(*) into: numreportparams
    from input.report_parameters;
    quit;

	%global reportid reportdata database logofile ReportType small_cellcounts customizecolumns stratifybyDP seed groupsfile 
            baselinefile tablefile figurefile labelfile itsregressionfile treeaggfile appendixfile CodeDescriptionsFile TableColumnsFile
            DPInfoFile L2ComparisonFile look_start look_end DateDistributed report_destination collapse_vars include_unweighted_trim;

	%do reportrun = 1 %to %eval(&numreports.);

        /*Reset all parameters*/		        
		%let reportid = &reportrun.;
		%let logofile = ;
		%let reportdata = Y;
		%let database = ;
		%let ReportType= ;
	    %let small_cellcounts = ;
	    %let customizecolumns =;
	    %let stratifybyDP = ;
	    %let seed = ;
	    %let groupsfile = ;
	    %let baselinefile = ;
	    %let tablefile = ;
	    %let figurefile = ;
	    %let labelfile = ;
	    %let itsregressionfile = ;
	    %let treeaggfile = ;
	    %let appendixfile = ;    
	    %let CodeDescriptionsFile = ;
	    %let TableColumnsFile = ;
	    %let DPInfoFile = ;
	    %let L2ComparisonFile = ;
	    %let look_start = 1;
	    %let look_end = 1;
	    %let datedistributed = ;
	    %let report_destination = ;
		%let collapse_vars = ;
		%let include_unweighted_trim= N;	

        /*Assign all parameters to macro variables*/
        %do reportparameter = 1 %to %eval(&numreportparams.);
            data _null_;
            set input.report_parameters;
            if _n_ = &reportparameter. then do;
                call symputx("parameter", parameter);
                call symputx("value", report&reportrun.);
                /*defensive*/
                if lowcase(parameter) in ('reporttype','stratifybydp','small_cellcounts','report_destination', 'include_unweighted_trim') then call symputx("value",upcase(report&reportrun.));
                if lowcase(parameter) in ('customizecolumns', 'collapse_vars') then call symputx("value",lowcase(report&reportrun.));
                /*default report_destination is both*/
                if lowcase(parameter) = 'report_destination' and missing(report&reportrun.) then call symputx("value","BOTH");
                /*default stratifybydp*/
                if lowcase(parameter) = 'stratifybydp' and missing(report&reportrun.) then call symputx("value","N");
				/*default include_unweighted_trim*/
                if lowcase(parameter) = 'include_unweighted_trim' and missing(report&reportrun.) then call symputx("value","N");
                /*add parenthesis for datedistributed*/
                if lowcase(parameter) in ('datedistributed') and missing(report&reportrun.)=0 then do;
                    tempvalue = input(report&reportrun.,ANYDTDTE32.); /*convert to SAS date*/
                    if missing(tempvalue) = 0 then do;
                        call symputx("value",cats('(', strip(put(tempvalue, worddate20.)), ')'));
                    end;
                    else do;
                        call symputx("value",cats('(', strip(report&reportrun.), ')'));
                    end;
                end;
            end;
            run;

            %let &parameter. = &value.;	
        %end;
	
		/* Add underscore for report id */
		%let reportid = _&reportid.;
		%if &reportid=_ %then %do;
		 	%let reportid=;
			%if &numreports. > 1 %then %do;
			%put WARNING: (Sentinel) More than one report is requested in REPORT_PARAMETERS and reportid is not specified for report number &reportrun..;
			%end;
		%end;

		/* Create reportdata and msocdata folders */
		%let repdata = &output.reportdata&reportid.;
		%let msocdata = &output.msocdata&reportid.;
		options DLCREATEDIR ;
		libname repdata "&repdata" ;
		libname msocdata "&msocdata" ;
		options NODLCREATEDIR;

		/* Create current report */
		%create_report();
	%end;	

	/*************************************************************************************************/
	/* Run log checker                                                                               */
	/*************************************************************************************************/
	
    proc printto log="&output.log_checker.log" new;
    run;

	%ms_logchecker(logdir =&output., logdir_out=output);

	/* End log */
    proc printto;
    run;	
	
    %put =====> END MACRO: create_report_driver ;

%mend create_report_driver;
