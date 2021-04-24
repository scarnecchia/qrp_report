****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: aggregate_report_tables.sas  
* Created (mm/dd/yyyy): 01/20/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro imports and aggregates the following tables relevant to report:

*			-[RUNID]_t1_cida.sas7bdat 
*			-[RUNID]_censor_cida.sas7bdat 

*			-[RUNID]_t2_cida.sas7bdat 
*			-[RUNID]_t2_followuptime_cida.sas7bdat 
*			-[RUNID]_censor_cida.sas7bdat 
*			-[RUNID]_t2_concomitance.sas7bdat 
*			-[RUNID]_t2_multevent.sas7bdat 
*			-[RUNID]_t2_epigap.sas7bdat 
*			-[RUNID]_t2_overlap.sas7bdat 

*			-[RUNID]_psdistribution_[LOOK].sas7bdat 

*			-[RUNID]_t4_cida_preg.sas7bdat 
*			-[RUNID]_t4_cida_preg_gestwk.sas7bdat 
*			-[RUNID]_t4_cida_nopreg.sas7bdat 
*			-[RUNID]_t4_cida_nopreg_gestwk.sas7bdat 

*			-[runid]_t5_cida_disp_by_daysupp
*			-[runid]_t5_cida_episdur
*			-[runid]_t5_cida_episdur_censor
*			-[runid]_t5_cida_gaps
*			-[runid]_t5_cida_firsteps

*			-[runid]_t6_utilcounts
*     		-[runid]_t6_trendcounts
*			-[runid]_t6_utildispstats
*			-[runid]_t6_utilepis_censor
*			-[runid]_t6_utilepisdurstats
*			-[runid]_t6_utiluptakestats
*			-[runid]_t6_switchepisdurstats
*			-[runid]_t6_switchplota
*			-[runid]_t6_switchplotb

*			-[RUNID]_distindex.sas7bdat 
*			-[RUNID]_distindexmap.sas7bdat 
*
*  Program inputs:                                                                                   
*  	-
* 
*  Program outputs:                                                                                                                                       
*  	-
* 
*  PARAMETERS:        

