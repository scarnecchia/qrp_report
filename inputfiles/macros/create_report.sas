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

***************************************************************************************************;
* Initialize global macro variables and read in input files                                  
***************************************************************************************************;

    /* Start log */
    proc printto log="&reportroot.output/qrp_report_log.log" new;
    run;

    %put =====> MACRO CALLED: create_report;

    /*clear work and output*/
    proc datasets nowarn nolist lib=work kill; quit;
    proc datasets nowarn nolist lib=output kill; quit;

    /*Initialize global macro variables*/
    %initialize_macro_variables();

    /*read in input files and process input file parameters*/
    %process_inputfiles();

***************************************************************************************************;
* Create concactenated libname for each DP and output DP metadata                                                      
***************************************************************************************************;

    %createlibref(dplist = &random_dplist.,
                  dpinfofile = dpinfofile, 
                  dataroot = &dataroot.,
                  signaturefile =%scan(&runidlist,1)_signature);




***************************************************************************************************;
*   Assign study start and end dates                                               
***************************************************************************************************;

    %output_report_dates();

/*--------------------------------------------------------------------------------------------*/
/* Clean Work                                                                                 */
/*--------------------------------------------------------------------------------------------*/

    proc datasets nowarn nolist lib=work kill; quit;

    /* End log */
    proc printto;
    run;
    
    %put =====> END MACRO: create_report ;

%mend create_report;
