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

%macro t4tables_output(table=, dataset=, tabnum=, title=, varlist=, varwidths=, varsmallcells=);

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

     
    /*Write to report*/
    %if &destination = excel %then %do;
	ods excel options(sheet_name="Table &tabnum." tab_color='green');
    %end;
    ods proclabel = "Table &tabnum.";


%mend t4tables_output;
