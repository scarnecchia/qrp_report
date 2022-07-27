****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: collapse_vars.sas  
* Created (mm/dd/yyyy): 12/7/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro reclassifies rows where NPTS [1,10] in order to collapse the value in the report
*
*  Program inputs:                                                                                   
*   - dataset containinga group variable, race, level, and NPTS
* 
*  Program outputs:                                                                                                                                       
*   - dataset where all rows in a stratification are collapsed if a race category is [1,10]
* 
*  PARAMETERS:                                                                       
*   - dataset = input and output dataset. 
*   - dpstrat = Y/N indicator - if Y then will collapse within DP
*   - sumcontinuousvars = list of variables to aggregate up prior to collapsing
*   - groupvar = variable name for group variable
*   - where = optional clause to restrict &dataset
*   - var = collapsing variable, currently only RACE is valid value
*   - list = values of &var. to evalute for collapsing
*   - unknown = value to assign the collapsed row
*   - sort = sort# of the dataset contains a sort variable
*   - varlist = list of variables to include in a proc means var statement when re-aggregating
*   - classlist = list of variables to include in a class statement when re-aggregating
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

%macro collapse_vars(dataset=,
                     dpstrat=N,
                     sumcontinuousvars=, 
                     groupvar=group,
                     where =1, 
                     var=race,
                     list=, 
                     unknown=, 
                     sort=, 
                     varlist=, 
                     classlist=);

    /*first determine which rows require collapsing*/;
    %let collapserows = N;

    %if %str("&sumcontinuousvars.") ne %str("") %then %do;
        %let classlist1 = &classlist.;
        %do c = 1 %to %sysfunc(countw(&sumcontinuousvars.));
            %let classlist1 = %sysfunc(tranwrd(&classlist1., %scan(&sumcontinuousvars., &c.), ));
        %end;
        proc means data=&dataset.(where=(&where.)) nway noprint missing;
            var npts;
        	class &classlist1. / missing;
            output out=_tempcollapse(drop=_:) sum=;
        run;

        data _tempcollapse;
            set _tempcollapse;
            if &var. in (&list) then do;
                if 1 <= npts <=10 then do;
                    collapse='Y';
                    call symputx('collapserows', 'Y');
                end;
            end;
        run;
    %end;
    %else %do;
    data _tempcollapse;
        set &dataset.(where=(&where));
        if &var. in (&list) then do;
            if 1 <= npts <=10 then do;
                collapse='Y';
                call symputx('collapserows', 'Y');
            end;
        end;
    run;
    %end;

    %if &collapserows = Y %then %do;

        /*if any rows are collapse - collapse that stratification in the table. 
          For example, if collapsing race = 1 in a race*sex table for Males, 
          need to also collapse for Females*/
        proc sql noprint;
            create table _collapselookup as
            select distinct &groupvar.
                           , &var.
                           , level
                           , collapse
                           %if &dpstrat = Y %then %do;
                           , dpidsiteid
                           %end;
            from _tempcollapse(where=(collapse='Y'));
        quit;

        data &dataset.(drop=collapse);
            if 0 then set _collapselookup;
            declare hash pt (hashexp:16, dataset:"_collapselookup");
            pt.definekey("&groupvar", "&var", "level" %if &dpstrat = Y %then %do; ,"dpidsiteid" %end;);
            pt.definedone();

            do until(eof1);
                set &dataset. end=eof1;
                if pt.find()=0 then do;
                        &var. = &unknown.;
                        %if %str("&sort.") ne %str("") %then %do;
                        sortorder&sort. = 6;
                        %end;
                    output;
                end;
                else do;
                    output;
                end;
            end;
            stop;
        run;

        *reaggregate;
    	proc means data=&dataset. nway noprint missing;
        	var &varlist.;
        	class &classlist.;
        	output out=&dataset.(drop=_:) sum=;
    	run;

    %end;

    proc datasets nowarn noprint nolist lib=work;
        delete _tempcollapse _collapselookup;
    quit;

%mend collapse_vars;
