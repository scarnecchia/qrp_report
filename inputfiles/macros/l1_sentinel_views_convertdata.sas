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

	%do i = 1 %to %sysfunc(countw(&repdatadsn,@));
	    %let dsn = %scan(&repdatadsn,&i,@);
		%let table = %sysfunc(tranwrd(&dsn,repdata.,%str()));
	    %do dpcnt = 0 %to &num_dp;
	        %let dsid=%sysfunc(open(&dsn));
	        %let check_table1=%sysfunc(varnum(&dsid,exp_mean&dpcnt));
			%let check_cidatable=%sysfunc(varnum(&dsid,column1));
			%let check_attrtable=%sysfunc(varnum(&dsid,report_descr)); 
	        %let rc=%sysfunc(close(&dsid));

			/******************************************************************/
			/* Table 1: Set in all tables					
						Drop rows with missing metvar values
						Keep necessary variables
						Rename variables
					    All other processing done later	
			/******************************************************************/
	        %if &check_table1 > 0 %then %do;
	            data _table1_&dpcnt._&i.;
	            set &dsn;
	            /* TODO */    
	            run;
			%end; /* Table1 */		
		%end; /* DP loop */


		/******************************************************************/
		/* Results Table : Set in all tables											
				    	   All other processing done later		
		/******************************************************************/
		%if &check_cidatable > 0 %then %do;
			data _cidatable_&i.;
			set &dsn;
			/* TODO */
			run;
		%end;


		/******************************************************************/
		/* Attrition Table : Set report table and keep necessary variables	
							 Extract monitoring period	
				    		 All other processing done later		
		/******************************************************************/
		%if &check_attrtable > 0 %then %do;
			proc sql noprint;
			select periodid into :periodid trimmed 
			from tableofcontents_views(where=(upcase(table)=upcase("&table")));
			quit;

			proc sql noprint undo_policy=none;
			create table _attrition_&i. as
			select a.group
				  ,a.report_descr
				  ,a.level
				  ,a.agg_remaining
				  ,a.agg_excluded
				  ,b.periodid2 as monitoringperiod length=3 format 3. 
	        from &dsn(keep=runid group report_descr level agg_remaining agg_excluded) as a
			left join Monitoringfile_views(where=(periodid=&periodid.)) as b
			on a.runid=b.runid
			order by monitoringperiod, group, level;                
	        quit;
	    %end; /* Attrition */
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





	/********************************************************/
	/* Attrition Table
	/********************************************************/

	/* TODO: Finalize formatting */
	data views.attrition;
	set _attrition:;
	run;


	/********************************************************/
	/* Table1
	/********************************************************/

	/* TODO: Wait for code refactoring and aggregation before finalizing */

	/*
	data views.table1;
	set _table1_:;
	run;
	*/


	/********************************************************/
	/* Results Table
	/********************************************************/

	/* TODO: Wait for code refactoring and aggregation before finalizing */

	/*
	data views.results;
	set _cidatable_:
	run;
	*/




	/********************************************************/
	/* ResultsColumns Table
	/********************************************************/








	/* Clean-up */
	proc datasets library=work nolist nowarn;
    	delete _table1_: _cidatable_ _attrition:;
	quit;
		
%mend l1_sentinel_views_convertdata;