*  Programming Notes:                                                                                
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

        %macro agg_report(infile=, outfile=, name=);

            proc datasets nowarn noprint nolist lib=work; delete &outfile.; quit;	
				
    		*loop through DPs;
    	    %do dps = 1 %to %eval(&num_dp.); 
    			%let dpidsiteid = %scan(&random_dplist,&dps); 
    			%let maskedID = %scan(&masked_dplist,&dps); 

    	 		%do n = 1 %to &numrunid.;
    		    %let runid = %scan(&runidlist, &n); 

    			   %if %sysfunc(exist(&dpidsiteid..&&runid._&infile))=0 %then %do;
    				   %put NOTE: (Sentinel) &&runid._&infile does not exist for &dpidsiteid..;
    			   %end;
    			   %else %do;
				   	%if %length(&&grouplist_&n..) > 0 %then %do;    			   
    				   data temp_&dps.; 
    				      length runid $5. dpidsiteid $6.;
    					  set &dpidsiteid..&&runid._&infile; 
    					  where lowcase(&name.) in (&&grouplist_&n..); 
    					  &name.=lowcase(&name.);
    					  dpidsiteid = "&maskedID";
    					  runid= "&runid.";
    					    %if %str("&infile.") = %str("t5_cida_gaps") %then %do;
    					      if gapnum = 999 then delete;
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

        %mend agg_report;

	    %if %str("&reporttype") = %str("T1") %then %do;
			%if %index(&datasetlist.,t1cida) > 0 %then %do;
			  %agg_report(infile=t1_cida, outfile=agg_t1cida, name=group); 
			%end;
			%if %index(&datasetlist.,t1censor) > 0 %then %do;
			  %agg_report(infile=censor_cida, outfile=agg_t1censor, name=group); 
			%end;
		%end; *T1;

	    %if %str("&reporttype") = %str("T2L1") %then %do;
			%if %index(&datasetlist.,t2cida) > 0 %then %do;
			  %agg_report(infile=t2_cida, outfile=agg_t2cida, name=group);
			%end;
			%if %index(&datasetlist.,t2censor) > 0 %then %do;
			  %agg_report(infile=censor_cida, outfile=agg_t2censor, name=group); 
			%end;
			%if %index(&datasetlist.,t2followuptime) > 0 %then %do;
			  %agg_report(infile=followuptime_cida, outfile=agg_t2followuptime, name=group); 
			%end;
			%if %index(&datasetlist.,t2conc) > 0 %then %do;
			  %agg_report(infile=t2_concomitance, outfile=agg_t2conc, name=analysisgrp); 
			%end;
			%if %index(&datasetlist.,t2multevent) > 0 %then %do;
			  %agg_report(infile=t2_multevent, outfile=agg_t2multevent, name=analysisgrp); 
			%end;
			%if %index(&datasetlist.,t2epigap) > 0 %then %do;
			  %agg_report(infile=t2_epigap, outfile=agg_t2epigap, name=analysisgrp); 
			%end;
			%if %index(&datasetlist.,t2overlap) > 0 %then %do;
			  %agg_report(infile=t2_overlap, outfile=agg_t2overlap, name=analysisgrp); 
			%end;
		%end; *T2L1;

    %do periodid = %eval(&look_start.) %to %eval(&look_end.);
		%if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
			%if %index(&figurelist,F1) > 0 %then %do;
			  %agg_report(infile=psdistribution_&periodid., outfile=agg_psdistribution_&periodid., name=analysisgrp);
			%end;
		%end; *T2L2 and T4L2;
	%end; *periodid;

	    %if %str("&reporttype") = %str("T4L1") %then %do;
			%if %index(&datasetlist.,t4preg) > 0 %then %do;
			  %agg_report(infile=t4_cida_preg, outfile=agg_t4preg, name=group); 
			%end;
			%if %index(&datasetlist.,t4preggestwk) > 0 %then %do;
			  %agg_report(infile=t4_cida_preg_gestwk, outfile=agg_t4preggestwk, name=group); 
			%end;
			%if %index(&datasetlist.,t4nopreg) > 0 %then %do;
			  %agg_report(infile=t4_cida_nopreg, outfile=agg_t4nopreg, name=group); 
			%end;
			%if %index(&datasetlist.,t4nopreggestwk) > 0 %then %do;
			  %agg_report(infile=t4_cida_nopreg_gestwk, outfile=agg_t4nopreggestwk, name=group); 
			%end;			
		%end; *T4L1;

	    %if %str("&reporttype") = %str("T5") %then %do;
			%if %index(&datasetlist.,t5episdur) > 0 %then %do;
				%agg_report(infile=t5_cida_episdur, outfile=agg_t5episdur, name=group);
			%end;
			%if %index(&datasetlist.,t5censor) > 0 %then %do;
			  %agg_report(infile=t5_cida_episdur_censor, outfile=agg_t5censor, name=group);
			%end;
			%if %index(&datasetlist.,t5disp) > 0 %then %do;
			  %agg_report(infile=t5_cida_disp_by_daysupp, outfile=agg_t5disp, name=group);
			%end;
			%if %index(&datasetlist.,t5gaps) > 0 %then %do;
			  %agg_report(infile=t5_cida_gaps, outfile=agg_t5gaps, name=group);
			%end;
			%if %index(&datasetlist.,t5first) > 0 %then %do;
			  %agg_report(infile=t5_cida_firsteps, outfile=agg_t5first, name=group);
			%end;
		%end; *T5;

	    %if %str("&reporttype") = %str("T6") %then %do;
			%if %index(&datasetlist.,t6counts) > 0 %then %do;
			  %agg_report(infile=t6_utilcounts, outfile=agg_t6counts, name=group);
			%end;
			%if %index(&datasetlist.,t6trend) > 0 %then %do;
			  %agg_report(infile=t6_trendcounts, outfile=agg_t6trend, name=group);
			%end;
			%if %index(&datasetlist.,t6disp) > 0 %then %do;
			  %agg_report(infile=t6_utildispstats, outfile=agg_t6disp, name=group);
		    %end;
			%if %index(&datasetlist.,t6episdur) > 0 %then %do;
			  %agg_report(infile=t6_utilepisdurstats, outfile=agg_t6episdur, name=group);
			%end;
			%if %index(&datasetlist.,t6uptake) > 0 %then %do;
			   %agg_report(infile=t6_utiluptakestats, outfile=agg_t6uptake, name=group);
			%end;
			%if %index(&datasetlist.,t6censor) > 0 %then %do;
			  %agg_report(infile=t6_utilepis_censor, outfile=agg_t6censor, name=group);
			%end;
			%if %index(&datasetlist.,t6switchepisdur) > 0 %then %do;
			   %agg_report(infile=t6_switchepisdurstats, outfile=agg_t6switchepisdur, name=analysisgrp);
			%end;
			%if %index(&datasetlist.,t6plota) > 0 %then %do;
			  %agg_report(infile=t6_switchplota, outfile=agg_t6plota, name=analysisgrp);
			%end;
			%if %index(&datasetlist.,t6plotb) > 0 %then %do;
			  %agg_report(infile=t6_switchplotb, outfile=agg_t6plotb, name=analysisgrp);
			%end;
		%end; *T6;

		/* Aggregate covariate profile tables */
		%if &numprofilecovarstoinclude > 0 %then %do;

			proc sql noprint;
				select distinct cohort 
				into :profilecohortlist separated by ' '
				from baselinefile
				where not missing(profilecovarstoinclude);
			quit;

		 %do periodid = %eval(&look_start.) %to %eval(&look_end.);
		   %do b = 1 %to %sysfunc(countw(&profilecohortlist));
		   	%let profilecohort = %scan(&profilecohortlist,&b);
			%agg_report(infile=profile_&profilecohort._&periodid, outfile=agg_&profilecohort._&periodid, name=group);

			data agg_profile;
		   	set
		   	%if %sysfunc(exist(agg_profile)) %then %do;
		   	 agg_profile
		   	%end;
		   	 agg_&profilecohort._&periodid(in=a);
		   	 length profiletablename $20;
		   	if a then profiletablename=cats(runid,"_profile_&profilecohort._&periodid.");
		    run;

		   %end;

		 %end;

		%end;

		/* Code distribution */
		%if &output_code_distribution. eq Y %then %do;
			%agg_report(infile=distindex, outfile=agg_distindex, name=group);
			%agg_report(infile=distindexmap, outfile=agg_distindexmap, name=group);
		%end;

	%put =====> END MACRO: aggregate_report_tables;

%mend aggregate_report_tables;
