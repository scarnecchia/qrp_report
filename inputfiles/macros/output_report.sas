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
*   - bordersize = line thickness for top/bottom report lines
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

%macro output_report(destination = , font=, fontsize=, footfontsize=, bordersize=);

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
* Covariate profile tables                                                      
***************************************************************************************************;

    %if &numprofilecovarstoinclude > 0 %then %do;
    %baseline_profile_output;
	%let tablenum = %eval(&tablenum + 1);
    %end;

***************************************************************************************************;
* Effect estimate tables                                                      
***************************************************************************************************;

    %if %index(&reporttype,L2) %then %do;
    /* Need to set to landscape so PDF tables don't wrap */
    options orientation = landscape;
        %l2_effect_estimate_output;
    options orientation = portrait;
    %end;

***************************************************************************************************;
* Code distribution tables                                                     
***************************************************************************************************;
	%if &output_code_distribution. eq Y %then %do;
		%codedistribution_output;
		%let tablenum = %eval(&tablenum + 1);
	%end;

***************************************************************************************************;
* Attrition tables                                                     
***************************************************************************************************;

    %if %sysfunc(prxmatch(m/T1|T2L1|T2L2|T4L1|T4L2|T5|T6/i,&reporttype.)) %then %do;
        %if &look_start = 1 %then %do;
            %let look_end = 1;
            %do periodid = %eval(&look_start) %to %eval(&look_end);
            /* Check to see if either dataset exists */
            %isdata(dataset=agg_patient_attrition);
            %let attrition_patient = &nobs;
            %isdata(dataset=agg_episode_attrition);
            %let attrition_episode = &nobs;

                %if &attrition_patient > 0 or &attrition_episode > 0 %then %do;

                    /* reset counter to reset table letter */
                    %let tablecount=1;

                    %if (&attrition_patient > 0 and &attrition_episode = 0) or (&attrition_patient = 0 and &attrition_episode > 0) %then %do;
                        %let tablecount = 0;
                    %end;

                    options orientation = landscape;
                    %attrition_output(tabletype=episode);
                    %attrition_output(tabletype=patient);
                    options orientation = portrait;
                    %let tablenum = %eval(&tablenum + 1);
                    
                %end;
            %end;/*periodid */
        %end;/* Remove when Monitoring period bug is fixed in DEV-18262 */ 
    %end;

***************************************************************************************************;
* Figures                                                   
***************************************************************************************************;

    *********************************************;
    * L2 Reports: PS Histograms and Forest Plots                                                   
    *********************************************;
    %if %index(&reporttype,L2) %then %do;
        %if %index(&figurelist,F1) %then %do;
        %l2_psdistribution_output;
        %end;
        %if %index(&figurelist,F2) %then %do;
        %l2_forestplot_driver;
        %end;   
    %end; 

    ************************************************;
    * Kaplan-Meier and CDF Plots (L1 and L2 reports)                                                
    ************************************************;
    options orientation = landscape;

	%if %sysfunc(prxmatch(m/T5/i,&reporttype.)) %then %do;
	  /* Figures F1, F2, and F3 */
      %if %sysfunc(prxmatch(m/F1|F2|F3/i,&figurelist.)) > 0 %then %do;
        %let F123_figurelist = %sysfunc(tranwrd(&figurelist., %str(F5), %str()));
	   
        %do figure_list = 1 %to %sysfunc(countw(&F123_figurelist.)); 
		  
        %let current_figurelist = %scan(&F123_figurelist, &figure_list, ' ');

		/*set up titles for F123 figures */
        %if "&current_figurelist" = "F1" %then %do;
          %let title_f123 =  Patient Entry into Study by Month;
		  %let yvarF123 = npts;
		%end;
		%if "&current_figurelist" = "F2" %then %do;
          %let title_f123 =  Number of Prescription Dispensings in Patients First Episodes by Month Patient Entered into Study;
		  %let yvarF123 = adjustedcodecount;
		%end;
		%if "&current_figurelist" = "F3" %then %do;
          %let title_f123 =  Total Days Supply in Patients First Episodes by Month Patient Entered into Study;
          %let yvarF123 = daysupp;
        %end;

		/*loop through the figuresubs to create &current_figuresub*/ 
	    proc sql noprint;
          select distinct max(order) into: max_order separated by ' '
            from figurefile(where=(figure = "&current_figurelist"));
			select figuresub into: current_figuresub separated by ' '
            from figurefile(where=(figure = "&current_figurelist"))
            order by order;
			select y1label into: y1label separated by ' '
            from figurefile(where=(figure = "&current_figurelist"))
            order by order;
			select y2label into: y2label separated by ' '
            from figurefile(where=(figure = "&current_figurelist"))
            order by order;
			select distinct grouplabel into: grouplabel separated by ' '
            from figure123;
        quit;
		%do t = 1 %to &max_order;
		 
		
		  %tableletter();
		  %if "&current_figuresub" = "overall" %then %do; 
		    %let tableletter = ;
		  %end;
		  %let current_figuresub = %scan(&current_figuresub, &t, ' ');
		  %let current_y1label = %scan(&y1label, &t, ' ');
	      %let current_y2label = %scan(&y2label, &t, ' ');
		  %figure_t5_output(figure=&current_figurelist, figurenum=&figure_list, figureletter=&tableletter., 
                          title=%quote(&title_f123. for &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.),
                          where= figuresub = "&current_figuresub" and order = &t, figuresub=&current_figuresub, 
                          yaxislabel1= &current_y1label, yaxislabel2= &current_y2label, yvar=&yvarF123.);
		%end;
		%let tableorder = tableorder &t;
	  %end;
	%end;

	%end;
	
      %figure_cdf_km_output;
     options orientation = portrait;
    
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
