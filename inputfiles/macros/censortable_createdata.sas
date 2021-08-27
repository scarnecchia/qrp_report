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
   /* Table specific user specified censor reasons*/
   %let censorreason_t3_all = ;
   
   proc sql noprint;
     select count(tablesub) into: numstrat trimmed from tablefile (where = (dataset = "&censordataset." and table in (&tables.))) ;
     select tablesub
            ,strat1
	        ,"'"||strip(levelid1)||"'"
			,"'"||strip(levelid2)||"'"
	  into :tablesub1 - :tablesub&numstrat.
	       ,:strat1 - :strat&numstrat.
		   ,:levels1 - :levels&numstrat.
		   ,:levels_o1 - :levels_o&numstrat.
     from tablefile (where = (dataset = "&censordataset." and table in (&tables.))) ;
	 
	 /* User specified censor reasons for Type 2 table 3 and Type 5 table 15 and 17 */
	 %if %index(&tables.,T3) > 0 | %index(&tables.,T15) > 0 | %index(&tables.,T17) > 0 %then %do;
			select distinct(censorreason) into: censorreason_t3_all separated by ' '
			from tablefile (where = (dataset = "&censordataset." and table in ("T3", "T15", "T17")));
	 %end;
	 
	 /* If T5Censor then acquire categories from the tablefile */  
     %if &censordataset. = t5censor %then %do;
        select distinct(categories) into: catvar
		from tablefile (where = (dataset = "&censordataset." and table in (&tables.)));
     %end;
   quit;
	
	/* Create a unique list of stratifiers and levels*/
	%let censor_strat_all = ; /* All censor stratifiers */
	%let levels_all = ; /* All levels that do not not contain censdays_value as a stratifier*/
	%let tablesub_all =; /* All tablesubs */
	%let levels_o_all =; /* All levels associated with overall tablesubs */
    %do s = 1 %to &numstrat.; 
	  %let censor_strat_all = &censor_strat_all. &&strat&s.;
	  %let levels_all = %sysfunc(tranwrd(&levels_all. &&levels&s.,%str(''),%str()));
	  %let tablesub_all = &tablesub_all. &&tablesub&s.;
	  %let levels_o_all = %sysfunc(tranwrd(&levels_o_all. &&levels_o&s.,%str(''),%str()));
	%end;
	
	/* Remove duplicate values */
	%nonrep(invar= censor_strat_all, outvar = censor_strat);
	%nonrep(invar= levels_all, outvar = levels);
	%nonrep(invar= tablesub_all, outvar = tablesubs);
	%nonrep(invar= levels_o_all, outvar = levels_overall);
	%nonrep(invar= censorreason_t3_all, outvar = censorreason_t3);
      
	%if %sysfunc(prxmatch(m/T1|T2L1/i,&reporttype.)) %then %do;  %let censor_strat = &censor_strat. censorcat_sort; %end;
	%if %index(&censor_strat.,agegroup) > 0 %then %do; %let censor_strat = &censor_strat. agegroupnum; %end;
	%if %index(&censor_strat.,episodelength) > 0 %then %do; %let censor_strat = &censor_strat. censdays_value_cat censorcat_sort; %end;
	
	/* All possible censor reasons based on dataset type */
	%if &censordataset. = t2followuptime %then %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_spec cens_event);
	%else %if &censordataset. = t5censor %then %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend cens_episend cens_spec);
	%else %let censorreason = %str(cens_elig cens_dth cens_dpend cens_qryend);
	
	/* If t2followuptime or t2censor and overall stratification is requested then censdays_value is required */
	%if &censordataset. ne t5censor and %str(&levels_overall) ne %str() %then %let distribution_var = censdays_value;
	%else %if &censordataset. = t5censor and %index(&censor_strat.,episodelength) > 0 %then %let distribution_var = episodelength;
	%else %let distribution_var = ;
	
 /*--------------------------------------------------------------------------------------------
    If T5Censor apply to the agg_t5censor data 
   --------------------------------------------------------------------------------------------*/  
   %if &censordataset. = t5censor %then %do;
      %convert_categories(var=episodelength, categories=&catvar.);
	  
      data agg_&censordataset.;
          set agg_&censordataset. (where=(level in (&levels. &levels_overall.)));
          *assign categories;
          length censdays_value_cat $50.;
          %do c =1 %to &num_categories.;
              if %scan(&categories_boolean., &c., ' ') then do;
                  censdays_value_cat = "%scan(&catvar., &c., ' ')";
                  censorcat_sort = &c.;
              end;
          %end;            
      run;
   %end;
 /*--------------------------------------------------------------------------------------------
 	Aggregate by censor reason and stratifications.
 	Stack aggregated with DP tables when stratification by DP is requested.                                                   
   --------------------------------------------------------------------------------------------*/  
   /* Aggregate data across all DPs */
   proc summary data = agg_&censordataset. (where=(level in (&levels. &levels_overall.))) nway missing;
   	 class runid group &censor_strat. level &distribution_var.;
   	 var episodes &censorreason.;
   	 output out = censor_all (drop = _:) sum=;
   run;
   
   %if &stratifybydp. = Y %then %do;
     /* Aggregate by DP */
     proc summary data = agg_&censordataset. (where=(level in (&levels. &levels_overall.))) nway missing;
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
	     else output censor_data; /* Data used for stratification statistics */
	   %end;
   run;
 
 /* Clean up work files */
   proc datasets lib=work nowarn nolist noprint;
     delete censor_all censor_dps; 
   quit;
   
 /*--------------------------------------------------------------------------------------------
 	Calculate summary statistics to merge back onto aggregate data                                                   
   --------------------------------------------------------------------------------------------*/
 	 %let cens_num_t3 = %sysfunc(countw(&censorreason_t3., %str( )));
 	 %let cens_num = %sysfunc(countw(&censorreason., %str( )));
	 
    /* Create a blank table if overall table not requested */
	%if %str(&distribution_var.) = %str() %then %do;
 	   proc sql noprint;
 	   	 create table unique_groups as
 	   	 select distinct dpidsiteid, group, runid
 	   	 from censor_data;
 	   quit;
 	   	   
 	   data _stats;
 	   	 set unique_groups;
 	   	 length table_name $12 min q1 median q3 max mean std 8;
 	   	 call missing(min, q1, median, q3, max, mean, std);
 	   	 table_name = "overall";
 	   	 output;
		 
	     %if &cens_num_t3. > 0 %then %do;
 	   	   %do cn= 1 %to &cens_num_t3;
 	   	      %let var = %scan(&censorreason_t3, &cn);
 	   	      table_name = "&var.";
 	   	      output;
 	   	   %end;
	     %end;
 	   run; 
	 %end;
		
   /* Calculate summary statistics for each censoring reason.
 	  Skip over censoring reasons without counts */ 
	 %if %str(&distribution_var.) ne %str() %then %do;
 	    %do sl = 1 %to %sysfunc(countw(episodes &censorreason_t3., %str( )));
 	    	%let cen_stat = %scan(episodes &censorreason_t3.,&sl.);
 	    	   proc sql noprint;
 	    	     select sum(&cen_stat.) into: checksum
 	    	     from censor_data_overall;
 	    	   quit;
 	    	   
 	    	 %if &checksum ^= 0 %then %do;
           
 	    	   proc means data= censor_data_overall nway missing noprint classdata=censor_data_overall;
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
 	    	      %if &cen_stat. = episodes %then %do;
 	    	        table_name = "overall";
 	    	      %end;
 	    	      %else %do;
 	    	        table_name = "&cen_stat.";
 	    	      %end;
 	    	   run;
 	    	 %end; /* checksum */
 		%end; /* censor reasons*/
		
		/* Stack all datasets together with one unique row per censor reason */
		data _stats;
 	      set _stats_:;
        run; 
		
 	 %end; /* overall levels */
	 
   /* Clean up work files */
      proc datasets lib=work nowarn nolist noprint;
        delete %if %str(&levels_overall) ne %str() %then %do;_stats_: %end; %else %do; unique_groups %end;; 
      quit;	
	  
   /* Calculate denominators and percentage totals by stratifiers, joining summary stats back to aggregate data */
      %do cl = 1 %to %sysfunc(countw(&tablesubs.,%str( )));
  	    proc sql noprint;
  	      create table den&cl. (drop = level) as
  	      select distinct b.* 
	                     ,a.epi_tot
  	      	             ,(b.episodes/a.epi_tot)   as epi_tot_pct         format=percent10.1
	   	                 %do cn= 1 %to &cens_num;
  	      	                %let var = %scan(&censorreason, &cn);
							,a.&var._tot
  	      	                ,(b.&var/a.epi_tot)     as &var._pct          format=percent10.1
  	      	                ,(b.&var/a.&var._tot)   as &var._reason_pct   format=percent10.1
  	      	             %end;
						 ,"&&tablesub&cl." as strat                       format = $8.
  	      from censor_data (where =(level = &&levels&cl.)) as b
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
  	      	           from censor_data (where =(level = &&levels&cl.)) a
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
	  %end;
    
      data censor_data_den;
        set den:;
      run;
	
    /* Clean up work files */
      proc datasets lib=work nowarn nolist noprint;
       delete den:; 
      quit;	
 	    
		data output.censor_data_den;
		set censor_data_den;
		run;
		
		data output.groupsfile;
		set groupsfile;
		run;
		
	  proc sql noprint;
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
	  
    /* Clean up work files */
       proc datasets lib=work nowarn nolist noprint;
        delete den:; 
       quit;
 
   /* For proc report, need to acquire censoring reason episodes in the "Episode" column as well as calculate denominators within each bin */
   	   data &censordataset. (drop=censdays_value_cat);
   	     set &censordataset.;
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
   	     %if %index(&tablesubs.,overall) > 0 %then %do;
   	       /*Dummy variable to use as 'across' variable to correctly place header*/
		   length dummy 3.;
   	       dummy = .;
   	     %end;
	     %if &cens_num_t3. > 0 %then %do;  
   	       %do cn = 1 %to &cens_num_t3.;
   	         %let var = %scan(&censorreason_t3., &cn);
   	         if table_name = "&var" then do;
   	         	  episodes = &var;
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
	   
	   
	 /*missing values T1, T2, T5*/
     %let is_e =0;
	 %let is_p =0;

     proc contents data=&censordataset. out=&censordataset._vars noprint;
	 quit;

	 proc sql noprint;
	   select count(*) into :is_e from &censordataset._vars where lowcase(name) = 'episodes';
	   select count(*) into :is_p from &censordataset._vars where lowcase(name) = 'patients';
	 quit;

     %let var_pe = ;
     %if &is_p> 0 %then %let var_pe = Patients;
     %if &is_e> 0 %then %let var_pe = &var_pe Episodes;
     %let stat_char = min q1 median q3 max mean std ;

     data &censordataset.;
       set &censordataset.;
       %do  cr = 1 %to %sysfunc(countw(&censorreason));
       /*Do not need to check if the variable exists on the dataset because only
         those created are listed*/
         %scan(&censorreason, &cr, ' ')_char = put(%scan(&censorreason, &cr, ' '), 8.);
         %scan(&censorreason, &cr, ' ')_pct_char = put(%scan(&censorreason, &cr, ' ')_pct, percent10.1);
 
		 %do st_c = 1 %to %sysfunc(countw(&stat_char));
           %scan(&stat_char, &st_c, ' ')_char = put(%scan(&stat_char, &st_c, ' '), 8.); 
		 %end;

       if
         %do pe = 1 %to %sysfunc(countw(&var_pe));
           %if &pe = 1 %then %do;
             %scan(&var_pe, &pe, ' ') = . 
	       %end;
	       %else %do;
	         and %scan(&var_pe, &pe, ' ') = . 
	       %end;
         %end;
         then do;
           %scan(&censorreason, &cr, ' ')_char = "NaN"; 
		   %scan(&censorreason, &cr, ' ')_pct_char = "NaN";
		   %do st_c = 1 %to %sysfunc(countw(&stat_char));
		     %scan(&stat_char, &st_c, ' ')_char = "NaN";
		   %end;
		   
       end;
       else if 
         %do pe = 1 %to %sysfunc(countw(&var_pe));
           %if &pe = 1 %then %do;
             %scan(&var_pe, &pe, ' ') = 0
	       %end;
	       %else %do;
	         or %scan(&var_pe, &pe, ' ') = 0 
	       %end; 
         %end;
         then do;
           %scan(&censorreason, &cr, ' ')_char = ".";
		   %scan(&censorreason, &cr, ' ')_pct_char = ".";
           %do st_c = 1 %to %sysfunc(countw(&stat_char));
		     %scan(&stat_char, &st_c, ' ')_char = ".";
		   %end; 
       end;
     %end;
   run;

   	   proc sort data=&censordataset. out = output.&censordataset.;
   	      by order dpidsiteid censorcat_sort table_name 
	  	%if %index(&censor_strat.,sex) > 0 %then %do; sex_sort %end; 
	  	%if %index(&censor_strat.,agegroup) > 0 %then %do; agegroupnum %end;
	  	%if %index(&censor_strat.,year) > 0 %then %do; year %end;;
   	   run;
 
   /* Clean up work files */
    proc datasets lib=work nowarn nolist noprint;
       delete _stats censor_data:; 
    quit;

   %put =====> END MACRO: censortable_createdata;
%mend censortable_createdata;
