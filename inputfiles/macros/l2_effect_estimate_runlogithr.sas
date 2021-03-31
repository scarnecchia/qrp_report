****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_runlogithr.sas  
* Created (mm/dd/yyyy): 07/01/2015
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*	This program implements the case centered approach by executing the logistic regression on 
*   risk set level datasets
* 
*  Program inputs:                                                                                   
*	- where = logic condition limiting the records to only those required to run the regression
*	- Analysis  = Unadjusted, Conditional, Unconditional
*	- subgroupcat = subgroup category
* 
*  Program outputs:                                                                                                                                       
*	- est: the dataset containing the hazard ratios and standars errors equivalent to the Cox model
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_runlogithr(where=, analysis=, subgroupcat=);

    %put =====> MACRO CALLED: l2_effect_estimate_runlogithr ;

    data forest;
    set cat_dp_rs;
    where &where.;
    run;

	*This is to run logit on enough obs or else e.r.r.o.r. message;
	proc sort data=forest out=forest_exp nodupkey;
		by case_exposure;	
		where case_exposure ne . and logodds ne .;
	run;

    %isdata(dataset=forest_exp); 	
    %if %eval(&NOBS.>=2) & %eval(&redactevents.=0) %then %do;

        ods output parameterestimates=pest;
        proc genmod  data = forest descending;
            model Case_exposure = / offset = logodds dist = binomial link = logit ;
        run;

        *format output dataset;
        data est; 
  			retain analysisgrp COVARNUM catnum MonitoringPeriod HR_95CI HR_pvalue;
  			set pest (obs=1 RENAME = (estimate = HR_coef) RENAME = (stderr = HR_se));

  			format analysisgrp $40. COVARNUM catnum best. HR_coef LowerWaldCL UpperWaldCL HR LCL UCL 5.2 MonitoringPeriod 2.0;
  			length analysisgrp $40 HR_95CI $30 Analysis $13 subgroupcat $10 HR_pvalue $6;

	        analysisgrp = "&analysisgrp.";
	        COVARNUM  = &covarnum.;
	        catnum = &cat.;
	  		MonitoringPeriod = &periodid.;
			Analysis= &analysis.;
			subgroupcat = "&subgroupcat.";

			if probchisq < 0.001 then do;
				HR_pvalue = '<0.001';
			end;
			else do;
  				HR_pvalue = put(probchisq, 6.3);
			end;

  			HR_95CI = strip(put(exp(HR_coef), 5.2))|| " ("||strip(put(exp(LowerWaldCL), 5.2))||", "|| strip(put(exp(UpperWaldCL), 5.2))||")";
            HR =  put(exp(HR_coef), 5.2);
            LCL =  put(exp(LowerWaldCL), 5.2);
            UCL =  put(exp(UpperWaldCL), 5.2);

            /* set HR_95CI to NaN if not computed */
            if nmiss(HR, LCL, UCL)=3 then do;
               HR_95CI='NaN';
            end;

  			label MonitoringPeriod = "Monitoring Period";
  			label hr_95CI = "Hazard Ratio (95% CI)";
  			label HR_pvalue = "Wald P-Value";
			label HR_coef = "Coefficient from GenMod";
			label HR_se = "StdErr of Coefficient";
            label HR = "Hazard Ratio";
            label LCL = "95% LCL";
            label UCL = "95% UCL";

  			keep analysisgrp COVARNUM catnum analysis subgroupcat MonitoringPeriod HR_95CI HR LCL UCL HR_pvalue HR_coef HR_se;
  		run;
	%end;
    %else %do;  *create empty dataset;
     	data est;
	  		format analysisgrp $40. COVARNUM catnum best.;
			length subgroupcat $10. analysisgrp $40. analysis $13.;

		    analysisgrp = "&analysisgrp.";
		    COVARNUM  = &covarnum.;
		    catnum = &cat.;
			Analysis= &analysis.;
			subgroupcat = "&subgroupcat.";

	  		format MonitoringPeriod 2.;
	  		length HR_95CI $30. HR_pvalue $6.;
	  		MonitoringPeriod = &periodid.;

			HR_95CI = ".";
		    format HR_coef HR LCL UCL 5.2 HR_se 8.4; 
		    HR_coef = .;
		    HR_se = .;
			HR_pvalue = ".";
            HR = .;
            LCL = .;
            UCL = .;

			%if %eval(&redactevents.>0) %then %do;
				HR_pvalue = 'N/A';
				HR_95CI='N/A';
			%end;
	    run; 
	%end;

	proc datasets library=work nowarn noprint;
	    append base= logitEst data=est force;
	    delete est pest forest forest_exp;
	quit;

    %put NOTE: ******** END OF MACRO: l2_effect_estimate_runlogithr ********;

%mend l2_effect_estimate_runlogithr;
