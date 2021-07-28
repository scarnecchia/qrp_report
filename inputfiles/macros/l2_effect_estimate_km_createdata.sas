****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_km_createdata.sas  
* Created (mm/dd/yyyy): 07/22/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro computes Kaplan-Meier estimates for PS Match and PS Stratification analysis
*                                        
*  Program inputs:                                                                                   
*   - Either a patient level or risk set level dataset
* 
*  Program outputs: 
*   - One dataset per plot
* 
*  PARAMETERS:  
*   - plotstocreate: list of plots (F3 F4 F5)
*   - kmrefpop: determines whether to produce weighted curves for VRM analysis
*            
*  Programming Notes: 
*   - All unweighted curves (unadjusted, FRM conditional/unconditional, VRM exposure cohort)
*     will be computed using risk-set data. Only VRM weighted curves will be computed using 
*     patient level data 
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_km_createdata(plotstocreate=, kmrefpop=);

	%put =====> MACRO CALLED: l2_effect_estimate_km_createdata;

    /*--------------------------------------------------------------------------------------------*/
    /* Compute Exposure Cohort KM curve and Reference Cohort KM curve                             */
    /*--------------------------------------------------------------------------------------------*/

    /*Restrict aggsurvival to requested plots, remove DPs that do not converge*/
    data _tempaggsurvival;
        set aggsurvival(keep=followupday evexp evunexp nexp nunexp analysis dpidsiteid 
                        where=(analysis in (&plotstocreate.)));
        if missing(evexp) | missing(evunexp) | missing(nexp) | missing(nunexp) then delete;
    run;

    %isdata(dataset=_tempaggsurvival);
    %if %eval(&nobs <1) %then %do;
        %put WARNING: (Sentinel) No observations to produce KM curves for &analysisgrp. Curves will not be produced;
    %end;
    %else %do;

        /*Square dataset to include 1 row per day*/
        proc sort data=_tempaggsurvival;
            by analysis dpidsiteid followupday;
        run;

        data _squarekmcdf(rename=i=followupday);
            set _tempaggsurvival(keep=analysis dpidsiteid followupday);
            by analysis dpidsiteid followupday;
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
            by analysis dpidsiteid followupday;
            if evexp = . then evexp = 0;
            if evunexp = . then evunexp = 0;
        run;

        /*fill in missing nexp and unexp counts with the previous value and
          create lag variables to compute total # of episodes censored/with event at each time point*/
        proc sort data=_aggsurvivalsquare;
            by analysis dpidsiteid descending followupday;
        run;

        /*repeat same computation for nexp, nunexp*/
        %macro aggsurvivaldatastep(var);
            retain _n&var.;
            if not missing(n&var.) then _n&var.=n&var.;
            else n&var.=_n&var.;
            drop _n&var.;
             
            lagn&var. = lag(n&var.);

            if first.dpidsiteid then censor&var. = n&var.;
            else censor&var. = n&var. - lagn&var.;
        %mend;

        data _aggsurvivalsquare1;
            set _aggsurvivalsquare;
            by analysis dpidsiteid descending followupday;
            %aggsurvivaldatastep(exp);
            %aggsurvivaldatastep(unexp);
        run;

        /*At this point:
            - evexp and evunexp = # of events at each time point
            - nexp and nunexp = number of episodes at risk at each time point
            - censorexp and censorunexp = total number of episodes censored at each time point */ 

        /*Summarize across DPs*/
        proc means data=_aggsurvivalsquare1 nway noprint;
            var nexp nunexp evexp evunexp censorexp censorunexp;
            class analysis followupday / missing;
            output out=_kmdata(drop=_: rename=followupday=day) sum=; /*rename followupday to match L1 figures*/
        run;

        /*Total counts*/
        proc sql noprint;
            create table cumulative_totals as
            select analysis,
                   max(nexp) as cum_nexp,
                   max(nunexp) as cum_nunexp,
                   sum(evexp) as cum_evexp,
                   sum(evunexp) as cum_evunexp
            from _kmdata
            group by analysis;
        quit;

        %isdata(dataset=labelfile);
        %let renamestatement = %str(rename=(lag_episodes_atriskexp=episodes_atriskexp lag_episodes_atriskunexp=episodes_atriskunexp));

        /*Compute KM curve*/
        data %if %index(&plotstocreate, 'Unadjusted')>0 %then %do; figureF3_analysis&loopcount.(&renamestatement.) %end;
             %if %index(&plotstocreate, 'Conditional')>0 %then %do; figureF4_analysis&loopcount.(&renamestatement.) %end;
             %if %index(&plotstocreate, 'Unconditional')>0 %then %do; figureF5_analysis&loopcount.(&renamestatement.) %end; ;

            set _kmdata; 
            by analysis day;

            array sum{*} sum_evexp sum_evunexp sum_censorexp sum_censorunexp;
            array varlist{*} evexp evunexp censorexp censorunexp;
           
            if first.analysis then do;
                merge cumulative_totals;
                by analysis;
        
                do i = 1 to dim(varlist);
                    sum{i} = varlist{i};
                end;
            end;
            else do;
                do i = 1 to dim(varlist);
                    sum{i} = varlist{i} + sum{i} ;
                end;
            end;

            retain sum_evexp sum_evunexp sum_censorexp sum_censorunexp;

            /*Episodes_atrisk used in atrisk table in plot and for KM curve - 
              need to lag to get the # of episodes at risk on the day and not episodes still at risk*/
            episodes_atriskexp = cum_nexp - sum_censorexp;
            episodes_atriskunexp = cum_nunexp - sum_censorunexp;
            lag_episodes_atriskexp = lag(episodes_atriskexp);
            lag_episodes_atriskunexp = lag(episodes_atriskunexp);

            /*reset day 0*/
            if day = 0 then do;
                lag_episodes_atriskexp = episodes_atriskexp;
                lag_episodes_atriskunexp = episodes_atriskunexp;
            end;

            /*-----KM Plot---------*/                
    		if day =0 then do;
                km_evexp = 1;
                km_evunexp = 1;
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
    		end;
    		retain km_evexp km_evunexp;

            /*assign raw group label as grouplabel if no label file - next step assigns label from labelfile*/
            %if %eval(&nobs.<1) %then %do;
            length grouplabel $40;
            grouplabel = "&analysisgrp.";
            %end;

            keep grouplabel day lag_episodes_atriskexp lag_episodes_atriskunexp km_:;

            %if %index(&plotstocreate, 'Unadjusted')>0 %then %do; if analysis = 'Unadjusted' then output figureF3_analysis&loopcount.; %end;
            %if %index(&plotstocreate, 'Conditional')>0 %then %do; if analysis = 'Conditional' then output figureF4_analysis&loopcount.; %end;
            %if %index(&plotstocreate, 'Unconditional')>0 %then %do; if analysis = 'Unconditional' then output figureF5_analysis&loopcount.; %end;
       run;

    %end; /*data exists*/

    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _tempaggsurvival _aggsurvivalsquare: nexp cumulative_totals;
    quit;

    /*--------------------------------------------------------------------------------------------*/
    /* Weighted Reference Cohort (VRM only for Conditional Plots)                                 */
    /*--------------------------------------------------------------------------------------------*/
    %if (&kmrefpop = weighted or &kmrefpop = both) & %index(&plotstocreate,'Conditional') %then %do;

        /* Reset matchID as a concactenation of matchid-dpidsiteid to ensure unique matchIDs across DPs */
        data _tempaggpl;
            length pat 3 matchid $12;
            set aggpl(keep=matchid event followuptime exposure dpidsiteid
                      rename=matchid=tempmatchid rename=followuptime=followupday);
            pat = 1;
            matchid=catt(tempmatchid,dpidsiteid);
        run;

        /* Restrict to informative events and person time */
        proc means data = _tempaggpl nway max noprint;
            class matchID exposure;
            var followupday;
            output out = _maxdata(drop = _:) max = maxFUtime;
        run;

        proc transpose data = _maxdata out = _maxdata2 prefix = maxFUtime;
            id exposure;
            by matchID;
            var maxFUtime;
        run;

        proc sql noprint undo_policy=none;
            /* Calculate Steps 1 through Steps 5 from original PS tool -
               Select all time points and collapse into one observation per matchid/time */
            create table step0 as 
            select b.matchID
            , a.event
            , b.followupday
            , a.exposure
            , (1/c.count) as wght
            , a.pat
            , c.count
            from (select x.matchid,
                   x.exposure,
                   x.pat,
                   case when x.followupday > FU.stopFU then FU.stopFU else x.followupday end as followupday,
                   case when x.followupday > FU.stopFU then 0 else x.event end as event
            from _tempaggpl as x
            left join (select matchid, 
                              min(maxFUTime1,maxFUTime0) as stopFU 
                       from _maxdata2) as FU
            on x.matchID = fu.matchID) as a
            right join (select distinct x.matchid, y.followupday  
                        from _tempaggpl as x,
                        (select distinct followupday from _tempaggpl where exposure=0) as y) as b 
            on a.matchID = b.matchID and a.followupday = b.followupday 
            inner join (select z.matchid, sum(z.pat) as count
                        from _tempaggpl z
                        where z.exposure=0 
                        group by z.matchid) as c 
            on c.matchID = b.matchID
            where a.exposure ^= 1
            order by b.matchID, b.followupday;

            /* Stack and aggregate - Step 6 from PS tool */
            create table step1 as 
            select b.matchid, b.followupday, max(b.exposure) as exposure, max(b.wght) as wght, max(b.count) as count,
            sum(b.pat) as pat, sum(b.event) as event
            from step0 b
            where not missing(b.exposure)
            group by b.matchid, b.followupday
            union all  
            select a.matchid, a.followupday, a.exposure, a.wght, a.count, a.pat, a.event
            from step0 a
            where missing(a.exposure)
            order by matchid, followupday;
        quit;


           /*  data step2;
                set step1;
                by matchid followupday;
                if missing(pat) then pat=0;

                lagpat= lag(pat);
                lagexp = lag(exposure);

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

                wdpart = event*wght;
                wrpart = atrisk*wght;

                atriskv = wrpart;
                eventv = wdpart;
            run;

            proc means data=step2 noprint nway;
                var wdpart wrpart atrisk event atriskv eventv;
                class followupday;
                output out=step3(drop=_:) sum()= ;
            run;

            proc sort data = step3;
            by followupday;
            run; */

            /* Square dataset here prior to KM metric computation */

           /* data step3;
                set step3;
                by followupday;
                lagevent = lag(event);
                lageventv = lag(eventv);

                retain atrisk2 atrisk2v;

                if _n_ = 1 and followupday = 0 then do;
                    atrisk = &totalN;
                    atrisk2 = atrisk;

                    prodcomp = 1;

                    atriskv = &totalNv;
                    atrisk2v = atriskv;
                end; 
                else if not missing(atrisk) then do;
                    atrisk2 = atrisk;

                    prodcomp = 1-(wdpart/wrpart);

                    atrisk2v = atriskv;
                end;
                else do;
                    atrisk = atrisk2;
                    atriskv = atrisk2v;
                    prodcomp = 1;
                end;
                keep time atrisk atriskv prodcomp group;
            run; */

            /*Step 10. Calculate KM*/
/*             proc sort data=step9; 
                by group time;
            run;

            data step10_&expval;
                set step9;
                by group time;
                if first.group then do;
                    km_estimate = prodcomp;
                end;
                else do;
                    km_estimate = km_estimate*prodcomp;
                end;
                    
                retain km_estimate;

                atrisk = round(atriskv);

                graphed = km_estimate;
                if atrisk eq 0 then graphed = .;        

                keep time atrisk km_estimate group graphed;
            run; */

        /*Clean up*/
        proc datasets nowarn noprint lib=work;
            delete _tempaggpl step:;
        quit;


    %end; /*kmrefpop=both or weighted*/


           /*Merge in labels*/



	%put =====> END MACRO: l2_effect_estimate_km_createdata;

%mend;
