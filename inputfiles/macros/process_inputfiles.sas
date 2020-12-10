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
                    call symputx("parameter", parameter);
                    call symputx("value", value);
                    if lowcase(parameter) in ('reporttype','stratifybydp','small_cellcounts') then call symputx("value",upcase(value));
                end;
            run;
            %let &parameter. = &value.;
        %end;

/************************************************************************************************************************************
*   Read in DPINFOFILE and mask DPs                                                     
************************************************************************************************************************************/

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
            set input.&DPInfoFile.(where=(upcase(includeDP)='Y'));
            call symputx('num_dp', _n_);
            dp=lowcase(dp);
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
        quit;
    %end;
	
/************************************************************************************************************************************
*   Read in the qrp parameters file and assign parameter to macro variables                                                 
************************************************************************************************************************************/
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
	     %if %sysfunc(exist(input.&l2comparisonsfile.)) %then %do;
		   input.&l2comparisonsfile. (keep = runid)
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
		      ,runid
	    into: numrunid
		     ,:runidlist separated by ' '
        from input.&groupsfile.
        group by runid;
        
		%let numrunid = &numrunid.;

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
	 
	 proc datasets noprint lib = work;
	  delete _:;
	 quit;
	
    %put =====> END MACRO: process_inputfiles;

%mend process_inputfiles;