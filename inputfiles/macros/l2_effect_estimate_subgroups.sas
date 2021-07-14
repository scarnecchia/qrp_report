****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_subgroups.sas  
* Created (mm/dd/yyyy): 02/04/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*	For L2 analyses, map COVARNUM to subgroup description and determine number of and value of 
*   each category within subgroup
*   
*  Program inputs:                      
*  - covarnum = COVARNUM from QRP package to compute macro variables
*  - computecategories = Y/N indicator to compute category values.
* 
*  Program outputs:   
*   - &subgroupvar = variable name for the covarnum
*   - &sublabel = label for the subgroup
*   - &numsubcat = number of subgroup categories
*   - &subcategorization = list of subgroup categories
* 
*  Programming Notes:                                                                                
*	- 
* 
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_subgroups(covarnum=, computecategories=);

    %put =====> MACRO CALLED: l2_effect_estimate_subgroups;

    /* COVARNUM mapping:
        - 1-999: covarnum from covariatecodes file
        - 1000: sex
        - 1001: age group
        - 1002: year
        - 1003: time
        - 1004-1011: currently not used
        - 1012: race
        - 1013: hispanic
        - 1014: preterm-posterm indicator (reporttype = T4L2 only)
        - 2000: match method (reporttype = T4L2 only)
        - 2001: birth type (reporttype = T4L2 only) */

    %let subgroupvar = ;
    %let sublabel = ;
    %let numsubcat = ;
    %let subcategorization = ;

    %if %eval(&covarnum. <1000) %then %do;
        %let subgroupvar = covar&covarnum.;
        %let numsubcat = 2;
	    %let sublabel = %cmpres(Covar&covarnum.);
        proc sql noprint;
            select distinct trim(left(studyname)) into: sublabel
            from infolder.&&&runid._covariatecodes
            where covarnum = &covarnum.;
        quit;
        %let subcategorization = 0 1;
    %end;
    %else %if &covarnum. = 1000 %then %do; 
        %let subgroupvar = Sex;
        %let sublabel = Sex;
        %let numsubcat = 2;
        %let subcategorization = F M; /*O is excluded due to low patient counts*/
    %end;
    %else %if &covarnum. = 1001 %then %do;
        %let subgroupvar = age_cat;
        %let sublabel = Age Group;

        %if &computecategories. = Y %then %do;
            /*if reporttype = T4L2 extract original cohortgrp*/
            %if %str("&reporttype.") = ("T4L2") %then %do;
                data _null_;
                    set infolder.&&&runid._micohortfile(where=(milgrp=substr("&grp1.",1,length("&grp1")-4)));
                    call symputx('cohortgrp', strip(groupname));
                run;
            %end;
            %else %if %str("&reporttype.") = ("T2L2") %then %do;
                %let cohortgrp = &grp1.;
            %end;

            data _null_;
                set infolder.&&&runid._cohortfile(keep=agestrat cohortgrp where=(lowcase(cohortgrp)="&cohortgrp."));
                if missing(agestrat) then do;
                    call symputx("subcategorization","00-01 02-04 05-09 10-14 15-18 19-21 22-44 45-64 65-74 75+");
                    call symputx("numsubcat",10);
                end;
                else do;
                    call symputx("subcategorization",agestrat);
                    call symputx("numsubcat",countw(agestrat," "));
                end;
            run;
        %end;
    %end;
    %else %if &covarnum. = 1002 %then %do;
        %let subgroupvar = Year;
        %let sublabel = Year;
        %if &computecategories. = Y %then %do;
            %let numsubcat = %eval(&&maxyear&periodid. - &minqueryyear + 1);
            %let subcategorization=;
            %do year = &minqueryyear. %to &&maxyear&periodid.;
                %let subcategorization = &subcategorization. &year.;
            %end;
            ;
        %end;
    %end;
    %else %if &covarnum. = 1003 %then %do;
        %let subgroupvar = Time;
        %let sublabel = Monitoring Period;
        %if &computecategories. = Y %then %do;
            %let numsubcat = %eval(&periodid.);
            %let subcategorization=;
            %do time = 1 %to &periodid.;
                %let subcategorization = &subcategorization. &time.;
            %end;
            ;
        %end;
    %end;
    %else %if &covarnum. = 1012 %then %do;
        %let subgroupvar = Race;
        %let sublabel = Race;
        %let numsubcat = 6;
        %let subcategorization = 1 2 3 4 0 5 ; /* Determines ordering */
    %end;
    %else %if &covarnum. = 1013 %then %do;
        %let subgroupvar = Hispanic;
        %let sublabel = Hispanic Origin;
        %let numsubcat = 3;
        %let subcategorization = Y N U;
    %end;
    %else %if &covarnum. = 1014 %then %do;
        %let subgroupvar = prepostind;
        %let sublabel = Delivery Status;
        %let numsubcat = 4;
        %let subcategorization = PRE TERM POST NONE;
    %end;
    %else %if &covarnum. = 2000 %then %do;
        %let subgroupvar = MatchMethod;
        %let sublabel = Match Method;
        %let numsubcat = 9;
        %let subcategorization = BC RE SI LA OT N1 N2 N3 NA;
    %end;
    %else %if &covarnum. = 2001 %then %do;
        %let subgroupvar = birth_type;
        %let sublabel = Birth Type;
        %let numsubcat = 8;
        %let subcategorization = 0 1 2 3 4 5 8 9;
    %end;
    %else %do;
        %put WARNING: (Sentinel) Covarnum &covarnum. is not currently supported.;
    %end;

    %put subgroup variables for covarnum &covarnum. have been defined as;
    %put &subgroupvar.;
    %put &sublabel.;
    %put &numsubcat.;
    %put &subcategorization.;

    %put NOTE: ******** END OF MACRO: l2_effect_estimate_subgroups ********;

%mend l2_effect_estimate_subgroups;
