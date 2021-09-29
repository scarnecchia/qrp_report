****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t1t2conc_output.sas  
* Created (mm/dd/yyyy): 09/21/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of T1/T2 and Concomitant Tables proc report output
*                                        
*  Program inputs:                                                                                   
*   - final_[t1cida/t2cida/t2conc]
*   - final_dps_[t1cida/t2cida/t2conc]
* 
*  Program outputs: 
* 	- repdata.table&tablenum.&tableletter
* 
*  PARAMETERS:               
*   - dataset = Input dataset (aggregated t1cida/t2cida/t2conc dataset)
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

%macro t1t2conc_output(dataset=,varlist=,stratavar=,varwidths=,varsmallcells=,title=);

    %let outfootnotes=;
    %let atleastoneheader=;

    %isdata(dataset=repdata.table&tablenum.&tableletter.);
    %if %eval(&nobs.<1) %then %do;
	data repdata.table&tablenum.&tableletter;
		set &dataset;
        length newcategory $80;
        newcategory = "";
        %if &includeheaderrow = Y %then %do;
        if missing(header) then header=grouplabel;
        %end;
     %if %sysfunc(countw(&stratavar.)) >=2 %then %do;
      %do cat = 1 %to %eval(%sysfunc(countw(&stratavar.))-1);
        %if &cat. = 1 %then %do;
          newcategory = strip(%scan(&stratavar., &cat.));;
        %end;
        %else %do;
          newcategory = cat(strip(newcategory),", ", strip(%scan(&stratavar., &cat.)));;
        %end;
      %end;        
    %end;
	run;
    %end;

	%if "&stratavar" = "race" %then %do;
	proc contents data = repdata.table&tablenum.&tableletter out = t noprint;
	run; 

	%let label_change_var = ;
	%let label_change = ;

	proc sql noprint;
	select name
      into: Label_change_var
	  separated by ' '
	  from t
      where label contains ("super 1") 
	  ;
	  select label
      into: Label_change
	  separated by ","
	  from t
      where label contains ("super 1") 
	  ;
	quit;
    
	%if "&label_change_var" ne "" %then %do;
	  data _null_;
	  label_change2 = tranwrd("&label_change", "super 1", "super 2");
	  call symput("label_change2", trim(label_change2));
	  run;
	
	  proc datasets lib=repdata nolist;
        modify  table&tablenum.&tableletter;
        %let val = %sysfunc(countw(&label_change_var));
	    %do lab = 1 %to &val;
	      label %scan(&label_change_var, &lab, ' ') = "%scan(%bquote(&label_change2.), &lab., %str(,))";
        %end;
      quit;
	%end;
    %end;

    proc sql noprint;
        select distinct footnote 
        into :outfootnotes 
        separated by "|"
        from tablecolumns
        where table="&reporttable" and not missing(footnote)
        order by footnote;
    quit;

     /* Select Footnotes */  
         data _footnotes;
           length footnote_order 3; 
           /* Always displayed across all types */
           set lookup.lookup_footnotes_t1t2conc (where=(order in ( 0
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
            )));
           by order;
           footnote_order = _n_;
        run;

		/* Need to rearrange the superscript for title when var = race*/
		%if "&stratavar." = "race" %then %do;
		  data _footnotes;
		    set _footnotes;
            if order = 8 then do; footnote_order = 0; order = 0; end; 
			footnote_order = footnote_order + 1;
			order = order +1;
		  run;
		%end;
		 
        proc sql noprint;
          select count(order) into: num_fn trimmed
          from _footnotes;
          
          %if &num_fn > 0 %then %do;
          select description into: fn1 - :fn&num_fn.
          from _footnotes
            order by order;
		   %end;
        quit;

      
		%assign_superscripts(type=title, order = 1);
        %assign_superscripts(type=line, order =  2 3 4 5 6 7 8);
		

    %if &destination = excel %then %do;
	ods excel options(sheet_name="Table &tablenum.&tableletter" tab_color='green');
    %end;
    ods proclabel = "Table&tablenum.&tableletter";

     proc report data = repdata.table&tablenum.&tableletter nofs nowd spanrows missing headskip split="*"
        style(header)=[rules=none vjust=b] split='*'
        style(report)=[rules=none frame=void cellpadding =1.75pt];
            
        columns (%if &reporttable = t2conc %then %do; analysisgrp %end; %else %do; group %end; level &stratavar. &varlist. header grouplabel newcategory);

        define header / order noprint order=data ' ';
        define grouplabel / order noprint order=data ' ';
        define newcategory / order noprint order=data ' ';
            
        define level / noprint;
            

        %do c = 1 %to %sysfunc(countw(&stratavar.));         
            %let cat = %scan(&stratavar., &c.);
             %if %sysfunc(countw(&stratavar.)) = 1 or &c. = %sysfunc(countw(&stratavar.)) %then %do;

                define &cat. / id ' ' 
                    style(column)=[just=L
                        %if "%lowcase(&cat.)" = "race" or "%lowcase(&cat.)" = "hispanic" %then width= 2.3in;
                                                                                         %else %if "%lowcase(&cat.)" = "agegroup" %then width = 1.1in;
                                                                                         %else %if "%lowcase(&cat.)" = "hhs_reg" %then width = 1.35in;
                                                                                         %else %if %index("%lowcase(&cat.)", covar) >0 %then width = 2in;
                                                                                         %else width =.81in; indent=20] 
                        style(header)=[just=C borderbottomcolor=black backgroundcolor=bgr];
            %end;
             %else %do;
                define &cat. / noprint;
             %end;

        %end;  
        %do v = 1 %to %sysfunc(countw(&varlist.));
            %let varname = %lowcase(%scan(&varlist., &v.,%str( )));
			%let varwidth = %lowcase(%scan(&varwidths., &v.,%str( )));
            %let varsmallcell = %lowcase(%scan(&varsmallcells., &v.,%str( )));
			
			   define &varname. / display 
                     style(column)=[width=&varwidth. just=c %if %str("&varsmallcell.") = %str("y") %then %do; background=background_n_fmt. %end;] 
					 style(header)=[just=C borderbottomcolor=black backgroundcolor=bgr borderrightcolor=bgr borderleftcolor=bgr];
        %end;

        %if &reporttable = t2conc %then %do;
        define analysisgrp / noprint;
        %end;
        %else %do;
        define group / noprint;
        %end;

		/* Add title */
		compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                       borderbottomwidth=&bordersize tagattr="wrap:yes" cellheight=.3in];
        line "Table &tablenum.&tableletter.. &title.&super_title.";
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
        
        /*add grouplabel*/
        compute before grouplabel / %if &includeheaderrow ^= Y %then %do;
                                        style=[%if &stratavar ^= overall %then %do;
                                                    backgroundcolor=libgr font_weight=bold bordertopcolor=black borderbottomcolor=black
                                               %end; 
                                               %else %do; 
                                               fontstyle=italic bordertopcolor=white borderbottomcolor=white
                                               %end; just=L];
                                    %end;
                                    %else %do;
                                    style=[fontstyle=italic just=L bordertopcolor=black borderbottomcolor=white];
                                    %end;

            length text $100;
            text = grouplabel;
            num = 100;
            line text $varying. num;    
        endcomp;

        %if %sysfunc(countw(&stratavar.)) >= 2 %then %do;
        /*add grouplabel*/
        compute before newcategory / style=[fontstyle=italic just=L font_weight=medium bordertopcolor=white borderbottomcolor=white];
            length text $100;
            text = newcategory;
            num = 100;
            line text $varying. num;    
        endcomp;
        %end;

        /* Add Footnotes */
        %if %str("&outfootnotes.") ne %str("") %then %do;
            %if &num_fn > 0 %then %do;
            compute after / style=[just=L nobreakspace=off borderbottomcolor=white bordertopwidth=&bordersize];
             line '';
              %do f = 1 %to &num_fn.;
                line "^{super &f}&&fn&f.";
              %end;
            endcomp;
            %end;
        %end;
        %else %do;
        compute after / style=[bordertopwidth=&bordersize borderbottomcolor=white];
             line '';
        endcomp;
        %end;
    run;

%mend t1t2conc_output;
