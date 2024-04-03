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
*    input.&tree_table.
*    Type 3 Analysis:
*       msoc.[RUNID]_t#_treeads_[TREEANALYSISID]_[LEVELID]_[LEVELNUM]_[PERIODID].sas7bdat 
*       msoc.[RUNID]_t3_tree_wkdays_[PERIODID]_agg.sas7bdat
*    Type 2 and Type 4:
*       msoc.[RUNID]_t#_treeads_[TREEANALYSISID]_[LEVELID]_[LEVELNUM]_[PERIODID].sas7bdat
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

  %do n = 1 %to &numrunid.;
   %let runid = %scan(&runidlist., &n.); 
   
   /***********************************************************************************************
    Identify EOI and REF for type 2 and 4
   ***********************************************************************************************/
   *Get EOI/REF for type 2/4 analysis;
    %if %eval(&typenum. ne 3) %then %do;
        proc sql noprint;
            create table comparison as
            select x.analysisgrp, y.eoi, y.ref
            from infolder.&&&runid._psmatchfile. (keep=analysisgrp psestimategrp) as x
            inner join infolder.&&&runid._psestimationfile. as y
            on x.psestimategrp = y.psestimategrp;
        quit;
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
       proc datasets lib = work;
        delete _uniques;
       quit;
     %end;
	 %else %do; 
	   %let &out_var. = ;
	 %end;
	 
   %mend find_lvl_vars;
     %find_lvl_vars(strata_table = t&typenum.treeanalysis, out_var =unique_lvlvars);
	 %if &run_t3wk. = Y %then %do; %find_lvl_vars(strata_table = t3treewkdays, out_var =unique_wklvlvars); %end;

  /************************************************************************************************
   collapse data
   ************************************************************************************************/
    proc means noprint data=agg_t&typenum._tree_analysis_&periodid. (where = (lowcase(runid) = "&runid.")) nway missing;
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
	%end;
	  
   /*----------------------------------------------------------------------------------------------
     Convert all strata variables that are used for identification to character values
     ----------------------------------------------------------------------------------------------*/ 
	  %if &num_unique_lvlvars. > 0 %then %do;
	    proc contents noprint data =_agg_t&typenum._tree_analysis_&periodid. (keep = &unique_lvlvars.) out = contents_all;
        run;
	    
	    proc sql noprint;
	      select count(name) into: num_nums
	      from contents_all where type = 1;
	      
	      %let num_nums = &num_nums.;
	      
	      %if &num_nums. > 0 %then %do;
	        select name into: num1 - :num&num_nums.
	        from contents_all where type = 1;
	      %end;
	    quit;
	    
	    data _agg_t&typenum._tree_analysis_&periodid.;
	      set _agg_t&typenum._tree_analysis_&periodid. 
	      %if &num_nums. > 0 %then %do;(rename = (%do nn = 1 %to &num_nums.; &&num&nn.. = &&num&nn.._in %end;))%end;;  
	      %do na = 1 %to &num_nums.; 
	        length &&num&na.. $50;
	        &&num&na.. = left(put(&&num&na.._in,8.));
	      %end;
        run;	
      %end;	

   /*----------------------------------------------------------------------------------------------
     Determine the number of treeanalysisids in the tree_file
     ----------------------------------------------------------------------------------------------*/
      proc sql noprint;    	
    	create table _tree_groups as 
    	select a.treeanalysisid
		      ,a.treeanalysisgrp
		      ,a.levelid
		      ,a.levelnum
			  ,a.levelnumlbl
			  ,a.rwstart
			  ,a.rwend
			  ,a.cwstart
			  ,a.cwend
			  ,b.levelvars
			  ,lower(b.tableid) as tableid
    	from input.&treeaggfile. (where = (lowcase(runid) = "&runid.")) a 
		  inner join infolder.&&&runid._userstrata (where = (lowcase(tableid) in ("t&typenum.treeanalysis", "t&typenum.treepoisson"))) b
	    on a.levelid = b.levelid
		  order by a.treeanalysisid;
      quit;

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
 
   /*----------------------------------------------------------------------------------------------
     Loop through each treeanalysisid and create TreeScan Analytic datasets from temporary datasets 
	 ----------------------------------------------------------------------------------------------*/
      %do t = 1 %to &num_treeids.;
    %if &num_unique_lvlvars > 0 %then %do;

    	%let num_levelvars = %sysfunc(countw(&&levelvar&t..,' '));

		  %do lv = 1 %to &num_levelvars.;
	         %let lvl_var&lv. = %sysfunc(scan(&&levelvar&t..,&lv.,' ')); 
		     %let lbl&lv. = %sysfunc(scan(&&levelnumlbl&t..,&lv.,' '));
	      %end;
		  
	      data temp_&runid._t&typenum._tree_analysis_&periodid._agg;
		     set _agg_t&typenum._tree_analysis_&periodid. (where = (treeanalysisgrp = "&&treegroup&t.." 
		                                                                   and level = "&&levelid&t.." 
		  	                                                           %do lv = 1 %to &num_levelvars.;
		  		                                                         and &&lvl_var&lv.. = "&&lbl&lv.."
		  	                                                           %end;));
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
          %put WARNING: No data exists for treeanalysisid = &&tree&t.., treeanalysisgrp = &&treegroup&t.., level = &&levelid&t..&labelwarning.. Aggregate datasets will not be produced.;
        %end;
	    %else %do;
	  /*----------------------------------------------------------------------------------------------
		 Map variables from tree_file and comparison file as follows. 
		 For type 2 and type 4:
		  - map treeanlysisgrp to group from tree_file
		  - map group to reference analysisgrp values to acquire EOI and REF group details from comparison file.
		 For type 3:
		  - map treeanalysisgrp to group from tree_file, which is the cohortgrp
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
          proc datasets lib = work;
            delete temp_&runid._t&typenum._tree_analysis_&periodid._agg;
          quit;
		  
      /*----------------------------------------------------------------------------------------------
		 Aggregate data by group levelid levelnum for NHOI's  and output finalize data based on type
		----------------------------------------------------------------------------------------------*/
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
				/* Exposed CSV */
				data _null_;
				     file "&REPORTROOT./output/&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid._case.csv" dsd delimiter=',';
				     set &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.(keep=hoi nhois_eoi);
						 put (_all_) (+0);
				run;

				/* Unexposed CSV */
				data _null_;
				     file "&REPORTROOT./output/&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid._ctrl.csv" dsd delimiter=',';
				     set &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.(keep=hoi nhois_ref);
						 put (_all_) (+0);
				run;
			%end; /* nobs > 0 */
		  %end;
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
				data _null_;
				     file "&REPORTROOT./output/&runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid..csv" dsd delimiter=',';
				     set &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.;
						 put (_all_) (+0);
				run;
			%end;
	    %end; /* final aggregation by type */
		  /* Clean up work space */
          proc datasets lib = work;
            delete &runid._t&typenum._treeads_&&tree&t.._&&levelid&t.._&&levelnum&t.._&periodid.;
          quit; 
		%end; /* data exists */ 
	  %end; /* treeanalysisid loop */

	  /*----------------------------------------------------------------------------------------------
		 Aggregate poisson data 
		----------------------------------------------------------------------------------------------*/
	    %if &treepoissonindicator = Y %then %do;
	    proc sql noprint;
	    	create table _agg_poissont&typenum._&periodid as 
	    	select a.*, b.adjustment, b.denominator
	    	from agg_t&typenum._treeanalysis_poisson_&periodid a 
	    	left join poisson_group_lookup_all b
	    	on a.runid = b.runid and a.treeanalysisgrp = b.treeanalysisgrp and a.group = b.group;
	    quit;

	    data _agg_poissont&typenum._&periodid(drop=exp unexp evexp evunexp futimeexp futimeunexp w_unexp w_evunexp w_futimeunexp denominator);
	    	set _agg_poissont&typenum._&periodid;
	    	length observed expected 8;
	    	if adjustment in ('psstrat@unweighted','psstrat@unweightedw') then do;
	    		if denominator = 'person' then do;
	    			observed=evexp;
	    			expected=exp*(evunexp/unexp);
	    		end;
	    		else if denominator = 'persontime' then do;
	    			observed=evexp;
	    			expected=futimeexp*(evunexp/futimeunexp);
	    		end;
	    	end;
	    	if adjustment in ('psstrat@weighted','iptw@weighted') then do;
	    		if denominator = 'person' then do;
	    			observed=evexp;
	    			expected=exp*(w_evunexp/w_unexp);
	    		end;
	    		else if denominator = 'persontime' then do;
	    			observed=evexp;
	    			expected=futimeexp*(w_evunexp/w_futimeunexp);
	    		end;
	    	end;
	    run;

	    data _null_;
	    	set poisson_group_lookup_all;
	    	count=put(_n_,6. -L);
	    	call symputx('num_poisson_treeids',count);
	    	call symputx('treepoissonid'||count,treeanalysisid);
	    	call symputx('treepoissonanalysisgrp'||count,treeanalysisgrp);
	    	call symputx('treepoissonlevelid'||count,levelid);
	    	call symputx('treepoissonlevelnum'||count,levelnum);
	    	call symputx('treepoissonlevelvar'||count,levelvars);
	    	call symputx('treepoissonlevelnumlbl'||count,levelnumlbl);
	    	call symputx('adjustmentmethod'||count,adjustment);
	    run;

	   	%do z = 1 %to &num_poisson_treeids;

	    	%let num_poisson_levelvars = %sysfunc(countw(&&treepoissonlevelvar&z..,' '));

			  %do lv = 1 %to &num_poisson_levelvars;
		        %let poisson_lvlvar&lv. = %sysfunc(scan(&&treepoissonlevelvar&z..,&lv.,' ')); 
			     %let poisson_lbl&lv. = %sysfunc(scan(&&treepoissonlevelnumlbl&z..,&lv.,' '));
		    %end;

			  proc means noprint data=_agg_poissont&typenum._&periodid.
			    (where=(lowcase(runid) = "&runid" and 
			    	      treeanalysisgrp="&&treepoissonanalysisgrp&z." and 
			  	        level = "&&treepoissonlevelid&z" and adjustment = "&&adjustmentmethod&z" and 
			  	        (observed > 0 and expected > 0)
			  	        %if &num_poisson_levelvars > 0 %then %do lv = 1 %to &num_poisson_levelvars;
			  	         and &&poisson_lvlvar&lv. = "&&poisson_lbl&lv."
			  	        %end;)) nway missing;

			    var observed expected;
			    class hoi;
			    output out=_t&typenum._temp (drop=_:) 	
			    sum(observed)=observed
			    sum(expected)=expected;
			  run;

			  /* Rename adjustment method for file name */
			  %if %str(&&adjustmentmethod&z.) = %str(psstrat@weighted) %then %let adjustment = _weighted;
			  %else %if %str(&&adjustmentmethod&z.) = %str(psstrat@unweightedw) %then %let adjustment = _unweighted; 
			  %else %let adjustment =;

			  %isdata(dataset=_t&typenum._temp);
			  %if &nobs > 0 %then %do;
				  data _null_;
				     file "&REPORTROOT./output/&runid._t&typenum._treeads_&&treepoissonid&z.._&&treepoissonlevelid&z.._&&treepoissonlevelnum&z.._&periodid.&adjustment..csv" dsd delimiter=',';
				     set _t&typenum._temp;
						 put (_all_) (+0);
					run;
				%end;

			%end; /* z */
			/* Clean up work space */
        proc datasets nowarn noprint nolist lib = work;
          delete _t&typenum._temp _agg_poissont&typenum._&periodid. poisson_group_lookup_all;
        quit; 
	    %end; /* treepoissonindicator = Y */
  %end; /* runid loop */
%mend aggregate_tree;
