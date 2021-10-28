****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t6censor_output.sas  
* Created (mm/dd/yyyy): 10/22/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of T6 Censoring tables
*                                        
*  Program inputs:                                                                                   
*   - table&tableid
* 
*  Program outputs: 
*   - repdata.&tablenum.&tableletter
* 
*  PARAMETERS:        
*   - tablenum - Table Number and letter
*   - dataset -  T6 censoring dataset
*   - title - Table title
*   - censorreason - List of censoring reasons   
*   - where - where clause        
*   - dptable - Determine whether to use dpidsiteid column                                                   
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

%macro t6censor_output(tablenum=,dataset=,title=,reasonlist=,where=,dptable=);

    /*Footnotes*/
    data _footnotes;
	   length footnote_order 3; 
       set lookup.lookup_footnotes_censortables(where = (order in (1
        %if %index(&reasonlist.,cens_episend) %then %do; 4 %end;
        %if %index(&reasonlist.,cens_event) %then %do; 5 %end;
        %if %index(&reasonlist.,cens_spec) %then %do; 6 %end;
        %if %index(&reasonlist.,cens_dth) %then %do; 7 %end;
        %if %index(&reasonlist.,cens_elig) %then %do; 8 %end;
        %if %index(&reasonlist.,cens_dpend) %then %do; 9 %end;
        %if %index(&reasonlist.,cens_qryend) %then %do; 10 %end; 
        %if %index(&reasonlist.,cens_switch) and &dataset=tableT9 %then %do; 11 %end;
        %if %index(&reasonlist.,cens_switch) and &dataset=tableT10 %then %do; 12 %end;)));
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
	%assign_superscripts(type =title, order =1);
	%assign_superscripts(type =cens_episend, order =4);
	%assign_superscripts(type =cens_event, order =5);
	%assign_superscripts(type =cens_spec, order =6);
	%assign_superscripts(type =cens_dth, order =7);
	%assign_superscripts(type =cens_elig, order =8);
	%assign_superscripts(type =cens_dpend, order =9);
	%assign_superscripts(type =cens_qryend, order =10);
	%assign_superscripts(type =cens_switch1, order =11);
	%assign_superscripts(type =cens_switch2, order =12);

	/* Save dataset to reportdata folder */
    %isdata(dataset=repdata.table&tablenum.);
    %if %eval(&nobs.<1) %then %do;
        data repdata.table&tablenum.;
            set &dataset(where=(&where.));
        %do corder = 1 %to %sysfunc(countw(&defaultcensororder));
            %let cen_var = %scan(&defaultcensororder., &corder.);
            %if %index(&reasonlist.,&cen_var.)>0 %then %do; 
            	%if &cen_var = cens_switch and &dataset = tableT9 %then %let cen_var = cens_switch1;
            	%if &cen_var = cens_switch and &dataset = tableT10 %then %let cen_var = cens_switch2;
                if censorlabel = "&&&cen_var._label" then censorlabel="&&&cen_var._label.&&super_&cen_var.";
            %end;
        %end;
        run;
    %end;

    proc datasets nowarn noprint lib=work;
        delete _footnotes;
    quit;

    %if &destination. = excel %then %do;
    ods excel options(sheet_name="Table &tablenum." tab_color = "green");
    %end;

    ods proclabel = "Table &tablenum.";
    proc report data=repdata.table&tablenum. nofs nowd spanrows missing split='*'
        style(header)=[rules=none frame=void background=BGR borderleftcolor = BGR vjust=b] split='*'
	    style(report)=[rules=none frame=void cellpadding =1.5pt];

    	columns order %if &includeheaderrow = Y %then %do; headerlabel %end; grouplabel %if &dptable=Y %then %do; dpidsiteid %end; censorlabel (n_char mean_char std_char min_char p1_char p5_char p10_char 
    							  p25_char median_char p75_char p90_char p95_char p99_char max_char);	

		define order / "" order=data noprint;

		%if &includeheaderrow = Y %then %do; 
        define headerlabel / order noprint order=data "";
        %end;	

        define grouplabel / order noprint order=data ""; 

        %if &dptable=Y %then %do;
        define dpidsiteid / order noprint order=data ""; 
        %end;

        define censorlabel / order order=data style(column)=[just=L %if &dptable = Y %then %do; indent=.25in %end; %else %do; indent=.15in %end; width=2in] "";

        define n_char / "Number of Episodes"
            style(column)=[width =.8in tagattr="type:string" background=$backgroundfmt.] 
            style(header)=[just=C background = BGR borderleftcolor = BGR];

        define mean_char / display 'Mean' style(column)=[just=C width=45pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define std_char / display 'Standard^n Deviation'  style(column)=[just=C width=44pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define min_char / display 'Minimum' style(column)=[just=C width=45pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p1_char / display '1%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p5_char / display '5%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p10_char / display '10%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p25_char / display '25%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define median_char / display 'Median' style(column)=[just=C width=45pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p75_char / display '75%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p90_char / display '90%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p95_char / display '95%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define p99_char / display '99%' style(column)=[just=C width=87 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define max_char / display 'Maximum' style(column)=[just=C width=45pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
       
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


        /* Add DP stratifications if requested */
        %if &dptable = Y %then %do;
            compute before dpidsiteid / style=[just=L fontstyle=italic bordertopcolor=white borderbottomcolor=white];
                length text3 $150;
                text3= dpidsiteid; 
                num= 150;
            	line text3 $varying. num; 
            endcomp;
        %end;

        /*Footnotes*/
        %if %eval(&num_fn.>0) %then %do;
    		compute after / style=[just=L nobreakspace=off borderbottomcolor=white bordertopcolor=black vjust=T fontsize=&footfontsize.
    		                        height=1.5in bordertopwidth = &bordersize tagattr="wrap:yes"];
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
	

%mend t6censor_output;