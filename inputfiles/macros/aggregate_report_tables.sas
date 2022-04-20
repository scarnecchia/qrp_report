****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: aggregate_report_tables.sas  
* Created (mm/dd/yyyy): 01/20/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro imports and aggregates tables produced by QRP
*
*
*  Program inputs:                                                                                   
* 			-[RUNID]_t1_cida.sas7bdat 
*			-[RUNID]_censor_cida.sas7bdat 
*
*			-[RUNID]_t2_cida.sas7bdat 
*			-[RUNID]_t2_followuptime_cida.sas7bdat 
*			-[RUNID]_censor_cida.sas7bdat 
*			-[RUNID]_t2_concomitance.sas7bdat 
*			-[RUNID]_t2_multevent.sas7bdat 
*			-[RUNID]_t2_epigap.sas7bdat 
*			-[RUNID]_t2_overlap.sas7bdat 
*
*			-[RUNID]_psdistribution_[LOOK].sas7bdat 
*
*			-[RUNID]_t4_cida_preg.sas7bdat 
*			-[RUNID]_t4_cida_preg_gestwk.sas7bdat 
*			-[RUNID]_t4_cida_nopreg.sas7bdat 
*			-[RUNID]_t4_cida_nopreg_gestwk.sas7bdat 
*
*			-[runid]_t5_cida_disp_by_daysupp
*           -[runid]_t5_cida_dose
*			-[runid]_t5_cida_episdur
*			-[runid]_t5_cida_episdur_censor
*			-[runid]_t5_cida_gaps
*			-[runid]_t5_cida_firsteps
*
*			-[runid]_t6_utilcounts
*     		-[runid]_t6_trendcounts
*			-[runid]_t6_utildispstats
*			-[runid]_t6_utilepis_censor
*			-[runid]_t6_utilepisdurstats
*			-[runid]_t6_utiluptakestats
*			-[runid]_t6_switchepisdurstats
*			-[runid]_t6_switchplota
*			-[runid]_t6_switchplotb
*           -[runid]_t6_productsdates
*
*			-[RUNID]_distindex.sas7bdat 
*			-[RUNID]_distindexmap.sas7bdat
*
*			-[RUNID]_attrition.sas7bdat
*		    -[RUNID]_mil_attrition.sas7bdat
*	        -[RUNID]_adjusted_attrition.sas7bdat
* 
*  Program outputs:                                                                                                                                       
*  	-
* 
*  PARAMETERS:        
*
*
*  Programming Notes:                                                                                
*    - Contains macro %agg_report which loops through each DP, reads in specified file, output
*      dataset to MSOCDATA, and applies stratification formats if requested 
* 
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro aggregate_report_tables();

	%put =====> MACRO CALLED: aggregate_report_tables;

        %macro agg_report(infile=, outfile=, name= , stratification = N, where=1);

            proc datasets nowarn noprint nolist lib=work; delete &outfile.; quit;	
				
    		*loop through DPs;
    	    %do dps = 1 %to %eval(&num_dp.); 
    			%let dpidsiteid = %scan(&random_dplist,&dps); 
    			%let maskedID = %scan(&masked_dplist,&dps); 

    	 		%do n = 1 %to &numrunid.;
    		    %let runid = %scan(&runidlist, &n); 

    		    	/* Globalize grouplist macro variables so they exist if attrition table is requested and groups only in baseline file*/
    		    	%global grouplist_&n;

    		    	/* unmask where clause */
    		    	%let where&n = %unquote(&where);

    			   %if %sysfunc(exist(&dpidsiteid..&&runid._&infile))=0 %then %do;
    				   %put NOTE: (Sentinel) &&runid._&infile does not exist for &dpidsiteid..;
    			   %end;
    			   %else %do;
				   	%if %length(&&grouplist_&n..) > 0 | %index(&infile, attrition) %then %do;    			   
    				   data temp_&dps.; 
    				      length runid $5. dpidsiteid $6.;
    					  set &dpidsiteid..&&runid._&infile; 
    					  where &&where&n; 
    					  &name.=lowcase(&name.);
    					  dpidsiteid = "&maskedID";
    					  runid= "&runid.";
    					    %if %str("&infile.") = %str("t5_cida_gaps") %then %do;
    					      if gapnum = 999 then delete;
							  if missing(gaplength)=0 and gaplength < 0 then gaplength =0;
    					    %end;				   
    					run;

    				   *warning if no rows selected after applying the where clause;
    				    %isdata(dataset=temp_&dps.);
    				    %if %eval(&nobs.=0) %then %do;
    					   %put WARNING: (Sentinel) No rows in dataset &dpidsiteid..&&runid._&infile where &name.="&&grouplist_&n..";
    				    %end;
    								
    				   /* Aggregate Data */
    				   proc append data=temp_&dps. base=&outfile. force; run;

    				   proc datasets nowarn noprint nolist lib=work; delete temp_&dps.; quit;	
    				%end; *&&grouplist_&n..;
    				   
    			   %end;	

    			%end; *runID;
    		  %end;*loop through DPs;
			  
			  %if &stratification. = Y %then %do;
			     /* Identify stratification variables */
				 %let dataset =%substr(&outfile.,5);
				 
				 proc sql noprint;
                   select distinct(tablesub) into: allstrata separated by ' ' 
                   from tablefile
                   where dataset = "&dataset." and index(tablesub,"#") = 0;
                 quit;
				 
				 %let totalstrata = %sysfunc(countw(&allstrata));

				 data stratavars_&outfile.;
				   length strata $15 strataorder 3;
				   %do a = 1 %to &totalstrata.;
				     strata = "%scan(&allstrata.,&a.)"; 
				     strataorder = &a;
				     output;
				   %end;
				 run;

				 proc sort nodupkey data = stratavars_&outfile.;
				   by strata;
				 run;
				 
				 proc sort data = stratavars_&outfile.;
				   by strataorder;
				 run;
				 
				 proc sql noprint;
				   select count(strata) into: numstrata_&dataset. trimmed
				   from stratavars_&outfile.;
				   
				   select strata
				   into: strata1 -  :strata&&numstrata_&dataset.
				   from stratavars_&outfile.;
				 quit;			  
			  
			     /* Put stratification variables through formats to acquire full names */
                 data &outfile.;
                   set &outfile.(rename = (
                     %do s = 1 %to &&numstrata_&dataset.;
                       %if &&strata&s. = sex | &&strata&s. = race | &&strata&s. = hispanic | &&strata&s. = hhs_reg | 
                           &&strata&s. = cb_reg | &&strata&s. = month | &&strata&s. = quarter | &&strata&s. = agegroup | &&strata&s. = zip_uncertain %then %do;
                           &&strata&s. = _&&strata&s.
                       %end;
                     %end;));
					 
				   %do s = 1 %to &&numstrata_&dataset.;
				     length sortorder&s. 3;
				     
                     %if &&strata&s. = sex      %then length sex $15;;
                     %if &&strata&s. = race     %then length race $55;;
					 %if &&strata&s. = hispanic %then length hispanic $20;;
					 %if &&strata&s. = hhs_reg  %then length hhs_reg $25;;
					 %if &&strata&s. = cb_reg   %then length cb_reg $25;;
					 %if &&strata&s. = zip_uncertain %then length zip_uncertain $3;;
                  
				     %if &&strata&s. = overall %then %do;
					   sortorder&s. = 1;
					 %end;
                     %if &&strata&s. = sex | &&strata&s. = race | &&strata&s. = hispanic | &&strata&s. = hhs_reg
                         | &&strata&s. = cb_reg | &&strata&s. = zip_uncertain %then %do;
                         &&strata&s. = put(_&&strata&s., $&&strata&s..fmt.);
						 sortorder&s. = input(put(_&&strata&s.,$&&strata&s..sort.),3.);
				         drop _&&strata&s.;
                     %end;
				     %else %if &&strata&s. = month %then %do;
                       length month $10;
                       month = put(_month, monthfmt.);
					   sortorder&s. = _month;
                       drop _month;
                     %end;
					 %else %if &&strata&s. = quarter %then %do;
                       length quarter $10;
                       quarter = put(_quarter, quarterfmt.);
					   sortorder&s. = _quarter;
                       drop _quarter;
                     %end;
				     %else %if &&strata&s. = year %then %do;
					   sortorder&s. = year;
                     %end;
				     %else %if &&strata&s. = agegroup %then %do;
                       length agegroup $40;
                       agegroup = put(_agegroup, $agegroupfmt.);
					   sortorder&s. = agegroupnum;
                       drop _agegroup;
                     %end;
					 %else %if %index(&&strata&s.,covar) > 0 %then %do;
					   if &&strata&s. = 1 then sortorder&s. = 1;
					   else if &&strata&s. = 0 then sortorder&s. = 2;
                     %end;
					 %else %do;
					   sortorder&s. = 1;
					 %end;
					 label sortorder&s. = "&&strata&s.._sort";
				   %end;
                 run;
			    
	          %end;

			  %output_datasets(dataset=&outfile., outlib=msocdata);
			  
			  /* If stratification by zip3 is requested, add state values */
              %if &stratification. = Y %then %do;
			    %if %index(&allstrata.,zip3) %then %do;
                  %addstatetozip3(data = &outfile.); 
				%end;
		      %end;

        %mend agg_report;

	    %if %str("&reporttype") = %str("T1") %then %do;
			%if %index(&datasetlist.,t1cida) > 0 %then %do;
			  %agg_report(infile=t1_cida, outfile=agg_t1cida, name=group, stratification = Y, where=%nrstr(lowcase(group) in (&&grouplist_&n..))); 
			%end;
			%if %index(&datasetlist.,t1censor) > 0 %then %do;
			  %agg_report(infile=censor_cida, outfile=agg_t1censor, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..))); 
			%end;
		%end; *T1;

	    %if %str("&reporttype") = %str("T2L1") %then %do;
			%if %index(&datasetlist.,t2cida) > 0 %then %do;
			  %agg_report(infile=t2_cida, outfile=agg_t2cida, name=group, stratification = Y, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t2censor) > 0 %then %do;
			  %agg_report(infile=censor_cida, outfile=agg_t2censor, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..))); 
			%end;
			%if %index(&datasetlist.,t2followuptime) > 0 %then %do;
			  %agg_report(infile=followuptime_cida, outfile=agg_t2followuptime, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..))); 
			%end;
			%if %index(&datasetlist.,t2conc) > 0 %then %do;
			  %agg_report(infile=t2_concomitance, outfile=agg_t2conc, name=analysisgrp, stratification = Y, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..))); 
			%end;
			%if %index(&datasetlist.,t2multevent) > 0 %then %do;
			  %agg_report(infile=t2_multevent, outfile=agg_t2multevent, name=analysisgrp, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..))); 
			%end;
			%if %index(&datasetlist.,t2epigap) > 0 %then %do;
			  %agg_report(infile=t2_epigap, outfile=agg_t2epigap, name=analysisgrp, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..))); 
			%end;
			%if %index(&datasetlist.,t2overlap) > 0 %then %do;
			  %agg_report(infile=t2_overlap, outfile=agg_t2overlap, name=analysisgrp, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..))); 
			%end;
		%end; *T2L1;

    %do periodid = %eval(&look_start.) %to %eval(&look_end.);
		%if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
			%if %index(&figurelist,F1) > 0 %then %do;
			  %agg_report(infile=psdistribution_&periodid., outfile=agg_psdistribution_&periodid., name=analysisgrp, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..)));
			%end;
		%end; *T2L2 and T4L2;
		%if %sysfunc(exist(input.&treeaggfile.)) %then %do;
		  %if %index(&reporttype., TREE) > 0 %then %do;
             %let type = %substr(&reporttype,5,1);
          %end;
          %else %do;
             %let type = %substr(&reporttype.,2,1);
          %end;
		  %agg_report(infile=t&type._tree_analysis_&periodid., outfile=agg_t&type._tree_analysis_&periodid., name=treeanalysisgrp, where=%nrstr(lowcase(treeanalysisgrp) in (&&grouplist_&n..)));
		  %if %str("&reporttype") = %str("TREE3") %then %do;
		     %agg_report(infile=t3_tree_wkdays_&periodid., outfile=agg_t3_tree_wkdays_&periodid., name=treeanalysisgrp, where=%nrstr(lowcase(treeanalysisgrp) in (&&grouplist_&n..)));
		  %end; /*TREE3*/
		%end; /*TREEAGGFILE exists*/
	%end; *periodid;

	    %if %str("&reporttype") = %str("T4L1") %then %do;
			%if %sysfunc(findw(&datasetlist,t4preg))%then %do;
			  %agg_report(infile=t4_cida_preg, outfile=agg_t4preg, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..))); 
			%end;
			%if %sysfunc(findw(&datasetlist,t4preggestwk)) %then %do;
			  %agg_report(infile=t4_cida_preg_gestwk, outfile=agg_t4preggestwk, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..))); 
			%end;
			%if %sysfunc(findw(&datasetlist,t4nopreg))%then %do;
			  %agg_report(infile=t4_cida_nopreg, outfile=agg_t4nopreg, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %sysfunc(findw(&datasetlist,t4nopreggestwk)) %then %do;
			  %agg_report(infile=t4_cida_nopreg_gestwk, outfile=agg_t4nopreggestwk, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..))); 
			%end;	  
		%end; *T4L1;

	    %if %str("&reporttype") = %str("T5") %then %do;
			%if %index(&datasetlist.,t5episdur) > 0 %then %do;
				%agg_report(infile=t5_cida_episdur, outfile=agg_t5episdur, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t5censor) > 0 %then %do;
			  %agg_report(infile=t5_cida_episdur_censor, outfile=agg_t5censor, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t5disp) > 0 %then %do;
			  %agg_report(infile=t5_cida_disp_by_daysupp, outfile=agg_t5disp, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t5dose) > 0 %then %do;
			  %agg_report(infile=t5_cida_dose, outfile=agg_t5dose, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t5gaps) > 0 %then %do;
			  %agg_report(infile=t5_cida_gaps, outfile=agg_t5gaps, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t5first) > 0 %then %do;
			  %agg_report(infile=t5_cida_firsteps, outfile=agg_t5first, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
		%end; *T5;

	    %if %str("&reporttype") = %str("T6") %then %do;
			%if %index(&datasetlist.,t6counts) > 0 %then %do;
			  %agg_report(infile=t6_utilcounts, outfile=agg_t6counts, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t6trend) > 0 %then %do;
			  %agg_report(infile=t6_trendcounts, outfile=agg_t6trend, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t6disp) > 0 %then %do;
			  %agg_report(infile=t6_utildispstats, outfile=agg_t6disp, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
		    %end;
			%if %index(&datasetlist.,t6episdur) > 0 %then %do;
			  %agg_report(infile=t6_utilepisdurstats, outfile=agg_t6episdur, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t6uptake) > 0 %then %do;
			   %agg_report(infile=t6_utiluptakestats, outfile=agg_t6uptake, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t6censor) > 0 %then %do;
			  %agg_report(infile=t6_utilepis_censor, outfile=agg_t6censor, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t6switchepisdur) > 0 %then %do;
			   %agg_report(infile=t6_switchepisdurstats, outfile=agg_t6switchepisdur, name=analysisgrp, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t6plota) > 0 %then %do;
			  %agg_report(infile=t6_switchplota, outfile=agg_t6plota, name=analysisgrp, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..)));
			%end;
			%if %index(&datasetlist.,t6plotb) > 0 %then %do;
			  %agg_report(infile=t6_switchplotb, outfile=agg_t6plotb, name=analysisgrp, where=%nrstr(lowcase(analysisgrp) in (&&grouplist_&n..)));
			%end;

			%isdata(dataset=groupsfile);
        	%if %eval(&nobs.>0) %then %do;			
			  %agg_report(infile=t6_productsdates, outfile=agg_t6_productsdates, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%end;
			%else %do; 
				data agg_t6_productsdates;
				format runid $5. dpidsiteid $6. group $40. productmarketingdate productapprovaldate Otherproductdate computedstartmarketingdate date9.;
				call missing(of _ALL_);
				stop;
				run;
			%end;			
		%end; *T6;

		/* Code distribution */
		%if &output_code_distribution. eq Y %then %do;
			%agg_report(infile=distindex, outfile=agg_distindex, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
			%agg_report(infile=distindexmap, outfile=agg_distindexmap, name=group, where=%nrstr(lowcase(group) in (&&grouplist_&n..)));
		%end;

		/* Attrition tables */
		%agg_report(infile=attrition, outfile=agg_attrition, name=group);
        %isdata(dataset=master_mil);
        %if %eval(&nobs.>0) %then %do;
		  %agg_report(infile=mil_attrition, outfile=agg_mil_attrition, name=analysisgrp);
        %end;

        %if %index(&reporttype,L2) %then %do;
          %do periodid = %eval(&look_start.) %to %eval(&look_end.);
		  %agg_report(infile=adjusted_attrition_&periodid., outfile=agg_adjusted_attrition_&periodid., name=analysisgrp);
          %end;
        %end;

	%put =====> END MACRO: aggregate_report_tables;

%mend aggregate_report_tables;
