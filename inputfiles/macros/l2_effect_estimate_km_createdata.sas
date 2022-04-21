****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_km_createdata.sas  
* Created (mm/dd/yyyy): 07/22/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro computes Kaplan-Meier estimates for PS Match, PS Stratification and IPTW analyses
*                                        
*  Program inputs:                                                                                   
*   - Either a patient level, risk set level or marginal weight dataset
* 
*  Program outputs: 
*   - One dataset per plot. This dataset contains the KM curve for the overall and all 
*     requested subgroups
* 
*  PARAMETERS:  
*   - plotstocreate: list of plots (Unadjusted Conditional Unconditional Weighted)
*   - kmrefpop: determines whether to produce weighted curves for VRM analysis
*            
*  Programming Notes: 
*   - For unweighted analyses, all unweighted curves (unadjusted, FRM conditional/unconditional, 
*     VRM exposure cohort) will be computed using risk-set data. Only VRM weighted curves will be 
*     computed using patient level data. 
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_km_createdata(plotstocreate=, kmrefpop=);

	%put =====> MACRO CALLED: l2_effect_estimate_km_createdata;

	/* Macro that will be used for final data processing:
        - if xmax specified and xmax > max followup time add a final row with 0 patients at risk
        - if subgroup is dropped, add a dummy row for final plot */
    %macro addrows(plotdata, figure);
        %isdata(dataset=&plotdata.);
        %if %eval(&nobs.>0) %then %do;
        data _null_;
            set figurefile(where=(figure="&figure."));
            call symputx('xmax', xmax);
        run;

        *Create dataset with xmax;
        data _tempxmax;
            set _subgrp(keep=subgroup subgroupcat);
            day = 0; output;
            %if %eval(&xmax. > .) %then %do;
            day = &xmax.; output;
            %end;
        run;

        proc sort data=_tempxmax;
            by subgroup subgroupcat day;
        run;

        data &plotdata.;
            merge &plotdata.(in=a) _tempxmax(in=b);
            by subgroup subgroupcat day;
            if b and not a then do;
                episodes_atriskexp = 0;
                episodes_atriskunexp = 0;
                km_evexp = .;
                km_evunexp = .;
                %if &weightedpop. = Y %then %do; 
                episodes_atriskunexp_wght = 0;
                km_evunexp_wght = .;
                %end;
            end;
        run;
        %end;
    %mend addrows;


	* Extract sample for KM plots using survival data;
	%if %index(&plotstocreate, 'Unadjusted')>0 or %index(&plotstocreate, 'Conditional')>0 or %index(&plotstocreate, 'Unconditional')>0 %then %do;
	    /*Restrict aggsurvival to requested plots, remove DPs that do not converge*/
	    data _tempaggsurvival;
	        set aggsurvival(keep=followupday evexp evunexp nexp nunexp analysis dpidsiteid subgroup subgroupcat
	                        where=(analysis in (&plotstocreate.) and missing(evexp)=0 and missing(evunexp)=0 and missing(nexp)=0 and missing(nunexp)=0));
	    run;
	%end;

	%isdata(dataset=_tempaggsurvival);
	%let nobssurvival = &nobs.;


	* Extract sample for KM plots using marginal weights;
	%if %index(&plotstocreate, 'Weighted')>0 %then %do;
	    /*Restrict aggsurvival to requested plots, remove DPs that do not converge*/
	    data _tempaggmw;
	        set aggmw(keep=followuptime SumC SumEC SumSquareEC SumSquareUnEC SumE SumUnE SumSquareE SumSquareUnE analysis dpidsiteid subgroup subgroupcat
	                  where=(analysis in (&plotstocreate.) and missing(followuptime)=0 ));
	    run;
	%end;
    
	%isdata(dataset=_tempaggmw);
	%let nobsmw = &nobs.;


	* Output a custom warning if there is no survival or marginal weight data avaiblable to compute KM;
    %if %eval(&nobssurvival <1) and %eval(&nobsmw <1) %then %do;
        %put WARNING: (Sentinel) No observations to produce KM curves for &analysisgrp.. Curves will not be produced;
    %end;
	%else %do;
		/*Group Labels*/
        %isdata(dataset=labelfile);
        %let grp1label = &grp1;
        %let grp0label = &grp0;
        %if %eval(&nobs.>0) %then %do;
            data _null_;    
                set labelfile(where=(group="&grp1." and runid = "&runid." and labeltype = "grouplabel") in=a)
                    labelfile(where=(group="&grp0." and runid = "&runid." and labeltype = "grouplabel") in=b);
                if a then call symputx('grp1label', label);
                if b then call symputx('grp0label', label);
            run;
        %end;
	%end;	


	************************************************************************************************************************
	* KM plots using survival data are requested (figure F3, F4, F5 for Unadjusted, Conditional and Unconditional analyses)
	***********************************************************************************************************************;
    %if %eval(&nobssurvival >0) %then %do;
        /*Square dataset to include 1 row per day*/
        proc sort data=_tempaggsurvival;
            by subgroup subgroupcat analysis dpidsiteid followupday;
        run;

        data _squarekmcdf(rename=i=followupday);
            set _tempaggsurvival(keep=analysis dpidsiteid subgroup subgroupcat followupday);
            by subgroup subgroupcat analysis dpidsiteid followupday;
            if last.dpidsiteid then do;  
                do i = 0 to followupday;
                output;
                end;
            end;
            drop followupday;
        run;

        /*Merge square dataset into _tempaggsurvival and set event counts to 0 when day is missing*/
        data _aggsurvivalsquare;
            merge _tempaggsurvival _squarekmcdf;
            by subgroup subgroupcat analysis dpidsiteid followupday;
            if evexp = . then evexp = 0;
            if evunexp = . then evunexp = 0;
        run;

        /*fill in missing nexp and unexp counts with the previous value and
          create lag variables to compute total # of episodes censored/with event at each time point*/
        proc sort data=_aggsurvivalsquare;
            by subgroup subgroupcat analysis dpidsiteid descending followupday;
        run;

        /*repeat same computation for nexp, nunexp*/
        %macro aggsurvivaldatastep(var, ifclause);
            retain _n&var.;
            if not missing(n&var.) then _n&var.=n&var.;
            else n&var.=_n&var.;
            drop _n&var.;
             
            lagn&var. = lag(n&var.);

            if &ifclause. then censor&var. = n&var.;
            else censor&var. = n&var. - lagn&var.;
        %mend;

        data _aggsurvivalsquare1;
            set _aggsurvivalsquare;
            by subgroup subgroupcat analysis dpidsiteid descending followupday;
            %aggsurvivaldatastep(exp, %str(first.dpidsiteid));
            %aggsurvivaldatastep(unexp, %str(first.dpidsiteid));
        run;

        /*At this point:
            - evexp and evunexp = # of events at each time point
            - nexp and nunexp = number of episodes at risk at each time point
            - censorexp and censorunexp = total number of episodes censored at each time point */ 

        /*Summarize across DPs*/
        proc means data=_aggsurvivalsquare1 nway noprint;
            var nexp nunexp evexp evunexp censorexp censorunexp;
            class subgroup subgroupcat analysis followupday / missing;
            output out=_kmdata(drop=_: rename=followupday=day) sum=; /*rename followupday to match L1 figures*/
        run;

        /*--------------------------------------------------------------------------------------------*/
        /* If weighted reference cohort (VRM only for Conditional Plots), then compute weighted       */
        /* metrics to use in KM computation                                                           */
        /* This section will be computed separately for each subgroup category and then stacked       */
        /*--------------------------------------------------------------------------------------------*/
        %let weightedpop = N;
        %if &kmrefpop = both | &kmrefpop = weighted & %index(&plotstocreate,'Conditional') %then %do;
            %do kmcount = 0 %to %eval(&allsubgroupcatcount.);
                %let kmloopsubgroup = ;
                %let kmloopsubgroupcat = ;

                %if &kmcount. > 0 %then %do;
                data _null_;
                    set _subgrp(where=(subgroup ne ''));
                    if _n_ = &kmcount. then do;
                        call symputx('kmloopsubgroup', subgroup);
                        call symputx('kmloopsubgroupcat', subgroupcat);
                    end;
                run;
                %end;

                /* Reset matchID as a concactenation of matchid-dpidsiteid to ensure unique matchIDs across DPs */
                data _tempaggpl(drop=subgroup subgroupcat);
                    length matchid $12;
                    set aggpl(where=(subgroup = "&kmloopsubgroup" and subgroupcat = "&kmloopsubgroupcat" and missing(tempmatchid)=0)
                                  keep=matchid event followuptime exposure dpidsiteid subgroup subgroupcat
                                  rename=matchid=tempmatchid rename=followuptime=day);
                    matchid=catt(tempmatchid,dpidsiteid);
                run;

                %isdata(dataset=_tempaggpl);
                %if %eval(&nobs.>0) %then %do;
                    %let weightedpop = Y;

                    /* Restrict to informative events and person time */
                    proc means data = _tempaggpl nway max noprint;
                        class matchID exposure;
                        var day;
                        output out = _maxdata(drop = _:) max = maxFUtime;
                    run;

                    proc transpose data = _maxdata out = _maxdata2 prefix = maxFUtime;
                        id exposure;
                        by matchID;
                        var maxFUtime;
                    run;

                    proc sql noprint;
                        create table _tempaggpl_informative as
                        select x.matchid,
                               x.exposure,
                               1 as pat length = 3,
                               case when x.day > FU.stopFU then FU.stopFU else x.day end as day,
                               case when x.day > FU.stopFU then 0 else x.event end as event
                        from _tempaggpl(where=(exposure=0)) as x
                        /* Selects the smallest of the maximum follow-up time across exposed/reference group */
                        left join (select matchid, 
                                          min(maxFUTime1,maxFUTime0) as stopFU 
                                          from _maxdata2) as FU
                        on x.matchID = fu.matchID;
                    quit;

                    proc sql noprint undo_policy=none;
                        /* Select all time points and collapse into one observation per matchid/time */
                        create table step0 as 
                        select b.matchID
                        , a.event
                        , b.day
                        , a.exposure
                        , (1/c.count) as wght
                        , a.pat
                        , c.count
                        /* Set follow-up time and event based on whether follow-up time exceeds the max follow-up time */
                        from _tempaggpl_informative as a
                        /* Joins and creates all combination of matchid/day values */
                        right join (select distinct x.matchid, y.day  
                                    from _tempaggpl_informative as x,
                                    (select distinct day from _tempaggpl_informative where exposure=0) as y) as b 
                        on a.matchID = b.matchID and a.day = b.day 
                        /* Sum patients grouped within each matchid */
                        inner join (select z.matchid, sum(z.pat) as count
                                    from _tempaggpl_informative z
                                    where z.exposure=0 
                                    group by z.matchid) as c 
                        on c.matchID = b.matchID
                        where a.exposure ^=1
                        order by b.matchID, b.day;

                        /* Aggregate all non-missing exposure values, stack back missing exposure rows */
                        create table step1 as 
                        select b.matchid, b.day, max(b.exposure) as exposure, max(b.wght) as wght, max(b.count) as count,
                        sum(b.pat) as pat, sum(b.event) as event
                        from step0 b
                        where not missing(b.exposure)
                        group by b.matchid, b.day
                        union all  
                        select a.matchid, a.day, a.exposure, a.wght, a.count, a.pat, a.event
                        from step0 a
                        where missing(a.exposure)
                        order by matchid, day;
                    quit;

                     data step2;
                        set step1;
                        by matchid day;
                        if missing(pat) then pat=0;

                        lagpat= lag(pat);
                        lagexp = lag(exposure);

                        /*Compute at risk*/
                        if first.matchID then do;
                            atrisk  = count;
                        end;
                        else if missing(lagexp) = 0 then do;
                            atrisk = atrisk - lagpat;
                        end;
                        else do;
                            atrisk = atrisk;
                        end;
                        retain atrisk;

                        if event = . then event = 0;

                        evunexp_wght = event*wght; /*weighted event*/
                        nunexp_wght = atrisk*wght; /*weighted at risk*/
                    run;

                    /*Aggregate to 1 row per day*/
                    proc means data=step2 noprint nway;
                        var nunexp_wght evunexp_wght;
                        class day;
                        output out=step3(drop=_:) sum()= ;
                    run;

                    /*Square table to include all potential followup days*/
                    data _squareweightedkm(rename=i=day);
                        set step3(keep=day) end=eof;
                        by day;
                        if eof then do;  
                            do i = 0 to day;
                            output;
                            end;
                        end;
                        drop day;
                    run;

                    /*Merge square dataset into step and set event counts to 0 when day is missing*/
                    data step4;
                        merge step3 _squareweightedkm;
                        by day;
                        if evunexp_wght = . then evunexp_wght = 0;
                        if day = 0 then nunexp_wght = 0;
                    run;

                    /*fill in missing nexp and unexp counts with the previous value and
                      create lag variables to compute total # of episodes censored/with event at each time point*/
                    proc sort data=step4;
                        by descending day;
                    run;

                    data step5;
                        set step4;
                        by descending day;
                        length analysis $13;
                        analysis = 'Conditional';
                        %aggsurvivaldatastep(unexp_wght, %str(day=0));
                    run;

                    /*merge in _kmdata*/
                    proc sql noprint undo_policy=none;
                        create table _tempkmloop&kmcount. as
                        select x.*,
                               y.evunexp_wght,
                               y.nunexp_wght,
                               y.censorunexp_wght
                        from _kmdata(where=(analysis='Conditional' and subgroup="&kmloopsubgroup." and subgroupcat="&kmloopsubgroupcat.")) as x
                        left join step5 as y
                        on x.day = y.day
                        order by analysis, day;
                    quit;
                %end; /*data exists*/
            %end; /*loop through each subgroup*/

            /*stack each subgroup and sort data*/
            data _kmdata;
                set _kmdata(where=(analysis ne 'Conditional'))
                    _tempkmloop:;
            run;

            proc sort data=_kmdata;
                by subgroup subgroupcat analysis day;
            run;

        %end; /*compute weighted metrics*/

        /*Total counts*/
        proc sql noprint;
            create table cumulative_totals as
            select analysis
                   , subgroup
                   , subgroupcat
                   , max(nexp) as cum_nexp
                   , max(nunexp) as cum_nunexp
                   , sum(evexp) as cum_evexp
                   , sum(evunexp) as cum_evunex
                   %if &weightedpop. = Y %then %do;
                   , max(nunexp_wght) as cum_nunexp_wght
                   , sum(evunexp_wght) as cum_evexp_wght
                   %end;
            from _kmdata
            group by subgroup, subgroupcat, analysis;
        quit;
        
        %let renamestatement = %str(rename=(lag_episodes_atriskexp=episodes_atriskexp lag_episodes_atriskunexp=episodes_atriskunexp));
        
        %if &weightedpop = Y %then %do;
        %let renamestatement = %str(rename=(lag_episodes_atriskexp=episodes_atriskexp lag_episodes_atriskunexp=episodes_atriskunexp 
                                            lag_episodes_atriskunexp_wght=episodes_atriskunexp_wght));
        %end;

		/* Compute KM 95%CI */
		%macro computeKMCI(cohort=);
			if 0 < km_ev&cohort. < 1 then do;
				Qt3&cohort. = sqrt(cumQt1&cohort.)*km_ev&cohort.;
				lowerCI_&cohort. = km_ev&cohort. ** exp((-1.96*Qt3&cohort.)/log(km_ev&cohort.));
				upperCI_&cohort. = km_ev&cohort. ** exp((1.96*Qt3&cohort.)/log(km_ev&cohort.));
			end;
			else do;
				lowerCI_&cohort. = km_ev&cohort.;
				upperCI_&cohort. = km_ev&cohort.;
			end;
		%mend computeKMCI;

        /*Compute KM curve*/
        data %if %index(&plotstocreate, 'Unadjusted')>0 %then %do; figureF3_analysis&loopcount._&periodid.(&renamestatement.) %end;
             %if %index(&plotstocreate, 'Conditional')>0 %then %do; figureF4_analysis&loopcount._&periodid.(&renamestatement.) %end;
             %if %index(&plotstocreate, 'Unconditional')>0 %then %do; figureF5_analysis&loopcount._&periodid.(&renamestatement.) %end; ;

            set _kmdata; 
            by subgroup subgroupcat analysis day;

            array sum{*} sum_evexp sum_evunexp sum_censorexp sum_censorunexp %if &weightedpop. = Y %then %do; sum_evunexp_wght sum_censorunexp_wght %end; ;
            array varlist{*} evexp evunexp censorexp censorunexp %if &weightedpop. = Y %then %do; evunexp_wght censorunexp_wght %end; ;

			if NExp = 0 then Qt1Exp=0;
			else Qt1Exp = EVExp / (NExp*(NExp-EVExp));
			if NUnExp = 0 then Qt1UnExp=0;
			else Qt1UnExp = EVUnExp / (NUnExp*(NUnExp-EVUnExp));

            if first.analysis then do;
                merge cumulative_totals;
                by subgroup subgroupcat analysis;
        
                do i = 1 to dim(varlist);
                    sum{i} = varlist{i};
                end;
				cumQt1Exp=Qt1Exp;
				cumQt1UnExp=Qt1UnExp;
            end;
            else do;
                do i = 1 to dim(varlist);
                    sum{i} = varlist{i} + sum{i} ;
                end;
				cumQt1Exp=cumQt1Exp+Qt1Exp;
				cumQt1UnExp=cumQt1UnExp+Qt1UnExp;
            end;

            retain cumQt1Exp cumQt1UnExp sum_evexp sum_evunexp sum_censorexp sum_censorunexp %if &weightedpop. = Y %then %do; sum_evunexp_wght sum_censorunexp_wght %end; ;

            /*Episodes_atrisk used in atrisk table in plot and for KM curve - 
              need to lag to get the # of episodes at risk on the day and not episodes still at risk*/
            episodes_atriskexp = cum_nexp - sum_censorexp;
            episodes_atriskunexp = cum_nunexp - sum_censorunexp;
            lag_episodes_atriskexp = lag(episodes_atriskexp);
            lag_episodes_atriskunexp = lag(episodes_atriskunexp);
            %if &weightedpop. = Y %then %do; 
            episodes_atriskunexp_wght = cum_nunexp_wght - sum_censorunexp_wght;
            lag_episodes_atriskunexp_wght = lag(episodes_atriskunexp_wght);
            %end;

            /*reset day 0*/
            if day = 0 then do;
                lag_episodes_atriskexp = episodes_atriskexp;
                lag_episodes_atriskunexp = episodes_atriskunexp;
                %if &weightedpop. = Y %then %do; 
                lag_episodes_atriskunexp_wght = episodes_atriskunexp_wght;
                %end;
            end;

            /*-----KM Plot---------*/                
    		if day =0 then do;
                km_evexp = 1;
                km_evunexp = 1;
                %if &weightedpop. = Y %then %do; 
                km_evunexp_wght = 1;
                %end;
    		end;
    		else do;
                if evexp > 0 then do;
    			    km_evexp = km_evexp*(1-(evexp/lag_episodes_atriskexp));
                end;
    		    else do;
                    km_evexp = km_evexp;
                end;
                if evunexp > 0 then do;
    			    km_evunexp = km_evunexp*(1-(evunexp/lag_episodes_atriskunexp));
                end;
    		    else do;
                    km_evunexp = km_evunexp;
                end;
                %if &weightedpop. = Y %then %do; 
                if evunexp_wght > 0 then do;
    			    km_evunexp_wght = km_evunexp_wght*(1-(evunexp_wght/lag_episodes_atriskunexp_wght));
                end;
    		    else do;
                    km_evunexp_wght = km_evunexp_wght;
                end;
                %end;
    		end;
    		retain km_evexp km_evunexp %if &weightedpop. = Y %then %do; km_evunexp_wght %end;;

			%computeKMCI(cohort=exp);
			%computeKMCI(cohort=Unexp);

            label km_evexp = "&grp1label."
                  lag_episodes_atriskexp = "&grp1label."
                  km_evunexp = "&grp0label."
                  lag_episodes_atriskunexp = "&grp0label."
                  %if &weightedpop. = Y %then %do; 
                  km_evunexp_wght = "&grp0label. (Weighted)"
                  lag_episodes_atriskunexp_wght = "&grp0label. (Weighted)"
                  %end;
                ;
            
            %if &weightedpop. = Y %then %do; 
                /*set non-Conditional analyses to missing*/
                if analysis ne 'Conditional' then do;
                    call missing(km_evunexp_wght, lag_episodes_atriskunexp_wght);
                end;
                else do;
                    /*round weighted at risk*/
                    lag_episodes_atriskunexp_wght = round(lag_episodes_atriskunexp_wght);
                end;
            %end;

            %if &ratio.=V and (&kmrefpop = both | &kmrefpop = weighted) %then %do; 
			     call missing(lowerCI_exp, lowerCI_Unexp, upperCI_exp, upperCI_Unexp);
			%end;

            format analysisgrp $40.;
            analysisgrp = "&analysisgrp";

            keep day lag_episodes_atrisk: km_: subgroup subgroupcat analysisgrp lowerCI_: upperCI_:;

            %if %index(&plotstocreate, 'Unadjusted')>0 %then %do; if analysis = 'Unadjusted' then output figureF3_analysis&loopcount._&periodid.; %end;
            %if %index(&plotstocreate, 'Conditional')>0 %then %do; if analysis = 'Conditional' then output figureF4_analysis&loopcount._&periodid.; %end;
            %if %index(&plotstocreate, 'Unconditional')>0 %then %do; if analysis = 'Unconditional' then output figureF5_analysis&loopcount._&periodid.; %end;
        run;
        
        %addrows(figureF3_analysis&loopcount._&periodid., F3);
        %addrows(figureF4_analysis&loopcount._&periodid., F4);
        %addrows(figureF5_analysis&loopcount._&periodid., F5);

	%end; /*survival data exists*/

	*********************************************************************************************************
	* KM plots using marginal weights are requested (figure F4 for IPTW/PS stratum weighted analyses)
	********************************************************************************************************;
	%if %eval(&nobsmw >0) %then %do;		
		%let weightedpop = N;

		/* Summarize across DPs */
		proc means data=_tempaggmw nway noprint missing;		
		var SumC SumEC SumSquareEC SumSquareUnEC SumE SumUnE SumSquareE SumSquareUnE;
		class subgroup subgroupcat followuptime / missing;
        output out=_kmdata(drop=_: rename=followuptime=day) sum=; /*rename followuptime to match L1 figures*/		
		run;
		
		/* Compute KM plots */
		%macro computeKMWeightedCI(cohort=);
			cVE = ( 1/(log(km_ev&cohort.))**2 ) * cumV&cohort.;
			lowerCI_&cohort. = km_ev&cohort. ** (exp(1.96*sqrt(cVE)));
			upperCI_&cohort. = km_ev&cohort. ** (exp(-1.96*sqrt(cVE)));
		%mend computeKMWeightedCI;

		data figureF4_analysis&loopcount._&periodid.;
		length day 8;
		set _kmdata;
		by subgroup subgroupcat;

		* Exposed computation;
		RatioE=SumEC/SumE;
		tempE=1-RatioE;
		VE=(RatioE)/((1-RatioE)*SumE**2 / SumSquareE);
		
		* Unexposed computation;
		RatioUnE=(SumC-SumEC)/SumUnE;
		tempUnE=1-RatioUnE;		
		VUnE=(RatioUnE)/((1-RatioUnE)*SumUnE**2 / SumSquareUnE);

		if first.subgroupcat then do;			
			holdtempday=day;
			
			* Add day 0;
			day=0;
			km_evexp=1;
			km_evunexp=1;			
			output;

			day=holdtempday;

			* Survival probability;
			km_evexp=tempE;
			km_evunexp=tempUnE;	

			* 95% CI;
			cumVExp=VE;
			%computeKMWeightedCI(cohort=exp);
			cumVUnExp=VUnE;
			%computeKMWeightedCI(cohort=unexp);
			output;
		end;
		else do;
			* Survival probability;
			km_evexp=km_evexp*tempE;
			km_evunexp=km_evunexp*tempUnE;

			* 95% CI;
			cumVExp=cumVExp+VE;
			%computeKMWeightedCI(cohort=exp);
			cumVUnExp=cumVUnExp+VUnE;
			%computeKMWeightedCI(cohort=unexp);
			output;
		end;
		retain km_evexp km_evunexp cumVExp cumVUnExp;		

		* For weighted plots, # at risk is weighted N;
		rename SumE=episodes_atriskexp
			   SumUnE=episodes_atriskunexp;

		label km_evexp = "&grp1label."
              SumE = "&grp1label."
              km_evunexp = "&grp0label."
              SumUnE = "&grp0label."
              ;
		
		keep subgroup subgroupcat day SumE SumUnE km_evexp km_evunexp lowerCI_: upperCI_:;
		run;

		proc sort data=figureF4_analysis&loopcount._&periodid.;
		by subgroup subgroupcat day;
		run;

		/* Add missing day values to make sure at risk data is correctly output */
		data _squarekmcdf(rename=i=day);
        set _kmdata(keep=subgroup subgroupcat day);
        by subgroup subgroupcat day;
        if last.subgroupcat and day > 0 then do;  
            do i = 0 to day;
            	output;
            end;
        end;		
        drop day;
        run;

		data figureF4_analysis&loopcount._&periodid.;
		merge figureF4_analysis&loopcount._&periodid.(in=a)
			  _squarekmcdf(in=b);
		by subgroup subgroupcat day;

		if not missing(episodes_atriskexp) then do;
			lagepisodes_atriskexp=episodes_atriskexp;
			lagepisodes_atriskunexp=episodes_atriskunexp;
			lagkm_evexp=km_evexp;
			lagkm_evunexp=km_evunexp;	
			laglowerCI_exp=lowerCI_exp;
			laglowerCI_unexp=lowerCI_unexp;	
			lagupperCI_exp=upperCI_exp;
			lagupperCI_unexp=upperCI_unexp;	
		end;
		else do;
			episodes_atriskexp=lagepisodes_atriskexp;
			episodes_atriskunexp=lagepisodes_atriskunexp;
			km_evexp=lagkm_evexp;
			km_evunexp=lagkm_evunexp;
			lowerCI_exp=laglowerCI_exp;
			lowerCI_unexp=laglowerCI_unexp;	
			upperCI_exp=lagupperCI_exp;
			upperCI_unexp=lagupperCI_unexp;	
		end;

		format analysisgrp $40.;
        analysisgrp = "&analysisgrp";

		retain lagepisodes_atriskexp lagepisodes_atriskunexp lagkm_evexp lagkm_evunexp
			   laglowerCI_exp laglowerCI_unexp lagupperCI_exp lagupperCI_unexp;
		drop lag:;	
		run;

		%addrows(figureF4_analysis&loopcount._&periodid., F4);

	%end; /*marginal weights data exists*/


    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _temp: _aggsurvivalsquare: nexp cumulative_totals step: _maxdata: _squareweightedkm _squarekmcdf _kmdata;
    quit;

	%put =====> END MACRO: l2_effect_estimate_km_createdata;

%mend l2_effect_estimate_km_createdata;
