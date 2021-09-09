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
*   - 
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

%macro figure_t5_output();

	%put =====> MACRO CALLED: figure_t5_output;

    /*--------------------------------------------------------------------------------------------*/
    /* Dataset exists                                                                             */
    /*--------------------------------------------------------------------------------------------*/

    %isdata(dataset=figure123);
    %if %eval(&nobs.>0) %then %do;
    
   




    %end; /*figure123 exists*/

	%put =====> END MACRO: figure_t5_output;

%mend figure_t5_output;
