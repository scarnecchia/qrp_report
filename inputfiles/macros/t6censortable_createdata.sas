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
*   -censordataset: input aggregate dataset
*   -levelid: levelID to restrict dataset
*   -censorreason: list of censor reasons to include in table    
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

%macro censortable_t6_createdata(censordataset=, levelid=, censorreason=) ;

  %put =====> MACRO CALLED: censortable_t6_createdata;


    /*Add all sites*/     
        proc means data= &data. noprint nway;
        var &endproduct. &endavail. &endenroll. &endquery. &enddeath. &endswitch.;
        class &grp. level &classvar. &catvar. / missing;
        output out=_allsites(drop=_:) sum=;
    run;

    data &data.1;
        set &data.
            _allsites(in=a);
            if a then dpidsiteID = 'ALL';
    run;

    *Find what level1 and level2 to subset the data;
    %find_levels;
    %put levels requested ==> &level1. , &level2.;
    %if &tbl. = T8 %then %let lvl = &overall_level.;
    %else %let lvl = &overall_level2.;


    *Create data for each stratification requested;
    %if %sysfunc(exist(&outname.)) %then %do;
        proc datasets noprint nowarn nolist lib=work;
         delete &outname.;
        quit;
    %end;

        %macro runstats(endvar=, num =);

            proc means data= &data.1 (where = (level = "&lvl.")) nway missing noprint ;
                var &catvar.;
                class &grp. dpidsiteid level;
                freq &&endvar.;
                output out=_censor (drop = _type_)      
                                        N = _N
                                        mean = _mean 
                                        std = _std
                                        min = _min
                                        p1  = _p1
                                        p5  = _p5
                                        p10 = _p10
                                        p25 = _p25
                                        median = _median 
                                        q3 = _p75
                                        p90 = _p90
                                        p95 = _p95
                                        p99 = _p99
                                        max = _max;
         run;

         data _censor ;
             set _censor ;
             format tablesub $2. table $4. groupn1 $40.;
             tablesub = "A";
             table = "&tbl.";
             groupn1 = "&endvar.";
             if groupn1 = "productdiscontinuationcount" then 
             groupn1 = "endproductdiscontinuationcount";
             stratsort1 = &num.; 
             if _N = 0 then _N = .; 
         run;
        %isdata(dataset=&outname.);
        %if %eval(&nobs) >0 %then %do;
            data &outname.;
                  set &outname.
                       _censor;
            run;
        %end;
         %else %do;
            data &outname.;
                set _censor;
            run;
         %end;

        proc datasets noprint nowarn nolist lib=work;
         delete _censor  ;
        quit;
     %mend runstats;
     %if "&tbl." = "T9" | "&tbl." = "T10" %then %do;
        %runstats(endvar = &endswitch., num = 0);
     %end;
     %runstats(endvar = %lowcase(&endproduct.), num = 1);
     %runstats(endvar = %lowcase(&endavail.), num = 2);
     %runstats(endvar = %lowcase(&endenroll.), num = 3);
     %runstats(endvar = %lowcase(&endquery.), num = 4);
     %runstats(endvar = %lowcase(&enddeath.), num = 5);

       *sort in order and add grouplabel;
     %if &tbl. = T8 %then %do;
        %let grpvar = group;
        %let grplabel = grouplabel;
        %let inputfile = input.&ProductGroupsFile.;
     %end;
     %else %if &indata. = plotb %then %do;
        %let grpvar = analysisgrp2;
        %let grplabel = analysisgrplabel2;
        %let inputfile = switch2;
    %end;
    %else %do;
        %let grpvar = analysisgrp1;
        %let grplabel = analysisgrplabel1;
        %let inputfile = switch1;
     %end;

     proc sql noprint undo_policy= none;
       create table &outname. as
       select a.*, coalescec(b.&grplabel., a.&grp.) as exposure, b.order
       from &outname. a, &inputfile. b
       where lowcase(a.&grp.) = lowcase(b.&grpvar.)
       order by tablesub, order, stratsort1;
     quit;
     
     proc datasets noprint nowarn nolist lib=work;
         delete _allsites  ;
    quit;

     *output permanent dataset;
     data output.&outname.;
         set &outname.;
     run;
     %put =====> END MACRO: create_censor_distribution v1.1;
   
   /* Clean up work files */
/*    proc datasets lib=work nowarn nolist noprint;*/
/*       delete ;*/
/*    quit;*/

   %put =====> END MACRO: censortable_t6_createdata;

%mend censortable_t6_createdata;
