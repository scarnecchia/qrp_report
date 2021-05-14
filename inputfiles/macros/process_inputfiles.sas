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

        proc sql noprint;
            select count(*) into: numparms
            from input.&createreportfile;
        quit;

        /*Assign all parameters to macro variables*/
        %do createreportparameter = 1 %to %eval(&numparms.);
            data _null_;
                set input.&createreportfile;
                if _n_ = &createreportparameter. then do;
                    call symputx("parameter", strip(parameter));
                    call symputx("value", strip(value));
                    /*defensive*/
                    if lowcase(parameter) in ('redactevents', 'redactpt') and missing(value) then call symputx("value",0);
                    if lowcase(parameter) in ('reporttype','stratifybydp','small_cellcounts','report_destination') then call symputx("value",upcase(value));
                    /*default report_destination is both*/
                    if lowcase(parameter) = 'report_destination' and missing(value) then call symputx("value","BOTH");
                    /*add parenthesis for datedistributed*/
                    if lowcase(parameter) in ('datedistributed') and missing(value)=0 then call symputx("value",cats('(', strip(value), ')'));
                end;
            run;
            %let &parameter. = &value.;
        %end;

/***************************************************************************************************
*   Check that REPORTTYPE is valid                                              
***************************************************************************************************/

    /*Valid values:
        - T1: Type 1 report
        - T2L1: Level 1, type 2 report
        - T2L2: Level 2, type 2 report 
        - ITS: ITS report
        - T4L1: Level 1, type 4 report 
        - T4L2: Level 2, type 4 report 
        - T5: Type 5 report
        - T6: Type 6 report
        - TREE2: tree aggregation for Type 2
        - TREE3: tree aggregration for Type 3
        - TREE4: tree aggregation for Type 4 */
    %if %sysfunc(prxmatch(m/T1|T2L1|T2L2|ITS|T4L1|T4L2|T5|T6|TREE2|TREE3|TREE4/i,&reporttype.)) <= 0 %then %do;
        %put ERROR: (SENTINEL) REPORTTYPE parameter is invalid. Reporting tool will abort.;
        %abort;
    %end;

/***************************************************************************************************
*   Read in DPINFOFILE and mask DPs                                                     
***************************************************************************************************/

    /*Check if DPINFOFILE exists and contains at least 1 DP to include in report*/
    %isdata(dataset=input.&DPInfoFile.);
    %if %eval(&nobs.=0) %then %do; 
        %put ERROR: (Sentinel) DPINFOFILE is missing.;
        %put ERROR: (Sentinel) Make sure file is specified correctly and placed in the inputfiles folder;
        %abort;
    %end;
    %else %do;
        /*Number of DPs to include in report and list of DPs*/
        data dpinfofile;
            length database $250;
            set input.&DPInfoFile.(where=(upcase(includeDP)='Y'));
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
*   Read in the qrp parameters file and assign parameter to macro variables                                                 
***************************************************************************************************/

    /* Transpose qrp_parameters to determine run values associated with desired runids */
	 proc transpose data=infolder.qrp_parameters(where=(lowcase(parameter)= 'runid')) out=_qrp_parameters_trans;
       var run:;
     run;

    /* Combine input files to identify all runids requested */
	 data _inputfiles;
	   set 
	     %if %sysfunc(exist(input.&groupsfile.)) %then %do;
	       input.&groupsfile. (keep = runid)
		 %end;
	     %if %sysfunc(exist(input.&l2comparisonfile.)) %then %do;
		   input.&l2comparisonfile. (keep = runid)
		 %end;
		 %if %sysfunc(exist(input.&baselinefile.)) %then %do;
		   input.&baselinefile. (keep = runid)
		 %end;
		 %if %sysfunc(exist(input.&itsregressionfile.)) %then %do;
		   input.&itsregressionfile. (keep = runid)
		 %end;
		 %if %sysfunc(exist(input.&treeaggfile.)) %then %do;
		   input.&treeaggfile. (keep = runid)
		 %end;;
     run;

     proc sql noprint;
        select count(distinct runid) 
	    into: numrunid
        from _inputfiles;
        
		%let numrunid = &numrunid.;

		select distinct lowcase(runid)
	    into: runidlist separated by ' '
        from _inputfiles;

		select distinct b._name_
		      ,a.runid
	    into: run1 -:run&numrunid. 
		     ,:id1 - :id&numrunid.
        from _inputfiles as a
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
            &&id&n.._utilfile &&id&n.._combofile &&id&n.._comorbfile &&id&n.._drugclassfile &&id&n.._pregdur &&id&n.._micohortfile
            &&id&n.._surveillancemode &&id&n.._labscodemap &&id&n.._zipfile &&id&n.._run_envelope &&id&n.._distindex &&id&n.._treatmentpathways
            &&id&n.._userstrata &&id&n.._overlapfile &&id&n.._overlapfile_adhere &&id&n.._concfile &&id&n.._multeventfile &&id&n.._multeventfile_adhere; 
			      
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
        %let &&id&n.._comorbfile           = ;
        %let &&id&n.._drugclassfile        = ;
        %let &&id&n.._pregdur              = ;
        %let &&id&n.._micohortfile         = ;
        %let &&id&n.._surveillancemode     = ;
        %let &&id&n.._labscodemap          = ;
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

        data _null_;
		  set infolder.qrp_parameters (keep = parameter &&run&n.);
		  new_parameter = catx("_","&&id&n.",parameter);
		  call symputx(new_parameter,&&run&n.,'G');
		run;
     %end;
	 
