****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t4tables_driver.sas  
* Created (mm/dd/yyyy): 12/15/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The driver macro produces tables for a Type 4 report
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

%macro t4tables_driver();

    %put =====> MACRO CALLED: t4tables_driver ;
		%t4tables_createdata;

	%put =====> END MACRO: t4tables_driver ;

%mend t4tables_driver;
