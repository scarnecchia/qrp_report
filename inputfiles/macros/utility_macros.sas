****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: utility_macros.sas  
*
* Created (mm/dd/yyyy): 12/20/2015
* Last modified: 12/1/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program includes the following macros:
*   - %isdata() macro determines whether a dataset is empty or not
*
*  Program inputs:                                                                                   
*   -
* 
*  Program outputs:                                                                                                                                       
*   -
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

*Macro to determine whether a dataset is empty or not;
%MACRO ISDATA(dataset=);
    %GLOBAL NOBS;
    %let NOBS=0;
    %if %sysfunc(exist(&dataset.))=1 and %LENGTH(&dataset.) ne 0 %then %do;
        data _null_;
        dsid=open("&dataset.");
        call symputx("NOBS",attrn(dsid,"NLOBS"));
        run;
    %end;   
%PUT &NOBS.;
%MEND ISDATA;