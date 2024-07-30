****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: process_inputfiles.sas  
* Created (mm/dd/yyyy): 11/30/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro reads in the CREATEREPORTFILE and other input files and merges in relevant
*          QRP input file parameter values
*                                        
*  Program inputs:                                                                                   
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

%macro process_inputfiles();

    %put =====> MACRO CALLED: process_inputfiles ;

/***************************************************************************************************
*   Read in CREATEREPORTFILE and assign each parameter to a macro variable                                                  
***************************************************************************************************/

    %isdata(dataset=input.&createreportfile.);
    %if %eval(&nobs<1) %then %do;
        %put ERROR: (Sentinel) CREATEREPORTFILE is missing.;
        %put ERROR: (Sentinel) Make sure file is specified correctly and placed in the inputfiles folder;
        %abort;
    %end;
    
	* Check if createreportfile has horizontal structure;
	proc contents data=input.&createreportfile. noprint out=createreportfile_content;
	quit;

	%let parameter_variable_exists=0;
	proc sql noprint;
	select count(*) into :parameter_variable_exists from createreportfile_content
	where lowcase(name)="parameter";
	quit;

	%put &=parameter_variable_exists;

	/* createreportfile has vertical structure */
	%if &parameter_variable_exists. > 0 %then %do;	
		data &createreportfile.;
		set input.&createreportfile.;
		run; 
	%end;
	/* createreportfile has horizontal structure */
	%else %do;		
		proc sql noprint;
		select distinct name into :createreportfile_param_content separated by ' ' from createreportfile_content			
		quit;

		%put &=createreportfile_param_content;

		data &createreportfile.;
		set input.&createreportfile.;
		value="value";		
		run;

		proc transpose data=&createreportfile. 
					   out=&createreportfile.(rename=_name_=parameter);
		id value;
		var &createreportfile_param_content.;
		run;		
	%end;

    /* Identify if leave behind report is being created based on the existance of the report_parameters dataset.
       Create macro variable to identify if it is a leave behind report */
        proc sql noprint;
            select count(*) into: numparms
            from &createreportfile;
        quit;

        /*Assign all parameters to macro variables*/
        %do createreportparameter = 1 %to %eval(&numparms.);		
            data _null_;
                set &createreportfile;
                if _n_ = &createreportparameter. then do;
                    call symputx("parameter", strip(parameter));
                    call symputx("value", strip(value));
                    /*defensive*/
                    if lowcase(parameter) in ('reporttype','stratifybydp','small_cellcounts','report_destination',
                                              'outputviewsdata', 'jirakey') then call symputx("value",upcase(value));
                    if lowcase(parameter) in ('customizecolumns', 'collapse_vars') then call symputx("value",lowcase(value));
                    /*default report_destination is both*/
                    if lowcase(parameter) = 'report_destination' and missing(value) then call symputx("value","BOTH");
                    /*default stratifybydp*/
                    if lowcase(parameter) = 'stratifybydp' and missing(value) then call symputx("value","N");
                    /*add parenthesis for datedistributed*/
                    if lowcase(parameter) in ('datedistributed') and missing(value)=0 then do;
                        tempvalue = input(value,ANYDTDTE32.); /*convert to SAS date*/
                        if missing(tempvalue) = 0 then do;
                            call symputx("value",cats('(', strip(put(tempvalue, worddate20.)), ')'));
                        end;
                        else do;
                            call symputx("value",cats('(', strip(value), ')'));
                        end;
                    end;
                end;
            run;

            /* Mask special characters from studytitle parameter */
            %if %lowcase(&parameter.) = studytitle %then %let value = %bquote(&value);
            %let &parameter. = &value.;

            /*assign formats to input files that were initially CSV - need to redirect log due to read of CSV file exposing file paths*/
            proc printto log=log;
	        run;

            %get_sas_format (%if &leavebehindreport = Y %then %do; path=&infolder., lib=infolder, %end;
                             %if &leavebehindreport = N %then %do; path=&input., lib=input, %end;
                             inputfile = &value, parameter=&parameter);

            /* Resume writing to log */
            %if &leavebehindreport = Y %then %do;
               proc printto log="&output.qrp_report_log&reportid..log";
               run;
            %end;
            %else %do;
                proc printto log="&output.qrp_report_log.log";
            %end;

        %end; /*createreport parameter loop*/

        /* If leave behind report is requested stratify by DP is set to N, report destination is PDF,
            dpfile is set to the work dpinfofile and reportdata is N. */
        %if &leavebehindreport = Y %then %do;
            %let stratifybydp = N;
            %let report_destination = PDF;
            %let dpfile = dpinfofile;
        %end;
        /* Set reportid suffix to missing when not a leave behind report */
        %else %do;
            %let reportid = ;
            %let dpfile = input.&DPInfoFile.;
            %global reportdata;
            %let reportdata = Y;
        %end;

        /* Check if user specified COLLAPSE_VARS if report type is L2. Parameter only applicable for L1 reports */
        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) >0 and %length(&collapse_vars) > 0 %then %do;
            %put WARNING: (Sentinel) COLLAPSE_VARS is not applicable for REPORTTYPE = &reporttype.. Rows will not be collapsed in the final report;
            %let collapse_vars = ;
        %end;

        /***************************************************************************************************
        *   Check if treeaggfile is specified. If this is the case, aggregated tree files and csv files 
        *   will automatically be created no matter what is the reporttype value (T3, T2L2, T4L2)  
        ***************************************************************************************************/

		%if %sysfunc(exist(input.&treeaggfile.)) %then %let treeaggindicator=Y;

/***************************************************************************************************
*  	Check if only the appendixfile is requested                                                     
***************************************************************************************************/
 	%let numfiles=0;
	%let numappendixfile=0;
	proc sql noprint;
		select count(*) into :numfiles from &createreportfile. 
		where strip(value) ne "" and lowcase(parameter) in ("baselinefile", "codedescriptionsfile", "groupsfile", "itsregressionfile", "l2comparisonfile", "treeaggfile");

		select count(*) into :numappendixfile from &createreportfile. 
		where strip(value) ne "" and lowcase(parameter) = "appendixfile";
	quit;

	%if &numfiles. = 0 and &numappendixfile. > 0 %then %let produceappendixfileonly=Y;

/***************************************************************************************************
 * Assign the maximum length to duplicate character variable names if a format values table exists 
 **************************************************************************************************/
    %if %sysfunc(exist(tmplib.format_values)) %then %do;
		/* Get character variables length to make sure the max function below works correctly */
		data tmplib.format_values;
		set tmplib.format_values;
		if substr(sas_format,1,1) eq "$" then char_var_length=input(compress(sas_format, "$"),best.);				
		run;

        %let inputvarlist=;
        proc sql noprint;
            select catx('@',full_inputfile_name,id,char_var_length)
            into :inputvarlist separated by ' '
            from 
            (select b.id, max(a.char_var_length) as char_var_length, a.full_inputfile_name 
                from tmplib.format_values a
                inner join 
                 (select id, count(*) as id_counts
                    from tmplib.format_values 
                    group by id) b
            on a.id = b.id 
            where b.id_counts > 1 and not missing(a.full_inputfile_name) and not missing(a.char_var_length)
            group by b.id
            )
        quit;

        %if %length(&inputvarlist) > 0 %then %do x = 1 %to %sysfunc(countw(&inputvarlist,%str( )));
            %let inputcombo = %scan(&inputvarlist,&x,%str( ));
            %let inputfile = %scan(&inputcombo,1,%str(@));
            %let inputvar = %scan(&inputcombo,2,%str(@));
            %let varformat = $%scan(&inputcombo,3,%str(@));
			
            %if &leavebehindreport = Y %then %do;
                data infolder.&inputfile;
                    length &inputvar &varformat;
                    format &inputvar &varformat..;
                    informat &inputvar &varformat..;
                    set infolder.&inputfile;
                run;
            %end;
            %else %do;
                data input.&inputfile;
                    length &inputvar &varformat;
                    format &inputvar &varformat..;
                    informat &inputvar &varformat..;
                    set input.&inputfile;
                run;
            %end;
        %end; /*x*/
    %end;/* tmplib.format_values exists */

/***************************************************************************************************
*   Check that REPORTTYPE is valid                                              
***************************************************************************************************/

    /*Valid values:
        - T1: Type 1 report
        - T2L1: Level 1, type 2 report
        - T2L2: Level 2, type 2 report 		
        - ITS: ITS report
		- T3: Type 3 report
        - T4L1: Level 1, type 4 report 
        - T4L2: Level 2, type 4 report 
        - T5: Type 5 report
        - T6: Type 6 report */
    %if %sysfunc(prxmatch(m/T1|T2L1|T2L2|ITS|T3|T4L1|T4L2|T5|T6/i,&reporttype.)) <= 0 and &produceappendixfileonly. ne Y %then %do;
        %put ERROR: (SENTINEL) REPORTTYPE parameter is invalid. Reporting tool will abort.;
        %abort;
    %end;

/***************************************************************************************************
*   Read in DPINFOFILE and mask DPs                                                     
***************************************************************************************************/

    /*Check if DPINFOFILE exists and contains at least 1 DP to include in report*/
    /* User specified dpinfofile */
    %isdata(dataset=&dpfile.);
    %if %eval(&nobs.=0) %then %do; 
		%if &produceappendixfileonly. eq N %then %do;
	        %put ERROR: (Sentinel) DPINFOFILE is missing.;
	        %put ERROR: (Sentinel) Make sure file is specified correctly and placed in the inputfiles folder;
	        %abort;
		%end;
    %end;
    %else %do;
        /*Number of DPs to include in report and list of DPs*/
        data dpinfofile;
            length database $250;
            set &dpfile. (where=(upcase(includeDP)='Y'));
            call symputx('num_dp', _n_);
            dp=lowcase(dp);
            if missing(database) then database = 'Sentinel Distributed Database';
        run;
        %if %eval(&num_dp.=0) %then %do;
            %put ERROR: (Sentinel) In DPINFOFILE, INCLUDEDP = N for all rows;
            %put ERROR: (Sentinel) At least 1 DP must be included in order for report to be produced;
            %abort;
        %end;

        proc sql noprint;
            select dp into: dplist separated by ' '
            from dpinfofile;
        quit;
        %put Number of DPs included in report: &num_dp.;
        %put List of DPs included in report: &dplist.;

        /*Create database macro variable to use in titles*/
        proc sql noprint;
            select count(distinct database)
            into: databasecount
            from dpinfofile;
            %let databasecount = &databasecount.;
            
            select distinct strip(database) into :database1 - :database&databasecount.
            from dpinfofile;
        quit;
        %if %eval(&databasecount.=1) %then %do; %let database = &database1.; %end;
        %else %if %eval(&databasecount.=2) %then %do; %let database = &database1. and &database2.; %end;
        %else %do;
            %do db = 1 %to %eval(&databasecount.);
                %if %eval(&db. ne &databasecount.) %then %let database = &database. &&database&db.,;
                %else %let database = &database. and &&database&db.;
            %end;
        %end;

        /*Randomize and mask DPs*/
        data maskedDPIDkey;
            length dp $8.;
            %do z = 1 %to &num_dp.;
                dp = "%scan(&DPlist,&z)";
                random=ranuni(&seed.);
                output;
            %end;
        run;

        proc sort data=maskedDPIDkey;
            by random;
        run;

        data output.dpinfo;
            length maskedID $4;
            set maskedDPIDkey;
            maskedID = "DP"||put(_N_, z02.);
            drop random;
        run;

        /*Put list of DPs into macro variable in order to maintain random order*/
        proc sql noprint;
            select dp into: random_dplist separated by ' '
            from output.dpinfo;
            select maskedID into: masked_dplist separated by ' '
            from output.dpinfo;
        quit;
    %end;

/***************************************************************************************************
*   Read in APPENDIXFILE if specified                                               
***************************************************************************************************/
    %if %sysfunc(exist(input.&appendixfile.)) ne 0 %then %do;
        data appendixfile;
            set input.&appendixfile.;
            /*defensive*/
            appendixtype = lowcase(appendixtype);
            codestab = lowcase(codestab);
            /*all files will default to .xlsx*/
            if index(codesfile,'.') then codesfile=scan(codesfile,1,'.');
        run;
    %end;
    
	%if &produceappendixfileonly. = Y %then %goto cleanup;
    
