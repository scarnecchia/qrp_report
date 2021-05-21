****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: attrition_output.sas  
* Created (mm/dd/yyyy): 05/18/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro outputs patient and/or episode level attrition data
*                                        
*  Program inputs:                                                                                   
*   - agg_patient_attrition
*	- agg_episode_attrition
* 
*  Program outputs: 
* 
*   -repdata.table&tablenum.&tableletter.
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

%macro attrition_output;

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

    %if &attrition_episode > 0 %then %do;
    %tableletter();
    data repdata.table&tablenum.&tableletter.;
    	set agg_episode_attrition;
    run;

        %if &destination = excel %then %do;
        ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="teal");
        %end;
        ods proclabel = "Table &tablenum.&tableletter.";
        proc report data=repdata.table&tablenum.&tableletter. nofs nowd spanrows missing
                style(header)=[rules=none vjust=b background=darkgrey] split='*'
                style(report)=[rules=none frame=box cellpadding=1.5pt];
                column report_descr (headerlabel,(grouplabel,(agg_remaining_char agg_excluded_char))) dummyvar;
                define report_descr / group order=data ' ' style(column)=[rules=none just=L] 
                                                           style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey];

                define headerlabel / across ' ' style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey];

                define grouplabel / across ' '  style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey];

                define agg_remaining_char / display 'Remaining' style(column)=[background=$backgroundfmt. tagattr="type:string"] 
                                                                style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey borderbottomcolor=black] format=$attrition.;

                define agg_excluded_char / display 'Excluded' style(column)=[background=$backgroundfmt. tagattr="type:string"]
                                                              style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey borderbottomcolor=black] format=$attrition.;

                define dummyvar / computed noprint;

                compute dummyvar;
                 dummyvar=1;
                endcomp;

                /*Add title*/
                compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                               tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
                line "Table &tablenum.&tableletter.. Summary of Episode Level Cohort Attrition in the &database. from &startdateformatted. to &enddateformatted.";
                endcomp;

                compute before report_descr / style=[background=lightgrey foreground=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];

                length text $100;
            
                if report_descr = 'Enrolled at any point during the query period' then do; 
                    text='Members meeting enrollment and demographic requirements'; 
                    num=100;
                end;
                else if report_descr = 'Had any cohort-defining claim during the query period' then do; 
                    text='Members with a valid index event'; 
                    num=100;
                end;
                else if report_descr = 'Total number of claims with cohort-identifying codes during the query period' then do; 
                    %if %index(&reporttype,T4L1) %then %do;
                    text='Live birth deliveries with a valid index date'; 
                    %end;
                    %else %do;
                    text='Cohort episodes with a valid index date'; 
                    %end;
                    num=100;
                end;
                else if report_descr = 'Had sufficient pre-index continuous enrollment' then do; 
                    %if %index(&reporttype,T4L1) %then %do;
                    text='Pregnancy episodes with required pre-index history'; 
                    %end;
                    %else %do;
                    text='Cohort episodes with required pre-index history'; 
                    %end;
                    num=100;
                end;
                else if report_descr = 'Had sufficient post-index continuous enrollment' then do; 
                    %if %index(&reporttype,T4L1) %then %do;
                    text='Pregnancy episodes with required post-index follow-up'; 
                    %end;
                    %else %do;
                    text='Cohort episodes with required post-index follow-up'; 
                    %end;
                    num=100;
                end;
                else if report_descr = 'Number of members' then do; 
                    text='Final cohort'; 
                    num=100;
                end;
                else do;
                  text=' ';
                  num=0;
                end;
                line text $Varying. num; 
                endcomp;
        run;

    %end;

    %if &attrition_patient > 0 %then %do;
    %tableletter();
    data repdata.table&tablenum.&tableletter.;
    	set agg_patient_attrition;
    run;

        %if &destination = excel %then %do;
        ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="teal");
        %end;
        ods proclabel = "Table &tablenum.&tableletter.";
        proc report data=repdata.table&tablenum.&tableletter. nofs nowd spanrows missing
                style(header)=[rules=none vjust=b background=darkgrey] split='*'
                style(report)=[rules=none frame=box cellpadding=1.5pt];
                column report_descr (headerlabel,(grouplabel,(agg_remaining_char agg_excluded_char))) dummyvar;
                define report_descr / group order=data ' ' style(column)=[rules=none just=L] 
                                                           style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey];

                define headerlabel / across ' ' style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey];

                define grouplabel / across ' '  style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey];

                define agg_remaining_char / display 'Remaining' style(column)=[background=$backgroundfmt. tagattr="type:string"] 
                                                                style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey borderbottomcolor=black] format=$attrition.;

                define agg_excluded_char / display 'Excluded' style(column)=[background=$backgroundfmt. tagattr="type:string"]
                                                              style(header)=[background = darkgrey borderleftcolor=darkgrey borderrightcolor=darkgrey borderbottomcolor=black] format=$attrition.;

                define dummyvar / computed noprint;

                compute dummyvar;
                 dummyvar=1;
                endcomp;

                /*Add title*/
                compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                               tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
                line "Table &tablenum.&tableletter.. Summary of Patient Level Cohort Attrition in the &database. from &startdateformatted. to &enddateformatted.";
                endcomp;

                compute before report_descr / style=[background=lightgrey foreground=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];

                length text $100;
            
                if report_descr = 'Enrolled at any point during the query period' then do; 
                    text='Members meeting enrollment and demographic requirements'; 
                    num=100;
                end;
                else if report_descr = 'Had any cohort-defining claim during the query period' then do; 
                    text='Members with a valid index event'; 
                    num=100;
                end;
                else if report_descr = 'Had sufficient pre-index continuous enrollment' then do; 
                    text='Members with required pre-index history'; 
                    num=100;
                end;
                else if report_descr = 'Had sufficient pre-index continuous enrollment' then do; 
                    text='Members with required pre-index history'; 
                    num=100;
                end;
                else if report_descr = 'Had sufficient post-index continuous enrollment' then do; 
                    text='Members with required post-index follow-up'; 
                    num=100;
                end;
                else if report_descr = 'Number of members' then do; 
                    text='Final cohort'; 
                    num=100;
                end;
                else do;
                  text=' ';
                  num=0;
                end;
                line text $Varying. num; 
                endcomp;
        run;

    %end;

    %end;

%mend attrition_output;