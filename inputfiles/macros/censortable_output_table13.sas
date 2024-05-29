****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_output_table13.sas  
* Created (mm/dd/yyyy): 08/30/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro contains a proc report to produce 2 L1 censor tables
*                                        
*  Program inputs:                                                                                   
*   - t2censor
*   - t2followuptime
*   - t5censor
*   - t5censor_first
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:   
*   - tablename: input dataset name
*   - tablenum: table number
*   - title: table title in report
*   - where: where clause to restrict input dataset
*   - tablesub: table stratifier
*   - continuousmetrics: Y/N indicator to print continuous metrics
*   - cattableheader: language to include across category header "Number of Episodes ...."
*   - conttableheader: language to include across continuous metrics
*   - episodesorpatients: Episodes or Patients label
*   - censorreason: Table T3 censor reason - only populated for table T3    
* 
*  Programming Notes:         
*   
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro censortable_output_table13(tablename=, 
                                  tablenum=,
                                  title=, 
                                  where=,
                                  tablesub=,
                                  continuousmetrics=, 
                                  cattableheader=,
                                  conttableheader=,
                                  episodesorpatients=,
                                  censorreason=);

    %put =====> MACRO CALLED: censortable_output_table13;

    /*Save dataset to REPORTDATA folder*/
    %isdata(dataset=repdata.table&tablenum.);
    %if %eval(&nobs.<1) %then %do;
        data repdata.table&tablenum.;
            set &tablename(where=(&where.));
            %if &continuousmetrics. = Y %then %do;
            dummy = '';
            %end;
        run;
    %end;

    /*Footnotes*/
    data _footnotes;
	   length footnote_order 3; 
       set lookup.lookup_footnotes(where = (type = "censor" and order in (999 /*dummy to prevent e r r o r*/
        %if %index(%str(&conttableheader.),%str(Observable Time))>0 %then %do; 3 %end;
        %if &censorreason. = cens_episend %then %do; 4 %end;
        %if &censorreason. = cens_event %then %do; 5 %end;
        %if &censorreason. = cens_spec %then %do; 6 %end;
        %if &censorreason. = cens_dth %then %do; 7 %end;
        %if &censorreason. = cens_elig %then %do; 8 %end;
        %if &censorreason. = cens_dpend %then %do; 9 %end;
        %if &censorreason. = cens_qryend %then %do; 10 %end; )
        %if &drop_cens_output.=Y %then %do;
         or (type = "drop_cens")
       %end;));
	  by order;
	  footnote_order = _n_;
    run;

    proc sql noprint;
	  select count(order) into: num_fn trimmed
	  from _footnotes;
    quit;

    %if %eval(&num_fn.>0) %then %do;
    proc sql noprint;
	  select description into: fn1 - :fn&num_fn.
	  from _footnotes
	  order by order;
	quit;
    %end;
    
	/* Assign macro variables for superscipts */
	%assign_superscripts(type =title, order =3 11);
	%assign_superscripts(type =reason, order =4 5 6 7 8 9 10);

    proc datasets nowarn noprint lib=work;
        delete _footnotes;
    quit;

    %if &destination. = excel %then %do;
    ods excel options(sheet_name="Table &tablenum." tab_color = "green" flow="1:400");
    %end;

    ods proclabel = "Table &tablenum.";
    proc report data=repdata.table&tablenum. nofs nowd spanrows missing split='*'
        style(header)=[rules=none frame=void background=BGR borderleftcolor = BGR vjust=b] split='*'
	    style(report)=[rules=none frame=void cellpadding =1.5pt];

    	columns %if &includeheaderrow = Y %then %do; headerlabel %end; order grouplabel (%if &tablesub. ne overall %then %do; &tablesub. %end; epi_tot_char 
                %if %str("&censorreason") ne %str("") %then %do; &censorreason._char %end;
                ("^S={background=BGR cellheight=0.75in}Number of &episodesorpatients. &cattableheader." censdays_value_cat_format, (episodes_char epi_tot_pct_char) ) 
                %if &continuousmetrics. = Y %then %do; (dummy, (min_char q1_char median_char q3_char max_char mean_char std_char) ) %end;);		

        %if &includeheaderrow = Y %then %do; 
        define headerlabel / group noprint order=data ' ';
        %end;

		define order / group "" order=data noprint;

        /*if overall - print grouplabel, if stratified - group label will be in compute block*/
        %if &tablesub. = overall %then %do;
        define grouplabel / group "" order=data style(column)=[just=L width =1.5in fontstyle=italic] style(header)=[background = BGR borderleftcolor = BGR]; 
        %end;
        %else %do;
        define &tablesub. / group  "" order=data style(column)=[just=L width=.9in];
        define grouplabel /group noprint;
        %end;

        define epi_tot_char / group "Total Number of &episodesorpatients"
            style(column)=[width =.8in tagattr="type:string" background=$backgroundfmt.] 
            style(header)=[just=C background = BGR borderleftcolor = BGR];

        %if %str("&censorreason") ne %str("") %then %do; 
        define &censorreason._char / group "Total Number of^n &episodesorpatients Censored^n due to %bquote(&&&censorreason._label)&super_reason."
            style(column)=[width=1in tagattr="type:string" background=$backgroundfmt.  borderleftcolor=black] 
            style(header)=[%if &destination. = excel %then %do;cellheight=50pt %end; just=C background = BGR borderleftcolor = BGR];
        %end;

        define censdays_value_cat_format / across '' order=data
            style(column)=[just=C tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR borderrightcolor=black 
                                                                  borderleftcolor=black borderleftwidth=1 borderrightwidth=1];
        define episodes_char / "Number of &episodesorpatients" group
           style(column)=[just=C width=55pt background=$backgroundfmt. tagattr="type:string" ] style(header)=[just=C background = BGR borderleftcolor = black borderrightcolor = BGR];
        define Epi_Tot_Pct_char / "Percent of Total &episodesorpatients" group
           style(column)=[just=C width=43pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR borderrightcolor = BGR];

        %if &continuousmetrics. = Y %then %do;
        define dummy / across "Distribution of &conttableheader." style(header)=[background = BGR borderleftcolor = BGR];
        define min_char /group 'Minimum' style(column)=[just=C width=37pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = black];
        define q1_char /group 'Q1' style(column)=[just=C width=27 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define median_char /group 'Median' style(column)=[just=C width=30pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define q3_char /group 'Q3' style(column)=[just=C width=27pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define max_char /group 'Maximum' style(column)=[just=C width=40pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define mean_char /group 'Mean' style(column)=[just=C width=27pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define std_char /group 'Standard^n Deviation'  style(column)=[just=C width=44pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        %end;

        /*Add title*/
        compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor = white
    	                              borderbottomwidth = &bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
        line "Table &tablenum.. &title.&super_title";
        endcomp;

        /*Add header if requested*/
        %if &includeheaderrow = Y %then %do; 
            compute before headerlabel / style=[background=LIBGR just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
            length text $100;
                text = headerlabel;
                num = 100;
                line text $varying. num;
            endcomp;
        %end;

        /*Add group label spanning header if stratified table and indent labels*/
        %if &tablesub. ne overall %then %do; 
            compute before grouplabel /
                    %if &includeheaderrow = Y %then %do; 
                    style=[background=white just=L fontstyle=italic bordertopcolor=white borderbottomcolor=white];
                    %end;
                    %else %do;
                    style=[background=LIBGR just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
                    %end;
                length text2 $150;
                text2= grouplabel; 
                num= 150;
            	line text2 $varying. num; 
            endcomp;

            /*indent*/
            compute &tablesub.;
                call define(_col_,'style','style={indent=25}');
            endcomp;
        %end;

        /*Footnotes*/
        %if %eval(&num_fn.>0) %then %do;
    		compute after / style=[just=L nobreakspace=off borderbottomcolor=white bordertopcolor=black vjust=T fontsize=&footfontsize.
    		                        height=.75in bordertopwidth = &bordersize tagattr="wrap:yes"];
    		  %do f = 1 %to &num_fn.;
                line "^{super &f.}&&fn&f.";
    		  %end;
            endcomp;
        %end;
        %else %do;
            /*Add thick line to bottom of report*/
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
            endcomp;
        %end;
    run;

%mend censortable_output_table13;
