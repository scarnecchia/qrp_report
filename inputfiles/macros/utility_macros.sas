****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: utility_macros.sas  
*
* Created (mm/dd/yyyy): 12/20/2015
* Last modified: 12/1/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program includes the following macros:
*   - %isdata() macro determines whether a dataset is empty or not
*   - %create_comma_charlist() macro converts space delimited list to comma delimited list with quotes
*   - %alphabetizevarutil() macro alphabetizes variables in a data step
*   - %tableletter() macro increments a letter suffix
*   - %varexist() macro checks for the existence of a variable
*   - %convert_categories() macro converts categories to mathematical expression
*	- %output_datasets() macro output SAS datasets  
*   - %nonrep() macro removes repeated words in macro variable
*	- %collapse_vars() macro collapses variables categories
*
*  Program inputs:                                                                                   
*   -
* 
*  Program outputs:                                                                                                                                       
*   -
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

*Macro to determine whether a dataset is empty or not;
%MACRO ISDATA(dataset=);
    %GLOBAL NOBS;
    %let NOBS=0;
    %if %sysfunc(exist(&dataset.))=1 and %LENGTH(&dataset.) ne 0 %then %do;
        data _null_;
        dsid=open("&dataset.");
        call symputx("NOBS",attrn(dsid,"NLOBS"));
        run;
    %end;   
%PUT &NOBS.;
%MEND ISDATA;

*Macro for converting macro variable with space deliminated list to comma deliminated list with quotation around each word;
%macro create_comma_charlist(inlist=, outlist=);
  %global &outlist.;

  %let countvars = %sysfunc(Countw(%quote(&inlist.), ' '));
    %do c = 1 %to &countvars.;
      %let word = %scan(%quote(&inlist),&c., ' ');
        %if &c. = 1 %then %do;
          %let &outlist. = "&word.";
        %end;
        %else %do;
          %let &outlist. = &&&outlist. , "&word.";
        %end;
    %end;
  %let &outlist = %upcase(&&&outlist);
%mend create_comma_charlist;

*Macro to alphabetize variables in a data step;
%macro alphabetizevarutil(array=, in=, out=);
    array &array.[10] $50 _temporary_;
      call missing(of &array.[*]);
       do i = 1 to dim(&array.) until(p eq 0);
        call scan(&in.,i,p,l);
          &array.[i] = substrn(&in.,p,l);
    end;
    call sortc(of &array.[*]);
    length &out. $100;
    &out. = catx(' ',of &array.[*]);
    drop i p l &in.;
%mend;

*Macro for incrementing table/figure letter suffix;
%macro tableletter();
  %if %eval(&tablecount = 0) %then %do;
    %let tableletter = ;
  %end;
  %else %do;
      %if %eval(%sysfunc(mod(&tablecount.,26))=0) %then %do;
        %let div = %eval((&tablecount. / 26)-1); %put &div.;
        %let secondplace = %eval(&tablecount - (26*&div));%put &secondplace.;
      %end; 
      %else %do;
        %let div = %sysfunc(int(&tablecount. / 26)); %put &div.;
        %let secondplace = %eval(&tablecount - (26*&div));%put &secondplace.;
      %end;

      %if %eval(&div = 0) %then %do;
        %let tableletter = %scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &tablecount.);
      %end;
      %else %do;
        %let tableletter = %scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &div.)%scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &secondplace);
      %end;
  %end;

  %put tableletter = &tableletter.;
  %let tablecount = %eval(&tablecount + 1); /*+1 to counter*/
%mend;

*Macro to check the existence of a variable;
%macro varexist (ds,var);
%local dsid rc ;
%let dsid = %sysfunc(open(&ds));
%if (&dsid) %then %do;
  %if %sysfunc(varnum(&dsid,&var)) %then 1;
  %else 0 ;
  %let rc = %sysfunc(close(&dsid));
%end;
%else 0;
%mend varexist;

/*********************************************************************************************/
/*   Define macro variables for superscripts that correspond to required footnotes           */
/*********************************************************************************************/   
  %macro assign_superscripts(type =, order =);
    %global super_&type.;
    %let super_&type. =;
    
    proc sql noprint;
      select cat('^{Super ',footnote_order,'}') into: super_&type. separated by '^{Super ,}'
      from _footnotes where order in (&order.);
    quit; 
  %mend assign_superscripts;

