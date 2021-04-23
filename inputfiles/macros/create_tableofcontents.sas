****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_tableofcontents.sas  
* Created (mm/dd/yyyy): 02/09/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro createas a dataset with 1 row per table and figure that is used as the 
*          report table of contents
*                                        
*  Program inputs:                                                                                   
*
*  Program outputs:          
*   -tableofcontents: dataset containing table of contents 
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

%macro create_tableofcontents();

    %put =====> MACRO CALLED: create_tableofcontents;

    /*********************************************************************************************/
    /* Utility macro to add row to tableofcontents file                                          */
    /*********************************************************************************************/
    %macro addtotoc(tabnum=, caption=, appendixtype=);
    data tableofcontents;
        set tableofcontents end=eof;
        output;
        if eof then do;
            tabnum = "&tabnum.";
            caption = "&caption.";
			appendixtype = "&appendixtype.";
            output;
        end;
    run;
    %mend;

    /*********************************************************************************************/
    /* Initialize empty table and table number                                                   */
    /*********************************************************************************************/
    data tableofcontents;
        length tabnum $25 caption $500 appendixtype $30;
        call missing(tabnum, caption, appendixtype);
    run;

    %let number = 1;
    %let tablenum = 1;

    /*********************************************************************************************/
    /* Build table of contents                                                                   */
    /*********************************************************************************************/

    /*****************/
    /* Glossary rows */
    /*****************/
    %addtotoc(tabnum=Glossary (CIDA), caption=List of Terms to Define Cohort Identification and Descriptive Analysis (CIDA) Found in this Report);
	%if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") | %str("&reporttype") = %str("TREE2") | %str("&reporttype") = %str("TREE4") %then %do;
	  %addtotoc(tabnum=Glossary (PSA), caption=List of Terms to Define Propensity Score Analysis (PSA) Found in this Report);				 
    %end;

    /******************/
    /* Baseline Table */
    /******************/
    %if %eval(&numbaselinetablegrp.>0) %then %do;

        /*counter for determining table letter*/
        %let tablecount = 1;

        /* counter for determining table number */
        %let tablenum = 2;

        /*loop through each baseline table*/
        %do b = 1 %to &numbaselinetablegrp.;
            %let analysisgrp = ;
            %let analysisgrp2 = ;
            %let baselinegroupnum = ;
            %let pregnancylabel = ;
            %let includenonpregnant = N;

            /*for L2 tables - need to reference PS/CS specific files to pull additional parameters*/
            %let ratio = F;
            %let psfile = ;
            %let weightlabel = ;
            %let weightscheme = ;
            %let pstrim = ;
            %let percentiles=;
            %let ratiolabel = ;
            %let caliperlabel = ;
            %let truncationlabel = ;
            %let psestimategrp = ;
            %let unadjusted = ;

            data _null_;
                set baselinefile(where=(order=&b.));
                if _n_ = 1 then do;
                    call symputx('analysisgrp', analysisgrp);
                    call symputx('runid', runid);
                    call symputx('cohort', cohort);
                    call symputx('unique_psestimate',unique_psestimate);
                    %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
                    if cohort in ('preg', 'nopreg') then do;
                        if upcase(includenonpregnant) = 'Y' then call symput('pregnancylabel', ' Pregnancy Cohort and Non-Pregnancy Cohort');
                        else call symput('pregnancylabel', ' Pregnancy Cohort');
                    end;
                    call symputx('includenonpregnant', upcase(includenonpregnant));
                    %end;
                    if missing(baselinegroupnum)=0 then call symputx('baselinegroupnum', baselinegroupnum);
                end;
                /*if baselinegroupnum is specified, a 2nd row will exist in the file*/
                if _n_ = 2 then do;
                    if missing(baselinegroupnum)=0 then do;
                        call symputx('analysisgrp2',analysisgrp);
                    end;
                end;
            run;
         
            %if %sysfunc(prxmatch(m/T2L2|T4L2|TREE2|TREE4/i,&reporttype.)) > 0 %then %do;
            data _null_;
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp." and covarnum=0));
                call symputx('psfile', strip(file));
                call symputx('psestimategrp', psestimategrp);
                call symput('unadjusted', 'Unadjusted '); /*for unadjusted table label*/

                if file = 'psmatchfile' then do;
                    call symputx('ratio',upcase(ratio));
                    if upcase(ratio)='F' then call symputx("ratiolabel",'Fixed Ratio 1:'||strip(put(ceiling, 8.)));
                    if upcase(ratio)='V' then call symputx("ratiolabel",'Variable Ratio 1:'||strip(put(ceiling, 8.)));
                    call symputx("caliperlabel", cat(', Caliper: ', caliper));
                end;
                if file = 'stratificationfile' then do;
                    call symputx('pstrim', pstrim);
                    call symputx('percentiles', percentiles);
                    if missing(strataweight) =0 then call symputx('weightscheme', strataweight);
        	        if upcase(strataweight)= 'ATE' or missing(strataweight) then call symputx("weightlabel","Average Treatment Effect (ATE)");
                    else if upcase(strataweight)= 'ATT' then call symputx("weightlabel","Average Treatment Effect in the Treated (ATT)");
                end;
                if file = 'iptwfile' then do;
                    if upcase(ipweight)= 'ATE' then call symputx("weightlabel","Average Treatment Effect (ATE)");
                    else if upcase(ipweight)= 'ATES' then call symputx("weightlabel","Average Treatment Effect, Stabilized (ATES)");
                    else if upcase(ipweight)= 'ATT' then call symputx("weightlabel","Average Treatment Effect in the Treated (ATT)");
                    call symputx('truncationlabel',strip(put(truncweight, best.))||'%');
                end;
            run;
            %end;

            /*determine if only 1 baseline table and set &tablecount to 0. Will occur if all the following are true:
            - 1 monitoring period
            - DP stratification = N
            - max(order) in baselinefile = 1
            - if reporttype = T2L2, T4L2, TREE2, or TREE4 - then analysis must be covariate stratification*/
            %if %eval(&b.=1) & %eval(&look_start.) = %eval(&look_end.) & &stratifybydp. = N & %eval(&numbaselinetablegrp.=1) %then %do;
                %if %sysfunc(prxmatch(m/T2L2|T4L2|TREE2|TREE4/i,&reporttype.)) = 0 %then %do;
                    %let tablecount = 0;
                %end;
                %else %do;
                    %if &psfile. = covstratfile %then %let tablecount = 0;
                %end;
            %end;

            /*Assign labels*/
            %let baselinelabel = ;
            %let grouplabel = &analysisgrp.;
            %let psestimatelabel = &psestimategrp.;
            %if %length(&baselinegroupnum.)>0 %then %do;
            %let grouplabel2 = &analysisgrp2.;
            %end;

            %isdata(dataset=labelfile);
            %if %eval(&nobs.>0) %then %do;
                data _null_;
                    set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid"))
                        %if %length(&baselinegroupnum.)>0 %then %do;
                        labelfile(in=b where=(group="&analysisgrp2" and runid = "&runid"))
                        %end; 
                        %if %sysfunc(prxmatch(m/T2L2|T4L2|TREE2|TREE4/i,&reporttype.)) > 0 %then %do;
                        labelfile(in=c where=(group="&psestimategrp" and runid = "&runid"))
                        %end; ;
                    if a then do;
                        if labeltype = 'grouplabel' then call symputx('grouplabel',label);
                        if labeltype = 'baselinelabel' then call symputx('baselinelabel',cat(', ',strip(label), ','));
                    end;
                    %if %length(&baselinegroupnum.)>0 %then %do;
                    if b then do;
                        if labeltype = 'grouplabel' then call symputx('grouplabel2',label);
                    end;
                    %end;
                    %if %sysfunc(prxmatch(m/T2L2|T4L2|TREE2|TREE4/i,&reporttype.)) > 0 & &psfile. ne covstratfile %then %do;
                    if c then do;
                        if labeltype = 'grouplabel' then call symputx('psestimatelabel',label);
                    end;
                    %end;
                run;
            %end;

            %let captionlabel = %bquote(&grouplabel.&pregnancylabel&baselinelabel.);
            %if %length(&baselinegroupnum.)>0 %then %do;
            %let captionlabel = %bquote(&grouplabel.&pregnancylabel and &grouplabel2.&pregnancylabel&baselinelabel.);
            %end;
            %if %sysfunc(prxmatch(m/T2L2|T4L2|TREE2|TREE4/i,&reporttype.)) >0 & &psfile. ne covstratfile %then %do;
            %let captionlabel = %bquote(&psestimatelabel.);
            %end;         

            /*1 block of code for both aggregate and DP tables*/
            %macro baselinetoc(table);
                %if %eval(&unique_psestimate.) = 1 %then %do;
                 %tableletter(); 
                 %addtotoc(tabnum=Table 1&tableletter., 
                 caption=%quote(&unadjusted.Baseline Characteristics of &captionlabel. (&table.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                %end;

                /*For L2 and TREE tables - up to 2 additional adjusted tables*/
                %if %sysfunc(prxmatch(m/T2L2|T4L2|TREE2|TREE4/i,&reporttype.)) > 0 %then %do;
                    /*PS Match Adjusted*/
                    %if &psfile. = psmatchfile %then %do;
                    %tableletter(); 
                    %addtotoc(tabnum=Table 1&tableletter., 
                    caption=%quote(Adjusted Baseline Characteristics of &grouplabel. (Propensity Score Matched, &table.), &ratiolabel.&caliperlabel., in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;

                    /*Unweighted - IPTW and PS Stratum*/
                    %if (&psfile. = iptwfile & %eval(&unique_psestimate.) = 1) | (&psfile. = stratificationfile & ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") & %eval(&pstrim.>=0)) %then %do;
                    %tableletter(); 
                    %addtotoc(tabnum=Table 1&tableletter., 
                     caption=%quote(Unweighted Baseline Characteristics of &grouplabel. (Unweighted, Trimmed, &table.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;

                    /*Weighted - IPTW, PS Stratum, PS Stratification*/
                    %if &psfile. = iptwfile | &psfile. = stratificationfile %then %do;
                        %if &psfile. = iptwfile %then %let stratumtitle = (Inverse Probability of Treatment Weighted, Trimmed, &table.), Weight: &weightlabel., Truncation: &truncationlabel.;
                        %else %if "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %let stratumtitle = (Propensity Score Stratum Weighted, Trimmed, &table.), Percentiles: &percentiles., Weight: &weightlabel.;
                        %else %let stratumtitle =(Propensity Score Stratified, &table.), Percentiles: &percentiles.;
                        %tableletter(); 
                        %addtotoc(tabnum=Table 1&tableletter., 
                        caption=%quote(Weighted Baseline Characteristics of &grouplabel. &stratumtitle., in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;
                %end; /*Additional L2 tables*/
            %mend;

            /*loop through each periodid*/
            %do periodid = %eval(&look_start.) %to %eval(&look_end.);
                /*Aggregated*/
                %baselinetoc(Aggregated);
       
                /*Output seperate table for each Data Partner - loop through each DP*/
                %if &stratifybydp. = Y %then %do;    
                    %do dps = 1 %to %eval(&num_dp.);
        		        %let maskedID = %scan(&masked_dplist,&dps); 
                        %baselinetoc(&maskedid.);
                    %end;
                %end; /*DP stratification*/
            %end; /*loop through each periodid*/
        %end; /*loop through each row in baselinefile*/
    %end; /*include baseline tables in toc*/

  /*************************/
  /* Effect estimate table */
  /*************************/

  %if &numl2comparisons > 0 %then %do; 

        /*loop through each baseline table*/
        %do c = 1 %to &numl2comparisons;

        /* reset counter to reset table letter */
        %let tablecount = 1;

            data _null_;
                set l2comparisonfile(where=(order=&c.));
                call symputx('analysisgrp', analysisgrp);
                call symputx('runid', runid);
            run;

            /* Merge in group labels if they exist */
            %let grouplabel = &analysisgrp;
            %isdata(dataset=labelfile);
            %if %eval(&nobs>0) %then %do;
            data _null_;
                set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid")) ;
                if labeltype = 'grouplabel' then call symputx('grouplabel',label);
            run;
            %end;

            /* Store covarnums to determine covar labels */
            proc sql noprint;
                select distinct covarnum
                into :covarlist
                separated by ' '
                from l2_effectestimates_&look_end.
                where analysisgrp="&analysisgrp.";
            quit;

            %if &covarlist = 0 %then %let tablecount = 0;

            /* loop covarnums and assign subgroup label */
            %do covarcount = 1 %to %sysfunc(countw(&covarlist));
                %let covarnum = %scan(&covarlist,&covarcount);

                %if &covarnum = 0 %then %do;
                %let titleend = %str();
                %end;

                %else %if &covarnum = 9000 %then %do; 
                %let titleend = %str(and Data Partner);
                %end;

                %else %do;
                %if &covarnum < 1000 %then %do;
                proc sql noprint;
                select distinct strip(studyname) into: subgrouplabel
                from infolder.&&&runid._covariatecodes
                where covarnum = &covarnum.;
                quit;
                %end;

                %if &covarnum = 1000 %then %let subgrouplabel = Sex;
                %else %if &covarnum = 1001 %then %let subgrouplabel = Age Group;
                %else %if &covarnum = 1002 %then %let subgrouplabel = Year;
                %else %if &covarnum = 1003 %then %let subgrouplabel = Monitoring Period;
                %else %if &covarnum = 1012 %then %let subgrouplabel = Race;
                %else %if &covarnum = 1013 %then %let subgrouplabel = Hispanic Origin;
                %else %if &covarnum = 1014 %then %let subgrouplabel = Delivery Status;
                %else %if &covarnum = 2000 %then %let subgrouplabel = Match Method;
                %else %if &covarnum = 2001 %then %let subgrouplabel = Birth Type;

                %let titleend = %str(and &subgrouplabel);
                %end;
                %tableletter();
                %addtotoc(tabnum=Table &tablenum.&tableletter.,
                caption=%quote(Effect Estimates for &grouplabel. in the &database. from &startdateformatted. to &&enddate&look_end.formatted., by Analysis Type &titleend.));
            %end; /* covarcount */
            %let tablenum = %eval(&tablenum + 1);
         %end; /* numl2comparison do loop */
    %end; /* numl2comparison */


  /*********************************************************************************************/
  /*   Code Distribution Tables                                                                */
  /*********************************************************************************************/ 
  %if &output_code_distribution. eq Y %then %do;

    /* This macros output a specific distribution type (EXP or HOI) entries in the table of content */
	%macro codedistribution_type_toc(distindextype=);
        /* Compute group label to display in title */
		%let grouplabel=;
		%isdata(dataset=labelfile);
    	%if %eval(&nobs>0) %then %do;
			proc sql noprint;
			select label into :grouplabel trimmed from labelfile
			where lower(group)="&group." and runid = "&runid" and
			%if &distindextype. eq exp %then %do;
				lower(labeltype)="grouplabel";
			%end;
			%else %do;
				lower(labeltype)="outcomelabel";
			%end;
			quit;
		%end;

		%if %str("&grouplabel.") eq %str("") %then %let grouplabel = %trim(&group.);

		/* Full Code Distribution Table */
		%tableletter();
		%addtotoc(tabnum=Table &tablenum.&tableletter.,
                  caption=%quote(Full Code Distribution of &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.));

		/* Total Code Counts Table */
		%tableletter();
		%addtotoc(tabnum=Table &tablenum.&tableletter.,
                  caption=%quote(Total Code Counts of &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.));
	%mend codedistribution_type_toc; 

	/* reset counter to reset table letter */
	%let tablecount=1;
    
	proc sql noprint;
	select count(*) into :numgroupscodedist trimmed 
	from GroupsDist;
	quit;
	
    %do loopcount = 1 %to &numgroupscodedist.; 

		%let codedistexp = N;
		%let codedisthoi = N;

        data _null_;
            set GroupsDist;
			if &loopcount. = _N_;
            call symputx('runid', runid);
            call symputx('group', group);			
            if index(upcase(codedist), "EXP") > 0 then call symputx('codedistexp', 'Y');
			if index(upcase(codedist), "HOI") > 0 then call symputx('codedisthoi', 'Y');
        run;

		%if &codedistexp. eq Y %then %do;
			* Defensive: make sure the requested data is available;
			%let obscount=0;

			proc sql noprint;
			select count(*) into :obscount from codedistdata
			where lower(group) = "&group." and runid = "&runid" and lower(distindextype) = "exp";
			quit;

			%if %eval(&obscount. > 0) %then %codedistribution_type_toc(distindextype=exp);
		%end;
		%if &codedisthoi. eq Y %then %do;
			* Defensive: make sure the requested data is available;
			%let obscount=0;

			proc sql noprint;
			select count(*) into :obscount from codedistdata
			where lower(group) = "&group." and runid = "&runid" and lower(distindextype) = "hoi";
			quit;

			%if %eval(&obscount. > 0) %then %codedistribution_type_toc(distindextype=hoi);
		%end;
				
	%end; *numgroupscodedist;
  %end;


  /*********************************************************************************************/
  /*   Figures                                                                                 */
  /*********************************************************************************************/  

    %isdata(dataset=figurefile);
    %if %eval(&nobs.>0) %then %do;

        %let figurenum = 1; /* Add +1 for additional figure types that are requested */
        %let tablecount = 1;

        /***************************************************************************************/
        /* ReportType = T2L2, T4L2, TREE2, or TREE4                                            */
        /***************************************************************************************/
        %if %sysfunc(prxmatch(m/T2L2|T4L2|TREE2|TREE4/i,&reporttype.)) > 0 %then %do;

	        /*F1: PS distribution histograms*/
	        %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) > 0 %then %do;

				proc sql noprint;
					select count(distinct AnalysisGrp) into: numPScomparisons
            		from l2comparisonfile(where=(OutputPSDistribution="Y"));
				quit;

				%do loopcount = 1 %to &numl2comparisons.; 

					data _NULL_;
		            set l2comparisonfile(where=(order=&loopcount.));
		            call symputx('runid', runid);
		            call symputx('analysisgrp', analysisgrp);
		            call symputx('OutputPSDistribution', OutputPSDistribution);
		       		run;

				  %if &OutputPSDistribution. = Y %then %do;

					%isdata(dataset=labelfile);
					%let grouplabel=&analysisgrp.;

				    %if %eval(&nobs>0) %then %do;
					  data _NULL_;
					  set labelfile(where=(lowcase(labeltype)='grouplabel'));
					  if group="&analysisgrp." and runid = "&runid";
		              call symputx('grouplabel', Label);
					  run;
					  %put &grouplabel.;
					%end;

					%let andafter=;

					proc sql noprint;
		            select strip(file) into: psfile
		            from pscs_masterinputs
		            where analysisgrp = "&analysisgrp.";
			        quit;
             %if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;
				      data _null_; 
	                  set pscs_masterinputs (where=(lowcase(analysisgrp)="&analysisgrp."));
	                    call symputx("psestimategrp", lowcase(psestimategrp));
	                        %if &psfile. = psmatchfile  %then %do;
	                            if upcase(ratio) = "F" then do;
								    call symput("andafter", " and After");
	                            end;
	                        %end;
	                        %if &psfile = iptwfile %then %do;
							   call symput("andafter", " and After");
	                        %end;
							%else %if &psfile = stratificationfile %then %do;
							   if upcase(strataweight) in ("ATE", "ATT") then do;
							     call symput("andafter", " and After");
							   end;
	                        %end;
	                  run; 

		            %do j = %eval(&look_start) %to %eval(&look_end);

						%if &numPScomparisons.=1 and %eval(&look_end)=1 %then %do;
							%let tablecount = 0;
						%end;
		                %tableletter();
		                %addtotoc(tabnum=Figure &figurenum.&tableletter.,
		                caption=%quote(Histograms Depicting Propensity Score Distributions Before&andafter Adjustment for &grouplabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.))
		            %end; /* loop periods */
				%end; /*psfile*/
			  %end; /* OutputPSDistribution */
			 %end; /* loop comparisons */
			 %let figurenum = %eval(&figurenum.+1); 
	        %end; /*Histograms*/

	        /*F2: Forest Plots*/
	        %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) > 0 %then %do;
	            %if %sysfunc(prxmatch(m/T2L2|TREE2/i,&reporttype.)) > 0 %then %let ForestRatioTitle = Hazard Ratios (HR);
	            %else %let ForestRatioTitle = Odds Ratios (OR);

						%let tableletter=a;
						%let tablecount = 1;

	            %do j = %eval(&look_start) %to %eval(&look_end);
	                %do plot = 1 %to 7;
	                    %let forest_title = ;
	                    data _null_;
	                    set forest_&j(where=(plotorder=&plot));
	                      call symputx("forest_title",forest_title);
	                    run;

	                    %if %length(&forest_title) > 0 %then %do;
	                    %tableletter();
	                    %addtotoc(tabnum=Figure &figurenum.&tableletter.,
	                    caption=%quote(Forest Plot of &ForestRatioTitle and 95% Confidence Intervals (CI) for &forest_title in the &database. from &startdateformatted. to &&enddate&j.formatted.))
	                    %end; /* Forest title exists */
	                %end; /* loop plots */
	            %end; /* loop periods */
	        %end; /*Forest plots */
        %end; /*L2 figures*/

    %end; /* Figure file */
	

    /*****************/
    /* Appendices    */
    /*****************/

    /*Appendix A*/
    %addtotoc(tabnum=Appendix A, caption=Dates of Available Data for Each Data Partner (DP) as of Request Distribution Date &datedistributed.);
	
	/* The remaining appendices are created in appendix_driver.sas */
	
    /*********************/
    /* Remove empty rows */
    /*********************/
    data tableofcontents;
       set tableofcontents;
       if missing(tabnum)=0;
    run;

    %put =====> END MACRO: create_tableofcontents ;

%mend create_tableofcontents;
