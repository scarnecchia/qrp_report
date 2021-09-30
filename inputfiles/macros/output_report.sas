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

        %if %sysfunc(prxmatch(m/t1cida|t2cida|t2conc/i,&tdatasetlist.)) %then %do;
              /* Set options to missing to prevent dot from printing in row */
              options orientation = landscape;
              options missing = ' ';
          %do td = 1 %to &tdatasetlistnum.; 
            %let reporttable = %scan(&tdatasetlist, &td.);
            %if ^%sysfunc(prxmatch(m/t1cida|t2cida|t2conc/i,&reporttable.)) %then %goto leavet1t2conc;
                %let tablecount=1;
                proc sql noprint;
                    select cats(columnname,'_char') 
                          ,cats(columnwidth,'in')
                          ,smallcellyn
                    into :outvarlist separated by ' ',
                         :outwidths separated by ' ',
                         :outsmallcells separated by ' '
                    from tablecolumns
                    where table="&reporttable"
                    order by order;

                    %let tableobs = 0;
                    select max(stratificationorder)
                    into :tableobs trimmed 
                    from tablefile
                    where dataset="&reporttable";
                quit; 
                
                %do z = 1 %to &tableobs;

                    %if &stratifybydp = Y %then %let tablecount=1;
                    %else %let tablecount=0;

                    data _null_;
                        set tablefile(where=(dataset="&reporttable" and stratificationorder=&z));
                        call symputx('tabletitle', tabletitle);
                        call symputx('strataid',levelid1);
                        call symputx('strataname',tablesub);
                    run;

                    %tableletter();
                    %t1t2conc_output(dataset=final_&reporttable(where=(level="&strataid")),
                                     varlist = &outvarlist,
                                     stratavar = %quote(&strataname),
                                     varwidths = %bquote(&outwidths.),
                                     varsmallcells = &outsmallcells,
                                     title=%bquote(Summary of &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.));

                %if &stratifybydp = Y %then %do;
                    %do dps = 1 %to %eval(&num_dp.);
                        %let maskedID = %scan(&masked_dplist,&dps); 
                        %tableletter();
                        %t1t2conc_output(dataset=final_dps_&reporttable(where=(level="&strataid" and dpidsiteid="&maskedID")),
                                         varlist = &outvarlist,
                                         stratavar = %quote(&strataname),
                                         varwidths = %bquote(&outwidths.),
                                         varsmallcells = &outsmallcells,
                                         title = %bquote(Summary of &reporttitle. in the &database. for &maskedID from &startdateformatted. to &enddateformatted.&tabletitle.));
                    %end;
                %end;
                %let tablenum = %eval(&tablenum + 1);
                %end; /* z */
          %leavet1t2conc:
          %end; /* td */
          options missing = '.';
          options orientation = portrait;
        %end; /* %sysfunc(prxmatch(m/t1cida|t2cida|t2conc/i,&tdatasetlist.)) */

    /*****************************************************************************************/
    /* Type 1 and 2 censor tables                                                            */
    /*****************************************************************************************/
    %if %sysfunc(prxmatch(m/t1censor|t2censor|t2followuptime/i,&tdatasetlist.)) > 0 %then %do;
    options orientation = landscape;
        %macro t1t2censoroutput(tablename=, tablenametitle=, cattableheader=, conttableheader=);
            %let tableidlist=;
            proc sql noprint;
                select distinct table into: tableidlist separated by ' '
                from tablefile(where=(dataset in ("&tablename.")));
            quit;

            %isdata(dataset=&tablename.);
            %if %eval(&nobs.>0) %then %do;

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

                        /*table T1/T3 - determine if continuous metrics should be printed*/
                        if missing(levelid2) = 0 and tablesub = 'overall' then call symputx('continuousmetrics', 'Y');
                        else call symputx('continuousmetrics', 'N');

                        /*table T2 - censor reasons*/
                        %if &tableid. = T2 %then %do;
                        call symputx('t2censorreasons', censorreason);
                        %end;
                    run;
                 
                    %tableletter();
                    %if &tableid. = T1 %then %do;
                    %censortable_output_table13(tablename=&tablename.,
                                                tablenum=&tablenum.&tableletter.,
                                                title=%quote(Summary of Time to End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.),
                                                where=%str(dpidsiteid = 'ALL' and table_name = 'overall' and strat = "&strat."),
                                                tablesub=&strat.,
                                                continuousmetrics=&continuousmetrics.,
                                                cattableheader=by &cattableheader.,
                                                conttableheader=%str(&conttableheader. in Days, by Episode),
                                                episodesorpatients=Episodes,
                                                censorreason=);
                    %if &stratifybydp. = Y & %eval(&st.=1) %then %do;
                    %tableletter();
                    %censortable_output_table13(tablename=&tablename.,
                                                tablenum=&tablenum.&tableletter.,
                                                title=%quote(Summary of Time to End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted., by Data Partner),
                                                where=%str(dpidsiteid ne 'ALL' and table_name = 'overall' and strat = 'overall'),
                                                tablesub=dpidsiteid,
                                                continuousmetrics=N,
                                                cattableheader=by &cattableheader.,
                                                conttableheader=%str(&conttableheader. in Days, by Episode),
                                                episodesorpatients=Episodes,
                                                censorreason=);
                    %end;
                    %end;

                    %else %if &tableid. = T2 %then %do;
                    %censortable_output_table2(tablename=&tablename.,
                                               title=%quote(Table &tablenum.&tableletter.. Summary of Reasons for End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.),
                                               where=%str(dpidsiteid = 'ALL' and table_name = 'overall' and strat = "&strat." and censorcat_sort = 1),
                                               reasonlist= &t2censorreasons.,
											   tablesub=&strat.,
											   tablenum=&tablenum.&tableletter.,
                                               episodesorpatients=Episodes); 
                    %if &stratifybydp. = Y & %eval(&st.=1) %then %do;
                    %tableletter();
                    %censortable_output_table2(tablename=&tablename.,
                                               title=%quote(Table &tablenum.&tableletter.. Summary of Reasons for End of &tablenametitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted., by Data Partner),
                                               where=%str(dpidsiteid ne 'ALL' and table_name = 'overall' and strat = "&strat." and censorcat_sort = 1),
                                               reasonlist= &t2censorreasons.,
											   tablesub=dpidsiteid,
											   tablenum=&tablenum.&tableletter.,
                                               episodesorpatients=Episodes); 
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
                                                
                                    /*table T1/T3 - determine if continuous metrics should be printed*/
                                    if missing(levelid2) = 0 and tablesub = 'overall' then call symputx('continuousmetrics', 'Y');
                                    else call symputx('continuousmetrics', 'N');

                                    /*check if censoring reason requested*/ 
                                    if findw(censorreason, "&reason.")>0 then call symputx('censorreasontable', 'Y');
                                run;

                                %if &censorreasontable. = Y %then %do;
                                %tableletter();
                                %censortable_output_table13(tablename=&tablename.,
                                tablenum=&tablenum.&tableletter.,
                                title=%quote(Summary of Time to End of &tablenametitle. due to %sysfunc(propcase(&&&reason._label)) for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.),
                                where=%str(dpidsiteid = 'ALL' and table_name = "&reason" and strat = "&strat."),
                                tablesub=&strat.,
                                continuousmetrics=&continuousmetrics.,
                                cattableheader=%quote(Censored due to %sysfunc(propcase(&&&reason._label)) by &cattableheader.),
                                conttableheader=%str(&conttableheader. in Days, by Episode),
                                episodesorpatients=Episodes,
                                censorreason=&reason.);
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
            %end; /*underlying data exists*/
            %end; /*loop through each table*/
            %end; /*table requested*/
        %mend;
 
        %t1t2censoroutput(tablename=t2followuptime, 
                          tablenametitle=At-Risk Period, 
                          cattableheader=Episode Length,
                          conttableheader=At-Risk Time);
        %t1t2censoroutput(tablename=t&typenum.censor, 
                          tablenametitle=Observable Data,
                          cattableheader=Observable Time,
                          conttableheader=Observable Time);
    options orientation = portrait;
    %end;