/***************************************************************************************************
*   Read in the qrp parameters file and assign parameter to macro variables                                                 
***************************************************************************************************/
	* Check if qrp_parameters has horizontal structure;
	proc contents data=infolder.qrp_parameters noprint out=qrp_param_content;
	quit;

	%let parameter_var_exists=0;
	proc sql noprint;
	select count(*) into :parameter_var_exists from qrp_param_content
	where lowcase(name)="parameter";
	quit;

	%put &=parameter_var_exists;

	%if &parameter_var_exists. > 0 %then %do;
		/* Transpose qrp_parameters to determine run values associated with desired runids */
		proc transpose data=infolder.qrp_parameters(where=(lowcase(parameter)= 'runid')) out=_qrp_parameters_trans;
		var run:;
		run;

		data qrp_parameters;
		set infolder.qrp_parameters;
		run;
	%end;
	%else %do;
		data _qrp_parameters_trans(keep=run runid rename=runid=col1 rename=run=_name_)
			 qrp_parameters;
		set infolder.qrp_parameters;		
		run = "run" || strip(put(_N_, best.));	
		run;

		proc sql noprint;
		select distinct name into :qrp_param_content separated by ' ' from qrp_param_content			
		quit;

		proc transpose data=qrp_parameters 
					   out=qrp_parameters(rename=_name_=parameter);
		id run;
		var &qrp_param_content.;
		run;
	%end;
     
    /* Combine input files to identify all runids requested */
    data inputfiles;
       set 
         %if %sysfunc(exist(input.&groupsfile.)) %then %do;
           input.&groupsfile. (keep = runid group order)
         %end;
         %if %sysfunc(exist(input.&l2comparisonfile.)) %then %do;
           input.&l2comparisonfile. (keep = runid analysisgrp order rename=analysisgrp=group)
         %end;
         %if %sysfunc(exist(input.&baselinefile.)) %then %do;
           input.&baselinefile. (keep = runid group order in=b)
         %end;
         %if %sysfunc(exist(input.&treeaggfile.)) %then %do;
           input.&treeaggfile. (keep = runid treeanalysisGrp rename=treeanalysisGrp=group)
         %end;;

        runid = lowcase(runid);
        group = lowcase(group);

         %if %sysfunc(exist(input.&baselinefile.)) %then %do;
           if b then baseline = 'Y';
           else baseline = 'N';
         %end;
     run;

     proc sql noprint;
        select count(distinct runid) 
        into: numrunid
        from inputfiles;
        
        %let numrunid = &numrunid.;

        select distinct runid
        into: runidlist separated by ' '
        from inputfiles;

        select distinct b._name_
              ,a.runid
        into: run1 -:run&numrunid. 
             ,:id1 - :id&numrunid.
        from inputfiles as a
        left join _qrp_parameters_trans as b
           on a.runid = b.col1;
     quit;

     /* Identify run specific parameters and values to store as macro variables*/
     %do n = 1 %to &numrunid.;
       /* Abort if run value is missing*/
        %if %str("&&run&n.") = %str("") %then %do;
           %put ERROR: (Sentinel) runid &&id&n. is not on the infolder.qrp_parameters file.;
           %put ERROR: (Sentinel) Review input files and confirm valid runids are requested for the QRP run designated at the infolder directory.;
           %abort;
        %end;
        
        /* Initialize macro variables */
        %global &&id&n.._runid  &&id&n.._periodidstart &&id&n.._periodidend &&id&n.._analysis &&id&n.._freezedata &&id&n.._monitoringfile
            &&id&n.._cohortfile &&id&n.._type1file &&id&n.._type2file &&id&n.._type3file &&id&n.._type4file &&id&n.._type5file &&id&n.._type6file 
            &&id&n.._metadatafile &&id&n.._treelookup &&id&n.._icd10icd9map &&id&n.._treefile &&id&n.._psestimationfile &&id&n.._itsfile
            &&id&n.._psmatchfile &&id&n.._stratificationfile &&id&n.._iptwfile &&id&n.._covstratfile &&id&n.._diagnostics &&id&n.._indlevel
            &&id&n.._cohortcodes &&id&n.._inclusioncodes &&id&n.._covariatecodes &&id&n.._profile &&id&n.._mfufile &&id&n.._stockpilingfile
            &&id&n.._utilfile &&id&n.._combofile &&id&n.._drugclassfile &&id&n.._micohortfile
            &&id&n.._surveillancemode &&id&n.._labcodesmap &&id&n.._zipfile &&id&n.._run_envelope &&id&n.._distindex &&id&n.._treatmentpathways
            &&id&n.._userstrata &&id&n.._overlapfile &&id&n.._overlapfile_adhere &&id&n.._concfile &&id&n.._multeventfile &&id&n.._multeventfile_adhere
            &&id&n.._pscssubgroupfile &&id&n.._riskscorefile &&id&n.._pregnancycodes &&id&n.._pregnancymeta &&id&n.._pregnancyduration;
                  
        %let &&id&n.._runid                = ;
        %let &&id&n.._periodidstart        = ;
        %let &&id&n.._periodidend          = ;
        %let &&id&n.._analysis             = ;
        %let &&id&n.._freezedata           = ;
        %let &&id&n.._monitoringfile       = ;
        %let &&id&n.._cohortfile           = ;
        %let &&id&n.._type1file            = ;
        %let &&id&n.._type2file            = ;
        %let &&id&n.._type3file            = ;
        %let &&id&n.._type4file            = ;
        %let &&id&n.._type5file            = ;
        %let &&id&n.._type6file            = ;
        %let &&id&n.._metadatafile         = ;
        %let &&id&n.._treelookup           = ;
        %let &&id&n.._icd10icd9map         = ;
        %let &&id&n.._treefile             = ;
        %let &&id&n.._psestimationfile     = ;
        %let &&id&n.._psmatchfile          = ;
        %let &&id&n.._stratificationfile   = ;
        %let &&id&n.._iptwfile             = ;
        %let &&id&n.._covstratfile         = ;
        %let &&id&n.._diagnostics          = ;
        %let &&id&n.._indlevel             = ;
        %let &&id&n.._cohortcodes          = ;
        %let &&id&n.._inclusioncodes       = ;
        %let &&id&n.._covariatecodes       = ;
        %let &&id&n.._profile              = ;
        %let &&id&n.._mfufile              = ;
        %let &&id&n.._stockpilingfile      = ;
        %let &&id&n.._utilfile             = ;
        %let &&id&n.._combofile            = ;
        %let &&id&n.._drugclassfile        = ;        
        %let &&id&n.._micohortfile         = ;
        %let &&id&n.._surveillancemode     = ;
        %let &&id&n.._labcodesmap          = ;
        %let &&id&n.._zipfile              = ;
        %let &&id&n.._run_envelope         = ;
        %let &&id&n.._distindex            = ;
        %let &&id&n.._treatmentpathways    = ;
        %let &&id&n.._userstrata           = ;
        %let &&id&n.._overlapfile          = ;
        %let &&id&n.._overlapfile_adhere   = ;
        %let &&id&n.._concfile             = ;
        %let &&id&n.._multeventfile        = ;
        %let &&id&n.._multeventfile_adhere = ;
        %let &&id&n.._itsfile              = ;
        %let &&id&n.._pscssubgroupfile     = ;
		%let &&id&n.._riskscorefile        = ;
		%let &&id&n.._pregnancycodes  	   = ;
		%let &&id&n.._pregnancymeta  	   = ;
		%let &&id&n.._pregnancyduration    = ;

        data _null_;
          set qrp_parameters (keep = parameter &&run&n.);
          new_parameter = catx("_","&&id&n.",parameter);
          call symputx(new_parameter,&&run&n.,'G');
          if parameter = "zipfile" and not missing(&&run&n.) then do;
            call symputx("zipfile",&&run&n.);
          end;
        run;

        /*if CSV files, assign SAS format. Need to reassign tmplib if not running leave behind report*/
		%if &leavebehindreport. ne Y %then %do;
		libname tmplib "&INFOLDER";
		%end;

        %isdata(dataset=qrp_parameters);
        %do p = 1 %to &nobs.;

            data _null_;
              set qrp_parameters (keep = parameter &&run&n.);
              if _n_ = &p. then do;
                call symputx("parameter", strip(parameter));
                call symputx("value", strip(&&run&n.));
              end;
            run;

            /*assign formats to input files that were initially CSV - need to redirect log due to read of CSV file exposing file paths*/
            proc printto log=log;
	        run;

            %get_sas_format (path=&infolder., lib=infolder, inputfile = &value, parameter=&parameter);

            /* Resume writing to log */
            %if &leavebehindreport = Y %then %do;
               proc printto log="&output.qrp_report_log&reportid..log";
               run;
            %end;
            %else %do;
                proc printto log="&output.qrp_report_log.log";
            %end;

        %end;

		/*restore tmplib to its original location*/
		%if &leavebehindreport. ne Y %then %do;
		libname tmplib "&REPORTROOT.inputfiles/";
		%end;

        /***************************************************************************************************
         * Assign the maximum length to duplicate character variable names if a format values table exists 
         **************************************************************************************************/
        %if %sysfunc(exist(tmplib.format_values)) %then %do;
			/* Get character variables length to make sure the max function below works correctly */
			data tmplib.format_values;
			set tmplib.format_values;
			if substr(sas_format,1,1) eq "$" then char_var_length=input(compress(sas_format, "$"),best.);				
			run;

            %let inputvarlist=;
            proc sql noprint;
                select catx('@',full_inputfile_name,id,char_var_length)
                into :inputvarlist separated by ' '
                from 
                (select b.id, max(a.char_var_length) as char_var_length, a.full_inputfile_name 
                    from tmplib.format_values a
                    inner join 
                     (select id, count(*) as id_counts
                        from tmplib.format_values 
                        group by id) b
                on a.id = b.id 
                where b.id_counts > 1 and not missing(a.full_inputfile_name) and not missing(a.char_var_length)
                group by b.id
                )
            quit;

            %if %length(&inputvarlist) > 0 %then %do x = 1 %to %sysfunc(countw(&inputvarlist,%str( )));
                %let inputcombo = %scan(&inputvarlist,&x,%str( ));
                %let inputfile = %scan(&inputcombo,1,%str(@));
                %let inputvar = %scan(&inputcombo,2,%str(@));
                %let varformat = $%scan(&inputcombo,3,%str(@));
				
                    data infolder.&inputfile;
                        length &inputvar &varformat;
                        format &inputvar &varformat..;
                        informat &inputvar &varformat..;
                        set infolder.&inputfile;
                    run;
                    
            %end; /*x*/
        %end;/* tmplib.format_values exists */
      
     %end;

/***********************************************************************************************************
*   Identify groups for each runID for reporttypes = T1, T2L1, T3, T4L1, T5, T6, T2L2, T4L2                                           
************************************************************************************************************/

    %if %sysfunc(exist(input.&groupsfile.)) ne 0 | %sysfunc(exist(input.&l2comparisonfile.)) ne 0 | &treeaggindicator. eq Y %then %do;
         %do n = 1 %to &numrunid.;
            %global grouplist_&n.;
            %let runid = %scan(&runidlist., &n.);
                proc sql noprint;
                /*RUNID specific list of groups*/
                select quote(strip(group), "'") into :grouplist_&n separated by ","
                from inputfiles
                where runid = "&runid." 
                    %if %sysfunc(exist(input.&baselinefile.)) %then %do;
                    and baseline = 'N';
                    %end;
                    ;
                quit;
                %put &&grouplist_&n..;
         %end;
    %end;

/***********************************************************************************************************
*   GROUPSFILE processing                                            
************************************************************************************************************/

    %if %sysfunc(exist(input.&groupsfile.)) ne 0 %then %do;

        data groupsfile;
			length runid $5;
            set input.&groupsfile.;
            runid = lowcase(runid);
            group = lowcase(group);
            if missing(includeinfigure) then includeinfigure = 'N';
            includeinfigure = upcase(includeinfigure);
            %if &reporttype.=T6 %then %do;
            includenegativetime = upcase(includenegativetime);
            %end;
        run;

		/*Verify code distribution module run, compare groupsfile.CODEDIST with qrp_parameters.DISTINDEX */
		%let modifycodedist=N;	
		
		data _distindex(drop=name rename=(value=distindex));
			length runid $5;
			set sashelp.vmacro(keep=name value where=(name like '%_DISTINDEX' ));
			runid=lowcase(scan(name,1,'_'));
		run;
	
		proc sort data=_distindex; by runid; run;		
		proc sort data=groupsfile; by runid order; run;		
		
		data groupsfile(drop=distindex);
			merge groupsfile(in=in1) _distindex(in=in2);
			by runid;
			if in1 and in2;
			if upcase(distindex)^='Y' and codedist^='' then do;
				codedist='';
				put "WARNING: (Sentinel) CODEDIST will be set to missing for " runid ": " group "because DISTINDEX not set to Y";		
			end;
		run;

        /*Set max(order) value into NUMGROUPS*/
        proc sql noprint;
            select max(order) into :numgroups 
            from groupsfile;
        quit;

        /* Check if code distribution is required */
        %let codedistcount = 0;

        proc sql noprint;
            select count(*) into :codedistcount 
            from groupsfile 
            where strip(CodeDist) ne '';
        quit;

        %if %eval(&codedistcount. > 0) %then %do;
            %let output_code_distribution = Y;
            proc sort data=groupsfile(keep=group runid order codedist topncodedist) out=GroupsDist;
            by order;
            where strip(codedist) ne "";
            run;
        %end;
        %put &=output_code_distribution;

        /*Type 6 - assign to macro variable which groups to include negative time*/
        %if &reporttype. = T6 %then %do;
            proc sql noprint;
                select quote(strip(group), "'") into :discardnegativetimegroups separated by ","
                from groupsfile
                where includenegativetime = "N";
            quit;
        %end;

        /* obtain only groups that figures were requested for */
        proc sql noprint;
            select distinct order 
            into :requestedfigs separated by ' '
            from  groupsfile
            where includeinfigure = 'Y'
            order by order;
        quit;

    %end;

/***************************************************************************************************
*   Create a combined treefile for all runs                                                
***************************************************************************************************/
    %if &treeaggindicator = Y  %then %do; 
         data master_treefile;
         set %do n = 1 %to &numrunid.;
                %let runid=&&id&n..;
                infolder.&&&runid._treefile(in=n&n.)
            %end;
         ;
         format runid $6.;
            %do n = 1 %to &numrunid.;
                if n&n. then do;
                runid = "&&id&n.";
                end;
            %end;
            treeanalysisgrp=lowcase(treeanalysisgrp);
         run;
    %end;
 
/***************************************************************************************************
*   Create a combined pregnancymeta for all runs                                                
***************************************************************************************************/
	%if %sysfunc(prxmatch(m/T4L1|T4L2/i,&reporttype.)) > 0	%then %do; 
	     data master_pregnancymeta;
	     set %do n = 1 %to &numrunid.;
	            %let runid=&&id&n..;
	            infolder.&&&runid._pregnancymeta(in=n&n.)
	        %end;
	     ;
	     format runid $6.;
	        %do n = 1 %to &numrunid.;
	            if n&n. then do;
	            runid = "&&id&n.";
	            end;
	        %end;
		 preg_outcome=upcase(preg_outcome);
		 preg_outcomecat=upcase(preg_outcomecat);
	     run;
	%end;

/***************************************************************************************************
*   Create a combined cohortfile for all runs                                                
***************************************************************************************************/

     data master_cohortfile;
     set %do n = 1 %to &numrunid.;
            %let runid=&&id&n..;
            infolder.&&&runid._cohortfile(in=n&n.)
        %end;
     ;
     format runid $6.;
        %do n = 1 %to &numrunid.;
            if n&n. then do;
            runid = "&&id&n.";
            end;
        %end;
     run;

/***************************************************************************************************
*   Create a combined cohortcodes for all runs                                                
***************************************************************************************************/

     data master_cohortcodes;
     set %do n = 1 %to &numrunid.;
            %let runid=&&id&n..;
            infolder.&&&runid._cohortcodes(in=n&n.)
        %end;
     ;
     format runid $6.;
        %do n = 1 %to &numrunid.;
            if n&n. then do;
            runid = "&&id&n.";
            end;
        %end;
     run;

