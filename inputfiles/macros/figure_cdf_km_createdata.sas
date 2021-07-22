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
*   - rename: syntax to rename variables on input dataset
*   - curve: KM or CDF
*   - whereclause: where statement to restrict &dataset
*   - dayvar: variable name for censor day variable
*   - includegroups: Groups to include in report
*   - includevars: censor reasons to include in final dataset
*   - transposedata: Y/N/T whether all groups are in 1 plot (Y=Yes, N=No, T=only execute transpose)
*   - discardnegativetimegroups: list of groups to remove negative ttswitch (Relevant for T6 only)
*   - figure: standard figure # from FIGUREFILE
*            
*  Programming Notes:         
*   - Curve = CDF will produce a 1-CDF plot
*   - Requires group names to be unique across runIDs
*   - Can specify transposedata = T if prior dataset exists with stacked data - used to produce 
*     2nd plot with the same data                                                                      
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro figure_cdf_km_createdata(dataset=, 
                                rename=,
                                curve=, 
                                whereclause=, 
                                dayvar=,
                                includegroups=,
                                includevars=,
                                transposedata=,
                                discardnegativetimegroups=,
                                figure=);

	%put =====> MACRO CALLED: figure_cdf_km_createdata;

    /*--------------------------------------------------------------------------------------------*/
    /* Confirm input dataset exists                                                               */
    /*--------------------------------------------------------------------------------------------*/
    %isdata(dataset=&dataset.);
    %if %eval(&nobs.<1) %then %do;
        %put WARNING: SENTINEL: plot &figure. requested, however dataset &dataset. does not exist;
        %goto skipfigure;
    %end;

    /*--------------------------------------------------------------------------------------------*/
    /* If transposedata T then do no execute aggregation and computation                          */
    /*--------------------------------------------------------------------------------------------*/
    %if &transposedata. ne T %then %do;

        /*--------------------------------------------------------------------------------------------*/
        /* Select rows and columns and aggregate data                                                 */
        /*--------------------------------------------------------------------------------------------*/
        proc means data=&dataset.(&rename. where=(&whereclause.)) nway noprint;
            var episodes &includevars.;
            class runid group &dayvar. / missing;
            output out=_kmcdfdata(drop=_: where=(missing(day)=0) rename=&dayvar.=day) sum=;
        run;

        %isdata(dataset=_kmcdfdata);
        %if %eval(&nobs.<1) %then %do;
            %put WARNING: SENTINEL: plot &figure. requested, however no observations available to compute curve;
            %goto skipfigure;
        %end;

        /*--------------------------------------------------------------------------------------------*/
        /* Remove negative time for Type 6                                                            */
        /*--------------------------------------------------------------------------------------------*/
        %let minday = 0;
        %if %str(&discardnegativetimegroups.) ne %str() %then %do;
            data _kmcdfdata;
                set _kmcdfdata;
                if group in (&discardnegativetimegroups.) and day <0 then delete;
            run;
        %end;

        /*--------------------------------------------------------------------------------------------*/
        /* Square data to include 1 row per day                                                       */
        /*--------------------------------------------------------------------------------------------*/
        /*find minimum day (can be negative for Type 6)*/
        %if &reporttype. = T6 %then %do;
            proc sql noprint;
                select min(day) into: minday
                from _kmcdfdata;
            quit;
            %let minday = %sysfunc(min(0,&minday.));
        %end;
        %else %do;
            %let minday = 0;
        %end;

        data _squarekmcdf(rename=i=day);
            set _kmcdfdata(keep=runid group day);
            by runid group day;
            if last.group then do;
                /*type 6 - length = 4*/ %if &reporttype.=T6 %then %do; length i 4; %end;
                do i = &minday. to day;
                output;
                end; 
            end;
            drop day;
        run;

        data _kmcdfdata;
            merge _kmcdfdata
                  _squarekmcdf 
                  _squaregroup;
            by runid group day;
            *set missing to 0;
            array change episodes &includevars.;
            do over change;
                if change=. then change=0;
            end;
        run;

        proc sql noprint undo_policy=none;
            create table _kmcdfdata as
            select x.*, y.order
            from _kmcdfdata x
            inner join groupsfile(where=(includeinfigure='Y')) y
            on x.runid = y.runid and x.group = y.group
            %if &reporttype. = T6 %then %do;
            where y.switchanalysis = 'Y'
            %end;
            order by runid, group, day;
        quit;
  
        /*--------------------------------------------------------------------------------------------*/
        /* Build macro variables                                                                      */
        /*--------------------------------------------------------------------------------------------*/
        %let censorreasonnum = %sysfunc(countw(&includevars.)); /*number of censor reasons*/
        %let kmcdf_cumlist = %sysfunc(prxchange(s/(\w+)/cum_$1/,-1,&includevars.));
        %let kmcdf_sumlist = %sysfunc(prxchange(s/(\w+)/sum_$1/,-1,&includevars.));
        %let kmcdf_cdflist = %sysfunc(prxchange(s/(\w+)/cdf_$1/,-1,&includevars.));

        /*--------------------------------------------------------------------------------------------*/
        /* Compute total number of episodes for each censoring criteria                               */
        /*--------------------------------------------------------------------------------------------*/
        data cumulative_totals(keep=group &kmcdf_cumlist. cum_episodes);
            array cum{*} &kmcdf_cumlist. cum_episodes;
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
        %isdata(dataset=labelfile); /*if labelfile exists*/

        data figure&figure.;
            set _kmcdfdata; 
            by group day;

            array sum{*} &kmcdf_sumlist. sum_episodes;
            array varlist{*} &includevars. episodes;
            array cum{*} &kmcdf_cumlist.; 
            %if "&curve" = "CDF" %then %do;
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

            %if "&curve" = "CDF" %then %do;
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

            /*assign raw group label as grouplabel if no label file - next step assigns label from labelfile*/
            %if %eval(&nobs.<1) %then %do;
            length grouplabel $40;
            grouplabel = group;
            %end;

            /*Assign censoring criteria labels*/
            %do lbl = 1 %to %eval(&censorreasonnum.);
                %let s=;
                %if %scan(&includevars., &lbl.) = cens_switch %then %do;
                    %if &dataset. = agg_t6plota %then %let s = 1;
                    %else %if &dataset. = agg_t6plotb %then %let s = 2;
                %end;
                %let var = %scan(&includevars., &lbl.);
                label &&curve._%scan(&includevars., &lbl.) = "&&&var.&s._label";
            %end;

            keep runid group: order day episodes_atrisk &curve._:;
         run;

        /*--------------------------------------------------------------------------------------------*/
        /* Assign Group label                                                                         */
        /*--------------------------------------------------------------------------------------------*/
         %if %eval(&nobs.>0) %then %do;
            proc sql noprint undo_policy = none;
                create table figure&figure. as 
                select a.*,
                      case when not missing(b.label) then b.label 
                           else a.group end as grouplabel length=&label_length.
                from figure&figure. as a
                left join labelfile(where=(labeltype = 'grouplabel')) as b
                on a.group = b.group and a.runid = b.runid
                order by a.group, a.day;
            quit;
         %end;

        /*--------------------------------------------------------------------------------------------*/
        /* if transposedata=N then create 1 dataset per group                                         */
        /*--------------------------------------------------------------------------------------------*/
        %if &transposedata. = N %then %do;
             data %do g = 1 %to &numgroups.;
                  figure&figure._group&g.
                  %end; ;
                set figure&figure.;
                %do g = 1 %to &numgroups.;
                if order = &g. then output figure&figure._group&g.;
                %end;
             run;

            /*delete extraneous datasets*/
            %do g = 1 %to &numgroups.;
                %isdata(dataset=(figure&figure._group&g.));
                %if %eval(&nobs.<1) %then %do;
                    proc datasets nowarn noprint lib=work;  
                    delete figure&figure._group&g.;
                    quit;
                %end;
            %end;
        %end;

     %end; /*end transposedata ne T*/

    /*--------------------------------------------------------------------------------------------*/
    /* When all groups in 1 plot (only 1 censor reason per plot), reformat data                   */
    /*--------------------------------------------------------------------------------------------*/
     %if &transposedata. = Y | &transposedata.=T %then %do;
        proc sort data=figure&figure.;
            by day order;
        run;

        proc transpose data=figure&figure. out=_tempfigure1&figure.(drop=_name_ _label_) prefix=group;
            by day;
            id order;
            idlabel grouplabel;
            var &curve._&includevars.;
        run;
        proc transpose data=figure&figure. out=_tempfigure2&figure.(drop=_name_) prefix=episodes_atrisk;
            by day;
            id order;
            idlabel grouplabel;
            var episodes_atrisk;
        run;

        /*merge both datasets together and fill in missing at risk values (when 1 group has longer followup)*/
        data figure&figure.;
            merge _tempfigure1&figure. _tempfigure2&figure.;
            by day;
            array epiatrisk{*} episodes_atrisk:;
            do i = 1 to dim(epiatrisk);
                if missing(epiatrisk{i}) then epiatrisk{i} = 0;
            end;
            drop i;
        run;
     %end;

    %skipfigure:

    proc datasets nowarn nolist noprint lib=work;
        delete _squarekmcdf _kmcdfdata _cumulative_totals _tempfigure:;
    quit;

	%put =====> END MACRO: baseline_aggregate;

%mend;
