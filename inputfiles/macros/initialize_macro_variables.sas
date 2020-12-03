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

    %put =====> MACRO ENDED: initialize_macro_variables ;

%mend initialize_macro_variables;
