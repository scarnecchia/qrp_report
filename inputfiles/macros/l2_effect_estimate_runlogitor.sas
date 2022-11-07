****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_runlogitor.sas  
* Created (mm/dd/yyyy): 02/04/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program computes the odds ratio by executing a logistic regression or 
*          Cochran-Mantel-Haenszel method on risk set level datasets
*
*  Program inputs: dataset cat_dp_rd
*
*  Program outputs: logitEst 
*
*  PARAMETERS: 
*   - where = value used to subset input analytic dataset cat_dp_rd
*   - analysis = used to create variable in order to label output
*   - subgroupcat = used to create variable in order to  label output
*   - ormethod = method used to compute OR (logit or cmh)
*   - s00 = probability of non-case selection among unexposed (optional)
*   - s01 = probability of case selection among unexposed (optional)
*   - s10 = probability of non-case selection among exposed (optional)
*   - s11 = probability of case selection among exposed (optional)
*            
*  Programming Notes:    
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_runlogitor(where=, 
                                     analysis=,
                                     subgroupcat=,
                                     ormethod=,
                                     s00=,
                                     s01=,
                                     s10=,
                                     s11=);

    %put =====> MACRO CALLED: l2_effect_estimate_runlogitor;

    /**************************************************************************/
    /* Create new data set using [RUNID]_riskdiffdata_[PERIODID].sas7bdat     */
    /* with per patient per line, variables: exposed 1: exposed, 0 unexposed  */
    /* event: 1: event, 0 not event                                           */
    /**************************************************************************/

    /*set indicator vars*/
    %let Expevlvl = 0;
    %let Unexpevlvl = 0;

    %if %index(&customizecolumns.,events) = 0 %then %do;
        data _sub1;
            set cat_dp_rd(where=(&where.));
		    /* retain observations with non-missing counts only */
            if nmiss(exp,unexp, evexp, evunexp)=0;
        run;

        /* confirm analytic dataset has observations */
        %isdata(dataset=_sub1);
        %if %eval(&NOBS.>=1) %then %do;
            data _forest(drop=cntexp cntunexp);
                set _sub1(keep=exp unexp evexp evunexp dp %if &pscsfile.=stratificationfile %then %do; percentile %end;);

                length exposure event 3;
                /* eoi group */
                do cntexp=1 to exp;
                    exposure=1;
                    event=0;
                    if cntexp <= evexp then event=1;
                    output;
                end;
                
                /* ref group */
                do cntunexp=1 to unexp;
                    exposure=0;
                    event=0;
                    if cntunexp <= evunexp then event=1;
                    output;
                end;
            run;
           
        %end; /* end do statement for creating person-level dataset */
    %end; /* risk-level data */    
  
    %isdata(dataset=_forest);
    %if %eval(&nobs.>=1) %then %do;
     proc sql noprint;
        select count(distinct event) into: Unexpevlvl
        from _forest
        where exposure=0;

        select count(distinct event) into: Expevlvl
        from _forest
        where exposure=1;
    quit;
    %end;

	/***************************************************/
    /* fit the model for generating odds ratio and CIs */
	/***************************************************/
    %if %eval(&Unexpevlvl.+&Expevlvl.)>=4 %then %do; 

        %if "&ormethod" = "logit" %then %do;
            ods output ParameterEstimates=_oddsratio;
            proc genmod data=_forest descending; 
                class exposure(ref='0') dp;
                model event=exposure dp /dist=bin;
            run;
        %end;
        %else %if "&ormethod" = "cmh" %then %do;
            ods output commonRelRisks=_oddsratio;
            proc freq data=_forest ;
                table dp*percentile*exposure*event / cmh;
            run;
        %end;

		/***********************/
		/* compute odds ratios */
		/***********************/
  	    data oddsratio; 
            %if "&ormethod" = "logit" %then %do;
  	           set _oddsratio (where=(lowcase(parameter)='exposure' and level1='1') rename = (estimate = or_coef stderr = or_se));
            %end;
            %else %if "&ormethod" = "cmh" %then %do;
              set _oddsratio (where=(index(lowcase(statistic), "odds")>0) rename=(value=or lowercl = lcl uppercl=ucl));
            %end;

            /*for both ORs - a character variable is computed in the form XX.XX (XX.XX-XX.XX) and 3 numeric variables are 
              output to use in the forest plot*/
  	        format analysisgrp $40. or adjor adjor_ucl adjor_lcl lcl ucl or 5.2 MonitoringPeriod 2.0;
  		    length analysisgrp $40 or_95ci adjor_95ci $30 analysis $13 subgroupcat subgroup $11;

            analysisgrp = "&analysisgrp.";
	        subgroup  = "&subgroup.";
	  		MonitoringPeriod = &periodid.;
			Analysis= &analysis.;
			subgroupcat = "&subgroupcat.";

            %if "&ormethod" = "logit" %then %do;
    		    or =exp(or_coef);
                lcl =exp(LowerWaldCL);
                ucl =exp(UpperWaldCL);
                or_95CI = strip(put(exp(or_coef), 5.2))|| " ("||strip(put(exp(LowerWaldCL), 5.2))||", "|| strip(put(exp(UpperWaldCL), 5.2))||")";
            %end;
            %else %if "&ormethod" = "cmh" %then %do;
                or_95CI = strip(put(or, 5.2))|| " ("||strip(put(lcl, 5.2))||", "|| strip(put(ucl, 5.2))||")";
                or_se=(or-lcl)/1.96;
            %end;

            /* set or_95ci to NaN if not computed */
            if nmiss(or, lcl, ucl)=3 then do;
               or_95ci='NaN';
            end;

            *adjusted odds ratio;
            adjor = .;
            adjor_lcl = .;
            adjor_ucl = .;
            adjor_95ci = 'N/A';

            %if %length(&s00.)>0 %then %do;
                if nmiss(or, or_se)=0 then do;
                    adjor=or*((&s10.*&s01.)/(&s11.*&s00.));
                    adjor_lcl = adjor-1.96*or_se;
                    adjor_ucl = adjor+1.96*or_se;
                    adjor_95CI = strip(put(adjor, 5.2))|| " ("||strip(put(adjor_lcl, 5.2))||", "|| strip(put(adjor_ucl, 5.2))||")";
                end;
                else do;
                adjor_95ci = 'NaN';
                end;
            %end;
            %else %do;
                adjor_95ci = 'NaN';
            %end;

  			label MonitoringPeriod = "Monitoring Period";
  			label or_95ci = "Odds Ratio (95% CI)";
  			label adjor_95ci = "Adjusted Odds Ratio (95% CI)";
		    label or_se = "StdErr of Coefficient";
            label or = "Odds Ratio";
            label LCL = "95% LCL";
            label UCL = "95% UCL";
            label adjor = "Adjusted Odds Ratio";
            label adjor_LCL = "Adjusted 95% LCL";
            label adjor_UCL = "Adjusted 95% UCL";

  			keep analysisgrp subgroup analysis subgroupcat MonitoringPeriod or or_95ci or_se adjor adjor_95ci LCL UCL adjor_LCL adjor_UCL;
  		run;
    %end; /* end do statement for formatting output for data with adequate events */

    /****************************************/
    /* create empty dataset if not computed */
    /****************************************/
    %else %do; 
        data oddsratio;
  	        format analysisgrp $40. adjor adjor_ucl adjor_lcl lcl ucl or 5.2 MonitoringPeriod 2.0;
  		    length analysisgrp $40 or_95ci adjor_95ci $30 analysis $13 subgroupcat subgroup $11;

            analysisgrp = "&analysisgrp.";
	        subgroup  = "&subgroup.";
	  		MonitoringPeriod = &periodid.;
			Analysis= &analysis.;
			subgroupcat = "&subgroupcat.";

            *odds ratio;
		    or = .;
            lcl = .;
            ucl = .;
            %if %index(&customizecolumns.,events) > 0 %then %do;
            or_95ci = 'N/A';
            %end;
            %else %do;
            or_95ci= "NaN";
            %end;
            or_se = .;

            *adjusted odds ratio;
            adjor = .;
            adjor_lcl = .;
            adjor_ucl = .;
            %if %index(&customizecolumns.,events) > 0 %then %do;
            adjor_95ci = 'N/A';
            %end;
            %else %do;
            adjor_95ci = 'NaN';		
            %end;
        run; 
    %end; /* end do statement for analysis when not events and nonevents */

    /* append results to base file */
    proc datasets library=work nowarn noprint;
	    append base= logitEst data=oddsratio force;
	    delete oddsratio _oddsratio _sub1 _forest;
	quit;
       
    %put NOTE: ******** END OF MACRO: l2_effect_estimate_runlogitor ********;

%mend l2_effect_estimate_runlogitor;
