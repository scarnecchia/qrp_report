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
*   - agg_t5first.sas7bdat
* 
*
*  Program outputs:                                                                                                                           
*   - TBD
* 
*  PARAMETERS: 
*   - dataset: aggregate dataset from %aggregate_report_tables
*   - whereclause: where clause to restrict input dataset
*   - catvar: variable that will be categorized
*   - countvar: metric counting counts
*   - cattableid: category table ID from TABLEFILE
*   - disttableid: distribution table ID from TABLEFILE
*
* 
*  Programming Notes:                                                                                
*  - Censor tables are computed in a separate macro (censortable_createdata.sas)   
*  - 'overall' stratification is required for any additional stratification 
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
                           disttableid=);

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
		class runid group level &stratvars. &catvar. / missing;
		output out=_t5data_summed(drop=_:) sum=;
	run;

    data _t5data_summed;
        set _t5data_summed(in=a)
            %if &stratifybydp. = Y %then %do;
            &dataset.(keep=dpidsiteid runid group level &stratvars. &catvar. &countvar.
                      where=(&whereclause. and level in (&levellist1. &levellist2.)))
            %end; ;
        length dpidsiteid $6.;
        if a then dpidsiteid = 'all';
    run;

    /*----------------------------------------------------------------------------------------------*/
    /* Compute overall (required - already checked in process_inputifles  and stratifiation metrics */
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
            end;
            if table = "&cattableid" then do;
                call symputx('categories', categories);
                call symputx('cattablestratorder', stratificationorder);
            end;
            if table = "&disttableid" then do;
                call symputx('disttablestratorder', stratificationorder);
            end;
        run;

        /*reset tablesub if overall*/
        %if &tablesub = overall %then %let tablesub = ;
        %if %index(&tablesub., agegroup)>0 %then %let tablesub = &tablesub. agegroupnum;

    	/*Extract column 1: Total*/
    	proc sort data=_t5data_summed out=_total_bydp(rename=&countvar.=total_count keep=dpidsiteid runid group &tablesub. &countvar.);
    		by dpidsiteid runid group &tablesub. &countvar.;
            where level = "&levelid1.";
    	run;

        /*Group continous var into categories*/
        %if "&cattableid." ne "" %then %do;

            %convert_categories(var=&catvar., categories=&categories.);

    		data _catdata;
    			set _t5data_summed(where=(level in ("&levelid2.")));

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
    			class dpidsiteid runid group &tablesub.  category categorysort / missing;
    			output out=_distribution_cat_&disttablestratorder.(drop=_:) sum=;
    		run;

    		*Transpose and square;	
    		proc transpose data=_distribution_cat_&disttablestratorder. out=_catdata_trans(drop=_name_) prefix=_;
    			by dpidsiteid runid group &tablesub.;
    			var &countvar.;
    			id categorysort;
    		run;

    		data table&cattableid._&cattablestratorder.;
    			merge _total_bydp _catdata_trans;
    			by dpidsiteid runid group &tablesub.;
    			
    			*First ensure all category variables exist;
    			if _n_ = 1 then do;
    				dsid = open("_catdata_trans");
    				%do c =1 %to &num_categories.;
    					if varnum(dsid,"_&c.") = 0 then _&c. =.;
    				%end;
    				rc= close(dsid);
    			end;
    			drop rc dsid;

    			*if overall - compute percent;
                %if %str("&tablesub.") = %str("") %then %do;
        			format total_percent 12.1;
        			total_percent = 100.0;
        			%do c =1 %to &num_categories.;
        				if total_count >0 then do;
        					_&c._percent = (_&c./total_count)*100;
        				end;
        			%end;
                %end;

    			*Fill in missing with 0s, Add labels and formats;
    			%do c =1 %to &num_categories.;
    				if _&c. = . then _&c. = 0;
    				label _&c. = "%scan(&categories., &c., ' ')";
                    format _&c. comma12.0; 
                    %if %str("&tablesub.") = %str("") %then %do;
    				if _&c._percent = . then _&c._percent = 0;
    				label _&c._percent = "%scan(&categories., &c., ' ') %";
    				format _&c._percent 12.1;
                    %end;
    			%end;

    			format total_count comma12.0;
    		run;

            proc datasets nowarn noprint lib=work;
                delete _totalbydp _catdata_trans _catdata _total_bystrat _distribution_cat:;
		    quit;

            /*compute stratification percents and merge in total row*/
            %if %eval(&s.>1) %then %do;
                *Merge in higher order stratifications;
                data table&cattableid._&cattablestratorder.;
                    set table&cattableid._&cattablestratorder.
				    table&cattableid._1(keep=runid group dpidsiteid total_percent total_count %do c = 1 %to &num_categories.; _&c. %end;);
                run;

                *Compute percentages;
                proc sql noprint undo_policy=none;
				    create table table&cattableid._&cattablestratorder. as
				    select x.*
					       , y.total_count as overall_total
    					   %do c = 1 %to &num_categories.;
    					   , y._&c. as _total_&c.
    					   %end;
    				from table&cattableid._&cattablestratorder. as x,
    					 table&cattableid._1 as y
    				where x.group = y.group and x.runid = y.runid and x.dpidsiteid=y.dpidsiteid;
    			quit;

    			data output.table&cattableid._&cattablestratorder.(drop=overall_total _total:);
    				set table&cattableid._&cattablestratorder. ;

    				if overall_total >0 then do;
    					total_percent = (total_count/overall_total)*100;
    				end;
    				else do;
    					total_percent = 0;
    				end;
    				format total_percent 12.1;

    				*Compute percent;
    				%do c =1 %to &num_categories.;
    					if _total_&c. >0 then do;
    						_&c._percent = (_&c./_total_&c.)*100;
    					end;
    					else do;
    						_&c._percent =0;
    					end;
    					format _&c._percent 12.1 _&c. comma12.0;
    				%end;
    			run;

    			proc sort data=table&cattableid._&cattablestratorder.;
    				by dpidsiteid runid group &tablesub.;
    			run;
            %end; /*compute stratification percents*/
        %end; /*category tables*/		
	%end; /*loop through each tablesub*/


    /*----------------------------------------------------------------------------------------------*/
    /* Apply labels                                                                                 */
    /*----------------------------------------------------------------------------------------------*/



    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _t5data_summed ;
    quit;

    %put =====> END MACRO: t5tables_createdata ;

%mend t5tables_createdata;
