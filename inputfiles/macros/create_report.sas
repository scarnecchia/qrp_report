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
    
    /*Create report formats and labels*/
    %report_formats_labels();

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

***************************************************************************************************;
* Baseline tables                                                      
***************************************************************************************************;

    %baseline_driver();

***************************************************************************************************;
* Aggregate MSOC output tables from each DP                                                      
***************************************************************************************************;

	%aggregate_report_tables;

***************************************************************************************************;
*   Compute effect estimates for Reporttype = T2L2 and T4L2                                              
***************************************************************************************************;

    /*loop l2 processing by periodid*/
    %do periodid = %eval(&look_start.) %to %eval(&look_end.);
        %l2_effect_estimate_driver();

    %if %index(&reporttype,L2) and %index(&figurelist,F2) %then %do;
        %l2_forestplot_createdata;
    %end;

    %end;


***************************************************************************************************;
*   Output report                                                
***************************************************************************************************;

    /*Compile table of contents*/
    %create_tableofcontents();

    /*Create PDF and Excel templates*/
    %if %str("&sysscp.") = %str("WIN") %then %do;
	   %report_template(outputtype = excel, tablefontsize = 10pt, footfontsize=9pt, font = Calibri); 
	%end;
	%else %do;
	   %report_template(outputtype = excel, tablefontsize = 9pt, footfontsize=8pt, font = Arial); 
	%end;
	%report_template(outputtype = pdf, tablefontsize = 8pt, footfontsize=7pt, font= Arial); 

    /*driver macro*/
    %output_report();

***************************************************************************************************;
*   Clean Work                                                                                 
***************************************************************************************************;

    proc datasets nowarn nolist lib=work kill; quit;

    /* End log */
    proc printto;
    run;
    
    %put =====> END MACRO: create_report ;

%mend create_report;
