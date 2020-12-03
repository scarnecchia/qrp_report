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

***************************************************************************************************;
*   Read in CREATEREPORTFILE and assign each parameter to a run level macro variable                                                  
***************************************************************************************************;

    %isdata(dataset=input.&createreportfile.);
    %if %eval(&nobs<1) %then %do;
        %put ERROR: (Sentinel) CREATEREPORTFILE is missing.;
        %put ERROR: (Sentinel) Make sure file is specified correctly and placed in the inputfiles folder;
        %abort;
    %end;

    /*Read in CREATEREPORTFILE and assign macro variables*/
    data _null_;
        set input.&createreportfile.;
        call symputx('ReportType', upcase(reporttype), 'G');
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


    %put =====> END MACRO: process_inputfiles;

%mend process_inputfiles;
