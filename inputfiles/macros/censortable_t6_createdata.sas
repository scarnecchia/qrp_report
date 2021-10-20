****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_t6_createdata.sas  
* Created (mm/dd/yyyy): 10/20/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro aggregates censoring table data for type6
*                                        
*  Program inputs:   
*   - agg_t6censor.sas7bdat                                                                                
*   - agg_switchplota.sas7bdat
*   - agg_switchplotb.sas7bdat  
*   
*  Program outputs:             
*   - 
*
*  PARAMETERS:
*
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

%macro censortable_t6_createdata;

  %put =====> MACRO CALLED: censortable_t6_createdata;


   
   /* Clean up work files */
/*    proc datasets lib=work nowarn nolist noprint;*/
/*       delete ;*/
/*    quit;*/

   %put =====> END MACRO: censortable_t6_createdata;

%mend censortable_t6_createdata;
