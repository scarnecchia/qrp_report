****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t5tables_createdata.sas  
* Created (mm/dd/yyyy): 08/06/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro produces tables for a Type 5 report
*                                        
*  Program inputs:                                                                                   
*   - agg_t5episdur.sas7bdat                                               
*   - agg_t5disp.sas7bdat
*   - agg_t5dose.sas7bdat
*
*  Program outputs:                                                                                                                           
*   - 1 dataset per table in the format [TableID]_[StratificationOrder]
* 
*  PARAMETERS: 
*   - dataset: aggregate dataset from %aggregate_report_tables
*   - whereclause: where clause to restrict input dataset
*   - catvar: variable that will be categorized
*   - countvar: metric counting counts
*   - cattableid: category table ID from TABLEFILE
*   - disttableid: distribution table ID from TABLEFILE
*   - catvarsort: variable on the input dataset containing category indicators
*   - createfootnote: Y/N indicator to create group-specific footnote table (for dose tables)
*   - dosevar: name of variable containing statistic names for dosing tables continuous metrics
*   - totalcountdosevar: name of variable containing counts for dosing tables continuous metrics
* 
*  Programming Notes:                                                                                
*  - Censor tables are computed in a separate macro (censortable_createdata.sas)   
*  - 'overall' stratification is required for any additional stratification 
*  - if CATVARSORT is specified, categories have already been computed in QRP, otherwise categories
*    must be specified in the TABLEFILE for category tables
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro t5tables_createdata(dataset=,
                           whereclause=,
                           catvar=,
                           countvar=,
                           cattableid=,
                           disttableid=,
                           catvarsort=,
                           createfootnote=,
						   dosevar=,
						   totalcountdosevar=);

    %put =====> MACRO CALLED: t5tables_createdata ;
	
    /*--------------------------------------------------------------------------------------------*/
    /* Determine all levelIDs and stratifications requested                                       */
    /*--------------------------------------------------------------------------------------------*/
    %let tablesub = ;
    %let tablesublist = ;

	/*Set &cattableid and &disttableid to missing if not requested*/
	%let table = "&cattableid.","&disttableid.";

	data _tablecheck&cattableid.
		 _tablecheck&disttableid.;
		 set tablefile(where=(table in (&table.)));
		 
		 if table = "&cattableid" then output _tablecheck&cattableid.;
		 if table = "&disttableid" then output _tablecheck&disttableid.;
	run;

	%isdata(dataset=_tablecheck&cattableid.);
	%if %eval(&nobs.<1) %then %do;
		%let cattableid = ;
	%end;
	%isdata(dataset=_tablecheck&disttableid.);
	%if %eval(&nobs.<1) %then %do;
		%let disttableid = ;
	%end;

	proc datasets nowarn noprint lib=work;
    delete _tablecheck:;
	quit;

    data tablefile;
	set tablefile;
	if tablesub = 'overall' then order_overall=0; else order_overall=1;
	run;

    proc sql noprint;
        select distinct quote(levelid1), quote(levelid2) 
        into :levellist1 separated by ',',
             :levellist2 separated by ','
        from tablefile
        where table in (%if %str("&cattableid.") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("&disttableid.") ne %str("") %then %do; "&disttableid" %end;);
        /*stratification variable list*/
        select distinct tablesub
        into :tablesub separated by ' '
        from tablefile
        where table in (%if %str("&cattableid.") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("disttableid") ne %str("") %then %do; "&disttableid" %end;)
              and tablesub ne 'overall';
        /*stratifications to compute*/
        select distinct tablesub, order_overall
        into :tablesublist separated by '|', :stratorderlist
        from tablefile
        where table in (%if %str("&cattableid.") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("disttableid") ne %str("") %then %do; "&disttableid" %end;)
        order by order_overall;
    quit;
 
    /*dedup stratvars list*/
    %if %str("&tablesub") ne %str("") %then %do;
        %nonrep(invar=tablesub, outvar=stratvars);
        /*add agegroupnum*/
        %if %index(&stratvars., agegroup)>0 and %index(&stratvars., agegroupnum)=0 %then %do;
            %let stratvars = &stratvars. agegroupnum;
        %end;
    %end;
    %else %do;
        %let stratvars = ;
    %end;

    /*--------------------------------------------------------------------------------------------*/
    /* Aggregate data                                                                             */
    /*--------------------------------------------------------------------------------------------*/

    proc means data=&dataset.(where=(&whereclause. and level in (&levellist1. &levellist2.))) noprint nway;
		var &countvar.;
		class runid group level &stratvars. &catvar. &catvarsort. / missing;
		output out=_t5data_summed(drop=_:) sum=;
	run;

    %if &stratifybydp. = Y %then %do;
    proc means data=&dataset.(where=(&whereclause. and level in (&levellist1. &levellist2.))) noprint nway;
		var &countvar.;
		class runid group dpidsiteid level &stratvars. &catvar. &catvarsort. / missing;
		output out=_t5data_summed_dp(drop=_:) sum=;
	run;
    %end;

    data _t5data_summed;
        set _t5data_summed(in=a)
            %if &stratifybydp. = Y %then %do;
            _t5data_summed_dp
            %end; ;
        length dpidsiteid $6.;
        if a then dpidsiteid = 'all';
    run;

    /*----------------------------------------------------------------------------------------------*/
    /* Compute overall (required - already checked in process_inputfiles  and stratification metrics */
    /*----------------------------------------------------------------------------------------------*/

    /*Loop through each tablesub*/
    %do s = 1 %to %sysfunc(countw(&tablesublist., '|'));
        %let tablesub = %scan(&tablesublist., &s., '|');

        %let cattablestratorder =0 ;
        %let disttablestratorder =0 ;

        data _null_;
            set tablefile(where=(table in (%if %str("&cattableid.") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("&disttableid.") ne %str("") %then %do; "&disttableid" %end;) and tablesub = "&tablesub."));
            if _n_ = 1 then do; /*levelid1 and levelid2 same for both tables*/
            	call symputx('levelid1', levelid1);
            	call symputx('levelid2', levelid2);
				call symputx('levelid3', levelid3);
            end;
            if table = "&cattableid" then do;
                call symputx('categories', categories);
                call symputx('cattablestratorder', stratificationorder);
            end;
            if table = "&disttableid" then do;
                call symputx('disttablestratorder', stratificationorder);
            end;
        run;

        /*if overall: reset tablesub*/
        /*if agegroup stratification: add agegroupnum to list of vars*/
        /*if stratified table, restrict to aggregate data*/
        %if &tablesub = overall %then %do;
            %let tablesub = ;
            %let dpwhere = ;
        %end;
        %else %do;
            %if %index(&tablesub., agegroup)>0 %then %let tablesub = &tablesub. agegroupnum;
            %let dpwhere = and dpidsiteid = 'all';
        %end;  
 

    	/*Extract column 1: Total*/
    	proc sort data=_t5data_summed out=_total_bydp(rename=&countvar.=total_count keep=dpidsiteid runid group &tablesub. &countvar.);
    		by dpidsiteid runid group &tablesub. &countvar.;
            where level = "&levelid1." &dpwhere.;
    	run;

        /*Group continous var into categories*/
		%if %eval(&cattablestratorder>0) %then %do;

            /*Group continuous variable into categories*/
            %if %str("&catvarsort.") = %str("") %then %do;
            %convert_categories(var=&catvar., categories=&categories.);

    		data _catdata;
    			set _t5data_summed(where=(level in ("&levelid2.") &dpwhere.));

    			*assign categories;
    			length category $50.;
    			%do c =1 %to &num_categories.;
    				if %scan(&categories_boolean., &c., ' ') then do;
    					category = "%scan(&categories., &c., ' ')";
    					categorysort = &c.;
    				end;
    			%end;
    			if categorysort = . then delete;			
    		run;

    		*collapse across categories;
    		proc means noprint nway data=_catdata;
    			var &countvar.;
    			class dpidsiteid runid group &tablesub. category categorysort / missing;
    			output out=_distribution_cat_&disttablestratorder.(drop=_:) sum=;
    		run;

            *assign labels;
            %do c =1 %to &num_categories.;
                %let lbl&c. = %scan(&categories., &c., ' ') days;
    		%end;

            %end;
            %else %do;
                /*Cateogries already defined in QRP*/
                proc means noprint nway data=_t5data_summed(rename=&catvarsort.=categorysort where=(level in ("&levelid2.") and missing(&catvar.)=0 &dpwhere.));
        			var &countvar.;
        			class dpidsiteid runid group &tablesub. categorysort / missing;
        			output out=_distribution_cat_&disttablestratorder.(drop=_:) sum=;
        		run;

                %let num_categories = 0;
                proc sql noprint;
                    select max(categorysort) into: num_categories
                    from _distribution_cat_&disttablestratorder.;
                quit;

                *assign labels;
                %do c =1 %to &num_categories.;
                    %let lbl&c. = Dose Group &c.;
            	%end;
                *if labelfile exists and custom labels specified - assign those;
                %if &labelfileexists = Y %then %do;
                    %let labeltype = ;
                    %if &catvar = cfdd_output_cat %then %let labeltype = cfddcatlabel;
                    %if &catvar = afdd_output_cat %then %let labeltype = afddcatlabel;
                    %if &catvar = cumdose_output_cat %then %let labeltype = cumdosecatlabel;
                    data _null_;
                        set labelfile(where=(labeltype="&labeltype."));
                        %do c = 1 %to &num_categories.;
                            if labelvar = "dosecat&c" then call symputx("lbl&c.", label);
                        %end;
                    run;
                %end;
            %end;

    		*Transpose and square;	
    		proc transpose data=_distribution_cat_&disttablestratorder. out=_catdata_trans(drop=_name_) prefix=_;
    			by dpidsiteid runid group &tablesub.;
    			var &countvar.;
    			id categorysort;
    		run;

    		data &cattableid._&cattablestratorder.;
    			merge _total_bydp _catdata_trans;
    			by dpidsiteid runid group &tablesub.;
    			
    			*First ensure all category variables exist;
    			if _n_ = 1 then do;
    				dsid = open("_catdata_trans");
    				%do c =1 %to &num_categories.;
    					if varnum(dsid,"_&c.") = 0 then _&c. =0;
                        /*initialize percent*/
    					if varnum(dsid,"_&c._percent") = 0 then _&c._percent =.;
    				%end;
    				rc= close(dsid);
    			end;
    			drop rc dsid;

    			*if overall - compute percent;
                %if %str("&tablesub.") = %str("") %then %do;
                    format total_count_char $15. total_percent_char $8.;
                    if total_count >0 then do;
                        total_count_char = strip(put(total_count, comma12.0));
                        total_percent = 100.0;
                        total_percent_char = '100.0%';
	                    %do c =1 %to &num_categories.;
                            if _&c. = . then _&c. = 0;
        					_&c._percent = (_&c./total_count)*100;
                            _&c._percent_char = strip(put(_&c./total_count,percent8.1));
                            _&c._char = strip(put(_&c., comma12.0));
                        %end;
                    end;
                    else do;
                        total_count_char = '0';
                        total_percent_char = '.';
                        total_percent = .;
	                    %do c =1 %to &num_categories.;
                            _&c._percent_char ='.';
                            _&c._char = '.';
                        %end;
                    end;
                %end;
                %else %do;
                    /*fill in missing categories with 0*/
                    %do c =1 %to &num_categories.;
    				if _&c. = . then _&c. = 0;
                    %end; 
    			%end;        

    			*Add labels - label for _&c.;
    			%do c =1 %to &num_categories.;
    				label _&c. = "&&&lbl&c.";
    			%end;
    		run;

            proc datasets nowarn noprint lib=work;
                delete _totalbydp _catdata_trans _catdata _total_bystrat _distribution_cat:;
		    quit;

            /*Compute dose distribution metrics*/
	        %if %sysfunc(prxmatch(m/T18\b|T19\b|T20\b|T21\b|T22\b/i,&tablelist.)) > 0 %then %do;
				%if %eval(&s. eq 1) %then %let output_t5dose_continuous_data = N;

				%if %eval(&s. eq 1) and %str("&levelid3.") ne %str("") %then %do;	
						
		    		proc sort data=&dataset.(where=(&whereclause. and level in ("&levelid3.")))
							  out=_t5data_dose_stats;	
					by runid group dpidsiteid;
					keep runid group dpidsiteid &dosevar. metricvalue; 	
					run;

					proc transpose data=_t5data_dose_stats out=_t5data_dose_stats_trans;
					by runid group dpidsiteid;
					var metricvalue;
					id &dosevar.;
					run;

					data _t5data_dose_stats;
					set _t5data_dose_stats_trans;
					count_std=0;
					weighted_std=0;
					if missing(mean) = 0 then weighted_mean = mean * &totalcountdosevar.;
					if missing(stddev) = 0 then do;
						weighted_std = (stddev**2)*(&totalcountdosevar. - 1);
						count_std=1;
					end;
					run;

					proc means data=_t5data_dose_stats nway missing noprint;
					var minimum maximum count_std weighted_std &totalcountdosevar. weighted_mean;
					class runid group;					
					output out=_t5data_dose_stats(drop=_:) min(minimum)=minimum
														   max(maximum)=maximum
														   sum(count_std)=count_std
														   sum(weighted_std)=weighted_std
														   sum(&totalcountdosevar.)=&totalcountdosevar.
														   sum(weighted_mean)=weighted_mean;
					run;

					data _t5data_dose_stats;
					length dpidsiteid $6.;
					set _t5data_dose_stats(in=a)
					%if &stratifybydp. = Y %then %do;
		            	_t5data_dose_stats_trans
		            %end; ;
					format mean_char stddev_char minimum_char maximum_char $15.;
					if a then do;
						dpidsiteid = 'all';
						mean = weighted_mean / &totalcountdosevar.;
						if missing(weighted_std) = 0 then stddev = sqrt(weighted_std /(&totalcountdosevar. - count_std));
					end;
					mean_char = strip(put(mean, comma12.1));
					stddev_char = strip(put(stddev, comma12.1));
					minimum_char = strip(put(minimum, comma12.0));
					maximum_char = strip(put(maximum, comma12.0));
					keep runid group dpidsiteid mean_char stddev_char minimum_char maximum_char;
					run;
			
					proc sort data=_t5data_dose_stats;
					by dpidsiteid runid group;
					run;

					data &cattableid._&cattablestratorder.;
	    			merge &cattableid._&cattablestratorder.
						  _t5data_dose_stats;
	    			by dpidsiteid runid group;
					run;	

					%let output_t5dose_continuous_data = Y;
				%end;						
			%end;

            /*compute stratification percents and merge in total row*/
            %if %eval(&s.>1) %then %do;
                *Merge in higher order stratifications;
                data &cattableid._&cattablestratorder.;
                    set &cattableid._&cattablestratorder.
				    &cattableid._1(where=(dpidsiteid = 'all') keep=runid group dpidsiteid total_percent total_count %do c = 1 %to &num_categories.; _&c. %end;);
                run;

                *Compute percentages;
                proc sql noprint undo_policy=none;
				    create table &cattableid._&cattablestratorder. as
				    select x.*
					       , y.total_count as overall_total
                           , y.total_count_char as overall_count_char
    					   %do c = 1 %to &num_categories.;
    					   , y._&c. as _total_&c.
    					   %end;
    				from &cattableid._&cattablestratorder. as x,
    					 &cattableid._1 as y
    				where x.group = y.group and x.runid = y.runid and x.dpidsiteid=y.dpidsiteid;
    			quit;

    			data &cattableid._&cattablestratorder.(drop=overall_total _total:);
    				set &cattableid._&cattablestratorder. ;
                    format total_count_char $15. total_percent_char $8.;

    				if overall_total >0 then do;
    					total_percent = (total_count/overall_total)*100;
                        total_percent_char = strip(put((total_count/overall_total), percent8.1));
                        total_count_char = strip(put(total_count, comma12.0));

                        *Compute percent and apply NaN indicator if a category has a denominator of 0;
        				%do c =1 %to &num_categories.;
                        format _&c._percent_char $8. _&c._char $15.;
    					if _total_&c. >0 then do;
    						_&c._percent = (_&c./_total_&c.)*100;
                            _&c._percent_char =  strip(put((_&c./_total_&c.), percent8.1));
                            _&c._char = strip(put(_&c., comma12.0)); 
    					end;
    					else do;
                            _&c. = 0;
                            _&c._char = '0';
    						_&c._percent =.;
                            _&c._percent_char = 'NaN';
    					end;
    				    %end;
    				end;
    				else do;
    					total_percent = .;
                        total_percent_char = '.';
                        *set categories to missing;
	                    %do c =1 %to &num_categories.;
                            _&c. = .;
                            _&c._char = '.';
    						_&c._percent = .;
    						_&c._percent_char = '.';
    				    %end;
    				end;
    			run;

    			proc sort data=&cattableid._&cattablestratorder.;
    				by dpidsiteid runid group &tablesub.;
    			run;
            %end; /*compute stratification percents*/
        %end; /*category tables*/

        /*Continous var metrics*/
        %if %eval(&disttablestratorder>0) %then %do;

			proc means data=_t5data_summed (where=(level in ("&levelid2."))) noprint nway;
			var &catvar.;
			freq &countvar.;
			class dpidsiteid runid group &tablesub.;
			output out=table_&disttableid.a(drop=_type_ _freq_) p25=_p25 p75=_p75 
													max=_max 
													min=_min 
													median=_median 
													mean=_mean 
													std =_std;		
			run;

			proc sort data=_t5data_summed (where=(level = "&levelid2")) nodupkey out=table_&disttableid.a2(keep=runid group dpidsiteid &tablesub.);
			by dpidsiteid runid group &tablesub.;
			run;

			data table_&disttableid.a;
				merge table_&disttableid.a(in=a) 	
					  table_&disttableid.a2(in=b);
				by dpidsiteid runid group &tablesub.;

				if b and not a then do;
					total_count=0;
				end;
			run;

			%if %eval(&s.>1) %then %do;

			    data table_&disttableid.a;
                    set table_&disttableid.a
				    &disttableid._1 (where=(dpidsiteid = 'all') keep=runid group dpidsiteid total_count mean_char std_char min_char p25_char median_char p75_char max_char);
                run;

			    *Retrieve N Overall;
                proc sql noprint undo_policy=none;
				    create table table_&disttableid.a as
				    select x.*
					       , y.total_count as overall_total
                           , y.total_count_char as overall_count_char
						   , y.mean_char as total_mean
						   , y.std_char as total_std
						   , y.min_char as total_min
						   , y.p25_char as total_p25
						   , y.median_char as total_median
						   , y.p75_char as total_p75
						   , y.max_char as total_max
    				from table_&disttableid.a as x,
    					 &disttableid._1 as y
    				where x.group = y.group and x.runid = y.runid and x.dpidsiteid=y.dpidsiteid;
    			quit;

				proc sort data = table_&disttableid.a;
				by dpidsiteid runid group &tablesub.;
				run;

			%end;

			/*Merge in totals*/
			data &disttableid._&disttablestratorder.;	
				merge table_&disttableid.a %if %eval(&s.>1) %then %do; (where=(dpidsiteid = 'all')) %end; _total_bydp;
				by dpidsiteid runid group &tablesub.;

				 total_count_char = strip(put(total_count, comma12.0));

				 %if %eval(&s.=1) %then %do;
					 mean_char = strip(put(_mean, comma12.1));
					 std_char = strip(put(_std, comma12.1));

					 min_char = strip(put(_min, comma12.0));
					 p25_char = strip(put(_p25, comma12.0));
					 median_char = strip(put(_median, comma12.0));
					 p75_char = strip(put(_p75, comma12.0));
					 max_char = strip(put(_max, comma12.0));
				 %end;

				 %if %eval(&s.>1) %then %do;
					 if missing(mean_char)=1 then mean_char = strip(put(_mean, comma12.1));
					 if missing(std_char)=1 then std_char = strip(put(_std, comma12.1));

					 if missing(min_char)=1 then min_char = strip(put(_min, comma12.0));
					 if missing(p25_char)=1 then p25_char = strip(put(_p25, comma12.0));
					 if missing(median_char)=1 then median_char = strip(put(_median, comma12.0));
					 if missing(p75_char)=1 then p75_char = strip(put(_p75, comma12.0));
					 if missing(max_char)=1 then max_char = strip(put(_max, comma12.0));
				 %end;

                format total_count_char $15. mean_char std_char p25_char median_char p75_char max_char $12.;

				%if %eval(&s.=1) %then %do;
		    		if total_count = 0 then do;
						mean_char = '.';
						std_char = '.';

						min_char = '.';
						p25_char = '.';
						median_char = '.';
						p75_char = '.';
						max_char = '.';
		    		end;
				%end;

				%if %eval(&s.>1) %then %do;
	    			if overall_total >0 then do;
		    			if total_count = 0 then do;
							mean_char = 'NaN';
						 	std_char = 'NaN';

							min_char = 'NaN';
							p25_char = 'NaN';
							median_char = 'NaN';
							p75_char = 'NaN';
							max_char = 'NaN';
		    			end;
					end;
					if overall_total = 0 then do;
		    			if total_count = 0 then do;
							mean_char = '.';
						 	std_char = '.';

							min_char = '.';
							p25_char = '.';
							median_char = '.';
							p75_char = '.';
							max_char = '.';
		    			end;
					end;

					drop total_mean total_std total_min total_max total_p25 total_p75 total_median;
				%end;

				if total_count = 1 then std_char = 'NaN';

			run;

		    proc datasets nowarn noprint lib=work;
            delete table_&disttableid.a table_&disttableid.a2;
		    quit;

		%end; /*continuous tables*/

	
	%end; /*loop through each tablesub*/

    /*----------------------------------------------------------------------------------------------*/
    /* Assign GROUPLABEL and sort order variables                                                   */
    /*----------------------------------------------------------------------------------------------*/

    /*Increase length of label if < longest stratification label*/
    %if &labelfileexists = Y %then %let t5tablelabellength = %sysfunc(max(50, &label_length.+50));
    %else %let t5tablelabellength = 50;

    /*utility macro*/
    %macro assignlabelvars(format=, sortorder1 = , sortorder2=);
        %if %length(&format)>0 %then %do; grouplabel= &format; %end;
        %if %length(&sortorder1)>0 %then %do; sortorder1=&sortorder1.; %end;
        %if %length(&sortorder2)>0 %then %do; sortorder2=&sortorder2.; %end;
    %mend;

    %macro addlabelstodisttables(data=, tablesub=);

        /*Assign group label, order and initialize sortorder1/sortorder2*/
        proc sql noprint undo_policy=none;
			create table &data. as
			select x.*,
                   %if &labelfileexists = Y %then %do;
                   case when not missing(lbla.label) then lbla.label  
                    else y.group 
                    end as grouplabel length=&t5tablelabellength.,
				    case when not missing(lblb.label) then lblb.label 
                         when not missing(lbla.label) then lbla.label  
                     else ' '  
					end as header length=&t5tablelabellength.,
                   %end;
                   %else %do;
   				   y.group as grouplabel length=&t5tablelabellength.,
   				   ' ' as header,
                   %end;
				   y.order,
				   0 as sortorder1,
				   0 as sortorder2
			from &data. as x
			inner join groupsfile as y
			on x.group = y.group and x.runid = y.runid
            %if &labelfileexists = Y %then %do;
            left join labelfile(where=(labeltype='grouplabel')) as lbla
            on x.group = lbla.group and x.runid = lbla.runid
            left join labelfile(where=(labeltype='header')) as lblb
            on x.group = lblb.group and x.runid = lblb.runid
            %end; ;
		quit;
		
        /*Number of stratifications*/
        %let stratnum = %sysfunc(countw(&tablesub.));

        /*if two stratifiers - create header row*/
        %if %eval(&stratnum.=2) %then %do;
			%let firststrat = %scan(&tablesub., 1);
			%let secondstrat = %scan(&tablesub., 2);
			proc sql noprint;
				create table _headerrow_&data. as
				select distinct runid, 
								dpidsiteid,
								group,
								order, 
								sortorder1, 
								sortorder2,
								header,	
								&firststrat.
                                %if &firststrat. = agegroup %then %do;
								, agegroupnum
                                %end;
				from &data.
				where missing(&firststrat.)=0;
			quit;
        %end;

        /*Assign formatted label - for each row will assign label to the variable grouplabel*/
        data &data.;
    		set &data. %if %eval(&stratnum.=2) %then %do; _headerrow_&data. %end; ;
            
            /*Overall and stratifybydp = Y*/
            %if &tablesub = overall and &stratifybydp = Y %then %do;
    	        if dpidsiteid ne 'all' then do;
    				grouplabel = dpidsiteid;
    				sortorder1 = 1;
    			end;
            %end;
            %else %if &tablesub ne overall %then %do;

                /*one stratifier*/
                %if %eval(&stratnum.=1) %then %do;
                    if missing(&tablesub.)=0 then do;
                        %if &tablesub = agegroup %then %do;
                        %assignlabelvars(format=put(&tablesub., $agefmt.), sortorder1 = agegroupnum, sortorder2=);
                        %end;
                        %else %do;
                        %assignlabelvars(format=put(&tablesub., $&tablesub.fmt.), sortorder1 = input(put(&tablesub., &tablesub.sort.),1.), sortorder2=);
                        %end;
                    end;
                %end;

                /*two stratifiers*/
                %else %if %eval(&stratnum.=2) %then %do;
                    if missing(&firststrat.)=0 then do;
                        %if &firststrat. = agegroup %then %do;
                        %assignlabelvars(format=put(&firststrat., $agefmt.), sortorder1 = agegroupnum, sortorder2=);
                        %end;
                        %else %do;
                        %assignlabelvars(format=put(&firststrat., $&firststrat.fmt.), sortorder1 = input(put(&firststrat., &firststrat.sort.),1.), sortorder2=);
                        %end;
                    end;
					if missing(&firststrat.) = 0 and missing(&secondstrat.) =0 then do;
                        %if &secondstrat. = agegroup %then %do;
                        %assignlabelvars(format=put(&secondstrat., $agefmt.), sortorder1 = , sortorder2=agegroupnum);
                        %end;
                        %else %do;
                        %assignlabelvars(format=put(&secondstrat., $&secondstrat.fmt.), sortorder1 = , sortorder2=input(put(&secondstrat., &secondstrat.sort.),1.));
                        %end;
                    end;
                %end;
            %end;

            /*Add footnote superscrip*/
            %if &createfootnote. = Y %then %do;
                if sortorder1 = 0 and sortorder2 = 0 then do;
                    grouplabel=cat(strip(grouplabel), "^{super", " ", order, "}");
                end;
            %end;
        run;
        
		proc sort data=&data. sortseq=linguistic(numeric_collation=on);;
			by order dpidsiteid sortorder1 sortorder2;
		run;	

        proc datasets nowarn noprint lib=work;
            delete _headerrow_:;
        quit;
	%mend;

    /*Loop through each table*/
    %do s = 1 %to %sysfunc(countw(&tablesublist., '|'));
        %let tablesub = %scan(&tablesublist., &s., '|');

        %let cattablestratorder =0 ;
        %let disttablestratorder =0 ;

        data _null_;
            set tablefile(where=(table in (%if %str("&cattableid.") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("&disttableid.") ne %str("") %then %do; "&disttableid" %end;) and tablesub = "&tablesub."));
            if table = "&cattableid" then do;
                call symputx('cattablestratorder', stratificationorder);
            end;
            if table = "&disttableid" then do;
                call symputx('disttablestratorder', stratificationorder);
            end;
        run;

    	%if %eval(&cattablestratorder.>0) %then %do;
    		%addlabelstodisttables(data=&cattableid._&cattablestratorder., tablesub=&tablesub.);
    	%end;
    	%if %eval(&disttablestratorder.>0) %then %do;
    		%addlabelstodisttables(data=&disttableid._&disttablestratorder., tablesub=&tablesub.);
    	%end;
    %end;

    /*Create footnote lookup table - used for dose tables*/
    %if &createfootnote. = Y %then %do;

        /*Identify unit and categories for each group*/
        proc sql noprint;
            create table _temp_unit as
            select a.group
                 , a.order        
                 , b.unit
                 , c.&catvar.
                   %if &labelfileexists = Y %then %do;
                 ,  case when not missing(lbl.label) then lbl.label  
                    else a.group 
                    end as grouplabel length=&t5tablelabellength.
                   %end;
				   %else %do;
				 , 	a.group as grouplabel length=&t5tablelabellength.
				   %end;
            from groupsfile(keep=group runid order) as a
            inner join
                (select distinct group, runid, unit
                from master_cohortcodes(keep=group runid unit indexcriteria)
                where indexcriteria = 'DEF' and missing(unit)=0) as b
            on a.group = b.group and a.runid = b.runid
            inner join
                (select group, runid, &catvar.
                from master_typefile(keep=group runid &catvar.)) as c
            on a.group=c.group and a.runid=c.runid
            %if &labelfileexists = Y %then %do;
            left join labelfile(where=(labeltype='grouplabel')) as lbl
            on a.group = lbl.group and a.runid = lbl.runid
            %end;
            order by a.order;
        quit;

        /*Create footnote*/
        data &cattableid._lookup_footnotes_dose;
            set _temp_unit;
            length description $575 ;
            %do c =1 %to &num_categories.;
            length label&c $200;
            label&c = catx(' ',"&&&lbl&c.", "=", scan(&catvar., &c., ' '));
            %end;

            description= cat(strip(grouplabel),': ', catx('; '%do c =1 %to &num_categories.; , label&c %end;));
            keep order description;
        run;

    %end;

    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _t5data_summed: _temp_unit;
    quit;

    %put =====> END MACRO: t5tables_createdata ;

%mend t5tables_createdata;
