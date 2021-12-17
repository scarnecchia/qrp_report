****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t4tables_createdata.sas  
* Created (mm/dd/yyyy): 08/06/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro produces tables for a Type 4 report
*                                        
*  Program inputs:                                                                                   
*   - agg_t4preg.sas7bdat   
*   - agg_t4nopreg.sas7bdat 
*
*  Program outputs:                                                                                                                           
*   - 1 dataset per table in the format [TableID]_[Tablesubstrat]
* 
*  PARAMETERS: 
*   - dataset: aggregate dataset from %aggregate_report_tables
*   - whereclause: where clause to restrict input dataset
*   - catvar: variable that will be categorized
*   - countvar: metric counting counts
*   - cattableid: category table ID from TABLEFILE
*   - createfootnote: Y/N indicator to create group-specific footnote table (for dose tables)
* 
*  Programming Notes:                                                                                 

*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro t4tables_createdata(datasets=);

    %put =====> MACRO CALLED: t4tables_createdata ;
	
    /************************************************************************************************
      Determine levels            
     ************************************************************************************************/	
	 /* Confirm a table columns file has been specified */
	 %if %str("&tablecolumnsfile.") = %str("") %then %do;
	   %put ERROR: (Sentinel) Lookup table includes dataset &tdatasetlist., but tablecolumnsfile is not specified in &createreportfile. file.;
	   %abort;
	 %end;
	  
	  proc sql noprint;
         select distinct quote(levelid1), quote(levelid2) 
         into :levellist1,
              :levellist2
         from tablefile
         where table in (&tableid.) and tablesubstrat in (&tablesubstrat.);
	  quit;
	  
	/************************************************************************************************
     Set preg and nopreg data together when requested for desired levels            
     ************************************************************************************************/
	 %let numdatasets = %sysfunc(countw(&datasets,' '));
	 data agg_t4moi;
	   set %if %index(&datasetlist.,t4preg) > 0 %then %do;
	         agg_t4preg (in = t4preg where = (level in (&levellist1., &levelist2.)))
		   %end;
		   %if %index(&datasetlist.,t4nopreg) > 0 %then %do;
		     agg_t4nopreg (in = t4nopreg where = (level in (&levellist1., &levelist2.)))
		   %end;;
	   if t4preg then preflg = "Y";
	   else pregflg = "N";
	 run;
	
	/************************************************************************************************
      Determine total count of variables on table and put tablecolumns information into macro variables             
    ************************************************************************************************/
	proc sql noprint;
	  select count(column) into: numcolumns trimmed
	  from tablecolumns;
		
	  select columnname 
	        ,column 
			,columnlabel
			,columnformat
			,scan(compress(column,'()'),1,'/') as numerator
			,scan(compress(scan(column,1,'*'),'()'),2,'/') as denominator
	   into: var1 -:var&numcolumns.
		    ,:formula1 - :formula&numcolumns.
			,:label1 - :label&numcolumns.
			,:format1 - :format&numcolumns.
			,:num1 - :num&numcolumns.
			,:denominator1 - :denominator&numcolumns.
	  from tablecolumns;
	  
	  select column into: sumcolumns separated by " "
	  from tablecolumns where index(column,"/") = 0;
    quit;
	
	/* DETERMINE IF NEXT STEPS ARE DONE BY DP OR WITHOUT
   /************************************************************************************************
     Summarize Data     
    ************************************************************************************************/	
	proc summary data = agg_t4moi nway missing;
	  class group level moiname;
	  var &sumcolumns. npts episodes episodes_3trim;
	run;
	  
	/************************************************************************************************
      If T1 requested determine denominators for percent calculations           
    ************************************************************************************************/
	%if %sysfunc(index(&tablelist.,T1)) > 0 %then %do;
	   proc sql noprint undo_policy=none;
	      create table agg_t4moi as 
              select a.*
			        ,b.episodes as den_episodes
					,b.episodes_3trim as den_episodes_3trim
              from agg_t4moi (where=(level="&levellist1")) as a,
                   agg_t4moi (where=(level="&levellist2"))as b
              where a.group=b.group and a.pregflg=b.pregflg 
			      %if &stratifybydp. = Y %then %do;
				    and a.dpidsiteid = b.dpidsiteid
				  %end;;
       quit;
	%end;  
	
   /************************************************************************************************
     Identify columns requested and apply labels and formats          
    ************************************************************************************************/
    %macro prep_t4tables (dsin =, dsout =, dpvar = );	
	   data &dsin.;
	     set &dsin.;
	
	%mend;
	/*Overall*/
    %prep_t4tables (dsin=agg_t4moi_summ, dsout=final_t4moi);
	
	%if &stratifybydp. = Y %then %do;
	  %prept1t2data(dsin=%str(agg_t4moi, dsout=final_dps_t4moi, dpvar=dpidsiteid);
	%end;

    %put =====> END MACRO: t4tables_createdata ;

%mend t4tables_createdata;
