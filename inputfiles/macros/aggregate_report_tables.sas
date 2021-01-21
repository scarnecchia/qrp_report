****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: aggregate_report_tables.sas  
*
* Created (mm/dd/yyyy): 01/20/2021
* Last modified: 01/20/2021
* Version: 1.1
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

*			-[RUNID]_t4_cida_preg.sas7bdat 
*			-[RUNID]_t4_cida_preg_gestwk.sas7bdat 

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

	*loop through DPs;
      %do dp = 1 %to %eval(&num_dp.); 
		%let DPID = %scan(&random_dplist,&dp); 
		%let maskedID = %scan(&masked_dpid_list,&dp); 

		%macro agg_report(infile=, outfile=, name=);

	 		%do n = 1 %to &numrunid.;
		    %let runid = %scan(&runidlist, &n); 

			    %do grpcnt=1 %to %eval(&&numgroups_&n..);
	            %let group = %scan(&&grouplist_&n.., &grpcnt);

					data _null_;
					set &groupsfile.;
            		where runid = "&runid.";
					where lowcase(group) = lowcase("&group.");
            		call symputx('order', order);
					run;

				   %if %sysfunc(exist(&DPID..&&runid._&infile))=0 %then %do;
					   %put WARNING: &&runid._&infile does not exist for &DPID.. Please confirm correct DPID and path location specified. Program will abort;
					   %abort; 
				   %end;
				   %else %do;
					   data temp_&dp._&group._&order.; 
						  set &DPID..&&runid._&infile; 
						  where lowcase(&name.)=lowcase("&group."); 
						  &name.=lowcase(&name.);
						  dpidsiteid = "&maskedID";
						  runid= "&runid.";
						  order= &order.;
						    %if %str("&infile.") = %str("t5_cida_gaps") %then %do;
						      if gapnum = 999 then delete;
						    %end;				   
						  run;
									
					   /* Aggregate Data */
					   %if ("&dp." eq "1") and &grpcnt=1 and &n.=1 %then %do;
						  data &outfile.; set temp_&dp._&group._&order.; run;
					   %end;
					   %else %do;
						  proc append data=temp_&dp._&group._&order. base=&outfile. force; run;
					   %end;
					   proc datasets nowarn noprint nolist lib=work; delete temp_&dp._&group._&order.; quit;	
				   %end;	

				 %end; *groups;
			%end; *runID;
		%mend agg_report;

	    %if %str("&reporttype") = %str("T1") %then %do;
			%if %index((lowcase(&datasetlist.)),t1cida) > 0 %then %do;
			  %agg_report(infile=t1_cida, outfile=agg_t1cida, name=group); 
			%end;
			%if %index((lowcase(&datasetlist.)),t1censor) > 0 %then %do;
			  %agg_report(infile=censor_cida, outfile=agg_t1censor, name=group); 
			%end;
		%end; *T1;

	    %if %str("&reporttype") = %str("T2L1") %then %do;
			%if %index((lowcase(&datasetlist.)),t2cida) > 0 %then %do;
			  %agg_report(infile=t2_cida, outfile=agg_t2cida, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t2censor) > 0 %then %do;
			  %agg_report(infile=censor_cida, outfile=agg_t2censor, name=group); 
			%end;
			%if %index((lowcase(&datasetlist.)),t2followuptime) > 0 %then %do;
			  %agg_report(infile=t2_followuptime_cida, outfile=agg_t2followuptime, name=group); 
			%end;
			%if %index((lowcase(&datasetlist.)),t2conc) > 0 %then %do;
			  %agg_report(infile=t2_concomitance, outfile=agg_t2conc, name=analysisgrp); 
			%end;
			%if %index((lowcase(&datasetlist.)),t2multevent) > 0 %then %do;
			  %agg_report(infile=t2_multevent, outfile=agg_t2multevent, name=analysisgrp); 
			%end;
			%if %index((lowcase(&datasetlist.)),t2epigap) > 0 %then %do;
			  %agg_report(infile=t2_epigap, outfile=agg_t2epigap, name=analysisgrp); 
			%end;
			%if %index((lowcase(&datasetlist.)),t2overlap) > 0 %then %do;
			  %agg_report(infile=t2_overlap, outfile=agg_t2overlap, name=analysisgrp); 
			%end;
		%end; *T2L1;

	    %if %str("&reporttype") = %str("T4L1") %then %do;
			%if %index((lowcase(&datasetlist.)),t4preg) > 0 %then %do;
			  %agg_report(infile=t4_cida_preg, outfile=agg_t4preg, name=group); 
			%end;
			%if %index((lowcase(&datasetlist.)),t4preggestwk) > 0 %then %do;
			  %agg_report(infile=t4_cida_preg_gestwk, outfile=agg_t4preggestwk, name=group); 
			%end;
		%end; *T4L1;

	    %if %str("&reporttype") = %str("T5") %then %do;
			%if %index((lowcase(&datasetlist.)),t5episdur) > 0 %then %do;
				%agg_report(infile=t5_cida_episdur, outfile=agg_t5episdur, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t5censor) > 0 %then %do;
			  %agg_report(infile=t5_cida_episdur_censor, outfile=agg_t5censor, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t5disp) > 0 %then %do;
			  %agg_report(infile=t5_cida_disp_by_daysupp, outfile=agg_t5disp, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t5gaps) > 0 %then %do;
			  %agg_report(infile=t5_cida_gaps, outfile=agg_t5gaps, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t5first) > 0 %then %do;
			  %agg_report(infile=t5_cida_firsteps, outfile=agg_t5first, name=group);
			%end;
		%end; *T5;

	    %if %str("&reporttype") = %str("T6") %then %do;
			%if %index((lowcase(&datasetlist.)),t6counts) > 0 %then %do;
			  %agg_report(infile=t6_utilcounts, outfile=agg_t6counts, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t6trend) > 0 %then %do;
			  %agg_report(infile=t6_trendcounts, outfile=agg_t6trend, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t6disp) > 0 %then %do;
			  %agg_report(infile=t6_utildispstats, outfile=agg_t6disp, name=group);
		    %end;
			%if %index((lowcase(&datasetlist.)),t6episdur) > 0 %then %do;
			  %agg_report(infile=t6_utilepisdurstats, outfile=agg_t6episdur, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t6uptake) > 0 %then %do;
			   %agg_report(infile=t6_utiluptakestats, outfile=agg_t6uptake, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t6censor) > 0 %then %do;
			  %agg_report(infile=t6_utilepis_censor, outfile=agg_t6censor, name=group);
			%end;
			%if %index((lowcase(&datasetlist.)),t6switchepisdur) > 0 %then %do;
			   %agg_report(infile=t6_switchepisdurstats, outfile=agg_t6switchepisdur, name=analysisgrp);
			%end;
			%if %index((lowcase(&datasetlist.)),t6plota) > 0 %then %do;
			  %agg_report(infile=t6_switchplota, outfile=agg_t6plota, name=analysisgrp);
			%end;
			%if %index((lowcase(&datasetlist.)),t6plotb) > 0 %then %do;
			  %agg_report(infile=t6_switchplotb, outfile=agg_t6plotb, name=analysisgrp);
			%end;
		%end; *T6;

	%end;*loop through DPs;

	%put =====> END MACRO: aggregate_report_tables;

%mend aggregate_report_tables;


