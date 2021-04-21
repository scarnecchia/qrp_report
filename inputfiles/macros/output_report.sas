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
*   - destination: ODS destination. Valid values: excel or pdf
*   - font: font
*   - fontsize = font size
*   - footfontsize  = font size for footnotes, typically set as 1 pt smaller than fontsize
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

%macro output_report(destination = , font=, fontsize=, footfontsize=);

    %put =====> MACRO CALLED: output_report;

***************************************************************************************************;
* Set up and initialize report template                                            
***************************************************************************************************;

    /*report template*/
    %report_template(outputtype = &destination., fontsize = &fontsize., font = &font.); 

    ods listing close;
    ods select all;
    ods noresults;
    options nodate nonumber orientation = landscape;
    %if &destination. = excel %then %do;
    ods excel file="&REPORTROOT.output/qrp_report.xlsx" NOGTITLE style = qrp_report_excel
        options(embedded_titles="yes"
            sheet_interval="proc"
            gridlines="off"
            frozen_headers = "yes"
            embedded_footnotes= "yes" 
            flow="tables");
    %end;
    %if &destination. = pdf %then %do;
    ods pdf file="&REPORTROOT.output/qrp_report.pdf" NOGTITLE dpi=300 pdftoc=1 style = qrp_report_pdf;
    %end;

    ods noproctitle;
    options nodate nonumber orientation=portrait;
    ods escapechar="^";
    title;

    /* Counter for figure number */
    %let figurenum=1;

    /* Counter for table number */
    %let tablenum=1;

***************************************************************************************************;
* Table of Contents                                            
***************************************************************************************************;  
    %if &destination. = excel %then %do;
    ods excel options(sheet_name="Table of Contents"
	                  tab_color = "orange");
	%end;
    ods proclabel = "Table of Contents";

    proc report data = tableofcontents nofs nowd headline headskip split="*" 
	    style(report) = {rules = none frame = box borderwidth =1pt bordercolor = black cellpadding=1.75pt};           
        columns ( "Table of Contents" tabnum caption);            
        define tabnum / order=data ' ' style(column)=[just=R width=1.1in fontweight=bold textdecoration=underline];
        define caption / order=data  ' ' style(column)=[just=L];
    run;

***************************************************************************************************;
* Baseline tables                                                      
***************************************************************************************************;

    %baseline_output();

***************************************************************************************************;
* Effect estimate tables                                                      
***************************************************************************************************;

    %if %index(&reporttype,L2) | &reporttype. = TREE2) | &reporttype. = TREE4 %then %do;
    /* Need to set to landscape so PDF tables don't wrap */
    options orientation = landscape;
        %l2_effect_estimate_output;
    options orientation = portrait;
    %end;

***************************************************************************************************;
* PS Histograms                                                    
***************************************************************************************************;

    %if (%index(&reporttype,L2) | &reporttype. = TREE2 | &reporttype. = TREE4)) and %index(&figurelist,F1) %then %do;
        %l2_psdistribution_output;
    %end; 

***************************************************************************************************;
* Forest Plots                                                    
***************************************************************************************************;
   
    %if (%index(&reporttype,L2) | &reporttype. = TREE2 | &reporttype. = TREE4)) and %index(&figurelist,F2) %then %do;
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