*Macro for converting categories to mathematical expression;
%macro convert_categories(var=, categories=);

  %global num_categories categories_boolean ;
  %let num_categories = ;
  %let categories_boolean = ;

  %let num_categories = %sysfunc(countw(&categories, ' '));
  %do loop = 1 %to &num_categories;
    /*variable list*/
    /*mathematical expressions*/
    %let cat = %scan(&categories., &loop., ' ');
    %put &cat.;
    /*no range of values (i.e. 0, <10, <=20, >60 >=75, 65+)*/
    %if %index(&cat., -) = 0 %then %do;
      %if %index(&cat.,+) > 0 %then %do;
        %let cat = &var>=%sysfunc(tranwrd(&cat., +, ));
      %end;
	  %else %if %index(&cat.,<) > 0 or %index(&cat.,=) > 0 or %index(&cat.,>) > 0 %then %do;
        %let cat = &var.&cat.;
      %end;
      %else %do;
        %let cat = &var.=&cat.;
      %end;
    %end;
    /*range of values inclusive of boundary (i.e. 25-50)*/
    %else %if %index(&cat., -) > 0 & %index(&cat., <) = 0 & %index(&cat., >) = 0 %then %do;
      %let cat = %sysfunc(tranwrd(&cat., -, <=&var.<=));
    %end;
    /*range of values inclusive of upper boundary, (i.e. 25<-60)*/
    %else %if %index(&cat., -) > 0 & %index(%scan(&cat., 1, '-'), <) > 0 %then %do;
      %let cat = %scan(&cat., 1, '-')&var.<=%scan(&cat., 2, '-');
    %end;
    /*range of values inclusive of lower boundary, (i.e. 50-<75)*/
    %else %if %index(&cat., -) > 0 & %index(%scan(&cat., 2, '-'), <) > 0 %then %do;
      %let cat = %scan(&cat., 1, '-')<=&var.%scan(&cat., 2, '-');
    %end;

    %let categories_boolean = &categories_boolean. &cat.;
  %end;

  %put &categories;
  %put &categories_boolean.;

%mend convert_categories;

%macro output_datasets (dataset=, inlib=work, outlib=, name=&infile.);
	%if &output_agg_data. = Y and &leavebehindreport = N %then %do;

		proc datasets library = &inlib;
	    copy out=&outlib. memtype=data;
	       select &dataset.(memtype=data)
	              ;
	 	quit;
		proc datasets library = &outlib.;
			change &dataset. = agg_&name.;
		quit;

	%end;
%mend output_datasets;

*Removes repeated words in a macro variable;
%macro nonrep(invar= , outvar= );
    %global &outvar;
    %let long = ;
    %if %str(&&&invar) ne %str() %then %do;
    %do w=1 %to %sysfunc(countw(&&&invar));
        %if %sysfunc(indexw(&long, %scan(&&&invar,&w))) = 0 %then %do;
            %let long = &long %scan(&&&invar,&w);
        %end;
    %end;
    %end;
    %let &outvar = &long.;
%mend;

*Collapse var categories;
%macro collapse_vars(dataset=, var=);

*assess levelid;
    proc sql noprint;
       select distinct strip(levelid1)  
	   into :levelToColl 
       from tablefile 
	   where tablesub = "&var." and dataset = "&table.";

        select distinct(tablesub) into: list separated by ' ' 
        from tablefile
        where dataset = "&table." and index(tablesub,"#") = 0;
	quit;

	%let list_pos=%sysfunc(countw(%substr(&list,1,%index(&list,&var.)+1)));  

	proc summary data = &dataset. (where = (level in ("&levelToColl."))) nway missing;
        class runid dpidsiteid level &grpvar. &var.;
		var npts;
        output out = nb_pts_&var. (drop = _:) sum=;
    run;

*assess categories to collapse;
	data nb_pts_&var.;
	set nb_pts_&var.;
	if 1 <= npts <= 10 then collapse=1; else collapse=0;
	run;
	proc sort data=&dataset.;
	by runid dpidsiteid &grpvar. &var.;
	run;

	data &var._renamed;
	merge &dataset. (in=a) nb_pts_&var. (in=b);
	by runid dpidsiteid &grpvar. &var.;
	if collapse = 1 then do;
		&var. = "Unknown"; 
		sortorder&list_pos.=5; 
	end;
	drop collapse;
	run;

*collapse rows;
	proc means data=&var._renamed nway noprint missing;
	var npts episodes adjustedcodecount rawcodecount daysupp amtsupp
          %if %index(&table,conc) = 0 %then %do;
             dennumpts dennummemdays timetocensor
		  %end;
		  %if %substr(&table,2,1) ne 1 %then %do;
		     eps_wevents all_events followuptime
		  %end;
		;
	class runid dpidsiteid level &grpvar. %do s = 1 %to &&numstrata_&table.; sortorder&s. %end; &&&table._stratification;
	output out=&dataset. (drop=_:) sum=;
	run;

%mend collapse_vars;
