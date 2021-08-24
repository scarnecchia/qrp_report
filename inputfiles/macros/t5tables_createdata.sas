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
*
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
                           catvarsort=);

    %put =====> MACRO CALLED: t5tables_createdata ;
	
    /*--------------------------------------------------------------------------------------------*/
    /* Determine all levelIDs and stratifications requested                                       */
    /*--------------------------------------------------------------------------------------------*/
    %let tablesub = ;
    %let tablesublist = ;

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
        select distinct tablesub, stratificationorder
        into :tablesublist separated by '|', :stratorderlist
        from tablefile
        where table in (%if %str("&cattableid.") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("disttableid") ne %str("") %then %do; "&disttableid" %end;)
        order by stratificationorder;
    quit;

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

	**Defensive coding for gap analyses;
	%if &disttableid. = T11 or &disttableid. = T12 or &disttableid. = T13 %then %do;
		data &dataset.;
		set &dataset.;
		if missing(gaplength)=0 and gaplength < 0 then gaplength =0;
		run;
	%end;

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

    /*-----------------------------------------------------------------------------------------------*/
    /* Compute overall (required - already checked in process_inputfiles  and stratification metrics */
    /*-----------------------------------------------------------------------------------------------*/

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
        %if "&cattableid." ne "" %then %do;

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

    			*Add labels - label for _&c. variables will be used for proc report;
    			%do c =1 %to &num_categories.;
    				label _&c. = "&&&lbl&c.";
    			%end;
    		run;

            proc datasets nowarn noprint lib=work;
                delete _totalbydp _catdata_trans _catdata _total_bystrat _distribution_cat:;
		    quit;

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
        %if "&disttableid." ne "" %then %do;

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
    				where x.group = y.group and x.runid = y.runid and x.dpidsiteid=y.dpidsiteid
					order by dpidsiteid, runid, group/*, &tablesub.*/;
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
					 std_char = strip(put(_p25, comma12.1));

					 min_char = strip(put(_min, comma12.0));
					 p25_char = strip(put(_p25, comma12.0));
					 median_char = strip(put(_median, comma12.0));
					 p75_char = strip(put(_p75, comma12.0));
					 max_char = strip(put(_max, comma12.0));
				 %end;

				 %if %eval(&s.>1) %then %do;
					 if missing(mean_char)=1 then mean_char = strip(put(_mean, comma12.1));
					 if missing(std_char)=1 then std_char = strip(put(_p25, comma12.1));

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
				%end;

				drop _: ;
			run;

		%end; /*continuous tables*/

	
	%end; /*loop through each tablesub*/

    /*----------------------------------------------------------------------------------------------*/
    /* Assign GROUPLABEL and sort order variables                                                   */
    /*----------------------------------------------------------------------------------------------*/

    /*Increase length of label if < longest stratification label*/
    %if &labelfileexists = Y %then %let t5tablelabellength = %sysfunc(max(40, &label_length.));
    %else %let t5tablelabellength = 40;

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

    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _t5data_summed:;
    quit;

    %put =====> END MACRO: t5tables_createdata ;

%mend t5tables_createdata;
