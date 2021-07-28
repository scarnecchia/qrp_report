****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_cdf_km_output.sas  
* Created (mm/dd/yyyy): 07/28/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro includes a proc sgplot to produce Kaplan-Meier and Cumulative Distribution
*          Function (CDF) curves with an at-risk table
*                                        
*  Program inputs:                                                                                   
*   - Dataset(s) computed in figure_cdf_km_createdata.sas (L1 plots) or 
*     l2_effect_estimate_km_createdata.sas (L2 plots)
* 
*  Program outputs: 
*   - Dataset(s) to output/repdata for each figure
* 
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

%macro figure_cdf_km_output();

	%put =====> MACRO CALLED: figure_cdf_km_output;


	%put =====> END MACRO: figure_cdf_km_output;

%mend;
