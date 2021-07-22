****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_km_createdata.sas  
* Created (mm/dd/yyyy): 07/22/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro computes Kaplan-Meier estimates for PS Match and PS Stratification analysis
*                                        
*  Program inputs:                                                                                   
*   - Either a patient level or risk set level dataset
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:  
*   - individualreturn: Y or N
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

%macro l2_effect_estimate_km_createdata(individualreturn=);

	%put =====> MACRO CALLED: l2_effect_estimate_km_createdata;

    /*--------------------------------------------------------------------------------------------*/
    /* Patient level data                                                                         */
    /*--------------------------------------------------------------------------------------------*/
    %if &individualreturn. = Y %then %do;






    /*Clean up*/

    %end; /*patient level data*/

    /*--------------------------------------------------------------------------------------------*/
    /* Risk set level data                                                                        */
    /*--------------------------------------------------------------------------------------------*/
    %else %if &individualreturn. = N %then %do;








    /*Clean up*/

    %end;

	%put =====> END MACRO: l2_effect_estimate_km_createdata;

%mend;
