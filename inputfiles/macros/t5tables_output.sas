****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t5tables_output.sas  
* Created (mm/dd/yyyy): 08/25/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro includes two proc report procedures in order to produce a categorical and 
*          continuous table in the report for Type 5 analyses
*                                        
*  Program inputs:                                                                                   
*   - Dataset(s) computed in %t5tables_createdata
* 
*  Program outputs: 
*   - Dataset(s) to output/repdata for each figure
* 
*  PARAMETERS:  
*   - dataset: input dataset
*   - report: indicator whether to produce categorical (1) or continuous (2) metrics
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

%macro t5tables_output();

	%put =====> MACRO CALLED: t5tables_output;

	%macro t5tables_output(dataset=,
						   report);

		





	%put =====> END MACRO: t5tables_output;

%mend;