/*********************************************************************************************/
/* Type 5 summary tables                                                                     */
/*********************************************************************************************/
	%if %str("&reporttype") = %str("T5") %then %do;
        options orientation = landscape;

        /*Split table order map file to T1-T13 and T18-T22*/
		%isdata(dataset=t5_tempmap);
        %if %eval(&nobs.>0) %then %do;
            data _temp_t5_tempmap1 _temp_t5_tempmap2;
                set t5_tempmap;
                if table in ('T1','T2','T3','T4','T5','T6','T7','T8','T9','T10','T11','T12','T13') then output _temp_t5_tempmap1;
                if table in ('T18','T19','T20','T21','T22') then output _temp_t5_tempmap2;
            run;
	    %end;

        /*Macro to produce Tables T1-T13, T18-T22*/
        %macro loopt5tablesoutput(dataset=);
        	/*Loop through each tablesub, determine whether to output categorical and/or continuous table*/
    		%isdata(dataset=&dataset.);
            %if %eval(&nobs.>0) %then %do;

        		%let t5tableobs = &nobs.;
        		%do st = 1 %to %eval(&t5tableobs.);

        			%let cattabledataset = ;
        			%let distabledataset = ;
        			%let tableorder=0;

        			data _null_;
        			 set &dataset.;
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

                proc datasets nowarn noprint lib=work;
                    delete _temp_t5_tempmap1; 
                quit;
            %end;
        %mend;

        /*****************************************************************************************/
        /* Type 5 Tables T1-T13                                                                  */
        /*****************************************************************************************/
        %loopt5tablesoutput(dataset=_temp_t5_tempmap1);
	
        /*****************************************************************************************/
        /* Type 5 censor tables                                                                  */
        /*****************************************************************************************/
        %macro t5censoroutput(tableid = , tablename=, first=, episodesorpatients=);

            %if %sysfunc(prxmatch(m/T14\b|T16\b/i,&tableid.)) > 0 %then %do;
                data _null_;
                    set tablefile(where=(dataset in ("t5censor") and table = "&tableid"));
                    /*censor reasons*/
                    call symputx('t5censorreasons', censorreason);
                run;

                /*counter for determining table letter*/
                %if &stratifybydp. = Y %then %let tablecount = 1;
                %else %let tablecount = 0;
                %tableletter();
                %censortable_output_table2(tablename=&tablename.,
                                           title=%quote(Summary of Reasons &first.Treatment Episodes Ended for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.),
                                           where=%str(dpidsiteid = 'ALL' and table_name = 'overall' and strat = "overall" and censorcat_sort = 1),
                                           reasonlist= &t5censorreasons.,
    									   tablenum=&tablenum.&tableletter.,
    									   tablesub= overall,
                                           episodesorpatients=&episodesorpatients.);
                %if &stratifybydp. = Y %then %do;
                %tableletter();
                %censortable_output_table2(tablename=&tablename.,
                                           title=%quote(Summary of Reasons &first.Treatment Episodes Ended for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted., by Data Partner),
                                           where=%str(dpidsiteid ne 'ALL' and table_name = 'overall' and strat = "overall" and censorcat_sort = 1),
                                           reasonlist= &t5censorreasons.,
    									   tablesub=dpidsiteid,
    		                               tablenum=&tablenum.&tableletter.,
                                           episodesorpatients=&episodesorpatients.);
                %end;
                %let tablenum = %eval(&tablenum + 1);
            %end;

            %if %sysfunc(prxmatch(m/T15\b|T17\b/i,&tableid.)) > 0 %then %do;
                /*loop through each reason for censoring*/
                %do c = 1 %to %sysfunc(countw(&defaultcensororder., ' '));
                    %let reason = %scan(&defaultcensororder., &c.);
                    %let censorreasontable = N;

                    data _null_;
                        set tablefile(where=(dataset in ("t5censor") and table = "&tableid."));
                        /*check if censoring reason requested*/ 
                        if findw(censorreason, "&reason.")>0 then call symputx('censorreasontable', 'Y');
                    run;

                    %if &censorreasontable. = Y %then %do;
                    /*check if rows exist in table (censorreason parameter has already been applied in %censortables_createdata*/
                    data chktable;
                        set &tablename.(where=(table_name="&reason."));
                    run;
                    %isdata(dataset=chktable);
                    %if %eval(&nobs.>0) %then %do;
                        /*note - table is not stratified by DP*/
                        %censortable_output_table13(tablename=&tablename.,
                         tablenum=&tablenum.,
                         title=%quote(Summary of Episode Duration for &first.Treatment Episodes Ended due to %sysfunc(propcase(&&&reason._label)) for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.),
                         where=%str(dpidsiteid = 'ALL' and table_name = "&reason" and strat = "overall"),
                         tablesub=overall,
                         continuousmetrics=Y, /*continuous metrics always returned*/
                         cattableheader=%quote(Censored due to %sysfunc(propcase(&&&reason._label)) by Episode Length),
                         conttableheader=%str(Treatment Episode Length, in Days),
                         episodesorpatients=&episodesorpatients.,
                         censorreason=&reason.);
                        %let tablenum = %eval(&tablenum + 1);
                    %end;
                    proc datasets nowarn noprint lib=work;
                        delete chktable;
                    quit;
                    %end;
                %end;
            %end;
        %mend;

        %if %sysfunc(prxmatch(m/T14\b/i,&tablelist.)) > 0 %then %do;
            %t5censoroutput(tableid=T14, tablename = t5censor_first, first=%str(First ),  episodesorpatients=Patients);
        %end;
        %if %sysfunc(prxmatch(m/T15\b/i,&tablelist.)) > 0 %then %do;
            %t5censoroutput(tableid=T15, tablename = t5censor_first, first=%str(First ), episodesorpatients=Patients);
        %end;
        %if %sysfunc(prxmatch(m/T16\b/i,&tablelist.)) > 0 %then %do;
            %t5censoroutput(tableid=T16, tablename = t5censor, first=, episodesorpatients=Episodes);
        %end;
        %if %sysfunc(prxmatch(m/T17\b/i,&tablelist.)) > 0 %then %do;
            %t5censoroutput(tableid=T17, tablename = t5censor, first=, episodesorpatients=Episodes);
        %end;

        /*****************************************************************************************/
        /* Type 5 Tables T1-T13                                                                  */
        /*****************************************************************************************/
        %loopt5tablesoutput(dataset=_temp_t5_tempmap2);

        options orientation = portrait;

    %end; /*type 5 tables*/ 


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

        /* reset counter to reset table letter */
        %let tablecount=1;

        %do j = %eval(&look_start) %to %eval(&look_end);

        %if %index(&reporttype,L2) %then %let attrperiodid=_&j;
        
        /* Check to see if either dataset exists */
        %isdata(dataset=agg_patient_attrition&attrperiodid);
        %let attrition_patient = &nobs;
        %isdata(dataset=agg_episode_attrition&attrperiodid);
        %let attrition_episode = &nobs;

            %if &attrition_patient > 0 or &attrition_episode > 0 %then %do;

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
