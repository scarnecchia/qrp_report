****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t1t2conc_createdata.sas  
* Created (mm/dd/yyyy): 05/14/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro produces tables for a standard Type 1 and Type 2 report
*                                        
*  Program inputs:                                                                                   
*   - For Type 1 requests: agg_t1cida.sas7bdat                                               
*   - For Type 2 requests: agg_t2cida.sas7bdat
*   - For Type 2 concomitance requests: agg_t1conc.sas7bdat
* 
*  Program outputs:                                                                                                                           
*   - For Type 1 requests aggregation across all data partners: agg_t1cida_summ.sas7bdat                             
*   - For Type 2 requests aggregation across all data partners: agg_t2cida_summ.sas7bdat
*   - For Type 2 concomitance requests: agg_t2conc_summ.sas7bdat 
*   - For Type 1 requests aggregation across all data partners by level: agg_t1cida_summ&level..sas7bdat                             
*   - For Type 2 requests aggregation across all data partners by level: agg_t2cida_summ&level.&level..sas7bdat
*   - For Type 2 concomitance requests by level: agg_t2conc_summ&level..sas7bdat 
* 
*  PARAMETERS: 
*  - for t1: table =t1_cida, grpvar = group
*  - for t2: table =t2_cida, grpvar = group
*  - for conc: table =t2_conc, grpvar = analysisgrp
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

