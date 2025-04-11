****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_report_driver.sas  
* Created (mm/dd/yyyy): 01/29/2025
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of all QRP reports. It loops through all reports specified in 
*		   the report_parameters input file and calls the %create_report() macro for each one.
*                                        
*  Program inputs: 
*	- input.report_parameters
*
* 
*  Program outputs:  
* 	- dpinfofile if called from QRP to produce leave behind reports 
*	- all data produced by the %create_report() macro
* 
*  PARAMETERS:    
*	- leavebehindreport(Y/N) specify if leave behind report is produced or not 
*            
*  Programming Notes:  
*	- This program calls the %ms_logchecker macro that will process all the log files created 
*	  in the output folder at the same time
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro create_report_driver(leavebehindreport=N);

***************************************************************************************************;
* Initialize global macro variables and librairies, and read in REPORT_PARAMETERS input file                                  
***************************************************************************************************;

    %put =====> MACRO CALLED: create_report_driver;

	%if &leavebehindreport. eq N %then %do;
		%isdata(dataset=input.report_parameters);
	    %if %eval(&nobs<1) %then %do;
	        %put ERROR: (Sentinel) REPORT_PARAMETERS file is missing. Make sure file placed in the inputfiles folder;
	        %abort;
	    %end;
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

	proc datasets nowarn noprint lib=work;
		delete report_param_content;
	quit;


	%global reportid dpfile reportdata database logofile ReportType small_cellcounts customizecolumns stratifybyDP seed groupsfile 
            baselinefile tablefile figurefile labelfile itsregressionfile treeaggfile appendixfile CodeDescriptionsFile TableColumnsFile
            DPInfoFile L2ComparisonFile look_start look_end DateDistributed report_destination collapse_vars include_unweighted_trim;

	%do reportrun = 1 %to %eval(&numreports.);        
		%let reportdata = N;
		%let reportid = ;
		%let logofile = ;		
		%let database = ;
		%let dpname = ;
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
		
		%if &leavebehindreport. eq N %then %do;
			/* Create reportdata and msocdata folders */
			%let repdata = &output.reportdata&reportid.;
			%let msocdata = &output.msocdata&reportid.;
			options DLCREATEDIR ;
			libname repdata "&repdata" ;
			libname msocdata "&msocdata" ;
			options NODLCREATEDIR;

			%let dpfile = input.&DPInfoFile.;
			%let reportdata = Y;
		%end;
		%else %do;
			/* Create dpinfo file */
			data dpinfofile;
              length dp $10 dpname $100 path $250 database $250 includedp $1;
			  dp = "&dp.";
			  path = "&msoc.";
			  %if %nrbquote(&dpname.) = %str() %then %do; dpname = "&dp."; %end;
			  %else %do; dpname = "&dpname."; %end;
			  %if %nrbquote(&database.) = %str() %then %do; database = "Sentinel Distributed Database"; %end;
			  %else %do; database = "&database."; %end;
			  includedp = "Y";
			run;

			%let dpfile = dpinfofile;
			%let stratifybydp = N;
        	%let report_destination = PDF;  

			/*If reportdata is set to N then set reportdata folder to the work folder, otherwise assign the repdata folder and libname*/
			%if &reportdata. = N %then %do;
		    	libname repdata %sysfunc(quote(%sysfunc(pathname(work))));	 
		    %end;
		  	%else %do; 
				%let repdata = &output.reportdata&reportid.;
				options DLCREATEDIR ;
				libname repdata "&repdata" ;
				proc datasets nowarn nolist lib=repdata kill; quit;
				options NODLCREATEDIR;
		  	%end;
		%end;

		/* Create current report */
		%create_report();
	%end;	

	/*************************************************************************************************/
	/* Run log checker                                                                               */
	/*************************************************************************************************/
	%if &leavebehindreport. eq N %then %do;
	    proc printto log="&output.log_checker.log" new;
	    run;

		%ms_logchecker(logdir =&output., logdir_out=output);
	%end;

	/* End log */
    proc printto;
    run;	
	
    %put =====> END MACRO: create_report_driver ;

%mend create_report_driver;
