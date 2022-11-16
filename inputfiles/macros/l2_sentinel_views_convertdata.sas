****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_sentinel_views_convertdata.sas
* Created (mm/dd/yyyy): 11/09/2022
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Transform qrp_report Type 2 Level 2 reporting datasets into Sentinel Views compatible 
*          datasets.
*
*  Program inputs: 
    Input files:
*   - pscs_masterinputs
*   - psest_masterinputs
*   - repdata.[table(n)]
*   - labelfile
*
*  Program outputs:  
*	- study
*	- analysisgroup
*	- table1
*   - effectest
*   - psdist
*   - kmtable
*   - attrition
*   - monitoringperiod
*
*  PARAMETERS: 
*	queryID: 5 Token Request ID, defined in %create_report as &viewsID
*   jirakey: Associated JIRA key for a query ID
*   userid: A users e-mail
*   studytitle: Title for study
*
*  Programming Notes: 
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO:
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_sentinel_views_convertdata(queryID=,jirakey=,userid=,studytitle=);

	proc datasets library=views kill nowarn nolist; run; quit;

        %let kmtableflag = ;
        %let psdistflag = ;
        %let psdsn=;
        %let repdatadsn=;
        %let psmodelvars=;

        /* Check to see if same periods were specified */
        %let dupperiods=0;
        proc sql noprint;
            select count(*) 
            into :dupperiods trimmed 
            from monitoringfile_views 
            group by periodid
            having count(*) > 1;
        quit;

        proc sql noprint;
            select distinct catx('@',covarnum,studyname)
            into :covarnumlabels 
            separated by '|'
            from covarname;
        quit;


        data pscs_masterinputs_views;
            length adjustmentmethod weightingmethod modelparameters $40;
            set pscs_masterinputs(where=(missing(subgroup)));
            if file = 'psmatchfile' then do;
                weightingmethod = '';
                adjustmentmethod = 'Propensity Score Matched';
                if upcase(ratio) = 'F' then modelparameters="Fixed Ratio 1:"||strip(put(ceiling,8.))||', Caliper='||strip(put(caliper,8.2));
                if upcase(ratio) = 'V' then modelparameters="Variable Ratio 1:"||strip(put(ceiling,8.))||', Caliper='||strip(put(caliper,8.2));
            end;
            if file = 'stratificationfile' then do;
                if not missing(strataweight) then do;
                weightingmethod = strataweight;
                adjustmentmethod = 'Propensity Score Stratum Weighted';
                end;
                else do;
                weightingmethod = '';
                adjustmentmethod = 'Propensity Score Stratified';
                end;
            if not missing(percentiles) then modelparameters='Trimmed'||'; Percentiles= '||strip(put(percentiles,8.));
            else modelparameters='';
            end;
            if file = 'covstratfile' then do;
                weightingmethod = '';
                adjustmentmethod = 'Covariate Stratified';
                do i = 1 to countw(stratvars);
                    vars=scan(propcase(stratvars),i);
                    if i = 1 then modelparameters = vars;
                    else modelparameters=catx(',',modelparameters,vars);
                end;
            end;
            if file = 'iptwfile' then do;
                weightingmethod = ipweight;
                adjustmentmethod = 'Inverse Probability Treatment Weighted';
                modelparameters='Trimmed';
            end;
            if missing(covarnum) then covarnum = 0;
        run;

        data psest_masterinputs_views;
            length tempvar class noclass $2000;
            set psest_masterinputs;
        /* Expand class and noclass covariates */
        do i = 1 to countw(class,' ,');
            word = scan(class,i,' ,');
            if index(word,'-') = 0 then do;
                if i = 1 then do;
                    tempvar=word;
                end;
                else do;
                    tempvar=catx(' ',tempvar,word);
                end;
            end;
            else do;
                start=input(compress(scan(word,1,'-'),'','A'),8.);
                end=input(compress(scan(word,-1,'-'),'','A'),8.);
                do covar = start to end;
                    if i = 1 and covar = start then do;
                        tempvar=cats("COVAR",covar);
                    end;
                    else do; 
                        tempvar=catx(' ',tempvar,cats("COVAR",covar));
                    end;
                end;
            end;
        end;
        class=tempvar;
        do i = 1 to countw(noclass,' ,');
            word = scan(noclass,i,' ,');
            if index(word,'-') = 0 then do;
                if i = 1 then do;
                    tempvar=word;
                end;
                else do;
                    tempvar=catx(' ',tempvar,word);
                end;
            end;
            else do;
                start=input(compress(scan(word,1,'-'),'','A'),8.);
                end=input(compress(scan(word,-1,'-'),'','A'),8.);
                do covar = start to end;
                    if i = 1 and covar = start then do;
                        tempvar=cats("COVAR",covar);
                    end;
                    else do; 
                        tempvar=catx(' ',tempvar,cats("COVAR",covar));
                    end;
                end;
            end;
        end;
        noclass=tempvar;
        drop tempvar start word end covar i;
        run;

    proc sort data=pscs_masterinputs_views nodupkey;
        by runid covarnum analysisgrp;
    run;

    proc sort data = l2comparisonfile out=uniquepsest;
        by order;
    run;

        /* Create analysisgrp, psestimategrp and unique_psestimate combination */
    proc sql noprint;
        select catx('|',catx('@',analysisgrp,psestimategrp),unique_psestimate)
        into :combs
        separated by '$'
        from uniquepsest;
    quit;

    proc sql noprint;
        /* Read in l2comparison for analysisgrp values and order values */
        create table analysistable as 
        select distinct a.runid, a.analysisgrp, a.order as sortingorder, b.weightingmethod, b.adjustmentmethod, b.modelparameters,
               coalescec(b.eoi,c.eoi) as exposure length=40, coalescec(b.ref,c.ref) as reference length=40, "" as design length=1
               %if &labelfileexists = Y %then %do;
               ,case when not missing(d.label) then d.label else "ADD OUTCOME LABEL" end as outcome length=200 
               ,case when not missing(e.label) then e.label else coalescec(e.group,a.analysisgrp) end as analysisgrouptitle length=200
               ,case when not missing(f.label) then f.label else coalescec(f.group,b.eoi,c.eoi) end as exposurelabel length=200
               ,case when not missing(g.label) then g.label else coalescec(g.group,b.ref,c.ref) end as referencelabel length=200
               %end;
               %else %do;
               ,a.analysisgrp as analysisgrouptitle length=200
               ,"ADD OUTCOME LABEL" as outcome length=200
               ,coalescec(b.eoi,c.eoi) as exposurelabel length=200
               ,coalescec(b.ref,c.ref) as referencelabel length=200
               %end;
        from l2comparisonfile a 
        left join pscs_masterinputs_views b 
        on a.analysisgrp = b.analysisgrp
        left join psest_masterinputs_views c 
        on b.psestimategrp = c.psestimategrp 
        %if &labelfileexists = Y %then %do;
        left join labelfile(where=(labeltype='outcomelabel')) d 
        on d.group = a.analysisgrp 
        left join labelfile(where=(labeltype='grouplabel')) e 
        on e.group = a.analysisgrp 
        left join labelfile(where=(labeltype='grouplabel')) f 
        on f.group = coalescec(b.eoi,c.eoi) 
        left join labelfile(where=(labeltype='grouplabel')) g 
        on g.group = coalescec(b.ref,c.ref)  
        %end;
        ;

        select distinct catx('#',psgrp,tempvar) length=4000
        into :psmodelvars separated by '|'
        from (select coalescec(a.psestimategrp,b.psestimategrp) as psgrp, catx(' ',upper(compbl(class)), upper(compbl(noclass))) as tempvar length=4000 
              from psest_masterinputs a, pscs_masterinputs b
              where a.psestimategrp = b.psestimategrp);

        /* Read in all datasets */
        select catx('.','repdata',memname) 
        into :repdatadsn separated by '@'
        from dictionary.tables 
        where libname = 'REPDATA' and prxmatch('/^table\d|^figure\d/i',memname);
    quit;

    /* If only a CS analysis is defined, create a dummy value to loop at least once */
    %if %length(&psmodelvars) = 0 %then %let psmodelvars = dummypsgrp#dummycovar|;

    %if &dupperiods > 1 %then %do;
    proc sql noprint;
        create table monitoringperiod_lookup as 
        select a.runid, a.analysisgrp, b.periodid, b.periodid2
        from analysistable a, monitoringfile_views b 
        where a.runid = b.runid;
    quit;
    %end;

    /* Loop all datasets to determine which it is */
    %do i = 1 %to %sysfunc(countw(&repdatadsn,@));
        %let dsn = %scan(&repdatadsn,&i,@);
        %do dpcnt = 0 %to &num_dp;
            %let dsid=%sysfunc(open(&dsn));
            %let check_table1=%sysfunc(varnum(&dsid,exp_mean&dpcnt));
            %let check_table2=%sysfunc(varnum(&dsid,HR_95CI));
            %let check_attrtable=%sysfunc(varnum(&dsid,report_descr));
            %let check_kmtable=%sysfunc(varnum(&dsid,day));
            %let check_psdist=%sysfunc(varnum(&dsid,ps_cat));
            %let rc=%sysfunc(close(&dsid));

            %if &check_table1 > 0 %then %do;
                data _table1_&dpcnt._&i.;
                    set &dsn(drop=subgroupcat);
                    length dp $5 unique_psestimate 3 subgroupcat psestimategrp $40;
                    table1order=_n_;
                    /* Change back standardized race/hispanic/sex values */
                    if upcase(metvar) = 'RACE_0' then metvar = 'RACE_UNKNOWN';
                    if upcase(metvar) = 'RACE_1' then metvar = 'AMERICANINDIAN';
                    if upcase(metvar) = 'RACE_2' then metvar = 'ASIAN';
                    if upcase(metvar) = 'RACE_3' then metvar = 'BLACK';
                    if upcase(metvar) = 'RACE_4' then metvar = 'PACIFICISLANDER';
                    if upcase(metvar) = 'RACE_5' then metvar = 'WHITE';
                    if upcase(metvar) = 'RACE_M' then metvar = 'MULTI';
                    if upcase(metvar) = 'SEX_M' then metvar = 'MALE';
                    if upcase(metvar) = 'SEX_F' then metvar = 'FEMALE';
                    if upcase(metvar) = 'SEX_O' then metvar = 'SEX_OTHER';
                    if upcase(metvar) = 'HISPANIC_Y' then metvar = 'HISPANIC_YES';
                    if upcase(metvar) = 'HISPANIC_N' then metvar = 'HISPANIC_NO';
                    if upcase(metvar) = 'HISPANIC_U' then metvar = 'HISPANIC_UNKNOWN';
                /* Add on unique_psestimate and psestimategrp */
                %do n = 1 %to %sysfunc(countw(&combs,%str($)));
                    %let comb = %scan(&combs,&n,%str($));
                if analysisgrp = "%scan(&comb,1,%str(@))" then do;
                    unique_psestimate=%scan(&comb,-1,%str(|));
                    psestimategrp="%scan(%substr(&comb,%index(&comb,@)+1),1,%str(|))";
                end;
                %end;
                /* Change unicode value to symbol */
                if indexw(label,"(*ESC*){unicode '2265'x}") then label=tranwrd(label,"(*ESC*){unicode '2265'x}",">=");
                pscovariate='N';
                %do m = 1 %to %sysfunc(countw(&psmodelvars,%str(|)));
                    %let psmodelcomb = %scan(&psmodelvars,&m,%str(|));
                    %let psestgrp = %scan(&psmodelcomb,1,%str(#));
                    %let psmodelvarsin = %scan(&psmodelcomb,-1,%str(#));
                if psestimategrp = "&psestgrp" then do;
                    %do z = 1 %to %sysfunc(countw(&psmodelvarsin));
                        %let psmodelvar = %scan(&psmodelvarsin,&z);
                            %if &psmodelvar = AGE %then %do; 
                            if prxmatch('/AGE/',metvar) then pscovariate = 'Y';
                            %end;
                            %if &psmodelvar = AGEGROUP %then %do; 
                            if prxmatch('/AGE\d/',metvar) then pscovariate = 'Y';
                            %end;
                            %if &psmodelvar = RACE %then %do; 
                            if prxmatch('/ASIAN|WHITE|AMERICAN*|BLACK*|PACIFIC*|MULTI*|RACE*/',metvar) then pscovariate='Y';
                            %end;
                            %if &psmodelvar = SEX %then %do;
                            if prxmatch('/SEX*|FEMALE|MALE/',metvar) then pscovariate = 'Y';
                            %end;
                            %if &psmodelvar = YEAR %then %do;
                            if prxmatch('/YEAR*/',metvar) then pscovariate = 'Y';
                            %end;
                            %if &psmodelvar = HISPANIC %then %do;
                            if prxmatch('/HISPANIC*/',metvar) then pscovariate = 'Y';
                            %end;
                            %if %sysfunc(prxmatch(/COVAR*|^NUM*|COMORBID*/,&psmodelvar)) %then %do; 
                            if strip(metvar) = "&psmodelvar" then pscovariate = 'Y';
                            %end;
                    %end;
                end;/* psestimategrp */
                %end; /* m */
                if prxmatch('/AGE\d/',metvar) > 0 then do;
                    COVARNUM=1001;
                    subgroupcat=tranwrd(substr(metvar,4,length(metvar)),'_','-');
                    /* add plus sign to subgroupcat for age group stratification */
                    if index(label,">=") then subgroupcat=cats(subgroupcat,'+');
                end;
                if prxmatch('/ASIAN|WHITE|AMERICAN*|BLACK*|PACIFIC*|MULTI*|RACE*/',metvar) > 0 then do;
                    COVARNUM=1012;
                    if prxmatch('/AMERICAN*/',metvar) > 0 then subgroupcat='1';
                    if prxmatch('/ASIAN/',metvar) > 0 then subgroupcat='2';
                    if prxmatch('/BLACK*/',metvar) > 0 then subgroupcat='3';
                    if prxmatch('/MULTI*/',metvar) > 0 then subgroupcat='M';
                    if prxmatch('/PACIFIC*/',metvar) > 0 then subgroupcat='4';
                    if prxmatch('/RACE*/',metvar) > 0 then subgroupcat='0';
                    if prxmatch('/WHITE/',metvar) > 0 then subgroupcat='5';
                end;
                if prxmatch('/YEAR*/',metvar) > 0 then do;
                    COVARNUM=1002;
                    subgroupcat=scan(metvar,-1,'_');
                end;
                if prxmatch('/SEX*|FEMALE|MALE/',metvar) > 0 then do;
                    COVARNUM=1000;
                    if prxmatch('/^FEMALE/',metvar) > 0 then subgroupcat='F';
                    if prxmatch('/^MALE/',metvar) > 0 then subgroupcat='M';
                    if prxmatch('/SEX*/',metvar) > 0 then subgroupcat='O';
                end;
                if prxmatch('/HISPANIC*/',metvar) > 0 then do;
                    COVARNUM=1013;
                    subgroupcat=substr(scan(metvar,-1,'_'),1,1);
                end;
                if prxmatch('/COVAR*/',metvar) > 0 then do;
                    COVARNUM=put(compress(metvar,'','A'),8.);
                    subgroupcat='';
                end;
                /* Remove lab covariate rows */
                if grouper = "Laboratory Characteristics" then delete;
                if &dpcnt. = 0 then dp = "agg";
                else if &dpcnt ^= 0 and &dpcnt < 10 then dp ="DP0&dpcnt";
                else if &dpcnt >= 10 then dp = "DP&dpcnt.";
                rename table=type exp_mean&dpcnt=exp_mean exp_std&dpcnt=exp_std comp_mean&dpcnt=comp_mean comp_std&dpcnt.=comp_std
                        sd&dpcnt=sd ad&dpcnt=ad;
                drop exp_mean&dpcnt._char exp_std&dpcnt._char comp_mean&dpcnt._char comp_std&dpcnt._char sd&dpcnt._char ad&dpcnt._char;
                run;

                /* Join monitoring period when there are multiple runs */
                %if &dupperiods > 1 %then %do;
                proc sql noprint undo_policy=none;
                    create table _table1_&dpcnt._&i. as 
                    select 
                    B.label, B.grouper, B.metvar, B.analysisgrp, B.type, B.weight, B.vartype, B.exp_mean, b.table1order,
                    B.comp_mean, B.exp_std, B.comp_std, B.ad, B.sd, b.subgroup, B.subgroupcat, B.dp, a.periodid2 as monitoringperiod, B.pscovariate, 
                    B.COVARNUM, B.unique_psestimate, B.psestimategrp
                    from monitoringperiod_lookup a right join _table1_&dpcnt._&i. b 
                    on a.periodid = b.monitoringperiod and a.analysisgrp = b.analysisgrp
                    order by table1order;
                quit;
                %end;
            %end;/* Check table 1 */

        /* Only set in aggregate tables */
        %if &dpcnt = 0 %then %do;
            /* Check and output propensity score distribution datasets */
            %if &check_psdist > 0 %then %do; 
                %let psdistflag = 1;
                data _psdist_&i;
                    set &dsn;
                run;
            %end;

            %if &check_table2 > 0 %then %do;

                %let deletesubgroups=;
                proc sql noprint; 
                    select distinct subgroup 
                    into :deletesubgroups separated by ' '
                    from &dsn;
                quit; 

                data _effectest_&i(drop=varlabel i);
                    set &dsn;
                    length varlabel $2000 covarnum_label $200;
                    COVARNUM=0;
                    catnum=0;
                    if ^missing(subgroup) then catnum=subgroupcatorder;
                    /* Remove overall rows from subgroup tables */
                    %if %length(&deletesubgroups) > 0 %then %do; 
                    if missing(subgroup) then delete;
                    %end;
                    if subgroup='sex' then COVARNUM=1000;
                    if subgroup='agegroup' then COVARNUM=1001;
                    if subgroup='year' then COVARNUM=1002;
                    if subgroup='periodid' then COVARNUM=1003;
                    if subgroup='race' then COVARNUM=1012;
                    if subgroup='hispanic' then COVARNUM=1013;
                    if subgroup='dpidsiteid' then COVARNUM=9000;
                    if index(subgroup,'covar') then COVARNUM=put(compress(subgroup,'','A'),8.);
                    if COVARNUM in (1:999) then do;
                        do i = 1 to countw("&covarnumlabels",'|');
                            varlabel = scan("&covarnumlabels",i,'|');
                            if COVARNUM = scan(varlabel,1,'@') then COVARNUM_Label = scan(varlabel,-1,'@');
                        end; 
                    end;
                    drop subgroup;
                run;
                %if &dupperiods > 1 %then %do;
                    proc sql noprint undo_policy=none;
                        create table _effectest_&i. as 
                        select B.medicalproduct, B.subgroupcat, B.analysisgrp, B.analysis, 
                                a.periodid2 as monitoringperiod, B.COVARNUM, B.catnum, B.n, B.FUTime_Y, B.AvgFUTime_D, B.AvgFUTime_Y, B.EV, 
                                B.totalevents, B.IR_1000PY, B.risk_1000NU, B.IRDiff_1000PY, B.RD_1000NU, B.poprisk, B.nnt, B.ar, 
                                B.par, B.EVchar, B.rrchar, B.IR_1000PYchar, B.IRDiff_1000PYchar, B.RD_1000NUchar, 
                                B.risk_1000NUchar, B.FUTime_Ychar, B.AvgFUTime_Dchar, B.AvgFUTime_Ychar, B.sort1, B.sort2, 
                                B.analysisgrpsort, B.title, B.HR_95CI, B.HR_pvalue, B.HR, B.LCL, B.UCL, B.HR_coef, B.HR_se, 
                                B.LABEL, B.medicalproduct_labeled, B.COVARNUM_Label
                        from monitoringperiod_lookup a right join _effectest_&i. b 
                        on a.periodid = b.monitoringperiod and a.analysisgrp = b.analysisgrp;
                    quit;
                %end;
            %end;

            %if &check_attrtable > 0 %then %do;
                data _attrition_&i(keep=monitoringperiod analysisgrp medicalproduct level descr remaining excluded);
                    length analysisgrp medicalproduct $40;
                    set &dsn;
                    analysisgrp=scan(group,1,'@');
                    medicalproduct=scan(group,-1,'@');
                    rename report_descr = descr
                           agg_remaining = remaining 
                           agg_excluded = excluded;
                run;
                %if &dupperiods > 1 %then %do;
                    proc sql noprint undo_policy=none;
                        create table _attrition_&i. as 
                        select B.analysisgrp, B.medicalproduct, B.descr, B.level, B.remaining, B.excluded, 
                               a.periodid2 as monitoringperiod
                        from monitoringperiod_lookup a right join _attrition_&i. b 
                        on a.periodid = b.monitoringperiod and a.analysisgrp = b.analysisgrp
                        order by analysisgrp, level, descr;
                    quit;
                %end;
            %end;

            %if &check_kmtable > 0 %then %do;
                /* Check that at least one kmtable was created */
                %let kmtableflag = 1;

                proc contents data = &dsn noprint out=_metanames(keep=name);
                run;

                /* Store at risk columns and km columns in macro variables to be transposed */
                proc sql noprint;
                    select lower(name) 
                    into :atriskcols 
                    separated by ' '
                    from _metanames
                    where lower(name) in ('episodes_atriskexp' 'episodes_atriskunexp' /* 'episodes_atriskunexp_wght' */);

                    select lower(name)  
                    into :kmcols 
                    separated by ' '
                    from _metanames
                    where lower(name) in ('km_evexp' 'km_evunexp' /* 'km_evunexp_wght' */);
                quit;

                data _null_;
                    if _n_=1 then do; 
                    dcl hash H(multidata:'y') ;   
                    h.definekey("analysisgrp") ;   
                    h.definedata("time", "subgroup", "subgroupcat", "dpidsiteid", "atrisk", "Km_estimate", "analysisgrp", "group", "medicalproduct", "analysis", "monitoringperiod");  
                    h.definedone() ;   
                    end;
                    length analysisgrp group medicalproduct $40 analysis $13;
                    set &dsn(rename=(day=time)) end=lr;
                    array t eoi ref;
                    array w eoilabel reflabel;
                    array z &atriskcols;
                    array y &kmcols;
                    do over z;
                        if not missing(z) then do;
                        medicalproduct=t;
                        atrisk=z;
                        group=w;
                        Km_estimate=y;
                        h.add();
                        end;
                    end;
                    if lr then h.output(dataset:"_km_&i");
                    run;
                %if &dupperiods > 1 %then %do;
                proc sql noprint undo_policy=none feedback;
                    create table _km_&i. as
                    select B.time, B.atrisk, B.Km_estimate, B.analysisgrp, B.group, B.medicalproduct,
                    B.analysis, b.subgroup, b.subgroupcat, b.dpidsiteid, a.periodid2 as monitoringperiod
                    from monitoringperiod_lookup a right join _km_&i. b
                    on a.periodid = b.monitoringperiod and a.analysisgrp = b.analysisgrp
                    order by time, atrisk, Km_estimate, analysisgrp, group, B.medicalproduct,
                    B.analysis, a.periodid2;
                quit;
                %end; /* dupperiods */
            %end; /* Check KM table */
        %end; /* dpcnt = 0 */
        %end; /* dpcnt */
    %end; /* i */

    /* Output all transformed tables to folder */
    data views.study;
        length queryid jirakey userid $40 studytitle $200;
        queryid="&queryid";
        %if %length(&jirakey) = 0 %then %do;
            jirakey="QF-0000";
        %end;
        %else %do;
            jirakey="&jirakey";
        %end;
        %if %length(&userid) = 0 %then %do;
            userid="qf@sentinelsystem.org";
        %end;
        %else %do;
            userid="&userid";
        %end;
        %if %length(&studytitle) = 0 %then %do;
            studytitle="ADD STUDY TITLE";
        %end;
        %else %do;
            studytitle="&studytitle";
        %end;
            output;
    run;

    /* Check to see if at least 1 km dataset exists */
    %if &kmtableflag = 1 %then %do;
        data views.kmtable;
            set _km:;
            where missing(subgroup) and dpidsiteid='ALL';
            keep time atrisk km_estimate analysisgrp group medicalproduct analysis monitoringperiod;
        run;
    %end;

    data table1;
        set _table1_:;
        /* Rounding done to avoid scientific notation */
        ad=round(ad,0.001);
        sd=round(sd,0.001);
        where missing(subgroup);
    run;

    /* Need to recreate unadjusted tables for groups */
    %let uniquepsest=;
    proc sql noprint;
        select distinct unique_psestimate
        into :uniquepsest
        separated by ' '
        from table1
        where unique_psestimate > 1;

        select distinct psestimategrp
        into :psestgrp 
        separated by ' '
        from table1;
    quit;

    %if %length(&uniquepsest) > 0 %then %do;
        %do x = 1 %to %sysfunc(countw(&psestgrp));
            %let psgrpvalue = %scan(&psestgrp,&x);
            /* Create the main unadjusted datasets that need to be merged on */
            data table1_unadj_&x.;
                set table1;
                where unique_psestimate = 1 and psestimategrp = "&psgrpvalue" and type="Unadjusted";
            run;

            %let unadjgroups=;
            proc sql noprint;
                select distinct analysisgrp 
                into :unadjgroups 
                separated by ' '
                from table1 
                where unique_psestimate > 1 and psestimategrp = "&psgrpvalue";
            quit;

            %if %length(&unadjgroups) > 0 %then %do;
                %do z = 1 %to %sysfunc(countw(&unadjgroups));
                    %let grpval = %scan(&unadjgroups,&z);
                    data _table1_unadj_&x._&z.;
                        set table1_unadj_&x.;
                        analysisgrp="&grpval";
                    run;
                %end;
            %end;
        %end;
    %end;

    data _temptable1;
        set %if %length(&uniquepsest) > 0 %then %do; _table1_: %end;
            %else %do; table1 %end;
        ;
        /* Set original table order for platform */
        table1order=_n_;
        where missing(subgroup);
        drop unique_psestimate psestimategrp;
    run;

    /* Create a rank/order variable grouped by label, grouper and metvar */
    proc sql noprint;
    create table _temptable1order as 
    select label, grouper, metvar, analysisgrp, 
           type, weight, vartype, monitoringperiod, exp_mean, comp_mean, exp_std, 
           comp_std, ad, sd, subgroupcat, dp, pscovariate, covarnum, table1order, min(table1order) as socrank
    from _temptable1
    group by label, grouper, metvar
    order by grouper;
    quit;

    /* Re-assign the rank variable only on the grouper */
    proc rank data = _temptable1order ties=dense out=_temptable1order;
    var socrank;
    by grouper ;
    label socrank = ' ';
    run;

    proc sort data = _temptable1order out=views.table1(drop=table1order);
        by table1order;
    run;

    data views.effectest;
        set _effectest_:;
    run;

    data views.attrition;
        set _attrition:;
        /* Delete rows not relevant for Sentinel Views */
        if index(level,'.') then delete;
        if descr = 'Number of events in comparative analysis' then delete;
        if descr = 'Number of episodes' then delete;
        if descr = 'Number of members' then delete;
        if descr = 'Excluded due to same-day initiation of both exposure groups' then delete;
        if descr = 'Number of patients with a truncated inverse probability of treatment weight' then delete;
    run;

    /* Check if medicalproduct_labeled variable exists, if not, assign it values and a label */
    %let dsid=%sysfunc(open(views.effectest));
    %let add_vars=%sysfunc(varnum(&dsid,medicalproduct_labeled));
    %let rc = %sysfunc(close(&dsid));

    %if &add_vars = 0 %then %do;
    data views.effectest;
        set views.effectest;
        medicalproduct_labeled=medicalproduct;
        label=medicalproduct;
    run;
    %end;

    /* Re-assign values for dates in monitoring file */
    data views.monitoringperiod(keep=monitoringperiod startdate enddate);
        set monitoringfile_views;
        if not missing(fupenddate) then enddate=fupenddate;
        else if not missing(indenddate) then enddate=fupenddate;
        rename periodid2=monitoringperiod;
        format enddate date9.;
    run;

    %if &psdistflag = 1 %then %do;
    data views.psdist(drop=subgroup subgroupcat);
        set _psdist_:;
        where missing(subgroup);
    run;
    %end;

    data views.analysisgroup;
        set analysistable;
        drop runid;
    run;

    proc datasets library=work nolist nowarn;
        delete analysistable _psdist: monitoringfile_views _attrition: _km: _temptable1: table1: _table1:
        _metanames _effectest: pscs_masterinputs_views psest_masterinputs_views uniquepsest; 
    quit;		
%mend l2_sentinel_views_convertdata;