%macro t1t2conc_createdata(table =, grpvar = );

    %put =====> MACRO CALLED: t1t2conc_createdata ;
	
   /************************************************************************************************
      Determine levels and stratifications               
    ************************************************************************************************/	
	/* Confirm a table columns file has been specified */
	%if %str("&tablecolumnsfile.") = %str("") %then %do;
	  %put ERROR: (Sentinel) Lookup table includes dataset &tdatasetlist., but tablecolumnsfile is not specified in &createreportfile. file.;
	  %abort;
	%end;
	
    proc sql noprint;
       /* Determine &table. levels and stratifications to store in macro variables*/
       select distinct quote(strip(levelid1))  
	   into :&table._levelid separated by ' '
       from tablefile where dataset = "&table.";
	 
       select distinct tablesub into: &table._stratification separated by ' ' 
            from tablefile
            where tablesub ne 'overall' and dataset = "&table.";
    quit;

   /************************************************************************************************
      Summarize data                 
    ************************************************************************************************/
    proc summary data = agg_&table. nway missing;
        class level &grpvar. %if %index(&&&table._stratification,agegroup) %then %do; agegroupnum %end;
              &&&table._stratification;
		  var npts episodes adjustedcodecount rawcodecount daysupp amtsupp
        %if %index(&table,conc) = 0 %then %do;
             dennumpts dennummemdays
		  %end;
		  %if %substr(&table,2,1) ne 1 %then %do;
		     eps_wevents all_events followuptime
		  %end;;
        output out = agg_&table._summ (drop = _:) sum=;
    run;
	
   /************************************************************************************************
      Determine total count of variables on table and put tablecolumns information into macro variables             
    ************************************************************************************************/
	proc sql noprint;
	  select count(column) into: numcolumns trimmed
	  from tablecolumns where table = "&table.";
		
	  select columnname 
	        ,column 
			,columnlabel
			,columnformat
			,scan(compress(column,'()'),1,'/') as numerator
			,scan(compress(scan(column,1,'*'),'()'),2,'/') as denominator
			,scan(compress(column,'()*0123456789.'),2,'/') as cidenominator
			,scan(column,2,'*') as multiplier
			,cirate
	   into: var1 -:var&numcolumns.
		    ,:formula1 - :formula&numcolumns.
			,:label1 - :label&numcolumns.
			,:format1 - :format&numcolumns.
			,:num1 - :num&numcolumns.
			,:denominator1 - :denominator&numcolumns.
			,:cidenom1 - :cidenom&numcolumns.
			,:multi1 - :multi&numcolumns.
			,:cirate1 - :cirate&numcolumns.
	  from tablecolumns where table = "&table.";
    quit;
	
   /************************************************************************************************
      Create covariatelist             
    ************************************************************************************************/
	 data _covars (keep = covarnum);
	   length covarnum 8;
	   set tablefile (where = (index(tablesub,'covar') > 0 and index(tablesub,'#') = 0 and dataset = "&table."));
	   covarstart = index(tablesub,'covar');
	   covarnum = input(compress(substr(tablesub,covarstart),'covar'),8.);
     run;
	 
	 proc sort nodupkey data = _covars;
	   by covarnum;
	 run;
	 
	 %let numcovars = 0;
	 %ISDATA(dataset=_covars); 
     %if &nobs > 0 %then %do;
	   proc sort nodupkey data = covarname(keep = covarnum studyname) out = _covarnames;
	     by covarnum;
	   run;
       
       proc sql noprint;
	     select count(covarnum) into: numcovars trimmed
	     from _covars;
	   
	     select cats('covar',a.covarnum),
                b.studyname
         into :covar1 - :covar&numcovars.,
              :study1 - :study&numcovars.
	     from _covars a
         left join _covarnames b
	     on a.covarnum = b.covarnum;
       quit;
     %end;
   /************************************************************************************************
       Prepare final summary datasets           
    ************************************************************************************************/ 
    /*Macro to finalize tables*/
    %macro prept1t2data(dsin=, dsout=, dpvar=, ind=, runid=);
       data _&dsout. (drop = lambda se ci_lower ci_upper p q);
         set &dsin.;
		 length lambda se ci_lower ci_upper p q 8;
		 call missing(lambda, se, ci_lower, ci_upper, p, q);
		/* Calculated vars and labels */
        %do vv = 1 %to &numcolumns;
		  label &&var&vv. = "&&label&vv.";
		  
	      %if %sysfunc(index(&&formula&vv.,/)) > 0 %then %do;
			 %if %str("&&cirate&vv.") = %str("R") %then %do;
			   format &&var&vv. $30.;
			   if &&cidenom&vv.. > 0 and &&num&vv. > 0then do;
                  lambda = &&formula&vv.;
			      se = sqrt(1/&&num&vv.);
			      ci_lower = exp(log(lambda) - 1.96 * se);
                  ci_upper = exp(log(lambda) + 1.96 * se);
			      &&var&vv. = strip(put(lambda, &&format&vv.)) || " (" || strip(put(ci_lower, &&format&vv.)) || ", " || strip(put(ci_upper, &&format&vv.)) || ")";
			   end;
			   else if &&num&vv. = 0 and &&cidenom&vv.. > 0 then do;
			      &&var&vv. = strip(put(0, &&format&vv.)) || " (" || strip(put(0, &&format&vv.)) || ", " || strip(put(0, &&format&vv.)) || ")";
			   end;
			   else &&var&vv. = "NaN";
             %end;	
			 %else %if %str("&&cirate&vv.") = %str("P") %then %do;
               format &&var&vv. $30.;			 
			   if &&cidenom&vv. > 0 then do;
                 p = %scan(&&formula&vv.,1,*);
			     q = 1 - p;
			     se = sqrt((p*q)/&&cidenom&vv.);
			     ci_lower = p - 1.96 * se;
                 ci_upper = p + 1.96 * se;
			     %if %eval(&&multi&vv. > 0) %then %do;
			       &&var&vv. = strip(put(p*&&multi&vv., &&format&vv.)) || "(" || strip(put(ci_lower*&&multi&vv., &&format&vv.)) || ", " || strip(put(ci_upper*&&multi&vv., &&format&vv.)) || ")";
			     %end;
			     %else %do;
			       &&var&vv. = strip(put(p, &&format&vv.)) || " (" || strip(put(ci_lower, &&format&vv.)) || ", " || strip(put(ci_upper, &&format&vv.)) || ")";
			     %end;
               end;
			   else &&var&vv. = "NaN";
			 %end;
			 %else %do;
			   format &&var&vv. &&format&vv.;
			   if &&denominator&vv. > 0 then &&var&vv. = &&formula&vv.;
			   else &&var&vv. =0;
			 %end;
		  %end;
		  %else %do;
		     format &&var&vv. &&format&vv.;
		     &&var&vv. = &&formula&vv.;
		  %end;
	    %end;
		
        /*labels for stratification variables*/
        %if %index(&&&table._stratification,state) %then %do;
            if state in ("Invalid", "Missing") and episodes lt 1 then delete;
        %end;

        label
              %if %index(&&&table._stratification,sex) %then %do;
              sex = "Sex"
              %end;
              %if %index(&&&table._stratification,agegroup) %then %do;
              Agegroup = "Age Group"
              %end;
              %if %index(&&&table._stratification,year) %then %do;
              year = "Year"
              %end;
              %if %index(&&&table._stratification,month) %then %do;
              month = "Month"
              %end;
              %if %index(&&&table._stratification,race) %then %do;
              race = "Race"
              %end;
              %if %index(&&&table._stratification,state)  %then %do;
              state = "State"
              %end;
              %if %index(&&&table._stratification,hhs_reg) %then %do;
              hhs_reg = "Health and Human Services (HHS) Region"
              %end;
              %if %index(&&&table._stratification,cb_reg) %then %do;
              cb_reg = "Census Bureau Region"
              %end;
              %if %index(&&&table._stratification,zip3) %then %do;
              zip3 = "3-Digit Zip Code/State"
              %end;
              %if %index(&&&table._stratification,zip_uncertain) %then %do;
              zip_uncertain = "Zip Uncertain"
              %end;
              %if %index(&&&table._stratification,hispanic) %then %do;
              hispanic = "Hispanic Origin"
              %end;

             /*covariate*/
             %if &numcovars. > 0 %then %do;
               %do c = 1 %to &numcovars.;
                  %if %index(&&&table._stratification,&&covar&c..) %then %do;
				    length _covar&covnum. $150;
                    label _covar&covnum. = "&&&covar&covnum.";
                    if covar&c. = 0 then _covar&c. = "No evidence of &&study&c..";
                    if covar&c. = 1 then _covar&c. = "Evidence of &&study&c.."; 
					drop covar&covnum.;
                    rename _covar&covnum. = covar&covnum.;
                  %end;
               %end;
             %end;
            ;                
        run;
		
		/* Apply labels */
		%isdata(dataset=labelfile);
		
        proc sql noprint;
          create table &dsout. as
          select a.*, b.order
		  %if %eval(&nobs.>0) %then %do;
		    ,d.label as header 
			,c.label as grouplabel 
		  %end;
          %else %do;
            ,"" as header 
			,"" as grouplabel 
           %end;				   
          from _&dsout. a 
		  left join groupsfile b
		  on strip(lowcase(a.&grpvar.)) = strip(lowcase(b.group))
		  %if %eval(&nobs.>0) %then %do;
		    left join labelfile (where = (labeltype = "grouplabel")) c
		    on strip(lowcase(a.&grpvar.)) = strip(lowcase(c.group))
		    left join labelfile (where = (labeltype = "headerlabel")) d
		    on strip(lowcase(a.&grpvar.)) = strip(lowcase(d.group))
		  %end;;
        quit;
		
		/* Assign sort order */
		data &dsout.;
		  set &dsout.;
		  %do ls = 1 %to %sysfunc(countw(&&&table._stratification.));
            %let strat = %scan(&&&table._stratification., &ls.);
		    %if &strat. = sex | &strat. = race | &strat. = hispanic | &strat. = hhs_reg | &strat. = cb_reg %then %do;
			  %if %index(&&&table._stratification.,&strat.) %then %do;
			    sortorder = put(&strat,$&strat.sort.);
			  %end;
			%end;
		  %end;
	    run;
		
		proc sort data = &dsout.;
		  by order sortorder;
		run;
    %mend;

    /*Overall*/
    %prept1t2data(dsin=agg_&table._summ, dsout=agg_&table._summ);

    %put =====> END MACRO: t1t2conc_createdata ;

%mend t1t2conc_createdata;
