****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t1t2t4conc_output.sas  
* Created (mm/dd/yyyy): 09/21/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of T1/T2/T4 and Concomitant Tables proc report output
*                                        
*  Program inputs:                                                                                   
*   - final_[t1cida/t2cida/t2conc/t4cida]
*   - final_dps_[t1cida/t2cida/t2conc/t4cida]
* 
*  Program outputs: 
* 	- repdata.table&tablenum.&tableletter
* 
*  PARAMETERS:               
*   - dataset = Input dataset (aggregated t1cida/t2cida/t2conc/t4cida dataset)
*   - varlist = List of character columns to be printed
*   - stratavar = Stratification variable
*   - varwidth = Width of variable 
*   - varsmallcells = Determine small cell count highlighting
*   - title = Report title                                               
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

%macro t1t2t4conc_output(dataset=,varlist=,stratavar=,varwidths=,varsmallcells=,title=);

    /*Create footnotes*/
    %let outfootnotes=;

    proc sql noprint;
        select distinct footnote 
        into :outfootnotes 
        separated by "|"
        from tablecolumns
        where table="&reporttable" and not missing(footnote)
        order by footnote;
    quit;

    /*check to see if binary is a selection for t4cida and if followuptime or timetocensor is in tablecolums*/
    %let t4hoimethod = ;
	%let follup_time = ;
    
    %if %index(&reporttype,T4L1) %then %do;
    %do ru = 1 %to &numrunid.;
      %let runidru = %scan(&runidlist., &ru.);
	  %let t4hoimethod = &t4hoimethod &&&runidru._t4hoimethod;
	%end;

	proc sql noprint;
	  select distinct(columnname), order into: follup_time separated by ' ', :dummyord
	  from tablecolumns
	  where table = 't4cida' and (column like '%followuptime%' or column like  '%timetocensor%')
      order by order;
    quit;
	%put follup_time = &follup_time;
    %end;

    data _footnotes; 
       length footnote_order 3; 
       set lookup.lookup_footnotes(where=((type =
          %if "&reporttable" ne "t4cida" %then %do;
            "t1t2conc" and order in ( 0
            %if %index(&stratavar.,race) %then %do;
              1
            %end;
            %if %str("&outfootnotes.") = %str("1") %then %do;
              2
            %end;
            %if %str("&outfootnotes.") = %str("2") %then %do;
              3
            %end;
            %if %str("&outfootnotes.") = %str("3") %then %do;
              4
            %end;
            %if %str("&outfootnotes.") = %str("2|3") %then %do;
              5
            %end;
            %if %str("&outfootnotes.") = %str("1|3") %then %do;
              6
            %end;
            %if %str("&outfootnotes.") = %str("1|2") %then %do;
              7
            %end;
            %if %str("&outfootnotes.") = %str("1|2|3") %then %do;
              8
            %end;
			%if %index(&stratavar.,race) & &collapse_vars. = race %then %do;
              10
            %end;)))
          %end;
          %else %do;
		     "type4" and order = -2) 
			%if %index(&stratavar.,race) %then %do;
			  or (type = "t1t2conc" and order = 1)
			%end;
	        %if %sysfunc(findw(&t4hoimethod, binary)) and %length(&follup_time) > 0 %then %do;
	          or (type = "t4cida" and order = 9)  
	        %end;
			%if %index(&stratavar.,race) & &collapse_vars. = race %then %do;
              or (type = "t1t2conc" and order = 10)
             %end;)
          %end; 
           );
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

	%assign_superscripts(type=title, order = 1 %if "&reporttable" = "t4cida" %then %do; -2 %end;);
	%if %sysfunc(findw(&t4hoimethod, binary)) and %length(&follup_time) > 0 %then %do;
	  %assign_superscripts(type=column, order = 9);	
	%end;
	%if "&reporttable" ne "t4cida" %then %do;
      %assign_superscripts(type=line, order =  2 3 4 5 6 7 8);
	%end;
	%assign_superscripts(type=raceunknown, order = 10);

    /*clean up*/
    proc datasets nowarn noprint lib=work;
      delete _footnotes;
    quit;

    /*Save dataset to repdata folder and create newcategory variable if >=2 stratification variables. 
      this variable is used as a computed header in the proc report*/

    /* Stratification count */
    %let countstrata = %sysfunc(countw(&stratavar));

    %isdata(dataset=repdata.table&tablenum.&tableletter.);
    %if %eval(&nobs.<1) %then %do;
	    /* check to see if footnote needs attached to column */
	    %if %sysfunc(findw(&t4hoimethod, binary)) and %length(&follup_time) > 0 %then %do;
		  /*get new columnlabels and add super script*/
		    proc sql noprint;
			  %do ft = 1 %to %sysfunc(countw(&follup_time));
		        %let current_column = %scan(&follup_time., &ft.,%str( ));
			    select columnlabel into: current_label&current_column.  
			    from tablecolumns
			    where table = 't4cida' and columnname =  "&current_column";
              %end;
			quit;
        %end;
		    
    	data repdata.table&tablenum.&tableletter;
    		set &dataset;
            %if &includeheaderrow = Y %then %do;
                if missing(header) then header=grouplabel;
            %end;

            %if %sysfunc(findw(&t4hoimethod, binary)) and %length(&follup_time) > 0 %then 
              %do ft = 1 %to %sysfunc(countw(&follup_time));
                %let current_column = %scan(&follup_time., &ft.,%str( ));
                label &current_column._char = "%trim(&&&current_label&current_column.)&super_column";  
              %end; 

            %if &countstrata >=2 %then %do;
                length newcategory $90;
                newcategory = "";

                %do cat = 1 %to %eval(&countstrata-1);
                    %if &cat. = 1 %then %do;
                    newcategory = strip(%scan(&stratavar., &cat.));;
                    %end;
                    %else %do;
                    newcategory = cat(strip(newcategory),", ", strip(%scan(&stratavar., &cat.)));;
                    %end;
                %end;        
            %end;

            /*if collapse_vars = race, add superscript to 'Unknown' category*/
            %if %index(&stratavar,race) & &collapse_vars. = race %then %do;
                if index(race,'Unknown')>0 then race= cats(race,"&super_raceunknown."); 
                %if &countstrata >=2 and %lowcase(%scan(&stratavar., &countstrata)) ne race %then %do;
                    if index(race,'Unknown')>0 then newcategory= cats(newcategory,"&super_raceunknown."); 
                %end;
            %end;
    	run;

        /* Output meta-data for sort order names and labels */
        proc contents data = repdata.table&tablenum.&tableletter noprint out = _tablesort&tablenum.&tableletter(keep=name label);
        run;

        %let tablesort = ;
        
        /* Iterate over each stratification individually to obtain correct order for ordering*/
        %do sortnum = 1 %to &countstrata;
            %let restrata = %scan(&stratavar,&sortnum);
            proc sql noprint;
                select name 
                into :tablesort&sortnum 
                from _tablesort&tablenum.&tableletter
                where name contains 'sortorder' and label = "&restrata._sort";
            quit;

            %if &restrata = zip3 %then %let tablesort&sortnum = &&tablesort&sortnum zip3;
            %if &restrata = state %then %let tablesort&sortnum = &&tablesort&sortnum sortorder_state;

            %if %length(&tablesort) = 0 %then %let tablesort = &&tablesort&sortnum;
            %else %let tablesort = &tablesort &&tablesort&sortnum;
        %end;

        proc sort data = repdata.table&tablenum.&tableletter;
            by order &tablesort;
        run;

        /*Modify footnotes # to reassign eligible member/member day footnote # from 1 to 2 if table stratified by race*/
    	%if %index(&stratavar,race) %then %do;
            proc contents data = repdata.table&tablenum.&tableletter out=t noprint;
        	run; 
        	
            %let label_change_var=;
            %let label_change=;

        	proc sql noprint;
        	  select name, label, varnum
              into: Label_change_var separated by ' ', :Label_change separated by '@', :dummyordervar
        	  from t
              where label contains ("super 1")
              order by varnum;
        	quit;

            %if %length(&label_change_var) > 0 %then %do;
                %let label_change2 = %sysfunc(tranwrd(%bquote(&label_change),%str(super 1),%str(super 2)));
        	
            	proc datasets lib=repdata nolist;
                    modify table&tablenum.&tableletter;
                    %let val = %sysfunc(countw(&label_change_var));
            	    %do lab = 1 %to &val;
            	      label %scan(&label_change_var, &lab, ' ') = "%scan(%bquote(&label_change2.), &lab., %str(@))";
                    %end;
                quit;

                proc datasets lib=work noprint nowarn;
                    delete t;
                quit;
        	%end;
        %end;
    %end; /*save data to repdata folder*/

    /*Write to report*/
    %if &destination = excel %then %do;
	ods excel options(sheet_name="Table &tablenum.&tableletter" tab_color='green');
    %end;
    ods proclabel = "Table &tablenum.&tableletter";

     proc report data = repdata.table&tablenum.&tableletter nofs nowd spanrows missing headskip split="*"
        style(header)=[rules=none vjust=b] split='*'
        style(report)=[rules=none frame=void cellpadding =1.75pt];
 
        columns %if &includeheaderrow = Y %then %do; header %end; order grouplabel 
                %if &countstrata >= 2 %then %do; newcategory %end; 
                %if &stratavar. ne overall %then %do;&stratavar. %end;  &varlist.;

        %if &includeheaderrow = Y %then %do; 
        define header / group noprint order=data ' ';
        %end;
		define order / group order=data noprint;
        
        /*if overall - print grouplabel, if stratified - group label will be in compute block*/
        %if &stratavar. = overall %then %do;
        define grouplabel / group "" order=data style(column)=[just=L width =1.5in fontstyle=italic] style(header)=[background = GGR borderleftcolor = GGR]; 
        %end;
        %else %do;
        define grouplabel /group noprint;
        %end;

        %if &countstrata >= 2 %then %do;
        define newcategory / order noprint order=data ' ';
        %end;

        /*stratifications*/
        %if &stratavar. ne overall %then %do;
        %do c = 1 %to &countstrata;         
            %let cat = %scan(&stratavar., &c.);
             %if &countstrata = 1 or &c. = &countstrata %then %do;
                define &cat. / id ' ' 
                    style(column)=[just=L
                        %if "%lowcase(&cat.)" = "race" or "%lowcase(&cat.)" = "hispanic" %then width= 2.3in;
                                                                                         %else %if "%lowcase(&cat.)" = "agegroup" %then width = 1.1in;
                                                                                         %else %if "%lowcase(&cat.)" = "hhs_reg" %then width = 1.35in;
                                                                                         %else %if %index("%lowcase(&cat.)", covar) >0 %then width = 2in;
                                                                                         %else width =.81in; indent=20] 
                        style(header)=[just=C borderbottomcolor=black backgroundcolor=GGR];
            %end;
             %else %do;
                define &cat. / noprint;
             %end;
        %end; 
        %end; 

        /*columns*/
        %do v = 1 %to %sysfunc(countw(&varlist.));
            %let varname = %lowcase(%scan(&varlist., &v.,%str( )));
			%let varwidth = %lowcase(%scan(&varwidths., &v.,%str( )));
            %let varsmallcell = %lowcase(%scan(&varsmallcells., &v.,%str( )));
			
			   define &varname. / display 
                     style(column)=[width=&varwidth. just=c %if %str("&varsmallcell.") = %str("y") %then %do; background=$backgroundfmt. %end; tagattr='type:string'] 
					 style(header)=[just=C borderbottomcolor=black backgroundcolor=GGR borderrightcolor=GGR borderleftcolor=GGR];
        %end;

		/* Add title */
		compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                       borderbottomwidth=&bordersize tagattr="wrap:yes" cellheight=.3in];
        line "Table &tablenum.&tableletter.. &title.&super_title.";
		endcomp;

        /*add header line*/
        %if &includeheaderrow = Y %then %do;
        compute before header / style=[backgroundcolor=LIGGR font_weight=bold just=L bordertopcolor=black borderbottomcolor=black];
            length text $100;
            text = header;
            num = 100;
            line text $varying. num;
        endcomp;
        %end;
        
        /*add grouplabel*/
        %if &stratavar. ne overall %then %do; 
        compute before grouplabel / 
                    %if &includeheaderrow = Y %then %do; 
                    style=[background=white just=L fontstyle=italic bordertopcolor=white borderbottomcolor=white];
                    %end;
                    %else %do;
                    style=[background=LIGGR just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
                    %end;
            length text $100;
            text = grouplabel;
            num = 100;
            line text $varying. num;    
        endcomp;
        %end;

        %if &countstrata >= 2 %then %do;
        /*add grouplabel*/
        compute before newcategory / style=[fontstyle=italic just=L font_weight=medium bordertopcolor=white borderbottomcolor=white];
            length text $100;
            text = newcategory;
            num = 100;
            line text $varying. num;    
        endcomp;
        %end;

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

%mend t1t2t4conc_output;
