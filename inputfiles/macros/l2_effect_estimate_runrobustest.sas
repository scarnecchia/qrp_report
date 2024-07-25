****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_runrobustest.sas  
* Created (mm/dd/yyyy): 07/08/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*	This program implements the point estimate and robust sandwich variance estimation on the sum of 
*   marginal weight risk set level datasets
* 
*  Program inputs:                                                                                   
*	- where = logic condition limiting the records to only those required to run estimation
*	- Analysis = Unadjusted, Conditional, Unconditional, Weighted
*	- subgroupcat = subgroup category
* 
*  Program outputs:                                                                                                                                       
*	- est: the dataset containing the hazard/risk ratios and 95% Confidence Intervals
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_runrobustest(where=, analysis=, subgroupcat=);

    %put =====> MACRO CALLED: l2_effect_estimate_runrobustest ;

    data forest;
        set cat_dp_mw;
        where &where. and RisksetID > 0;
    run;

    *Determine at least 1 event in exposure and reference group;
    %isdata(dataset=forest);
    %if %eval(&nobs.>=1) %then %do;

        *Determine at least 1 event in exposure and reference group;
        proc sql noprint;
            select sum(sumec), sum(SumSquareUnEC) into :sumec, :SumSquareUnEC
            from forest;
        quit;
        
        %if %eval(&sumec.>0) & %eval(&SumSquareUnEC.>0) & %index(&customizecolumns.,events) = 0 %then %do;

			/* For T4L2 analyses, each "risksetpop" should  be treated as its own site => create risksetpopnum indicator. */ 
			%if &reporttype. eq T4L2 and %str(&analysis.) eq %str("Conditional") %then %do;
				proc sort data=forest; 
				by dpidsiteid risksetpop;
				run;

				data forest;
				set forest;				
				by dpidsiteid risksetpop;
				if first.dpidsiteid then risksetpopnum=0;
				if first.risksetpop then risksetpopnum=risksetpopnum+1;				
				retain risksetpopnum;
				run;
			%end;
           
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

        	/* Defensive: make sure the dataset does not exist for append below */
			proc datasets library=work nowarn nolist;			    
			    delete lag_final_get;
			quit;

			%macro computedifferences(where=);
                  /* When calculating the differences for non binary analyses, we need to shift the rows up one so the correct rows are aligned */                        
                  %if &reporttype. ne T4L2 %then %do;
                        data lag_dp_get_&get_dp.;
                              set forest(where=(&where.) keep=dpidsiteid SumSquareE SumSquareUnE
                                                  rename=(SumSquareE=lSumSqE SumSquareUnE=lSumSqUnE) firstobs=2);
                        run;

                        /* Merge dataset back onto itself starting at second row to calculate differences */
                        options mergenoby=nowarn;
                        data lag_ss_get_&get_dp.;
                        retain CumSum1E CumSum2E;
                        merge forest(where=(&where.)) lag_dp_get_&get_dp.(drop=dpidsiteid);
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
                  /* For binary analyses, because there is only 1 risk set per condition, the cumulative sum will always equal the original sum */
                  %else %do;
                        data lag_ss_get_&get_dp.;
                        set forest(where=(&where.));
                        SumSqEdiff=SumSquareE;
                        SumSqUnEdiff=SumSquareUnE;
                        S0=(SumE*HR)+SumUnE;
                        S1=(SumE*HR);
                        CumSum1E+(sumC/S0);
                        CumSum2E+(sumC*S1/(S0**2));
                              run;
                        %end;

                        proc datasets library=work nowarn nolist;
                            append base=lag_final_get data=lag_ss_get_&get_dp.;
                            delete lag_dp_get_&get_dp. lag_ss_get_&get_dp.;
                        quit;
            %mend computedifferences;			

        	/* Get unique dps, loop through */
        	%do j = 1 %to %sysfunc(countw(&GET_DP_LIST));
        		%let get_dp = %scan(&GET_DP_LIST, &j);

				/* Process T4L2 distinct risksetpop as a separated site */
				%if &reporttype eq T4L2 and %str(&analysis.) eq %str("Conditional") %then %do;
					proc sql noprint;
						select count(distinct risksetpopnum) into :numrisksetpop
						from forest 
						where dpidsiteid="&get_dp.";
					quit;

					%put &=numrisksetpop;

					%do risksetpopnum = 1 %to &numrisksetpop.;
						%computedifferences(where=%str(dpidsiteid="&get_dp." and risksetpopnum=&risksetpopnum.));
					%end;
				%end;
            	%else %do;
					%computedifferences(where=%str(dpidsiteid="&get_dp."));
				%end;
        	%end;

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
                retain analysisgrp subgroup MonitoringPeriod HR_95CI HR_pvalue;
                set pest(obs=1);

                format analysisgrp $40. MonitoringPeriod 2.0;
                length analysisgrp $40 HR_95CI $30 Analysis $13 subgroupcat $11 subgroup $15 HR_pvalue $6;

                analysisgrp = "&analysisgrp.";
                subgroup  = "&subgroup";
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

                keep analysisgrp subgroup analysis subgroupcat MonitoringPeriod HR_95CI HR_pvalue HR LCL UCL HR_coef HR_se;
            run;        
        %end;
        %else %if %index(&customizecolumns.,events) > 0 %then %do;
        data est;
            format analysisgrp $40.; 
            length subgroup $15. subgroupcat $11. analysisgrp $40. analysis $13.;

            analysisgrp = "&analysisgrp.";
            Analysis= &analysis.;
            subgroupcat = "&subgroupcat.";
            subgroup = "&subgroup.";

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
	  		format analysisgrp $40.; 
			length subgroupcat $11. subgroup $15. analysisgrp $40. analysis $13.;

		    analysisgrp = "&analysisgrp.";
			Analysis= &analysis.;
			subgroupcat = "&subgroupcat.";
			subgroup = "&subgroup.";

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

	%if "&reporttype." = "T4L2" %then %do;
		data est;
		set est;
		%if  &&&runid._t4hoimethod. = binary %then %do;
		  	label rr_95ci = "Risk Ratio (95% CI)";	  	
			label rr_se = "StdErr of Coefficient";
		    label rr = "Risk Ratio";	    	    

			rename hr_95CI = rr_95ci;
			rename HR = rr;
			rename HR_se = rr_se;
		%end;
		%if  &&&runid._t4hoimethod. = timetoevent %then %do;
			rr_95ci = .;
			rr = .;
			rr_se = .;
		%end;
		run;
	%end;
		
	proc datasets library=work nowarn noprint;
	    append base= logitEst data=est force;
	    delete est pest forest lag_: HR_EQ;
	quit;

%put NOTE: ******** END OF MACRO: l2_effect_estimate_runrobustest ********;

%mend l2_effect_estimate_runrobustest;
