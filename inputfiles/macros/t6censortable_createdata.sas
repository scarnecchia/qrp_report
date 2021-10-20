****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_t6_createdata.sas  
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
*   - 
*
*  PARAMETERS:
*   -TableID: tableID from tablefile
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

%macro censortable_t6_createdata() ;

    %put =====> MACRO CALLED: censortable_t6_createdata;

    /*--------------------------------------------------------------------------------------------*/
    /* Table specific parameters                                                                  */
    /*--------------------------------------------------------------------------------------------*/

    data _censor_tablefile;
        set tablefile(where=(table in ('T8', 'T9', 'T10');
    run;

    %isdata(dataset=_censor_tablefile);
    %if %eval(&nobs.>0) %then %do;
        %let censortableloop = &nobs.;

        /*loop through each table*/
        %do cl = 1 %to %eval(&censortableloop.);

            %let table=
            %let censordataset=;
            %let censorreason=;
            %let levelid=;
            %let groupvar=;
            %let dayvar=;

            data _null_;
                set _censor_tablefile;
                if _n_ = &cl. then do;
                    call symputx('tableid', strip(table));
                    call symputx('censordataset', strip(dataset));
                    call symputx('levelid', levelid1);
                    call symputx('censorreason', censorreason)
                    
                    /*assign group and day variables*/
                    if censordataset = 't6censor' then do;
                        call symputx('groupvar', group);
                        call symputx('dayvar', episodelength);
                    end;
                    else do;
                        call symputx('groupvar', analysisgrp);
                        call symputx('dayvar', ttswitch);
                    end;
                end;
            run;

            /*--------------------------------------------------------------------------------------------*/
            /* Dataset exists                                                                             */
            /*--------------------------------------------------------------------------------------------*/
            %isdata(dataset=&censordataset.);
            %if %eval(&nobs.>0) %then %do;
            
            /*--------------------------------------------------------------------------------------------*/
            /* Aggregate data across all DPs and stack DP data                                            */
            /*--------------------------------------------------------------------------------------------*/

        	proc means data=&censordataset.(where=(levelid="&levelid")) noprint nway;
                var &censorreason.;
                class &groupvar. &dayvar. / missing;
        		output out=sum_censor(drop=_:) sum=;
        	run;

            %if &stratifybydp. = Y %then %do;
                data sum_censor;
                    set &censordataset.(where=(levelid="&levelid" keep=&censorreason. &groupvar. &dayvar. dpidsiteid))
                        sum_censor(in=a);
                        if a then dpidsiteid = 'ALL';
                run;
            %end;

            /*--------------------------------------------------------------------------------------------*/
            /* Statistics for each censor reason                                                          */
            /*--------------------------------------------------------------------------------------------*/
  
/*            proc means data= &data.1 (where = (level = "&lvl.")) nway missing noprint ;*/
/*                var &catvar.;*/
/*                class &grp. dpidsiteid level;*/
/*                freq &&endvar.;*/
/*                output out=_censor (drop = _type_)      */
/*                                        N = _N*/
/*                                        mean = _mean */
/*                                        std = _std*/
/*                                        min = _min*/
/*                                        p1  = _p1*/
/*                                        p5  = _p5*/
/*                                        p10 = _p10*/
/*                                        p25 = _p25*/
/*                                        median = _median */
/*                                        q3 = _p75*/
/*                                        p90 = _p90*/
/*                                        p95 = _p95*/
/*                                        p99 = _p99*/
/*                                        max = _max;*/
/*         run;*/

            /*--------------------------------------------------------------------------------------------*/
            /* Missing value indicators                                                                   */
            /*--------------------------------------------------------------------------------------------*/
       

            /*--------------------------------------------------------------------------------------------*/
            /* Apply labels                                                                               */
            /*--------------------------------------------------------------------------------------------*/

   
            /*--------------------------------------------------------------------------------------------*/
            /* Clean up                                                                                   */
            /*--------------------------------------------------------------------------------------------*/

            proc datasets lib=work nowarn nolist noprint;
               delete sum_censor;
            quit;

      
        
            %end; /*dataset exists*/
        %end; /*loop through table*/
    %end; /*censor tables requested*/

    proc datasets lib=work nowarn nolist noprint;
       delete _censor_tablefile ;
    quit;

   %put =====> END MACRO: censortable_t6_createdata;

%mend censortable_t6_createdata;
