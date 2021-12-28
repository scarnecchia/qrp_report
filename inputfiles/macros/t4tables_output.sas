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
*   - where = where clause to restrict &dataset
*   - tabnum = table number and letter
*   - title = table title              
*   - nonpreg = Y/N indicator for inclusion of non-pregnant matched cohort 
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
                       where=,
                       tabnum=,
                       title=, 
                       nonpreg=,
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
           %if &nonpreg = N %then %do; 1 %end;
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
    		set &dataset(where=(&where.) keep=group moiname pregflg den_episodes order grouplabel moilabel &varlist. &varlistnochar.
                         %if &dataset. = final_dps_t4moi %then %do; dpidsiteid %end;
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
        style(header)=[rules=none vjust=b backgroundcolor=bgr borderbottomcolor=bgr borderrightcolor=bgr borderleftcolor=bgr] split='*'
        style(report)=[rules=none frame=void cellpadding =1.75pt];
 
        columns %if &nonpreg. = Y %then %do; pregflg %end;
                %if &includeheaderrow. = Y %then %do; header %end;
                order grouplabel %if &includemoiheaderrow = Y %then %do; moiheader %end; moilabel &columnstatement.;

        %if &nonpreg. = Y %then %do;
        define pregflg / order order=data noprint;
        %end;
        %if &includeheaderrow. = Y %then %do; 
        define header / order noprint order=data ' ';
        %end;

		define order / order order=data noprint;
        define grouplabel / order order=data noprint; 
        %if &includemoiheaderrow. = Y %then %do; 
        define moiheader / order noprint order=data ' ';
        %end;
        define moilabel / "Exposure(s) of Interest&super_title."
             style(column)= [just=l indent=%if &includemoiheaderrow = Y %then %do;.25in%end; %else %do;.15in%end;]
    		 style(header)=[just=l borderbottomcolor=black backgroundcolor=bgr borderrightcolor=bgr borderleftcolor=bgr];

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
        
        /*add pregnant/non-pregnant header*/
        %if &nonpreg. = Y %then %do;
        compute before pregflg / style=[backgroundcolor=libgr font_weight=bold just=L bordertopcolor=black borderbottomcolor=black];
            length text $100;
            if pregflg = 'Y' then text = "Pregnant Cohort";
            else text = "Matched Non-Pregnant Cohort";
            num = 100;
            line text $varying. num;
        endcomp;
        %end;

        /*add header line*/
        %if &includeheaderrow = Y %then %do;
        compute before header / style=[backgroundcolor=bwh font_weight=bold just=L bordertopcolor=black borderbottomcolor=black];
            length text $100;
            text = header;
            num = 100;
            line text $varying. num;
        endcomp;
        %end;
        
        /*add group label*/
        compute before grouplabel / 
			 %if &includeheaderrow. = Y %then %do;
                style=[backgroundcolor=white font_weight=bold just=L bordertopcolor=white borderbottomcolor=white];
             %end;
             %else %do;
                style=[backgroundcolor=bwh font_weight=bold just=L bordertopcolor=black borderbottomcolor=black];
             %end;
            length text $100;
            text = grouplabel;
            num = 100;
            line text $varying. num;
        endcomp;

        /*MOI header*/
        %if &includemoiheaderrow. = Y %then %do;
        compute before moiheader / style=[fontstyle=italic indent=.15in backgroundcolor=white just=L bordertopcolor=white borderbottomcolor=white];
            length text $100;
            text = moiheader;
            num = 100;
            line text $varying. num;
        endcomp;
        %end;

        /*add footnotes*/
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
