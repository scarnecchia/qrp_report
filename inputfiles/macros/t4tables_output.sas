****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t4tables_output.sas  
* Created (mm/dd/yyyy): 12/27/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of T4 summary table proc report output
*                                        
*  Program inputs:                                                                                   
*   - final_t4moi
*   - final_dps_t4moi
* 
*  Program outputs: 
* 	- repdata.table&tablenum.&tableletter
* 
*  PARAMETERS:               
*   - table = table indicator from tablefile
*   - dataset = input dataset
*   - tabnum = table number and letter
*   - title = table title                                               
*   - varlist = List of column names
*   - varwidths = list of variable widths
*   - varsmallcells = List of small cell count highlighting indicators for each column
*   - columnstatementlabels = List of column headers to include in COLUMNS statement
*   - definestatementlabels = List of column headers to include in DEFINE statement
          
*  Programming Notes:     
*   Table T1 includes both N and # columns under a single column. For this reason, the parameter
*    COLUMNLABELS contains a list of labels to include in the COLUMNS statement and COLUMNHEADERS
*    contains a list of labels to include in the DEFINE statement
*                                                                           
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro t4tables_output(table=, 
                       dataset=, 
                       tabnum=,
                       title=, 
                       varlist=, 
                       varwidths=, 
                       varsmallcells=,
                       columnstatementlabels=,
                       definestatementlabels=);

    /*Assign footnotes*/
    data _footnotes;
       length footnote_order 3; 
       set lookup.lookup_footnotes(where=(type = "t4l1moi" and order in ( 0
          %if &table.=T1 %then %do;
            %if %index(&title., "Non-Pregnant")=0 %then %do; 1 %end;
            %else %do; 2 %end;
           %end;
        )));
       by order;
       footnote_order = _n_;
    run;
	 
    proc sql noprint;
        select count(order) into: num_fn trimmed
        from _footnotes;
      
        %if &num_fn > 0 %then %do;
          select description into: fn1 - :fn&num_fn.
          from _footnotes
          order by order;
        %end;
    quit;

	%assign_superscripts(type=title, order = 1 2);

    /*Save dataset to repdata folder*/
    %isdata(dataset=repdata.table&tabnum.);
    %if %eval(&nobs.<1) %then %do;
        /*list of numeric variables*/
        %let varlistnochar = %sysfunc(tranwrd(&varlist., _char, %str()));

        data repdata.table&tabnum.;
    		set &dataset(keep=group moiname pregflg den_episodes order grouplabel moilabel &varlist. &varlistnochar.
                         %if dataset = final_dps_t4moi %then %do; dpidsiteid %end;
                         %if &includeheaderrow. =Y %then %do; header %end;
                         %if &includemoiheaderrow. =Y %then %do; moiheader %end;);
    	run;
    %end;

    /*Create columns statement with varlist headers. Necessary because T1 contains both N and % under one header*/
    %let columnstatement = ;
    %if &table. = T1 %then %do;
        %do v = 1 %to %sysfunc(countw(%str(&columnstatementlabels.),|||));
            %let label = %scan(%str(&columnstatementlabels.),&v., ||||);
            proc sql noprint;
                select cats(columnname,'_char') 
                into :tmpcolumns separated by ' '
                from tablecolumns
                where table="&table" and columnlabel = "&label."
                order by order;
            quit; 
            %let columnstatement = &columnstatement. ("&label." &tmpcolumns.);
        %end;
    %end;
    %else %do;
        %let columnstatement = &varlist;
    %end;
     
    /*Write to report*/
    %if &destination = excel %then %do;
	ods excel options(sheet_name="Table &tabnum." tab_color='green');
    %end;
    ods proclabel = "Table &tabnum.";

     proc report data = repdata.table&tabnum. nofs nowd spanrows missing headskip split="*"
        style(header)=[rules=none vjust=b] split='*'
        style(report)=[rules=none frame=void cellpadding =1.75pt];
 
        columns %if &includeheaderrow = Y %then %do; header %end;
                %if &includemoiheaderrow = Y %then %do; moiheader %end;
                order grouplabel &columnstatement.;

        %if &includeheaderrow = Y %then %do; 
        define header / group noprint order=data ' ';
        %end;
		define order / group order=data noprint;


        /*columns*/
        %do v = 1 %to %sysfunc(countw(&varlist.));
            %let varname = %lowcase(%scan(&varlist., &v.,%str( )));
            %let varlabel = %scan(&definestatementlabels., &v.,%str(|||));
			%let varwidth = %lowcase(%scan(&varwidths., &v.,%str( )));
            %let varsmallcell = %lowcase(%scan(&varsmallcells., &v.,%str( )));
			
		   define &varname. / display "&varlabel"
                 style(column)=[width=&varwidth. just=c %if %str("&varsmallcell.") = %str("y") %then %do; background=$backgroundfmt. %end; tagattr='type:string'] 
				 style(header)=[just=C borderbottomcolor=black backgroundcolor=bgr borderrightcolor=bgr borderleftcolor=bgr];
        %end;

		/* Add title */
		compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                       borderbottomwidth=&bordersize tagattr="wrap:yes" cellheight=.3in];
        line "Table &tabnum.. &title.";
		endcomp;

        /*add header line*/
        %if &includeheaderrow = Y %then %do;
        compute before header / style=[backgroundcolor=libgr font_weight=bold just=L bordertopcolor=black borderbottomcolor=black];
            length text $100;
            text = header;
            num = 100;
            line text $varying. num;
        endcomp;
        %end;






/*"&super_title.";*/







        /* Add Footnotes */
        %if &num_fn > 0 %then %do;
            compute after / style=[just=L vjust=t nobreakspace=off borderbottomcolor=white bordertopwidth=&bordersize height=1in];
            %do f = 1 %to &num_fn.;
                line "^{super &f}&&fn&f.";
            %end;
            endcomp;
        %end;
        %else %do;
        compute after / style=[bordertopwidth=&bordersize borderbottomcolor=white];
             line '';
        endcomp;
        %end;
    run;

%mend t4tables_output;
