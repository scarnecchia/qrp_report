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
*   - list of plots to create
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

%macro l2_effect_estimate_km_createdata(individualreturn=, plotstocreate=);

	%put =====> MACRO CALLED: l2_effect_estimate_km_createdata;

    /*loop through each plot*/
    %do p = 1 %to %sysfunc(countw(&plotstocreate.));
        %let plot = %scan(&plotstocreate., &p.);

        /*--------------------------------------------------------------------------------------------*/
        /* Patient level data                                                                         */
        /*--------------------------------------------------------------------------------------------*/
        %if &individualreturn. = Y %then %do;
/*            data step0;*/
/*                set aggpl;*/
/*                pat = 1;*/
/*                keep matchid event followuptime exposure pat;*/
/*            run;*/

            /*For conditional analysis, restrict to informative events*/
            %if &plot. = Conditional %then %do;


            %end;


           






        /*Clean up*/

        %end; /*patient level data*/

        /*--------------------------------------------------------------------------------------------*/
        /* Risk set level data                                                                        */
        /*--------------------------------------------------------------------------------------------*/
        %else %if &individualreturn. = N %then %do;








        /*Clean up*/

        %end; /*risk set data*/

    %end; /*loop through each plot*/

	%put =====> END MACRO: l2_effect_estimate_km_createdata;

%mend;
