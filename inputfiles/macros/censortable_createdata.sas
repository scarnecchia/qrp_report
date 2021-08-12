****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_createdata.sas  
* Created (mm/dd/yyyy): 08/10/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro aggregates censoring table data
*                                        
*  Program inputs:   
*   - agg_t1censor.sas7bdat                                                                                
*   - agg_t2censor.sas7bdat
*   - agg_t2followuptime.sas7bdat  
*   - agg_t5censor.sas7bdat  
*   
*  Program outputs:                                                                                                                                       
*   - censor_data_final.sas7bdat
*
*  PARAMETERS:
*   - tables: list of censor tables in quotes from table file                                                                   
*   - censordataset: censor dataset name on table file
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
%macro censortable_createdata (tables = , censordataset = );
  %put =====> MACRO CALLED: censortable_createdata;

 /*--------------------------------------------------------------------------------------------
 	Identify censor stratification variables                                                      
   --------------------------------------------------------------------------------------------*/
   %let censor_sort = ;
   %let censor_distribution =;
   
   data _censor_strat;
     set tablefile (where = (dataset = "&censordataset." and table in (&tables.)));
     num_strat = countw(left(strat1),' ');
     num_strat2 = countw(left(strat2),' ');
     do s = 1 to num_strat;
       stratvar = scan(strat1, s); output;
     if lowcase(tablesub) = "overall" then stratvar_overall = stratvar; output;
     end;
     do ss = 1 to num_strat2;
       stratvar = scan(strat2, ss); output;
     if lowcase(tablesub) = "overall" then stratvar_overall = stratvar; output;
     end;
     if stratvar = "censdays_value_cat" then call symputx('censor_sort','censorcat_sort');
	 if stratvar = "censdays_value" then call symputx('censor_distribution','Y');
   run;
   
   proc sql noprint;
     select distinct(stratvar)
     into: censor_strat separated by ' '
     from _censor_strat (where = (not missing(stratvar)));
   
     select distinct(compress("'"||stratvar_overall||"'"))
     into: censor_overall separated by ','
     from _censor_strat (where = (not missing(stratvar_overall)));
     
     select distinct(censorreason) into: censorreason
     from _censor_strat
   quit;
   
   %let censor_strat = &censor_strat. &censor_sort.;
   %Put censor strat vars are &censor_strat.;
   
   /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
     delete _censor_strat; 
   quit; 
 /*--------------------------------------------------------------------------------------------
 	Aggregate by censor reason and stratifications.
 	Stack aggregated with DP tables when stratification by DP is requested.                                                   
   --------------------------------------------------------------------------------------------*/  
   /* Aggregate data across all DPs */
   proc summary data = agg_&censordataset. nway missing;
   	 class runid level group &censor_strat. ;
   	 var episodes &censorreason.;
   	 output out = censor_all (drop = _:) sum=;
   run;
   
   %let censor_dp = ;
   %if &stratifybydp. = Y %then %do;
     /* Aggregate by DP */
     proc summary data = agg_&censordataset. nway missing;
      class runid dpidsiteid level group &censor_strat.;
      var episodes &censorreason.;
      output out = censor_dps (drop = _:) sum=;
     run;
	 %let censor_dp = censor_dps;
   %end;
 
   /* Stack together*/
   data censor_data;
     set censor_all (in = a)
   	     &censor_dp.;
     if a then dpidsiteid = "ALL";
   run;
 
 /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
     delete censor_all &censor_dp.; 
   quit;
    
 /*--------------------------------------------------------------------------------------------
 	Calculate summary statistics to merge back onto aggregate data                                                   
   --------------------------------------------------------------------------------------------*/
   /* Calculate summary statistics for each censoring reason.
 	 Skip over censoring reasons without counts */
 	 %let cens_num = %sysfunc(countw(&censorreason., %str( )));
 
 	 %do sl = 1 %to %sysfunc(countw(episodes &censorreason., %str( )));
 		%let cen_stat = %scan(episodes &censorreason.,&sl.);
 		
 		proc sql noprint;
 		  select sum(&cen_stat.) into: checksum
 		  from censor_data;
 		quit;
 		
 		%if &checksum = 0 %then %do;
 			 %put WARNING: (Sentinel) Variable &cen_stat. has no episodes. This variable will not be used to generate summary statistics;
 		%end;
 		%else %do;	   
            %if "&censor_distribution" = "Y" %then %do;
 			    proc means data= censor_data nway missing noprint classdata=censor_data;
 			    	var censdays_value;
 			    	class runid dpidsiteid group level ;
 			    	freq &cen_stat.;
 			    	where not missing(censdays_value);
 			    	output out=_stats_&cen_stat. (drop=_type_ _freq_)     
 			    								mean = Mean 
 			    								std = std
 			    								min = min
 			    								q1 = q1
 			    								median = median 
 			    								q3 = q3
 			    								max = max;
 			    run;
 		
 		   	/* Create indicator variable to show which statistics are associated with which censor reason */ 
 		   	data _stats_&cen_stat.;
 		   	  length table_name $32;
 		   	  set _stats_&cen_stat.;
 		   	  %if &cen_stat. = episodes %then %do;
 		   	    table_name = "Overall";
 		   	  %end;
 		   	  %else %do;
 		   	    table_name = "&cen_stat.";
 		   	  %end;
 		   	run;
 		   %end;
 		   %else %do;
 		   	  /* Create a blank table if distribution isn't specified */
 		   	  proc sql noprint;
 		   	  	 create table unique_groups as
 		   	  	 select distinct level, dpidsiteid, group, runid
 		   	  	 from censor_data;
 		   	  quit;
 			  
 		   	  data _stats_;
 		   	  	set unique_groups;
 		   	  	length table_name $32 min q1 median q3 max mean std 8;
 		   	  	call missing(min, q1, median, q3, max, mean, std);
 		   	  	table_name = "Overall";
 		   	  	output;
 			  
 		   	  	%do cn= 1 %to &cens_num;
 		   	  	   %let var = %scan(&censorreason, &cn);
 		   	  	   table_name = "&var.";
 		   	  	   output;
 		   	  	%end;
 		   	  run; 
 		   %end; /* censor distribution */
 		%end; /* cen_stat episodes */
 	 %end; /* censor reasons */
 	 
   /* Stack all datasets together. There are many repeat observations, recnum will be used to create one set per group */
 	 data _statsdups;
 	   set _stats_:;
 	   recnum=_n_;
      run; 
 
   /* This step produces unique rows per DP, group and table. This avoids dropping any required missing rows */
     proc sql noprint;
 	   create table _stats as
 	   select * 
 	   from _statsdups
 	   group by runid, dpidsiteid, group, table_name
 	   having recnum=max(recnum);
 	 quit;
 	
   /* Clean up work files */
      proc datasets lib=work nowarn nolist noprint;
        delete _stats_: _statsdups unique_groups; 
      quit;	
  	
   /* Calculate denominators and percentage totals, joining summary stats back to aggregate data */
  	 proc sql noprint;
  	   create table censor_data_den as
  	   select distinct a.*, 
  	   	 (episodes/epi_tot)   as epi_tot_pct       format=percent10.1,
  	   	 %do cn= 1 %to &cens_num;
  	   	   %let var = %scan(&censorreason, &cn);
  	   	   (&var/epi_tot)     as &var._pct         format=percent10.1,
  	   	   (&var/&var._tot)   as &var._reason_pct  format=percent10.1
  	   	   %if &cn ^= &cens_num %then %do; , %end;
  	   	 %end;
  	   from (select distinct a.*, 
  	   		sum(episodes) as epi_tot,
  	   		%do cn = 1 %to &cens_num;
  	   		  %let var = %scan(&censorreason, &cn);
  	   		  sum(&var) as &var._tot
  	   		  %if &cn ^= &cens_num %then %do; , %end;
  	   		%end;
  	   	    from censor_data %if "&censor_distribution" = "Y" %then %do; (drop=censdays_value) %end; a
  	   	    /* counts need to be grouped by user specified stratas */
  	   	    group by a.runid, a.dpidsiteid, a.group, a.level) as a;
 	 
  	   create table censor_data_stats as
  	   select distinct a.*, 
  	 		 b.table_name,
  	 		 b.min, 
  	 		 b.q1, 
  	 		 b.median, 
  	 		 b.q3,
  	 		 b.max,
  	 		 b.mean,
  	 		 b.std
  	   from censor_data_den a left join _stats b
  	   on a.runid = b.runid and a.dpidsiteid = b.dpidsiteid and a.group = b.group ;
  	   
  	   create table &censordataset. as
  	   select distinct a.*, 
  	         %if &labelfileexists. = Y %then %do;
  	   		   case when not missing(b.label) then b.label 
               else a.group end as grouplabel
  	 		 %end;
  	 		 %else %do;
  	 		   a.group as grouplabel
  	 		 %end;
  	   from censor_data_stats a 
  	   %if &labelfileexists. = Y %then %do;
  	     inner join labelfile(where=(labeltype='grouplabel')) b
  	     on a.group = b.group
  	   %end;
  	   %if %str("&censor_sort") ne %str("") %then %do; where not missing(censdays_value_cat) %end;
  	   order by runid, dpidsiteid, grouplabel %if %str("&censor_sort") ne %str("") %then %do; ,censorcat_sort, censdays_value_cat %end; , table_name;
  	 quit;
 
   /* For proc report, need to acquire censoring reason episodes in the "Episode" column as well as calculate denominators within each bin */
   	 data &censordataset.;
   	   set &censordataset.;
   	   %do cn = 1 %to &cens_num;
   	     %let var = %scan(&censorreason, &cn);
   	     if table_name = "&var" then do;
   	     	episodes = &var;
   	    	epi_tot  = &var._tot;
   	    	epi_tot_pct = &var._reason_pct;
   	    	&var = &var._tot;
   	     end;
   	     if missing(&var._pct) then &var._pct = 0;
   	     if missing(epi_tot_pct) then epi_tot_pct = 0;
   	     drop &var._reason: &var._tot: ;
   	   %end;
   	   format epi_tot_pct percent10.1;
   	 run;
   
   	 %if "&censor_distribution" = "Y" and %str("&censor_sort") = %str("") %then %do;
   	    proc sort data = &censordataset. nodupkey;
   		  by _all_;
   	    run;
   	 %end;
   
   /* Final formatting */
   	 data &censordataset.;
   	   set &censordataset.;
   	   length strat $8;
   	   if level in (&censor_overall.) then strat = 'overall';
   	   %if %str("&censor_sort") ne %str("") %then %do;
   	     if missing(censdays_value_cat) = 0 then do;
   	       dash = index(censdays_value_cat, '-');
   	       format censdays_value_cat_format $20. pre post comma12.0;
   	       if dash >1 then do;
   	         pre = input(substr(censdays_value_cat,1,dash-1), best.);
   	         post = input(substr(censdays_value_cat,dash+1), best.);
   	         censdays_value_cat_format = cat(strip(put(pre,comma12.0)), '-',strip(put(post,comma12.0)), ' days');
   	         drop post;
   	       end;
   	       else do;
   	         plus = index(censdays_value_cat, '+');
   	         pre = input(substr(censdays_value_cat,1,plus-1), best.);
   	         censdays_value_cat_format = cats(put(pre,comma12.0), '+ days');
   	       end;
   	       drop dash pre;
   	     end;
   	   %end;
   	   %if "&censor_distribution" = "Y" %then %do;
   	     /*Dummy variable to use as 'across' variable to correctly place header*/
   	     dummy = .;
   	   %end;
   	 run;
   
   	 proc sort data=&censordataset.;
   	    by dpidsiteid &censor_sort.;
   	 run;
 
   /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
      delete _stats censor_data_stats; 
   quit;

   %put =====> END MACRO: censortable_createdata;
%mend censortable_createdata;