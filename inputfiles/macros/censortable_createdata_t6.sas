****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_createdata_t6.sas  
* Created (mm/dd/yyyy): 10/20/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro aggregates censoring table data for type6
*                                        
*  Program inputs:   
*   - agg_t6censor.sas7bdat                                                                                
*   - agg_switchplota.sas7bdat
*   - agg_switchplotb.sas7bdat  
*   
*  Program outputs:             
*   - [table].sas7bdat
*
*  PARAMETERS:
*   - table: table ID from tablefile
*   - censordataset: input dataset
*   - censorreason: list of censor reasons from tablefile
*   - levelid: levelid1 from tablefile
*   - groupvar: variable used to differentiate groups (group or analysisgrp)
*   - dayvar: variable used to indicate each day
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

%macro censortable_createdata_t6(table=, censordataset=, censorreason=, levelid=, groupvar=, dayvar=);

    %put =====> MACRO CALLED: censortable_createdata_t6;

    /*--------------------------------------------------------------------------------------------*/
    /* Dataset exists                                                                             */
    /*--------------------------------------------------------------------------------------------*/
    %isdata(dataset=&censordataset.);
    %if %eval(&nobs.>0) %then %do;
    
    /*--------------------------------------------------------------------------------------------*/
    /* Aggregate data across all DPs and stack DP data                                            */
    /*--------------------------------------------------------------------------------------------*/

    proc means data=&censordataset.(where=(level="&levelid")) noprint nway;
        var &censorreason.;
        class runid &groupvar. &dayvar. / missing;
        output out=sum_censor(drop=_:) sum=;
    run;

    %if &stratifybydp. = Y %then %do;
        data sum_censor(drop=level);
            set &censordataset.(where=(level="&levelid") keep=&censorreason. &groupvar. &dayvar. dpidsiteid runid level)
                sum_censor(in=a);
                if a then dpidsiteid = 'ALL';
        run;
    %end;

    /*--------------------------------------------------------------------------------------------*/
    /* Statistics for each censor reason                                                          */
    /*--------------------------------------------------------------------------------------------*/

    /*create squared table - needed to merge because freq statement drops rows where &reason.=0*/
    proc sort data=sum_censor nodupkey out=_square(keep=runid &groupvar. %if &stratifybydp. = Y %then %do; dpidsiteid %end; );
		by runid &groupvar. %if &stratifybydp. = Y %then %do; dpidsiteid %end; ;
	run;

    %do cr =1 %to %sysfunc(countw(&censorreason.));
        %let reason = %scan(&censorreason., &cr.);

        proc means data=sum_censor nway missing noprint ;
            var &dayvar.;
            class runid &groupvar. %if &stratifybydp. = Y %then %do; dpidsiteid %end; ;
            freq &reason.;
            output out=_censor&cr.(drop = _:) N = n
                                              mean = mean 
                                              std = std
                                              min = min
                                              p1  = p1
                                              p5  = p5
                                              p10 = p10
                                              q1 = p25
                                              median = median 
                                              q3 = p75
                                              p90 = p90
                                              p95 = p95
                                              p99 = p99
                                              max = max;
        run;

        /*convert censor reason back to standard variable names*/
        %let reason = %sysfunc(tranwrd(&reason.,endenrollmentcount,cens_elig));
        %let reason = %sysfunc(tranwrd(&reason.,deathcount,cens_dth));
        %let reason = %sysfunc(tranwrd(&reason.,endavaildatacount,cens_dpend));
        %let reason = %sysfunc(tranwrd(&reason.,endquerycount,cens_qryend));
        %let reason = %sysfunc(tranwrd(&reason.,endproductdiscontinuationcount,cens_episend));
        %let reason = %sysfunc(tranwrd(&reason.,productdiscontinuationcount,cens_episend));
        %let reason = %sysfunc(tranwrd(&reason.,switchedcount,cens_switch));

        /*Merge in squared dataset, add back censorreason and assign censor reason label*/
        data _censor&cr.;
            merge _censor&cr.
                  _square;
            by runid &groupvar. %if &stratifybydp. = Y %then %do; dpidsiteid %end; ;

            if n = . then n = 0;

            %if &stratifybydp. = N %then %do;
                length dpidsiteid $6;
                dpidsiteid = 'ALL';
            %end;

            length censorreason $32. censorlabel $&label_length.;
            censorreason = "&reason.";
            %if &reason ne cens_switch %then %do;
            censorlabel = "&&&reason._label";
            %end;
            %else %do;
                %if &table=T9 %then %do;
                censorlabel = "&&&reason.1_label";
                %end;
                %else %do;
                censorlabel = "&&&reason.2_label";
                %end;
            %end;
        run;

        %if %eval(&cr.=1) %then %do;
            data _stacked;
                set _censor&cr.;
            run;
        %end;
        %else %do;
            data _stacked;
                set _stacked _censor&cr.;
            run;
         %end;
    %end; /*loop through each censor reason*/

    /*--------------------------------------------------------------------------------------------*/
    /* Missing value indicators and format variables                                              */
    /*--------------------------------------------------------------------------------------------*/

    /*total count in cohort*/
    proc sql noprint;
        create table _totals as 
        select runid, &groupvar., dpidsiteid, sum(n) as overall_tot
        from _stacked
        group by runid, &groupvar., dpidsiteid;
    quit;

    proc sort data=_stacked;
        by runid &groupvar. dpidsiteid;
    run;

    %let metriclist = mean std min p1 p5 p10 p25 median p75 p90 p95 p99 max;
                                         
    data _stacked1(drop=overall_tot);
        merge _stacked _totals;
        by runid &groupvar. dpidsiteid; 

        /*assign censor order*/
        censororder = indexw("&defaultcensororder", censorreason);

        /*create character vars - set mean/std to 1 decimal, all others to 0 decimals*/
        n_char = strip(put(n, comma12.0));
        mean_char = strip(put(mean, comma10.1));
        std_char = strip(put(std, comma10.1));
        %do m =3 %to %sysfunc(countw(&metriclist));
        %scan(&metriclist, &m, ' ')_char = strip(put(%scan(&metriclist, &m, ' '), comma10.0));
        %end;

        /*set metrics to '.' if overall_tot = 0*/
        if overall_tot = 0 then do;
        %do m =1 %to %sysfunc(countw(&metriclist));
        %scan(&metriclist, &m, ' ')_char = '.';
        %end;
        end;
        else do;
            /*if patients in cohort, but none for censor reason - metrics cannot be computed*/
            if n = 0 then do;
                %do m =1 %to %sysfunc(countw(&metriclist));
                %scan(&metriclist, &m, ' ')_char = 'NaN';
                %end;
            end;
            /*if patients in cohort, but none for censor reason - metrics cannot be computed*/
            else if n = 1 then do;
                std_char = 'NaN'; 
            end;
        end;
    run;

    /*--------------------------------------------------------------------------------------------*/
    /* Apply group labels and sort                                                                */
    /*--------------------------------------------------------------------------------------------*/

    proc sql noprint;
  	     create table table&table. as
  	     select a.*
                , b.order
	  		   %if &labelfileexists. = Y %then %do;
  	     	   ,case when not missing(c.label) then c.label 
                else a.&groupvar. end as grouplabel
  	     	   ,case when not missing(d.label) then d.label 
                 when not missing(c.label) then c.label 
				 else a.&groupvar. end as headerlabel
          	   %end;
          	   %else %do;
          	   ,a.&groupvar. as grouplabel
        	   ,'' as headerlabel
          	   %end;
  	     from _stacked1 a 
	     inner join groupsfile b
  	     on a.runid = b.runid and a.&groupvar. = b.group 
	     %if &labelfileexists. = Y %then %do;
  	       left join labelfile(where=(labeltype='grouplabel')) c
  	       on a.&groupvar. = c.group and a.runid = c.runid
  	       left join labelfile(where=(labeltype='header')) d
  	       on a.&groupvar. = d.group and a.runid = d.runid

  	    %end;
        ;
    quit;

    proc sort data=table&table. out=output.table&table. sortseq=linguistic (numeric_collation=on);;
        by order dpidsiteid censororder;
    run;

    /*--------------------------------------------------------------------------------------------*/
    /* Clean up                                                                                   */
    /*--------------------------------------------------------------------------------------------*/

    proc datasets lib=work nowarn nolist noprint;
       delete _censor_tablefile _stacked: _totals _censor: sum_censor _square;
    quit;

    %end; /*dataset exists*/

   %put =====> END MACRO: censortable_createdata_t6;

%mend censortable_createdata_t6;
