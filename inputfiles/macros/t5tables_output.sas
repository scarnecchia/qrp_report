****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t5tables_output.sas  
* Created (mm/dd/yyyy): 08/25/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro includes two proc report procedures in order to produce a categorical and 
*          continuous table in the report for Type 5 analyses
*                                        
*  Program inputs:                                                                                   
*   - Dataset(s) computed in %t5tables_createdata
* 
*  Program outputs: 
*   - Dataset(s) to output/repdata for each figure
* 
*  PARAMETERS:  
*   - dataset: input dataset
*   - report: indicator whether to produce categorical (1) or continuous (2) metrics
*   
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

%macro t5tables_output(dataset=,
					   reporttype=);

	%put =====> MACRO CALLED: t5tables_output;
	
    %let num_fn = 0;
	
	%let t5title = ;
	%let tabletitle = ;
	%let num_categories = ;

	data _null_;
		set tablefile;
		if "&dataset" = catx('_',table,put(stratificationorder,1.)) then do;
			call symputx('categories', categories);
			if tablesub = 'overall' and "&stratifybydp." = "Y" then call symputx('tabletitle', ', by Data Partner');
			else call symputx('tabletitle', tabletitle);
		end;
	run;
	
	%let num_categories = %sysfunc(countw(&categories, ' '));
	
	data repdata.table&tablenum.&tableletter.;
		set &dataset.;
	run;
	
	/* Categorical */
	%if &reporttype. = cat %then %do;
	
		%if %index(&dataset,T1_) %then %do; %let t5title = Categorical Summary of Days Supplied per Dispensing; %end;
		%else %if %index(&dataset,T3_) %then %do; %let t5title = Categorical Summary of Patients%str(%') Cumulative Treatment Episode Durations; %end;
		%else %if %index(&dataset,T5_) %then %do; %let t5title = Categorical Summary of All Treatment Episodes; %end;
		%else %if %index(&dataset,T7_) %then %do; %let t5title = Categorical Summary of First Treatment Episodes; %end;
		%else %if %index(&dataset,T9_) %then %do; %let t5title = Categorical Summary of Second and Subsequent Treatment Episodes; %end;

		%if &destination = excel %then %do;
			ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="green");
		%end;
		ods proclabel = "Table &tablenum.&tableletter.";		
        proc report data=repdata.table&tablenum.&tableletter. nofs nowd spanrows missing
            style(header)=[rules=none frame=void vjust=b borderbottomcolor=bgr bordertopcolor=bgr background=bgr borderleftcolor=bgr] split='*'
            style(report)=[rules=none frame=void cellpadding=1.75pt];	
	
			column header grouplabel total_count_char ("Number of Dispensings by Days Supplied" 
					  %do s = 1 %to %eval(&num_categories);
						 %let t5cat = %scan(&categories., &s, %str( ));
						 ("^S={ borderleftcolor=ligr}&t5cat. Days" _&s._char _&s._percent_char)
                      %end;
					);
			   	define header /display ' ' 
					style(column)=[just=L] 
                    style(header)=[background = bgr borderleftcolor= bgr borderrightcolor=bgr];
			   	define grouplabel /display ' ' 
					style(column)=[just=L] 
                    style(header)=[background = bgr borderleftcolor= bgr borderrightcolor=bgr];
				define total_count_char / display 'Total Number*of Dispensings'  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;	
				%do s=1 %to %eval(&num_categories);
					define _&s._char / display 'Number of*Dispensings'  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderleftwidth=1 borderrightcolor=bgr] format=$nafmt.;
					define _&s._percent_char / display 'Percent of All*Dispensings'  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;	
				%end;

            /*Add title*/
            compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           borderbottomwidth=&bordersize tagattr="wrap:no" cellheight=.3in];
            line "Table &tablenum.&tableletter.. &t5title. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.";
            endcomp;

            /* Add Footnotes */
            %if %eval(&num_fn > 0) %then %do;
                compute after / style=[just=L borderbottomcolor=white bordertopcolor=black vjust=T fontsize=&footfontsize. bordertopwidth = &bordersize];
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
	%end;	/* Categorical */

	/* Continuous */
	%if &reporttype. = dist %then %do;
	
		%if %index(&dataset,T2_) %then %do; %let t5title = Continuous Summary of Days Supplied per Dispensing; %end;
		%else %if %index(&dataset,T4_) %then %do; %let t5title = Continuous Summary of Patients%str(%') Cumulative Treatment Episode Durations; %end;
		%else %if %index(&dataset,T6_) %then %do; %let t5title = Continuous Summary of All Treatment Episodes; %end;
		%else %if %index(&dataset,T8_) %then %do; %let t5title = Continuous Summary of First Treatment Episodes; %end;
		%else %if %index(&dataset,T10_) %then %do; %let t5title = Continuous Summary of Second and Subsequent Treatment Episodes; %end;
		%else %if %index(&dataset,T11_) %then %do; %let t5title = Continuous Summary of All Treatment Episode Gaps; %end;
		%else %if %index(&dataset,T12_) %then %do; %let t5title = Continuous Summary of First Treatment Episode Gaps; %end;
		%else %if %index(&dataset,T13_) %then %do; %let t5title = Continuous Summary of Second and Subsequent Treatment Episode Gaps; %end;

		%if &destination = excel %then %do;
			ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="green");
		%end;
		ods proclabel = "Table &tablenum.&tableletter.";		
        proc report data=repdata.table&tablenum.&tableletter. nofs nowd spanrows missing
            style(header)=[rules=none frame=void vjust=b borderbottomcolor=bgr bordertopcolor=bgr background=bgr borderleftcolor=bgr] split='*'
            style(report)=[rules=none frame=void cellpadding=1.75pt];

			column header grouplabel total_count_char ("Distribution of Days Supplied by Dispensing" min_char p25_char median_char p75_char max_char mean_char std_char);
			   	define header /display ' ' 
					style(column)=[just=L] 
                    style(header)=[background = bgr borderleftcolor= bgr borderrightcolor=bgr];
			   	define grouplabel /display ' ' 
					style(column)=[just=L] 
                    style(header)=[background = bgr borderleftcolor= bgr borderrightcolor=bgr];
				define total_count_char / display 'Total Number*of Dispensings'  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderleftwidth=1 borderrightcolor=bgr] format=$nafmt.;
				define min_char / display 'Minimum' 
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderleftwidth=1 borderrightcolor=bgr] format=$nafmt.;	
				define p25_char / display 'Q1' 
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;	
				define median_char / display 'Median' 
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;		
				define p75_char / display 'Q3' 
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;			
				define max_char / display 'Maximum' 
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;		
				define mean_char / display 'Mean' 
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;			
				define std_char / display 'Standard*Deviation' 
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;	

			/* Add title */
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           borderbottomwidth=&bordersize tagattr="wrap:no" cellheight=.3in];
            line "Table &tablenum.&tableletter.. &t5title. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.";
			endcomp;

            /* Add Footnotes */
            %if %eval(&num_fn > 0) %then %do;
                compute after / style=[just=L borderbottomcolor=white bordertopcolor=black vjust=T fontsize=&footfontsize. bordertopwidth = &bordersize];
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
	%end;	/* Continuous */
		

	%put =====> END MACRO: t5tables_output;

%mend;
