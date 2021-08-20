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
*   - t1censor.sas7bdat                                                                                
*   - t2censor.sas7bdat
*   - t2followuptime.sas7bdat  
*   - t5censor.sas7bdat 
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
   %let censor_distribution =;
   %let censorreason = ;  
   %let censorreason_t3 = ;     
   %let censdays_value_level =;
   %let censor_strat = ;
   %let censor_overall_level = ;
  
    data _null_;
     set tablefile (where = (dataset = "&censordataset." and table in (&tables.)));
     if not missing(levelid2) then do;
       call symputx('censor_distribution','Y');
     end;
    run;		
   
	proc sql noprint;
		select "'"||strip(levelid12)||"'" into: censdays_value_level separated by ','
		from (select distinct levelid1 as levelid12
			  from tablefile (where = (dataset = "&censordataset." and table in (&tables.)))
			  union corr all
			  select distinct levelid2 as levelid12
			  from tablefile (where = (dataset = "&censordataset." and table in (&tables.)))
			  where levelid2 ne '');

		select strip(strat12) into: censor_strat separated by ' '
		from (select distinct strat1 as strat12
			  from tablefile (where = (dataset = "&censordataset." and table in (&tables.)))
			  union corr all
			  select distinct strat2 as strat12
			  from tablefile (where = (dataset = "&censordataset." and table in (&tables.)))
			  where levelid2 ne '');
			  
		select "'"||strip(levelid12)||"'" into: censor_overall_level separated by ','
		from (select distinct levelid1 as levelid12
			  from tablefile (where = (dataset = "&censordataset." and table in (&tables.)))
			  where lowcase(tablesub)='overall'
			  union corr all
			  select distinct levelid2 as levelid12
			  from tablefile (where = (dataset = "&censordataset." and table in (&tables.)))
			  where lowcase(tablesub)='overall' and levelid2 ne '');
			  
		%if %index(&tables.,T3) > 0 %then %do;
			select distinct(censorreason) into: censorreason_t3
			from tablefile (where = (dataset = "&censordataset." and table in (&tables.)));
		%end;
	quit;
      
	%let censor_strat = &censor_strat. censorcat_sort;
	%if %index(&censor_strat.,agegroup) > 0 %then %do; %let censor_strat = &censor_strat. agegroupnum; %end;
	
	%if &censordataset. = t2followuptime %then %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_spec cens_event);
	%else %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend);
   
   /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
     delete _censor_strat; 
   quit; 
 /*--------------------------------------------------------------------------------------------
 	Aggregate by censor reason and stratifications.
 	Stack aggregated with DP tables when stratification by DP is requested.                                                   
   --------------------------------------------------------------------------------------------*/  
   /* Aggregate data across all DPs */
   proc summary data = agg_&censordataset. (where=(level in (&censdays_value_level.))) nway missing;
   	 class runid level group &censor_strat. ;
   	 var episodes &censorreason.;
   	 output out = censor_all (drop = _:) sum=;
   run;
   
   %if &stratifybydp. = Y %then %do;
     /* Aggregate by DP */
     proc summary data = agg_&censordataset. (where=(level in (&censdays_value_level.))) nway missing;
      class runid dpidsiteid level group &censor_strat.;
      var episodes &censorreason.;
      output out = censor_dps (drop = _:) sum=;
     run;
   %end;
 
   /* Stack together*/
   data censor_data;
     set censor_all (in = a)   
	 %if &stratifybydp. = Y %then %do;
   	     censor_dps
	 %end;;		 
       if a then do;
	     dpidsiteid = "ALL";
	   end;
   run;
 
 /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
     delete censor_all censor_dps; 
   quit;
    
 /*--------------------------------------------------------------------------------------------
 	Calculate summary statistics to merge back onto aggregate data                                                   
   --------------------------------------------------------------------------------------------*/
 	 %let cens_num = %sysfunc(countw(&censorreason_t3., %str( )));
	 
    /* Create a blank table if distribution isn't specified */
	%if "&censor_distribution" ne "Y" %then %do;
 	   proc sql noprint;
 	   	 create table unique_groups as
 	   	 select distinct level, dpidsiteid, group, runid
 	   	 from censor_data;
 	   quit;
 	   
 	   data _stats_;
 	   	 set unique_groups;
 	   	 length table_name $12 min q1 median q3 max mean std 8;
 	   	 call missing(min, q1, median, q3, max, mean, std);
 	   	 table_name = "overall";
 	   	 output;
		 
	     %if &cens_num. > 0 %then %do;
 	   	   %do cn= 1 %to &cens_num;
 	   	      %let var = %scan(&censorreason_t3, &cn);
 	   	      table_name = "&var.";
 	   	      output;
 	   	   %end;
	     %end;
 	   run; 

	 %end;
			  
   /* Calculate summary statistics for each censoring reason.
 	 Skip over censoring reasons without counts */ 
 	 %do sl = 1 %to %sysfunc(countw(episodes &censorreason_t3., %str( )));
 		%let cen_stat = %scan(episodes &censorreason_t3.,&sl.);
 		
 		proc sql noprint;
 		  select sum(&cen_stat.) into: checksum
 		  from censor_data;
 		quit;
 		
 		%if &checksum ^= 0 %then %do;
		 
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
 		      length table_name $12;
 		      set _stats_&cen_stat.;
 		      %if &cen_stat. = episodes %then %do;
 		        table_name = "overall";
 		      %end;
 		      %else %do;
 		        table_name = "&cen_stat.";
 		      %end;
 		    run;

 		 %end; /* censor_distribution */
 		%end; /* checksum */
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
  	   	 (episodes/epi_tot)   as epi_tot_pct       format=percent10.1
		 %if &cens_num. > 0 %then %do; ,
  	   	   %do cn= 1 %to &cens_num;
  	   	     %let var = %scan(&censorreason_t3, &cn);
  	   	     (&var/epi_tot)     as &var._pct         format=percent10.1,
  	   	     (&var/&var._tot)   as &var._reason_pct  format=percent10.1
  	   	     %if &cn ^= &cens_num %then %do; , %end;
  	   	   %end;
		 %end;
  	   from (select distinct a.*, 
  	   		sum(episodes) as epi_tot
			%if &cens_num. > 0 %then %do; ,
  	   		  %do cn = 1 %to &cens_num;
  	   		    %let var = %scan(&censorreason_t3, &cn);
  	   		    sum(&var) as &var._tot
  	   		    %if &cn ^= &cens_num %then %do; , %end;
  	   		  %end;
			%end; 
  	   	    from censor_data %if "&censor_distribution" = "Y" %then %do; (drop=censdays_value) %end; a
  	   	    /* counts need to be grouped by user specified stratas */
  	   	    group by a.runid, a.dpidsiteid, a.group, a.level) as a;
 	 
  	   create table &censordataset. as
  	   select distinct a.*, 
  	 		 b.table_name,
  	 		 b.min, 
  	 		 b.q1, 
  	 		 b.median, 
  	 		 b.q3,
  	 		 b.max,
  	 		 b.mean,
  	 		 b.std,
			 e.order
			 %if &labelfileexists. = Y %then %do;
  	   		   ,case when not missing(c.label) then c.label 
               else a.group end as grouplabel
  	   		   ,case when not missing(d.label) then d.label 
               else '' end as headerlabel
  	 		 %end;
  	 		 %else %do;
  	 		   ,a.group as grouplabel
			   ,'' as headerlabel
  	 		 %end;
  	   from censor_data_den a 
	   left join _stats b
  	   on a.runid = b.runid 
	      and a.dpidsiteid = b.dpidsiteid 
	      and a.group = b.group 
	   %if &labelfileexists. = Y %then %do;
  	     left join labelfile(where=(labeltype='grouplabel')) c
  	     on a.group = c.group
  	     left join labelfile(where=(labeltype='header')) d
  	     on a.group = d.group
  	   %end;
	   left join groupsfile e
	   on a.group = e.group
	   where not missing(censdays_value_cat);
  	 quit;
 
   /* For proc report, need to acquire censoring reason episodes in the "Episode" column as well as calculate denominators within each bin */
   	 data &censordataset. (drop=censdays_value_cat);
   	   set &censordataset.;
					%if %sysfunc(prxmatch(m/sex/i,&censor_strat.)) > 0 %then %do;
						length _sex $6;
						_sex = put(sex, $sexfmt.);
						drop sex;
						rename _sex=sex;
					%end;
					%if %sysfunc(prxmatch(m/agegroup/i,&censor_strat.)) > 0 %then %do;
						length _agegroup $40;
						_agegroup = put(agegroup, $agefmt.);
						drop agegroup;
						rename _agegroup=agegroup;
					%end;
	   length strat $8;
		 if level in (&censdays_value_level.) then strat = "overall";
   	     if not missing(censdays_value_cat) then do;
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
				drop plus;
			end;
			drop dash pre;
   	     end;
   	   %if "&censor_distribution" = "Y" %then %do;
   	     /*Dummy variable to use as 'across' variable to correctly place header*/
   	     dummy = .;
   	   %end;
	   %if &cens_num. > 0 %then %do;
   	     %do cn = 1 %to &cens_num;
   	       %let var = %scan(&censorreason_t3, &cn);
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
	   %end;
   	   format epi_tot_pct percent10.1;
   	 run;
   
   	 %if "&censor_distribution" = "Y" %then %do;
   	    proc sort data = &censordataset. nodupkey;
   		  by _all_;
   	    run;

   	 %end;
   
   	 proc sort data=&censordataset.;
   	    by order dpidsiteid censorcat_sort table_name;
   	 run;
 
   /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
      delete _stats censor_data:; 
   quit;

   %put =====> END MACRO: censortable_createdata;
%mend censortable_createdata;