****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_runrobusthr.sas  
* Created (mm/dd/yyyy): 07/08/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*	This program implements the point estimate and robust sandwich variance estimation on the sum of 
*   marginal weight risk set level datasets
* 
*  Program inputs:                                                                                   
*	- where = logic condition limiting the records to only those required to run estimation
*	- Analysis  = Unconditional
*	- subgroupcat = subgroup category
* 
*  Program outputs:                                                                                                                                       
*	- est: the dataset containing the hazard ratios and 95% Confidence Intervals
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_runrobusthr(where=, analysis=, subgroupcat=);

    %put =====> MACRO CALLED: l2_effect_estimate_runrobusthr ;

    data forest;
        set cat_dp_mw;
        where &where.;
    run;

    *Determine at least 1 event in exposure and reference group;
    %isdata(dataset=forest);
    %if %eval(&nobs.>=1) %then %do;

        *Determine at least 1 event in exposure and reference group;
        proc sql noprint;
            select sum(sumec), sum(SumSquareUnEC) into :sumec, :SumSquareUnEC
            from forest;
        quit;
        
        %if %eval(&sumec.>0) & %eval(&SumSquareUnEC.>0) & %index(&customizecolumns.,redactevents) = 0 %then %do;

            /* Need to sort by SumSquareE and SumSquareUnE for difference calculations later on */
            proc sort data = forest;
        		by descending SumSquareE descending SumSquareUnE;
        	run;

        	proc iml;
        	/* Read in necessary variables for HR estimation */
        	use forest;
        	read all var {SUMEC SUMC SUME SUMUNE};
        	close forest;

        	/* Define function for summation process, need to declare SUM variables as global due to local scoping */
        	start COX(HR) global(SUMEC,SUMC,SUME,SUMUNE);
           		y=sum(SUMEC-SUMC#(SUME#HR)/(SUME#HR+SUMUNE));
           		return(y);
        	finish COX;

        	/* Initial HR guess of 1 */
        	HR=1;
        	/* One equation being solved for */
        	optn={1};

        	/* Non-linear system that utilizes COX function to return optimized HR */
        	call nlphqn(rc, Soln, "COX", HR, optn);
        	/* Store solution in macro variable */
        	call symputx("HR_SOL",Soln);
        	quit;

        	/* Add HR back to original dataset */
        	data forest;
        	set forest;
        	HR=&HR_SOL;
        	run;

        	proc sql noprint;
        		select distinct dpidsiteid
        		into :GET_DP_LIST separated by ' '
        		from forest;
        	quit;

        	/* Get unique dps, loop through */

        	%do j = 1 %to %sysfunc(countw(&GET_DP_LIST));
        		%let get_dp = %scan(&GET_DP_LIST, &j);

            	/* When calculating the differences, we need to shift the rows up one so the correct rows are aligned */
            	data lag_dp_get_&get_dp.;
            		set forest(where=(dpidsiteid="&get_dp.") keep=dpidsiteid SumSquareE SumSquareUnE rename=(SumSquareE=lSumSqE SumSquareUnE=lSumSqUnE) firstobs=2);
            	run;

            	/* Merge dataset back onto itself starting at second row to calculate differences */
            	options mergenoby=nowarn;
            	data lag_ss_get_&get_dp.;
            	retain CumSum1E CumSum2E;
            	merge forest(where=(dpidsiteid="&get_dp.")) lag_dp_get_&get_dp.(drop=dpidsiteid);
            	if missing(lSumSqE) then lSumSqE = 0;
            	if missing(lSumSqUne) then lSumSqUne = 0;
            	SumSqEdiff=SumSquareE-lSumSqE;
            	SumSqUnEdiff=SumSquareUnE-lSumSqUne;
            	S0=(SumE*HR)+SumUnE;
            	S1=(SumE*HR);
            	CumSum1E+(sumC/S0);
            	CumSum2E+(sumC*S1/(S0**2));
            	run;
            	options mergenoby=warn;
        	%end;

        	/* Set data back together */
        	data lag_final_get;
        	set lag_ss_get:;
        	run;

        	proc sql noprint ;
        	/* Calculate Q1-Q6 */
        	/* Important note: Q1-Q6 here are summed across all DPs. In original program, they are summed within each DP, then q is summed across all DPs */
        	create table weight_final_get as
        	select *, (q1)+(q2)+(q3)-2*(q4)+2*(q5)-2*(q6) as q
        			  from (select dpidsiteid, HR,
        			   sum((1-S1/S0)**2*SumSquareEC+(S1/S0)**2*SumSquareUnEC) as Q1,
        			  (exp(2*log(HR)))*sum(SumSqEdiff*CumSum1E**2) as Q2,
        			  (exp(2*log(HR)))*sum(SumSqEdiff*CumSum2E**2)+sum(sumSqUnEdiff*cumsum2E**2) as Q3,
        			  HR*sum(SumSquareEC*(1-S1/S0)*cumsum1E) as Q4,
        			  (HR*sum(SumSquareEC*(1-S1/S0)*CumSum2E)+sum(SumSquareUnEC*(0-S1/S0)*CumSum2E)) as Q5,
        			  (exp(2*log(HR)))*sum(SumSqEdiff*CumSum1E*CumSum2E) as Q6,
        			  sum(SUMC*(S1/S0-(S1/S0)**2)) as H
        			  from lag_final_get
        			  group by dpidsiteid,HR);

            /* Calculate robust variance and standard error in subquery, lower and upper CI in outer query*/
        	create table pest as
        	select *, exp(log(HR)-(1.96*robust_se)) as LCL,
        			  exp(log(HR)+(1.96*robust_se)) as UCL
        	from (select *, divide(sum(q),sum(H)**2) as robust_var, divide(sum(q),sum(H)**2)**0.5 as robust_se
        		  from weight_final_get);

        	quit;

            *format output dataset;
            data est; 
                retain analysisgrp covarnum catnum MonitoringPeriod HR_95CI HR_pvalue;
                set pest(obs=1);

                format analysisgrp $40. covarnum catnum best. MonitoringPeriod 2.0;
                length analysisgrp $40 HR_95CI $30 Analysis $13 subgroupcat $10 HR_pvalue $6 covarnum 8;

                analysisgrp = "&analysisgrp.";
                covarnum  = &covarnum.;
                catnum = &cat.;
                MonitoringPeriod = &periodid.;
                Analysis= &analysis.;
                subgroupcat = "&subgroupcat.";
                HR_pvalue = 'N/A'; /*no p value*/

                /* set HR_95CI to NaN if not computed */
                if nmiss(HR, LCL, UCL)=3 then do;
                   HR_95CI='NaN';
                end;

                HR_95CI = strip(put(HR, 5.2))|| " ("||strip(put(LCL, 5.2))||", "|| strip(put(UCL, 5.2))||")";
                label MonitoringPeriod = "Monitoring Period";
                label hr_95CI = "Hazard Ratio (95% CI)";
                label HR = "Hazard Ratio";
                label LCL = "95% LCL";
                label UCL = "95% UCL";

                /*Needed for append - n/a for this estimation method*/
                format HR_coef 5.2 HR_se 8.4 ; 
                HR_se = .;
                HR_coef = .;

                keep analysisgrp COVARNUM catnum analysis subgroupcat MonitoringPeriod HR_95CI HR_pvalue HR LCL UCL HR_coef HR_se;
            run;        
        %end;
        %else %if %index(&customizecolumns.,redactevents) > 0 %then %do;
        data est;
            format analysisgrp $40. covarnum catnum best.; 
            length subgroupcat $10. analysisgrp $40. analysis $13. covarnum 8;

            analysisgrp = "&analysisgrp.";
            covarnum  = &covarnum.;
            catnum = &cat.;
            Analysis= &analysis.;
            subgroupcat = "&subgroupcat.";

            format MonitoringPeriod 2.;
            length HR_95CI $30. HR_pvalue $6.;
            MonitoringPeriod = &periodid.;

            HR_95CI = "N/A";
            HR_se = .;
            HR_coef = .;
            HR_pvalue = "N/A";
            HR = .;
            LCL = .;
            UCL = .;
        run; 
        %end;
        %else %do;
        %goto emptyds;
        %end;
	%end;
    %else %do;  *create empty dataset;
        %emptyds:
     	data est;
	  		format analysisgrp $40. covarnum catnum best.; 
			length subgroupcat $10. analysisgrp $40. analysis $13. covarnum 8;

		    analysisgrp = "&analysisgrp.";
		    covarnum  = &covarnum.;
		    catnum = &cat.;
			Analysis= &analysis.;
			subgroupcat = "&subgroupcat.";

	  		format MonitoringPeriod 2.;
	  		length HR_95CI $30. HR_pvalue $6.;
	  		MonitoringPeriod = &periodid.;

			HR_95CI = "NaN";
		    HR_se = .;
            HR_coef = .;
			HR_pvalue = "N/A";
            HR = .;
            LCL = .;
            UCL = .;
	    run; 
	%end;

	proc datasets library=work nowarn noprint;
	    append base= logitEst data=est force;
	    delete est pest forest lag_: HR_EQ;
	quit;

%put NOTE: ******** END OF MACRO: l2_effect_estimate_runrobusthr ********;

%mend l2_effect_estimate_runrobusthr;
