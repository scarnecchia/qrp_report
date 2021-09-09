****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_t5_output.sas  
* Created (mm/dd/yyyy): 09/08/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Produce type 5 figures F1-F3
*
*  Program inputs:                                                                                   
*  	- figure123.sas7bdat
* 
*  Program outputs:                                                                                                                           
*   - N/A
* 
*  PARAMETERS: 
*   -figurenum: figure number
*   -title: figure title
*   -where: where clause to restrict figure123.sas7bdat
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

%macro figure_t5_output(figurenum=, title=, where=);

	%put =====> MACRO CALLED: figure_t5_output;

    /*Save dataset to REPORTDATA folder*/
    %isdata(dataset=repdata.figure&tablenum.);
    %if %eval(&nobs.<1) %then %do;
        data repdata.figure&tablenum.;
            set figure123(where=(&where.));
        run;
    %end;
   





	%put =====> END MACRO: figure_t5_output;

%mend figure_t5_output;