/***************************************************************************************************
*   Identify groups for each runID for reporttypes = T1, T2L1, T4L1, T5, T6, T2L2, T4L2, TREE2, TREE3, TREE4                                             
***************************************************************************************************/

	%if %sysfunc(exist(input.&groupsfile.)) ne 0 | %sysfunc(exist(input.&l2comparisonfile.)) ne 0 | %sysfunc(exist(input.&treeaggfile.)) ne 0 %then %do;
		data groupsfile;
			set 
			%if %sysfunc(exist(input.&groupsfile.)) ne 0 %then %do;
				input.&groupsfile.
			%end;
			%if %sysfunc(exist(input.&l2comparisonfile.)) ne 0 %then %do;
        		input.&l2comparisonfile. (rename=AnalysisGrp=group)
			%end;
            %if %sysfunc(exist(input.&treeaggfile.)) ne 0 %then %do;
                input.&treeaggfile. (rename=treeanalysisGrp=group)
            %end;
			;
			runid = lowcase(runid);
			group = lowcase(group);
		run;

		 %do n = 1 %to &numrunid.;
			%global grouplist_&n.;
	         %let runid = %scan(&runidlist., &n.);
	     		proc sql noprint;
	            /*RUNID specific list of groups*/
	            select quote(strip(group), "'") into :grouplist_&n separated by ","
	            from groupsfile
	            where runid = "&runid.";
				quit;
				%put &&grouplist_&n..;
	     %end;

		 /* Check if code distribution is required */
		 %if %sysfunc(exist(input.&groupsfile.)) ne 0 %then %do;
			%let codedistcount = 0;

			proc sql noprint;
			select count(*) into :codedistcount 
			from input.&groupsfile. where strip(CodeDist) ne '';
			quit;

			%if %eval(&codedistcount. > 0) %then %do;
				%let output_code_distribution = Y;

				proc sort data=groupsfile(keep=group runid order codedist topncodedist) out=GroupsDist;
				by order;
				where strip(codedist) ne "";
				run;
			%end;

			%put &=output_code_distribution;
		 %end;
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
*   Read in LABELFILE if specified                                               
***************************************************************************************************/
	%if %sysfunc(exist(input.&labelfile.)) ne 0 %then %do;
        data labelfile;
            set input.&labelfile.;
            /*defensive*/
    		runid = lowcase(runid);
    		group = lowcase(group);
            labeltype = lowcase(labeltype);
        run;

        /* Determine length of label based off input file */
        proc contents data = labelfile out=_label_length(keep=name length) noprint;
        run;

        data _null_;
            set _label_length(where=(lowcase(name)= 'label'));
            call symputx('label_length',length);
        run;
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
    %end;

    /*Read in TableFile, alphabetize variables, and assign title*/
    %isdata(dataset=input.&tablefile.);
    %if %eval(&nobs.>0) %then %do;
        data tablefile(rename=levelid1_out=levelid1 rename=levelid2_out=levelid2 rename=levelid3_out=levelid3 
                       rename=tablesub_out=tablesub rename=tablesubstrat_out=tablesubstrat);
            set input.&tablefile.(where=(upcase(includeinreport)='Y'));

        	table=upcase(table);
        	tablesub=lowcase(tablesub);
            tablesubstrat=lowcase(tablesubstrat);
        	levelid1 = lowcase(levelid1);
        	levelid2 = lowcase(levelid2);
        	levelid3 = lowcase(levelid3);
        	dataset = lowcase(dataset);

        	*defensive: replace overall with missing;
        	if levelid1 = 'overall' then levelid1 = '';
        	if levelid2 = 'overall' then levelid2 = '';
        	if levelid3 = 'overall' then levelid3 = '';

            /*if reporttype = T4L1, replace dataset if tablesubstrat = t4nopreg*/
            %if %str("&reporttype") = %str("T4L1") %then %do;
                if tablesubstrat = 't4nopreg' then do;
                    if dataset = 't4preg' then dataset = 't4nopreg';
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
                if index(tabletitle, 'Covar')>0 then tabletitle =tranwrd(tabletitle, 'Covar', '&covar');
            end;

        	*alphabetize levelid, tablesub and tablesubstrat vars;
            %alphabetizevarutil(array=a, in=levelid1, out=levelid1_out);
            %alphabetizevarutil(array=b, in=levelid2, out=levelid2_out);
            %alphabetizevarutil(array=c, in=levelid3, out=levelid3_out);
            %alphabetizevarutil(array=d, in=tablesub, out=tablesub_out);
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
                		 , strata.levelid as levelid1
                         , strata1.levelid as levelid2
                         , strata2.levelid as levelid3
                	from tablefile as table
                	left join userstrata as strata
                	on strata.tableid = table.dataset and strata.levelvars = table.levelid1
                    left join userstrata as strata1
                	on strata1.tableid = table.dataset and strata1.levelvars = table.levelid2
                    left join userstrata as strata2
                	on strata2.tableid = table.dataset and strata2.levelvars = table.levelid3;
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
                    /*Assign macro variable DATASETLIST for list of datasets to aggregate*/
                    proc sql noprint;
                        select distinct strip(lowcase(dataset)) into: tdatasetlist separated by ' '
                        from tablefile(where=(missing(dataset)=0))
                    quit;
                    %let datasetlist = &tdatasetlist.;
					
					/* Read in table columns file*/
					%if "&tdatasetlist." ne "" %then %do;
			          %if %str("&tablecolumnsfile.") = %str("") %then %do;
			  	        %put ERROR: (Sentinel) Lookup table includes dataset &tdatasetlist., but tablecolumnsfile is not specified in &createreportfile. file.;
			  		    %abort;
			  	      %end;
			          %else %if %sysfunc(exist(input.&tablecolumnsfile.))=0 %then %do;
                        %put ERROR: (Sentinel) tablecolumnsfile table is specified as input.&tablecolumnsfile. on &createreportfile., but the file does not exist.;
			  		    %abort;
                      %end;
					  %else %do;
					    data tablecolumns;
						  set input.&tablecolumnsfile. (rename = (order = order_in column = column_in) 
						                                where = (includeinreport = "Y" and lowcase(table) in (%sysfunc(tranwrd("&tdatasetlist.",%str( )," ")))));
						  length columnname $32 smallcellYN $1 footnote 3;
	                      by table order_in;
			              column = lowcase(compress(column_in));
	                      order = _n_;
			              smallcellYN = "N";
			              call missing(footnote);
			              columnname = compress("column"||order);
			              if column in ("adjustedcodecount", "all_events", "dennumpts", "episodes", "eps_wevents", "npts", "rawcodecount") then smallcellYN = "Y";
			              if index(column,'dennumpts') > 0 and index(column,'dennummemdays') = 0 and index(column,'365.25') = 0 and index(column,'30.35') = 0 then footnote = 1;
			              else if (index(column,'dennummemdays') > 0 and index(column,'dennumpts') = 0 and index(column,'365.25') = 0 and index(column,'30.35') = 0) then footnote = 2;
			              else if index(column,'dennummemdays') > 0 and index(column,'dennumpts') = 0 and index(column,'365.25') > 0 then footnote = 3;
                        run;
					  %end;
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
        data figurefile(rename=levelid1_out=levelid1 rename=levelid2_out=levelid2 rename=levelid3_out=levelid3 
                        rename=figuresub_out=figuresub);
            set input.&figurefile.(where=(upcase(includeinreport)='Y'));

        	figure=upcase(figure);
        	figuresub=lowcase(figuresub);
        	levelid1 = lowcase(levelid1);
        	levelid2 = lowcase(levelid2);
        	levelid3 = lowcase(levelid3);
        	dataset = lowcase(dataset);

        	*defensive: replace overall with missing;
        	if levelid1 = 'overall' then levelid1 = '';
        	if levelid2 = 'overall' then levelid2 = '';
        	if levelid3 = 'overall' then levelid3 = '';

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

      /*Put list of requested figures into macro variabl FIGURELIST*/
        proc sql noprint;
            select distinct figure into: figurelist separated by ' '
            from figurefile;
        quit;

        %isdata(dataset=figurefile);
        %if %eval(&nobs.>0) & %sysfunc(prxmatch(m/T1|T2L1|ITS|T5|T6/i,&reporttype.)) %then %do;
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
                    	 , strata.levelid as levelid1
                         , strata1.levelid as levelid2
                         , strata2.levelid as levelid3
                    from figurefile as figure
                    left join userstrata as strata
                    on strata.tableid = figurefile.dataset and strata.levelvars = figurefile.levelid1
                    left join userstrata as strata1
                    on strata1.tableid = figurefile.dataset and strata1.levelvars = figurefile.levelid2
                    left join userstrata as strata2
                    on strata2.tableid = figurefile.dataset and strata2.levelvars = figurefile.levelid3;
                quit;
            	
                *Defensive check - if levels missing for required stratifications, write warning to the log and abort;
                data levelid_check;
                    set figurefile;
                    where levelid1 is missing | (levelnum = 2 and levelid2 is missing) | (levelnum = 3 and levelid3 is missing);
                run;

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
***************************************************************************************************/

  %if %sysfunc(exist(input.&baselinefile.)) %then %do;
        %let chk_baselinegroupnum = ;

        /* Check whether order values are the same across different run IDs */
        proc sql noprint;
            select count(distinct order)
            into :numorder 
            from input.&baselinefile;
        quit;

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
        run;

        /* Check for populated baselinegroupnum parameter within specific analysis types */
        %if %sysfunc(prxmatch(m/T2L2|T4L2|T6/i,&reporttype.)) > 0 and %length(&chk_baselinegroupnum) > 0 %then %do;
         %put ERROR: (Sentinel) BASELINEGROUPNUM functionality is not available for REPORTTYPE = &reporttype. and must be set to missing.;
         %abort;
        %end;

        %end; /* m */

     %end; /* baselinefile */

