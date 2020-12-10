****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: initialize_macro_variables.sas  
* Created (mm/dd/yyyy): 11/30/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro initializes global macro variables
*
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*
*  PARAMETERS:                                                                       
*            
*  Programming Notes:                                                                                
*   -Macro variables read in from CREATEREPORTFILE are set to global in processinputfiles.sas                                                                        
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro initialize_macro_variables();

    %put =====> MACRO CALLED: initialize_macro_variables ;

    /*variables related to DPs*/
    %global num_dp random_dplist;
    %let num_dp = 0; 

    /*variables related to query*/
    %global runidlist;
    %let runidlist = r01; /*temporary - remove when runidlist implemented*/

    /*variables related to createreport input file*/
    %global ReportType small_cellcounts redactevents redactPT stratifybyDP seed groupsfile baselinefile tablefile
            figurefile labelfile itsregressionfile treeaggfile appendixfile selectionprobabilities
            CodeDescriptionsFile TableColumnsFile DPInfoFile L2ComparisonsFile;

    %let ReportType= ;
    %let small_cellcounts = ;
    %let redactevents = ;
    %let redactPT = ;
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
    %let selectionprobabilities = ;
    %let CodeDescriptionsFile = ;
    %let TableColumnsFile = ;
    %let DPInfoFile = ;
    %let L2ComparisonsFile = ;

    %put =====> MACRO ENDED: initialize_macro_variables ;

%mend initialize_macro_variables;
