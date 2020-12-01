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
*   -Macro variables read in from CREATEREPORT_FILE and CREATEPLOTS_FILE 
*    are set to global in processinputfiles.sas                                                                        
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro initialize_macro_variables();

    %put =====> MACRO CALLED: initialize_macro_variables ;

    /* Input file paramaters*/
    %global groupsfile baselinefile tablefile figurefile labelfile itsregressionfile treeaggfile 
            appendixfile selectionprobabilities CodeDescriptionsFile TableColumnsFile DPInfoFile L2ComparisonsFile;

    %let groupsfile=;
    %let baselinefile=;
    %let tablefile=;
    %let figurefile=;
    %let labelfile=;
    %let itsregressionfile=;
    %let treeaggfile=;
    %let appendixfile=;
    %let selectionprobabilities=;
    %let CodeDescriptionsFile=;
    %let TableColumnsFile=;
    %let DPInfoFile=;
    %let L2ComparisonsFile=;

    /* Report parameters */
    %global reporttype small_cellcounts redactevents redactPt stratifybydp seed look_start look_end;

    %let reporttype=;
    %let small_cellcounts=;
    %let redactevents=;
    %let redactPt=;
    %let stratifybydp =;
    %let seed=.;
    %let look_start=.;
    %let look_end=.;

    %put =====> MACRO ENDED: initialize_macro_variables ;

%mend initialize_macro_variables;
