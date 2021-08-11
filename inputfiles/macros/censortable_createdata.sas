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
*   - [runid]_censor_cida.sas7bdat                                                                                
* 
*  Program outputs:                                                                                                                                       
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
%macro censortable_createdata (tables = , censordataset = );
  %put =====> MACRO CALLED: censortable_createdata
  /*Create censor lookup table*/;
    data censor_tablelookup;
        set tablefile;
        where dataset in ("&censordataset.");
    run;

    %isdata(dataset=censor_tablelookup);
    %if %eval(&nobs.>0) %then %do;
        %let censortables =;
		%let censorfigures =;
		
		/*Determine which tables and figures to produce*/
		proc sql noprint;
			select distinct table into: censortables separated by ' '
			from censor_tablelookup
			where substr(table,1,1)='T';

			select distinct table into: censorfigures separated by ' '
			from censor_tablelookup
			where substr(table,1,1)='F';
		quit;
		%put &censortables. &censorfigures.;

    /*--------------------------------------------------------------------------------------------
		Put levelIDs in macro variables                                                            
      --------------------------------------------------------------------------------------------*/
		%let censor_overall = '';
		proc sql noprint;
			select "'"||strip(levelid12)||"'" into: censor_levelid separated by ','
			from (select distinct levelid1 as levelid12
				  from censor_tablelookup
				  union corr all
				  select distinct levelid2 as levelid12
				  from censor_tablelookup
				  where levelid2 ne '');

			select strip(strat12) into: censor_strat separated by ' '
			from (select distinct strat1 as strat12
				  from censor_tablelookup
				  union corr all
				  select distinct strat2 as strat12
				  from censor_tablelookup
				  where strat2 ne '');
				  
			select "'"||strip(levelid12)||"'" into: censor_overall separated by ','
			from (select distinct levelid1 as levelid12
				  from censor_tablelookup
				  where lowcase(tablesub)='overall'
				  union corr all
				  select distinct levelid2 as levelid12
				  from censor_tablelookup
				  where lowcase(tablesub)='overall' and levelid2 ne '');
				  
			select distinct(censorreason) into: censorreason
			from censor_tablelookup;
		quit;
		
        %if %index(&censor_strat, censdays_value_cat) %then %do; %let censor_strat = &censor_strat censorcat_sort; %end;
		
		%put &censor_levelid &censor_strat. &censor_overall.;
		
    /*--------------------------------------------------------------------------------------------
		Assign default censor reason if it is not assigned in the tablefile                                                        
      --------------------------------------------------------------------------------------------*/
	   %if %str("&censorreason.") = %str("") %then %do;
	      %if &type. = 1 %then %do;
             %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend);
          %end;
		  %else %if &type. = 2 %then %do;
             %let censorreason = %str(cens_episend cens_event cens_spec cens_dth cens_elig cens_dpend cens_qryend);
		  %end;
		  %else %do;
		     %let censorreason = %str(cens_episend cens_spec cens_dth cens_elig cens_dpend cens_qryend);
		  %end;
       %end;
	   
	/*--------------------------------------------------------------------------------------------
		Aggregate censor tables across runs                                                    
      --------------------------------------------------------------------------------------------*/
	   %do dps = 1 %to %eval(&num_dp.); 
         %let dpidsiteid = %scan(&random_dplist,&dps); 
    	 %let maskedID = %scan(&masked_dplist,&dps); 
		 
		 %do n = 1 %to &numrunid.;
    	   %let runid = %scan(&runidlist, &n); 
		   %let tablefigures = %sysfunc(tranwrd(&tables.,%str( ),%str(|)));
		   
		   /* Identify table and figure files */
		   %if (%sysfunc(prxmatch(m/&tablefigures./i,&censortables.)) > 0) | (%sysfunc(prxmatch(m/&tablefigures./i,&censorfigures.)) > 0) %then %do;
		   	  %if %sysfunc(exist(&dpidsiteid..&runid._censor_cida))=0 %then %do;
		   		%put WARNING: (Sentinel) &RUNID._censor_cida does not exist for &dpidsiteid.. Please confirm correct DP and path location specified. Program will abort;
		   		%abort; 
		   	  %end;
		   	  %else %do; 
		   		data _censor_dp&dps.;
		   		  length runid $5. dpidsiteid $6.;
		   		  set &dpidsiteid..&runid._censor_cida;
		   		  where lowcase(group) in (&&grouplist_&n..) and level in (&censor_levelid.);
		   		  dpidsiteid = "&maskedID";  
				  runid = "&runid.";
		   		run;   
		      %end; /* censor cida data exists */
		   %end; /* censor table and figures exist */
		 %end; /* runid */
	   %end; /* data partners */
	   
	   data censor_cida_agg;
	     set _censor_dp:
		 %if %sysfunc(prxmatch(m/sex/i,&censor_strat.)) > 0 %then %do;
		   (rename = (sex = _sex))
		 %end;;
		 %if %sysfunc(prxmatch(m/sex/i,&censor_strat.)) > 0 %then %do;
			length sex $45;
			sex = put(_sex, $sexfmt.);
			drop _sex;
		 %end;    
	   run;
	   
	  /* Clean up work files */
      proc datasets lib=work nowarn nolist noprint;
        delete _censor_dp:; 
      quit;
	   
	/*--------------------------------------------------------------------------------------------
		Aggregate up by censor reason and stratifications and stack aggregated with DP tables                                                   
      --------------------------------------------------------------------------------------------*/
	  %if (%sysfunc(prxmatch(m/&tablefigures./i,&censortables.)) > 0) %then %do;
	     /* Aggregate data across all DPs */
	     proc summary data = censor_cida_agg nway missing;
	     	class runid level group &censor_strat. ;
	     	var episodes &censorreason.;
	     	output out = censor_all (drop = _:) sum=;
	     run;
	     
	     /* Aggregate by DP */
	     proc summary data = censor_cida_agg nway missing;
	     	class runid dpidsiteid level group &censor_strat.;
	     	var episodes &censorreason.;
	     	output out = censor_dps (drop = _:) sum=;
	     run;
	     
	     /* Stack together*/
	     data censor_data;
	       set censor_all (in = a)
	     	   censor_dps (in = b);
	       if a then dpidsiteid = "ALL";
	     run;
		 
		 /* Clean up work files */
         proc datasets lib=work nowarn nolist noprint;
           delete censor_all censor_dps censor_cida_agg; 
         quit;
	     	
	     %let dsid = %sysfunc(open(censor_data));
	     %if %sysfunc(varnum(&dsid,censdays_value))>0 %then %do; %let censor_distribution = Y; %end;
	     %if %sysfunc(varnum(&dsid,censdays_value_cat))>0 %then %do; %let censor_category = Y; %end;
	     %let rc = %sysfunc(close(&dsid));
	   
	/*--------------------------------------------------------------------------------------------
		Calculate summary statistics to merge back onto aggregate data                                                   
      --------------------------------------------------------------------------------------------*/
	  /* Calculate summary statistics for each censoring reason.
		 Skip over censoring reasons without counts */
		 %let cens_num = %sysfunc(countw(&censorreason., %str( )));

		 %do sl = 1 %to %sysfunc(countw(episodes &censorreason., %str( )));
			%let cen_stat = %scan(episodes &censorreason.,&sl.);
			
            %do n = 1 %to &numrunid.;
    	       %let runid = %scan(&runidlist, &n);
			   proc sql noprint;
			     select sum(&cen_stat.) into: checksum
			     from censor_data (where = (runid = "&runid."));
			   quit;
			   
			   %if &checksum = 0 %then %do;
			   	 %put WARNING: (Sentinel) Variable &cen_stat. has no episodes for runid &runid.. This variable will not be used to generate summary statistics;
			   %end;
			   %else %do;	   
                  %if "&censor_distribution" = "Y" %then %do;
			   	    proc means data= censor_data (where = (runid = "&runid.")) nway missing noprint classdata=censor_data;
			   	    	var censdays_value;
			   	    	class dpidsiteid group level ;
			   	    	freq &cen_stat.;
			   	    	where not missing(censdays_value);
			   	    	output out=_stats_&cen_stat.&n. (drop=_type_ _freq_)     
			   	    								mean = Mean 
			   	    								std = std
			   	    								min = min
			   	    								q1 = q1
			   	    								median = median 
			   	    								q3 = q3
			   	    								max = max;
			   	    run;
			   
			      	/* Create indicator variable to show which statistics are associated with which censor reason */ 
			      	data _stats_&cen_stat.&n.;
			      	  length table_name $32;
			      	  set _stats_&cen_stat.&n.;
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
			      	  	 select distinct level, dpidsiteid, group
			      	  	 from censor_data (where = (runid = "&runid."));
			      	  quit;
			   	  
			      	  data _stats_&n.;
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
			%end; /* runid */
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
	 	   		  %let var = %scan(&censor_reason, &cn);
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
	 	   
	 	   create table censor_data_final(drop=group) as
	 	   select distinct a.*, 
	 	         %if &labelfileexists. = Y %then %do;
	 	   		   b.order, 
	 	   		   b.label as grouplabel
	 	 		 %end;
	 	 		 %else %do;
	 	 		   a.group as grouplabel
	 	 		 %end;
	 	   from censor_data_stats a 
	 	   %if &labelfileexists. = Y %then %do;
	 	     inner join labelfile(where=(labeltype='grouplabel')) b
	 	     on a.runid = b. runid and a.group = b.group
	 	   %end;
	 	   %if "&censor_category" = "Y" %then %do; where not missing(censdays_value_cat) %end;
	 	   order by runid, dpidsiteid, grouplabel %if "&censor_category" = "Y" %then %do; ,censorcat_sort, censdays_value_cat %end; , table_name;
	 	 quit;

      /* For proc report, need to acquire censoring reason episodes in the "Episode" column as well as calculate denominators within each bin */
	  	 data censor_data_final;
	  	   set censor_data_final;
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
	  
	  	 %if "&censor_distribution" = "Y" and %str("&censor_category") eq %str("") %then %do;
	  	    proc sort data = censor_data_final nodupkey;
	  		  by _all_;
	  	    run;
	  	 %end;
	  
	  /* Final formatting */
	  	 data censor_data_final;
	  	   set censor_data_final;
	  	   length strat $8;
	  	   if level in (&censor_overall.) then strat = 'overall';
	  	   %if "&censor_category" = "Y" %then %do;
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
	  
	  	 proc sort data=censor_data_final;
	  	    by order runid dpidsiteid %if %str("&censor_category") = %str("Y") %then %do; censorcat_sort %end; ;
	  	 run;
		 
		  data output.censor_data_final;
	  set censor_data_final;
	  run;
	  
	  %end; /* censortables > 0 */	
   %end; /* censor_tablelookup nobs > 0 */

   /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
      delete _stats censor_data_stats; 
   quit;

   %put =====> END MACRO: censortable_createdata;
%mend censortable_createdata;