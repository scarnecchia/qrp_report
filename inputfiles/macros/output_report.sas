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
* T1/T2/Concomitant Use tables                                                      
***************************************************************************************************;
    %if %sysfunc(prxmatch(m/T1|T2L1/i,&reporttype.)) & %eval(&tdatasetlistnum. > 0) %then %do;
        /* Report Type T1 summary tables and Report Type T2L1 tables (T1cida or T2cida) */
          %if %sysfunc(prxmatch(m/t1cida|t2cida|t2conc/i,&tdatasetlist.)) %then %do;
          %do td = 1 %to &tdatasetlistnum.; 
            %let reporttable = %scan(&tdatasetlist, &td.);

                proc sql noprint;
                    select distinct levelid1, tablesub, stratificationorder 
                    into :stratalevelid separated by ' ', 
                         :stratanames separated by '$',
                         :dummy
                    from tablefile
                    where dataset="&reporttable"
                    order by stratificationorder;

                    select columnname, 
                           case when cirate in ("P","R") then "$30." 
                           else columnformat end as fmt 
                          ,cats(columnwidth,'in')
                    into :outvarlist separated by ' ',
                         :outformat separated by ' ',
                         :outwidth separated by ' '
                    from tablecolumns
                    where table="&reporttable"
                    order by order;
                quit; 
                
                %if %eval(&tableobs.=1) %then %let tablecount=0;

                %do z = 1 %to %sysfunc(countw(&stratalevelid));
                    %let strataid = %scan(&stratalevelid,&z);
                    %let strataname = %scan(&stratanames,&z,$);

                    data _null_;
                        set tablefile;
                        if _n_ = &z then do;
                        call symputx('tabletitle', tabletitle);
                        end;
                    run;

                    %tableletter();
                    %t1t2conc_output(dataset=final_&reporttable(where=(levelid="&strata")),
                                     varlist = &outvarlist,
                                     var = %quote(&strataname),
                                     varwidths = %bquote(&outwidths.),
                                     title=%bquote(Summary of &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.),
                                     varformats =%bquote(&outformats.));

                %if &stratifybydp = Y %then %do;
                    %do dps = 1 %to %eval(&num_dp.);
                        %let maskedID = %scan(&masked_dplist,&dps); 
                        %tableletter();
                        %t1t2conc_output(dataset=final_dps_&reporttable(where=(levelid="&strata" and dpidsiteid="&maskedID")),
                                         varlist = &outvarlist,
                                         var = %quote(&strata),
                                         varwidths = %bquote(&outwidths.),
                                         title = %bquote(Summary of &reporttitle. in the &database. from &startdateformatted. to &enddateformatted, by &maskedID.),
                                         varformats =%bquote(&outformats.));
                    %end;
                %end;
                %end;
          %end;
          %end;
    %end;


***************************************************************************************************;
* Type 5 summary tables                                                      
***************************************************************************************************;
	%if %str("&reporttype") = %str("T5") %then %do;	
    options orientation = landscape;
		/*Loop through each tablesub, determine whether to output categorical and/or continuous table*/
		%isdata(dataset=t5_tempmap);
		%let t5tableobs = &nobs.;
		%do st = 1 %to %eval(&t5tableobs.);

			%let cattabledataset = ;
			%let distabledataset = ;
			%let tableorder=0;

			data _null_;
			 set t5_tempmap;
				if _n_ = &st. then do;
					call symputx('numtables', numtables);
					call symputx('tableorder', tableorder);
					%if %varexist(t5_tempmap,cattable) = 1 %then %do;
						if missing(cattable)=0 then call symputx('cattabledataset', catx('_',cattable,put(catstratificationorder,1.)));
					%end;
					%if %varexist(t5_tempmap,disttable) = 1 %then %do;
						if missing(disttable)=0 then call symputx('distabledataset', catx('_',disttable,put(diststratificationorder,1.)));
					%end;
				end;
			run;

			/*Increment the table number and reset the table letter counter*/
			%if %eval(&tableorder.=1) %then %do;
				%if %eval(&st. ^=1) %then %let tablenum = %eval(&tablenum + 1);
				%let tablecount=1;
			%end;
			
			/*reset table letter counter if only 1 table*/
			%if %eval(&numtables.=1) %then %let tablecount=0;

			%if %str("&cattabledataset.") ne %str("") %then %do;
				%tableletter();
				%t5tables_output(dataset=&cattabledataset.,reporttype=cat);
			%end;
			%if %str("&distabledataset.") ne %str("") %then %do;
				%tableletter();
				%t5tables_output(dataset=&distabledataset.,reporttype=dist);
			%end;			
        %end;		
		%let tablenum = %eval(&tablenum + 1);
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