/***************************************************************************************************
*   Create a pregnancy outcome label dataset                                            
***************************************************************************************************/
    %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0  and %sysfunc(exist(input.&baselinefile)) %then %do; 
        proc sql noprint;
            select distinct upper(preg_outcome)
            into :live_preg_outcomes separated by '|'
            from master_pregnancymeta
            where upper(preg_outcomecat) = 'LIVE';

            select distinct upper(preg_outcome)
            into :nonlive_preg_outcomes separated by '|'
            from master_pregnancymeta
            where upper(preg_outcomecat) = 'NONLIVE';
        quit; 

        data _po_codes;
            set master_cohortcodes(where=(upcase(codecat) = 'PO'));
            i=1;
            do while(scan(code, i, " ") ne "");
                code2=upcase(scan(code, i, " "));           
                output;
                i=i+1; 
            end;
            drop i code;
            rename code2=code;
        run;

        proc sql noprint;
            create table _pregnancy_outcome_labels as 
            select distinct a.runid, a.group, a.order, b.code  
            from input.&baselinefile as a 
            left join _po_codes as b
            on a.runid = b.runid and a.group = b.group
            order by a.runid, a.group, a.order;
        quit;

        proc transpose data = _pregnancy_outcome_labels out=_temp_preg_labels;
            var code;
            by runid group order;
        run;

        data _temp_preg_labels;
            set _temp_preg_labels;
            code=catx(' ', of col:);
        run;

        %let single_nonlive_orders =;
        proc sql noprint undo_policy=none;
            /* Add baselinegroupnum to dataset */
            create table _temp_preg_labels as 
            select a.*, b.baselinegroupnum
            from _temp_preg_labels a 
            left join input.&baselinefile b 
            on a.runid = b.runid and a.group = b.group and a.order = b.order;

            select distinct catx('@',order,baselinegroupnum) 
            into :single_nonlive_orders
            separated by ' '
            from _temp_preg_labels
            where countw(code) = 1 and prxmatch("/&nonlive_preg_outcomes/", code);
        quit;

        proc sort data = input.&baselinefile out=baseline_preg_labels;
            by runid group order;
        run;

        data baseline_preg_labels;
            merge baseline_preg_labels
                  _temp_preg_labels;
            by runid group order;
            length preg_outcome_label $65;
            if prxmatch("/&live_preg_outcomes/i",code) and ^prxmatch("/&nonlive_preg_outcomes/i",code) and ^prxmatch("/MIX/i",code) then do;
                if upcase(includenonpregnant) = 'Y' then preg_outcome_label='%str( )Live Birth Delivery Cohort and Non-Pregnant Cohort';
                else preg_outcome_label='%str( )Live Birth Delivery Cohort';
            end;
            else if prxmatch("/&nonlive_preg_outcomes/i",code) and ^prxmatch("/&live_preg_outcomes/i",code) and ^prxmatch("/MIX/i",code) then do;
                count=0;
                substring="&nonlive_preg_outcomes";
                do i = 1 to countw(substring,"|");
                    count + count(upcase(code), strip(scan(substring,i,"|")),'i');
                end;
                if count > 1 then do;
                    if upcase(includenonpregnant) = 'Y' then preg_outcome_label='%str( )Non-live Birth Outcomes Cohort and Non-Pregnant Cohort';
                    else preg_outcome_label='%str( )Non-live Birth Outcomes Cohort';
                end;
                else if count = 1 then do;
                    %if %length(&single_nonlive_orders) > 0 %then %do b = 1 %to %sysfunc(countw(&single_nonlive_orders, %str( )));
                        %let c = %scan(&single_nonlive_orders,&b,%str( ));
                        %let ordernum=%scan(&c,1,%str(@));
                        %let baselinenum=%scan(&c,-1,%str(@));

                    rc = dosubl("proc sql noprint;
                                 select descr into :preg_outcome_descr trimmed 
                                 from master_pregnancymeta b    
                                 where upper(b.preg_outcome) = (select upper(code)
                                                                from _temp_preg_labels
                                                                where order = &ordernum and baselinegroupnum=&baselinenum);
                                quit;");

                    if order = &ordernum and baselinegroupnum = &baselinenum then do;
                        if upcase(includenonpregnant) = 'Y' then preg_outcome_label= cat('%str( )', symget('preg_outcome_descr'),' Cohort and Non-Pregnant Cohort');
                        else preg_outcome_label=cat('%str( )', symget('preg_outcome_descr'),' Cohort');
                    end;
                    %end;
                end;
            end;
            else if prxmatch('/MIX/i',code) and ^prxmatch("/&live_preg_outcomes/i",code) and ^prxmatch("/&nonlive_preg_outcomes/i",code) then do; 
                rc = dosubl('proc sql noprint;
                             select descr into :preg_outcome_descr trimmed
                             from master_pregnancymeta 
                             where upcase(preg_outcome) = "MIX"; 
                             quit;
                            ');
                if upcase(includenonpregnant) = 'Y' then preg_outcome_label=cat('%str( )', symget('preg_outcome_descr'), ' Cohort and Non-Pregnant Cohort');
                else preg_outcome_label=cat('%str( )', symget('preg_outcome_descr'),' Cohort');
             end;
             else do;
                if upcase(includenonpregnant) = 'Y' then preg_outcome_label='%str( )Pregnant Cohort and Non-Pregnant Cohort';
                else preg_outcome_label='%str( )Pregnant Cohort';
             end;
             drop _name_ count substring i code col: rc;
        run;
    %end;
/***************************************************************************************************
*   Create a combined type file for all runs                                        
***************************************************************************************************/
    
    %let typenum = %substr(&reporttype,2,1);

     data master_typefile;
     set %do n = 1 %to &numrunid.;
            %let runid=&&id&n..;
            infolder.&&&runid._type&typenum.file(in=n&n.)
        %end;
     ;
     format runid $5.;
        %do n = 1 %to &numrunid.;
            if n&n. then do;
            runid = "&&id&n.";
            end;
        %end;

     %if &typenum. = 2 %then %do;
     /*assign macro variable if BASECOHORT is specified*/
     if missing(basecohort) = 0 then call symputx('basecohortused', 'Y');
     %end;
     run;

/***************************************************************************************************
*   Create a combined inclusion codes file for all runs                                        
***************************************************************************************************/

    data inclusioncodes_shell;
        length runid $5 group $40 condlevel $30;
        call missing(runid, group, condlevel);
        stop;
    run;

    data master_inclusioncodes;
        set 
        %do n = 1 %to &numrunid.;
        %let runid =&&id&n..;
        %if %sysfunc(exist(infolder.&&&runid._inclusioncodes)) %then %do;
        infolder.&&&runid._inclusioncodes(in=n&n)
        %end;
        %else %do;
        inclusioncodes_shell
        %end;
        %end;
        ;
        format runid $5.;
        %do n = 1 %to &numrunid.;
        %let runid =&&id&n..;
        %if %sysfunc(exist(infolder.&&&runid._inclusioncodes)) %then %do;
        if n&n. then do;
        runid = "&&id&n.";
        end;
        %end;
        %end;
    run;

    /*Type 2 queries, when BASECOHORT is specified, need to assign inclusion codes from BASECOHORT*/
    %if &basecohortused. = Y %then %do;
        /*build set and group assignment statements*/
        %let inclusionsetstatement = ;
        %let inclusioninstatement = ;

        proc sql noprint;
            select count(*) into: numoutcomecohorts 
            from master_typefile(where=(missing(basecohort)=0));
        quit;

        %do bc = 1 %to %eval(&numoutcomecohorts.);
            data _null_;
                set master_typefile(where=(missing(basecohort)=0));
                if _n_ = &bc. then do;
                    call symputx('runid', strip(runid));
                    call symputx('cohort', strip(group));
                    call symputx('basecohort', strip(basecohort));
                end;
            run;

            %let inclusionsetstatement = &inclusionsetstatement. master_inclusioncodes(in=a&bc. where=(runid="&runid." and group = "&basecohort."));
            %let inclusioninstatement = &inclusioninstatement. %str(if a&bc. then do; group ="&cohort"; end;) ;
        %end;

        /*add inclusion codes for outcome cohorts*/
        data master_inclusioncodes;
            set master_inclusioncodes
                &inclusionsetstatement.;
            &inclusioninstatement.;
        run;

    %end; /*Type 2 when basecohort specified*/


/*******************************************************************************************************
*   Create a combined treatmentpathways file for all runs and identify analysisgrps/groups in GROUPSFILE                                     
********************************************************************************************************/

    %if &reporttype. = T6 %then %do;
        data _treatmentpathways_shell;
            length runid $5 analysisgrp group $40;
            call missing(runid, analysisgrp, group);
            stop;
        run;

        data master_treatmentpathways;
            set 
            %do n = 1 %to &numrunid.;
                %let runid =&&id&n..;
                %if %sysfunc(exist(infolder.&&&runid._treatmentpathways)) %then %do;
                infolder.&&&runid._treatmentpathways(in=n&n)
                %end;
                %else %do;
                    _treatmentpathways_shell
                %end;
            %end;
            ;
            format runid $5.;
            %do n = 1 %to &numrunid.;
                %let runid =&&id&n..;
                %if %sysfunc(exist(infolder.&&&runid._treatmentpathways)) %then %do;
                if n&n. then do;
                runid = "&&id&n.";
                end;
                %end;
            %end;
        run;

        /*add variables to GROUPSFILE to indicate whether group is a COHORTGRP or ANALYSISGRP*/
        %isdata(dataset=groupsfile);
        %if %eval(&nobs.>0) %then %do;
            proc sql noprint undo_policy=none;
                create table groupsfile as
                select distinct x.*,
                                case when missing(y.cohortgrp) then 'Y'
                                else 'N'
                                end as switchanalysis,
                                case when missing(z.analysisgrp) then 'Y'
                                else 'N'
                                end as utilizationanalysis,
                                case when a.switchevalstep = 2 then 'Y'
                                else 'N'
                                end as switch2indicator
                from groupsfile as x
                left join master_cohortfile as y
                on x.group = y.cohortgrp and x.runid = y.runid
                left join master_treatmentpathways as z
                on x.group = z.analysisgrp and x.runid = z.runid
                left join (select runid, analysisgrp, switchevalstep 
                           from master_treatmentpathways 
                           where switchevalstep=2) as a
                on x.group = a.analysisgrp and x.runid = a.runid
                order by x.order;
            quit;
        %end;
    %end;

/***************************************************************************************************
*   Create a stacked t2 add-on file for all runs                                        
***************************************************************************************************/

    %if %index(&reporttype., T2L1) %then %do;
        data _t2_addonshell;
            length runid $5 group primary secondary $40;
            call missing(runid, group, primary, secondary);
            stop;
        run;

        data master_t2addon(keep=runid group primary secondary);
        set %do n = 1 %to &numrunid.;
                %let runid=&&id&n..;
                %if %sysfunc(exist(infolder.&&&runid._multeventfile)) %then %do;
                infolder.&&&runid._multeventfile(in=n&n.)
                %end;
                %else %if %sysfunc(exist(infolder.&&&runid._overlapfile)) %then %do;
                infolder.&&&runid._overlapfile(in=n&n.)
                %end;
                %else %if %sysfunc(exist(infolder.&&&runid._concfile)) %then %do;
                infolder.&&&runid._concfile(in=n&n.)
                %end;
                %else %do;
                _t2_addonshell
                %end;
            %end;
         ;
         format runid $5.;
            %do n = 1 %to &numrunid.;
                %let runid=&&id&n..;
                %if %sysfunc(exist(infolder.&&&runid._multeventfile)) or 
                    %sysfunc(exist(infolder.&&&runid._overlapfile)) or
                    %sysfunc(exist(infolder.&&&runid._concfile)) %then %do; 
                if n&n. then do;
                group=lowcase(analysisgrp);
                runid = "&&id&n.";
                end;
                %end;
            %end;
         run;
    %end;

/***************************************************************************************************
*   Create a stacked type 4 MICOHORT files                                      
***************************************************************************************************/

    %if %index(&reporttype.,T4) %then %do;
        data _mil_shell;
            length runid controlmp $5 ref group groupname $40;
            call missing(runid, controlmp, ref, group, groupname);
            stop;
        run;

       data master_mil(keep=runid group groupname controlmp ref);
            set %do n = 1 %to &numrunid.;
            %let runid=&&id&n..;
            %if %sysfunc(exist(infolder.&&&runid._micohortfile)) %then %do;
            infolder.&&&runid._micohortfile(in=n&n.)
            %end;
            %else %do;
            _mil_shell
            %end;
            %end;
            ;
            format runid $5.;
            %do n = 1 %to &numrunid.;
                %let runid=&&id&n..;
                %if %sysfunc(exist(infolder.&&&runid._micohortfile)) %then %do;
                if n&n. then do;
                group=lowcase(milgrp);
				ref=catt(group,"_ref");
                runid = "&&id&n.";
                end;
                %end;
            %end;
        run;
    %end;

/***************************************************************************************************
*   Create a stacked monitoring file for Sentinel Views                                
***************************************************************************************************/

    /* Create periodid2 variable when multiple runs are requested in query */
    /* Views platform does not have a way of distinguishing multiple runids
       so monitoring period variable is incremented as periodid2 to work around
       limitation */
    %if &outputviewsdata = Y and %sysfunc(prxmatch(m/T1|T2L1|T2L2/i,&reporttype)) %then %do;
        data monitoringfile_views;
            set %do n = 1 %to &numrunid.;
            %let runid=&&id&n..;
            infolder.&&&runid._monitoringfile(in=n&n.)
            %end;
        ;
         retain periodid2 0;
         format runid $6.;
            %do n = 1 %to &numrunid.;
                if n&n. then do;
                runid = "&&id&n.";
                periodid2+1;
                end;
            %end;
        run;

        /* Check that groupsfile is defined */
        %if %length(&groupsfile) = 0 and %sysfunc(prxmatch(m/T1|T2L1/i,&reporttype)) %then %do;
            %put ERROR: (SENTINEL) GROUPSFILE must be specified when OUTPUTVIEWSDATA=Y;
            %put The reporting code will abort;
            %abort;
        %end;
    %end;

/***************************************************************************************************
*   Read in LABELFILE if specified                                               
***************************************************************************************************/
    
    /*reassign reporttitle default if Type 4 L1*/
    %if &reporttype. = T4L1 %then %let reporttitle = Exposure(s) of Interest;

    %if %sysfunc(exist(input.&labelfile.)) ne 0 %then %do;
        data labelfile;
            set input.&labelfile.;
            /*defensive*/
            runid = lowcase(runid);
            group = lowcase(group);
            labeltype = lowcase(labeltype);
            labelvar = lowcase(labelvar);
            /*set reporttitle if specified*/
            if labeltype = 'reporttitle' then call symputx('reporttitle', label);
            if labeltype = 'header' then call symputx('includeheaderrow', 'Y');
            if labeltype = 'moiheader' then call symputx('includemoiheaderrow', 'Y');
        run;

        /* Determine length of label based off input file */
        proc contents data = labelfile out=_label_length(keep=name length) noprint;
        run;

        data _null_;
            set _label_length(where=(lowcase(name)= 'label'));
            call symputx('label_length',length);
        run;
        
        %let labelfileexists = Y;       

        /*Assign user censoring criteria labels*/
        data _null_;
            set labelfile(where=(labeltype='censorlabel'));
            call symputx(cats(labelvar,'_label'), label);
        run;
    %end;
    
/***************************************************************************************************
*   Userstrata, TableFile and FigureFile Processing                                         
***************************************************************************************************/
/*Userstrata file - loop through each runID, stack userstrata files and dedup*/
    %do n = 1 %to &numrunid.;
        %let runid =&&id&n..;
        /*confirm userstrata file exists*/
        %if %sysfunc(exist(infolder.&&&runid._userstrata)) %then %do;
            data _tempuserstrata(rename=levelvars_out=levelvars);
                format levelvars $100.;
                set infolder.&&&runid._userstrata;
                levelvars = lowcase(levelvars);
                tableid = lowcase(tableID);
                levelvars = tranwrd(levelvars, "*", " ");
                levelid = strip(levelid);

                /*****************************************/
                /* Defensive coding for automatic strata */
                /*****************************************/
                /*All report types*/
                if index(levelvars, 'month') > 0 & index(levelvars, 'year') = 0 then do;
                    levelvars = tranwrd(levelvars, "month", "year month");
                end;
                if index(levelvars, 'quarter') > 0 & index(levelvars, 'year') = 0 then do;
                   levelvars = tranwrd(levelvars, "quarter", "year quarter");
                end;

                /*ReportType = T2L1*/
                %if %str("&reporttype") = %str("T2L1") %then %do;
                if tableID in ('t2epigap', 't2epigapprev') and index(levelvars, 'epi_gap') = 0 then do;
                    levelvars = catx(' ',levelvars, "epi_gap");
                end;
                %end;

                /*ReportType = T6*/
                %if %str("&reporttype") = %str("T6") %then %do;
                if tableID= "t6disp" and index(levelvars, 'daysupp') = 0 then do;
                    levelvars = catx(' ',levelvars, "daysupp");
                end;
                if tableID = "t6episdur" and index(levelvars, 'cumepisodelength') = 0 then do;
                    levelvars = catx(' ',levelvars, "cumepisodelength");
                end;
                if tableID = "t6censor" and index(levelvars, 'episodelength') = 0 then do;
                    levelvars = catx(' ',levelvars, "episodelength");
                end;
                if tableID = "t6uptake" and index(levelvars, 'uptakedays') = 0 then do;
                    levelvars = catx(' ',levelvars, "uptakedays");
                end;
                if tableID = "t6trend" and index(levelvars, 'year') = 0 then do;
                    levelvars = catx(' ',levelvars, "year");
                end;
                if tableID = "t6switchepisdur" and index(levelvars, 'episodelength') = 0 then do;
                    levelvars = catx(' ',levelvars, "episodelength");
                end;
                %end;

                *alphabetize levelid vars;
                %alphabetizevarutil(array=d, in=levelvars, out=levelvars_out);
            run;

            proc append base=userstrata data=_tempuserstrata force; run;
        %end;
    %end;

    /*userstrata is optional if no rows in tablefile and figurefile are specified with DATASET populated*/
    %let userstrataspecified = N;
    %isdata(dataset=userstrata);
    %if %eval(&nobs.>0) %then %do;
        %let userstrataspecified = Y;
        proc sort data=userstrata nodupkey;
            by _all_;
        run;

        *Abort if there are duplicate tableid/levelid values and tableid/levelvars values;
        proc sort data=userstrata nodupkey dupout=_userstratadups;
            by tableid levelid;
        run;
        %isdata(dataset=_userstratadups);
        %if %eval(&nobs.>0) %then %do;
            %put ERROR: (SENTINEL) Multiple Userstrata files requested with different tableid-levelid combinations.;
            %put The reporting code will abort;
            %abort;
        %end;

         proc sort data=userstrata nodupkey dupout=_userstratadups;
            by tableid levelvars;
        run;
        %isdata(dataset=_userstratadups);
        %if %eval(&nobs.>0) %then %do;
            %put ERROR: (SENTINEL) Multiple Userstrata files requested with different tableid-levelvars combinations.;
            %put The reporting code will abort;
            %abort;
        %end;

        /* Type 3 tree weekdays table is not requested through tablefile
           and will be stored and processed independently. 
           Check if t3treewkdays was requested */
        %if &treeaggindicator. eq Y and &reporttype = T3 %then %do;
            data _null_;
                set userstrata(keep=tableid);
                if lowcase(tableid) = 't3treewkdays' then call symputx('t3treewkdaysdset','t3treewkdays');
            run;
        %end;
    %end;

    /*Read in TableFile, alphabetize variables, and assign title*/
    %isdata(dataset=input.&tablefile.);
    %if %eval(&nobs.>0) %then %do;
    
        /*Type 6 tables - cross check that relevant analysisgrps requested in GROUPSFILE*/
        %let switchobs = 0;
        %let switch2obs = 0;
        %if &reporttype.=T6 & %eval(&numgroups.>0) %then %do;
            proc sql noprint;
                select count(*) into: switchobs
                from groupsfile(where=(switchanalysis='Y'));
                select count(*) into: switch2obs
                from groupsfile(where=(switchanalysis='Y' & switch2indicator='Y'));
            quit;           
        %end;

        data tablefile(rename=levelid1_out=levelid1 rename=levelid2_out=levelid2 rename=levelid3_out=levelid3 rename=tablesubstrat_out=tablesubstrat);
            length censorreason $125;
            set input.&tablefile.(where=(upcase(includeinreport)='Y'));
            %if &typenum. = 4 | &typenum. = 3 %then %do;
              call missing(censorreason);
            %end;
            %else %do;
              if missing(censorreason) then do;
                if dataset in ("t1censor" "t2censor") then censorreason = "cens_elig cens_dth cens_dpend cens_qryend";
                else if dataset = "t2followuptime" then censorreason = "cens_episend cens_event cens_spec cens_dth cens_elig cens_dpend cens_qryend";
                else if dataset = "t5censor" then censorreason = "cens_episend cens_spec cens_dth cens_elig cens_dpend cens_qryend";
                else if dataset = "t6censor" then censorreason = "endenrollmentcount deathcount endavaildatacount endquerycount endproductdiscontinuationcount";
                else if dataset in ("t6plota", "t6plotb") then censorreason = "endenrollmentcount deathcount endavaildatacount endquerycount productdiscontinuationcount switchedcount";
              end;
              else do;
                %if &reporttype. = T6 %then %do;
                    /*convert to type 6 variables*/
                   censorreason = tranwrd(censorreason,'cens_elig','endenrollmentcount');
                   censorreason = tranwrd(censorreason,'cens_dth','deathcount');
                   censorreason = tranwrd(censorreason,'cens_dpend','endavaildatacount');
                   censorreason = tranwrd(censorreason,'cens_qryend','endquerycount');
                   if dataset = "t6censor" then censorreason = tranwrd(censorreason,'cens_episend','endproductdiscontinuationcount');
                    else censorreason = tranwrd(censorreason,'cens_episend','productdiscontinuationcount');
                   censorreason = tranwrd(censorreason,'cens_switch','switchedcount');
                %end;
                %else %do;
                censorreason = lowcase(censorreason);
                %end;
              end;
            %end;
            table=upcase(table);
            tablesub=lowcase(tablesub);
            tablesubstrat=lowcase(tablesubstrat);
            levelid1 = lowcase(levelid1);
            levelid2 = lowcase(levelid2);
            levelid3 = lowcase(levelid3);
            dataset = lowcase(dataset);
            n = _n_;

            /*defensive - abort if switchplots requested but no switch analysisgrps*/
            %if &reporttype.=T6 & %eval(&switchobs <1) %then %do;
                if dataset = 't6plota' then do;
                    put 'ERROR: (Sentinel) 1st switch requested in the TABLEFILE, however no 1st switch analyses were requested in the GROUPSFILE';
                    abort;
                end;
            %end;
            %if &reporttype.=T6 & %eval(&switch2obs <1) %then %do;
                if dataset = 't6plotb' then do;
                    put 'ERROR: (Sentinel) 2nd switch requested in the TABLEFILE, however no 2nd switch analyses were requested in the GROUPSFILE';
                    abort;
                end;
            %end;

            *defensive: replace overall with missing;
            if levelid1 = 'overall' then levelid1 = '';
            if levelid2 = 'overall' then levelid2 = '';
            if levelid3 = 'overall' then levelid3 = '';

            /*if reporttype = T4L1, replace dataset if tablesubstrat = t4nopreg*/
            %if %str("&reporttype") = %str("T4L1") %then %do;
                if tablesubstrat = 't4nopreg' then do;
                    if dataset = 't4preg' then dataset = 't4nopreg';
                end;
                else if tablesubstrat = 't4nopreggestwk' then do;
                    if dataset = 't4preggestwk' then dataset = 't4nopreggestwk';
                end;
            %end;

            /*Add column to hold table title stratification value - prior to reorder of variables*/
            format tabletitle $100.;
            if tablesub='overall' then do;
                tabletitle = '';
            end;
            else do;
                numw = countw(tablesub);
                do i = 1 to numw;
                    if i = 1 then do;
                        tabletitle = ', by '||strip(propcase(scan(tablesub, i)));
                    end;
                    else if i = 2 and numw = 2 then do;
                        tabletitle = cat(strip(tabletitle), ' and ',strip(propcase(scan(tablesub, i))));
                    end;
                    else if i = numw and numw >2 then do;
                        tabletitle = cat(strip(tabletitle), ', and ',strip(propcase(scan(tablesub, i))));
                    end;
                    else do;
                        tabletitle = cat(strip(tabletitle), ', ',strip(propcase(scan(tablesub, i))));
                    end;
                end;
                drop i numw;

                /*change the following tablesub values:
                 - Agegroup => Age Group
                 - Hispanic => Hispanic Origin
                 - Zip3 => 3-Digit Zip/State
                 - Zip_uncertain => Zip Uncertain
                 - Hhs_reg => Health and Human Services (HHS) Region
                 - Cb_reg => Census Bureau Region
                 - Adherence => Overall Adherence Criteria
                */
                if index(tabletitle, 'Agegroup')>0 then tabletitle =tranwrd(tabletitle, 'Agegroup', 'Age Group');
                if index(tabletitle, 'Hispanic')>0 then tabletitle =tranwrd(tabletitle, 'Hispanic', 'Hispanic Origin');
                if index(tabletitle, 'Zip3')>0 then tabletitle =tranwrd(tabletitle, 'Zip3', '3-Digit Zip/State');
                if index(tabletitle, 'Zip_uncertain')>0 then tabletitle =tranwrd(tabletitle, 'Zip_uncertain', 'Zip Uncertain');
                if index(tabletitle, 'Hhs_reg')>0 then tabletitle =tranwrd(tabletitle, 'Hhs_reg', 'Health and Human Services (HHS) Region');
                if index(tabletitle, 'Cb_reg')>0 then tabletitle =tranwrd(tabletitle, 'Cb_reg', 'Census Bureau Region');
                if index(tabletitle, 'Adherence')>0 and index(tabletitle, 'Adherence_')=0 then tabletitle =tranwrd(tabletitle, 'Adherence', 'Overall Adherence Criteria');

                /*Add ampersand to covariate. Will be resovled when title prints*/
                if index(tabletitle, 'Covar')>0 then tabletitle =tranwrd(tabletitle, 'Covar', '&StudyCovar');
            end;

            *alphabetize levelid, tablesub and tablesubstrat vars;
            %alphabetizevarutil(array=a, in=levelid1, out=levelid1_out);
            %alphabetizevarutil(array=b, in=levelid2, out=levelid2_out);
            %alphabetizevarutil(array=c, in=levelid3, out=levelid3_out);
            *%alphabetizevarutil(array=d, in=tablesub, out=tablesub_out);
            %alphabetizevarutil(array=e, in=tablesubstrat, out=tablesubstrat_out);
        run;

        %isdata(dataset=tablefile);
        %if %eval(&nobs.>0) %then %do;
            /*TableFile requires USERSTRATA specified*/
            %if &userstrataspecified. = N %then %do;
                %put ERROR: (Sentinel) TableFile specified however no USERSTRATA file is specified in QRP.;
                %abort;
            %end;
            %else %do;

                *Merge in levelids - need to do three times, 1 for each levelid;
                proc sql noprint undo_policy=none;
                    create table tablefile as
                    select distinct table.table
                         , table.tablesub
                         , table.tablesubstrat
                         , table.dataset
                         , table.levelid1 as strat1
                         , table.levelid2 as strat2
                         , table.levelid3 as strat3
                         , table.levelnum
                         , table.tabletitle
                         , table.censorreason
                         , table.categories
                         , strata.levelid as levelid1
                         , strata1.levelid as levelid2
                         , strata2.levelid as levelid3
                         , table.n
                    from tablefile as table
                    left join userstrata as strata
                    on strata.tableid = table.dataset and strata.levelvars = table.levelid1
                    left join userstrata as strata1
                    on strata1.tableid = table.dataset and strata1.levelvars = table.levelid2
                    left join userstrata as strata2
                    on strata2.tableid = table.dataset and strata2.levelvars = table.levelid3
                    order by table.n;
                quit;
   
                /*Assign stratificationorder to maintain default stratification order of tables*/
                /*Assign macro variable DATASETLIST for list of datasets*/
                proc sql noprint;
                    select distinct strip(lowcase(dataset)) into: tdatasetlist separated by ' '
                    from tablefile(where=(missing(dataset)=0))
                quit;
                %let datasetlist = &tdatasetlist.;
                %let tdatasetlistnum = %sysfunc(countw(&tdatasetlist.));

                /*Loop through for all datasets*/
                %do ds = 1 %to %eval(&tdatasetlistnum.);

                  data tablefile_&ds.;
                    set tablefile (where=(dataset= "%scan(&tdatasetlist, &ds, ' ')"));
                    length n 3;
                    n =_n_;
                  run;

                  /*Keep only the first one, order matters and is kept with n*/
                  proc sql noprint;
                    create table tablefile_sub_&ds. (drop = n) as 
                    select distinct table,  tablesub, n 
                    from tablefile_&ds.
                    group by table, tablesub
                    having min(n) = n
                    order by n;
                  quit;

                  proc sql noprint undo_policy=none;
                    create table tablefile_post_&ds. (drop = so) as
                    select distinct a.*, count(b.so) as stratificationorder length=3
                    from (select  *, monotonic() as so from tablefile_sub_&ds.) a
                    left join
                    (select  *, monotonic() as so from tablefile_sub_&ds.) b
                    on a.table=b.table  and b.so <= a.so
                    group by  a.table, a.tablesub
                    order by  a.table, stratificationorder;
                  quit;

                  proc sql noprint;
                    create table tablefile_u_&ds. (drop = n) as 
                    select a.*, b.stratificationorder from tablefile_&ds. as a 
                    left join
                    tablefile_post_&ds. as b
                    on a.table = b.table  and a.tablesub = b.tablesub;
                  quit;
                %end;

                /*Stack all datasets back up*/
                data tablefile;
                  set tablefile_u_:;
                run;

                proc sort data=tablefile sortseq=linguistic(numeric_collation=on);
                  by table dataset stratificationorder;
                quit;

                proc datasets noprint nowarn lib = work;
                  delete tablefile_:;
                quit;
            
                *Defensive check - if levels missing for required stratifications, write warning to the log and abort;
                data levelid_check;
                    set tablefile;
                    where levelid1 is missing | (levelnum = 2 and levelid2 is missing) | (levelnum = 3 and levelid3 is missing);
                run;

                %isdata(dataset=levelid_check);
                %if %eval(&nobs.>0) %then %do;
                    data output.levelid_check;
                        set levelid_check;
                    run;
                   %put ERROR: (Sentinel) Unable to generate all requested report tables and stratifications.;
                   %put ERROR: (Sentinel) Check output data LEVELID_CHECK for more information.;
                   %abort;
                %end;
                %else %do;
                    /*Put list of requested figures into macro variable TABLELIST*/
                    proc sql noprint;
                        select distinct table into: tablelist separated by ' '
                        from tablefile;
                    quit;

                    /*Type 5:
                       - Tables T1-T10 require overall category
                       - Tables T1, T3, T5, T7, T9, T15, T17 all require categories
                       - Must specify the same category for all stratifications within a table*/
                    %if &reporttype. = T5 %then %do;
                        %do t =1 %to %sysfunc(countw(&tablelist.));
                            %let overallrequested = N;
                            data _null_;    
                                set tablefile(where=(table="%scan(&tablelist, &t, ' ')"));
                                if _n_ = 1 then do;
                                    categoryfortable = categories;
                                end;
                                retain categoryfortable;
                                if tablesub = 'overall' then call symputx('overallrequested', 'Y');
                                if table in ('T1', 'T3', 'T5', 'T7', 'T9', 'T15', 'T17') and missing(categories) then do;
                                    put "ERROR: (Sentinel) CATEGORIES parameter must be populated for table %scan(&tablelist, &t, ' ')";
                                    abort;
                                end; 
                                if categoryfortable ne categories then do;
                                    put "ERROR: (Sentinel) CATEGORIES parameter must be the same for all stratifications for table %scan(&tablelist, &t, ' ')";
                                    abort;
                                end;
                            run;
                            %if &overallrequested. = N %then %do;
                               %put ERROR: (Sentinel) Overall table required for table %scan(&tablelist, &t, ' ');
                               %abort;
                            %end;
                        %end;
                        /* If censor tables T15 and T17 are requested confirm categories are the same across both tables */ 
                        %if %index(&tablelist,T15) | %index(&tablelist,T17) %then %do;
                           data _null_;    
                                set tablefile(where=(table in ('T15' 'T17')));
                                retain categoryfortable;
                                if _n_ = 1 then do;
                                   categoryfortable = categories;
                                end;
                                if categoryfortable ne categories then do;
                                    put "ERROR: (Sentinel) CATEGORIES parameter must be the same for tables T15 and T17.";
                                    put "Categories for table " table " are " categories ", expected categories are " categoryfortable ".";
                                    abort;
                                end;
                            run;
                        %end;
                    %end;
                    
                    /* Read in table columns file*/
                    %if %str("&tablecolumnsfile.") ne %str("") %then %do;
                      %if %sysfunc(exist(input.&tablecolumnsfile.))=0 %then %do;
                        %put ERROR: (Sentinel) tablecolumnsfile table is specified as input.&tablecolumnsfile. on &createreportfile., but the file does not exist.;
                        %abort;
                      %end;
                      %else %do;
                         proc sort data = input.&tablecolumnsfile. (where = (includeinreport = "Y" and 
                           table in (%sysfunc(tranwrd("&tdatasetlist.",%str( )," ")) %sysfunc(tranwrd("&tablelist.",%str( )," ")))))
                                    out = tablecolumns;
                           by table order;
                         run;
      
                         %isdata(dataset=tablecolumns);
                         %if %eval(&nobs.>0) %then %do;
                            %let checkt4l1_t1t5 = N;

                            data tablecolumns (keep = table column order columnlabel columnformat columnwidth columnname smallcellYN 
                                                  %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do; columnheader numerator %end;
                                                  %if %sysfunc(prxmatch(m/T1|T2L1/i,&reporttype.)) > 0 %then %do; cirate %end;);
                              set tablecolumns (rename = (order = order_in column = column_in));
                              length columnname $32 smallcellYN $1;
                              by table order_in;
                              column = lowcase(compress(column_in));
                              order + 1;
                              if order_in = 1 then order = 1;
                              columnname = compress("column"||put(order,3.));
                              smallcellYN = "N";

                              /*Type 4:
                                1. assign column headers - table T1 assign Number or Percent. Other tables are assigned columnlabel
                                2. Set small cell highlighting to Y for all n variables */
                              %if %str("&reporttype.") = %str("T4L1") %then %do;
                                if index(column,'/') = 0 then smallcellYN = "Y";
                                  columnheader=columnlabel;
                                  numerator = scan(compress(column,'()'),1,'/');
                                  if table in ('T1', 'T5') then do;
                                    if index(column, '/')>0 then columnheader = 'Percent';
                                    else columnheader = 'Number';
                                    call symputx('checkt4l1_t1t5', 'Y');
                                  end;
                              %end;
                            run;

                            /*Type 4 - check to ensure N and % columns have the same label*/
                            %if &checkt4l1_t1t5 = Y %then %do;
                                %let count = 1;
                                proc sql noprint;
                                    select max(c) into: count
                                    from (select count(distinct columnlabel) as c from tablecolumns(where=(table='T1')) group by numerator);
                                quit;

                                %if %eval(&count>1) %then %do;
                                  %put ERROR: (Sentinel) Different labels specified for N and % columns in table T1.;
                                  %abort;
                                %end;
                            %end;                         
                            
                            /* Add footnotes for T1 and T2L1 */
                            %if %sysfunc(prxmatch(m/T1|T2L1/i,&reporttype.)) > 0 %then %do;
                              data tablecolumns;
                                set tablecolumns;
                                length footnote 3;
                                by table order;
                                call missing(footnote);
                                if column in ("adjustedcodecount", "all_events", "dennumpts", "episodes", "eps_wevents", "npts", "rawcodecount") then smallcellYN = "Y";
                                if index(column,'dennumpts') > 0 and index(column,'dennummemdays') = 0 and index(column,'365.25') = 0 and index(column,'30.35') = 0 then footnote = 1;
                                else if (index(column,'dennummemdays') > 0 and index(column,'dennumpts') = 0 and index(column,'365.25') = 0 and index(column,'30.35') = 0) then footnote = 2;
                                else if index(column,'dennummemdays') > 0 and index(column,'dennumpts') = 0 and index(column,'365.25') > 0 then footnote = 3;
                              run;
                            %end;
                         %end;
                         %else %do;
                            %put ERROR: (Sentinel) All rows on input.&tablecolumnsfile. are set to N.; 
                            %put Columns must be selected for tables:&tdatasetlist.;
                            %abort;
                         %end;
                      %end;
                    %end; 
                    %else %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
                        /* A table columns file must be specified for T4L1 */
                        %put ERROR: (Sentinel) Lookup table includes dataset &tdatasetlist., but tablecolumnsfile is not specified in &createreportfile. file.;
                        %abort;
                    %end;
                %end;
            %end;
        %end; /*TableFile has rows with IncludeinReport=Y*/
        %else %do;
            %put WARNING: (Sentinel) TableFile specified, but all rows have INCLUDEINREPORT set to N.;
        %end;
    %end; /*TableFile specified*/

    /*Read in FigureFile, alphabetize variables, and assign title*/
    %isdata(dataset=input.&figurefile.);
    %if %eval(&nobs.>0) %then %do;

        /*macro variable to cross checkout Type 6 treatmentpathways file to ensure an analysisgrp has been requested*/
        %let t6checktreatmentpathways = N;

        /*macro variable to determine if a warn should be written to the log for Type 5 figures*/
        %let t5figurewarn=N;

        /*read in figurefile*/
        data figurefile(rename=levelid1_out=levelid1 rename=levelid2_out=levelid2 rename=levelid3_out=levelid3 
                        rename=figuresub_out=figuresub rename=censordisplay1=censordisplay);
            set input.&figurefile.(where=(upcase(includeinreport)='Y'));

            figure=upcase(figure);
            figuresub=lowcase(figuresub);
            levelid1 = lowcase(levelid1);
            levelid2 = lowcase(levelid2);
            levelid3 = lowcase(levelid3);
            dataset = lowcase(dataset);
            includeatrisktable = upcase(includeatrisktable);

            *if censordisplay is missing, replace with default list of censoring reasons;
            length censordisplay1 $80 n 3;
            censordisplay1 = lowcase(censordisplay);
            %if &reporttype. = T1 | &reporttype. = T2L1 %then %do; 
            if index(dataset, 'censor') and missing(censordisplay) then censordisplay1 = 'cens_elig cens_dth cens_dpend cens_qryend';
            if index(dataset, 'followuptime') and figure = 'F2' and missing(censordisplay) then censordisplay1 = 'cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_spec cens_event';
            else if index(dataset, 'followuptime') and figure = 'F1' and missing(censordisplay) then censordisplay1 = 'cens_event';
            /*Figure F1 is a KM curve for event of interest*/
            if index(dataset, 'followuptime') and figure = 'F1' and censordisplay1 ne 'cens_event' then do;
                put 'ERROR: (Sentinel) Figure F1 is a Kaplan-Meier Estimate of Event of Interest Not Occurring - censordisplay must be cens_event';
                abort;
            end;
            %end;
            %else %if &reporttype. = T5 %then %do;
            if index(dataset, 'censor') and missing(censordisplay) and figure = 'F4' then censordisplay1 = 'cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_spec';
            /*for F5 - check to ensure a censoring criterion is specified and only 1 is specified*/
            else if index(dataset, 'censor') and figure = 'F5' then do;
                if missing(censordisplay) then do;
                    put 'ERROR: (Sentinel) Figure F5 requires the user to specify one censor reason to display in the plot';
                    abort;
                end;
                if countw(censordisplay) >1 then do;
                    put 'ERROR: (Sentinel) Only 1 censor reason can be displayed in Figure F5';
                    abort;
                end;
            end;
            else if figure in ("F1", "F2", "F3") then do;
                if not missing(xmin) or not missing(xmax) or not missing(xtick) then call symputx('t5figurewarn', 'Y');
            end;
            %end;
            %else %if &reporttype. = T6 %then %do;
                /*Type 6 variable names in datasets t6plota/t6plotb do not match other censor variables. If specified, replace with cens_ variables*/
                /*Figure F4 and F5 are KM curves - censordisplay should be missing or set to cens_switch*/
                if figure in ('F4', 'F5') then do;
                    if missing(censordisplay)=0 and censordisplay not in ('switchedcount', 'cens_switch') then do;
                        put 'ERROR: (Sentinel) Figures F4 and F5 are Kaplan-Meier Estimate of Switch not occuring - censordisplay cannot be specified';
                        abort;
                    end;
                    else do;
                        censordisplay1 = 'cens_switch';
                    end;
                end;
                if figure in ('F6', 'F7') then do;
                    if missing(censordisplay) then do; censordisplay1 = 'cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_switch'; end;
                    else do;
                        censordisplay1=tranwrd(censordisplay1, "endenrollmentcount", "cens_elig");
                        censordisplay1=tranwrd(censordisplay1, "deathcount", "cens_dth");
                        censordisplay1=tranwrd(censordisplay1, "endavaildatacount", "cens_dpend");
                        censordisplay1=tranwrd(censordisplay1, "endquerycount", "cens_qryend");
                        censordisplay1=tranwrd(censordisplay1, "productdiscontinuationcount", "cens_episend");
                        censordisplay1=tranwrd(censordisplay1, "switchedcount", "cens_switch");
                    end;
                end;
                /*Figure F8 and F9 are Cumulative Incidence curves - censordisplay should be populated and set to a single value*/
                if figure in ('F8', 'F9') then do;
                    if missing(censordisplay) then do;
                        put 'WARNING: (Sentinel) Figures F8 and F9 are Cumulative Incidence of Switch - censordisplay must be specified as competing risk. Figure will not be produced.';
                        delete;
                    end;
                    else do
                        numcensordisplay = countw(censordisplay);
                        censordisplay1=scan(censordisplay, 1);                      
                        if numcensordisplay > 1 then do;
                            put 'WARNING: (Sentinel) Figures F8 and F9 are Cumulative Incidence of Switch - censordisplay must contain one unique value. The first value specified will be used as competing risk.';                        
                        end;
                        if censordisplay1 not in ('cens_elig', 'cens_dth', 'cens_dpend', 'cens_episend', 'cens_dth') then do;
                            put 'ERROR: (Sentinel) Figures F8 and F9 are Cumulative Incidence of Switch - censordisplay must be one of cens_elig, cens_dth, cens_dpend, cens_qryend, cens_episend';
                            abort;
                        end;                                           
                    end;
                    drop numcensordisplay;
                end;
                /*if figure using t6plota/t6plotb dataset, need to request figures in at last 1 analysisgrp in the TREATMENTPATHWAYS file*/
                if index(dataset, 't6plot') then call symputx('t6checktreatmentpathways', 'Y');
            %end;
            drop censordisplay;

            *defensive: replace overall with missing;
            if levelid1 = 'overall' then levelid1 = '';
            if levelid2 = 'overall' then levelid2 = '';
            if levelid3 = 'overall' then levelid3 = '';

            n = _n_;

            /*Add column to hold figure title stratification value - prior to reorder of variables*/
            format figuretitle $100.;
            if figuresub='overall' then do;
                figuretitle = '';
            end;
            else do;
                numw = countw(figuresub);
                do i = 1 to numw;
                    if i = 1 then do;
                        figuretitle = ', by '||strip(propcase(scan(figuresub, i)));
                    end;
                    else if i = 2 and numw = 2 then do;
                        figuretitle = cat(strip(figuretitle), ' and ',strip(propcase(scan(figuresub, i))));
                    end;
                    else if i = numw and numw >2 then do;
                        figuretitle = cat(strip(figuretitle), ', and ',strip(propcase(scan(figuresub, i))));
                    end;
                    else do;
                        figuretitle = cat(strip(figuretitle), ', ',strip(propcase(scan(figuresub, i))));
                    end;
                end;
                drop i numw;

                /*change the following tablesub values:
                 - Agegroup => Age Group
                 - Hispanic => Hispanic Origin
                */
                if index(figuretitle, 'Agegroup')>0 then figuretitle =tranwrd(figuretitle, 'Agegroup', 'Age Group');
                if index(figuretitle, 'Hispanic')>0 then figuretitle =tranwrd(figuretitle, 'Hispanic', 'Hispanic Origin');
            end;

            *alphabetize levelid and figuresub vars;
            %alphabetizevarutil(array=a, in=levelid1, out=levelid1_out);
            %alphabetizevarutil(array=b, in=levelid2, out=levelid2_out);
            %alphabetizevarutil(array=c, in=levelid3, out=levelid3_out);
            %alphabetizevarutil(array=d, in=figuresub, out=figuresub_out);
        run;

        %if &t5figurewarn. eq Y %then %put WARNING: (Sentinel) XMIN, XMAX and XTICK parameters should be set to missing when type 5 figures F1, F2, F3 are requested. Values specified will be ignored.;

        %isdata(dataset=figurefile);
        %if %eval(&nobs.>0) %then %do; 

            /*Type 6 figures - cross check that relevant groups requested in GROUPSFILE*/
            %if &t6checktreatmentpathways. = Y %then %do;
                proc sql noprint;
                    create table _tempt6check as
                    select group
                    from groupsfile(where=(includeinfigure='Y' and switchanalysis='Y'));
                quit;
                %isdata(dataset=_tempt6check);
                %if %eval(&nobs.<1) %then %do;
                    %put ERROR: (Sentinel) Switch plots requested in the FIGUREFILE, however no switching analyses were requested in the GROUPSFILE;
                    %abort;
                %end;
            %end;

            /*Put list of requested figures into macro variable FIGURELIST*/
            proc sql noprint;
                select distinct figure into: figurelist separated by ' '
                from figurefile;
            quit;

        %if %sysfunc(prxmatch(m/T1|T2L1|ITS|T5|T6/i,&reporttype.)) %then %do;
            /*Figurefile requires USERSTRATA specified if reporttype=T1, T2L1, T5, T6, ITS*/
            /*USERSTRATA is optional for reporttype = T2L2, T4L2*/
            %if &userstrataspecified. = N %then %do;
                %put ERROR: (Sentinel) FigureFile specified however no USERSTRATA file is specified in QRP.;
                %abort;
            %end;
            %else %do;
                /*Check USERSTRATA file against FigureFile to ensure correct levelIDs specified*/
                *Merge in levelids - need to do three times, 1 for each levelid;
                proc sql noprint undo_policy=none;
                    create table figurefile as
                    select distinct figure.figure
                         , figure.figuresub
                         , figure.dataset
                         , figure.levelid1 as strat1
                         , figure.levelid2 as strat2
                         , figure.levelid3 as strat3
                         , figure.levelnum
                         , figure.figuretitle
                         , figure.xmin
                         , figure.xmax
                         , figure.xtick 
                         , figure.ymin
                         , figure.ymax 
                         , figure.ytick
                         , figure.includeatrisktable
                         , figure.censordisplay
                         , strata.levelid as levelid1
                         , strata1.levelid as levelid2
                         , strata2.levelid as levelid3
                         , figure.n
                    from figurefile as figure
                    left join userstrata as strata
                    on strata.tableid = figure.dataset and strata.levelvars = figure.levelid1
                    left join userstrata as strata1
                    on strata1.tableid = figure.dataset and strata1.levelvars = figure.levelid2
                    left join userstrata as strata2
                    on strata2.tableid = figure.dataset and strata2.levelvars = figure.levelid3
                    order by figure.n;
                quit;

                *Defensive check - if levels missing for required stratifications, write warning to the log and abort;
                data levelid_check;
                    set figurefile;
                    where levelid1 is missing | (levelnum = 2 and levelid2 is missing) | (levelnum = 3 and levelid3 is missing);
                run;

                /*Add strata order*/
                
                %do figure_loop = 1 %to %sysfunc(countw(&figurelist));
                  %let flist_1 = %scan(&figurelist, &figure_loop, ' ');

                    data _figurefile_&flist_1.;
                      length stratificationorder 3;
                      set figurefile (where=(figure = "&flist_1"));
                      stratificationorder = _N_;
                    run;
                %end;
                data figurefile;
                  set _figurefile_:;
                run;
        
                /*For L1 figures, assign list of GROUPS to include in figures*/
                %if %sysfunc(prxmatch(m/T1|T2L1|T5|T6/i,&reporttype.)) %then %do;
                    %isdata(dataset=input.&groupsfile.);
                    %if %eval(&nobs.>0) %then %do;
                        proc sql noprint;
                            select quote(strip(group), "'") into :includegroupinfigure separated by ' '
                            from groupsfile
                            where includeinfigure = 'Y'; 
                        quit;

                        %if %str("&includegroupinfigure") = %str("") %then %do;
                            %put ERROR: (Sentinel) Figures requested in FIGUREFILE, however INCLUDEINFIGURE is set to N for all groups;
                            %abort;
                        %end;
                    %end;
                    %else %do;
                        %put ERROR: (Sentinel) Figures requested in FIGUREFILE, however GROUPSFILE is missing. Specify a GROUPSFILE in CREATEREPORTFILE;
                        %abort;
                    %end;
                %end;

                %isdata(dataset=levelid_check);
                %if %eval(&nobs.>0) %then %do;
                    data output.levelid_check;
                        set levelid_check;
                    run;
                   %put ERROR: (Sentinel) Unable to generate all requested report figures and stratifications.;
                   %put ERROR: (Sentinel) Check output data LEVELID_CHECK for more information.;
                   %abort;
                %end;
                %else %do;
                    /*Assign macro variable DATASETLIST for list of datasets to aggregate*/
                    proc sql noprint;
                        select distinct strip(lowcase(dataset)) into: fdatasetlist separated by ' '
                        from figurefile(where=(missing(dataset)=0))
                    quit;
                    %let datasetlist = &datasetlist. &fdatasetlist.;
                %end;
            %end;
        %end; /*L1 figures*/
        %end; /*FigureFile has rows with IncludeinReport=Y and should be mapped to USERSTRATA file*/
        %else %if %eval(&nobs.<1) %then %do;
            %put WARNING: (Sentinel) FigureFile specified, but all rows have INCLUDEINREPORT set to N.;
        %end;
    %end; /*FigureFile specified*/

    /*TableFile and FigureFile are optional, but if neither are specified for the following report types then write warning to the log:
       T1, T2L1, T4L1, T5, T6, ITS*/
    %if %sysfunc(prxmatch(m/T1|T2L1|ITS|T4L1|T5|T6/i,&reporttype.)) & %sysfunc(exist(tablefile))<1 & %sysfunc(exist(figurefile))<1 %then %do;
        %put WARNING: (Sentinel) TableFile and FigureFile are not specified. No additional tables or figures will be produced.;
    %end;

    %put datasetlist = &datasetlist;

/***************************************************************************************************
*   BASELINEGROUPNUM parameter check - ensure valid parameter combinations are used    
*   LABCHARACTERISTICS parameter check - if lab covariates specified, process list                                       
***************************************************************************************************/

    %if %sysfunc(exist(input.&baselinefile.)) %then %do;
        %let chk_baselinegroupnum = ;
        %let chk_covinps=;

        /* Check whether order values are the same across different run IDs */
        proc sql noprint;
            select count(distinct order)
            into :numorder 
            from input.&baselinefile;

            /* Check if lab covariates specified */
            select upper(labcharacteristics) into: labcovars separated by ' '
            from input.&baselinefile(where=(not missing(labcharacteristics)));
        quit;

        %if %length(&labcovars) > 0 %then %do;
        /* Expand lab covariates */
        %baseline_expand_parameters(var=labcovars);
        /* Remove quotes from the list */
        %let labcovars = %sysfunc(tranwrd(&labcovars,%str(%")/*"*/,%str( )));
        /* Remove duplicate covar values from list */
        %nonrep(invar=labcovars, outvar=labcharacteristics);

        /* sort covariates in ascending order */
        data _tempcovars;
            length tempcovar $20;
            %do i = 1 %to %sysfunc(countw(&labcharacteristics));
                %let tempcovar = %scan(&labcharacteristics,&i);
            tempcovar="&tempcovar";
            output;
            %end;
        run;

        proc sort data = _tempcovars sortseq=linguistic(numeric_collation=on);
            by tempcovar;
        run;

        proc sql noprint;
            select tempcovar 
            into :labcharacteristics separated by ' '
            from _tempcovars;
        quit;

        %end;

        %do m = 1 %to &numorder;
        data _null_;
           set input.&baselinefile.(where=(order=&m));
           lag_runid = lag(runid);
           if _n_ > 1 then do;
            if lowcase(runid) ^= lowcase(lag_runid) then do;
                put 'ERROR: (Sentinel) ORDER values cannot be repeated across different RUNID values';
                abort;
            end;
            if missing(baselinegroupnum) then do;
                put 'ERROR: (Sentinel) ORDER values can only be repeated when using the BASELINEGROUPNUM parameter';
                abort;
            end;
           end;
           if _n_ > 2 then do;
             put 'ERROR: (Sentinel) Only a maximum of 2 rows per ORDER value can be specified for the BASELINEGROUPNUM parameter';
             put 'ERROR: (Sentinel) Please ensure your baseline input file has the appropriate values';
             abort;
           end;
           if not missing(baselinegroupnum) then call symputx('chk_baselinegroupnum', baselinegroupnum);
           if not missing(covinps) then call symputx('chk_covinps', covinps);
        run;
        %end; /* m */
        
        /* Check for populated baselinegroupnum parameter within specific analysis types */
        %if %sysfunc(prxmatch(m/T2L2|T4L2|T6/i,&reporttype.)) > 0 and %length(&chk_baselinegroupnum) > 0 %then %do;
         %put ERROR: (Sentinel) BASELINEGROUPNUM functionality is not available for REPORTTYPE = &reporttype. and must be set to missing.;
         %abort;
        %end;

        /* Check if covinps has been specifed for L1 requests*/
        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) = 0 and %length(&chk_covinps) > 0 %then %do;
         %put WARNING: (Sentinel) covinps is not relevant for REPORTTYPE = &reporttype.. No covariates will be identified in the Baseline Characteristics table.;
        %end;

     %end; /* baselinefile */

/***************************************************************************************************
*   For L2 reports:
     1: Read in L2ComparisonFile    
     2: create master PS/CS input file dataset    
     3. Add unique psestimategrp flag to the l2comparisonfile    
***************************************************************************************************/

    %if &reporttype = T2L2 | &reporttype = T4L2 %then %do;

        /******************/
        /*L2ComparisonFile*/
        /******************/
        %isdata(dataset=input.&l2comparisonfile.);
        %if %eval(&nobs.>0) %then %do; 
            %let outputforestplot      = N;
            %let OutputPSDistribution  = N;
            data l2comparisonfile;
                set input.&l2comparisonfile.;
                /*defensive*/
                analysisgrp=strip(lowcase(analysisgrp));
                runid=strip(lowcase(runid));
                if missing(outputconditional) then outputconditional = 'Y';
                if missing(outputunconditional) then outputunconditional = 'Y';
                outputconditional=strip(upcase(outputconditional));
                outputunconditional=strip(upcase(outputunconditional));

                if missing(outputforestplot) then outputforestplot = 'N';
                else outputforestplot=strip(upcase(outputforestplot));
                if outputforestplot = 'Y' then call symputx('outputforestplot', 'Y');

                if missing(OutputPSDistribution) then OutputPSDistribution = 'N';
                else OutputPSDistribution=strip(upcase(OutputPSDistribution));
                if OutputPSDistribution = 'Y' then call symputx('OutputPSDistribution', 'Y');

                if missing(kmrefpop) then kmrefpop = 'unweighted';
                else kmrefpop=strip(lowcase(kmrefpop));
            run;

            %let numl2comparisons = &nobs.;

            /*Defensive check - if any comparisons request forest plot, then F2 in FIGUREFILE must be requested*/
            %if %index(&figurelist.,F2)=0 & &outputforestplot=Y %then %do;
                %put WARNING: (Sentinel) Forest Plots not requested in FIGUREFILE, however OUTPUTFORESTPLOT set to Y in L2COMPARISONFILE.;
                %put WARNING: (Sentinel) Forest Plots will not be produced;
                data l2comparisonfile;
                    set l2comparisonfile;
                    outputforestplot = 'N'; 
                run;
            %end;
            %if %index(&figurelist.,F2)>0 & &outputforestplot=N %then %do;
                %put WARNING: (Sentinel) Forest Plots requested in FIGUREFILE, however OUTPUTFORESTPLOT set to N for all rows in L2COMPARISONFILE;
                proc sql noprint;
                    select distinct figure into: figurelist separated by ' '
                    from figurefile
                    where figure ne 'F2';
                quit;
            %end;
            /*Defensive check - if any comparisons request histogram, then F1 in FIGUREFILE must be requested*/
            %if %index(&figurelist.,F1)=0 & &OutputPSDistribution=Y %then %do;
                %put WARNING: (Sentinel) PS Histograms not requested in FIGUREFILE, however OutputPSDistribution set to Y in L2COMPARISONFILE.;
                %put WARNING: (Sentinel) PS Histograms will not be produced;
                data l2comparisonfile;
                    set l2comparisonfile;
                    OutputPSDistribution = 'N'; 
                run;
            %end;
            %if %index(&figurelist.,F1)>0 & &OutputPSDistribution=N %then %do;
                %put WARNING: (Sentinel) PS Histograms requested in FIGUREFILE, however OutputPSDistribution set to N for all rows in L2COMPARISONFILE;
                proc sql noprint;
                    select distinct figure into: figurelist separated by ' '
                    from figurefile
                    where figure ne 'F1';
                quit;
            %end;
            /*T2L2: if KM curves requested, ensure events are not being redacted*/
            %if &reporttype. = T2L2 & %sysfunc(prxmatch(m/F3|F4|F5/i,&figurelist.)) > 0 %then %do;
                %if %index(&customizecolumns.,events) > 0 %then %do;
                    %put WARNING: (Sentinel) KM curves are requested, however events are redacted so KM curves will not be produced;
                    data _null_;
                        call symputx('figurelist', prxchange('s/F3|F4|F5//', -1, "&figurelist.")); /*remove KM curves*/
                    run;
                %end;
            %end;
            /*T2L2 and T4L2: if Forest Plots requested, ensure events are not being redacted*/
            %if %index(&reporttype,L2) and %index(&figurelist,F2) %then %do;
                %if %index(&customizecolumns.,events) > 0 %then %do;
                    %put WARNING: (Sentinel) Forest Plots are requested, however events are redacted so Forest Plots will not be produced;
                    data _null_;
                        call symputx('figurelist', prxchange('s/F2//', -1, "&figurelist.")); /*remove Forest Plots curves*/
                    run;
                %end;
            %end;
        %end;
        %else %do;
            %put WARNING: (Sentinel) L2ComparisonFile is required when ReportType = T2L2 or T4L2 in order to produce effect estimates and PS histograms. Effect estimates and PS histograms will not be computed;
        %end;

        /* T2L2/T4L2: Check for obscure combinations of including columns and simultaneous redaction */
        %if (%index(&customizecolumns.,redactevents) > 0 and (%index(&customizecolumns.,include) > 0 or %index(&customizecolumns.,sumevents) > 0)) or 
             (%index(&customizecolumns.,sumevents) > 0 and %index(&customizecolumns.,include) > 0) %then %do;
            %put WARNING: (Sentinel) The following values for CUSTOMIZECOLUMNS have been specified: &customizecolumns..;
            %put WARNING: (Sentinel) Columns that have been included for display also may be redacted. Results may not appear as expected.;
        %end;        
        
        /**********************************/
        /*Master PS/CS input file datasets*/
        /**********************************/

        /*Create shell table*/
        data pscs_masterinputs;
            length runid $5 file $32 analysisgrp psestimategrp eoi ref $40 ratio $1 strataweight $3 ipweight $4
                   caliper ceiling percentiles truncweight pstrim 8 unconditional reestimateps $1 subgroup $15 subgroupcat $11 stratvars $18;
            call missing(runid, file, analysisgrp, psestimategrp, eoi, ref, subgroup, subgroupcat, reestimateps, truncweight, ceiling, caliper, ratio, strataweight,
                   ipweight, percentiles, unconditional, pstrim, stratvars);
            stop;
        run;
        data psest_masterinputs;
            length runid $5 psestimategrp eoi ref $40 hdps $1;
            call missing(runid, psestimategrp, eoi, ref, hdps);
            stop;
        run;

        /*Set each table by looping through runIDs*/
        %do n = 1 %to &numrunid.;
            %let runid = %scan(&runidlist., &n.);
            data pscs_masterinputs;
                set pscs_masterinputs(in=x)
                %if %str("&&&runid._psmatchfile") ne %str("") %then %do;
                    infolder.&&&runid._psmatchfile(in=a)
                %end;
                %if %str("&&&runid._stratificationfile") ne %str("") %then %do;
                    infolder.&&&runid._stratificationfile(in=b)
                %end;
                %if %str("&&&runid._covstratfile") ne %str("") %then %do;
                    infolder.&&&runid._covstratfile(in=c)
                %end;
                %if %str("&&&runid._iptwfile") ne %str("") %then %do;
                    infolder.&&&runid._iptwfile(in=d)
                %end; ;

                %if %str("&&&runid._psmatchfile") ne %str("") %then %do;
                if a then file = 'psmatchfile';
                %end;
                %if %str("&&&runid._stratificationfile") ne %str("") %then %do;
                if b then file = 'stratificationfile';
                %end;
                %if %str("&&&runid._covstratfile") ne %str("") %then %do;
                if c then file = 'covstratfile';
                %end;
                %if %str("&&&runid._iptwfile") ne %str("") %then %do;
                if d then file = 'iptwfile';
                %end;

                if not x then do;
                runid = "&runid.";
                end;
                analysisgrp = lowcase(analysisgrp);
                psestimategrp = lowcase(psestimategrp);
                keep runid file analysisgrp psestimategrp subgroup subgroupcat ceiling caliper ratio strataweight truncweight
                     ipweight percentiles eoi ref unconditional pstrim reestimateps stratvars;
            run;

            data psest_masterinputs;
               set psest_masterinputs(in=x)
               %if %str("&&&runid._psestimationfile") ne %str("") %then %do;
                   infolder.&&&runid._psestimationfile(in=a)
               %end;
               ;
                if not x then do;
                runid = "&runid.";
                end;
                psestimategrp = lowcase(psestimategrp);
                eoi = lowcase(eoi);
                ref = lowcase(ref);
            run;
            
            /* If subgroups file exists then add subgroups to pscs_masterinputs */
            %isdata(dataset=infolder.&&&runid._pscssubgroupfile);
            %if %eval(&nobs. > 0) %then %do;
              proc sql noprint undo_policy=none;
                create table _pscs_masterinputs_subgroups as
                select pscs.runid
                      ,pscs.file
                      ,pscs.analysisgrp
                      ,pscs.psestimategrp
                      ,pscs.ceiling
                      ,pscs.caliper
                      ,pscs.ratio
                      ,pscs.strataweight
                      ,pscs.truncweight
                      ,pscs.ipweight
                      ,pscs.percentiles
                      ,pscs.eoi
                      ,pscs.ref
                      ,pscs.unconditional
                      ,pscs.pstrim
                      ,pscs.stratvars 
                      ,lowcase(sub.subgroup) as subgroup
                      ,upcase(sub.subgroupcat) as subgroupcat
                      /*set in REESTIMATEPS - defensive set to Y / N if no applicable*/
                      ,case when (strip(pscs.file) = 'iptwfile' | strip(pscs.file) = 'stratificationfile' & missing(strataweight)=0) then 'Y'
                       when strip(pscs.file) = 'covstratfile' then 'N'
                       else sub.reestimateps 
                       end as reestimateps
                from pscs_masterinputs as pscs
                inner join infolder.&&&runid._pscssubgroupfile as sub
                on pscs.analysisgrp = sub.analysisgrp;
              quit;
              
              data pscs_masterinputs;
                set pscs_masterinputs
                   _pscs_masterinputs_subgroups;
              run;
              
              /* Clean up work space */
              proc datasets lib = work;
               delete _pscs_masterinputs_subgroups;
              quit;
           %end;
        %end;

        /*Merge in psestimategrp parameters name*/
        proc sql noprint undo_policy=none;
            create table pscs_masterinputs as 
            select pscs.runid
                  ,pscs.file
                  ,pscs.analysisgrp
                  ,pscs.psestimategrp
                  ,pscs.ceiling
                  ,pscs.caliper
                  ,pscs.ratio
                  ,pscs.strataweight
                  ,pscs.truncweight
                  ,pscs.ipweight
                  ,pscs.percentiles
                  ,case when missing(pscs.eoi) then est.eoi
                  else pscs.eoi
                  end as eoi
                  ,case when missing(pscs.ref) then est.ref
                  else pscs.ref
                  end as ref
                  ,est.hdps
                  ,pscs.unconditional
                  ,pscs.pstrim
                  ,pscs.subgroup
                  ,pscs.subgroupcat
                  ,pscs.reestimateps
                  ,pscs.stratvars 
            from pscs_masterinputs as pscs
                 left join psest_masterinputs est
            on pscs.psestimategrp = est.psestimategrp; 
        quit;

        /*Type 4 - add GROUPNAME (base cohort)*/
        %if &reporttype. = T4L2 %then %do;
          proc sql noprint undo_policy=none;
            create table pscs_masterinputs as 
            select x.*,
                   y.groupname
            from pscs_masterinputs as x
            left join master_mil as y
            on substr(x.eoi,1,length(x.eoi)-4) = y.group and x.runid = y.runid;
        quit;
        %end;

        *Add unique psestimategrp flag to the l2comparisonfile;     
        %isdata(dataset=l2comparisonfile);
        %if %eval(&nobs.>0) %then %do;
         proc sql noprint;
           create table _l2comparisonfile_ps as
             select base.*
                   ,pscs.psestimategrp
             from l2comparisonfile as base
             left join pscs_masterinputs (where = (missing(subgroup))) as pscs
              on base.runid = pscs.runid
              and base.analysisgrp = pscs.analysisgrp
              order by runid, psestimategrp, order;
         quit;
         
         data l2comparisonfile;
           set _l2comparisonfile_ps; 
           length unique_psestimate 3;
           retain unique_psestimate;
           by runid psestimategrp order;
           unique_psestimate +1;
           if missing(psestimategrp) or first.psestimategrp then unique_psestimate = 1;
         run;
         %end;
    
        proc sort data=pscs_masterinputs nodupkey;
            by runid analysisgrp subgroup subgroupcat;
        run;
    %end;   

    /***************************************************************************
    Read in and Output TXT file for treelookup file per runid when it exists
    ***************************************************************************/
    %if &treeaggindicator. eq Y %then %do;
       /*Set each table by looping through runIDs*/
       %do n = 1 %to &numrunid.;
       %let runid = %scan(&runidlist., &n.);
       
       /* Determine if there is a comma in any row on the lookup file */
          %if %str("&&&runid._treelookup") ne %str("") %then %do;
             data _treelookup;
               length comma_in_parent comma_in_child 3.;
               set infolder.&&&runid._treelookup;
                if index(parent,',') > 0 then comma_in_parent = 1;
                else comma_in_parent = 0;
                if index(child,',') > 0 then comma_in_child = 1;
                else comma_in_child = 0;
             run;
             
             proc sql noprint;
               select sum(comma_in_parent) as parent_comma
                     ,sum(comma_in_child) as child_comma
               into :parent_comma
                   ,:child_comma
               from _treelookup;
             quit;
             
             %let parent_comma = &parent_comma.;
             %let child_comma = &child_comma.;
             
             %if &parent_comma. > 0 or &child_comma. > 0 %then %do;
               %put WARNING: Commas exist in either the child or parent node. A tab-delimited file will be produced.;
               %put &parent_comma. parent, and &child_comma. child nodes have commas.;
                proc export data = infolder.&&&runid._treelookup
                      outfile   = "&output.&&&runid._treelookup..txt"
                     dbms      = tab replace;
                     putnames  = NO;
                run;
             %end;  
             %else %do;  
                proc export data = infolder.&&&runid._treelookup
                      outfile   = "&output.&&&runid._treelookup..txt"
                     dbms      = dlm replace;
                     delimiter = ',';
                     putnames  = NO;
                run;
             %end;
          
             /* Clean up work space */
             proc datasets lib = work;
              delete _treelookup;
             quit;
          %end; /* treelookup exists */
        %end; /* runid loop */
      %end; /* tree aggregation requested */ 

    /***************************************************************************************************
    *  Create dataset containing tree analysis groups for poisson aggregation and tree analysis                                        
    ***************************************************************************************************/
    %if &treeaggindicator = Y %then %do; 
		/* Determine which datasets should be aggregated in MSOCDATA */
		data _null_;
		set userstrata;
		if tableid = "t&typenum.treeanalysis" then call symputx('treeanalysisaggindicator','Y');
        if tableid = "t&typenum.treepoisson" then call symputx('treepoissonaggindicator','Y');
		run;

        /* Check if poisson analyses are being requested */
        proc sql noprint;
            /* Create look-up table for poisson aggregation */
            create table _tree_group_lookup as 
            select a.runid, a.treeanalysisgrp, a.group, a.denominator, 
                   d.treeanalysisid, d.levelid, d.levelnum, d.levelnumlbl, 
                   d.rwstart, d.rwend, d.cwstart, d.cwend, e.tableid, e.levelvars
                   %if &reporttype ^= T3 %then %do;
                   ,case when missing(c.strataweight) and c.file='stratificationfile' then 'psstrat@unweighted'
                        when not missing(c.strataweight) and c.file='stratificationfile' then 'psstrat@weighted'
                        when not missing(c.ipweight) and c.file='iptwfile' then 'iptw@weighted'
                        else ''
                        end as adjustment length=20
                   %end;
            from master_treefile a 
            %if &reporttype ^= T3 %then %do;
            inner join pscs_masterinputs c
            on a.group = c.analysisgrp
            %end;
            inner join input.&treeaggfile d
            on lower(a.treeanalysisgrp) = lower(d.treeanalysisgrp)
            inner join userstrata e
            on d.levelid = e.levelid 
            where e.tableid in ("t&typenum.treepoisson","t&typenum.treeanalysis");
        quit;

        /* Create unweighted group for PS stratified weighted analysis */
        /* Tree analysis datasets cannot have values for weights, so remove them for processing in aggregate_tree */
        /* Vice versa for poisson - currently all groups for poisson will be weighted or unweighted */
        %if &reporttype ^= T3 %then %do;
            data tree_group_lookup_all;
                set _tree_group_lookup(in=a) _tree_group_lookup(where=(adjustment='psstrat@weighted') in=b);
                if b then do;
                    if tableid="t&typenum.treeanalysis" and not missing(adjustment) then delete;
                    if tableid="t&typenum.treepoisson" and missing(adjustment) then delete;
                    adjustment='psstrat@unweightedw';
                    output tree_group_lookup_all;
                end;
                else if a then do;
                    if tableid="t&typenum.treeanalysis" and not missing(adjustment) then delete;
                    if tableid="t&typenum.treepoisson" and missing(adjustment) then delete;
                    output tree_group_lookup_all;
                end;
            run;
        %end;
        %else %do;
            data tree_group_lookup_all;
                set _tree_group_lookup;
            run;
        %end;

        data _null_;
            set tree_group_lookup_all;
            if tableid = "t&typenum.treeanalysis" then call symputx('treeanalysisindicator','Y');
            if tableid = "t&typenum.treepoisson" then call symputx('treepoissonindicator','Y');
        run;

        /* Clean up work space */
        proc datasets nowarn noprint nolist lib = work;
          delete _tree_group_lookup;
        quit;
    %end; /* Treeaggindicator = Y */

/***************************************************************************************************
*  Create stacked dataset containing covariate labels for all runs          
*  Check stacked dataset for non-lab covariates that were specified as lab covariates                                    
***************************************************************************************************/
    /*loop through each runID, create datasets covarname_&runid.*/
    %do r = 1 %to %eval(&numrunid.);
        %let runid = %scan(&runidlist., &r.);
        %if %sysfunc(exist(infolder.&&&runid._covariatecodes.))=1 %then %do;

            /* Get studyname length per runid */
            proc contents data = infolder.&&&runid._covariatecodes. out=studylen(keep=name length) noprint;
            run;

            proc sql noprint;    
                create table covarname_&runid. as 
                select distinct covarnum, 
                                strip(studyname) as studyname, 
                                "&runid" as runid length=5, 
                                cats('covar',covarnum) as cov_varname length=8,
                                codedays,
								%if %index(&reporttype,T4) > 0 %then %do;
								covfromanchor,
								covtoanchor,	
								codepop,
								/* codepop2 will be used to compute codepop for cc covariates*/
								codepop as codepop2 format $6. length=6,
								code,
								%end;
                                codetype,
                                codecat
                from infolder.&&&runid._covariatecodes.;

                select length
                into: MAXLEN_STUDYNAME
                from studylen
                where lower(name)='studyname';
            quit;

			%if %index(&reporttype,T4) > 0 %then %do;
				/* Determine codepop value for cc covariates if any 
				   If cc covariates are defined using at least a covariate anchored on indexdt_exp, consider them as such */
				data Covarname_cc;
				set Covarname_&runid.;
				where upcase(codecat)="CC";
				code=compress(code,"andornotANDORNOT()");
				run;

				proc sql noprint;
				select distinct covarnum into :cc_covars separated by " " 
				from Covarname_cc;
				quit;

				%isdata(dataset=Covarname_cc);
				%if %eval(&nobs.>0) %then %do;
					%do cc_cov=1 %to %sysfunc(countw(&cc_covars.));
						%let cc_covar=%scan(&cc_covars., &cc_cov.);

						proc sql noprint;
							select code into :cc_covarlist 
							from Covarname_cc
							where covarnum=&cc_covar.; 

							select distinct codepop into :cc_codepop separated by " " 
							from Covarname_&runid.
							where covarnum in (&cc_covarlist.); 

							select distinct upcase(covfromanchor), upcase(covtoanchor) 
                            into :cc_covfromanchor separated by " ", 
                                 :cc_covtoanchor  separated by " " 
							from Covarname_&runid.
							where covarnum in (&cc_covarlist.); 
						quit;

						data Covarname_&runid.;
						set Covarname_&runid.; 
						if covarnum=&cc_covar. then do;
							/* Reassess codepop */
							codepop2="&cc_codepop";
							if index(codepop2, "M")>0 and index(codepop2, "I")>0 then codepop="MI";
							else if index(codepop2, "M")>0 then codepop="M";
							else if index(codepop2, "I")>0 then codepop="I";

							/* Reassess covfromanchor and covtoanchor */
							covfromanchor2="&cc_covfromanchor";
							covtoanchor2="&cc_covtoanchor";
							if index(covfromanchor2, "INDEXDT_EXP")>0 or index(covtoanchor2, "INDEXDT_EXP")>0 then do;
								covfromanchor="INDEXDT_EXP";
								covtoanchor="INDEXDT_EXP";
							end;
						end;
						run;
					%end; /* loop through cc covariates */
				%end; /* Covarname_cc contains data */
			%end; /* T4 report type */

            /* Need to set maximum studyname length across all runs */
            %if &baselinelabellength < &MAXLEN_STUDYNAME. %then %let baselinelabellength = &MAXLEN_STUDYNAME.;           
            %if %eval(&baselinelabellength. <80) %then %let baselinelabellength = 80;

            %if %sysfunc(exist(covarname))=0 %then %do;
                data covarname;
                    length studyname $&baselinelabellength;
                    set covarname_&runid.;
                run;     
            %end;
            %else %do;
                data covarname;
                    length studyname $&baselinelabellength;
                    set covarname covarname_&runid.;
                run;     
            %end;

        %end;
    %end;    

    /* Check whether labcharacteristics parameter contains non-lab codes and identify which lab covariates are categorical  */
    %isdata(dataset=covarname);
    %if %length(&labcovars) > 0 and &nobs > 0 %then %do;

        /*list of categorical labs*/
        proc sql noprint; 
            select upper(quote(cov_varname))
            into: charlabslist separated by ' '
            from covarname
            where codecat = 'LB' and substr(strip(reverse(codetype)), 1, 1) = 'C';
        quit;

        /*warn user if labcharacteristics parameter contains non-lab covariates*/
        data _null_;
            set covarname(where=(codecat^='LB' or codedays>1));
            %do labcovarnum = 1 %to %sysfunc(countw(&labcharacteristics));
                %let labcovar = %scan(&labcharacteristics,&labcovarnum);
                if upcase(cov_varname) = "&labcovar" then do;
                    put "WARNING: (Sentinel) The following covariate has been specified in LABCHARACTERISTICS but is not a lab covariate";
                    put cov_varname= codecat= codetype=;
                end;
            %end;
        run;
    %end;

    %if &nobs > 0 %then %do;
	    proc sort data = covarname nodupkey out=covarname(keep=covarnum studyname runid cov_varname %if %index(&reporttype,T4) > 0 %then %do; covfromanchor covtoanchor codepop %end;);
	        by runid covarnum;
	    run;  

		/* Views dashboards require the same covariates to be specified across runs for all covariates */
		%if &outputviewsdata. = Y and %sysfunc(prxmatch(m/T1|T2L1|T2L2/i,&reporttype)) %then %do;
			proc sort data=covarname out=_covarstudyname nodupkey;
				by covarnum studyname;
			run;

			proc sort data=_covarstudyname out=covarnameviews(keep=covarnum studyname cov_varname) dupout=_covdup nodupkey;
				by covarnum;
			run;

			%isdata(dataset=_covdup);
			%if %eval(&nobs.>0) %then %do;
				%put ERROR: (Sentinel) The same covariatecodes file must be used for all runs when using Sentinel Views.;
				%abort;
			%end;
	    %end;

	%end;

    /*Delete temporary dataset*/
   proc datasets nowarn noprint nolist lib=work; 
        delete studylen covarname_: _covarstudyname _covdup; 
   quit;  

/************************************************************************************************
     Create list of covariates specified in requested tables and figures
************************************************************************************************/
    
    %macro assigncovarlabels(dataset=, var=);

        %isdata(dataset=&dataset.);
        %if %eval(&nobs.>0) %then %do;
            data _covars (keep = covarnum);
               length covarnum 8;
               set &dataset. (where = (index(&var.,'covar') > 0 and index(&var.,'#') = 0));
               call missing(covarnum);
               if index(&var.,'covar') > 0 then do;
                 numstrat = countw(&var.,' ');
                 do ns = 1 to numstrat;
                   if index(scan(&var.,ns,' '),'covar') > 0 then do;
                     covarstrat = scan(&var.,ns,' ');
                     covarnum = input(substr(covarstrat,6),8.); output;
                   end;
                 end;
               end;
               if missing(covarnum) then delete;
            run;
                  
            %ISDATA(dataset=_covars); 
            %if &nobs > 0 %then %do;
                proc sort nodupkey data = _covars;
                    by covarnum;
                run;

               /* When covariates are requested in the &dataset., each of them must have the same studyname across selected runs */ 
               proc sort nodupkey data=covarname out=_covardup;
               by covarnum studyname;
               run;

               proc sql noprint undo_policy=none;
                 create table _covardup as
                 select distinct a.studyname,
                        a.covarnum
                 from _covardup a 
                      inner join _covars b
                 on a.covarnum=b.covarnum
                 group by a.covarnum
                 having freq(a.covarnum) > 1;
               quit;

               %ISDATA(dataset=_covardup); 
               %if &nobs > 0 %then %do;
                   %put ERROR: (SENTINEL) Multiple covariatecodes file exist with different covarnum studynames for requested stratification.;
                   %put ERROR: (SENTINEL) Remove covariate stratification or update QRP;
                   %put The reporting code will abort;
                   %abort;
               %end;

               proc sort nodupkey data = covarname(keep = covarnum studyname) out = _covarnames;
                 by covarnum;
               run;
               
               proc sql noprint undo_policy=none;
                 select count(covarnum) into: numsummarystratcovars trimmed
                 from _covars;

                 create table _covarnames as 
                 select a.covarnum,
                        b.studyname
                 from _covars a
                 left join _covarnames b
                 on a.covarnum = b.covarnum;

                 select covarnum into :tmpcovars separated by '|' from _covarnames;
                 select studyname into :tmpStudy separated by '|' from _covarnames;

                 %do cc = 1 %to &numsummarystratcovars;
                 /* Covariate names (i.e. covar1) and corresponding study names requested in &dataset. */
                 %global covar&cc studycovar%scan(&tmpcovars., &cc., %str(|));

                 %let covar&cc = covar%scan(&tmpcovars., &cc., %str(|));
                 %let studycovar%scan(&tmpcovars., &cc., %str(|)) = %scan(&tmpStudy., &cc., %str(|));
                 %end;              
               quit;
             %end;
        %end;
    %mend;
    %assigncovarlabels(dataset=tablefile, var=tablesub);
    %assigncovarlabels(dataset=pscs_masterinputs, var=subgroup);

/***************************************************************************************************
*  Create stacked dataset containing riskscores data for all runs                                            
***************************************************************************************************/
	%do r = 1 %to %eval(&numrunid.);
        %let runid = %scan(&runidlist., &r.);
        %if %sysfunc(exist(infolder.&&&runid._riskscorefile.))=1 %then %do;

            /* Get riskscorecat length per runid */
            proc contents data = infolder.&&&runid._riskscorefile. out=riskscorecatlen(keep=name length) noprint;
            run;

            proc sql noprint;    
                create table _riskscorefile_&runid. as 
                select distinct riskscore, 
                                strip(riskscorecat) as riskscorecat, 
                                "&runid" as runid length=5                                 							
                from infolder.&&&runid._riskscorefile.;

                select length
                into: MAXLEN_RISKSCORECAT trimmed
                from riskscorecatlen
                where lower(name)='riskscorecat';
            quit;

			%if %eval(&MAXLEN_RISKSCORECAT. < 7) %then %let MAXLEN_RISKSCORECAT=7;

            /* Need to set maximum riskscorecat length across all runs */          
            %if %sysfunc(exist(riskscorefile))=0 %then %do;
                data riskscorefile;
                    length riskscorecat $&MAXLEN_RISKSCORECAT.;
                    set _riskscorefile_&runid.;
                run;     
            %end;
            %else %do;
                data riskscorefile;
                    length riskscorecat $&MAXLEN_RISKSCORECAT.;
                    set riskscorefile _riskscorefile_&runid.;
                run;     
            %end;
			
			/* Assign labels for standard risk scores */ 
			data riskscorefile;
			set riskscorefile;
			format label $70.;
			riskscore = upcase(riskscore);
			if riskscore = "ADCSI" then label="Adapted Diabetes Complications Severity Index (aDCSI)";
			else if riskscore = "CHA2DS2VASC" then label="CHA^{sub 2}DS^{sub 2}-VASc score";
			else if riskscore = "CCI" then label="Combined comorbidity score";
			else if riskscore = "FRAILTY" then label="Claims-Based frailty index";
			else if riskscore = "HASBLED" then label="HAS-BLED score";
			else if riskscore = "OBSCOMORB" then label="Obstetric comorbidity index";
			else if riskscore = "PEDCOMORB" then label="Pediatric comorbidity index";
			else label=riskscore;		
			if strip(riskscorecat) = "" then riskscorecat="missing";	
			run;

			/*Delete temporary dataset*/
		    proc datasets nowarn noprint nolist lib=work; 
		    	delete riskscorecatlen _riskscorefile_:; 
		    quit; 
        %end;
    %end;  

/***************************************************************************************************
*   Clean up                                                
***************************************************************************************************/
%cleanup:

     proc datasets noprint nowarn lib = work;
      delete _: inclusioncodes_shell;
     quit;
    
    %put =====> END MACRO: process_inputfiles;

%mend process_inputfiles;
