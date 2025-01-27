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

    %put =====> MACRO CALLED: create_report;

    /* If leave behind report runs then use reportid for log suffix */
    %if &leavebehindreport = Y %then %do;
    /* Start log */
       proc printto log="&output.qrp_report_log&reportid..log" new;
       run;
    %end;

	%else %do;
    /* Need to retain work datasets from qrp for leave behind report.
       Repdata is set to work directory when leave behind report is run,
	   and data for qrp report is in the msocdata folder	*/
	   proc datasets nowarn nolist lib=work kill; quit;
	   proc datasets nowarn nolist lib=repdata kill; quit;
	   proc datasets nowarn nolist lib=msocdata kill; quit; 

        /*read in JSON file and determine if there are any CSV files*/
        %convert_inputfiles(lib=&INFOLDER, JSON_LIB=&infolder.macros/integration);
        %convert_inputfiles(lib=&REPORTROOT.inputfiles/, JSON_LIB=&input.macros/integration);

       proc printto log="&output.qrp_report_log.log" new;
	%end;
	
    /*Initialize global macro variables*/
    %initialize_macro_variables();

    /*read in input files and process input file parameters*/
    %process_inputfiles();

	/*check if only appendixfile should be processed*/
	%if &produceappendixfileonly. = Y %then %goto format_labels;

***************************************************************************************************;
* Create concatenated libname for each DP and output DP metadata                                                      
***************************************************************************************************;

    %createlibref(dplist = &random_dplist.,
                  dpinfofile = dpinfofile, 
                  dataroot = &dataroot.,
                  signaturefile =%scan(&runidlist,1)_signature);

    /*Drop requestID tokens from dpinfo file*/
    data output.dpinfo;
        set output.dpinfo(drop=projid wptype wpid dpid);
    run;
	
***************************************************************************************************;
*   Assign study start and end dates                                               
***************************************************************************************************;

    %output_report_dates();

***************************************************************************************************;
*   Create report formats and labels                                           
***************************************************************************************************;

	%format_labels:    

    %report_formats_labels();

	%if &produceappendixfileonly. = Y %then %goto createtoc;

***************************************************************************************************;
* Baseline tables                                                      
***************************************************************************************************;

    %baseline_driver();
    
***************************************************************************************************;
* Aggregate MSOC output tables from each DP                                                      
***************************************************************************************************;

	%aggregate_report_tables;
    
***************************************************************************************************;
*   Calculate L1 summary tables                                             
***************************************************************************************************;
    %isdata(dataset=tablefile);
    %if %eval(&nobs.>0) %then %do;

    /*ReportType T1, T2L1, T4L1 and T5*/
    %if %sysfunc(prxmatch(m/T1|T2L1|T4L1|T5/i,&reporttype.)) & %eval(&tdatasetlistnum. > 0) %then %do;
	   %do td = 1 %to &tdatasetlistnum.; 
	      %let reporttable = %scan(&tdatasetlist, &td.);
		  
          /* Report Type T1, T2L1 and T4L1 summary tables (T1cida, T2cida or T4cida) */
          %if &reporttable. = t1cida | &reporttable. = t2cida | &reporttable = t4cida %then %do;
            %t1t2t4conc_createdata(table = &reporttable., grpvar = group);
          %end;
		  
          /* Concomitant episodes tables */
          %if &reporttable. = t2conc %then %do;
            %t1t2t4conc_createdata(table = &reporttable., grpvar = analysisgrp);
          %end;

          /*Censor tables - Types 1, 2, and 5*/
          %if %sysfunc(prxmatch(m/t1censor|t2censor|t2followuptime|t5censor/i,&reporttable.)) > 0 %then %do;
            %isdata(dataset=agg_&reporttable.);
            %if %eval(&nobs.>0) %then %do;
            proc sql noprint;
                select distinct quote(strip(table)) into: censortablelist separated by ' '
                from tablefile(where=(dataset="&reporttable."));
            quit;
            %censortable_createdata_t1t2t5(tables=&censortablelist., censordataset = &reporttable.);
            %end;
          %end;

       %end;
    %end;
    
	/*ReportType T4*/
	%if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
	     /* Create data for T4Preg and T4NoPreg datasets */
		 %if %sysfunc(findw(&datasetlist,t4preg)) | %sysfunc(findw(&datasetlist,t4nopreg)) %then %do;
	       %t4tables_createdata(dataset = preg, output_suffix = _t4moi, episode_var=episodes);
		 %end;
	     /* Create data for T4Preggestwk and T4NoPreggestwk datasets */
		 %if %sysfunc(findw(&datasetlist,t4preggestwk)) | %sysfunc(findw(&datasetlist,t4nopreggestwk)) %then %do;
	       %t4tables_createdata(dataset = preggestwk, output_suffix = _t4gestwk, episode_var = pregepisodes);
		 %end;
	%end;
	
    /*ReportType T5*/
	%if %str("&reporttype") = %str("T5") %then %do;
	   %t5tables_driver();
	%end;

    /*ReportType T6*/
	%if %str("&reporttype") = %str("T6") %then %do;
	   %t6tables_driver();
	%end;

    %end; /*tablefile exists*/

