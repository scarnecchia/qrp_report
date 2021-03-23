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

***************************************************************************************************;
*   Create report formats and labels                                           
***************************************************************************************************;

    %report_formats_labels();

***************************************************************************************************;
* Baseline tables                                                      
***************************************************************************************************;

    %baseline_driver();

***************************************************************************************************;
* Aggregate MSOC output tables from each DP                                                      
***************************************************************************************************;

	%aggregate_report_tables;

***************************************************************************************************;
*   Compute effect estimates and forest plot dataset for Reporttype = T2L2 and T4L2                                              
***************************************************************************************************;

    /*loop l2 processing by periodid*/
    %do periodid = %eval(&look_start.) %to %eval(&look_end.);
        %l2_effect_estimate_driver();
        %if %index(&reporttype,L2) and %index(&figurelist,F2) %then %do;
            %l2_forestplot_createdata;
        %end;
    %end;

***************************************************************************************************;
*   Compile table of contents                                            
***************************************************************************************************;

    %create_tableofcontents();

***************************************************************************************************;
*   Create appendices                                           
***************************************************************************************************;

    %appendix_driver();

***************************************************************************************************;
*   Output report                                                
***************************************************************************************************;

    /*Excel*/
    %if "&report_destination." = "BOTH" | "&report_destination." = "EXCEL"  %then %do;
        /*windows: report font = Calibri, font size = 10, footnote fontsize = 9*/
        %if %str("&sysscp.") = %str("WIN") %then %do;
        %output_report(destination = excel,font=calibri, fontsize=10pt, footfontsize=9pt);
        %end;
        /*non-windows: report font = arial, font size = 9, footnote fontsize = 8*/
        %else %do;
        %output_report(destination = excel,font=arial, fontsize=9pt, footfontsize=8pt);
        %end;
    %end;

    /*PDF*/
    %if "&report_destination." = "BOTH" | "&report_destination." = "PDF"  %then %do;
        /*all systems: report font = arial, font size = 8, footnote fontsize = 7*/
        %output_report(destination = pdf,font=arial, fontsize=8pt, footfontsize=7pt);
    %end;


    /*Create PDF and Excel templates*/

    /*driver macro*/

***************************************************************************************************;
*   Clean Work                                                                                 
***************************************************************************************************;

    proc datasets nowarn nolist lib=work kill; quit;

    /* End log */
    proc printto;
    run;
    
    %put =====> END MACRO: create_report ;

%mend create_report;
