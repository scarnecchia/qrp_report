****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_output_table2.sas  
* Created (mm/dd/yyyy): 08/27/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates table 2 output
*                                        
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*
*  PARAMETERS:	
*   - Tablename: dataset name (t1censor/t2censor/t2followuptime/t5censor/t5censor_first)
*	- Title: table title
*	- Where: where clause to filter the &tablename dataset
*   - Reasonlist: list of reasons to include in table 
*   - Tablesub: table stratifier
*   - episodesorpatients: Episodes or Patients label
*   - tablenum: table number
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

%macro censortable_output_table2 (Tablename=, Title=, Where=, Reasonlist=, tablesub=,  episodesorpatients =, tablenum =);

    /*Footnotes*/
    data _footnotes;
       set lookup.lookup_footnotes(where = 
       (type = "censor" and order in (999
       %if %str("&episodesorpatients.") = %str("Episodes") %then %do; 1 %end;
       %if %str("&episodesorpatients.") = %str("Patients") %then %do; 2 %end;
       %if &tablename. = t1censor | &tablename. = t2censor %then %do; 3 %end;
       %if %index(&reasonlist.,cens_episend)>0 %then %do; 4 %end;
       %if %index(&reasonlist.,cens_event)>0 %then %do; 5 %end;
       %if %index(&reasonlist.,cens_spec)>0 %then %do; 6 %end;
       %if %index(&reasonlist.,cens_dth)>0 %then %do; 7 %end;
       %if %index(&reasonlist.,cens_elig)>0 %then %do; 8 %end;
       %if %index(&reasonlist.,cens_dpend)>0 %then %do; 9 %end;
       %if %index(&reasonlist.,cens_qryend)>0 %then %do; 10 %end; )
      
        %if &drop_cens_output.=Y %then %do;
         or (type = "drop_cens" and order = 13) 
        %end;));
	  by order;
      if order >= 4 and order ne 13 then order = order +1;
	  if order = 13 then order = 4;
    run;

	%if &drop_cens_output.=Y %then %do;
      proc sort data = _footnotes;
	    by order;
	  quit;
	%end;

	data _footnotes;
	  set _footnotes;
	  length footnote_order 3; 
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
	%assign_superscripts(type =title, order =1 2 3 4);
	%assign_superscripts(type =cens_episend, order =5);
	%assign_superscripts(type =cens_event, order =6);
	%assign_superscripts(type =cens_spec, order =7);
	%assign_superscripts(type =cens_dth, order =8);
	%assign_superscripts(type =cens_elig, order =9);
	%assign_superscripts(type =cens_dpend, order =10);
	%assign_superscripts(type =cens_qryend, order =11);

    proc datasets nowarn noprint lib=work;
        delete _footnotes;
    quit;

    /*Save to reportdata folder*/
    %isdata(dataset=repdata.table&tablenum.);
    %if %eval(&nobs.<1) %then %do;
    data repdata.table&tablenum.;
        set &tablename(where=(&where.));
        %do corder = 1 %to 7;
            %let cen_var = %scan(&defaultcensororder., &corder.);
            %if %index(&reasonlist.,&cen_var.)>0 %then %do; 
                &cen_var._label = "&&&cen_var._label.&&super_&cen_var.";
            %end;
        %end;
    run; 
    %end;

    %if &destination. = excel %then %do;
    ods excel options(sheet_name="Table &tablenum." tab_color = "green" flow="1:400");
    %end;

    ods proclabel = "Table &tablenum.";

    proc report data = repdata.table&tablenum. nofs nowd spanrows missing split="*"
    	style(header)=[rules=none frame=void background=BGR borderleftcolor = BGR vjust=b] split='*'
	    style(report)=[rules=none frame=void cellpadding =1.5pt];
    		
    	columns %if &includeheaderrow = Y %then %do; headerlabel %end; order grouplabel 
             (%if &tablesub. ne overall %then %do; &tablesub. %end;  epi_tot_char 
                ("^S={background=BGR} Censoring Reason" %do corder = 1 %to 7;
                    %let cen_var = %scan(&defaultcensororder., &corder.);
                    %if %index(&reasonlist.,&cen_var.)>0 %then %do; (&cen_var._label,(&cen_var._tot_char &cen_var._tot_pct_char)) %end;
                %end;
                ));        

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

        %do corder = 1 %to 7;
            %let cen_var = %scan(&defaultcensororder., &corder.);
            %if %index(&reasonlist.,&cen_var.)>0 %then %do; 
              define &cen_var._label / across ' ' style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black background=bgr borderrightcolor=black 
                                                                  borderleftcolor=black borderleftwidth=1 borderrightwidth=1 cellheight=.75in];
    		  define &cen_var._tot_char / group "Number of &episodesorpatients" 
    		    style(column)=[just=C width=55pt background=$backgroundfmt. tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = black borderrightcolor = BGR];
    		  define &cen_var._tot_pct_char / group "Percent of Total &episodesorpatients"
    		     style(column)=[just=C width=43pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR borderrightcolor = BGR];
            %end;
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
    		                        height=2in bordertopwidth = &bordersize tagattr="wrap:yes"];
    		  %do f = 1 %to &num_fn.;
                line "^{super &f.}&&fn&f.";
    		  %end;
            endcomp;
        %end;

    run;

%mend censortable_output_table2;
