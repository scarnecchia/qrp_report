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

%macro t1t2conc_output(dataset=);

	data repdata.table&tablenum.&tableletter;
		set &dataset;
	run;

	ods excel options(sheet_name="Table&tablenum.&tableletter");
    ods proclabel = "Table&tablenum.&tableletter";

     proc report data = repdata.table&tablenum.&tableletter nofs nowd spanrows missing headskip split="*"
        style(header)=[rules=none background=white font_weight=bold font_size=8pt color=black just = l fontfamily=arial vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
        style(report)=[rules=none frame=box background=white cellpadding =&line_spacing.pt color=black /*just=l*/];
            
        columns ("&title." group level &&var. &&varlist. header grouplabel newcategory);

        define header / order noprint order=data ' ';
        define grouplabel / order noprint order=data ' ';
        define newcategory / order noprint order=data ' ';
            
        %if "&&var." = "" %then %do;
        define level / id style=[backgroundcolor = white color = white];
        %end;
        %else %do;
        define level / noprint;
        %end;
            
        %do c = 1 %to %sysfunc(countw(&&var.));         
            %let cat = %scan(&&var., &c.);
             %if %sysfunc(countw(&&var.)) = 1 or &c. = %sysfunc(countw(&&var.)) %then %do;
                define &cat. / id 
                    style(column)=[font_size=8pt color=black fontfamily=arial
                        %if "%lowcase(&cat.)" = "race" or "%lowcase(&cat.)" = "hispanic" %then width= 2.3in;
                                                                                         %else %if "%lowcase(&cat.)" = "agegroup" %then width = 1.1in;
                                                                                         %else %if "%lowcase(&cat.)" = "hhs_reg" %then width = 1.35in;
                                                                                         %else %if %index("%lowcase(&cat.)", covar) >0 %then width = 2in;
                                                                                         %else width =.81in; just=l indent=20] 
                        style(header)=[just=C background=white borderbottomcolor=black];
            %end;
             %else %do;
                define &cat. / noprint;
             %end;

        %end;  
        %do v = 1 %to %sysfunc(countw(&varlist.));
            %let varname = %lowcase(%scan(&varlist., &v.,%str( )));
			%let varwidth = %lowcase(%scan(&varwidths., &v.,%str( )));
			%let varformat = %lowcase(%scan(&varformats., &v.,%str( )));
			%let varsmallcell = %lowcase(%scan(&varsmallcells., &v.,%str( )));
			
			   define &varname. / display format=&varformat.
                     style(column)=[font_size=8pt color=black fontfamily=arial width=&varwidth. just=c 
					      background = %if %str("&varsmallcell.") = %str("y") %then %do; background_n_fmt. %end; %else %do; background_greynum. %end;] 
					 %if %str("&varformat.") = %str("$30.") %then %do;
					    style(header)=[just=C width=.82in background=white borderbottomcolor=black];
					 %end;
					 %else %do;
					    style(header)=[just=C background=white borderbottomcolor=black];
			         %end;
        %end;

        define group / noprint;

			/* Add title */
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           borderbottomwidth=&bordersize tagattr="wrap:no" cellheight=.3in];
            line "Table &tablenum.&tableletter.. &t5title. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.";
			endcomp;

        /*add header line*/
        %if "&report0_header" = "Y" %then %do; 
            compute before header / style=[backgroundcolor=darkgray fontfamily=arial font_size=8pt color=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
            length text $100;
                text = header;
                num = 100;
                line text $varying. num;
            endcomp;
        %end;
        
        /*add grouplabel*/
        compute before grouplabel / style=[backgroundcolor=white  fontfamily=arial fontstyle=italic font_size=8pt color=black just=L font_weight = medium bordertopcolor=black ];
            length text $100;
            text = grouplabel;
            num = 100;
            line text $varying. num;    
        endcomp;
            
        %if %sysfunc(countw(&&var.)) ge 2 %then %do;
        /*add grouplabel*/
        compute before newcategory / style=[backgroundcolor=white fontfamily=arial fontstyle=italic font_size=8pt color=black just=L font_weight = medium bordertopcolor=black ];
            length text $100;
            text = newcategory;
            num = 100;
            line text $varying. num;    
        endcomp;
        %end;

        /*footnote in table*/
        %if %str("&outfootnotes.") ne %str("") %then %do;
        compute after / style=[just=L fontfamily=arial font_size=7.5pt color=black bordertopcolor=black];
            line '';

            *eligible members only;
            %if %str("&outfootnotes.") = %str("1") %then %do;
            line "^{super 1}Eligible Members are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period";
            %end;

            *eligible member days only;
            %if %str("&outfootnotes.") = %str("2") %then %do;
            line "^{super 1}Eligible Member-Days are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period";
            %end;

            *eligible member years only;
            %if %str("&outfootnotes.") = %str("3") %then %do;
            line "^{super 1}Eligible Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period";
            %end;

            *eligible member days and years;
            %if %str("&outfootnotes.") = %str("2|3") %then %do;
            line "^{super 1}Eligible Member-Days and Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period";
            %end;

            *eligible members and years;
			%if %str("&outfootnotes.") = %str("1|3") %then %do;
            line "^{super 1}Eligible Members and Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period";
            %end;

            *eligible members and days;
            %if %str("&outfootnotes.") = %str("1|2") %then %do;
		    line "^{super 1}Eligible Members and Member-Days are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period";
            %end;

            *eligible members, days, and years;
            %if %str("&outfootnotes.") = %str("1|2|3") %then %do;
			line "^{super 1}Eligible Members, Member-Days, and Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period";
            %end;
        endcomp;
        %end;
    run;

%mend t1t2conc_output;