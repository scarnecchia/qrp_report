****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: output_report.sas  
* Created (mm/dd/yyyy): 02/24/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the calling of each macro to produce a report
*                                        
*  Program inputs:                                                                                   
*
* 
*  Program outputs:                                                                                                                                       
*   - qrp_report.pdf
*   - qrp_report.xlsx
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

%macro output_report();

    %put =====> MACRO CALLED: output_report;

***************************************************************************************************;
* Set up                                            
***************************************************************************************************;

    ods listing close;
    ods select all;
    ods noresults;
    options nodate nonumber orientation = landscape;
    ods excel file="&REPORTROOT.output/qrp_report.xlsx" NOGTITLE style = qrp_report_excel
        options(embedded_titles="yes"
            sheet_interval="proc"
            gridlines="off"
            frozen_headers = "yes"
            embedded_footnotes= "yes" 
            flow="tables");
    ods pdf file="&REPORTROOT.output/qrp_report.pdf" NOGTITLE dpi=300 pdftoc=1 style = qrp_report_pdf;
    ods noproctitle;
    options nodate nonumber orientation=portrait;
    ods escapechar="^";
    title;

/* Counter for figure number */
    %let figurenum=1;

***************************************************************************************************;
* Table of Contents                                            
***************************************************************************************************;


***************************************************************************************************;
* Baseline tables                                                      
***************************************************************************************************;

    %baseline_output();

***************************************************************************************************;
* Forest Plots                                                    
***************************************************************************************************;
   
    %if %index(&reporttype,L2) and %index(&figurelist,F2) %then %do;
        %l2_forestplot_driver;
    %end; 

***************************************************************************************************;
* Appendices                                                                                
***************************************************************************************************;

    %appendix_output();

***************************************************************************************************;
* Clean up                                                                                
***************************************************************************************************;

    ods _all_ close;
    ods listing;
    ods results;

    %put =====> END MACRO: output_report ;

%mend output_report;
