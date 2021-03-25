****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_psdistribution_createdata.sas  
* Created (mm/dd/yyyy): 03/17/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates both aggregated and DP specific PS distribution datasets
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

%macro l2_psdistribution_createdata;

    %do loopcount = 1 %to &numl2comparisons.; 
     
        /*Initialize macro variables for the analysisgrp loop*/
		%let OutputPSDistribution = ;
		%let ratio = ;

        /*set parameters from l2comparisonfile for this loop*/
        data _null_;
            set l2comparisonfile(where=(order=&loopcount.));
            call symputx('runid', runid);
            call symputx('analysisgrp', analysisgrp);
            call symputx('OutputPSDistribution', OutputPSDistribution);
        run;

		%if &OutputPSDistribution.=Y %then %do;
        /* only psmatchfile, stratificationfile, and iptwfile have histogram */
	        proc sql noprint;
	            select strip(file) into: psfile
	            from pscs_masterinputs
	            where analysisgrp = "&analysisgrp.";
	        quit;

	        %put now computing PS distributions for &analysisgrp.;

			%if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;
				data _null_; 
		          set pscs_masterinputs (where=(lowcase(analysisgrp)="&analysisgrp."));
		            call symputx("psestimategrp", lowcase(psestimategrp));
		                 %if &psfile. = psmatchfile  %then %do;
		                    call symputx('RATIO',upcase(ratio)) ;
		                 %end;
		        run; 
		        data _null_; 
		          set psest_masterinputs (where=(psestimategrp="&psestimategrp."));
		          call symputx('eoi', eoi) ;
		          call symputx('ref', ref) ;    
		        run;
			%end;

	      	%if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;

	            /* Determine weights on input dataset to use for squaring */
	            proc sql noprint;
	              select count(distinct(weight)) into: numweights trimmed
	              from agg_psdistribution_&periodid.;
	              
	              select distinct(weight) into: weight1 - :weight&numweights.
	              from agg_psdistribution_&periodid.;
	            quit;

	            /*Create bins dataset*/
	            %let start = -0.0125;
	                data bins;
	                length type $20;
	                  %do bin = 1 %to 41;
	                      ps_cat = &bin.;
	                      bin_eoi = &start.;
	                      bin_ref = &start.;
	                      %let start = &start. + 0.025;
	                      type = 'Unadjusted';
	                      weight = "Unweighted";
	                      output;
						  %do wt = 1 %to &numweights;
		                  	%if %eval(&ratio.= F ) | &psfile = iptwfile | &psfile = stratificationfile %then %do;
			                	type = 'Adjusted';
			                    weight = "&&weight&wt.";
			                    output;
		                    %end;/* end weight loop */
	                      %end;/* end fixed ratio do statement */
	                  %end;/* end bins do loop */
	                run;

	            /*Determine which histograms to produce*/
	            %let dp_start = 0;
	            %let dp_end = &num_dp.;

	            %if &stratifybydp. ne Y %then %do; /*only output aggregated histogram*/
	                %let dp_end = 0;
	            %end;

	            %do dps = &dp_start. %to &dp_end.; /*dps = 0 is aggregated histogram*/

	                /*Aggregate across DPs*/
	                %if &dps = 0 %then %do;
	                    proc means data=agg_psdistribution_&periodid. (where=(lowcase(analysisgrp)="&analysisgrp." and runid="&runid.")) noprint nway;
	                        var npts;
	                        class group type weight ps_cat analysisgrp;
	                        output out=hist_0(drop=_:) sum=;
	                    run;
						
	                    %let dpsiteid = agg;
	                %end;
	                %else %do; /* end aggregate do statement */
	                    %let dpsiteid = %scan(&masked_dplist,&dps);
	                %end; /* end dp assignment for non-agg do statement */

	                data raw_histogram;
	                   set %if &dps=0 %then %do; hist_&dps.; %end;
	                       %else %do; agg_psdistribution_&periodid. (where=(lowcase(analysisgrp)="&analysisgrp." and dpidsiteid="&dpsiteid." and runid="&runid.")); %end;
	                run;

	                /*Transpose to create separate column for exposure and comparator counts*/
	                proc sort data=raw_histogram;
	                    by type weight ps_cat;
	                run;

					/*defensive coding to avoid errors with group names with more than 32 charac*/
					data raw_histogram;
					set raw_histogram;
					if group="&eoi." then group = "eoi";
					if group="&ref." then group = "ref";
					run;

	                proc transpose data=raw_histogram out=raw_histogram1 prefix = _;
	                    by type weight ps_cat;
	                    id group;
	                    var npts;
	                run;

					%isdata(dataset=labelfile);
					%let eoilabel=&eoi.;
					%let reflabel=&ref.;

			    	%if %eval(&nobs>0) %then %do;
					  data _NULL_;
					  set labelfile(where=(lowcase(labeltype)='grouplabel'));
				 	  if group="&eoi." then call symputx('eoilabel', %quote(Label));
				 	  if group="&ref." then call symputx('reflabel', %quote(Label));
				 	  run;
				 	  %put &eoilabel.;
				 	  %put &reflabel.;
					%end;


	                proc sql noprint;
	                    create table raw_histogram_&loopcount._&dps._&periodid. as
	                    select    x._eoi
	                            , x._ref
	                            , y.type
	                            , y.ps_cat
	                            , y.weight
	                            , "&analysisgrp" as analysisgrp format=$40.
	                            , y.bin_eoi label="Histogram of &eoilabel."
	                            , y.bin_ref label="Histogram of &reflabel."
	                            , "&dpsiteid." as dp length=6
								, "&runid." as runid length=3
								, "&loopcount." as order length=3
	                    from raw_histogram1 as x right join bins as y on x.ps_cat = y.ps_cat and x.type =y.type and x.weight=y.weight;
	                quit;

	                proc append data=raw_histogram_&loopcount._&dps._&periodid. base=histogram_&periodid. force; run;

	                proc datasets noprint nowarn lib=work; delete raw:; quit;

	            %end; /*loop through DPs*/
	        %end; /*if PS analysis (matching/stratification)*/
    	%end; /*OutputPSDistribution*/
	%end;  /*loop through comparisons*/

%mend l2_psdistribution_createdata;
