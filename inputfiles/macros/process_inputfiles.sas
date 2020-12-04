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

    %isdata(dataset=input.&createreportfile.);
    %if %eval(&nobs<1) %then %do;
        %put ERROR: (Sentinel) CREATEREPORTFILE is missing.;
        %put ERROR: (Sentinel) Make sure file is specified correctly and placed in the inputfiles folder;
        %abort;
    %end;

    /*Determine number of runs*/
    proc contents data=input.&createreportfile noprint out=&createreportfile;
    run;
       
        %global numparms;
        proc sql noprint;
            select count(*) into: numparms
            from input.&createreportfile;
        quit;

        *Reset all parameters;
        %let ReportType= ;
        %let small_cellcounts = ;
        %let redactevents = ;
        %let redactPT = ;
        %let stratifybyDP = ;
        %let seed = ;
        %let groupsfile = ;
        %let tablefile = ;
        %let figurefile = ;
        %let labelfile = ;
        %let itsregressionfile = ;
        %let treeaggfile = ;
        %let appendixfile = ;
        %let selectionprobabilities = ;
        %let CodeDescriptionsFile = ;
        %let TableColumnsFile = ;
        %let DPInfoFile = ;
        %let L2ComparisonsFile = ;

        /*Assign all parameters to macro variables*/
        %do createreportparameter = 1 %to %eval(&numparms.);
            data _null_;
                set input.&createreportfile;
                if _n_ = &createreportparameter. then do;
                    call symputx("parameter", parameter);
                    call symputx("value", value);
                end;
            run;
            %let &parameter. = &value.;
        %end;


        /*Check if DPINFOFILE exists, abort if it doesn't*/
        %isdata(dataset=input.&DPInfoFile.);
        %if %eval(&nobs.=0) %then %do; 
            %put ERROR: (Sentinel) DPINFOFILE is missing.;
            %put ERROR: (Sentinel) Make sure file is specified correctly and placed in the inputfiles folder;
            %abort;
        %end;

    %put =====> END MACRO: process_inputfiles;

%mend process_inputfiles;
