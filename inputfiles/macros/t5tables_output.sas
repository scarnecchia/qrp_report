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
	
	%let header=;
	data repdata.table&tablenum.&tableletter.;
		set &dataset.;
		if missing(header)=0 then call symputx('header','header');
	run;
	
	proc sql noprint;
	select max(sortorder1), max(sortorder2)
	  into :maxorder1, :maxorder2
	 from &dataset.;
	quit;
	%put maxorder1 = &maxorder1.;
	%put maxorder2 = &maxorder2.;
	
    %let num_fn = 0;	
	
	%let t5title = ;
	%let tabletitle = ;
	%let categories = ;
	%let num_categories = ;

	%if %sysfunc(prxmatch(m/T18_|T19_|T20_|T21_|T22_/i,&dataset.)) > 0 %then %do;
		data _null_;
			set MASTER_TYPEFILE;
			%if %sysfunc(prxmatch(m/T18_/i,&dataset.)) > 0 %then %do;
				call symputx('categories', cfdd_output_cat);	
			%end;
			%if %sysfunc(prxmatch(m/T19_|T20_/i,&dataset.)) > 0 %then %do;
				call symputx('categories', afdd_output_cat);	
			%end;
			%if %sysfunc(prxmatch(m/T21_|T22_/i,&dataset.)) > 0 %then %do;
				call symputx('categories', cumdose_output_cat);	
			%end;
		run;

        /*Footnotes*/
        proc sql noprint;
          select max(order) into: num_fn trimmed
          from %substr(&dataset.,1,3)_lookup_footnotes_dose;
        quit;

        %if %eval(&num_fn.>0) %then %do;
        proc sql noprint;
          select description into: fn1 - :fn&num_fn.
          from %substr(&dataset.,1,3)_lookup_footnotes_dose
          order by order;
        quit;
        %end;        
	%end;
	%else %do;
		data _null_;
			set tablefile;
			if "&dataset" = catx('_',table,put(stratificationorder,1.)) then do;
				call symputx('categories', categories);
				if tablesub = 'overall' and "&stratifybydp." = "Y" then call symputx('tabletitle', ', by Data Partner');
				else call symputx('tabletitle', tabletitle);
			end;
		run;
	%end;
	
	%let num_categories = %sysfunc(countw(&categories, ' '));
	
	%if %sysfunc(prxmatch(m/T18_|T19_|T20_|T21_|T22_/i,&dataset.)) > 0 %then %do;
		%if &labelfileexists = Y %then %do;
			%let labeltype = ;
			%if %sysfunc(prxmatch(m/T18_/i,&dataset.)) > 0 %then %let labeltype = cfddcatlabel;
			%if %sysfunc(prxmatch(m/T19_|T20_/i,&dataset.)) > 0 %then %let labeltype = afddcatlabel;
			%if %sysfunc(prxmatch(m/T21_|T22_/i,&dataset.)) > 0 %then %let labeltype = cumdosecatlabel;
			%do c =1 %to &num_categories.;
				%let lbl&c. = Dose Group &c.;
			%end;
			data _null_;
				set labelfile(where=(labeltype="&labeltype."));
				%do c = 1 %to &num_categories.;
					if labelvar = "dosecat&c" then call symputx("lbl&c.", label);
				%end;
			run;
		%end;
	%end;
	
	/* Categorical */
	%if &reporttype. = cat %then %do;
		
		%let t5head = Number of Dispensings by Days Supplied;
		%let t5type = Dispensings;
		%if %index(&dataset,T1_) %then %do; %let t5title = Categorical Summary of Days Supplied per Dispensing; %end;
		%else %if %index(&dataset,T3_) %then %do; %let t5title = Categorical Summary of Patients%str(%') Cumulative Exposure Duration,; %end;
		%else %if %index(&dataset,T5_) %then %do; %let t5title = Categorical Summary of All Treatment Episodes,; %end;
		%else %if %index(&dataset,T7_) %then %do; %let t5title = Categorical Summary of First Treatment Episodes,; %end;
		%else %if %index(&dataset,T9_) %then %do; %let t5title = Categorical Summary of Second and Subsequent Treatment Episodes,; %end;
		%else %if %index(&dataset,T18_) %then %do; 
			%let t5title = Summary of Filled Daily Dose in Each Dispensing,; 
			%let t5head = Number of Dispensings by Filled Daily Dose; 
		%end;
		%else %if %index(&dataset,T19_) %then %do; 
			%let t5title = Summary of Average Filled Daily Dose in Each Treatment Episode,; 
			%let t5head = Number of Episodes by Average Filled Daily Dose; 
			%let t5type = Episodes;
		%end;
		%else %if %index(&dataset,T20_) %then %do; 
			%let t5title = Summary of Average Filled Daily Dose in Each Patient%str(%')s First Valid Episode,; 
			%let t5head = Number of Patients by Average Filled Daily Dose in First Treatment Episode; 
			%let t5type = Patients;
		%end;
		%else %if %index(&dataset,T21_) %then %do; 
			%let t5title = Summary of Cumulative Filled Dose in All Treatment Episodes,; 
			%let t5head = Number of Patients by Cumulative Filled Dose; 
			%let t5type = Patients;
		%end;
		%else %if %index(&dataset,T22_) %then %do; 
			%let t5title = Summary of Cumulative Filled Dose in Each Patient%str(%')s First Treatment Episode,; 
			%let t5head = Number of Patients by Cumulative Filled Dose in First Treatment Episode; 
			%let t5type = Patients;
		%end;
        
		%if &destination = excel %then %do;
			ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="green");
		%end;
		ods proclabel = "Table &tablenum.&tableletter.";		
        proc report data=repdata.table&tablenum.&tableletter. nofs nowd spanrows missing
            style(header)=[rules=none frame=void vjust=b borderbottomcolor=bgr bordertopcolor=bgr background=bgr borderleftcolor=black borderrightcolor=black] split='*'
            style(report)=[rules=none frame=void cellpadding=1.75pt];	
			
			column &header. order sortorder1 sortorder2 grouplabel total_count_char ("&t5head." 
					  %do s = 1 %to %eval(&num_categories);
		%if %sysfunc(prxmatch(m/T18_|T19_|T20_|T21_|T22_/i,&dataset.)) > 0 %then %do;
						 ("^S={ borderleftcolor=bgr bordertopcolor=black}&&lbl&s.."
		%end;
		%else %do;
						 %let t5cat = %scan(&categories., &s, %str( ));
						 ("^S={ borderleftcolor=bgr bordertopcolor=black}&t5cat. Days"
		%end;
						 _&s._char _&s._percent_char)
                      %end;
					);

				%if %str("&header.") ne %str("") %then %do; 
				define header / group noprint order=data;
				%end;
			   	define order / order noprint order=data;
			   	define sortorder1 / order noprint order=data;
			   	define sortorder2 / order noprint order=data;
				define grouplabel / display ''
					style(column)=[just=L] 
					style(header)=[background = bgr borderleftcolor= bgr borderrightcolor=bgr borderbottomcolor=black];
				define total_count_char / display "Total Number*of &t5type."  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1 borderbottomcolor=black];	
				%do s=1 %to %eval(&num_categories);
					define _&s._char / display "Number of*&t5type."  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderleftwidth=1 borderrightcolor=bgr bordertopcolor=black borderbottomcolor=black];
					define _&s._percent_char / display "Percent of Total*&t5type."  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1 bordertopcolor=black borderbottomcolor=black];	
				%end;

            /*format grouplabel*/
            compute grouplabel;
                if sortorder1=0 then do;
					%if %str("&header.") ne %str("") %then %do; 
						call define (_col_,"style","style=[fontstyle=italic]");
					%end;
					%else %do;
						if &maxorder1=0 then call define (_col_,"style","style=[fontstyle=italic]");
						else call define (_row_,"style","style=[background=libgr font_weight=bold bordertopcolor=black borderbottomcolor=black]");
					%end;
				end;
				else if &maxorder1=1 then call define(_col_,'style','style={indent=.15in}');
				else do;
					if sortorder2 = 0 then call define(_col_,'style','style={indent=.15in}');
					else if sortorder2 ne 0 then call define(_col_,'style','style={indent=.25in}');
				end;
            endcomp;

            /*Add title*/
            compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           borderbottomwidth=&bordersize tagattr="wrap:no" cellheight=.3in];
				line "Table &tablenum.&tableletter.. &t5title. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.";
            endcomp;
          
            /*Add header rows*/
			%if %str("&header.") ne %str("") %then %do; 
            compute before header / style=[background=libgr foreground=black just=L font_weight=bold bordertopcolor=black bordertopwidth=1 borderbottomcolor=black]; 
				text = header;
				num = 100;
				line text $Varying. num;
            endcomp; 
			%end;

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
		%else %if %index(&dataset,T4_) %then %do; %let t5title = Continuous Summary of Patients%str(%') Cumulative Exposure Duration; %end;
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
            style(header)=[rules=none frame=void vjust=b borderbottomcolor=bgr bordertopcolor=bgr background=bgr borderleftcolor=black borderrightcolor=black] split='*'
            style(report)=[rules=none frame=void cellpadding=1.75pt];

			column &header. order sortorder1 sortorder2 grouplabel total_count_char ("Distribution of Days Supplied by Dispensing" min_char p25_char median_char p75_char max_char mean_char std_char);
				%if %str("&header.") ne %str("") %then %do; 
				define header / group noprint order=data;
				%end;
			   	define order / order noprint order=data;
			   	define sortorder1 / order noprint order=data;
			   	define sortorder2 / order noprint order=data;
				define grouplabel / display ''
					style(column)=[just=L] 
					style(header)=[background = bgr borderleftcolor= bgr borderrightcolor=bgr borderbottomcolor=black];
				define total_count_char / display 'Total Number*of Dispensings'  
					style(column)=[background=$backgroundfmt. tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=bgr borderleftwidth=1 borderrightcolor=bgr borderbottomcolor=black];
				define min_char / display 'Minimum' 
					style(column)=[tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderleftwidth=1 borderrightcolor=bgr bordertopcolor=black borderbottomcolor=black];	
				define p25_char / display 'Q1' 
					style(column)=[tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderrightcolor=bgr borderrightwidth=1 bordertopcolor=black borderbottomcolor=black];	
				define median_char / display 'Median' 
					style(column)=[tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderrightcolor=bgr borderrightwidth=1 bordertopcolor=black borderbottomcolor=black];		
				define p75_char / display 'Q3' 
					style(column)=[tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderrightcolor=bgr borderrightwidth=1 bordertopcolor=black borderbottomcolor=black];			
				define max_char / display 'Maximum' 
					style(column)=[tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderrightcolor=bgr borderrightwidth=1 bordertopcolor=black borderbottomcolor=black];		
				define mean_char / display 'Mean' 
					style(column)=[tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderrightcolor=bgr borderrightwidth=1 bordertopcolor=black borderbottomcolor=black];			
				define std_char / display 'Standard*Deviation' 
					style(column)=[tagattr="type:string"] 
					style(header)=[background = bgr borderleftcolor=black borderrightcolor=bgr borderrightwidth=1 bordertopcolor=black borderbottomcolor=black];	

            /*format grouplabel*/
            compute grouplabel;
                if sortorder1=0 then do;
					%if %str("&header.") ne %str("") %then %do;
						call define (_col_,"style","style=[fontstyle=italic]");
					%end;
					%else %do;
						if &maxorder1=0 then call define (_col_,"style","style=[fontstyle=italic]");
						else call define (_row_,"style","style=[background=libgr font_weight=bold bordertopcolor=black borderbottomcolor=black]");
					%end;
				end;
				else if &maxorder1=1 then call define(_col_,'style','style={indent=.15in}');
				else do;
					if sortorder2 = 0 then call define(_col_,'style','style={indent=.15in}');
					else if sortorder2 ne 0 then call define(_col_,'style','style={indent=.25in}');
				end;
            endcomp;

			/* Add title */
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           borderbottomwidth=&bordersize tagattr="wrap:no" cellheight=.3in];
            line "Table &tablenum.&tableletter.. &t5title. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.";
			endcomp;
          
            /*Add header rows*/
			%if %str("&header.") ne %str("") %then %do;
            compute before header / style=[background=libgr foreground=black just=L font_weight=bold bordertopcolor=black bordertopwidth=1 borderbottomcolor=black]; 
				text = header;
				num = 100;
				line text $Varying. num;
            endcomp; 
			%end;
         
            /*Add thick line to bottom of report*/
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
            endcomp;
        run;
	%end;	/* Continuous */
		

	%put =====> END MACRO: t5tables_output;

%mend;
