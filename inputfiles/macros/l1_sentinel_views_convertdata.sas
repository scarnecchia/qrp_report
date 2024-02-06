****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l1_sentinel_views_convertdata.sas
* Created (mm/dd/yyyy): 08/12/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Transform qrp_report Types 1 and 2 MSOCDATA folder datasets for use in the Sentinel Views
*          KPI Studio Platform.
*
*  Program inputs: 
    Input files:
*   - work.userstrata.sas7bdat
*	- input.[baselinefile]
*   MSOCDATA datasets
*	- msocdata.agg_baseline_[PeriodID]
*	- msocdata.agg_[ReportType]cida   
*	- msocdata.agg_t2followuptime 
*
*  Program outputs:  
*	- agg_[ReportType]_baseline
*	- agg_[ReportType]_cida
*	- agg_t2_followuptime
*
*  PARAMETERS: 
*	requestID: 5 Token Request ID, defined in %create_report as &viewsID
*   jirakey: Jira tag number associated with query
*   userid: Users e-mail address
*   studytitle: Title of query
*
*  Programming Notes: 
*   - This macro calls %baseline_expand_parameters macro 
*   - summary and followup tables must be requested in the TABLEFILE in order to be available for
*     inclusion in KPI studio
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO:
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l1_sentinel_views_convertdata(requestID=,jirakey=,userid=,studytitle=);

	proc datasets library=views kill nowarn nolist; run; quit;

	/* Loop through list of tables in REPDATA library */
	proc sql noprint;
	select catx('.','repdata',memname) 
	into :repdatadsn separated by '@'
	from dictionary.tables 
	where libname = 'REPDATA' and prxmatch('/^table\d|^figure\d/i',memname);
	quit;

	%let table1exists=0;
	%let resultstableexists=0;

	%do i = 1 %to %sysfunc(countw(&repdatadsn,@));
	    %let dsn = %scan(&repdatadsn,&i,@);
		%let table = %sysfunc(tranwrd(&dsn,repdata.,%str()));
		%let dsid=%sysfunc(open(&dsn));
        %let check_table1=%sysfunc(varnum(&dsid,metvar));
		%let check_cidatable=%sysfunc(varnum(&dsid,column1));
		%let check_attrtable=%sysfunc(varnum(&dsid,report_descr));         
		%let check_dpidsiteid=%sysfunc(varnum(&dsid,dpidsiteid)); 
 
		/******************************************************************/
		/* Table 1: Set in all tables					
					Drop rows with missing metvar values
					Extract monitoring period
					Keep necessary variables
					Rename variables
				    All other processing done later	
		/******************************************************************/
		%if &check_table1 > 0 %then %do;	
			%let table1exists=1;	

		    %do dpcnt = 0 %to &num_dp;		        		
				%let check_table1_dp=%sysfunc(varnum(&dsid,exp_mean&dpcnt));	
				%if &check_table1_dp > 0 %then %do;	
					proc sql noprint;
					select periodid2 into :periodid2 trimmed 
					from tableofcontents_views(where=(upcase(table)=upcase("&table"))) as a
					join monitoringfile_views as b
					on a.runid=b.runid and a.periodid=b.periodid;

					select distinct quote(strip(group))
					into :views_groups separated by ' '
					from input.&groupsfile;
					quit;

		            data _table1_&dpcnt._&i.;
	                set &dsn;
	                length dp $10 monitoringperiod 3; 
					format monitoringperiod 3.; 
	                if missing(metvar) then delete;              
	                if &dpcnt. = 0 then dp = "Aggregate";
	                else if &dpcnt ^= 0 and &dpcnt < 10 then dp ="DP0&dpcnt";
	                else if &dpcnt >= 10 then dp = "DP&dpcnt.";
					monitoringperiod=&periodid2;
	                rename sortorder1=headerorder
						   exp_mean&dpcnt._char=exp_mean_char 
						   exp_std&dpcnt._char=exp_std_char
						   analysisgrp=cohortgrp; 				
					where analysisgrp in (&views_groups);	   
	                keep metvar	label sortorder: grouper analysisgrp vartype exp_mean&dpcnt._char exp_std&dpcnt._char dp monitoringperiod;
		            run;		
				%end;
			%end;  /* DP loop */	
		%end; /* Table1 */


		/******************************************************************/
		/* Results Table : Set in all tables											
				    	   Compute and format all variables	
		/******************************************************************/
		%if &check_cidatable > 0 %then %do;
			%let resultstableexists=1;

			/* Get number of selected stat columns, level (unique in &dsn) and stratification variables */
			proc sql noprint;
				select count(*) into :numcolumns trimmed from tablecolumns 
				where table= %if &reporttype. eq T1 %then %do; "t1cida" %end; %else %do; "t2cida" %end;;

				select distinct level into :level from &dsn;
				select lowcase(tablesub) into :strats from tablefile where levelid1="&level";
			quit;

			/* Compute stratorder and stratcatorder and drop unnecessary variables */
			data _cidatable_&i. (rename=group=cohortgrp);
			length stratcatorder 3.;
			set &dsn;
			by order;
			if first.order then stratcatorder=1;
			else stratcatorder=stratcatorder+1;
			retain stratcatorder;
			drop order header grouplabel sortorder: %do col=1 %to &numcolumns; column&col. %end;;
			run;

			proc sql noprint undo_policy=none;
				create table _cidatable_&i. as
				select a.*
				      ,b.stratificationorder as stratorder length=3
				from _cidatable_&i. as a
				left join tablefile as b 
				on a.level = b.levelid1;
			quit;

			/* Get monitoringperiod */
			proc sql noprint undo_policy=none;
			create table _cidatable_&i. as
			select a.*,
				   c.periodid2 as monitoringperiod length=3 format 3.
			from _cidatable_&i. as a 
			left join groupsfile as b
			on a.cohortgrp=b.group
			join Monitoringfile_views(where=(periodid=&look_end.)) as c
			on b.runid=c.runid;
			quit;

			/* Get stratification values (raw and formatted) if stratification is not overall */
			%if &strats. ne overall %then %do;
				proc sort nodupkey data=%if &reporttype=T1 %then %do; msocdata.agg_t1_cida %end;
										%else %do; msocdata.agg_t2_cida %end; (where=(level="&level.") keep=level &strats.) out=_stratcat;
				by &strats.;
				run;

				data _stratcat;
				set _stratcat;
				%do z = 1 %to %sysfunc(countw(&strats));
					%let strat = %scan(&strats,&z);		   
					%if &strat eq year or &strat eq zip3 or &strat eq state %then %do;
						&strat.fmt = &strat;
					%end;
					%else %if %index(&strat, covar)> 0 %then %do;
						format &strat.fmt $50.;
						if &strat. = 0 then &strat.fmt="No evidence of &&&Study&strat.";
						else &strat.fmt="Evidence of &&&Study&strat.";
					%end;
					/* For month and quarter, using the &strat. macro variable when assigning format generates a w.a.r.n.i.n.g in the log */
					%else %if &strat. eq month %then %do;												
						length monthfmt $10;
						monthfmt = put(month, monthfmt.);	
					%end;
					%else %if &strat. eq quarter %then %do;												
						length quarterfmt $10;
						quarterfmt = put(quarter, quarterfmt.);	
					%end;
					%else %do;
						&strat.fmt = put(&strat., $&strat.fmt.);
					%end;
				%end;
				run;

				proc sql noprint undo_policy=none;
					create table _cidatable_&i. as
					select a.*
						   %do z = 1 %to %sysfunc(countw(&strats));
						   	 	%let strat = %scan(&strats,&z);	  
						   ,b.&strat. as &strat.raw
						   %end;	
					from _cidatable_&i. as a
					left join _stratcat as b
					on %do z = 1 %to %sysfunc(countw(&strats));
					   		%let strat = %scan(&strats,&z);	  
						   a.&strat=b.&strat.fmt %if &z. < %sysfunc(countw(&strats)) %then %do; and %end;
					   %end;;
				quit;

				proc contents data=&dsn. noprint out=_content(keep=name label);
				quit;

				/* Get covariate label if necessary */
				%if %index(&strats., covar) > 0 %then %do;
					proc sql noprint undo_policy=none;
					create table _content as
					select name, 
						   case when b.studyname is not null then b.studyname
						   	    else a.label
						   end as label
					from _content as a
					left join (select distinct studyname, cov_varname from covarname) as b
					on lowcase(a.name) = lowcase(b.cov_varname);
					quit;
				%end;
				
				/* Compute stratlabel */
				data _content(where=(order>0));
				set _content;
				%do z = 1 %to %sysfunc(countw(&strats));
			   		%let strat = %scan(&strats,&z);	  
				    if lowcase(name) = lowcase("&strat.") then order=&z.;		
			    %end;
				run;

				%create_comma_charlist(inlist=&strats., outlist=strats_quoted);

				proc sql noprint;
				select label into :stratlabel separated by "/" 
				from _content
				where upcase(name) in (&strats_quoted.)
				order by order;
				quit;
				
			%end; /* Stratification is not overall */	 	

			/* Finalize variables computation and formatting; */
			data _cidatable_&i.;
			length %do col=1 %to &numcolumns; column&col._char %end; $50;
			retain monitoringperiod cohortgrp dp strat stratcat stratlabel stratcatlabel 
				   stratdashboardlabel stratorder stratcatorder %do col=1 %to &numcolumns; column&col._char %end;;
			set _cidatable_&i.;
			keep monitoringperiod cohortgrp dp strat stratcat stratlabel stratcatlabel 
				 stratdashboardlabel stratorder stratcatorder %do col=1 %to &numcolumns; column&col._char %end;;			
			format dp $10. strat stratcat $50. stratlabel stratcatlabel $500. stratdashboardlabel $1000. %do col=1 %to &numcolumns; column&col._char %end; $50.;
			
			%if &check_dpidsiteid > 0 %then %do; 
				dp=dpidsiteid;
			%end;
			%else %do;
				dp="Aggregate";
			%end;

			strat="&strats";
			%if &strats. eq overall %then %do;
				stratcat="overall";
				stratlabel="Overall Analysis";
				stratcatlabel="Overall Analysis";
				stratdashboardlabel="Overall Analysis";
			%end;
			%else %do;
				stratlabel="&stratlabel.";	
				stratcat="";
				stratcatlabel="";
				%do z = 1 %to %sysfunc(countw(&strats));
			   		%let strat = %scan(&strats,&z);	  

					/* Additional processing for covariates */	
					%if %index(&strat., covar) > 0 %then %do;
						if index(&strat., "No evidence of ") > 0 then do;							
							&strat.="No";
						end;
						else do;							
							&strat.="Yes";
						end;						
					%end;

				    stratcat = strip(stratcat) %if &z. > 1 %then %do; || " "  %end; || strip(&strat.raw);		
					stratcatlabel = strip(stratcatlabel) %if &z. > 1 %then %do; || "/"  %end; || strip(&strat.);
			    %end;	
								
				stratdashboardlabel = strip(stratlabel) || ": " || strip(stratcatlabel);
			%end;

			/* Replace missing indicator values with blanks */
			%do col=1 %to &numcolumns;
				if upcase(column&col._char) in(".", "N/A", "NAN") then column&col._char="";
			%end;
			run;
		%end; /* Result table */


		/******************************************************************/
		/* Attrition Table : Set report table and keep necessary variables	
							 Extract monitoring period	
							 Apply formatting
				    		 Final stacking done later		
		/******************************************************************/
		%if &check_attrtable > 0 %then %do;
			proc sql noprint;
			select periodid into :periodid trimmed 
			from tableofcontents_views(where=(upcase(table)=upcase("&table")));

			select distinct quote(strip(group))
			into :views_groups separated by ' '
			from input.&groupsfile;
			quit;

			proc sql noprint undo_policy=none;
			create table _attrition_&i. as
			select a.group as cohortgrp length=40
				  ,a.report_descr as descr length=500
				  ,a.level length=8
				  ,a.agg_remaining as remaining length=8
				  ,a.agg_excluded as excluded length=8
				  ,b.periodid2 as monitoringperiod length=3 format 3. 
	        from &dsn(keep=runid group report_descr level agg_remaining agg_excluded) as a
			left join Monitoringfile_views(where=(periodid=&periodid.)) as b
			on a.runid=b.runid
			where group in (&views_groups)
			order by monitoringperiod, group, level;                
	        quit;
	    %end; /* Attrition */

		%let rc=%sysfunc(close(&dsid));
	%end; /* repdata tables loop */


	/********************************************************/
	/* Study table
	/********************************************************/
    data views.study;
        length queryid $40 querytype $10 jirakey $40 studytitle $1000 userid $500;
        queryid="&requestid";
        querytype="%upcase(&reporttype)";
        %if %length(&jirakey) = 0 %then %do;
            jirakey="QF-0000";
        %end;
        %else %do;
            jirakey="&jirakey";
        %end;
        %if %length(&userid) = 0 %then %do;
            userid="qf@sentinelsystem.org";
        %end;
        %else %do;
            userid="&userid";
        %end;
        %if %length(&studytitle) = 0 %then %do;
            studytitle="ADD STUDY TITLE";
        %end;
        %else %do;
            studytitle="&studytitle";
        %end;
            output;
    run;

	/********************************************************/
	/* Monitoring Table
	/********************************************************/
    /* Re-assign values for dates in monitoring file */
    proc sql noprint;
        select max(input(dpmaxdate,date9.)) into: maxdpenddate
        from output.dpinfo;
    quit;

    data views.monitoringperiod(keep=monitoringperiod startdate enddate);
        retain periodid2 startdate enddate;
        set monitoringfile_views;
        enddate=coalesce(fupenddate,indenddate, &maxdpenddate.);        
        rename periodid2=monitoringperiod;
        format enddate date9. periodid2 3.;
        length periodid2 3 startdate enddate 4;
    run;




	/********************************************************/
	/* CohortGroup Table
	/********************************************************/
    proc sql;
    create table cohortgroup as
    select distinct 
      a.group as cohortgrp length 40,
	  c.label as cohortgrptitle length 500,
	  b.label as outcomelabel,
      %if %sysfunc(prxmatch(m/T2L1/i,&reporttype)) %then %do;
        'ADD OUTCOME LABEL' as outcome length 500,
      %end;
      %else %do;	   
	    'N/A' as outcome length 500,
      %end;
	  a.order as sortingorder,
	  ' ' as design length 500
	from groupsfile as a
	     left join labelfile (where =(labeltype = "outcomelabel")) as b
		on a.group = b.group
		 left join labelfile (where = (labeltype = "grouplabel")) as c
	    on a.group = c.group;
	quit;
   
    data views.cohortgroup;
      set cohortgroup; 
	    %if %sysfunc(prxmatch(m/T2L1/i,&reporttype)) %then %do;
	      if outcomelabel ne '' then outcome = outcomelabel;
		  drop outcomelabel;
	    %end;
	    if cohortgrptitle = '' then cohortgrptitle = cohortgrp;
		drop outcomelabel;
    run;




	/********************************************************/
	/* Attrition Table
	/********************************************************/
	data views.attrition;
	set _attrition_:;
	run;


	/********************************************************/
	/* Table1
	/********************************************************/
	%if &table1exists > 0 %then %do;	
		%let riskscore_regex=;
		%let riskscorelist=;
		%let lab_cov_list=;
		%if %sysfunc(exist(riskscorefile)) %then %do;
			proc sql noprint;	
	            select distinct cats(riskscore,'_CAT'), riskscore
	            into :riskscore_regex separated by '|', :riskscorelist separated by '|'
	            from riskscorefile;
			quit;	
		%end;	

		%isdata(dataset=covarnameviews);
		%if &nobs > 0 %then %do;
			proc sql noprint;
				select distinct catx('|',studyname,cov_varname)
				into :lab_cov_list separated by '@'
				from covarnameviews;
			quit;
		%end;

		data views.table1;
		%if %length(&riskscorelist) > 0 or %length(&riskscore_regex) > 0 %then %do;
		retain riskscore_label;
		%end;
		length monitoringperiod 3 cohortgrp $40 dp $10 grouper $60 headerlabel $500 variablelabel $1000
		       metvar $32 vartype exp_mean_char exp_std_char $30;   
		set _table1_:;
		if upcase(metvar)='AGE' then do;
			headerlabel='Mean Age';
			variablelabel='';
		end;

		if prxmatch('/AGE\d/i',metvar) then do;
			headerlabel='Age';
			variablelabel=label;
		end;

		if prxmatch('/SEX_/i',metvar) then do;
			headerlabel='Sex';
			variablelabel=label;
		end;
		if prxmatch('/YEAR_\d/i',metvar) then do;
			headerlabel='Year';
			variablelabel=label;
		end;
		if prxmatch('/RACE_/i',metvar) then do;
			headerlabel='Race';
			variablelabel=label;
		end;
		if prxmatch('/HISPANIC_/i',metvar) then do;
			headerlabel='Hispanic';
			variablelabel=label;
		end;

		%if %length(&riskscorelist) > 0 or %length(&riskscore_regex) > 0 %then %do;
		if prxmatch("/&riskscorelist/i",metvar) and vartype="continuous" then do;
  			headerlabel=strip(label) || " (continuous)";
  			riskscore_label=label;			
  			if metvar = "CHA2DS2VASC" then headerlabel="CHA2DS2-VASc score (continuous)";
  		end;
  		if prxmatch("/&riskscore_regex/i",metvar) and vartype="dichotomous" then do;
			headerlabel=strip(riskscore_label) || " (categorical)";
			variablelabel=label;
			if prxmatch('/CHA2DS2VASC_CAT/i',metvar) then headerlabel="CHA2DS2-VASc score (categorical)";
		end;
		%end;

		if prxmatch("/COVAR\d/i",metvar) then do;
			headerlabel=label;
			variablelabel='';
		end;		

		if prxmatch("/NUM/i",metvar) then do;
			headerlabel=label;
			variablelabel='';
		end;	

		/*Lab covariates */
		%if %length(&lab_cov_list) > 0 %then %do;
		if grouper = "Laboratory Characteristics" then do;
			%do z = 1 %to %sysfunc(countw(&lab_cov_list,%str(@)));
				%let cov_pairing = %scan(&lab_cov_list,&z,%str(@));
				%let cov_header = %scan(&cov_pairing,1,%str(|));
				%let lab_covar_match = %scan(&cov_pairing,-1,%str(|));
				if prxmatch("/&lab_covar_match/i",metvar) then headerlabel="&cov_header";
			%end;
			variablelabel=label;	
		end;
		%end;

  		if indexw(variablelabel,"(*ESC*){unicode '2265'x}") then variablelabel=tranwrd(variablelabel,"(*ESC*){unicode '2265'x}",">=");
		if exp_mean_char in ('.','N/A','NaN') then exp_mean_char = '';
		if exp_std_char in ('.','N/A','NaN') then exp_std_char = '';
		keep monitoringperiod cohortgrp dp grouper headerlabel variablelabel metvar vartype exp_mean_char exp_std_char;   
		run;

		/* create ordering variables */
		data views.table1;
			length monitoringperiod 3 cohortgrp $40 dp $10 grouper $60 headerlabel $500 variablelabel $1000
		       grouperorder headerorder variableorder 3 metvar $32 vartype exp_mean_char exp_std_char $30;   
			set views.table1;  
			by monitoringperiod cohortgrp dp grouper headerlabel variablelabel notsorted;
			if first.monitoringperiod or first.cohortgrp or first.dp then do;
				grouperorder=0;
				headerorder=0;
				variableorder=0;
			end;
			if first.grouper then grouperorder+1;
			if first.headerlabel then do;
				headerorder+1;
				variableorder=0;
			end;
			if first.variablelabel then variableorder+1;
		run;

	%end; /* Table1 exists */


	/********************************************************/
	/* Results Table
	/********************************************************/
	%if &resultstableexists > 0 %then %do;			
	    data views.results;
		retain monitoringperiod cohortgrp dp strat stratcat stratlabel stratcatlabel 
			   stratdashboardlabel stratorder stratcatorder %do col=1 %to &numcolumns; column&col._char %end;;
		set _cidatable_:;
		run;

		proc sort data=views.results;
		by monitoringperiod cohortgrp dp stratorder stratcatorder;
		run;
	%end; /* Results table exists */


	/********************************************************/
	/* ResultsColumns Table
	/********************************************************/
	
	%isdata(dataset=views.results);
	%if %eval(&nobs.>0) %then %do;
		proc sql;
		  create table views.resultscolumns as
		   select column as columnkey length 25,
		   order,
		   columnlabel as columnheader length 500,
		   (case when CIrate = 'N' and 
					   find(columnFormat, "comma", "i")  then 'Y'
				 else 'N' end) as Histogram length 10,
		   (case when find(columnformat, "n.", "i") then "INT"
				 when find(columnformat, "comma", "i") then 
					tranwrd(cats('DECIMAL',"(", substr(columnformat, find(columnformat, '.') -2), ")"), '.', ',')
				 else'NVARCHAR(250)' end) as format length 20
		   from tablecolumns;
		 quit;
	%end;


	/* Clean-up */
	proc datasets library=work nolist nowarn;
    	delete _table1_: _cidatable_: _attrition: _content _stratcat;
	quit;
		
%mend l1_sentinel_views_convertdata;
