****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_psdistribution_output.sas  
* Created (mm/dd/yyyy): 03/17/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates both aggregated and DP specific PS histograms
*                                        
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*
*  PARAMETERS:                                                                       
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

%macro l2_psdistribution_output;

	%macro output_histogram(type=, weight=);

		%isdata(dataset=repdata.Figure&figurenum.&tableletter.);
		%if %eval(&nobs=0) %then %do;
		data repdata.Figure&figurenum.&tableletter.;
		set histogram_&i. (where=(runid="&runid." and order="&loopcount." and subgroup="&subgroup." and subgroupcat="&subgroupcat."));
		run;
		%end;

		proc sgplot data=histogram_&i. (where=(runid="&runid." and order="&loopcount." and subgroup="&subgroup." and subgroupcat="&subgroupcat."));  
			histogram bin_eoi / freq = _eoi    transparency=0.8 fillattrs=(color=blue) binstart = 0 binwidth = 0.025;
			histogram bin_ref / freq =_ref  transparency=0.8 fillattrs=(color=red) binstart = 0 binwidth = 0.025;
			keylegend / location=outside position=bottom noborder valueattrs=(size=&fontsize. family=&font.);
			xaxis label = "PS" labelattrs=(size=&fontsize. family=&font. color=gray) valueattrs=(size=&fontsize. family=&font. color=gray) values=(0 to 1 by .2) offsetmax = .02;
			yaxis display=(noline) label="Percent" labelattrs=(size=&fontsize. family=&font. color=gray) valueattrs=(size=&fontsize. family=&font. color=gray);
			where type = "&type." and weight="&weight." and dp = "&maskeddpid." and lowcase(analysisgrp) = "&analysisgrp.";
		run;
	%mend output_histogram;

  	options orientation=portrait;
  	options nocenter;
  	ods startpage = now;
  	ods startpage = no;
    %let tablecount=1;
    %let tableletter=a;

	%do i = %eval(&look_start) %to %eval(&look_end); /*loop through periods*/

	    %do loopcount = 1 %to &numl2comparisons.; 

			data _NULL_;
            set l2comparisonfile(where=(order=&loopcount.));
            call symputx('runid', runid);
            call symputx('analysisgrp', analysisgrp);
            call symputx('OutputPSDistribution', OutputPSDistribution);
       		run;

			%isdata(dataset=labelfile);
			%let grouplabel=&analysisgrp.;

		    %if %eval(&nobs>0) %then %do;
			  data _NULL_;
			  set labelfile(where=(lowcase(labeltype)='grouplabel'));
			  if group="&analysisgrp." and runid="&runid.";
              call symputx("grouplabel",  %quote(Label));
			  run;
			%end;

  			%if &OutputPSDistribution. = Y %then %do;

				proc sql noprint;
		        select strip(file) into: psfile
		        from pscs_masterinputs
		        where analysisgrp = "&analysisgrp." and runid = "&runid";
		        quit;

				%let ratiohist =;
	            %let caliperhist =;
				%let andafter =;
	            %let matchtype = ;
	            %let analysisgrphist = ;
	            %let analysisgrpschemelong = ;
				%let pstrim =;

            	%if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;
                	data _null_; 
                  	set pscs_masterinputs (where=(lowcase(analysisgrp)="&analysisgrp."));
                    call symputx("psestimategrp", lowcase(psestimategrp));
                        %if &psfile. = psmatchfile  %then %do;
							call symputx("matchtype",strip(upcase(ratio)));
							call symputx("ratiohist","1:"||strip(ceiling));
                            if upcase(ratio) = "F" then call symput("andafter", " and After");
                            call symputx("caliperhist", caliper);
                        %end;
                        %if &psfile = iptwfile %then %do;
						   call symput("andafter", " and After");
                           if upcase(ipweight)= 'ATE' then call symputx("analysisgrpschemelong", %str(", Inverse Probability of Treatment Weighted, Average Treatment Effect (ATE)"));
                           else if upcase(ipweight)= 'ATES' then call symputx("analysisgrpschemelong", %str(", Inverse Probability of Treatment Weighted, Average Treatment Effect Stabilized (ATES)"));
                           else if upcase(ipweight)= 'ATT' then call symputx("analysisgrpschemelong", %str(", Inverse Probability of Treatment Weighted, Average Treatment Effect in the Treated (ATT)"));
                        %end;
						%else %if &psfile = stratificationfile %then %do;
						   if upcase(strataweight) in ("ATE", "ATT") then do;
						     call symput("andafter", " and After");
                             call symputx("analysisgrphist","STRATAWEIGHT");
							 call symputx("pstrim","pstrim");
                             if upcase(strataweight) = "ATE" then call symputx("analysisgrpschemelong", %str(", Stratum Weighted, Average Treatment Effect (ATE)"));
                             else if upcase(strataweight)= "ATT" then call symputx("analysisgrpschemelong", %str(", Stratum Weighted, Average Treatment Effect in the Treated (ATT)"));
						   end;
                           if "&treeaggindicator." = "Y" then call symput("andafter", " and After");
                        %end;
                	run; 
	                data _null_; 
	                    set psest_masterinputs (where=(lowcase(psestimategrp)="&psestimategrp."));
	                    call symputx('eoi', eoi) ;
	                    call symputx('ref', ref) ;    
	                run;

					%let numsubgroups=0;
					%let subgroup=;
					%let subgroupcat=;
					%let subgrouptitle=;

					proc sort nodupkey data=Pscs_masterinputs(where=(analysisgrp="&analysisgrp." and runid="&runid." and not missing(subgroup))) 
										   out=_subgroups(keep=subgroup subgroupcat subgrouporder subgroupcatorder combinedlabel);
					by subgrouporder subgroupcatorder;
					run;

					proc sql noprint;
					select count(*) into :numsubgroups from _subgroups;
					quit;

					%do sub=0 %to &numsubgroups.;

						%let max_eoi=0;
						%let max_ref=0;						
						
						%if &sub. > 0 %then %do;
							data _null_;
							set _subgroups;
							if _N_=&sub.;
							call symputx("SubGroup",lowcase(strip(subgroup)));
						    call symputx("SubgroupCat",upcase(strip(subgroupcat)));
							call symputx("subgrouptitle",combinedlabel);
							run;

							proc sql noprint;
								select max(_eoi), max(_ref) into :max_eoi, :max_ref
								from histogram_&i. (where=(runid="&runid." and order="&loopcount." and subgroup="&subgroup." and subgroupcat="&subgroupcat."));
							quit;
						%end;
						%else %do;
							proc sql noprint;
								select max(_eoi), max(_ref) into :max_eoi, :max_ref
								from histogram_&i. (where=(runid="&runid." and order="&loopcount." and subgroup="" and subgroupcat=""));
							quit;
						%end;
	
						%if &max_eoi. > 0 and &max_ref. > 0 %then %do;

						%put Looping on subgroup &SubGroup.: &SubgroupCat.;

	              		%let num_loops = 0;
	              		%if &stratifybydp. = Y %then %let num_loops = &num_dp;
	              
	                	ods graphics on / width=5in scale=on;

		                /*Trick excel to create new sheet*/
						%if &destination. = excel %then %do;
		                ods excel options(sheet_interval="table");
		                ods exclude all;
		                data _null_;
		                file print;
		                put _all_;
		                run;
		                ods select all;
						%end;						

						%if &numsubgroups.=0 %then %let tablecount = 0;
		                %tableletter();
		                %if &destination. = excel %then %do;
		                ods excel options(sheet_interval="none" sheet_name = "Figure &figurenum.&tableletter." tab_color="DeepSkyBlue" flow='none');
		                %end;

		                proc odstext pagebreak=yes;
			                p %quote("Figure &figurenum.&tableletter.. Histograms Depicting Propensity Score Distributions Before&andafter Adjustment for &grouplabel. ^{newline} in the &database. from &startdateformatted. to &&enddate&i.formatted.&subgrouptitle. ") /
			                style=[just=L font_weight=bold bordertopcolor=black borderbottomcolor=black tagattr='mergeacross:12'];
							%if &destination. = pdf %then %do;
								ODS PDF BOOKMARKGEN = ON; 
								ods proclabel = "Figure &figurenum.&tableletter.";
							%end;
		                run;
						%if &destination. = pdf %then %do;
							ODS PDF BOOKMARKGEN = OFF; 
							%end;

			                %let maskeddpid = agg;
			                %let dps= 0;
			                %let hisanalysis = Unadjusted;
			                %if &psfile. = iptwfile |(&psfile. = stratificationfile & &treeaggindicator. = Y) |"&analysisgrphist." ="STRATAWEIGHT" %then %do;
			                  proc odstext ;
								p "Unweighted Propensity Score Distribution Before Trimming" / style=[just=L color=black tagattr='mergeacross:12'];
		                %end;
						%else %do;
						  	proc odstext ;
								p "Unadjusted Propensity Score Distribution" / style=[just=L color=black tagattr='mergeacross:12'];
						%end;
						
		                %output_histogram(type=Unadjusted, weight=Unweighted);

	                  	%if "&matchtype" = "F" %then %do;
		                  proc odstext ;
							p " ";
							p "Propensity Score Fixed Ratio &ratiohist. Adjusted Cohort, Matched Caliper = &caliperhist." / style=[just=L color=black tagattr='mergeacross:12'];
		                  %let hisanalysis = Adjusted;
		                  %output_histogram(type=Adjusted, weight=Unweighted);
	                  	%end;

	                  	%if &psfile. = iptwfile | "&analysisgrphist." ="STRATAWEIGHT" | 
                           (&psfile. = stratificationfile & &treeaggindicator. = Y) %then %do;
	                    
		                    proc sql noprint;
		                      select distinct(weight)
		                      into :weight_type 
		                      separated by ' '
		                      from histogram_&i. (where=(runid="&runid." and order="&loopcount."  and subgroup="&subgroup." and subgroupcat="&subgroupcat."));
		                    quit;

		                    %do analysisgrpcount = 1 %to %sysfunc(countw(&weight_type));
		                      %let analysisgrp_type = %scan(&weight_type,&analysisgrpcount);

		                      %if &analysisgrp_type. = Weighted %then %do;
		                        ods startpage = now;
								proc odstext ;
									p " ";
									p "Weighted Propensity Score Distribution After Trimming&analysisgrpschemelong." / style=[just=L color=black tagattr='mergeacross:12'];
		                      %end;
							  %else %do;
							    proc odstext ;
									p " ";
									p "Unweighted Propensity Score Distribution After Trimming" / style=[just=L color=black tagattr='mergeacross:12'];
							  %end;
		                      
		                      %let hisanalysis = Adjusted;
		                      %output_histogram(type=Adjusted, weight=&analysisgrp_type);

		                    %end; *analysisgrpcount;
	                  	%end; * iptwfile;                

	                	%if &stratifybydp. = Y %then %do;
					  		ods startpage = now;
					  		proc odstext pagebreak=yes;
	                      		p " ";
					  		run;
					  
	                  		%do dps = 1 %to &num_loops;
			                  	ods startpage = now;
								proc odstext pagebreak=yes;
					                p " ";
								run;
			                 
			                    %let DPSITEID = %scan(&random_dplist,&dps);
			                    %let maskeddpid = %scan(&masked_dplist,&dps);
			                 
			                    /*output histogram*/
			                    %let hisanalysis = Unadjusted;
			                    %if &psfile. = iptwfile | "&analysisgrphist." ="STRATAWEIGHT" | 
                                   (&psfile. = stratificationfile & &treeaggindicator. = Y) %then %do;
			                      proc odstext ;
									p "Unweighted Propensity Score Distribution Before Trimming" / style=[just=L color=black tagattr='mergeacross:12'];
			                    %end;
							    %else %do;
							      proc odstext ;
									p "Unadjusted Propensity Score Distribution" / style=[just=L color=black tagattr='mergeacross:12'];
							    %end;
								proc odstext ;
									p "Data Partner %substr(&MaskedDPID.,3)" / style=[just=L color=black];
			                    %output_histogram(type=Unadjusted, weight=Unweighted);

			                    %if "&matchtype" = "F" %then %do;
			                      %let hisanalysis = Adjusted;
			                      proc odstext ;
									p " ";
									p "Propensity Score Fixed Ratio &ratiohist. Adjusted Cohort, Matched Caliper = &caliperhist." / style=[just=L color=black tagattr='mergeacross:12'];
									p "Data Partner %substr(&MaskedDPID.,3)" / style=[just=L color=black];
			                      %output_histogram(type=Adjusted, weight=Unweighted);
			                    %end;
								
								%if &psfile. = iptwfile | "&analysisgrphist." ="STRATAWEIGHT" | 
                                   (&psfile. = stratificationfile & &treeaggindicator. = Y) %then %do;
			                    
				                      proc sql noprint;
				                        select distinct(weight)
				                        into :weight_type 
				                        separated by ' '
				                        from histogram_&i. (where=(runid="&runid." and order="&loopcount."  and subgroup="&subgroup." and subgroupcat="&subgroupcat."));
				                      quit;

									%do analysisgrpcount = 1 %to %sysfunc(countw(&weight_type));
										%let analysisgrp_type = %scan(&weight_type,&analysisgrpcount);

											%if &analysisgrp_type. = Weighted %then %do;
											  ods startpage = now;
											  proc odstext ;
												p " ";
												p "Weighted Propensity Score Distribution After Trimming&analysisgrpschemelong." / style=[just=L color=black tagattr='mergeacross:12'];
											%end;
											%else %do;
											  proc odstext ;
												p " ";
												p "Unweighted Propensity Score Distribution After Trimming" / style=[just=L color=black tagattr='mergeacross:12'];
											%end;
											proc odstext ;
												p "Data Partner %substr(&MaskedDPID.,3)" / style=[just=L color=black];
											%let hisanalysis = Adjusted;
											%output_histogram(type=Adjusted, weight=&analysisgrp_type);
				                    %end; *analysisgrpcount;
								%end; *iptwfile;  
			                %end; * dps;  
	                	%end; *stratify by DP;  
						%end; *subgroupcat;
					%end;  *sufficient data to plot histogram;
			  	ods startpage = now;

				%let figurenum = %eval(&figurenum.+1); 
				%let tablecount = 1;
				%let tableletter =a;

				%end; *psfile;
		    %end; *OutputPSDistribution;			
	    %end; *numl2comparisons;
	%end; *look;

	%if &destination. = pdf %then %do;
		ODS PDF BOOKMARKGEN = ON;
	%end; 	

%mend l2_psdistribution_output;
