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
		set histogram_&i. (where=(runid="&runid." and order="&loopcount."));
		run;
		%end;

		proc sgplot data=histogram_&i. (where=(runid="&runid." and order="&loopcount."));  
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
			  if group="&analysisgrp.";
              call symputx("grouplabel",  %quote(Label));
			  run;
			%end;

  			%if &OutputPSDistribution. = Y %then %do;
				%let figurenum=1;

				proc sql noprint;
		        select strip(file) into: psfile
		        from pscs_masterinputs
		        where analysisgrp = "&analysisgrp.";
		        quit;

				%let ratiohist =;
	            %let caliperhist =;
				%let andafter =;
	            %let matchtype = ;
	            %let analysisgrphist = ;
	            %let analysisgrpchemelong = ;
				%let pstrim =;

            %if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;
                data _null_; 
                  set pscs_masterinputs (where=(lowcase(analysisgrp)="&analysisgrp."));
                    call symputx("psestimategrp", lowcase(psestimategrp));
                        %if &psfile. = psmatchfile  %then %do;
                            if upcase(ratio) = "F" then do;
							    call symput("andafter", " and After");
                                call symputx("matchtype",'F');
                                call symputx("ratiohist","1:"||strip(ceiling)); 
                            end;
                            else if upcase(ratio) = "V" then do;
                                call symputx("matchtype",'V');
                                call symputx("ratiohist","1:"||strip(ceiling));
                            end;
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
                        %end;
                run; 
                data _null_; 
                    set psest_masterinputs (where=(lowcase(psestimategrp)="&psestimategrp."));
                    call symputx('eoi', eoi) ;
                    call symputx('ref', ref) ;    
                run;

              %let num_loops = 0;
              %if &stratifybydp. = Y %then %do;
                %let num_loops = &num_dp;
              %end;

              %do i = %eval(&look_start) %to %eval(&look_end); /*loop through periods*/

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

				proc sql noprint;
					select count(distinct AnalysisGrp) into: numPScomparisons
            		from l2comparisonfile(where=(OutputPSDistribution="Y"));
				quit;

				%if &numPScomparisons.=1 and %eval(&look_end)=1 %then %let tablecount = 0;
                %tableletter();
                %if &destination. = excel %then %do;
                ods excel options(sheet_interval="none" sheet_name = "Figure &figurenum.&tableletter." tab_color="DeepSkyBlue" flow='none');
                %end;

                proc odstext pagebreak=yes;
	                p %quote("Figure &figurenum.&tableletter.. Histograms Depicting Propensity Score Distributions Before&andafter Adjustment for &grouplabel. ^{newline} in the &database. from &startdateformatted. to &&enddate&i.formatted.") /
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
                %if &psfile. = iptwfile | "&analysisgrphist." ="STRATAWEIGHT" %then %do;
                  proc odstext ;
					p "Unweighted Propensity Score Distribution Before Trimming" / style=[just=L color=black];
                %end;
				%else %do;
				  proc odstext ;
					p "Unadjusted Propensity Score Distribution" / style=[just=L color=black];
				%end;
				
                %output_histogram(type=Unadjusted, weight=Unweighted);

                  %if "&matchtype" = "F" %then %do;
	                  proc odstext ;
						p " ";
						p "Propensity Score Fixed Ratio &ratiohist. Adjusted Cohort, Matched Caliper = &caliperhist." / style=[just=L color=black];
	                  %let hisanalysis = Adjusted;
	                  %output_histogram(type=Adjusted, weight=Unweighted);
                  %end;

                  %if &psfile. = iptwfile | "&analysisgrphist." ="STRATAWEIGHT" %then %do;
                    
                    proc sql noprint;
                      select distinct(weight)
                      into :weight_type 
                      separated by ' '
                      from histogram_&i. (where=(runid="&runid." and order="&loopcount."));
                    quit;

                    %do analysisgrpcount = 1 %to %sysfunc(countw(&weight_type));
                      %let analysisgrp_type = %scan(&weight_type,&analysisgrpcount);

                      %if &analysisgrp_type. = Weighted %then %do;
                        ods startpage = now;
						proc odstext ;
							p " ";
							p "Weighted Propensity Score Distribution After Trimming&analysisgrpschemelong." / style=[just=L color=black];
                      %end;
					  %else %do;
					    proc odstext ;
							p " ";
							p "Unweighted Propensity Score Distribution After Trimming" / style=[just=L color=black];
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
                    %let DPSITEID = %scan(&random_dplist,&dps);
                    %let maskeddpid = %scan(&masked_dplist,&dps);
                     
                    /*Assign C-Statistic*/
                    proc sql noprint;
                      select c_stat into: cstat
                      from &DPSITEID..&RUNID._estimates_&i.
                      where lowcase(psestimategrp)="&psestimategrp."; 
                    quit;
				  
                    /*output histogram*/
                    %let hisanalysis = Unadjusted;
                    %if &psfile. = iptwfile | "&analysisgrphist." ="STRATAWEIGHT" %then %do;
                      proc odstext ;
						p "Unweighted Propensity Score Distribution Before Trimming" / style=[just=L color=black];
                    %end;
				    %else %do;
				      proc odstext ;
						p "Unadjusted Propensity Score Distribution" / style=[just=L color=black];
				    %end;
					proc odstext ;
						p "Data Partner %substr(&MaskedDPID.,3)" / style=[just=L color=black];
						p "C-Stat for &hisanalysis. Cohort: &cstat" / style=[just=L color=black];
                    %output_histogram(type=Unadjusted, weight=Unweighted);

                    %if "&matchtype" = "F" %then %do;
                      %let hisanalysis = Adjusted;
                      proc odstext ;
						p " ";
						p "Propensity Score Fixed Ratio &ratiohist. Adjusted Cohort, Matched Caliper = &caliperhist." / style=[just=L color=black];
						p "Data Partner %substr(&MaskedDPID.,3)" / style=[just=L color=black];
						p "C-Stat for &hisanalysis. Cohort: &cstat" / style=[just=L color=black];
                      %output_histogram(type=Adjusted, weight=Unweighted);
                    %end;
					
					%if &psfile. = iptwfile | "&analysisgrphist." ="STRATAWEIGHT" %then %do;
                    
                      proc sql noprint;
                        select distinct(weight)
                        into :weight_type 
                        separated by ' '
                        from histogram_&i. (where=(runid="&runid." and order="&loopcount."));
                      quit;
					  
                      %do analysisgrpcount = 1 %to %sysfunc(countw(&weight_type));
                        %let analysisgrp_type = %scan(&weight_type,&analysisgrpcount);
					  
                        %if &analysisgrp_type. = Weighted %then %do;
                          ods startpage = now;
						  proc odstext ;
							p " ";
							p "Weighted Propensity Score Distribution After Trimming&analysisgrpschemelong." / style=[just=L color=black];
                        %end;
						%else %do;
                          proc odstext ;
							p " ";
							p "Unweighted Propensity Score Distribution After Trimming" / style=[just=L color=black];
						%end;
						proc odstext ;
							p "Data Partner %substr(&MaskedDPID.,3)" / style=[just=L color=black];
						%let hisanalysis = Adjusted;
                        %output_histogram(type=Adjusted, weight=&analysisgrp_type);
                      %end; *analysisgrpcount;
					%end; *iptwfile;  
                  %end; * dps;  
                %end; *stratify by DP;
              %end; *look;
			  ods startpage = now;
			%end; *psfile;
		    %end; *OutputPSDistribution;
	    %end; *numl2comparisons;

		%if &destination. = pdf %then %do;
		 ODS PDF BOOKMARKGEN = ON;
		%end; 
		%let figurenum = %eval(&figurenum.+1); 

%mend l2_psdistribution_output;
