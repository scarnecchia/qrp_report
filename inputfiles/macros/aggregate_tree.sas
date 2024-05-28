************************************************************************************************
*                                         SENTINEL PROGRAM
*************************************************************************************************
* PROGRAM:  aggregate_tree.sas 
* Created (mm/dd/yy): 04/28/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Create analytic datasets that can be used as inputs to TreeScan software
* 
* Program inputs:       
*    input.&treeaggfile.
*	 infolder.&&&runid._treefile.
*	 infolder.&&&runid._userstrata.
*	 infolder.&&&runid._psmatchfile.
*	 infolder.&&&runid._psestimationfile.
*	 tree_group_lookup_all
*
** Program outputs:
*    Type 3 Analysis:       
*       	msoc.[RUNID]_t3_tree_wkdays_[PERIODID]_agg.sas7bdat
*	   	non fixed window only:
*	    	msoc.[RUNID]_t#_treeads_[TREEANALYSISID]_[LEVELID]_[LEVELNUM]_[PERIODID].csv
*		fixed window only: 	
*			msoc.[RUNID]_t#_treeads_[TREEANALYSISID]_[LEVELID]_[LEVELNUM]_[PERIODID]_case.csv
*			msoc.[RUNID]_t#_treeads_[TREEANALYSISID]_[LEVELID]_[LEVELNUM]_[PERIODID]_ctrl.csv
*    Type 2 and Type 4:
*       	msoc.[RUNID]_t#_treeads_[TREEANALYSISID]_[LEVELID]_[LEVELNUM]_[PERIODID]_case.csv
*			msoc.[RUNID]_t#_treeads_[TREEANALYSISID]_[LEVELID]_[LEVELNUM]_[PERIODID]_ctrl.csv
*		UNWEIGHTED PSSTRAT only:
*			msoc.[RUNID]_t#_treeads_[TREEPOISSON]_[LEVELID]_[LEVELNUM]_[PERIODID]_weighted.csv
*			msoc.[RUNID]_t#_treeads_[TREEPOISSON]_[LEVELID]_[LEVELNUM]_[PERIODID]_unweighted.csv
*		non UNWEIGHTED PSSTRAT only:
*			msoc.[RUNID]_t#_treeads_[TREEPOISSON]_[LEVELID]_[LEVELNUM]_[PERIODID].csv
*
*  PARAMETERS:  
*          
*  Programming Notes: 
*
*------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro aggregate_tree();

   /*---------------------------------------------------------------------------------------------------------
     Utility macro: convert all numeric strata variables that are used for identification to character values
     -------------------------------------------------------------------------------------------------------*/ 
	%macro convert_num_strata_to_char(DSET=,KEEPVARS=);
    	proc contents noprint data =&DSET(keep = &keepvars) out = contents_all;
        run;
      
      	proc sql noprint;
	        select count(name) into: num_nums trimmed
	        from contents_all where type = 1;
	        
	        %if &num_nums. > 0 %then %do;
	          select name into: num1 - :num&num_nums.
	          from contents_all where type = 1;
	        %end;
      	quit;
      
      	data &DSET;
	        set &DSET
	        %if &num_nums. > 0 %then %do;(rename = (%do nn = 1 %to &num_nums.; &&num&nn.. = &&num&nn.._in %end;))%end;;  
	        %do na = 1 %to &num_nums.; 
	          length &&num&na.. $50;
	          &&num&na.. = left(put(&&num&na.._in,8.));
	        %end;
        run;  

		proc datasets nowarn noprint lib=work;
			delete contents_all;
		quit;
    %mend convert_num_strata_to_char;

   /*---------------------------------------------------------------------------------------------------------
     Loop entire logic by RUNID
     -------------------------------------------------------------------------------------------------------*/ 

  	%do n = 1 %to &numrunid.;
   		%let runid = %scan(&runidlist., &n.); 

	   	/* Merge back original levelvars column from source userstrata to keep strata order */
	   	proc sql noprint undo_policy=none;
		   	create table tree_group_lookup_all as 
		   	select a.*, b.levelvars 
		   	from tree_group_lookup_all(drop=levelvars) a 
		   	left join infolder.&&&runid._userstrata b
		   	on lower(a.tableID) = lower(b.tableid) and a.levelid = b.levelid;
	   	quit;
   
	  	/***********************************************************************************************
	   	* Process treeanalysis and/or t3treewkdays tables
	   	* If no bernoulli groups requested, skip to check logic for numlevels and numlevellabels 
	  	/***********************************************************************************************/
		%if &treeanalysisindicator ne Y %then %goto treecheck;

		   /***********************************************************************************************
		    Identify EOI and REF for type 2 and 4
		   ***********************************************************************************************/
		    %if %eval(&typenum. ne 3) %then %do;
		    	%if %sysfunc(exist(infolder.&&&runid._psmatchfile)) %then %do;
		        proc sql noprint;
		            create table comparison as
		            select x.analysisgrp, y.eoi, y.ref
		            from infolder.&&&runid._psmatchfile. (keep=analysisgrp psestimategrp) as x
		            inner join infolder.&&&runid._psestimationfile. as y
		            on x.psestimategrp = y.psestimategrp;
		        quit;
		      %end;
		    %end;
		
		  /***********************************************************************************************
		    Determine if there is a t3treewkdays dataset created
		   ***********************************************************************************************/
		   %let run_t3wk = N;
		   %if %sysfunc(exist(agg_t3_tree_wkdays_&periodid)) =1 %then %do;
		      proc sql;
		       select case when count(levelid) > 0 then 'Y'
		              else 'N' end into: run_t3wk
		       from infolder.&&&runid._userstrata. (where = (lowcase(tableid) = 't3treewkdays'));
		      quit;
			%end;
		
		  	/***********************************************************************************************
		    Determine distinct list of levelvars to use in aggregation based on userstrata file
		   	***********************************************************************************************/
			%macro find_lvl_vars (strata_table = , out_var =);
	     		%global &out_var. num_&out_var.;
		 
			     proc sql noprint; 
			       select distinct(b.levelvars) into: all_levelvars separated by ' '
			  	   from %if "&strata_table." = "t3treewkdays" %then %do; 
				          infolder.&&&runid._userstrata. (where = (lowcase(tableid) = "&strata_table.")) b;
						%end;
						%else %do;
						  input.&treeaggfile.(where = (lowcase(runid)= "&runid.")) a 
			  	          inner join infolder.&&&runid._userstrata. (where = (lowcase(tableid) = "&strata_table.")) b
			  	          on a.levelid = b.levelid;
						%end;
				quit;
	     
	     		%let num_&out_var.= %sysfunc(countw(&all_levelvars,' '));
			    %let &out_var. = ;

		 		%if &&num_&out_var.. > 0 %then %do;
			       data _uniques;
			        %do u = 1 %to &&num_&out_var..;
			  	      levelvar = scan("&all_levelvars.",&u.); output;
			  	    %end;
			       run;
			       
			       proc sort nodupkey data = _uniques;
			         by levelvar;
			       run;
	       
			       proc sql noprint;
			         select levelvar into: &out_var. separated by ' '
			  	     from _uniques;
			       quit;
			       
			       /* Clean up work space */
			       proc datasets nowarn noprint nolist lib = work;
			        delete _uniques;
			       quit;
			   	%end;
		 
	   		%mend find_lvl_vars;

	     	%find_lvl_vars(strata_table = t&typenum.treeanalysis, out_var =unique_lvlvars);
		 	%if &run_t3wk. = Y %then %do; %find_lvl_vars(strata_table = t3treewkdays, out_var =unique_wklvlvars); %end;

		  	/***********************************************************************************************
		    Select treeanalysisgrp values where only bernoulli groups are selected to filter aggregate dataset
		   	***********************************************************************************************/
		    proc sql noprint;
			   	select distinct quote(lower(strip(treeanalysisgrp)))
			    into :_tree_analysis_groups separated ','
			    from tree_group_lookup_all(where=(lowcase(runid) = "&runid." and tableid = "t&typenum.treeanalysis"));
		   	quit;

			/************************************************************************************************
		   	collapse data
		   	************************************************************************************************/
		    proc means noprint data=agg_t&typenum._tree_analysis_&periodid. (where = (lowcase(runid) = "&runid." and lowcase(treeanalysisgrp) in (&_tree_analysis_groups))) nway missing;
			  var nhois;
			  class treeanalysisgrp group level tte ttc hoi &unique_lvlvars.;
			  output out=_agg_t&typenum._tree_analysis_&periodid.(drop=_:) 	
			  sum (nhois)=sum_nhois;
			run;
		
			%if &run_t3wk. = Y %then %do;
				proc means noprint data=agg_t3_tree_wkdays_&periodid. (where = (lowcase(runid) = "&runid.")) nway missing;
				    var count;
				    class treeanalysisgrp group level orig_hoi hoi wkday  &unique_wklvlvars.;
				    output out=_agg_t3_tree_wkdays_&periodid.(drop=_:) 	
				    sum (count)=sum_count;
				run;
		  
			  	%if &num_unique_wklvlvars. > 0 %then %do;
				  %let unique_wkday = %sysfunc(tranwrd(%quote(&unique_wklvlvars.),%str( ),%str(,)));
			  	%end;
			
	        	proc sql noprint;
				  create table output.&&&runid._runid._t3_tree_wkdays_&periodid._agg as
				  select treeanalysisgrp              format = $40.
				        ,group                        format = $40.
						,level                        format = $3.
						,orig_hoi                     format = $11.
						,hoi                          format = $11.
				        ,wkday                        format = 8.
						,case when sum_count < 1 then 0
						 else sum_count end as count  format = 8.
						%if &num_unique_wklvlvars. > 0 %then %do;
						  ,&unique_wkday.
						%end;
				  from _agg_t3_tree_wkdays_&periodid.;
				quit;		
			%end; /*type 3 treewkdays*/
		  
			/************************************************************************************************
		    Convert all strata variables that are used for identification to character values
		   	************************************************************************************************/
			%if &num_unique_lvlvars. > 0 %then %do;
	    		%convert_num_strata_to_char(DSET=_agg_t&typenum._tree_analysis_&periodid.,KEEPVARS=&unique_lvlvars);
		    %end;	

		/*End Bernoulli (t#treeanalysis and t3treewkdays pre-processing*/
		/*Using _tree_groups dataset, will determine which treeanalysisID use t#treeanalysis and which use t#treepoisson*/
		%treecheck:

		/************************************************************************************************
	    Determine the number of treeanalysisids in the treeaggfile
	   	************************************************************************************************/
		proc sql noprint;    	
	    	create table _tree_groups as 
	    	select treeanalysisid
	      		  ,treeanalysisgrp
			      ,levelid
			      ,levelnum
			      ,levelnumlbl
			      ,rwstart
			      ,rwend
			      ,cwstart
			      ,cwend
			      ,levelvars
			      ,tableid
    		from tree_group_lookup_all(where = (lowcase(tableid) in ("t&typenum.treeanalysis", "t&typenum.treepoisson") and lowcase(runid)="&runid."))
		  	order by treeanalysisid;
		quit;

      	%let num_treeids=0;

	  	/* Determine what user strata values are, and the expected values based on levelnumlbl per levelnum */
     	data _null_;
	     	set _tree_groups;
	     	retain count 0;
	     	num_levelvars=countw(levelvars,' ');
	     	num_lbls=countw(levelnumlbl,' ');

		    if num_levelvars ne num_lbls then do;
		        put 'ERROR: (Sentinel) There must be one value in levelnumlbl for every levelvars.';
		        put treeanalysisid= treeanalysisgrp= levelvars= levelnumlbl=;
		        abort;
		   	end;

	      	/* Count number of treeanalysisIDs and corresponding input file values to loop to generate output for t#treeanalysis (Bernoulli output)*/
	      	if tableid = "t&typenum.treeanalysis" then do;
		        count+1;
		        treecount=put(count,6. -L);
		        call symputx('num_treeids',treecount);
		        call symputx('tree'||treecount,treeanalysisid);
		        call symputx('treegroup'||treecount,treeanalysisgrp);
		        call symputx('levelid'||treecount,levelid);
		        call symputx('levelnum'||treecount,levelnum);
		        call symputx('levelnumlbl'||treecount,levelnumlbl);
		        call symputx('rwstart'||treecount,put(rwstart,best.));
		        call symputx('rwend'||treecount,put(rwend,best.));
		        call symputx('cwstart'||treecount,put(cwstart,best.));
		        call symputx('cwend'||treecount,put(cwend,best.));
		        call symputx('levelvar'||treecount,levelvars);
	      	end;
		run;

		/*********************************************************************************************************
	     Loop through each treeanalysisid/stratification and create TreeScan Analytic datasets for Beroulli output
		 Poisson output is created after this loop
	   	*********************************************************************************************************/
		%do t = 1 %to &num_treeids.;
		
			/*if stratifications requested, generate where clause*/
       		%if &num_unique_lvlvars > 0 %then %do;
    			%let num_levelvars = %sysfunc(countw(&&levelvar&t..,' '));

				 %do lv = 1 %to &num_levelvars.;
			         %let lvl_var&lv. = %sysfunc(scan(&&levelvar&t..,&lv.,' ')); 
				     %let lbl&lv. = %sysfunc(scan(&&levelnumlbl&t..,&lv.,' '));
			     %end;
		  
	     	 	data temp_&runid._t&typenum._tree_analysis_&periodid._agg;
					set _agg_t&typenum._tree_analysis_&periodid. 
					(where = (treeanalysisgrp = "&&treegroup&t.." and level = "&&levelid&t.." %do lv = 1 %to &num_levelvars.; and &&lvl_var&lv.. = "&&lbl&lv.." %end;));
		  		run;
			%end; 
        	%else %do;
		  		%let num_levelvars = 0;
		  		data temp_&runid._t&typenum._tree_analysis_&periodid._agg;
		    	 	set _agg_t&typenum._tree_analysis_&periodid. (where = (treeanalysisgrp = "&&treegroup&t.." and level = "&&levelid&t.." ));
		  		run;
			%end;

			/*----------------------------------------------------------------------------------------------
	        Determine if record count is greater than 0 and output warning if not 
		    ----------------------------------------------------------------------------------------------*/
	    	%isdata(dataset=temp_&runid._t&typenum._tree_analysis_&periodid._agg);
	        %if &nobs. = 0 %then %do;
	           %let labelwarning =;
	           %if &num_levelvars. > 0 %then %do;
	        		%do lv = 1 %to &num_levelvars.; 
	        			%let labelwarning = &labelwarning., &&lvl_var&lv.. = &&lbl&lv..;
	        		%end;
	           %end;
	          %put WARNING: (Sentinel) No data exists for treeanalysisid = &&tree&t.., treeanalysisgrp = &&treegroup&t.., level = &&levelid&t..&labelwarning.. Aggregate datasets will not be produced.;
			%end;
			%else %do;

		  		/*----------------------------------------------------------------------------------------------
				 Map variables from treefile and comparison file as follows. 
				 For type 2 and type 4:
				  - map treeanlysisgrp to group from treefile
				  - map group to reference analysisgrp values to acquire EOI and REF group details from comparison file.
				 For type 3:
				  - map treeanalysisgrp to group from treefile, which is the cohortgrp
				----------------------------------------------------------------------------------------------*/
		  		data &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.;
				    length levelnum levelnumlbl $32 group $40;
				    if _n_ = 1 then do;
					  declare hash grp (dataset: "infolder.&&&runid._treefile.");
					  grp.definekey("treeanalysisgrp");
					  grp.definedata ("group");
					  grp.definedone();
					  call missing(group);
					  
					  %if &typenum. ne 3 %then %do;
					    length eoi ref $40;
					    declare hash comp (dataset: "comparison(rename = (analysisgrp = group))");
					    comp.definekey("group");
					    comp.definedata ("eoi", "ref");
					    comp.definedone();
						call missing(eoi, ref);
					  %end;
					end;

				    set temp_&runid._t&typenum._tree_analysis_&periodid._agg (rename = (group = stratagroup));
					if grp.find() = 0 then group = group;
					%if &typenum. ne 3 %then %do;
					  if comp.find() = 0 then do;
					     eoi = eoi;
					     ref = ref;
					  end;
					  if stratagroup = eoi then nhois_eoi = sum_nhois;
					  else if stratagroup = ref then nhois_ref = sum_nhois;
					%end;
					%else %if &&rwstart&t.. ne . and &&rwend&t.. ne . and &&cwstart&t.. ne . and &&cwend&t.. ne . %then %do;
					  if &&rwstart&t.. <= tte <= &&rwend&t.. then nhois_eoi = sum_nhois;
					  else if &&cwstart&t.. <= tte <= &&cwend&t.. then nhois_ref = sum_nhois;
					%end;
					levelnum = "&&levelnum&t..";
					levelnumlbl = "&&levelnumlbl&t..";
				run;
		  
			  	/* Clean up work space */
	          	proc datasets lib = work nowarn noprint nolist;
	            	delete temp_&runid._t&typenum._tree_analysis_&periodid._agg;
	          	quit;
		  
      			/*----------------------------------------------------------------------------------------------
				 Aggregate data to 1 row per HOI and save final data to OUTPUT folder as CSV
				----------------------------------------------------------------------------------------------*/

					/*Type 2, Type 4, and Type 3 fixed window design (Bernoulli scan)*/
		  			%if &typenum. ne 3 or (&&rwstart&t.. ne . and &&rwend&t.. ne . and &&cwstart&t.. ne . and &&cwend&t.. ne .) %then %do;	
					    proc sql noprint undo_policy=none;
						  create table &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid. as
						  select hoi
						        ,nhois_eoi
								,nhois_ref
						  from (
						    select hoi                                   format = $11.
							  	,case when sum(nhois_eoi) < 1 then 0
			                       else sum(nhois_eoi) end as nhois_eoi  format = 8.
							  	,case when sum(nhois_ref) < 1 then 0
			                       else sum(nhois_ref) end as nhois_ref  format = 8.
						    from &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.
						    group by hoi)
						  where nhois_eoi > 0 or nhois_ref > 0;
						quit;

						%isdata(dataset=&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.);
						%if &nobs > 0 %then %do;
      						/* Prevent path from being written to log */
							proc printto log=log; run;

							/* Exposed CSV */
							data _null_;
							     file "&OUTPUT.&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid._case.csv" dsd delimiter=',';
							     set &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.(keep=hoi nhois_eoi);
									 put (_all_) (+0);
							run;

							/* Unexposed CSV */
							data _null_;
							     file "&OUTPUT.&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid._ctrl.csv" dsd delimiter=',';
							     set &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.(keep=hoi nhois_ref);
									 put (_all_) (+0);
							run;

					        /* Resume writing to log */
					        proc printto log="&OUTPUT.qrp_report_log&reportid..log"; run;
						%end; /* nobs > 0 */
		  			%end; /*Bernoulli scan*/

					/*Type 3 non- fixed window design (Tree scan)*/
	      			%else %do;	   
				        proc sql noprint undo_policy=none;
						  create table &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid. as
						  select hoi                               format = $11.
						        ,case when sum(sum_nhois) < 1 then 0
								 else sum(sum_nhois) end as nhois  format = 8.
						        ,tte                               format = 8.
								,ttc                               format = 8.
						  from &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.
						  group by hoi
						          ,tte
								  ,ttc;
						quit;

						%isdata(dataset=&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.);
						%if &nobs > 0 %then %do;
							/* Prevent path from being written to log */
							proc printto log=log; run;

							data _null_;
							     file "&OUTPUT.&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid..csv" dsd delimiter=',';
							     set &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.;
									 put (_all_) (+0);
							run;

							/* Resume writing to log */
        					proc printto log="&OUTPUT.qrp_report_log&reportid..log"; run;
						%end;
	    			%end; /* Type 3 tree scan */

		  		/* Clean up work space */
          		proc datasets lib = work noprint nowarn nolist;
            		delete &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.;
          		quit; 

			%end; /* data exists to output CSV file */ 
		%end; /* treeanalysisid loop for t#treeanalysis data */

		/*********************************************************************************************************
	     Aggregate poisson data 
	   	*********************************************************************************************************/
	    %if &treepoissonindicator = Y %then %do;

		    proc sql noprint;
		    	create table _agg_poissont&typenum._&periodid as 
		    	select distinct a.*, b.adjustment, b.denominator
		    	from agg_t&typenum._treeanalysis_poisson_&periodid a 
		    	left join tree_group_lookup_all(where=(tableid="t&typenum.treepoisson")) b
		    	on a.runid = b.runid and a.treeanalysisgrp = b.treeanalysisgrp and a.group = b.group and a.level=b.levelid
		    	where lower(b.runid) = "&runid.";
		    quit;

			/* For PS STRAT Weighted analysis groups, we need to aggregate by DP/Strata/HOI before computing observed and expected metrics */
			%let levelvars=;

			proc sql noprint;
			select distinct levelvars into :levelvars separated by " "
			from tree_group_lookup_all(where=(adjustment="psstrat@weighted"));
			quit;

			proc means nway missing noprint data=_agg_poissont&typenum._&periodid(where=(adjustment="psstrat@weighted"));
			class runid dpidsiteid treeanalysisgrp group level hoi &levelvars. adjustment denominator;
			var Exp UnExp w_UnExp EvExp EvUnExp w_EvUnExp FutimeExp FutimeUnExp W_FuTimeUnExp;
			output out=_t&typenum._temp(drop=_:) sum=;
			run;

	    	/* Compute metrics based on denominator, analysis type and weighting value */
		    data _agg_poissont&typenum._&periodid(drop=exp unexp evexp evunexp futimeexp futimeunexp w_unexp w_evunexp w_futimeunexp denominator);
		    	set _agg_poissont&typenum._&periodid.(where=(adjustment ne "psstrat@weighted"))
			    _t&typenum._temp;
		    	length observed expected 8;
		    	if adjustment in ('psstrat@unweighted','psstrat@unweightedw') then do;
		    		if denominator = 'person' then do;
		    			observed=evexp;
		    			if unexp > 0 then expected=exp*(evunexp/unexp);
		    			else expected=.;
		    		end;
		    		else if denominator = 'persontime' then do;
		    			observed=evexp;
		    			if futimeunexp > 0 then expected=futimeexp*(evunexp/futimeunexp);
		    			else expected=.;
		    		end;
		    	end;
		    	if adjustment in ('psstrat@weighted','iptw@weighted') then do;
		    		if denominator = 'person' then do;
		    			observed=evexp;
		    			if w_unexp > 0 then expected=exp*(w_evunexp/w_unexp);
		    			else expected=.;
		    		end;
		    		else if denominator = 'persontime' then do;
		    			observed=evexp;
		    			if w_futimeunexp > 0 then expected=futimeexp*(w_evunexp/w_futimeunexp);
		    			else expected=.;
		    		end;
		    	end;
		    run;

	    	/* Store count and values to loop and generate output for poisson data */
      		%let poisson_lvlvar_list=;
			data _null_;
		        set tree_group_lookup_all(where=(tableid="t&typenum.treepoisson" and lowcase(runid)="&runid."));
		        count=put(_n_,6. -L);
		        call symputx('num_poisson_treeids',count);
		        call symputx('treepoissonid'||count,treeanalysisid);
		        call symputx('treepoissonanalysisgrp'||count,treeanalysisgrp);
		        call symputx('treepoissonlevelid'||count,levelid);
		        call symputx('treepoissonlevelnum'||count,levelnum);
		        call symputx('treepoissonlevelvar'||count,levelvars);
		        call symputx('treepoissonlevelnumlbl'||count,levelnumlbl);
		        call symputx('adjustmentmethod'||count,adjustment);
		        call symputx('poisson_lvlvar_list',trim(resolve('&poisson_lvlvar_list'))||' '||strip(levelvars));
			run;

     		/* Convert numeric stratifications to character */
      		%if %length(&poisson_lvlvar_list) > 0 %then %do;
      			%convert_num_strata_to_char(DSET=_agg_poissont&typenum._&periodid,KEEPVARS=&poisson_lvlvar_list);
      		%end;

			/*********************************************************************************************************
		     Loop through each treeanalysisid/stratification and create TreeScan Analytic datasets for Poisson output
		   	*********************************************************************************************************/
			%do z = 1 %to &num_poisson_treeids;

				/*if stratifications requested, generate where clause*/
	    		%let num_poisson_levelvars = %sysfunc(countw(&&treepoissonlevelvar&z..,' '));
			  	%do lv = 1 %to &num_poisson_levelvars;
		        	%let poisson_lvlvar&lv. = %sysfunc(scan(&&treepoissonlevelvar&z..,&lv.,' ')); 
			     	%let poisson_lbl&lv. = %sysfunc(scan(&&treepoissonlevelnumlbl&z..,&lv.,' '));
		      	%end;

			  	proc means noprint data=_agg_poissont&typenum._&periodid.
			    	(where=(lowcase(runid) = "&runid" and treeanalysisgrp="&&treepoissonanalysisgrp&z." and 
			  	        level = "&&treepoissonlevelid&z" and adjustment = "&&adjustmentmethod&z"
			  	        %if &num_poisson_levelvars > 0 %then %do lv = 1 %to &num_poisson_levelvars;
			  	         and &&poisson_lvlvar&lv. = "&&poisson_lbl&lv."
			  	        %end;)) nway missing;

			    	var observed expected;
			    	class hoi;
			    	output out=_t&typenum._temp (drop=_: where=(observed > 0 and expected > 0)) sum(observed)=observed sum(expected)=expected;
			  	run;

			  	/* Rename adjustment method for file name */
				%if %str(&&adjustmentmethod&z.) = %str(psstrat@weighted) %then %let adjustment = _weighted;
				%else %if %str(&&adjustmentmethod&z.) = %str(psstrat@unweightedw) %then %let adjustment = _unweighted; 
				%else %let adjustment =;

			  	%isdata(dataset=_t&typenum._temp);
			  	%if &nobs > 0 %then %do;

				  	/* Prevent path from being written to log */
				  	proc printto log=log; run;

				  	data _null_;
				     file "&OUTPUT.&runid._t&typenum._treeads_&&treepoissonid&z.._&&treepoissonlevelid&z.._&&treepoissonlevelnum&z.._&periodid.&adjustment..csv" dsd delimiter=',';
				     set _t&typenum._temp;
						 put (_all_) (+0);
				  	run;

         			/* Resume writing to log */
          			proc printto log="&OUTPUT.qrp_report_log&reportid..log"; run;	
				%end;
			  	%else %do;
			    	%put WARNING: (Sentinel) No data exists for treeanalysisid = &&treepoissonid&z.., treeanalysisgrp = &&treepoissonanalysisgrp&z.., level = &&treepoissonlevelid&z.., levelnum = &&treepoissonlevelnum&z... CSV will not be produced.;
			  	%end;

			%end; /* Loop through each treeanalysisID for poisson */

			/* Clean up work space */
       		proc datasets nowarn noprint nolist lib = work;
          		delete _t&typenum._temp _agg_poissont&typenum._&periodid. poisson_group_lookup_all;
        	quit; 

	    %end; /* treepoissonindicator = Y */

	%end; /* runid loop */

%mend aggregate_tree;
