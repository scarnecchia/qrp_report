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
* 
* 
*  PARAMETERS:  
*   - individualreturn: Y or N
*   - plotstocreate: list of plots (F3 F4 F5)
*   - kmrefpop: determines whether to produce weighted curves for VRM analysis
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

%macro l2_effect_estimate_km_createdata(individualreturn=, plotstocreate=, kmrefpop=);

	%put =====> MACRO CALLED: l2_effect_estimate_km_createdata;


    /*--------------------------------------------------------------------------------------------*/
    /* Patient level data                                                                         */
    /*--------------------------------------------------------------------------------------------*/
    %if &individualreturn. = Y %then %do;

    /*loop through each plot*/
    %do p = 1 %to %sysfunc(countw(&plotstocreate.));
        %let plot = %scan(&plotstocreate., &p.);


/*            data step0;*/
/*                set aggpl;*/
/*                pat = 1;*/
/*                keep matchid event followuptime exposure pat;*/
/*            run;*/

        /*For conditional analysis, restrict to informative events*/
        %if &plot. = Conditional %then %do;


        %end;


       






    /*Clean up*/

    %end; /*loop through plots*/

    %end; /*patient level data*/

    /*--------------------------------------------------------------------------------------------*/
    /* Risk set level data                                                                        */
    /*--------------------------------------------------------------------------------------------*/
    %else %if &individualreturn. = N %then %do;
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

            %isdata(labelfile);
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

           /*Merge in labels*/



        %end; /*data exists*/

    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _tempaggsurvival _aggsurvivalsquare: nexp cumulative_totals;
    quit;

    %end; /*risk set data*/

	%put =====> END MACRO: l2_effect_estimate_km_createdata;

%mend;
