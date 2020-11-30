****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_report.sas  
* Created (mm/dd/yyyy): 11/30/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of QRP reports
*                                        
*  Program inputs:                                                                                   
*
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

%macro create_report();

    /* Start log */
    proc printto log="&reportroot./output/qrp_report_output.log" new;
    run;

    %put =====> MACRO CALLED: create_report;

    %global output input infolder macros;

    /* If reportroot is missing, assign default path */
    %if %length(&reportroot) = 0 %then %do;
    %let rc = %sysfunc(filename(fr,.));
    %let reportroot = %sysfunc(pathname(&fr.));
    /* Find all \ slashes and turn them into / for both Windows/Unix compatibility */
    %let reportroot = %sysfunc(tranwrd(&reportroot,\,/));
    /* Remove inputfiles/macros subdirectory to get root path */
    %let reportroot = %sysfunc(tranwrd(&reportroot,inputfiles/macros,/));
    %let rc= %sysfunc(filename(fr));
    %end;

    %let reportroot = %soc_clean_paths(&reportroot.);

    /*Assign libname for output location*/
    %let output = &reportroot.output/;
    libname output "&output";

    /*Assign libname for inputfiles location*/
    %let input = &reportroot.inputfiles/;
    libname input "&input";

    /*Assign libname for macros location */
    %let macros = &reportroot.inputfiles/macros/;
    libname macros "&macros";

    /*Assign libname for package infolder*/
    libname infolder "&infolder.";

    /*clear work and output*/
    proc datasets nowarn nolist lib=work kill; quit;
    proc datasets nowarn nolist lib=output kill; quit;

/*--------------------------------------------------------------------------------------------*/
/* Clean Work                                                                              */
/*--------------------------------------------------------------------------------------------*/

    proc datasets nowarn nolist lib=work kill; quit;

    /* End log */
    proc printto;
    run;
    
    %put =====> END MACRO: create_report ;

%mend create_report;