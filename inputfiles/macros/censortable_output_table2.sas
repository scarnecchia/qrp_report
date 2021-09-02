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
*  PARAMETERS: •	
*   - Tablename – dataset name (t1censor/t2censor/t2followuptime/t5censor/t5censor_first)
*	- Title – table title
*	- Where – where clause to filter the &tablename dataset
*   - Reasonlist – list of reasons to include in table  
*   - Tablenum - number for table 
*   - episodesorpatients: Episodes or Patients label
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
%macro censortable_output_table2 (Tablename=, Title=, Where=, Reasonlist=, tablenum=, stratification = );
            
    /*Save to reportdata folder*/
    %isdata(dataset=repdata.table&tablenum.);
	%let nobs = 4;
    %if %eval(&nobs.>1) %then %do;
        data repdata.table_&Tablename._T&tablenum.;
            set &tablename(where=(&where.));
        run;
    %end;

  /*Footnotes*/
/*    data _footnotes;*/
/*	   length footnote_order 3; */
/*       set lookup.lookup_footnotes_censortables(where = (order in (*/
/*       %if %str("&episodesorpatients.") = %str("Episodes") %then %do; 1; %end;*/
/*       %if %str("&episodesorpatients.") = %str("Patients") %then %do; 2; %end;*/
/*       %if &tablename. = t1censor | &tablename. = t2censor %then %do; 3 %end;*/
/*       %if %index(&reasonlist.,cens_episend)>0 %then %do; 4 %end;*/
/*       %if %index(&reasonlist.,cens_event)>0 %then %do; 5 %end;*/
/*       %if %index(&reasonlist.,cens_spec)>0 %then %do; 6 %end;*/
/*       %if %index(&reasonlist.,cens_dth)>0 %then %do; 7 %end;*/
/*       %if %index(&reasonlist.,cens_elig)>0 %then %do; 8 %end;*/
/*       %if %index(&reasonlist.,cens_dpend)>0 %then %do; 9 %end;*/
/*       %if %index(&reasonlist.,cens_qryend)>0 %then %do; 10 %end; )));*/
/*	  by order;*/
/*	  footnote_order = _n_;*/
/*    run;*/
/**/
/*    proc sql noprint;*/
/*	  select count(order) into: num_fn trimmed*/
/*	  from _footnotes;*/
/*    quit;*/
/**/
/*    %if %eval(&num_fn.>0) %then %do;*/
/*    proc sql noprint;*/
/*	  select description into: fn1 - :fn&num_fn.*/
/*	  from _footnotes*/
/*	  order by order;*/
/*	quit;*/
/*    %end;*/
/*    */
	/* Assign macro variables for superscipts */
/*	%assign_superscripts(type =title, order =1 2 3);*/
/*	%assign_superscripts(type =reason, order =4 5 6 7 8 9 10);*/
/**/
/*    proc datasets nowarn noprint lib=work;*/
/*        delete _footnotes;*/
/*    quit;*/
 
    ods excel options(sheet_name="Table &tablenum." tab_color= "green");
    ods proclabel = "Table &tablenum.";

    proc report data = repdata.table_&Tablename._T&tablenum. nofs nowd spanrows missing headskip split="*"
    	style(header)=[rules=none frame=void background=BGR borderleftcolor = BGR vjust=b] split='*'
	    style(report)=[rules=none frame=void cellpadding =1.5pt];
    		
    	columns %if &includeheaderrow = Y %then %do; headerlabel %end; grouplabel (%if &tablesub. ne overall %then %do; &tablesub. %end; epi_tot 

             ("^S={background=BGR}&title."
             %do i = 1 %to %sysfunc(countw(&censorreason));
                %let CEN_VAR = %lowcase(%scan(&censorreason., &i));
				    %if "&cen_var" = "cens_episend" %then %let cenlabel = End of Exposure Episode;
					%if "&cen_var" = "cens_event" %then %let cenlabel = Occurrence of Outcome of Interest;
					%if "&cen_var" = "cens_spec" %then %let cenlabel = Occurrence of User-Defined Censoring Criteria;
					%if "&cen_var" = "cens_dth" %then %let cenlabel = Evidence of Death;
					%if "&cen_var" = "cens_elig" %then %let cenlabel = Disenrollment;
					%if "&cen_var" = "cens_dpend" %then %let cenlabel = End of Data;
					%if "&cen_var" = "cens_qryend" %then %let cenlabel = End of Study Period;                                     
                ("^S={background=BGR}&cenlabel." &cen_var._tot_char &cen_var._tot_pct_char)
             %end;
            );

        /*if overall - print grouplabel, if stratified - group label will be in compute block*/
        %if %str("&stratification.") = %str("") %then %do;
    	define grouplabel / group "" order=data
    	  style(column)=[font_size=8pt color=black fontfamily=arial width =1.5in just=l] 
          style(header)=[just=C background=white borderbottomcolor=black];
        %end;

        define dpidsiteid /group noprint;  

        %if %str("&STRATIFICATION") ne %str("")  %then %do;
        define &STRATIFICATION / group noprint;
        define display_&STRATIFICATION / computed "" order=data 
/*         %if %bquote("&AGEGROUPFMT") ne %str("") and &STRATIFICATION = agegroup %then %do; format=$agefmt. %end;*/
         style(column)=[font_size=8pt color=black fontfamily=arial width =  /*%if %bquote("&AGEGROUPFMT") ne %str("") and &STRATIFICATION = agegroup %then %do; 1in %end; %else %do;*/ .5in /*%end;*/ just=l indent=10] style(header)=[just=C background=white borderbottomcolor=black];
        define grouplabel /group noprint;
        %end;

        define epi_tot_char / group "Total Number of &episodesorpatients" format = comma12.0
    	 style(column)=[width=1in tagattr="type:string" background= backgroundfmt.] 
            style(header)=[%if &destination. = excel %then %do;cellheight=50pt %end; just=C background = BGR borderleftcolor = BGR];

        %do i = 1 %to %sysfunc(countw(&censorreason));
            %let cen_var = %scan(&censorreason, &i., ' ');
            define &cen_var._tot_char / group "Number of &episodesorpatients" style(column)=[just=C width=37pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
            define &cen_var._tot_pct_char / group  "Percent of Total &episodesorpatients" style(column)=[just=C width=37pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        %end;


        /*Footnotes*/
/*        %if %eval(&num_fn.>0) %then %do;*/
/*    		compute after / style=[just=L nobreakspace=off borderbottomcolor=white bordertopcolor=black vjust=T fontsize=&footfontsize.*/
/*    		                        height=.75in bordertopwidth = &bordersize tagattr="wrap:yes"];*/
/*    		  %do f = 1 %to &num_fn.;*/
/*                line "^{super &f.}&&fn&f.";*/
/*    		  %end;*/
/*            endcomp;*/
/*        %end;*/

        where &where.;
    run;



%mend censortable_output_table2;
