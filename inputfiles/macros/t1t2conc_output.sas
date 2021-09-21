****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t1t2conc_output.sas  
* Created (mm/dd/yyyy): 09/21/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of T1/T2 and Concomitant Tables proc report output
*                                        
*  Program inputs:                                                                                   
*   - final_[t1cida/t2cida/t2conc]
*   - final_dps_[t1cida/t2cida/t2conc]
* 
*  Program outputs: 
* 	- repdata.table&tablenum.&tableletter
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

%macro t1t2conc_output(dataset=);

%mend t1t2conc_output;