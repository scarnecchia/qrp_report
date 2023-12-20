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
	%let effectestflag = ;
	%let table1flag = ;
    %let repdatadsn=;
    %let psmodelvars=;
    %let riskscore_regex=;

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
        from covarnameviews;

        %if %sysfunc(exist(riskscorefile)) %then %do;
            select distinct cats(riskscore,'_CAT'), riskscore
            into :riskscore_regex separated by '|', :riskscorelist separated by '|'
            from riskscorefile;
        %end;
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
        by runid analysisgrp;
    run;

    /* Create analysisgrp, psestimategrp and unique_psestimate combination */
	%isdata(dataset=baselinefile);
	%if %eval(&nobs.>0) %then %do;
		%let table1flag = 1;
		proc sql noprint; 
			select distinct catx('|',catx('@',analysisgrp,psestimategrp),unique_psestimate)
	        into :combs
	        separated by '$'
	        from baselinefile;
		quit;
	%end;

	%isdata(dataset=l2comparisonfile);
	%if %eval(&nobs.>0) %then %do;
		%let effectestflag = 1;	    
	        
    	proc sql noprint;
        /* Read in l2comparison for analysisgrp values and order values */
        create table analysistable as 
        select distinct a.runid, a.analysisgrp, a.order as sortingorder, b.weightingmethod, b.adjustmentmethod, b.modelparameters,
               coalescec(b.eoi,c.eoi) as exposure length=40, coalescec(b.ref,c.ref) as reference length=40, "" as design length=500
               %if &labelfileexists = Y %then %do;
               ,case when not missing(d.label) then d.label else "ADD OUTCOME LABEL" end as outcome length=500 
               ,case when not missing(e.label) then e.label else coalescec(e.group,a.analysisgrp) end as analysisgrptitle length=500
               ,case when not missing(f.label) then f.label else coalescec(f.group,b.eoi,c.eoi) end as exposurelabel length=500
               ,case when not missing(g.label) then g.label else coalescec(g.group,b.ref,c.ref) end as referencelabel length=500
               %end;
               %else %do;
               ,a.analysisgrp as analysisgrptitle length=500
               ,"ADD OUTCOME LABEL" as outcome length=500
               ,coalescec(b.eoi,c.eoi) as exposurelabel length=500
               ,coalescec(b.ref,c.ref) as referencelabel length=500
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
    	quit;
	%end;
	
	proc sql noprint;		
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

			/******************************************************************/
			/* Table 1: Set in all tables
						Assign PSCOVARIATE and DP indicators
						Drop rows with missing metvar values
						Drop char variables
						Rename variables
					    All other processing done later*/
			/******************************************************************/
            %if &check_table1 > 0 %then %do;
                data _table1_&dpcnt._&i.;
                    set &dsn;
                    length dp $10 unique_psestimate 3 psestimategrp $40;

	                /* Add on unique_psestimate and psestimategrp */
	                %do n = 1 %to %sysfunc(countw(&combs,%str($)));
	                    %let comb = %scan(&combs,&n,%str($));
	                	if analysisgrp = "%scan(&comb,1,%str(@))" then do;
		                    unique_psestimate=%scan(&comb,-1,%str(|));
		                    psestimategrp="%scan(%substr(&comb,%index(&comb,@)+1),1,%str(|))";
	                	end;
	                %end;
            
                	pscovariate='N';
	                %do m = 1 %to %sysfunc(countw(&psmodelvars,%str(|)));
	                    %let psmodelcomb = %scan(&psmodelvars,&m,%str(|));
	                    %let psestgrp = %scan(&psmodelcomb,1,%str(#));
	                    %let psmodelvarsin = %scan(&psmodelcomb,-1,%str(#));
		               	    if psestimategrp = "&psestgrp" then do;
		                    %do z = 1 %to %sysfunc(countw(&psmodelvarsin));
		                        %let psmodelvar = %scan(&psmodelvarsin,&z);
		                            %if &psmodelvar = AGE %then %do; 
		                                if metvar = 'AGE' then pscovariate = 'Y';
		                            %end;
		                            %if &psmodelvar = AGEGROUP %then %do; 
		                                if prxmatch('/AGE\d/',metvar) then pscovariate = 'Y';
		                            %end;
		                            %if &psmodelvar = RACE %then %do; 
		                                if prxmatch('/RACE*/',metvar) then pscovariate='Y';
		                            %end;
		                            %if &psmodelvar = SEX %then %do;
		                                if prxmatch('/SEX*/',metvar) then pscovariate = 'Y';
		                            %end;
		                            %if &psmodelvar = YEAR %then %do;
		                                if prxmatch('/YEAR*/',metvar) then pscovariate = 'Y';
		                            %end;
		                            %if &psmodelvar = HISPANIC %then %do;
		                                if prxmatch('/HISPANIC*/',metvar) then pscovariate = 'Y';
		                            %end;
		                            %if %sysfunc(prxmatch(/COVAR*|^NUM*/,&psmodelvar)) %then %do; 
		                                if strip(metvar) = "&psmodelvar" then pscovariate = 'Y';
		                            %end;
									%if %sysfunc(exist(riskscorefile)) %then %do;
										%do scorenum = 1 %to %sysfunc(countw(&riskscorelist));
											%let score = %scan(&riskscorelist,&scorenum);
											if strip(metvar) = "&psmodelvar" and metvar = "&score." then pscovariate = 'Y';																		
										%end;
									%end;
		                    %end;
	                	end;/* psestimategrp */
	                %end; /* m */
                 
	                if missing(metvar) then delete;              
	                if &dpcnt. = 0 then dp = "Aggregate";
	                else if &dpcnt ^= 0 and &dpcnt < 10 then dp ="DP0&dpcnt";
	                else if &dpcnt >= 10 then dp = "DP&dpcnt.";
	                rename table=type 
						   sortorder1=headerorder
						   exp_mean&dpcnt=exp_mean 
						   exp_std&dpcnt=exp_std 
						   comp_mean&dpcnt=comp_mean
						   comp_std&dpcnt.=comp_std
	                       sd&dpcnt=sd ad&dpcnt=ad;
	                drop exp_mean&dpcnt._char exp_std&dpcnt._char comp_mean&dpcnt._char comp_std&dpcnt._char sd&dpcnt._char ad&dpcnt._char;
                run;

                /* Join monitoring period when there are multiple runs */
                %if &dupperiods > 1 %then %do;
                proc sql noprint undo_policy=none;
                    create table _table1_&dpcnt._&i. as 
                    select 
                    B.label, B.headerorder, B.grouper, B.sortorder2, B.sortorder3, B.sortorder4, B.metvar, B.analysisgrp, B.type, B.weight, B.vartype, B.exp_mean,
                    B.comp_mean, B.exp_std, B.comp_std, B.ad, B.sd, b.subgroup, B.subgroupcat, B.dp, a.periodid2 as monitoringperiod, B.pscovariate, 
                    B.unique_psestimate, B.psestimategrp
                    from monitoringperiod_lookup a right join _table1_&dpcnt._&i. b 
                    on a.periodid = b.monitoringperiod and a.analysisgrp = b.analysisgrp;
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
                    length varlabel $2000 covarnum_label $500;                                                      
                    /* Remove overall rows from subgroup tables */
                    %if %length(&deletesubgroups) > 0 %then %do; 
                    if missing(subgroup) then delete;
                    %end;
                    if index(subgroup,'covar') then do;
						COVARNUM=put(compress(subgroup,'','A'),8.);                    
                        do i = 1 to countw("&covarnumlabels",'|');
                            varlabel = scan("&covarnumlabels",i,'|');
                            if COVARNUM = scan(varlabel,1,'@') then COVARNUM_Label = scan(varlabel,-1,'@');
                        end; 
                    end;
					else COVARNUM=.;      
                    drop subgroup;
                run;
                %if &dupperiods > 1 %then %do;
                    proc sql noprint undo_policy=none;
                        create table _effectest_&i. as 
                        select B.medicalproduct, B.subgroupcat, B.analysisgrp, B.analysis, 
                                a.periodid2 as monitoringperiod, B.COVARNUM, B.n, B.FUTime_Y, B.AvgFUTime_D, B.AvgFUTime_Y, B.EV, 
                                B.totalevents, B.IR_1000PY, B.risk_1000NU, B.IRDiff_1000PY, B.RD_1000NU, B.poprisk, B.nnt, B.ar, 
                                B.par, B.EVchar, B.rrchar, B.IR_1000PYchar, B.IRDiff_1000PYchar, B.RD_1000NUchar, 
                                B.risk_1000NUchar, B.FUTime_Ychar, B.AvgFUTime_Dchar, B.AvgFUTime_Ychar, B.sort1, B.sort2, 
                                B.analysisgrpsort, B.tabletitle, B.HR_95CI, B.HR_pvalue, B.HR, B.LCL, B.UCL, B.HR_coef, B.HR_se, 
                                %if &labelfileexists = Y %then %do; B.LABEL, B.medicalproduct_labeled, %end; B.COVARNUM_Label
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

				%let dsid=%sysfunc(open(&dsn));
	    		%let check_ci=%sysfunc(varnum(&dsid,lowerCI_exp));	    		  
	    		%let rc=%sysfunc(close(&dsid));

                data _null_;
                    if _n_=1 then do; 
                    dcl hash H(multidata:'y') ;   
                    h.definekey("analysisgrp") ;   
                    h.definedata("time", "subgroup", "subgroupcat", "dpidsiteid", "atrisk", "Km_estimate", "analysisgrp", "group", "medicalproduct", "analysis", "monitoringperiod", "lowerci", "upperci");  
                    h.definedone() ;   
                    end;
                    length analysisgrp group medicalproduct $40 analysis $13;
                    set &dsn(rename=(day=time)) end=lr;
                    array t eoi ref;
                    array w eoilabel reflabel;
                    array z &atriskcols;
                    array y &kmcols;
					%if &check_ci. > 0 %then %do;
					array l lowerCI_exp lowerCI_unexp;
					array u upperCI_exp upperCI_unexp;
					%end;
                    do over z;
                        if not missing(z) then do;
                        medicalproduct=t;
                        atrisk=z;
                        group=w;
                        Km_estimate=y;
						%if &check_ci. > 0 %then %do;
						lowerci=l;
						upperci=u;
						%end;
						%else %do;
						lowerci=.;
						upperci=.;
						%end;
                        h.add();
                        end;
                    end;
                    if lr then h.output(dataset:"_km_&i");
                    run;

                %if &dupperiods > 1 %then %do;
                proc sql noprint undo_policy=none feedback;
                    create table _km_&i. as
                    select B.time, B.atrisk, B.Km_estimate, B.analysisgrp, B.group, B.medicalproduct, B.lowerci, B.upperci,
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
        length queryid jirakey $40 studytitle $1000 userid $80;
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

	/* Verify if subgroups and covariates information are available in pscs_masterinputs */
	%let dsid=%sysfunc(open(Pscs_masterinputs));
    %let check_subgroups=%sysfunc(varnum(&dsid,subgroup));
    %let check_covars=%sysfunc(varnum(&dsid,covar));          
    %let rc=%sysfunc(close(&dsid));

	/* Because some output tables do not have runid, deduplicate pscs_masterinputs by 
	   analysisgrp/subgroup/subgroupcat that are agnostic to runid */
	%if &check_subgroups>0 %then %do;
	proc sort nodupkey data=Pscs_masterinputs out=_subgroup_info;
	by analysisgrp subgroup subgroupcat;
	run;
	%end;

	%let submissing=%str(if missing(subgroup) then subgroup="overall";
						if missing(subgroupcat) then subgroupcat="overall";
						if missing(subgrouplabel) then subgrouplabel="Overall Analysis";
						if missing(subgroupcatlabel) then subgroupcatlabel="Overall Analysis";);
	%let suboverall=%str(subgroup="overall";
						subgroupcat="overall";
						tabletitle="Overall Analysis";
						SubgroupCatLabel="Overall Analysis";
						subGroupOrder=1;
						subGroupCatOrder=1;);

	%macro getsubgroupsinfo(dataset=);
		proc sql noprint undo_policy=none;
			create table &dataset. as
			select a.*
				   ,b.tabletitle as subgrouplabel format $500. length=500
				   ,b.subgroupcatlabel as subgroupcatlabel format $500. length=500
				   ,b.subGroupOrder as subGroupOrder format best. length=3
			   	   ,b.subGroupCatOrder as subGroupCatOrder format best. length=3	
			from &dataset. as a
			left join _subgroup_info as b
			on a.analysisgrp=b.analysisgrp and a.subgroup=b.subgroup and a.subgroupcat=b.subgroupcat;
			quit;			
	%mend getsubgroupsinfo;

    /* Check to see if at least 1 km dataset exists */
    %if &kmtableflag = 1 %then %do;
        data views.kmtable;
	    set  _km:;
		/* No subgroups */
		%if &check_subgroups=0 %then %do;
		format subgroup subgroupcat $50. subgrouplabel subgroupcatlabel $500. subGroupOrder subGroupCatOrder best.;
		length subGroupOrder subGroupCatOrder 3;
		&suboverall.;
		%end;
		if dpidsiteid="ALL" or (dpidsiteid ne "all" and missing(subgroup));
		run;

		/* Get subgroups information */
		%if &check_subgroups>0 %then %do;			
			%getsubgroupsinfo(dataset=views.kmtable);
		%end;

		/* Get covariates information */
		%if &check_covars > 0 %then %do;
			proc sql noprint undo_policy=none;
			create table views.kmtable as
			select a.*			   
				   ,c.covarnum
				   ,c.studyname
			from views.kmtable as a		
			left join covarnameviews as c on a.subgroup=c.cov_varname;
			quit;
		%end;

	    data views.kmtable(keep=monitoringperiod analysisgrp analysis medicalproduct Dp subgroup subgroupcat subgrouplabel subgroupcatlabel
			   					subGroupOrder subGroupCatOrder time atrisk KM_estimate lowerci upperci);
		retain monitoringperiod analysisgrp analysis medicalproduct Dp subgroup subgroupcat subgrouplabel subgroupcatlabel
			   subGroupOrder subGroupCatOrder time atrisk KM_estimate lowerci upperci;
		length dp $10 subgroup subgroupcat $50;
		format monitoringperiod 3. dp $10. subgroup subgroupcat $50.;
	    set views.kmtable;
		if dpidsiteid="ALL" then dp="Aggregate";
		else dp=dpidsiteid;
		&submissing.;

		/* Specify correct values for covariates */
		%if &check_covars > 0 %then %do;
		if not missing(covarnum) then do;
			subgrouplabel=studyname;
			if subgroupcat="1" then do;
				subgroupcatlabel="Yes";
				subGroupCatOrder=2;
			end;
			else do;
				subgroupcatlabel="No";
				subGroupCatOrder=1;
			end;
			subGroupOrder=1000+covarnum;
		end;
		%end;
	    run;
    %end; /* KM data requested */

	%if &table1flag. eq 1 %then %do;
	    data table1;
	    set _table1_:;	            
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

	    %let labcharacteristics=N;
	
	    data _temptable1;
	        set %if %length(&uniquepsest) > 0 %then %do; _table1_: %end;
	            %else %do; table1 %end;
	        ;
	        /* Set original table order for platform */
	        /* No subgroups */
			%if &check_subgroups=0 %then %do;
			format subgroup subgroupcat $50. subgrouplabel subgroupcatlabel $500.  subGroupOrder subGroupCatOrder best.;
			length subGroupOrder subGroupCatOrder 3;
			&suboverall.;
			%end;
			if dp="Aggregate" or (dp ne "Aggregate" and missing(subgroup));

			/* Create metvar2 variable to get labs and riskscores required information */
			if grouper="Laboratory Characteristics" then do;
				metvar2=strip(tranwrd(metvar,"N_",""));
				if index(metvar2,"LBUNIT") > 0 then metvar2=substr(metvar2, 1, index(metvar2,"LBUNIT")-1);
				else if index(metvar2,"LBRES") > 0 then metvar2=substr(metvar2, 1, index(metvar2,"LBRES")-1);
				else if index(metvar2,"_NOTEST") > 0 then metvar2=substr(metvar2, 1, index(metvar2,"_NOTEST")-1);
				call symputx("labcharacteristics", "Y");
			end;
			else do;
				metvar2=metvar;
				if index(metvar2,"_CAT") > 0 then metvar2=substr(metvar2, 1, index(metvar2,"_CAT")-1);
			end;

	        drop unique_psestimate;
	    run;	
		
		/* Get riskscores information if necessary */
		%if %sysfunc(exist(riskscorefile)) %then %do;
			proc sort nodupkey data=_temptable1(where=(prxmatch("/&riskscorelist/i",metvar) and metvar=metvar2)) out=_riskscores_info;
			by metvar2;		
			run;

			proc sql noprint undo_policy=none;
			create table _temptable1 as 
			select a.*
				   ,b.label as riskscorelabel
				   ,b.pscovariate as riskscore_pscovariate
			from _temptable1 as a 
			left join _riskscores_info as b
			on a.metvar2=b.metvar2;
			quit;
		%end;
		
		/* Get subgroups information */
		%if &check_subgroups>0 %then %do;
			%getsubgroupsinfo(dataset=_temptable1);			
		%end;

		/* Get covariates information */
		%isdata(dataset=covarnameviews);
		%if %eval(&nobs.>0) %then %do;	
			proc sql noprint undo_policy=none;
			create table _temptable1 as
			select a.*			   
				   ,c.covarnum
				   ,c.studyname
			from _temptable1 as a		
			left join covarnameviews as c on a.subgroup=c.cov_varname;
			
			create table _temptable1 as 
			select a.*
				   ,b.studyname as covarlabel
			from _temptable1 as a 
			left join covarnameviews as b
			on a.metvar2=upcase(b.cov_varname);
			quit;		
		%end;

		/*sort to assign variableorder*/
		proc sort data=_temptable1 out=_temptable1order nodupkey;
			by headerorder sortorder2 sortorder3 sortorder4;
		run;

		data _temptable1order;
			set _temptable1order;
			by headerorder sortorder2 sortorder3 sortorder4;

			/*assignvariableorder*/
			variableorder+1;
			if first.headerorder then variableorder = 1;
		run;

		proc sort data=_temptable1;
			by headerorder sortorder2 sortorder3 sortorder4;
		run;
			
	    data views.table1(keep=monitoringperiod2 analysisgrp type weight dp subgroup subgroupcat subgrouplabel subgroupcatlabel subGroupOrder subGroupCatOrder
			   		   		  headerlabel variableFilterLabel variableLabel headerorder variableOrder pscovariate metvar30 vartype exp_mean exp_std comp_mean comp_std ad sd
						 rename=(metvar30=metvar monitoringperiod2=monitoringperiod));
		retain monitoringperiod2 analysisgrp type weight dp subgroup subgroupcat subgrouplabel subgroupcatlabel subGroupOrder subGroupCatOrder
			   headerlabel variableFilterLabel variableLabel headerorder variableOrder pscovariate metvar30 vartype exp_mean exp_std comp_mean comp_std ad sd;
		length monitoringperiod2 headerorder 3 metvar30 $30 subgroup subgroupcat $50 subgrouplabel subgroupcatlabel $500;
		format monitoringperiod2 3. metvar30 $30. subgroup subgroupcat $50. headerlabel variableFilterLabel $500. variableLabel $1000.;

	    merge _temptable1 
			  _temptable1order;

		by headerorder sortorder2 sortorder3 sortorder4;

		metvar30=metvar;	
		monitoringperiod2=monitoringperiod;
		&submissing.;

		/*assign headerlabel*/
		headerlabel=grouper;
		if metvar="AGE" then headerlabel="Mean Age";
		else if prxmatch('/AGE\d/',metvar) > 0 or label="Age" then headerlabel="Age";
		else if prxmatch('/RACE*/',metvar) > 0 or label="Race" then headerlabel="Race";
		else if prxmatch('/YEAR*/',metvar) > 0 or label="Year" then headerlabel="Year";
		else if prxmatch('/SEX*/',metvar) > 0 or label="Sex" then headerlabel="Sex";
		else if prxmatch('/HISPANIC*/',metvar) > 0 or label="Hispanic origin" then headerlabel="Hispanic";

		/*headerorder takes the value of sortorder1 -> need to recode 1 to 0 to avoid showing # of episodes in dashboard*/
		if headerorder = 1 then headerorder=0;

		variableFilterLabel=label;
		if grouper="Laboratory Characteristics" and vartype="continuous" then variableFilterLabel=strip(covarlabel) || " (continuous)";
		else if grouper="Laboratory Characteristics" then variableFilterLabel=strip(covarlabel) || ": " || strip(label);
		%if %sysfunc(exist(riskscorefile)) %then %do;
		else if prxmatch("/&riskscorelist/i",metvar) and vartype="continuous" then do;
			variableFilterLabel=strip(label) || " (continuous)";
			pscovariate=riskscore_pscovariate;
		end;
		else if prxmatch("/&riskscorelist/i",metvar) then do;
			variableFilterLabel=strip(riskscorelabel) || ": " || strip(label);
			pscovariate=riskscore_pscovariate;
		end;
		/* Remove SAS specific coding for CHA2DS2VASC (currently coded as: CHA^{sub 2}DS^{sub 2}-VASc) */
		if metvar = "CHA2DS2VASC" then variableFilterLabel="CHA2DS2-VASc score";
		%end;
		
		variableLabel=variableFilterLabel;
		if vartype="dichotomous" and grouper="Demographic Characteristics" then variableLabel = strip(headerlabel) || ": " || strip(variableFilterLabel);

		/* Now that we have extracted covariate numbers for labs we need to assess pscovariate for them */
		%if &labcharacteristics. eq Y %then %do;
			%do m = 1 %to %sysfunc(countw(&psmodelvars,%str(|)));
			    %let psmodelcomb = %scan(&psmodelvars,&m,%str(|));
			    %let psestgrp = %scan(&psmodelcomb,1,%str(#));
			    %let psmodelvarsin = %scan(&psmodelcomb,-1,%str(#));
				if psestimategrp = "&psestgrp" then do;
				    %do z = 1 %to %sysfunc(countw(&psmodelvarsin));
				        %let psmodelvar = %scan(&psmodelvarsin,&z);		            
			            %if %sysfunc(prxmatch(/COVAR*/,&psmodelvar)) %then %do; 
			                if strip(metvar2) = "&psmodelvar" then pscovariate = 'Y';
			            %end;				
				    %end;
				end;/* psestimategrp */
			%end; /* m */
		%end;

		/* Specify correct values for covariates */
		%if &nobs > 0 %then %do;
			if not missing(covarnum) then do;
				subgrouplabel=studyname;
				if subgroupcat="1" then do;
					subgroupcatlabel="Yes";
					subGroupCatOrder=2;
				end;
				else do;
					subgroupcatlabel="No";
					subGroupCatOrder=1;
				end;
				subGroupOrder=1000+covarnum;
			end;
		%end;

		/* Change unicode value to symbol */
        if indexw(label,"(*ESC*){unicode '2265'x}") then label=tranwrd(label,"(*ESC*){unicode '2265'x}",">=");
        if indexw(subgroupcatlabel,"(*ESC*){unicode '2265'x}") then subgroupcatlabel=tranwrd(subgroupcatlabel,"(*ESC*){unicode '2265'x}",">=");
	    run;

	%end; /* Table1 requested*/

	%if &effectestflag. eq 1 %then %do;
	    data views.effectest;
	    set _effectest_:;
		/* No subgroups */
		%if &check_subgroups=0 %then %do;
		format subgroup $50.;
		subgroup="overall";
		%end;	
	    run;

		/* Get missing subgroups information */
		%if &check_subgroups>0 %then %do;
			proc sql noprint undo_policy=none;
			create table views.effectest as
			select a.*
				   ,b.subgroup	
			from views.effectest as a
			left join _subgroup_info as b
			on a.analysisgrp=b.analysisgrp and a.tabletitle=b.tabletitle and a.subgroupcat=b.subgroupcat;
			quit;
		%end;

	    data views.effectest(rename=(tabletitle=subgrouplabel monitoringperiod2=monitoringperiod) 
							 keep=monitoringperiod2 analysisgrp analysis medicalproduct DP subgroup subgroupcat tabletitle subgroupcatlabel
			  					 SubgroupDashboardLabel subGroupOrder subGroupCatOrder n EV IRDiff_1000PY RD_1000NU risk_1000NU FUTime_Y
			  					 AvgFUTime_D AvgFUTime_Y IR_1000PY NNT AR poprisk PAR totalevents EVchar IR_1000PYchar IRDiff_1000PYchar
			  					 RD_1000NUchar risk_1000NUchar rrchar FUTime_Ychar AvgFUTime_Dchar AvgFUTime_Ychar sort1 sort2 HR_95CI
			   					 HR_pvalue HR LCL UCL HR_coef HR_se);
		retain monitoringperiod2 analysisgrp analysis medicalproduct DP subgroup subgroupcat tabletitle subgroupcatlabel
			   SubgroupDashboardLabel subGroupOrder subGroupCatOrder n EV IRDiff_1000PY RD_1000NU risk_1000NU FUTime_Y
			   AvgFUTime_D AvgFUTime_Y IR_1000PY NNT AR poprisk PAR totalevents EVchar IR_1000PYchar IRDiff_1000PYchar
			   RD_1000NUchar risk_1000NUchar rrchar FUTime_Ychar AvgFUTime_Dchar AvgFUTime_Ychar sort1 sort2 HR_95CI
			   HR_pvalue HR LCL UCL HR_coef HR_se;
		length monitoringperiod2 3 dp $10 subgroup subgroupcat $50 tabletitle subgroupcatlabel $500
			   IR_1000PYchar IRDiff_1000PYchar RD_1000NUchar risk_1000NUchar rrchar FUTime_Ychar AvgFUTime_Dchar AvgFUTime_Ychar HR_95CI HR_pvalue $40;
		format monitoringperiod2 3. dp $10. subgroup subgroupcat $50. SubgroupDashboardLabel $1000.
			   IR_1000PYchar IRDiff_1000PYchar RD_1000NUchar risk_1000NUchar rrchar FUTime_Ychar AvgFUTime_Dchar AvgFUTime_Ychar HR_95CI HR_pvalue $40. HR_coef best8.;
	    set views.effectest;
		monitoringperiod2=monitoringperiod;
		if tabletitle="Data Partner" then do;
			dp=subgroupcat;
			subgroup="overall";
			subgroupcat="overall";
			tabletitle="Overall Analysis";
			SubgroupCatLabel="Overall Analysis";
			subGroupOrder=1;
			subGroupCatOrder=1;
		end;
		else dp="Aggregate";
		if missing(subgroup) or subgroup="overall" then do;
			subgroup="overall";
			SubgroupDashboardLabel="Overall Analysis";
		end;
		else SubgroupDashboardLabel = strip(tabletitle) || ": " || strip(subgroupcatlabel);
		if missing(subgroupcat) then subgroupcat="overall";
		if missing(tabletitle) then tabletitle="Overall Analysis";
		if missing(subgroupcatlabel) then subgroupcatlabel="Overall Analysis";
		
		/* Specify correct values for covariates */
		if not missing(covarnum_label) then do;
			tabletitle=covarnum_label;
			if subgroupcat="1" then do;
				subgroupcatlabel="Yes";
				subGroupCatOrder=2;
			end;
			else do;
				subgroupcatlabel="No";
				subGroupCatOrder=1;
			end;
			SubgroupDashboardLabel = strip(tabletitle) || ": " || strip(subgroupcatlabel);
			subGroupOrder=1000+covarnum;
		end;
	    run;

		data views.analysisgroup;
		retain analysisgrp analysisgrptitle exposure exposurelabel reference referencelabel outcome design adjustmentmethod modelparameters weightingmethod sortingorder;
        set analysistable;
        drop runid;
    run;
	%end; /* Effect estimates requested */

    /* Delete rows not relevant for Sentinel Views */
    data views.attrition(rename=monitoringperiod2=monitoringperiod);
        set _attrition:(where=(not missing(level) and descr not in('Number of events in comparative analysis',
                                                                   'Number of episodes',
                                                                   'Number of members' ,
                                                                   'Excluded due to same-day initiation of both exposure groups',
                                                                   'Number of patients with a truncated inverse probability of treatment weight')));
	format level best8. monitoringperiod2 3.;
	length monitoringperiod2 3;
	monitoringperiod2=monitoringperiod;
	drop monitoringperiod;
    run;    

    /* Re-assign values for dates in monitoring file */
	proc sql noprint;
        select max(input(dpmaxdate,date9.)) into: maxdpenddate
        from output.dpinfo;
    quit;

    data views.monitoringperiod(keep=monitoringperiod startdate enddate);
		retain periodid2 startdate enddate;
        set monitoringfile_views;
		enddate=coalesce(fupenddate,indenddate, &maxdpenddate.);        
        rename periodid2=monitoringperiod;
        format enddate date9. periodid2 3.;
		length periodid2 3 startdate enddate 4;
    run;

    %if &psdistflag = 1 %then %do;    	
		data views.psdist;
	    set _psdist_:;
		/* No subgroups */
		%if &check_subgroups=0 %then %do;
		format subgroup subgroupcat $50. subgrouplabel subgroupcatlabel $500.  subGroupOrder subGroupCatOrder best.;
		length subGroupOrder subGroupCatOrder 3;
		&suboverall.;
		%end;	
		if dp="agg" or (dp ne "agg" and missing(subgroup));
	    run;

		/* Get subgroups information */
		%if &check_subgroups>0 %then %do;
			%getsubgroupsinfo(dataset=views.psdist);			
		%end;

		/* Get covariates information */
		%if &check_covars > 0 %then %do;
			proc sql noprint undo_policy=none;
			create table views.psdist as
			select a.*			   
				   ,c.covarnum
				   ,c.studyname
			from views.psdist as a		
			left join covarnameviews as c on a.subgroup=c.cov_varname;
			quit;
		%end;

	    data views.psdist(rename=(_eoi=EoiEpiCount _ref=RefEpiCount ps_cat3=ps_cat) keep=monitoringperiod analysisgrp Type weight Dp subgroup subgroupcat subgrouplabel subgroupcatlabel subGroupOrder subGroupCatOrder  _eoi _ref ps_cat3 bin_eoi bin_ref);
		retain monitoringperiod analysisgrp Type weight Dp subgroup subgroupcat subgrouplabel subgroupcatlabel subGroupOrder subGroupCatOrder  _eoi _ref ps_cat3 bin_eoi bin_ref;
		length ps_cat3 3 dp $10 Type weight $30 subgroup subgroupcat $50 _eoi _ref bin_eoi bin_ref 8;
		format dp $10. Type weight $30. subgroup subgroupcat $50. _eoi _ref bin_eoi bin_ref best8.;
	    set views.psdist;
		ps_cat3=ps_cat;
		if dp="agg" then dp="Aggregate";
		if missing(subgroup) then subgroup="overall";
		if missing(subgroupcat) then subgroupcat="overall";
		if missing(subgrouplabel) then subgrouplabel="Overall Analysis";
		if missing(subgroupcatlabel) then subgroupcatlabel="Overall Analysis";

		/* Specify correct values for covariates */
		%if &check_covars > 0 %then %do;
		if not missing(covarnum) then do;
			subgrouplabel=studyname;
			if subgroupcat="1" then do;
				subgroupcatlabel="Yes";
				subGroupCatOrder=2;
			end;
			else do;
				subgroupcatlabel="No";
				subGroupCatOrder=1;
			end;
			subGroupOrder=1000+covarnum;
		end;
		%end;
	    run;
    %end; /* PS distribution data requested */   

    proc datasets library=work nolist nowarn;
        delete analysistable _psdist: monitoringfile_views _attrition: _km: _temptable1: table1: _table1:
        _metanames _effectest: pscs_masterinputs_views psest_masterinputs_views; 
    quit;		

%mend l2_sentinel_views_convertdata;
