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

/*********************************************************************************************/
/* Type 1 and 2 summary tables                                                               */
/*********************************************************************************************/


    /*****************************************************************************************/
    /* Type 1 and 2 censor tables                                                            */
    /*****************************************************************************************/
    %if %sysfunc(prxmatch(m/t1censor|t2censor|t2followuptime/i,&tdatasetlist.)) > 0 %then %do;

        %macro t1t2censoroutput(tablename=, tablenametitle=);
            %let tableidlist=;
            proc sql noprint;
                select distinct table into: tableidlist separated by ' '
                from tablefile(where=(dataset in ("&tablename.")));
            quit;

            %if %str("&tableidlist") ne %str("") %then %do;
            %do t = 1 %to %sysfunc(countw(&tableidlist.));
                %let tableid = %scan(&tableidlist., &t.);
                %let stratificationorder = 0;
                proc sql noprint;
                    select max(stratificationorder) into: stratificationorder
                    from tablefile(where=(dataset in ("&tablename.") and table = "&tableid"));
                quit;

               /*counter for determining table letter*/
               %if %eval(&stratificationorder. = 1) & &stratifybydp. ne Y %then %let tablecount = 0;
               %else %let tablecount = 1;

                %do st = 1 %to &stratificationorder.;
                    data _null_;
                        set tablefile(where=(dataset in ("&tablename.") and table = "&tableid" and stratificationorder = &st.));
                        call symputx('tabletitle', tabletitle);
                        if tablesub = 'overall' then call symputx('strat', 'overall');
                        else call symputx('strat', tablesub);

                        /*table T2 - default censor reasons*/
                        %if &tableid. = T2 %then %do;
                        call symputx('t2censorreasons', censorreason);
                        %end;
                    run;
                 
                    %tableletter();
                    %if &tableid. = T1 %then %do;
/*                    %censortable_output_table13(tablename=&tablename.,*/
/*                                                title=%quote(Table &tablenum.&tableletter.. Summary of Time to End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.),*/
/*                                                where=%str(dpidsiteid = 'ALL' and table_name = 'overall' and strat = "&strat."));*/
                    %if &stratifybydp. = Y & %eval(&st.=1) %then %do;
                    %tableletter();
/*                    %censortable_output_table13(tablename=&tablename.,*/
/*                                                title=%quote(Table &tablenum.&tableletter.. Summary of Time to End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted., by Data Partner),*/
/*                                                where=%str(dpidsiteid ne 'ALL' and table_name = 'overall' and strat = 'overall'));*/
                    %end;
                    %end;

                    %else %if &tableid. = T2 %then %do;
/*                    %censortable_output_table2(tablename=&tablename.,*/
/*                                               title=%quote(Table &tablenum.&tableletter.. Summary of Reasons for End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.),*/
/*                                               where=%str(dpidsiteid = 'ALL' and table_name = 'overall' and strat = "&strat."),*/
/*                                               reasonlist= &t2censorreasons.);*/
                    %if &stratifybydp. = Y & %eval(&st.=1) %then %do;
                    %tableletter();
/*                    %censortable_output_table2(tablename=&tablename.,*/
/*                                               title=%quote(Table &tablenum.&tableletter.. Summary of Reasons for End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted., by Data Partner),*/
/*                                               where=%str(dpidsiteid ne 'ALL' and table_name = 'overall' and strat = "&strat."),*/
/*                                               reasonlist= &t2censorreasons.);*/
                    %end;
                    %end;

                    %else %if &tableid. = T3 & %eval(&st.=1) %then %do;

                        /*loop through each reason for censoring and within that - loop through stratificationorder*/
                        %do c = 1 %to %sysfunc(countw(&defaultcensororder., ' '));
                            %let reason = %scan(&defaultcensororder., &c.);
                            /*check if rows exist in table (censorreason parameter has already been applied in %censortables_createdata*/
                            data chktable;
                                set &tablename.(where=(table_name="&reason."));
                            run;
                            %isdata(dataset=chktable);
                            %if %eval(&nobs.>0) %then %do;

                            /*set table letter counter - need to check # of stratifications requested for censor reason*/
                            proc sql noprint;
                                select count(distinct stratificationorder) into: reasonstratificationorder
                                from tablefile
                                where dataset in ("&tablename.") and table = "&tableid" and findw(censorreason, "&reason.")>0;
                            quit;

                            %if %eval(&reasonstratificationorder. = 1) %then %let tablecount = 0;
                            %else %let tablecount = 1;

                            /*loop through each stratification*/
                            %do t3st = 1 %to &stratificationorder.;
                                %let censorreasontable = N;
                                data _null_;
                                    set tablefile(where=(dataset in ("&tablename.") and table = "T3" and stratificationorder = &t3st.));
                                    call symputx('tabletitle', tabletitle);
                                    if tablesub = 'overall' then call symputx('strat', 'overall');
                                    else call symputx('strat', tablesub);

                                    /*check if censoring reason requested*/ 
                                    if findw(censorreason, "&reason.")>0 then call symputx('censorreasontable', 'Y');
                                run;

                                %if &censorreasontable. = Y %then %do;
                                %tableletter();
/*                                %censortable_output_table13(tablename=&tablename.,*/
/*                                title=%quote(Table &tablenum.&tableletter.. Summary of Time to End of &tablenametitle. due to %sysfunc(propcase(&&&reason._label)) for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.),*/
/*                                where=%str(dpidsiteid = 'ALL' and table_name = "&reason" and strat = "&strat."));*/
                                %end; /*censor reason requested*/
                            %end; /*loop through stratification*/

                            proc datasets nowarn noprint lib=work;
                                delete chktable;
                            quit;

                            /*after each censor reason upnumber table*/
                            %let tablenum = %eval(&tablenum + 1);
                            %end; /*dataset exists*/
                         %end; /*censor reason loop*/
                    %end; /*T3*/
                %end; /*loop through stratifications*/

                /*if table = T1 or T2 - upnumber table*/
                %if %sysfunc(prxmatch(m/T1|T2/i,&tableid.)) > 0 %then %do;
                %let tablenum = %eval(&tablenum + 1);
                %end;
            %end; /*loop through each table*/
            %end; /*table requested*/
        %mend;
 
        %t1t2censoroutput(tablename=t2followuptime, tablenametitle=At-Risk Period);
        %t1t2censoroutput(tablename=t&typenum.censor, tablenametitle=Observable Data);
    %end;


/*********************************************************************************************/
/* Type 5 summary tables                                                                     */
/*********************************************************************************************/



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
