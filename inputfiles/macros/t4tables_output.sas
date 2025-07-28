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
*   - final_t4moi / final_t4gestwk
*   - final_dps_t4moi / final_dps_t4gestwk
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
*   - varsuperscripts = Y/N indicator on whether columns will get superscript for footnote
*   - columnstatementlabels = List of column headers to include in COLUMNS statement
*   - definestatementlabels = List of column headers to include in DEFINE statement
*   - spanningheader = Header that spans the top of entire table
*          
*  Programming Notes:     
*   Tables T1 and T5 includes both N and # columns under a single column. For this reason, the parameter
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
                       varsuperscripts=,
                       columnstatementlabels=,
                       definestatementlabels=,
                       spanningheader=);


	/* Determine the pregnant cohort header based on pregnancy outcomes used to define the cohort */
	proc sql noprint;
	create table _outcomes as
	select distinct a.group, 
				    b.code
	from &dataset. as a 
	join Master_cohortcodes as b on a.group=b.group
	where b.codecat="PO";
	quit;	

	proc sql noprint undo_policy=none;
	create table _outcomes as
	select distinct a.preg_outcome, 
					a.preg_outcomecat,
				    a.descr
	from Master_pregnancymeta as a 
	join _outcomes as b on a.preg_outcome=b.code;

	select count(distinct preg_outcomecat) into :num_unique_preg_outcomecat from _outcomes;
	select count(distinct preg_outcome) into :num_unique_preg_outcome from _outcomes;
	select distinct upcase(preg_outcomecat) into :unique_preg_outcomecat separated by "|" from _outcomes; 
	select distinct descr into :unique_descr separated by "|" from _outcomes; 
	quit;

	%if &num_unique_preg_outcomecat. eq 1 %then %do;
		%if %upcase(&unique_preg_outcomecat.) eq LIVE %then %let preg_cohort_header=Live Birth Delivery Cohort;
		%else %if &num_unique_preg_outcome. eq 1 %then %let preg_cohort_header=&unique_descr. Cohort;
		%else %let preg_cohort_header=Non-Live Birth Outcomes Cohort;
	%end;
	%else %let preg_cohort_header=Pregnant Cohort;

    /*Assign footnotes*/
	%let T2Columns=N;
	%let T3Columns=N;
	%if &table. = T1 %then %do;
		proc contents data=&dataset.(keep=&varlist.) out=_contents(keep=label) noprint; run;
		data _null_;
			set _contents;
			if index(lowcase(label),"second trimester") | index(lowcase(label),"2nd trimester") then call symputx("T2Columns", "Y");
			if index(lowcase(label),"third trimester") | index(lowcase(label),"3rd trimester") then call symputx("T3Columns", "Y");
		run;
	%end;
    data _footnotes;
       length footnote_order 3; 
       set lookup.lookup_footnotes(where=( (type = "t4l1moi" and order in ( 0	   	  
	   	  %if &T2Columns.=Y %then %do; 2 %end;
		  %if &T3Columns.=Y %then %do; 3 %end;
          %if &table.=T1 %then %do;
           %if &nonpreg. = Y %then %do; 4 %end;
            %else %do; 5 %end;
           %end;
          %if &table.=T5 %then %do;
           %if &nonpreg. = Y %then %do; 6 %end;
            %else %do; 7 %end;
           %end; 
           %if %index(&varsuperscripts,Y) %then %do; 1 %end;)
          or (type='type4' and order in (-2 %if &nonpreg. = Y %then %do; -1 %end;))
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

	%assign_superscripts(type=title, order = -2 -1);
	%assign_superscripts(type=exposure, order = 4 5 6 7);
    %assign_superscripts(type=column, order = 1);	
	%assign_superscripts(type=T2column, order = 2);
	%assign_superscripts(type=T3column, order = 3);

    /*Save dataset to repdata folder*/
    %isdata(dataset=repdata.table&tabnum.);
    %if %eval(&nobs.<1) %then %do;

        /*list of numeric variables*/
        %let varlistnochar = %sysfunc(tranwrd(&varlist., _char, %str()));

        data repdata.table&tabnum.;
    		set &dataset(where=(&where.) keep=group moiname pregflg order grouplabel moilabel &varlist. &varlistnochar.
                         %if %index(&dataset., t4moi) %then %do; den_episodes %end;
                         %if %index(&dataset., _dps_) %then %do; dpidsiteid %end;
                         %if &includeheaderrow. =Y %then %do; header %end;
                         %if &includemoiheaderrow. =Y %then %do; moiheader %end;);			
    	run;
    %end;

    /*Create columns statement with varlist headers. Necessary because T1 and T5 contains both N and % under one header*/
    %let columnstatement = ;
    %if &table. = T1 | &table. = T5 %then %do;
        %do v = 1 %to %sysfunc(countw(%str(&columnstatementlabels.),|||));
            %let label = %scan(%str(&columnstatementlabels.),&v., |||);
            %let skip = 0;
            /*skip if columnlabel is same as prior variable label*/
            %if %eval(&v.>1) %then %do;
                %if "&label." = "%scan(%str(&columnstatementlabels.),%eval(&v.-1),|||)" %then %let skip = 1;
            %end;

            %if &v. = 1 | &skip. = 0 %then %do;
                proc sql noprint;
                    select cats(columnname,'_char') 
                    into :tmpcolumns separated by ' '
                    from tablecolumns
                    where table="&table" and columnlabel = "&label."
                    order by order;
                quit; 
                %let columnsuperscript_flag = %scan(%str(&varsuperscripts.),&v., |||);
                %if &columnsuperscript_flag = Y %then %let label = %scan(%str(&columnstatementlabels.),&v., |||)&super_column.;

				%if &table.=T1 %then %do;
					%if %index(%upcase(&label.),SECOND) %then %do;
						%if &columnsuperscript_flag = Y %then %let label=%sysfunc(compress(&label., }))%quote(,)%sysfunc(compress(&super_T2column.,^{Super }))};		
						%else %let label=&label.&super_T2column.;
					%end;
					%else %if %index(%upcase(&label.),THIRD) %then %do;
						%if &columnsuperscript_flag = Y %then %let label=%sysfunc(compress(&label., }))%quote(,)%sysfunc(compress(&super_T3column.,^{Super }))};
						%else %let label=&label.&super_T3column.;
					%end;
				%end;
                %let columnstatement = &columnstatement. ("&label." &tmpcolumns.);
            %end;
        %end;
    %end;
    %else %do;
        %let columnstatement = &varlist;
    %end;
  
    /*Write to report*/
    %if &destination = excel %then %do;
	ods excel options(sheet_name="Table &tabnum." tab_color='green' flow="1:400");
    %end;
    ods proclabel = "Table &tabnum.";

     proc report data = repdata.table&tabnum. nofs nowd spanrows missing headskip split="*"
        style(header)=[rules=none vjust=b backgroundcolor=bgr borderbottomcolor=bgr borderrightcolor=bgr borderleftcolor=bgr tagattr='type:string'] split='*'
        style(report)=[rules=none frame=void cellpadding =1.75pt];
 
        columns (%if %length(&spanningheader)>0 %then %do; "&spanningheader." %end; %if &nonpreg. = Y %then %do; pregflg %end;
                %if &includeheaderrow. = Y %then %do; header %end;
                order grouplabel %if &includemoiheaderrow = Y %then %do; moiheader %end; moilabel &columnstatement.);

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
        define moilabel / "Exposure(s) of Interest&super_exposure."
             style(column)= [just=l indent=%if &includemoiheaderrow = Y %then %do;.25in%end; %else %do;.15in%end;]
    		 style(header)=[just=l borderbottomcolor=black backgroundcolor=bgr borderrightcolor=bgr borderleftcolor=bgr];

        /*columns*/
        %do v = 1 %to %sysfunc(countw(&varlist.));
            %let varname = %lowcase(%scan(&varlist., &v.,%str( )));
            %let varlabel = %scan(&definestatementlabels., &v.,%str(|||));
			%let varwidth = %lowcase(%scan(&varwidths., &v.,%str( )));
            %let varsmallcell = %lowcase(%scan(&varsmallcells., &v.,%str( )));
            %let columnsuperscript_flag = %scan(%str(&varsuperscripts.),&v., |||);

            /* add conditional logic to resolve superscript on specific tables, and adjust height so superscript doesn't break cell formatting */
		   define &varname. / display %if %sysfunc(prxmatch(m/T2|T3|T4|T6/i,&table)) and &columnsuperscript_flag = Y %then %do; "&varlabel.&super_column." %end;
                                      %else %do; "&varlabel" %end;
                 style(column)=[width=&varwidth. just=c %if %str("&varsmallcell.") = %str("y") %then %do; background=$backgroundfmt. %end; tagattr='type:string'] 
				 style(header)=[%if %sysfunc(prxmatch(m/T2|T3|T4|T6/i,&table)) and &columnsuperscript_flag = Y %then %do; height=.5in %end; just=C borderbottomcolor=black backgroundcolor=bgr borderrightcolor=bgr borderleftcolor=bgr tagattr='type:string'];
        %end;

		/* Add title */
		compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                       borderbottomwidth=&bordersize tagattr="wrap:yes" cellheight=.3in];
        line "Table &tabnum.. &title.&super_title.";
		endcomp;
        
        /*add pregnant/non-pregnant header*/
        %if &nonpreg. = Y %then %do;
        compute before pregflg / style=[backgroundcolor=libgr font_weight=bold just=L bordertopcolor=black borderbottomcolor=black];
            length text $1000;
            if pregflg = 'Y' then text = "&preg_cohort_header.";
            else text = "All Matched Non-Pregnant Episodes";
            num = 1000;
            line text $varying. num;
        endcomp;
        %end;

        /*add header line*/
        %if &includeheaderrow = Y %then %do;
        compute before header / style=[backgroundcolor=bwh font_weight=bold just=L bordertopcolor=black borderbottomcolor=black];
            length text $1000;
            text = header;
            num = 1000;
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
            length text $1000;
            text = grouplabel;
            num = 1000;
            line text $varying. num;
        endcomp;

        /*MOI header*/
        %if &includemoiheaderrow. = Y %then %do;
        compute before moiheader / style=[fontstyle=italic indent=.15in backgroundcolor=white just=L bordertopcolor=white borderbottomcolor=white];
            length text $1000;
            text = moiheader;
            num = 1000;
            line text $varying. num;
        endcomp;
        %end;

        /*add footnotes*/
        %if &num_fn > 0 %then %do;
                compute after / style=[just=L borderbottomcolor=white bordertopcolor=black vjust=T fontsize=&footfontsize. bordertopwidth = &bordersize
                                       nobreakspace=off];
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

	proc datasets nowarn noprint lib=work;
		delete _contents _footnotes _outcomes;
	quit;

%mend t4tables_output;