/***************************************************************************************************
*   For L2 reports:
     1: Read in L2ComparisonFile
     2: For T4 reports: read in optional SelectionProbabilitiesFile
     3: create master PS/CS input file dataset    
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
        %end;
        %else %do;
            %put WARNING: (Sentinel) L2ComparisonFile is required when ReportType = T2L2 or T4L2 in order to produce effect estimates and PS histograms. Effect estimates and PS histograms will not be computed;
        %end;

        /****************************/
        /*SelectionProbabilitiesFile*/
        /****************************/
        %if %str("&reporttype") = %str("T4L2") %then %do;
        %isdata(dataset=input.&SelectionProbabilitiesFile.);
        %if %eval(&nobs.>0) %then %do;
            data SelectionProbabilitiesFile;
                set input.&SelectionProbabilitiesFile.;
                /*defensive*/
                analysisgrp=strip(lowcase(analysisgrp));
                runid=strip(lowcase(runid));
                value = upcase(value);
            run;
        %end;
        %end;
        
        /**********************************/
        /*Master PS/CS input file datasets*/
        /**********************************/

        /*Create shell table*/
        data pscs_masterinputs;
            length runid $5 file $32 analysisgrp psestimategrp eoi ref $40 ratio $1 strataweight $3 ipweight $4
                   caliper ceiling percentiles covarnum truncweight 8 unconditional $1.;
            call missing(runid, file, analysisgrp, psestimategrp, eoi, ref, covarnum, truncweight, ceiling, caliper, ratio, strataweight,
                   ipweight, percentiles, unconditional);
            stop;
        run;
        data psest_masterinputs;
            length runid $5 psestimategrp eoi ref $40;
            call missing(runid, psestimategrp, eoi, ref);
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
                if missing(covarnum) then covarnum = 0;
                keep runid file analysisgrp psestimategrp covarnum ceiling caliper ratio strataweight truncweight
                     ipweight percentiles eoi ref unconditional;
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
        %end;

        proc sort data=pscs_masterinputs nodupkey;
            by runid covarnum analysisgrp;
        run;
	%end;	
	
		
 /***************************************************************************
   Read in and Output TXT file for treelookup file per runid when it exists
  ***************************************************************************/
     %if %sysfunc(exist(input.&treeaggfile.)) %then %do;
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
	  %end; /* reporttypes are T2L2 T4L2 or TREE */ 
/***************************************************************************************************
*   Clean up                                                
***************************************************************************************************/

	 proc datasets noprint nowarn lib = work;
	  delete _:;
	 quit;
	
    %put =====> END MACRO: process_inputfiles;

%mend process_inputfiles;
