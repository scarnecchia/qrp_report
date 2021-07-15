****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_cdf_km_createdata.sas  
* Created (mm/dd/yyyy): 07/14/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro computes Kaplan-Meier and Cumulative Distribution Function (CDF) estimates
*                                        
*  Program inputs:                                                                                   
*   - MSOC dataset containing 1 row per day and columns containing counts of episodes censored
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:  
*   - dataset: aggregate dataset from %aggregate_report_tables
*   - curve: KM or 1-CDF
*   - whereclause: where statement to restrict &dataset
*   - dayvar: variable name for censor day variable
*   - includegroups: Groups to include in report
*   - includevars: censor reasons to include in final dataset
*   - figure: standard figure # from FIGUREFILE
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

%macro figure_cdf_km_createdata(dataset=, 
                                curve=, 
                                whereclause=, 
                                dayvar=,
                                includegroups=,
                                includevars=,
                                figure=);

	%put =====> MACRO CALLED: figure_cdf_km_createdata;

    /*--------------------------------------------------------------------------------------------*/
    /* Select rows and columns and aggregate data                                                 */
    /*--------------------------------------------------------------------------------------------*/

    proc means data=&dataset.(where=(&whereclause.)) nway noprint;
        var episodes &includevars.;
        class runid group &dayvar. / missing;
        output out=_kmcdfdata(drop=_: where=(missing(&dayvar.)=0)) sum=;
    run;

    /*--------------------------------------------------------------------------------------------*/
    /* Square data to include 1 row per day                                                       */
    /*--------------------------------------------------------------------------------------------*/


















































	%put =====> END MACRO: baseline_aggregate;

%mend;
