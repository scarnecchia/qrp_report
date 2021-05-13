****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t1t2conc_createdata.sas  
* Created (mm/dd/yyyy): 07/19/2017
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
*   - 
* 
*  PARAMETERS: 
*  - for t1: table =t1_cida , grpvar = group, analysistype = cida 
*  - for t2: table =t2_cida , grpvar = group, analysistype = cida 
*  - for conc: table =t2_conc, grpvar = analysisgrp, analysistype = conc 
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

%macro t1t2conc_createdata(table =, grpvar =, analysistype =);

    %put =====> MACRO CALLED: t1t2conc_createdata ;
	
    %isdata(dataset=tablelookup);
    %if %eval(&nobs.>0) %then %do;
	
	    data &analysistype._tablelookup;
           set tablelookup;
           where dataset = "&table.";
        run;

        proc sql noprint;
            /* Determine &analysistype. levels and stratifications to store in macro variables*/
            select distinct quote(strip(levelid1)) into: &analysistype._levelid separated by ' '
            from tablelookup where table = "&table.";

            select distinct tablesub into: &analysistype._stratification separated by ' ' 
                 from tablelookup
                 where tablesub ne 'overall' and table = "&table.";
        quit;

   /************************************************************************************************
      Summarize data                 
    ************************************************************************************************/
      proc summary data = agg_&table. nway missing;
          class level &grpvar. %if %index(&&&analysistype._stratification,agegroup) %then %do; agegroupnum %end;
                &&&analysistype._stratification;
	  	  var npts episodes adjustedcodecount rawcodecount daysupp amtsupp
          %if "&analysistype" ne "conc" %then %do;
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
			,footnote
	   into: var1 -:var&numcolumns.
		    ,:formula1 - :formula&numcolumns.
			,:label1 - :label&numcolumns.
			,:format1 - :format&numcolumns.
			,:num1 - :num&numcolumns.
			,:denominator1 - :denominator&numcolumns.
			,:cidenom1 - :cidenom&numcolumns.
			,:multi1 - :multi&numcolumns.
			,:cirate1 - :cirate&numcolumns.
			,:footnote1 - :footnote&numcolumns.
	  from tablecolumns where table = "&table.";
    quit;

    /************************************************************************************************
       Prepare final summary datasets           
     ************************************************************************************************/ 
    /*Macro to finalize tables*/
    %macro prept1t2data(dsin=, dsout=, dpvar=, ind=);
       data &dsout. (drop = lambda se ci_lower ci_upper p q);
         set &dsin.;
		 length lambda se ci_lower ci_upper p q 8;
		 call missing(lambda, se, ci_lower, ci_upper, p, q);
		/* Calculated vars and labels */
        %do vv = 1 %to &numcolumns;
		  %if &&footnote&vv. > 0 %then %do;
		    label &&var&vv. = "&&label&vv.^{super 1}";
		  %end;
		  %else %do;
		    label &&var&vv. = "&&label&vv.";
		  %end;
		  
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
        %if %index(&&&analysistype._stratification,state) %then %do;
            if state in ("Invalid", "Missing") and episodes lt 1 then delete;
        %end;

        label
              %if %index(&&&analysistype._stratification,sex) %then %do;
              sex = "Sex"
              %end;
              %if %index(&&&analysistype._stratification,agegroup) %then %do;
              Agegroup = "Age Group"
              %end;
              %if %index(&&&analysistype._stratification,year) %then %do;
              year = "Year"
              %end;
              %if %index(&&&analysistype._stratification,month) %then %do;
              month = "Month"
              %end;
              %if %index(&&&analysistype._stratification,race) %then %do;
              race = "Race"
              %end;
              %if %index(&&&analysistype._stratification,state)  %then %do;
              state = "State"
              %end;
              %if %index(&&&analysistype._stratification,hhs_reg) %then %do;
              hhs_reg = "HHS Region"
              %end;
              %if %index(&&&analysistype._stratification,cb_reg) %then %do;
              cb_reg = "Census Region"
              %end;
              %if %index(&&&analysistype._stratification,zip3) %then %do;
              zip3 = "3-Digit Zip/State"
              %end;
              %if %index(&&&analysistype._stratification,zip_uncertain) %then %do;
              zip_uncertain = "Zip Uncertain"
              %end;
              %if %index(&&&analysistype._stratification,hispanic) %then %do;
              hispanic = "Hispanic"
              %end;

             /*covariate*/
             %if %str(&covarlist) ne %str() %then %do;
                %do c = 1 %to %sysfunc(countw(&covarlist.));
                    %let w = %lowcase(%scan(&covarlist., &c.));
                    %let covnum = %substr(&w., 6);
                    %if %index(&&&analysistype._stratification,covar&covnum.) %then %do;
                       covar&covnum. = "&&covar&covnum."
                    %end;
                %end;
             %end;
            ;                
        run;
		
        /*get all the continous variables in the dataset*/
        %do l = 1 %to %sysfunc(countw(&&&analysistype._levelid));
            %let level = %sysfunc(dequote(%scan(&&&analysistype._levelid., &l.)));
            %let category = %sysfunc(putc(&level, $strata&analysistype.fmt));

            %if %index(%lowcase(&category), agegroup) %then %do;
                %let category = %sysfunc(tranwrd(%quote(&category.), Agegroup, AgegroupNum Agegroup));
            %end; 
			
			data &dsout.&level. (keep = &dpvar. &grpvar. level %quote(&category.) %do vv = 1 %to &numcolumns; &&var&vv. %end;);
			  set &dsout. (where = (level = "&level" %if %index(%lowcase(&category.), zip3 ) %then %do; and episodes gt 0 %end;));
			run;
			
			proc sort data = &dsout.&level.;
			  by &dpvar. &grpvar. level %quote(&category.);
			run;
			
            proc sql noprint;
                create table _&dsout.&level. as
                select a.*, b.header, b.grouplabel, b.order
                from &dsout.&level. a, report_type&report_ty. b
                where strip(lowcase(a.&grpvar.)) = strip(lowcase(b.group));
            quit;
			
            proc sort data=_&dsout.&level.;
                by order %quote(&category.) ;
            run;    

            /*DP stratified - Assign masked DP*/
            %if %str("&dpvar.") = "maskedID" %then %do;
                %do d = 1 %to &num_dp.;

                    %let DPSITEID = %scan(&random_dpid_list,&d);
                    proc sql noprint;
                        select maskedid into: MaskedDPID
                        from output.maskeddpidkey
                        where dp = "&DPSITEID.";
                    quit;   

                    data _&dsout.&level._&d.;
                        set _&dsout.&level.;
                        where maskedID = "&MaskedDPID.";
                    run;    
                %end;
            %end;
        %end;
    %mend;

    /*Overall*/
    %prept1t2data(dsin=agg_dps_t&type.&analysistype._summ, dsout=agg_dps_&analysistype._summ, dpvar=, ind=agg);

    /*By DP*/
    %if ("&stratify_by_DP." = "Y") and ("&analysistype" ne "conc") %then %do;
        %prept1t2data(dsin=agg_dps_t&type.&analysistype., dsout=agg_dps_&analysistype._by, dpvar=maskedID, ind=dp);
    %end;

    /*Clean up work files*/
    proc datasets lib=work nowarn nolist noprint;
        delete /*agg_dp:*/ combine: group1: trans_:; 
    quit;

    %end; /* produce cida tables */

    %put =====> END MACRO: t1t2conc_createdata ;

%mend t1t2conc_createdata;