***************************************************************************************************;
*   Compute L1 figures                                            
***************************************************************************************************;

    %if %str("&figurelist.") ne %str("") & %sysfunc(prxmatch(m/T1|T2L1|T5|T6/i,&reporttype.)) %then %do;
        %figure_l1_driver();
    %end;
        
***************************************************************************************************;
*   Compute effect estimates, forest plot, and PS Histograms dataset for Reporttype = T2L2 and T4L2                                              
***************************************************************************************************;
    /*loop l2 processing by periodid*/
    %do periodid = %eval(&look_start.) %to %eval(&look_end.);		
		%l2_effect_estimate_driver();
		%if %index(&reporttype,L2) and %index(&figurelist,F1) %then %do;
			%l2_psdistribution_createdata;
		%end;
        %if %index(&reporttype,L2) and %index(&figurelist,F2) and &treeaggindicator. eq N %then %do;
            %l2_forestplot_createdata;
        %end;
    %end;

***************************************************************************************************;
* Attrition tables                                                      
***************************************************************************************************;
    %do periodid = %eval(&look_start) %to %eval(&look_end);
        %attrition_createdata;
    %end;

***************************************************************************************************;
*   Compute code distribution tables                                                     
***************************************************************************************************;
	%if &output_code_distribution. eq Y %then %do;		
		%codedistribution_createdata;
	%end;
	
***************************************************************************************************;
*   Compile table of contents                                            
***************************************************************************************************;
%createtoc:

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
        %output_report(destination = excel,font=calibri, fontsize=10pt, footfontsize=9pt, bordersize=6pt);
        %end;
        /*non-windows: report font = arial, font size = 9, footnote fontsize = 8*/
        %else %do;
        %output_report(destination = excel,font=arial, fontsize=9pt, footfontsize=8pt, bordersize=6pt);
        %end;
    %end;

    /*PDF*/
    %if "&report_destination." = "BOTH" | "&report_destination." = "PDF"  %then %do;
        /*all systems: report font = arial, font size = 8, footnote fontsize = 7*/
        %output_report(destination = pdf,font=arial, fontsize=8pt, footfontsize=7pt, bordersize=2pt);
    %end;
      
***************************************************************************************************;
*   Create analytic datasets that can be used as inputs to TreeScan software                                             
***************************************************************************************************;
    /*loop aggregate tree processing by periodid*/
    %if &treeaggindicator. eq Y %then %do;
      %do periodid = %eval(&look_start.) %to %eval(&look_end.);
        %aggregate_tree();
      %end;
    %end;		

/*************************************************************************************************/
/* Run log checker                                                                               */
/*************************************************************************************************/
	
    %if &leavebehindreport = N %then %do;
	  proc printto log="&output.log_checker.log" new;
      run;

	   %ms_logchecker(logdir =&output., logdir_out=output, logname=qrp_report_log.log );
	%end;

***************************************************************************************************;
*   Clean directories                                                                                 
***************************************************************************************************;

    proc datasets nowarn nolist lib=work kill; quit;

    /*remove filenames datasets if created*/
    %if &leavebehindreport = N %then %do;
    proc datasets nowarn nolist lib=input;
        delete filenames format_values;
    quit;
    proc datasets nowarn nolist lib=infolder;
        delete filenames format_values;
    quit;
    %end;

    /* End log */
    proc printto;
    run;
    
    %put =====> END MACRO: create_report ;

%mend create_report;
