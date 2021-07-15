****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_cdf_km_createdata.sas  
* Created (mm/dd/yyyy): 07/14/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro computes Kaplan-Meier and Cumulative Distribution Function (CDF) estimates
*                                        
*  Program inputs:                                                                                   
*   - MSOC dataset containing 1 row per day and columns containing counts of episodes censored
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:  
*   - dataset: aggregate dataset from %aggregate_report_tables
*   - curve: KM or 1-CDF
*   - whereclause: where statement to restrict &dataset
*   - dayvar: variable name for censor day variable
*   - includegroups: Groups to include in report
*   - includevars: censor reasons to include in final dataset
*   - figure: standard figure # from FIGUREFILE
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

%macro figure_cdf_km_createdata(dataset=, 
                                curve=, 
                                whereclause=, 
                                dayvar=,
                                includegroups=,
                                includevars=,
                                figure=);

	%put =====> MACRO CALLED: figure_cdf_km_createdata;

    /*--------------------------------------------------------------------------------------------*/
    /* Select rows and columns and aggregate data                                                 */
    /*--------------------------------------------------------------------------------------------*/
    proc means data=&dataset.(where=(&whereclause.)) nway noprint;
        var episodes &includevars.;
        class runid group &dayvar. / missing;
        output out=_kmcdfdata(drop=_: where=(missing(day)=0) rename=&dayvar.=day) sum=;
    run;

    /*--------------------------------------------------------------------------------------------*/
    /* Square data to include 1 row per day                                                       */
    /*--------------------------------------------------------------------------------------------*/
    data _squarekmcdf(rename=i=day);
        set _kmcdfdata(keep=runid group day);
        by runid group day;
        if last.group then do;
            do i = 0 to day;
            output;
            end; 
        end;
        drop day;
    run;

    data _kmcdfdata;
        merge _kmcdfdata _squarekmcdf;
        by runid group day;
        *set missing to 0;
        array change episodes &includevars.;
        do over change;
            if change=. then change=0;
        end;
    run;

    /*--------------------------------------------------------------------------------------------*/
    /* Build macro variables                                                                      */
    /*--------------------------------------------------------------------------------------------*/
    %let censorreasonnum = %sysfunc(countw(&includevars.)); /*number of censor reasons*/
    %let kmcdf_cum_list=;
    %let kmcdf_sumlist=;
    %let kmcdf_cdflist=;
    %let kmcdf_atrisk=;

    %do i =1 %to %eval(&censorreasonnum.);
        %let kmcdf_cum_list = &kmcdf_cum_list. %sysfunc(cats(cum_,%quote(%scan(&includevars., &i.))));
        %let kmcdf_sumlist = &kmcdf_sumlist. %sysfunc(cats(sum_,%quote(%scan(&includevars., &i.))));
        %let kmcdf_cdflist = &kmcdf_cdflist. %sysfunc(cats(cdf_,%quote(%scan(&includevars., &i.))));
    %end;

    /*--------------------------------------------------------------------------------------------*/
    /* Compute total number of episodes for each censoring criteria                               */
    /*--------------------------------------------------------------------------------------------*/
    data cumulative_totals(keep=group &kmcdf_cum_list. cum_episodes);
        array cum{*} &kmcdf_cum_list. cum_episodes;
        array censorcriteria{*} &includevars. episodes;

        do i = 1 to dim(cum);
            cum{i} = 0;
        end;

        do until(last.group);
            set _kmcdfdata;  
            by group;

            do a = 1 to dim(cum);
                cum{a} = cum{a} + censorcriteria{a};
            end;
        end;
    run;

    /*--------------------------------------------------------------------------------------------*/
    /* Compute KM or 1-CDF estimate                                                               */
    /*--------------------------------------------------------------------------------------------*/
    data output.figure&figure.;
        set _kmcdfdata; 
        by group day;

        array sum{*} &kmcdf_sumlist. sum_episodes;
        array varlist{*} &includevars. episodes;
        array cum{*} &kmcdf_cum_list.; 
        %if "&curve" = "1-CDF" %then %do;
        array cdflist{*} &kmcdf_cdflist. ;
        %end;

        if first.group then do;
            merge cumulative_totals;
            by group;
    
            do i = 1 to dim(varlist);
                sum{i} = varlist{i};
            end;
        end;
        else do;
            do i = 1 to dim(varlist);
                sum{i} = varlist{i} + sum{i} ;
            end;
        end;

        retain &kmcdf_sumlist. sum_episodes;

        /*Episodes_atrisk used in atrisk table in plot and for KM curve*/
        episodes_atrisk = cum_episodes - sum_episodes;

        %if "&curve" = "1-CDF" %then %do;
        /*------1-CDF plot-----*/
        do a = 1 to dim(cdflist);
            if cum{a} = 0 then cdflist{a} = 1; else cdflist{a} = 1-(sum{a} / cum{a});
        end;
        drop a i;
        %end;
        /*-----KM Plot---------*/
        %else %if "&curve" = "KM" %then %do;
            lag_episodes_atrisk = lag(episodes_atrisk);
            
			if first.group then do;
				lag_episodes_atrisk = .; 
				%do cns = 1 %to %eval(&censorreasonnum.);
					km_%scan(&includevars., &cns.) = 1;
				%end;
			end;
			else do;
				%do cns = 1 %to %eval(&censorreasonnum.);
					if %scan(&includevars., &cns.) > 0 then do;
						km_%scan(&includevars., &cns.) = km_%scan(&includevars., &cns.)*(1-(%scan(&includevars., &cns.)/lag_episodes_atrisk));
					end;
					else do;
						km_%scan(&includevars., &cns.) = km_%scan(&includevars., &cns.);
					end;

				%end;
			end;
			retain %do cns = 1 %to %eval(&censorreasonnum.); km_%scan(&includevars., &cns.) %end; ;
        %end;

        keep runid group day episodes_atrisk
            %if "&curve" = "1-CDF" %then %do; cdf_: %end; 
            %if "&curve" = "KM" %then %do; km_: %end; 
            ;
     run;

    /*--------------------------------------------------------------------------------------------*/
    /* When all groups in 1 plot, reformat data                                                   */
    /*--------------------------------------------------------------------------------------------*/


    /*--------------------------------------------------------------------------------------------*/
    /* Merge Group label and assign censor reason labels                                          */
    /*--------------------------------------------------------------------------------------------*/










    proc datasets nowarn nolist noprint lib=work;
        delete _squarekmcdf _kmcdfdata _cumulative_totals;
    quit;

	%put =====> END MACRO: baseline_aggregate;

%mend;
