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

***************************************************************************************************;
* Table of Contents                                            
***************************************************************************************************;


***************************************************************************************************;
* Baseline tables                                                      
***************************************************************************************************;

***************************************************************************************************;
* Forest Plots                                                    
***************************************************************************************************;
   
    %if &outputforestplot = Y %then %do;
  /* Place holder code for figure number, this is subject to be moved and/or changed */
        %let forestfig=1;
        %forestplot_driver;
    %end; 

***************************************************************************************************;
* Appendices                                                                                
***************************************************************************************************;


***************************************************************************************************;
* Clean up                                                                                
***************************************************************************************************;

    ods _all_ close;
    ods listing;
    ods results;

    %put =====> END MACRO: output_report ;

%mend output_report;
