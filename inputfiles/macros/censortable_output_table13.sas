****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_output_table13.sas  
* Created (mm/dd/yyyy): 08/30/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro contains a proc report to produce 2 L1 censor tables
*                                        
*  Program inputs:                                                                                   
*   - t2censor
*   - t2followuptime
*   - t5censor
*   - t5censor_first
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:       
*   - tablename: input dataset name
*   - tablenum: table number
*   - title: table title in report
*   - where: where clause to restrict input dataset
*            
*  Programming Notes:         
*   
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro censortable_output_table13(tablename=, tablenum=, title=, where=);

    %put =====> MACRO CALLED: censortable_output_table13;








%mend censortable_output_table13;
