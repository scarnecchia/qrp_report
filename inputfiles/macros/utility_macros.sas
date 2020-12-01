****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: utility_macros.sas  
*
* Created (mm/dd/yyyy): 12/20/2015
* Last modified: 06/30/2019
* Version: 1.2
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program includes two macros:
*   - %isdata() macro determines whether a dataset is empty or not
*   - &colmaxmin() macro runs a proc means
*   - %createcovarlabel() macro takes a covariate input file and creates dataset with COVARNUM and a label
*   - %recodecovars() macro creates a list of covariates to correctly group in output
*   - %create_comma_charlist() macro creates a list of variables, each in quotation marks and separated by a comma
*   - %tableletter() macro dynamically increases table numbering              
*   - %soc_clean_paths()
*   - %soc_dirExist()
*   - %soc_quotepath()
*   - %soc_lib()
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
*--------------------------------------------------------------------------------------------------
*  CHANGE LOG: 
*
*   Version   Date       Initials      Comment (reference external documentation when available)
*   -------   --------   --------   ---------------------------------------------------------------
*   1.1       10/30/17   AP         Made length of covariate labels data-driven
*
*   1.2       06/30/19   AP         Add SOC setup macros
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