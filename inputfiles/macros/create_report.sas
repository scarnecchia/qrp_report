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

/*--------------------------------------------------------------------------------------------*/
/* Assign libnames, initialize global macro variables and read in input files                 */
/*--------------------------------------------------------------------------------------------*/

    /* Start log */
    proc printto log="&reportroot./output/qrp_report_output.log" new;
    run;

    %put =====> MACRO CALLED: create_report;

    %global output input infolder macros;

    /*Assign libname for output location*/
    %let output = &reportroot.output/;
    libname output "&output";

    /*Assign libname for inputfiles location*/
    %let input = &reportroot.inputfiles/;
    libname input "&input";

    /*Assign libname for macros location */
    %let macros = &reportroot.inputfiles/macros/;
    libname macros "&macros";

    /*clear work and output*/
    proc datasets nowarn nolist lib=work kill; quit;
    proc datasets nowarn nolist lib=output kill; quit;

    /*Initialize global macro variables*/
    %initialize_macro_variables();

    /*read in input files and process input file parameters*/
    %process_inputfiles();

/*--------------------------------------------------------------------------------------------*/
/* Clean Work                                                                                 */
/*--------------------------------------------------------------------------------------------*/

    proc datasets nowarn nolist lib=work kill; quit;

    /* End log */
    proc printto;
    run;
    
    %put =====> END MACRO: create_report ;

%mend create_report;