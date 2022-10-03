****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l1_sentinel_views_convertdata.sas
* Created (mm/dd/yyyy): 08/12/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Transform QRP_REPORT L1 MSOCDATA folder data
*
*
*  Program inputs: agg_t1_baseline, agg_t1_cida
*
*  Program outputs:  agg_t1_baseline, agg_t1_cida
*
*  PARAMETERS:
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


%macro l1_sentinel_views_convertdata;

	proc datasets library=views kill; run; quit;

	proc copy in=msocdata out=views memtype=data; run;

	%let msocdatadsn=;
	proc sql noprint;
		/* Read in all datasets */
        select catx('.','msocdata',memname) 
        into :msocdatadsn separated by '@'
        from dictionary.tables 
        where libname = 'MSOCDATA';
    quit;

    %do z = 1 %to %sysfunc(countw(&msocdatadsn,@));

    	%let msocdata = %scan(&msocdatadsn,&z,@);
		%let out_table= views.%scan(&msocdata,2,.);
	
        /* Start checking to ensure certain variables exist in the data - If not, set them up to missing */

    	%if %index(&out_table,CIDA) and ^%index(&out_table,CENSOR) and ^%index(&out_table,FOLLOWUPTIME) %then %do;
			
        data &out_table ;
            set &out_table;
			%if %varexist(&out_table,agegroup)		=0 %then %do; agegroup		=''; %end;
			%if %varexist(&out_table,agegroupnum)	=0 %then %do; agegroupnum	=. ; %end;
			%if %varexist(&out_table,sex)			=0 %then %do; sex			=''; %end;
			%if %varexist(&out_table,year)			=0 %then %do; year			=. ; %end;
			%if %varexist(&out_table,month)			=0 %then %do; month			=. ; %end;
			%if %varexist(&out_table,quarter)		=0 %then %do; quarter		=. ; %end;
			%if %varexist(&out_table,zip3)			=0 %then %do; zip3			=''; %end;
			%if %varexist(&out_table,state)			=0 %then %do; state			=''; %end;
			%if %varexist(&out_table,hhs_reg)		=0 %then %do; hhs_reg		=''; %end;
			%if %varexist(&out_table,cb_reg)			=0 %then %do; cb_reg		=''; %end;
			%if %varexist(&out_table,zip_uncertain)	=0 %then %do; zip_uncertain	=''; %end;
			%if %varexist(&out_table,race)			=0 %then %do; race			=''; %end;
			%if %varexist(&out_table,hispanic)		=0 %then %do; hispanic		=''; %end;      
        run;
		

    	%let covarlistcomma = ;
    	%let covarlist = ;
    	proc sql noprint;

            /* Check to see if covars are in dataset */
            select distinct 'a.'||name, name 
            into :covarlistcomma separated by ',', :covarlistspace separated by ' '
            from dictionary.columns 
            where libname = 'VIEWS' and lower(memname) contains 'cida' 
            						   and lower(memname) not contains 'censor' 
                                       and lower(memname) not contains 'followuptime'
            						   and lower(name) like 'covar%';
       		select lower(tableid) 
       		into :tabletype 
       		from userstrata
       		where lower(tableid) contains 'cida';

            select distinct levelvars 
            into :covarlist separated by '@'
            from userstrata 
            where lower(tableid) contains 'cida' and lower(levelvars) like '%covar%';

    		/* Obtain stratifications */
   			create table cida_levelvars as 
   			select A.runid, A.dpidsiteid, A.group, A.Level, A.sex, A.agegroup, A.year, A.month, A.quarter, A.zip3, 
				   A.state, A.hhs_reg, A.cb_reg, A.zip_uncertain, A.race, 
                   A.hispanic, A.Npts, A.Episodes, A.AdjustedCodeCount, A.RawCodeCount, 
                   A.DaySupp, A.AmtSupp, 
                   A.timetocensor, A.DenNumPts, A.DenNumMemDays, divide(A.DenNumMemDays,365.25) as DenNumMemYears
                   %if %upcase(&reporttype) = T2L1 %then %do;
                   ,A.eps_wevents,A.all_events,A.followuptime 
                   %end;
                   %if %length(&covarlistcomma) > 0 %then %do; ,&covarlistcomma %end; ,b.levelvars 
    		from &out_table A 
    		left join userstrata(where=(tableid="&tabletype")) B
    		on a.level = b.levelid;

    		/* Aggregate only the overall row, stack table together */
    		create table agg_cida as 
    		select a.runid, 'AGGR' as dpidsiteid, a.group, a.levelvars, a.sex, a.agegroup, a.year, a.month, a.quarter,
                   a.zip3, a.state, a.hhs_reg, a.cb_reg, a.zip_uncertain, a.race, a.hispanic, sum(a.Npts) as Npts, sum(a.Episodes) as Episodes 
                   %if %length(&covarlistcomma) > 0 %then %do; ,&covarlistcomma %end;
				   ,sum(a.AdjustedCodeCount) as AdjustedCodeCount, sum(a.RawCodeCount) as RawCodeCount, 
                   sum(a.DaySupp) as DaySupp, sum(a.AmtSupp) as AmtSupp, 
                   sum(a.timetocensor) as timetocensor, sum(a.DenNumPts) as DenNumPts, sum(a.DenNumMemDays) as DenNumMemDays, sum(DenNumMemYears) as DenNumMemYears
                   %if %upcase(&reporttype) = T2L1 %then %do;
                    ,sum(A.eps_wevents) as eps_wevents, sum(A.all_events) as all_events, sum(A.followuptime) as followuptime 
                   %end; 
            	   from cida_levelvars a
            	   group by a.runid, a.group, a.levelvars, a.sex, A.agegroup, a.year, a.month, a.quarter, 
                            a.zip3, a.state, a.hhs_reg, a.cb_reg, a.zip_uncertain, A.race, A.hispanic
                            %if %length(&covarlistcomma) > 0 %then %do; ,&covarlistcomma %end;
            outer union corr 
            select b.* 
            from cida_levelvars b;
    	quit;
 
       %if %upcase(&reporttype) = T1 %then %do;
        data views.agg_t1_cida
       %end;
       %else %if %upcase(&reporttype) = T2L1 %then %do;
        data views.agg_t2_cida
       %end;
       ;
       	set agg_cida;
        length requestid $40;

        covar_label='';
        covarn='';
        %let covarlabel = ;
        %let covarn = ;

       	%if %length(&covarlist) > 0 %then %do;
            %let covarlabel = ;
            %let covarn = ;
           %do i = 1 %to %sysfunc(countw(&covarlist,%str(@)));
              %let covars = %scan(&covarlist,&i,%str(@));
              %do j = 1 %to %sysfunc(countw(&covars,%str( )));
                %let covar = %scan(&covars,&j,%str( ));
                %if %index(&covar,covar) %then %do;
                length covarn_&i._&j covarn $200 covar_label_&i._&j covar_label $200;
                    if &covar = 0 and levelvars = "&covars" then covar_label_&i._&j = catx('|',vlabel(&covar),'N');
                    else if &covar = 1 and levelvars = "&covars" then covar_label_&i._&j = catx('|',vlabel(&covar),'Y');
                    if not missing(&covar) and levelvars = "&covars" then covarn_&i._&j ="%upcase(&covar.)";
                %let covarlabel = &covarlabel covar_label_&i._&j;
                %let covarn = &covarn covarn_&i._&j;
                %end;
              %end;
            %end;
            %let covarlabel = %sysfunc(tranwrd(%sysfunc(compbl(&covarlabel)),%str( ),%str(,)));
            %let covarn = %sysfunc(tranwrd(%sysfunc(compbl(&covarn)),%str( ),%str(,)));
            covar_label = catx(',',&covarlabel);
            covarn = catx(',',&covarn);
        %end;
        requestid="&viewsID";
        if indexw(agegroup,"(*ESC*){unicode '2265'x}") then agegroup=tranwrd(agegroup,"(*ESC*){unicode '2265'x}",">=");
        rename levelvars=stratification_vars dpidsiteid=dpid;
        drop level %if %length(&covarlist) > 0 %then %do; &covarlistspace covar_label_: covarn_:%end;
        ;
    	run;

        %put &=covarlabel;
        %put &=covarn;

    	%end; /* Cida table */
		
    	%else %if %index(&out_table,BASELINE) %then %do;
				
    	%let baselinevarlist = ;

    	proc sql noprint;
            /* Get all baseline dataset variables */
            select distinct name, 'sum(a.'||name||') as '||name
            into :baselinevarlist separated by ' ', :baselinecommalist separated by ',' 
            from dictionary.columns
            where libname = 'VIEWS' and lower(memname) contains 'baseline' and prxmatch('/covar|age\d|sex|year|race|hispanic/i',name)
			and ^ prxmatch("m/n_covar|mean_covar|std_covar|lbres|lbunit/oi", name) ;
			;			
			
            %let contvars = std_Age std_COMORBIDSCORE std_NumAV std_NUMOA std_NUMIP std_NUMIS std_NUMED std_NumGeneric std_NumClass std_NumRx;
            %do i = 1 %to %sysfunc(countw(&contvars));
                %let stdvar = %scan(&contvars,&i);
            select count(distinct dpidsiteid)
            into :&stdvar.dpnum
            from &out_table
            where not missing(&stdvar);
            %end;

            create table agg_baseline as 
            select  A.runid, A.group, 'AGGR' as dpidsiteid, sum(A.patient) as patient, &baselinecommalist, sum(A.N_episodes) as n_episodes, 
            		divide(sum(A.mean_Age*A.N_Episodes),sum(A.N_episodes)) as mean_Age, 
                    divide(sum(A.mean_COMORBIDSCORE*N_Episodes),sum(N_episodes)) as mean_COMORBIDSCORE, 
                    divide(sum(A.mean_NumAV*A.N_Episodes),sum(A.N_episodes)) as mean_NumAV, 
                    divide(sum(A.mean_NumOA*A.N_Episodes),sum(A.N_episodes)) as mean_NumOA,
					divide(sum(A.mean_NumIP*A.N_Episodes),sum(A.N_episodes)) as mean_NumIP, 
                    divide(sum(A.mean_NumIS*A.N_Episodes),sum(A.N_episodes)) as mean_NumIS, 
                    divide(sum(A.mean_NumED*A.N_Episodes),sum(A.N_episodes)) as mean_NumED, 
                    divide(sum(A.mean_NumGeneric*A.N_Episodes),sum(A.N_episodes)) as mean_NumGeneric, 
                    divide(sum(A.mean_NumClass*A.N_Episodes),sum(A.N_episodes)) as mean_NumClass, 
					divide(sum(A.mean_NumRx*A.N_Episodes),sum(A.N_episodes)) as mean_NumRx, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_Age**2),sum(A.N_episodes-&std_Agedpnum))) as std_Age, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_COMORBIDSCORE**2),sum(A.N_episodes-&std_COMORBIDSCOREdpnum))) as std_COMORBIDSCORE, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumAV**2),sum(A.N_episodes-&std_NUMAVdpnum))) as std_NumAV, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumOA**2),sum(A.N_episodes-&std_NUMOAdpnum))) as std_NumOA, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumIP**2),sum(A.N_episodes-&std_NUMIPdpnum))) as std_NumIP, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumIS**2),sum(A.N_episodes-&std_NUMISdpnum))) as std_NumIS, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumED**2),sum(A.N_episodes-&std_NUMEDdpnum))) as std_NumED, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumGeneric**2),sum(A.N_episodes-&std_NumGenericdpnum))) as std_NumGeneric, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumClass**2),sum(A.N_episodes-&std_NumClassdpnum))) as std_NumClass, 
                    sqrt(divide(sum((A.N_Episodes-1)*A.std_NumRx**2),sum(A.N_episodes-&std_NumRxdpnum))) as std_NumRx
            	   from &out_table a
            	   group by a.runid, a.group
            union corr all
            select b.* 
            from &out_table b;
        quit;
		
		
        /* Create temporary subsets to manipulate the data */
        data _sub1_agg_base(drop=patient n_episodes mean_: std_:) 
             _sub2_agg_base(keep=runid group dpid patient n_episodes)
             _sub3_agg_base(keep=runid group dpid mean_: std_:);
            set agg_baseline(rename=(dpidsiteid=dpid)); 
        run;

        proc sort data=_sub1_agg_base;
            by group runid dpid;
        run;

        /* Transpose all stratifications into one column */
        proc transpose data = _sub1_agg_base out=_sub1_agg_base; 
            by group runid dpid;
        run; 

        proc sort data = _sub2_agg_base;
            by group runid dpid;
        run;

		/* De-dupe continuous statistics */
        proc sort data = _sub3_agg_base nodupkey out=_sub3_agg_base;
            by group runid dpid;
        run;

        proc sql noprint;
            select distinct upper(medproduse), upper(healthchar), upper(UtilizationIntensity)
            into :medproduse separated by ' ', :healthchar separated ' ', :UtilizationIntensity separated by ' '
            from input.&baselinefile;
        quit;
		
        %baseline_expand_parameters(var =medproduse);
        %baseline_expand_parameters(var =healthchar);
        %baseline_expand_parameters(var =UtilizationIntensity);

        data _sub1_2_agg_base;
            length _name_ $200 variable_subgroup $60;
            merge _sub1_agg_base _sub2_agg_base;
            by group runid dpid;
            variable_subgroup = 'Custom Variables';
            if upcase(_name_) in (&medproduse) then variable_subgroup = "Medical Product Use";
            if upcase(_name_) in (&healthchar) then variable_subgroup = "Health Characteristics";
            if scan(upcase(_name_),-1,'_') in (&UtilizationIntensity) then variable_subgroup = "Health Service Utilization Intensity Metrics";
            if index(upcase(_name_),'AGE') then do;
                covarnum=1001;
                variable_subgroup='Age';
            end;
            if index(upcase(_name_),'YEAR') then do; 
                covarnum=1002;
                variable_subgroup='Year';
            end;
            if index(upcase(_name_),'SEX') or index(upcase(_name_),'RACE') or index(upcase(_name_),'HISPANIC') then do;
                if index(upcase(_name_),'SEX') then do;
                    covarnum=1000;
                    variable_subgroup='Sex';
                end;
                if index(upcase(_name_),'RACE') then do;
                    covarnum=1012;
                    variable_subgroup='Race';
                end;
                if index(upcase(_name_),'HISPANIC') then do;
                    covarnum=1013;
                    variable_subgroup='Hispanic';
                end;
                patient2=col1;
                patients_pct=round(divide(patient2,patient)*100,0.1);
                episode2=.;
                episodes_pct=.;
            end;
            else do;
                episode2=col1;
                episodes_pct=round(divide(episode2,n_episodes)*100,0.1);
                patient2=.;
                patients_pct=.;
                if index(upcase(_name_),'COVAR') then do;
                    covarnum=input(compress(_name_,'','A'),8.);
                    _name_=_label_;
                end;
            end;
            label _name_=' ';
            drop patient n_episodes _label_ col1;
            rename patient2=patients episode2=episodes _name_=variable;
        run;

        %if %upcase(&reporttype) = T1 %then %do;
        data views.agg_t1_baseline;
        %end;
        %else %if %upcase(&reporttype) = T2L1 %then %do;
        data views.agg_t2_baseline;
        %end;
            set _sub1_2_agg_base _sub3_agg_base;
        length requestid $40;
        requestid="&viewsID";
        if not missing(mean_age) then do;
            if missing(variable) then variable = "Custom Variables";
            variable_subgroup = "Health Service Utilization Intensity Metrics";
        end;
        run;
		
        %end; /* baseline table */

        %else %if %index(&out_table,FOLLOWUPTIME) %then %do;

        %let dsid=%sysfunc(open(&out_table));
        %let check_age=%sysfunc(varnum(&dsid,agegroup));
        %let check_sex=%sysfunc(varnum(&dsid,sex));
        %let check_year=%sysfunc(varnum(&dsid,year));
        %let check_month=%sysfunc(varnum(&dsid,month));
        %let check_quarter=%sysfunc(varnum(&dsid,quarter));
        %let check_eventflag=%sysfunc(varnum(&dsid,event_flag));
        %let rc=%sysfunc(close(&dsid));

        /* if columns are missing, initialize them */
        data &out_table;
            set &out_table;
            %if &check_age=0 %then %do;
            agegroup='';
            agegroupnum=.;
            %end;
            %if &check_sex=0 %then %do;
            sex='';
            %end;
            %if &check_year=0 %then %do;
            year=.;
            %end;
            %if &check_month=0 %then %do;
            month=.;
            %end;
            %if &check_quarter=0 %then %do;
            quarter=.;
            %end;
            %if &check_eventflag=0 %then %do;
            event_flag='';
            %end;
        run;

        proc sql noprint;
            select lower(tableid) 
            into :tabletype 
            from userstrata
            where lower(tableid) contains 'followuptime';

            /* Obtain stratifications */
            create table followuptime_levelvars as 
            select A.runid, A.dpidsiteid, A.group, A.Level, A.censdays_value, A.censdays_value_cat, A.sex, A.agegroup, A.event_flag, 
                   A.year, A.month, A.quarter, A.Episodes, A.cens_elig, A.cens_dth, A.cens_dpend, A.cens_qryend, A.cens_episend, 
                   A.cens_spec, A.cens_event, b.levelvars
            from &out_table A 
            left join userstrata(where=(tableid="&tabletype")) B
            on a.level = b.levelid
            order by A.runid, A.dpidsiteid, A.group, A.Level, A.censdays_value, A.censdays_value_cat, A.sex, A.agegroup, A.event_flag, 
                   A.year, A.month, A.quarter;

            /* Aggregate only the overall row, stack table together */
            create table agg_followuptime as 
            select a.runid, 'AGGR' as dpidsiteid, a.group, a.levelvars, A.censdays_value, A.censdays_value_cat, A.sex, A.agegroup, A.event_flag, 
                   A.year, A.month, A.quarter, sum(A.Episodes) as Episodes, sum(A.cens_elig) as cens_elig, sum(A.cens_dth) as cens_dth, 
                   sum(A.cens_dpend) as cens_dpend, sum(A.cens_qryend) as cens_qryend, sum(A.cens_episend) as cens_episend, 
                   sum(A.cens_spec) as cens_spec, sum(A.cens_event) as cens_event
                   from followuptime_levelvars a
                   group by a.runid, a.group, a.levelvars, A.censdays_value, A.censdays_value_cat, a.sex, A.agegroup, A.event_flag, 
                            a.year, a.month, a.quarter
            outer union corr 
            select b.* 
            from followuptime_levelvars b;
        quit;

        data views.agg_t2_followuptime;
            set agg_followuptime;
            length requestid $40;
            requestid="&viewsID";
            rename levelvars=stratification_vars dpidsiteid=dpid;
            drop level;
        run; 

        %end; /* End follow-up time datast */
		
		proc datasets nolist nowarn lib=work; 
			delete _sub: cida_levelvars agg_cida agg_baseline followuptime_levelvars agg_followuptime;
		quit;
		
						
    %end; /* Loop all tables */

	proc sql noprint;
		select memname into :dropfromviews separated by ' '
		from dictionary.tables 
		where libname = 'VIEWS'
		and ^prxmatch("m/agg_t1_baseline|agg_t1_cida/oi", memname);
	quit;
	
	proc datasets library=views nolist nowarn;
    	delete &dropfromviews;
	quit;	
		
%mend l1_sentinel_views_convertdata;
