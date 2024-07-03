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
*   - agg_t4preggestwk.sas7bdat   
*   - agg_t4nopreggestwk.sas7bdat 
*
*  Program outputs:                                                                                                                           
*   - final_t4moi - levelid and moiname stratification across data partners
*   - final_dps_t4moi - levelid and moiname stratification by data partner
*   - final_t4gestwk - moiname and gestwk stratification across data partners
*   - final_dps_t4gestwk - moiname and gestwk stratification by data partner
* 
*  PARAMETERS: 
*   - dataset = suffix for input dataset indicator
*   - output_suffix = suffix for output dataset name
*   - episode_var: variable that holds # of pregnancy episodes
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

%macro t4tables_createdata(dataset = , output_suffix = , episode_var = );

    %put =====> MACRO CALLED: t4tables_createdata ;

   /*********************************************************************************************************
      Determine total count of variables on table and put tablecolumns information into macro variables
        - For tables T1-T4, there is a 1:1 relationship between rows in TABLECOLUMNS and columns in the table 
        - For tables T5-T6, TABLECOLUMNS only contains 3 possible columns, this table will be expanded for 
          each gestational week after table information is assigned to macro variables
    ********************************************************************************************************/
	proc sql noprint;
	  select distinct(compress(table)) into: tables separated by '" "'
      from tablefile where dataset in ("t4&dataset." "t4no&dataset.");
	  
	  select count(column) into: numcolumns trimmed
	  from tablecolumns where table in ("&tables.");
	  
	  select columnname 
	        ,column 
			,columnlabel
			,columnformat
			,scan(compress(column,'()'),1,'/') as numerator
			,case when index(column,'/') = 0 then ''
			   when index(column,'*')  > 0 then cats("den_",scan(compress(scan(column,1,'*'),'()'),2,'/')) 
			   else cats("den_",scan(column,2,'/')) end as denominator
			,case when index(columnformat,'$') > 0 then columnformat
			   else compress('$'||put(input(scan(compress(columnformat,'','a'),1,'.'),3.) +  input(scan(compress(columnformat,'','a'),2,'.'),3.),8.)||".") end as columnformatchar
	   into: var1 -:var&numcolumns.
		    ,:formula1 - :formula&numcolumns.
			,:label1 - :label&numcolumns.
			,:format1 - :format&numcolumns.
			,:num1 - :num&numcolumns.
			,:denominator1 - :denominator&numcolumns.
			,:formatchar1 - :formatchar&numcolumns.
	  from tablecolumns where table in ("&tables.");
	  
	  select distinct(a.numerator)
	         into: sumcolumns separated by " "
	        from (select case when index(column,'/') > 0 then scan(compress(column,'()'),1,'/')
                   else column end as numerator from tablecolumns where table in ("&tables.")) a;
    quit;

    /*Expand table to 1 row per gestional week*/
    %if &dataset. = preggestwk %then %do;

	    /* Identify min gestwk requested. Max 43 weeks if postpregdays is not positive */
        data master_typefile;
            set master_typefile;
            length gestwk_min gestwk_max 3;
            if prepregdays >0 then gestwk_min = int((-prepregdays/7)-1); 
            else gestwk_min = 0; 
			if postpregdays >0 then gestwk_max = 43 + int(((postpregdays-1)/7)+1); 
		    else gestwk_max = 43;
        run;

        proc sql noprint;
		    select min(a.gestwk_min), max(a.gestwk_max) into: min_min, :max_max
            from master_typefile a,
                 groupsfile b
            where a.group = b.group;
        quit;

        data _temptablecolumns;
            set tablecolumns(where=(table in ('T5', 'T6')) rename=columnname=origcolumnname);
            spanningheader = columnlabel;
            /*negative weeks*/
            %if %eval(&min_min<0) %then %do;
            do i = 1 to %sysfunc(abs(&min_min.)) ;
			    if i ne 0 then do;
                length columnname $32;
                /*change columnname to gestwk#column#*/
                columnname = cats('gestwkneg', i, origcolumnname);
                /*change columnlabel/columnheader (T6) to gestational week*/
                columnlabel = strip(cats('-',strip(put(i, best.))));
                if table = 'T6' then columnheader = strip(cats('-',strip(put(i, best.))));
                gestwkorder = i*-1;
                output;
				end;
            end;
            drop i;
            %end;
            
            /*Positive weeks*/
            do gestwkorder = 0 to &max_max.;
                
                /*change columnname to gestwk#column#*/
                columnname = cats('gestwk', gestwkorder, origcolumnname);
                /*change columnlabel/columnheader (T6) to gestational week*/
                columnlabel = strip(put(gestwkorder, best.));
				if gestwkorder > 43 then do;
					*columnlabel = strip(cats("(*ESC*){unicode '002B'x}",put(gestwkorder-43, best.)));
					columnlabel = strip(cats("+",put(gestwkorder-43, best.)));
					columnname = cats('gestwkpos', gestwkorder-43, origcolumnname);
				end;
                if table = 'T6' then do;
					columnheader = strip(put(gestwkorder, best.));
					if gestwkorder > 43 then columnheader = strip(cats("+",put(gestwkorder-43, best.)));
				end;
                output;
            end;
			
        run;

        data tablecolumns;
            set tablecolumns(where=(table not in ('T5', 'T6')))
                _temptablecolumns;
        run;
    %end;

   /************************************************************************************************
     Identify substrat tables requested     
    ************************************************************************************************/
	 proc sql noprint;
	    select count(distinct tablesubstrat) into: numdset trimmed
		from tablefile where dataset in ("t4&dataset." "t4no&dataset.");
		
		select distinct tablesubstrat 
		   into: substrat1 - :substrat&numdset.
	    from tablefile where dataset in ("t4&dataset." "t4no&dataset.");
	 quit;

    /************************************************************************************************
      Assign default value for list of groups that assign pre pregnancy periods   
    ************************************************************************************************/
     %let prepreggrouplist =''; 
	 
	/************************************************************************************************
      Code specific for t4pregnancy and t4nopregnancy
	  - Identify levels 1 and 2 for preg and nopreg
	  - Calculate denominator episodes and denominator episodes in trimester 3
	  - Summarize data by group moiname and pregnancy flag for the identified level ids
     ************************************************************************************************/	
	 %if &dataset. = preg %then %do;
	
      /************************************************************************************************
        Determine levels
       ************************************************************************************************/	 
	    %let t4preglevel1 =;
	    %let t4preglevel2 =;
	    %let t4nopreglevel1 =;
	    %let t4nopreglevel2 =;
	    
	    %do ds = 1 %to &numdset.;
	      proc sql noprint;
             select distinct quote(levelid1), quote(levelid2) 
             into :&&&substrat&ds..level1,
                  :&&&substrat&ds..level2
             from tablefile where dataset = "&&substrat&ds.";
	      quit;
	    %end;
	  
     /************************************************************************************************
       Determine denominators for percent calculations          
      ************************************************************************************************/
        %macro t4_preg_nopreg (dsin = );	
	       proc sql noprint undo_policy=none;
	          create table _&dsin as 
                  select b.*
	              ,a.&episode_var. as den_&episode_var.
				  ,a.&episode_var._2trim as den_&episode_var._2trim
	              ,a.&episode_var._3trim as den_&episode_var._3trim
                  from agg_t4&dsin (keep = &episode_var. &episode_var._2trim &episode_var._3trim level group dpidsiteid 
	    		                    where=(level in (&&t4&dsin.level1))) as a,
                       agg_t4&dsin (where=(level in (&&t4&dsin.level2))) as b
                  where a.group=b.group 
	              and a.dpidsiteid = b.dpidsiteid;
           quit;
        %mend t4_preg_nopreg;
	    %if %sysfunc(findw(&datasetlist.,t4preg)) > 0 %then %do;
	      %t4_preg_nopreg(dsin = preg);
	    %end;
	    %if %sysfunc(findw(&datasetlist.,t4nopreg)) > 0 %then %do;
	       %t4_preg_nopreg(dsin = nopreg);
	    %end;
	  
     /************************************************************************************************
       Set preg and nopreg data together when requested for desired levels            
      ************************************************************************************************/
	     data _agg_t4moi;
	       length moiname $5;
	       set %if %sysfunc(findw(&datasetlist.,t4preg)) > 0 %then %do;
	             _preg (in = t4preg keep= dpidsiteid group moiname &sumcolumns &episode_var. &episode_var._2trim &episode_var._3trim den_:)
	    	   %end;
	    	   %if %sysfunc(findw(&datasetlist.,t4nopreg)) > 0 %then %do;
	    	     _nopreg (in = t4nopreg keep= dpidsiteid group moiname &sumcolumns &episode_var. &episode_var._2trim &episode_var._3trim den_:)
	    	   %end;;
	       if t4preg then pregflg = "Y";
	       else pregflg = "N";
	     run;
	  
     /************************************************************************************************
       List of groups with a defined pre-pregnancy period          
      ************************************************************************************************/
        %if %index(&sumcolumns., pre)>0 %then %do;
            proc sql noprint;
                select distinct "'"||group||"'" into: prepreggrouplist separated by ','
                from master_typefile
                where prepregdays >0;
            quit;
			%if %str("&prepreggrouplist") = %str("") %then %let prepreggrouplist = '';
        %end;
	  
     /************************************************************************************************
       Summarize Data     
      ************************************************************************************************/	
	    proc summary data = _agg_t4moi nway missing;
	      class group moiname pregflg;
	      var &sumcolumns. &episode_var. &episode_var._2trim &episode_var._3trim den_&episode_var. den_&episode_var._2trim den_&episode_var._3trim;
	      output out = _agg_t4moi_summ (drop = _:) sum=;
	    run;
	
	  %end; /* T4preg and T4nopreg specific code */

	/************************************************************************************************
      Summarize preg and nopreg data by group moiname pregflg and gestational week
	   - Gestational week data is in a different format than pregnancy data and requires separate processing
     ************************************************************************************************/	
	  %else %do;
	    data _agg_t4moi (keep = group moiname gestwk pregflg dpidsiteid den_&episode_var. &sumcolumns. pregflg gestwk_char);
	      length pregflg $1 gestwk_char $15;
	      set %if %sysfunc(findw(&datasetlist.,t4preggestwk)) %then %do;
	  	      agg_t4preggestwk (in = preg)
	  		%end;
	  		%if %sysfunc(findw(&datasetlist.,t4nopreggestwk)) %then %do;
	  	      agg_t4nopreggestwk (in = nopreg)
	  		%end;;
	  	if index(gestwk,"-") > 0 then gestwk_char = catt("gestwkneg", compress(gestwk,"-"));
          else gestwk_char = catt("gestwk",tranwrd(gestwk,"+","pos"));
	  	if preg then pregflg = "Y";
	      else pregflg = "N";
	  	den_&episode_var. = &episode_var.;
		if index(gestwk,"+") > 0 then gestwk_num = 43 + input(compress(gestwk,"+"),3.);
		else gestwk_num = input(gestwk,3.);
		if not (&min_min. <= gestwk_num <= &max_max.) then delete; /* remove gestational weeks not requested in the type4 file */
	    run;	
	
	    proc summary data = _agg_t4moi nway missing;
          class group moiname pregflg gestwk_char;
          var &sumcolumns. den_&episode_var.;
          output out = _agg_t4moi_summ (drop = _:) sum=;
        run;
	
		%if &stratifybydp. = Y %then %do;
			proc summary data = _agg_t4moi nway missing;
	        class dpidsiteid group moiname pregflg gestwk_char;
	        var &sumcolumns. den_&episode_var.;
	        output out = _agg_t4moi_dp (drop = _:) sum=;
	        run;
		%end;

		/*Determine the minimum gestional week for each group and assign to a macro variable*/
        proc sql noprint undo_policy=none;
           select distinct group into: group_list separated by ' '
           from _agg_t4moi;
        quit;

        data _null_;
          set master_typefile;
          %do g = 1 %to %sysfunc(countw(&group_list));
              if group = "%scan(&group_list, &g)" then do;
				call symputx("gestwk_min_group&g.", gestwk_min);
				call symputx("gestwk_max_group&g.", gestwk_max);
			  end;
          %end;
        run;
	  %end;
	
   /************************************************************************************************
     Identify columns requested and apply labels and formats          
    ************************************************************************************************/ 
    %macro prep_t4tables (dsin =, dsout =, dpvar = );
	
    	/* Join t4pregenrdays to dataset to be utilized as a condition for formatting */
    	proc sql noprint undo_policy=none;
    		create table &dsin as 
    		select a.* , b.t4pregenrdays, c.prepregdays, c.postpregdays
    		from &dsin a 
    		left join master_cohortfile b 
    		on a.group = b.cohortgrp
    		left join master_typefile c 
    		on a.group = c.group 
    		%if &dataset = preggestwk %then %do;
    		order by %if %length(&dpvar) %then %do; &dpvar, %end; group, moiname, pregflg ,gestwk_char
    		%end;
    		;
    		select distinct group into: cohort_list separated by ' ' from &dsin;
    	quit;

	   data &dsin. (keep = &dpvar. group moiname column: pregflg den_&episode_var. %if &dataset. = preggestwk %then %do; gestwk_char den_episodes_wk0 %end; %else %do; den_&episode_var._2trim den_&episode_var._3trim %end;);
	     set &dsin.;
		 /* Identify the total number of episodes at week 0 for gestational data. This is the max number of episodes in a cohort. */
		 %if &dataset. = preggestwk %then %do;
		   by &dpvar. group moiname pregflg gestwk_char;
		   retain den_episodes_wk0;
		   if first.pregflg and gestwk_char = "gestwk0" then den_episodes_wk0 = den_pregepisodes;
		 %end;
		 
		 %do vv = 1 %to &numcolumns;
		    label &&var&vv.. = "&&label&vv..";
			label &&var&vv.._char = "&&label&vv..";
			format &&var&vv.._char &&formatchar&vv..;
			
			%if %index(&&formula&vv.,/) > 0 %then %do;
               if &&num&vv. = . then &&num&vv. = 0;
			   if &&denominator&vv. <=0 then do;
			     &&var&vv. = .;
			   end;
			   else do;
			     &&var&vv. = &&num&vv./&&denominator&vv.;
			   end;
               &&var&vv.._char = strip(put(&&var&vv., &&format&vv..));
			%end;
			%else %do;
              if &&formula&vv. = . then &&formula&vv. = 0;
		      &&var&vv. = &&formula&vv.;
		      &&var&vv.._char = strip(put(&&var&vv., &&format&vv..));
			%end;
            
            /*standard missing value indicators*/
            /*if 0 patients in cohort, set to '.'*/
            if %if &dataset. = preg %then %do; den_&episode_var. <=0 %end; %else %do; den_episodes_wk0 <=0 %end; then do;
                &&var&vv. = .;
                &&var&vv.._char = '.';
            end;
            else do;
                /*if pre-pregnancy period not evaluated, set to 'N/A'*/
                %if %index(&&formula&vv.,pre)>0 and &dataset. = preg %then %do;
                    if group not in (&prepreggrouplist) then do;
                        &&var&vv.._char = 'N/A';
                        &&var&vv. = .;
                    end;
                %end;
                /* check each group and the pregnancy enrollment value value - set to N/A based on enrollment value */
                	%do i = 1 %to %sysfunc(countw(&cohort_list));
                		%let t4group = %scan(&cohort_list,&i);
                			%if &dataset = preg %then %do;
		                		%if %sysfunc(prxmatch(m/usepre|sumrawcntpre|sumadjcntpre/i,&&formula&vv.)) %then %do; 
		                			if lowcase(group) = "&t4group" and (-1*prepregdays) < t4pregenrdays <= 0 then do;
		                		   	&&var&vv.._char = 'N/A';
			                        &&var&vv. = .;
			                        &&var&vv.._ss=1;
			                    	end;
			                    %end;
		                		%if %sysfunc(prxmatch(m/usepre|sumrawcntpre|sumadjcntpre|anyt\b|anyt\/episodes\b|allt|anyt1|onlyt1|sumrawcntanyt1|sumadjcntanyt1|sumrawcntonlyt1|sumadjcntonlyt1/i,&&formula&vv.)) %then %do;
		                		    if lowcase(group) = "&t4group" and 0 < t4pregenrdays <= 97 then do; 
		                		    &&var&vv.._char = 'N/A';
			                        &&var&vv. = .;
			                        &&var&vv.._ss=1;
			                    	end;
		                		%end;
		                		%if %sysfunc(prxmatch(m/usepre|sumrawcntpre|sumadjcntpre|anyt\b|anyt\/episodes\b|allt|anyt1|onlyt1|anyt2|onlyt2|sumrawcntanyt1|sumadjcntanyt1|sumrawcntanyt2|sumadjcntanyt2|sumrawcntonlyt2|sumadjcntonlyt2/i,&&formula&vv.)) %then %do;
		                			if lowcase(group) = "&t4group" and 97 < t4pregenrdays <= 195 then do; 
		                		    &&var&vv.._char = 'N/A';
			                        &&var&vv. = .;
			                        &&var&vv.._ss=1;
			                        end;
			                    %end;
			                    %if %sysfunc(prxmatch(m/usepre|sumrawcntpre|sumadjcntpre|anyt\b|anyt\/episodes\b|allt|anyt1|onlyt1|anyt2|onlyt2|anyt3|onlyt3|sumrawcntanyt1|sumadjcntanyt1|sumrawcntonlyt1|sumadjcntonlyt1|sumrawcntonlyt2|sumadjcntonlyt2|sumrawcntanyt2|sumadjcntanyt2|sumrawcntonly3|sumadjcntonlyt3|sumrawcntanyt3|sumadjcntanyt3/i,&&formula&vv.)) %then %do;
		                			if lowcase(group) = "&t4group" and t4pregenrdays > 195 then do;   
			                        &&var&vv.._char = 'N/A';
			                        &&var&vv. = .;
			                        &&var&vv.._ss=1;
			                    	end;
		                    	%end;
		                    %end;
		                    %if &dataset = preggestwk %then %do;
		                        %if %sysfunc(prxmatch(m/moi/i,&&formula&vv.)) %then %do; 
								/* t4pregenrdays check is not required if gestwk is after the pregnancy outcome */
								if index(gestwk_char, "gestwkpos") = 0 then do;
			                        if lowcase(group) = "&t4group" then do; 
										gestwk = input(compress(gestwk_char, "gestwkneg"),best.);
			                        	if t4pregenrdays < 0 and abs(int(t4pregenrdays/7)) < abs(gestwk) and gestwk < 0 then do;
			                        		&&var&vv.._char = 'N/A';
			                        		&&var&vv. = .;
			                        		&&var&vv.._ss=1;
				                        end;
			                        	else if t4pregenrdays >= 0 and int(t4pregenrdays/7) >= gestwk +1 then do;
			                        		&&var&vv.._char = 'N/A';
			                        		&&var&vv. = .;
			                        		&&var&vv.._ss=1;
			                        	end;
			                        end;
								end;
								/* Check postpregdays coverage */
								else do;
									if lowcase(group) = "&t4group" then do; 
										gestwk = input(compress(gestwk_char, "gestwkpos"),best.);
									    if postpregdays <= 0 then do;
									        &&var&vv.._char = 'N/A';
									        &&var&vv. = .;
									        &&var&vv.._ss=1;
									    end;
									    else if postpregdays > 0 and (int(postpregdays/7)+1) < gestwk then do;
									        &&var&vv.._char = 'N/A';
									        &&var&vv. = .;
									        &&var&vv.._ss=1;
									    end;
									end;
								end;
		                        %end;
		                    %end;
		                    if lowcase(group) = "&t4group" and missing(t4pregenrdays) then do;
		                    		&&var&vv.._char = 'N/A';
		                        	&&var&vv. = .;
		                        	&&var&vv.._ss=1;
		                    end;
	                %end;
                /*if 0 episodes in 2nd/3rd trimester for preg/nopreg data or 0 episodes per week for gestational week data, % cannot be computed*/
                %if &&denominator&vv. = den_&episode_var._2trim | &&denominator&vv. = den_&episode_var._3trim | &&denominator&vv. = den_pregepisodes %then %do;
                    if &&denominator&vv. <=0 then &&var&vv.._char = 'NaN';
                %end;
            end;
	     %end;
	   run;

        /* transpose Data for gestwk from a long dataset (1 row per week) to a wide dataset (1 column per week) */
        %if &dataset. = preggestwk %then %do;
            /*Transpose both numeric and character vars*/
    		%do va = 1 %to &numcolumns; 
                proc transpose data = &dsin suffix = &&var&va.. out = &dsin._tran_&va.  (drop =_name_ _label_);
                   by &dpvar. group moiname pregflg den_episodes_wk0;
                   id gestwk_char;
                   var &&var&va..;
                run;
				
                proc transpose data = &dsin suffix = &&var&va.._char out = &dsin._tran_&va._char  (drop =_name_ _label_);
                   by &dpvar. group moiname pregflg den_episodes_wk0;
                   id gestwk_char;
                   var &&var&va.._char;
                run;

                proc transpose data = &dsin suffix = &&var&va.._ss out = &dsin._tran_&va._ss  (drop =_name_);
                   by &dpvar. group moiname pregflg den_episodes_wk0;
                   id gestwk_char;
                   var &&var&va.._ss;
                run;
				
            %end;
		 
		   /* Merge data for all columns */
		   data &dsin.;
             merge &dsin._tran_:;
		     by &dpvar. group moiname pregflg den_episodes_wk0;			 
			 %do g = 1 %to %sysfunc(countw(&group_list));  
			   /* set pre-pregnancy period to N/A for weeks that are less than the minimum gestational week per group */
			   %if &min_min. < &&&gestwk_min_group&g. %then %do;
			     if group = "%scan(&group_list., &g.)" then do;
			       %do min_loop = &min_min. %to &&&gestwk_min_group&g. -1;
                      %do vv = 1 %to &numcolumns; 
				  	    if den_episodes_wk0 > 0 then do;
                          gestwkneg%sysfunc(abs(&min_loop.))&&var&vv.._char = 'N/A';
                        end;
                        else do;
                          gestwkneg%sysfunc(abs(&min_loop.))&&var&vv.._char = '.';
                        end;
                      %end;
                   %end;
			     end;
			   %end;
			   /* set post-pregnancy period to N/A for weeks that are more than the maximum gestational week per group */
			   %if &&&gestwk_max_group&g. < &max_max. %then %do;
			     if group = "%scan(&group_list., &g.)" then do;				   
			       %do max_loop = &&&gestwk_max_group&g. - 42 %to &max_max. - 43;
                      %do vv = 1 %to &numcolumns; 
				  	    if den_episodes_wk0 > 0 then do;
                          gestwkpos%sysfunc(abs(&max_loop.))&&var&vv.._char = 'N/A';
                        end;
                        else do;
                          gestwkpos%sysfunc(abs(&max_loop.))&&var&vv.._char = '.';
                        end;
                      %end;
                   %end;
			     end;
			   %end;
			 %end;
           run;
        %end; /*gestational week table transpose*/
		
	   	/* Check if columns related to 2nd/3rd trimesters are requested */	    
		%let T2Columns=N;
		%let T3Columns=N;
		%if %index(%upcase(&sumcolumns.), ANYT2) | %index(%upcase(&sumcolumns.), ONLYT2) %then %let T2Columns=Y;
		%if %index(%upcase(&sumcolumns.), ANYT3) | %index(%upcase(&sumcolumns.), ONLYT3) %then %let T3Columns=Y;

	   /* Apply labels */
       proc sql noprint;
         create table &dsout. as
		 select all.*
         from(select a.*, b.order
		 %if &labelfileexists. = Y %then %do;
		 	,case %if &includeheaderrow = Y %then %do; when c.label = "" and d.label = "" then strip(a.group) %end;
			%if &dataset. = preg %then %do;
		 	        when c.label = "" then catx(' ',strip(a.group),"(" || %if &T2Columns. eq Y %then %do;strip(put(a.den_&episode_var._2trim,comma12.0))||" episodes reach the 2nd trimester, " || %end; %if &T3Columns. eq Y %then %do;strip(put(a.den_&episode_var._3trim,comma12.0))||" episodes reach the 3rd trimester, " || %end;strip(put(a.den_&episode_var.,comma12.0))||" total episodes)")
		 	   else catx(' ',strip(c.label),"(" || %if &T2Columns. eq Y %then %do;strip(put(a.den_&episode_var._2trim,comma12.0))||" episodes reach the 2nd trimester, " || %end; %if &T3Columns. eq Y %then %do;strip(put(a.den_&episode_var._3trim,comma12.0))||" episodes reach the 3rd trimester, " || %end;strip(put(a.den_&episode_var.,comma12.0))||" total episodes)") end as grouplabel 
		 	  ,case when d.label = "" then catx(' ',coalescec(c.label, a.group),strip(a.group),"(" || %if &T2Columns. eq Y %then %do;strip(put(a.den_&episode_var._2trim,comma12.0))||" episodes reach the 2nd trimester, " || %end; %if &T3Columns. eq Y %then %do;strip(put(a.den_&episode_var._3trim,comma12.0))||" episodes reach the 3rd trimester, " || %end;strip(put(a.den_&episode_var.,comma12.0))||" total episodes)")
			%end;
			%else %do;
			       when c.label = "" then strip(a.group)
		 	   else strip(c.label) end as grouplabel 
		 	  ,case when d.label = "" then coalescec(c.label, a.group)
			%end;
             else d.label end as header
            ,case when e.label = "" then a.moiname
             else e.label end as moilabel 
		       	,case when f.label = "" then a.moiname
             else f.label end as moiheader 
		 %end;
         %else %do;
		    %if &dataset. = preg %then %do;
		      ,catx(' ',strip(a.group),"(" || %if &T2Columns. eq Y %then %do;strip(put(a.den_&episode_var._2trim,comma12.0))||" episodes reach the 2nd trimester, " || %end; %if &T3Columns. eq Y %then %do;strip(put(a.den_&episode_var._3trim,comma12.0))||" episodes reach the 3rd trimester, " || %end;strip(put(a.den_&episode_var.,comma12.0))||" total episodes)") as grouplabel  
			%end;
			%else %do;
			  ,strip(a.group) as grouplabel
			%end;
            ,a.moiname as moilabel
            ,"" as moiheader 
         %end;				   
             from &dsin. a 
		      left join groupsfile b
		      on strip(lowcase(a.group)) = strip(lowcase(b.group))
		      %if &labelfileexists. = Y %then %do;
		        left join labelfile (where = (labeltype = "grouplabel")) c
		        on strip(a.group) = strip(c.group)
		        left join labelfile (where = (labeltype = "header")) d
		        on strip(a.group) = strip(d.group)
		     	left join labelfile (where = (labeltype = "moilabel")) e
		     	on strip(a.group) = strip(e.group)
		     	 and lowcase(a.moiname) = strip(e.labelvar)
		     	left join labelfile (where = (labeltype = "moiheader")) f
		     	on strip(a.group) = strip(f.group)
		     	 and lowcase(a.moiname) = strip(f.labelvar)
		      %end;) all;
        quit;
		
		proc sort data = &dsout. sortseq=linguistic(numeric_collation=on);
		  by descending pregflg order moiname;
		run;
    %mend;

	/*Overall*/
    %prep_t4tables (dsin=_agg_t4moi_summ, dsout=final&output_suffix.);

	/*By Data Partner*/
    %if &stratifybydp. = Y %then %do;
	  %prep_t4tables(dsin=%if &dataset. = preg %then %do; _agg_t4moi %end; %else %do; _agg_t4moi_dp %end;, dsout=final_dps&output_suffix., dpvar=dpidsiteid);
	%end;
	
	/*Clean up*/
    proc datasets nowarn noprint lib=work;
      delete _:;
    quit;

    %put =====> END MACRO: t4tables_createdata ;

%mend t4tables_createdata;
