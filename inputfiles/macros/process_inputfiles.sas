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

    /*Read in CREATEREPORT_FILE and assign macro variables*/
    data _null_;
        set input.&createreportfile.;
        call symputx('ReportType', reporttype, 'G');
        call symputx('small_cellcounts',upcase(small_cellcounts),'G');
        call symputx('redactevents',redactevents,'G');
        call symputx('redactPT',redactPT,'G');
        /*DP stratification*/
        call symputx('stratifybyDP', upcase(stratifybyDP), 'G');
        call symputx('seed', seed, 'G');
        /* Report input files */
        call symputx('groupsfile', groupsfile, 'G');
        call symputx('baselinefile', baselinefile, 'G');
        call symputx('tablefile', tablefile, 'G');
        call symputx('figurefile', figurefile, 'G');
        call symputx('labelfile', labelfile, 'G');
        call symputx('itsregressionfile', itsregressionfile, 'G');
        call symputx('treeaggfile', treeaggfile, 'G');
        call symputx('appendixfile', appendixfile, 'G');
        call symputx('selectionprobabilities',selectionprobabilities,'G');
        call symputx('CodeDescriptionsFile',CodeDescriptionsFile,'G');
        call symputx('TableColumnsFile',TableColumnsFile,'G');
        call symputx('DPInfoFile', DPInfoFile, 'G');
        call symputx('L2ComparisonsFile',L2ComparisonsFile,'G');
        /*Look periods in report*/
        call symputx('look_start', look_start, 'G');
        call symputx('look_end', look_end, 'G');
    run;

    /*Check if DPINFOFILE exists, abort if it doesn't*/
    %isdata(dataset=input.&DPInfoFile.);
    %if %eval(&nobs.=0) %then %do; 
        %put ERROR: (Sentinel) DPINFOFILE is missing.;
        %put ERROR: (Sentinel) Make sure file is specified correctly and placed in the inputfiles folder;
        %abort;
    %end;

    %put =====> END MACRO: process_inputfiles;

%mend process_inputfiles;
