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
*   - t5censor_first.sas7bdat
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
   %let censorreason_t3_all = ;/* Table 3 user specified censor reasons*/
   %let censor_strat_all = ;   /* All censor stratifiers */
   %let levels_all = ;         /* All levels that do not not contain censdays_value as a stratifier*/
   %let tablesub_all =;        /* All tablesubs */
   %let level_o =;        /* Level associated with overall continuous return */
   
   proc sql noprint;
     select tablesub
            ,%if &censordataset. = t5censor %then %do; catx(' ',strat1, strat2) %end;
			 %else %do; strat1 %end;
	        ,"'"||strip(levelid1)||"'"
			,"'"||strip(levelid2)||"'"
	  into :tablesub_all separated by " "
	       ,:censor_strat_all separated by " "
		   ,:levels_all separated by " "
		   ,:level_o separated by " "
     from tablefile (where = (dataset = "&censordataset." and table in (&tables.))) ;
	 
	 /* User specified censor reasons for Type 1 and Type 2 table 3 and Type 5 table 15 and 17 */
	 %if %index(&tables.,T3) > 0 | %index(&tables.,T15) > 0 | %index(&tables.,T17) > 0 %then %do;
			select distinct(censorreason) into: censorreason_t3_all separated by ' '
			from tablefile (where = (dataset = "&censordataset." and table in ("T3", "T15", "T17")));
	 %end;
	 
	 /* If T5Censor then acquire categories from the tablefile */  
     %if &censordataset. = t5censor %then %do;
      select distinct(categories) into: catvar
		  from tablefile (where = (dataset = "&censordataset." and table in ("T15", "T17")));
     %end;
   quit;
	
	/* Create a unique list of stratifiers and levels */
	%nonrep(invar= censor_strat_all, outvar = censor_strat);
	%nonrep(invar= levels_all, outvar = levels);
	%nonrep(invar= tablesub_all, outvar = tablesubs);
	%nonrep(invar= level_o, outvar = level_overall);
	%nonrep(invar= censorreason_t3_all, outvar = censorreason_t3);
      
	%if %sysfunc(prxmatch(m/T1|T2L1/i,&reporttype.)) %then %do;  %let censor_strat = &censor_strat. censorcat_sort; %end;
	%if %index(&censor_strat.,agegroup) > 0 %then %do; %let censor_strat = &censor_strat. agegroupnum; %end;
	%if %index(&tables.,T15) > 0 | %index(&tables.,T17) > 0 %then %do; %let censor_strat = &censor_strat. censdays_value_cat censorcat_sort; %end;
	
	/* All possible censor reasons based on dataset type */
	%if &censordataset. = t2followuptime %then %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_spec cens_event);
	%else %if &censordataset. = t5censor %then %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_spec);
	%else %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend);
	
	/* If t2followuptime or t2censor and overall stratification is requested then censdays_value is required 
	   If t5 censor requested and episodelength is a stratifier then confirm episodenum is populated */
	%if &censordataset. ne t5censor and %str(&level_overall) ne %str('') %then %let distribution_var = censdays_value;
	%else %if %index(&censor_strat.,episodelength) > 0 %then %let distribution_var = episodelength;
	%else %let distribution_var = ;
	
	/* Count the number of unique censor reassons across all tables and for table 3 only */
	%let cens_num_t3 = %sysfunc(countw(&censorreason_t3., %str( )));
 	%let cens_num = %sysfunc(countw(&censorreason., %str( )));
	
 /*--------------------------------------------------------------------------------------------
    If T5Censor apply censdays_value_cat to the agg_t5censor data
   --------------------------------------------------------------------------------------------*/  
   %if &censordataset. = t5censor and (%index(&tables.,T15) > 0 | %index(&tables.,T17) > 0) %then %do;
      %convert_categories(var=episodelength, categories=&catvar.);
	  
      data agg_&censordataset.;
          set agg_&censordataset. (where=(level in (&levels. &level_overall.)));
          *assign categories;
          length censdays_value_cat $15. censorcat_sort 3;
		  *initialize values;
		  call missing(censdays_value_cat);
		  censorcat_sort = 1;
          %do c =1 %to &num_categories.;
              if %scan(&categories_boolean., &c., ' ') then do;
                  censdays_value_cat = "%scan(&catvar., &c., ' ')";
                  censorcat_sort = &c.;
              end;
          %end;            
      run;
	  
	  %let levels_t15 =;
	  /* Identify levels associated with Table 3 */
	  proc sql noprint;
	     select case when table = "T15" then "'"||strip(levelid1)||"'"
                else "'"||strip(levelid2)||"'" end 
		 into: levels_t3 separated by ' '
		 from tablefile (where = (dataset = "t5censor" and table in ("T15", "T17")));

         %if %index(&tables.,T15) > 0 %then %do;  
		   select "'"||strip(levelid1)||"'"
		   into: levels_t15 separated by ' '
		   from tablefile (where = (dataset = "t5censor" and table in ("T15")));
		 %end;
	  quit;
	  
	  /* Square table censdays_value_cat and censorcat_sort */
	  proc sql noprint;
 	   	 create table _unique_groups as
 	   	 select distinct dpidsiteid, group, runid, level
 	   	 from agg_&censordataset. (where = (level in (&levels_t3.)))
		 order by dpidsiteid, group, runid, level;
 	  quit;
	  
	  data _square_censdays;
	    set _unique_groups;
		by dpidsiteid group runid level;
		length censdays_value_cat $50. censorcat_sort 3;
		%do c =1 %to &num_categories.;
           censdays_value_cat = "%scan(&catvar., &c., ' ')";
           censorcat_sort = &c.;
		   _episodes = 0;
		   _npts = 0;
		   %do cn= 1 %to &cens_num_t3.;
  	      	 _%scan(&censorreason, &cn) = 0;
  	       %end;
		   output;
        %end; 
	  run;
	  
	  proc sort data = agg_&censordataset.;
	    by dpidsiteid group runid level censorcat_sort;
	  run;
	  
	  data agg_&censordataset (drop = _:);
	    merge _square_censdays (in = square)
		      agg_&censordataset (in = censor);
	    by dpidsiteid group runid level censorcat_sort censdays_value_cat;
		if square and not censor and not missing(censdays_value_cat) then do;
		  %if %index(&tables.,T15) > 0 %then %do; 
		    episodenum = 1;
		  %end;
		  if index(censdays_value_cat,'-') > 0 then episodelength = input(scan(censdays_value_cat,1,'-'),8.);
		  else if index(censdays_value_cat,'+') > 0 then episodelength = input(scan(censdays_value_cat,1,'+'),8.);
		  else episodelength = input(censdays_value_cat,8.);
		  episodes = _episodes;
		  npts = _npts;
		  %do cn= 1 %to &cens_num_t3.;
  	      	 %scan(&censorreason, &cn) = _%scan(&censorreason, &cn);
  	      %end;
		end;
	  run;
	  
	  /* Clean up work files */
      proc datasets lib=work nowarn nolist noprint;
       delete _square_censdays _unique_groups; 
      quit;
   %end;
   
 /*--------------------------------------------------------------------------------------------
 	Aggregate by censor reason and stratifications.
 	Stack aggregated with DP tables when stratification by DP is requested.                                                   
   --------------------------------------------------------------------------------------------*/  
   /* Aggregate data across all DPs */
   proc summary data = agg_&censordataset. (where=(level in (&levels. &level_overall.))) nway missing;
   	 class runid group &censor_strat. level &distribution_var.;
   	 var episodes &censorreason.;
   	 output out = censor_all (drop = _:) sum=;
   run;
   
   %if &stratifybydp. = Y %then %do;
     /* Aggregate by DP */
     proc summary data = agg_&censordataset. (where=(level in (&levels. &level_overall.))) nway missing;
      class runid dpidsiteid group &censor_strat. level &distribution_var.;
      var episodes &censorreason.;
      output out = censor_dps (drop = _:) sum=;
     run;
   %end;
 
   /* Stack together*/
   data %if %str(&distribution_var.) ne %str() %then %do;
          censor_data (drop = &distribution_var.)
          censor_data_overall (drop = level)
		%end;
		%else %do;
		  censor_data
		%end;;
     set censor_all (in = a)   
	 %if &stratifybydp. = Y %then %do;
   	     censor_dps
	 %end;;		 
       if a then do;
	     dpidsiteid = "ALL";
	   end;
	   %if %str(&distribution_var.) ne %str() %then %do;
	     if not missing(&distribution_var.) then output censor_data_overall; /* Data used for censor reason summary statistics */
		 /* Data used for stratification statistics */
	     %if %str(&distribution_var.) = %str(censdays_value) %then %do; else output censor_data; %end; 
		 %else %do; if not missing(&distribution_var.) then output censor_data; %end; /* Data used for T5Censor stratifications when episodelength requested */
	   %end;
   run;
 
  /* Identify levels on the censor_data dataset */
   proc sql noprint;
     select count(distinct(level)) into: numcensorlevel trimmed
	 from censor_data;
	 
	 /* There are instances where there are multiple levesl for t5censor, but tablesub is always overall, so force tablesub macros to "overall" */
	 select distinct(a.level) 
            ,%if &censordataset. = t5censor %then %do; "overall" %end;
			 %else %do; tablesub %end;
      into:censlevel1 -:censlevel&numcensorlevel.
		 ,:tablesub1 -:tablesub&numcensorlevel.
	 from censor_data as a
     left join tablefile (where = (dataset = "&censordataset." and table in (&tables.))) as b
       on strip(a.level) = strip(b.levelid1);
   quit;
   
 /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
     delete censor_all censor_dps; 
   quit;
   
 /*--------------------------------------------------------------------------------------------
 	Set default values for summary statistics when censdays_value or episodelength stratification
    not requested	
   --------------------------------------------------------------------------------------------*/
  /* Create a blank table. If overall table not requested or there are no episodes on the dataset this
     dataset is used as a table shell. */
 	   proc sql noprint;
 	   	 create table unique_groups as
 	   	 select distinct dpidsiteid, group, runid
 	   	 from censor_data;
 	   quit;
 	   	   
     data %if %str(&distribution_var.) ne %str() %then %do;_square_stats %end;
	      %else %do; _stats %end;;
 	   	 set unique_groups;
 	   	 length table_name $12 min q1 median q3 max mean std 8;
 	   	 call missing(min, q1, median, q3, max, mean, std);
 	   	 table_name = "overall";
 	   	 output;
		 
	     %if &cens_num_t3. > 0 %then %do;
 	   	   %do cn= 1 %to &cens_num_t3;
   	       table_name = "%scan(&censorreason_t3, &cn)";
 	   	      output;
 	   	   %end;
	     %end;
 	   run; 
		
 /*--------------------------------------------------------------------------------------------
 	Calculate summary statistics	
   --------------------------------------------------------------------------------------------*/
   %macro censor_summary (dset_suffix = , whereclause = );
   /* Calculate summary statistics for each censoring reason.
 	  Skip over censoring reasons without counts */ 
	 %if %str(&distribution_var.) ne %str() %then %do;
 	    %do sl = 1 %to %sysfunc(countw(episodes &censorreason_t3., %str( )));
 	    	%let cen_stat = %scan(episodes &censorreason_t3.,&sl.);
			%if &cen_stat. = episodes %then %do; %let table_name = overall; %end;
 	    	%else %do; %let table_name = &cen_stat.; %end;
				  
 	    	   proc sql noprint;
 	    	     select sum(&cen_stat.) into: checksum
 	    	     from censor_data_overall &whereclause.;
 	    	   quit;
 	    	   
 	    	 %if &checksum ^= 0 %then %do;
           
 	    	   proc means data= censor_data_overall &whereclause. nway missing noprint classdata=censor_data_overall &whereclause.;
 	    	    	var &distribution_var.;
 	    	    	class runid dpidsiteid group;
 	    	    	freq &cen_stat.;
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
				  table_name = "&table_name.";
 	    	   run;
			   
 	    	 %end; /* checksum */
			 %else %do;
			   /* Use table shell when there are not any episodes */
			   data _stats_&cen_stat.;
			     length table_name $12;
			     set _square_stats (where = (table_name = "&table_name."));
			   run;
			   
			 %end;
 		%end; /* censor reasons*/
		
		/* Stack all datasets together with one unique row per censor reason */
		data _stats;
 	      set _stats_:;
        run; 
		
 	 %end; /* overall levels */
	 
   /* Clean up work files */
      proc datasets lib=work nowarn nolist noprint;
        delete %if %str(&distribution_var.) ne %str() %then %do;_stats_: %end; 
		       unique_groups; 
      quit;	
	  
   /* If episodelength is requested for stratification need to summarize data by 
      runid group dpidsiteid level and censorcat_sort for tables 2 and 3. If only
      episodenum is requested (table 14), then summarize by runid group dpidsiteid level. */
      %if %index(&censor_strat.,episode) > 0 %then %do; 
	    proc sql noprint undo_policy=none;
		  create table censor_data&dset_suffix. as 
		     select runid
			       ,group
				   ,dpidsiteid
				   ,level
				   %if %index(&tables.,T15) > 0 | %index(&tables.,T17) > 0 %then %do;
				   ,censdays_value_cat 
				   ,censorcat_sort
				   %end;
				   ,sum(episodes) as episodes
				   %do cn= 1 %to &cens_num;
  	      	          %let var = %scan(&censorreason, &cn);
					  ,sum(&var.) as &var.
  	      	       %end;
		     from censor_data &whereclause.
			 group by runid, group, dpidsiteid, level
			       %if %index(&tables.,T15) > 0 | %index(&tables.,T17) > 0 %then %do;
				     ,censdays_value_cat
					 ,censorcat_sort
				   %end;;
		quit;
	  %end;
	  
   /* Calculate denominators and percentage totals by stratifiers, joining summary stats back to aggregate data 
      Looping occurs based on levels on the censor_data dataset. For Types 1 and 2 these are levels that do not have
	  censdays_value populated. There is one loop for each tablesub requested. For type 5 the loop runs for all levels requested */
      %do cl = 1 %to &numcensorlevel.;
  	    proc sql noprint;
  	      create table den&cl. (drop = level) as
  	      select distinct b.* 
	                     ,a.epi_tot
  	      	             ,(b.episodes/a.epi_tot)   as epi_tot_pct         
	   	                 %do cn= 1 %to &cens_num;
  	      	                %let var = %scan(&censorreason, &cn);
							,a.&var._tot
  	      	                ,(b.&var/a.&var._tot)   as &var._pct          
							,a.&var._tot/a.epi_tot  as &var._tot_pct      
  	      	             %end;
						 ,"&&tablesub&cl." as strat                       length=8 format = $8.
						 %if "&&tablesub&cl." = "overall" %then %do;
						   ,a.epi_tot as overall_tot
						 %end;
  	      from censor_data&dset_suffix. (where =(level = "&&censlevel&cl.")) as b
	      left join 
	          (select distinct runid
	   	           ,dpidsiteid
	   			   ,group
	   			   %if "&&tablesub&cl." ne "overall" %then %do; ,&&tablesub&cl. %end; 
  	      		       ,sum(episodes) as epi_tot 
  	      		       %do cn = 1 %to &cens_num;
  	      		         %let var = %scan(&censorreason, &cn);
  	      		         ,sum(&var) as &var._tot
  	      		       %end;
  	      	           from censor_data&dset_suffix. (where =(level = "&&censlevel&cl.")) a
  	      	           /* counts need to be grouped by user specified stratas */
  	      	           group by runid 
	   			           ,dpidsiteid 
	   			           ,group  
	   					   %if "&&tablesub&cl." ne "overall" %then %do; ,&&tablesub&cl. %end;) as a
	   	           on a.runid = b.runid 
	   	           and a.dpidsiteid = b.dpidsiteid 
	   	           and a.group = b.group 
	   	           %if "&&tablesub&cl." ne "overall" %then %do; and a.&&tablesub&cl. = b.&&tablesub&cl. %end;;
	      quit;
		  
		  /* Create an overall_tot variable when overall counts are not requested. This is needed for missing value indicators */
		  %if "&&tablesub&cl." ne "overall" %then %do;
		     proc sql noprint undo_policy=none; 
			   create table den&cl. as
			   select b.*
			          ,a.overall_tot
			   from (
			   select distinct runid
	   	             ,dpidsiteid
	   			     ,group
					 ,sum(episodes) as overall_tot
			   from den&cl.
			   group by runid, dpidsiteid, group) as a
			   left join (
			      select *
				  from den&cl. as b)
			   on a.runid = b.runid 
			      and a.dpidsiteid = b.dpidsiteid
				  and a.group = b.group;
		     quit;
		  %end;
	  %end;
    
      data censor_data_den&dset_suffix;
        set den:;
      run;
      
    /* Clean up work files */
      proc datasets lib=work nowarn nolist noprint;
       delete den:; 
      quit;	
		
	  proc sql noprint;
  	     create table &censordataset.&dset_suffix. as
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
                 when not missing(c.label) then c.label 
				 else a.group end as headerlabel
  	   	 %end;
  	   	 %else %do;
  	   	   ,a.group as grouplabel
	  		   ,'' as headerlabel
  	   	 %end;
  	     from censor_data_den&dset_suffix a 
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
		 %if %str(&distribution_var.) = %str(censdays_value) %then %do;
	     where not missing(censdays_value_cat) %end;;
  	   quit;

    /* Clean up work files */
       proc datasets lib=work nowarn nolist noprint;
        delete den:; 
       quit;
 
   /* For proc report, need to acquire censoring reason episodes in the "Episode" column as well as calculate denominators within each bin */
   	   data &censordataset.&dset_suffix. (drop=censdays_value_cat);
   	     set &censordataset.&dset_suffix.;
		 %if %str(&distribution_var.) = %str() and &censordataset. = t5censor %then %do;
		   length censdays_value_cat $50. censorcat_sort 3;
		   censdays_value_cat = "";
		   censorcat_sort = 1;
		 %end;
	  	 %if %index(&tablesubs.,sex) > 0 %then %do;
	  	 	length _sex $6;
	  	 	_sex = put(sex, $sexfmt.);
	  	 	sex_sort = put(sex, $sexsort.);
	  	 	drop sex;
	  	 	rename _sex=sex;
	  	 %end;
	  	 %if %index(&tablesubs.,agegroup) > 0 %then %do;
	  	 	length _agegroup $40;
	  	 	_agegroup = put(agegroup, $agefmt.);
	  	 	drop agegroup;
	  	 	rename _agegroup=agegroup;
	  	 %end;
	  	 if strat ne "overall" then do;		 
	  		 min = .;
  	   		 q1 = .; 
  	   		 median = .; 
  	   		 q3 = .;
  	   		 max = .;
  	   		 mean = .;
  	   		 std = .;
	  	 end;
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
	     %if &cens_num_t3. > 0 %then %do;  
   	       %do cn = 1 %to &cens_num_t3.;
   	         %let var = %scan(&censorreason_t3., &cn);
   	         if table_name = "&var" then do;
   	         	  episodes = &var;
   	        	  epi_tot_pct = &var._pct;
   	        	  &var = &var._tot;
				  drop &var._pct;
   	         end;
   	       %end;
	     %end;
		 if missing(epi_tot_pct) then epi_tot_pct = 0;
   	   run;
	   
	   /*Assign missing values indicators*/
	   %let pct = '';
	   %let tot = '';

       proc contents data=&censordataset.&dset_suffix. out=&censordataset._vars noprint;
	   quit;

	   proc sql noprint;
	     select distinct name into :pct 
           separated by ' '
           from &censordataset._vars 
           where lowcase(substr(name, length(name) - 3,4)) = "_pct";

           select distinct name into :cen_tot 
           separated by ' '
           from &censordataset._vars 
           where lowcase(substr(name, length(name) - 3,4)) = "_tot";
	   quit;

       %let stat_char = min q1 median q3 max mean std;
	   %let cen_tot = &cen_tot &censorreason;

       data &censordataset.&dset_suffix.(drop= overall_tot:);
         set &censordataset.&dset_suffix.;
	      /*_tot variable char and missing creation */
	     episodes_char = strip(put(episodes, comma8.0));
         %do  cr = 1 %to %sysfunc(countw(&cen_tot));
           %scan(&cen_tot, &cr, ' ')_char = strip(put(%scan(&cen_tot, &cr, ' '), comma8.0));
         %end;
	     /*stat variables*/
	     %do  cr = 1 %to %sysfunc(countw(&stat_char));
           %if %sysfunc(prxmatch(m/mean|std/i,%scan(&stat_char, &cr, ' '))) %then %do;
             %scan(&stat_char, &cr, ' ')_char = strip(put(%scan(&stat_char, &cr, ' '), 10.1));
           %end;
           %else %do;
             %scan(&stat_char, &cr, ' ')_char = strip(put(%scan(&stat_char, &cr, ' '), comma8.0));
           %end; 
	     %end;

	     /*_pct variables*/
	     %do  cr = 1 %to %sysfunc(countw(&pct));    
           %scan(&pct, &cr, ' ')_char = strip(put(%scan(&pct, &cr, ' '), percent10.1));	   
         %end;

		 %do cr1 = 1 %to %sysfunc(countw(&cen_tot));
         /* pct and stat variables */ 

		 	%let step1 = %scan(&cen_tot, &cr1, ' ');
			%let pctVar = &step1._pct;  
		 
		   if overall_tot = 0 then do;
		     &pctVar._char = "."; 
		   end;
		   if ((%scan(&cen_tot, &cr1, ' ') = 0) or missing(%scan(&cen_tot, &cr1, ' ')) = 1)and overall_tot > 0  
		       and episodes = 0
             then do;
		     &pctVar._char = "0.0%";
		   end;
		   if table_name ne "overall" then do;
		   	   if  table_name = "%scan(&cen_tot, &cr1, ' ')" and (%scan(&cen_tot, &cr1, ' ')) = 0
			   and overall_tot > 0  then epi_tot_pct_char = "NaN";
		   end;

		 %do  cr = 1 %to %sysfunc(countw(&stat_char));
		 if overall_tot = 0 then do;
		     %scan(&stat_char, &cr, ' ')_char = "."; 
		   end;
		   else if (episodes = 0)and overall_tot > 0 
             and strat ne "overall" 
             then do;
		     %scan(&stat_char, &cr, ' ')_char = "NaN"; 
		   end;
         if "%scan(&stat_char, &cr, ' ')" = "std" and episodes = 1 
           and strat ne "overall"
		   then do;
		   %scan(&stat_char, &cr, ' ')_char = "NaN";
		 end;
		 if strat ne "overall" and %scan(&stat_char, &cr, ' ')_char = "NaN" 
		   then do;
		    %scan(&stat_char, &cr, ' ')_char = ".";
         end; 
         %end;
         
		 if overall_tot = 0
           then do;
             %scan(&cen_tot, &cr1, ' ')_char = ".";		  
         end;
         else if (%scan(&cen_tot, &cr1, ' ') = 0 and overall_tot > 0)
           then do;
             %scan(&cen_tot, &cr1, ' ')_char = "0"; 	   
         end;
         
	     %end;
     run;



        /*final sort of data*/
        proc sort data=&censordataset.&dset_suffix. ;
   	      by order censorcat_sort table_name dpidsiteid
	  	%if %index(&censor_strat.,sex) > 0 %then %do; sex_sort %end; 
	  	%if %index(&censor_strat.,agegroup) > 0 %then %do; agegroupnum %end;
	  	%if %index(&censor_strat.,year) > 0 %then %do; year %end;;
   	   run;
 
   %mend censor_summary;

   /* If episodenum is a stratification variable then create first episode tables */
   %if %index(&censor_strat.,episodenum) > 0 %then %do;
      %censor_summary (dset_suffix = _first, whereclause = %str((where = (episodenum = 1))));
   %end;
   
   /* Create all episodes tables */
    %if %sysfunc(prxmatch(m/t1censor|t2censor|t2followuptime/i,&censordataset.)) > 0 | (&censordataset=t5censor and %sysfunc(prxmatch(m/T16|T17/i,&tables.)) > 0) %then %do;
   %censor_summary;
    %end;
   
   /* Clean up work files */
    proc datasets lib=work nowarn nolist noprint;
       delete _stats censor_data: _square_stats; 
    quit;

   %put =====> END MACRO: censortable_createdata;

%mend censortable_createdata;
