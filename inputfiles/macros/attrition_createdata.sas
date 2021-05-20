****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: attrition_createdata.sas  
* Created (mm/dd/yyyy): 05/13/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro transforms and manipulates attrition table data to be output
*                                        
*  Program inputs:                                                                                   
*   - agg_attrition
* 
*  Program outputs: 
*	- agg_patient_attrition
*   - agg_episode_attrition
* 
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

%macro attrition_createdata;

/* Link all required groups from inputfiles */

	%isdata(dataset=master_t2addon)
	%let t2addonnobs = &nobs;
	%isdata(dataset=master_mil);
	%let milnobs=&nobs;

	proc sql noprint;
	create table attrition_groups as 
	select distinct a.runid, a.group 
	%if &t2addonnobs > 0 %then %do; , b.primary, b.secondary %end; 
	%if &milnobs > 0 %then %do; ,b.groupname %end;
	from inputfiles a
	%if &t2addonnobs > 0 %then %do;
	left join master_t2addon b
	on a.group = b.group and a.runid = b.runid
	%end;
	%if &milnobs > 0 %then %do;
	left join master_mil b 
	on a.group = b.group and a.runid = b.runid
	%end;
	;
	quit;

	%isdata(dataset=master_inclusioncodes);
	%let inclnobs = &nobs;
	/* Join only required groups to attrition table */
    proc sql noprint;
   		create table all_attrition_groups as 
   		select distinct A.runid, A.dpidsiteid, A.group, 
   						A.level, A.claim_level, A.descr, 
						A.remaining, A.excluded, d.t%substr(&reporttype,2,1)cohortdef
						%if %index(&reporttype,T4) %then %do; ,d.t%substr(&reporttype,2,1)cohortdef2 %end;
   		%if &inclnobs > 0 %then %do; ,c.condlevel %end;
   		from agg_attrition a
   		inner join 
   		attrition_groups b
   		on a.group = b.group and a.runid = b.runid
   		left join 
   		master_typefile d
   		on a.group = d.group and a.runid = d.runid
   		%if &t2addonnobs > 0 %then %do;
   		or (a.group = b.primary) or (a.group = b.secondary) and a.runid = b.runid
   		%end;
   		%if &milnobs > 0 %then %do;
   		or a.group = b.groupname and a.runid = b.runid
   		%end;
   		/* Join condlevel when inclusioncodes file exists */
   		%if &inclnobs > 0 %then %do;
   		left join 
   		master_inclusioncodes c
   		on b.group = c.group and b.runid = c.runid
   		%end;
   		;
   	quit;

   	/* Extract only necessary label pieces for condlevel merge */
   	data all_attrition_groups;
   		set all_attrition_groups;
	   	if find(level,'.') then do;
	   		if find(descr,'lacking') then descr=substr(descr,1,findw(descr,'lacking')+6);
	   		else descr=substr(descr,1,findw(descr,'for')+2);
	   	end;
   	run;

    proc sql noprint undo_policy=none;
        /* Join lookup table to groups table requested by user */
        create table all_attrition_agg as
   		select a.runid, a.dpidsiteid, a.group, a.level, a.claim_level, a.t%substr(&reporttype,2,1)cohortdef, 
   			   a.descr, a.remaining, a.excluded, b.report_descr %if &inclnobs > 0 %then %do; ,a.condlevel %end;
        from all_attrition_groups a
        left join 
             lookup.lookup_attrition b 
        on a.claim_level = b.claim_level and a.descr = b.descr;

        /* Sum across all DPs */
		create table all_attrition_agg as 
		select distinct runid, group, report_descr, level, claim_level, remaining, excluded, t%substr(&reporttype,2,1)cohortdef,
             sum(remaining) as agg_remaining, sum(excluded) as agg_excluded
             %if &inclnobs > 0 %then %do; ,condlevel %end;
             from all_attrition_agg
        group by runid, group, report_descr, level;

        /* Sum again, but only to collapse rows 2, 3 and 4 together and 15 and 16 together for excluded */
        create table all_attrition_agg as 
        select runid, group, report_descr, claim_level, t%substr(&reporttype,2,1)cohortdef, max(input(level,best.)) as level,
        	   agg_remaining format=comma12., sum(agg_excluded) as agg_excluded format=comma12.
        	   %if &inclnobs > 0 %then %do; ,condlevel %end;
        from all_attrition_agg
        group by runid, group, report_descr, claim_level, t%substr(&reporttype,2,1)cohortdef, agg_remaining %if &inclnobs > 0 %then %do; ,condlevel %end;;
    quit;


    /* Set in condlevel value and delete un-needed rows */
	data all_attrition_agg(keep=runid group level claim_level agg_remaining agg_excluded report_descr t%substr(&reporttype,2,1)cohortdef);
		set all_attrition_agg;
		%if &inclnobs >0 %then %do;
		if not missing(condlevel) then do;
			if index(report_descr,'[CONDLEVEL N]') then report_descr=condlevel;
		end;
		%end;
		if missing(report_descr) then delete;
	run;

    /* Merge in group labels and headers if they exist */
    %isdata(dataset=labelfile);
	  %if %eval(&nobs>0) %then %do;
	  proc sql noprint undo_policy=none;
	        create table all_attrition_agg as
	        select a.*, case when not missing(b.label) then b.label else b.group end as grouplabel, c.label as headerlabel
	        from all_attrition_agg a 
	        left join labelfile(where=(lowcase(labeltype) = 'grouplabel')) b
	        on a.group = b.group
	        left join labelfile(where=(lowcase(labeltype) = 'header' and not missing(label))) c
	        on a.group = c.group;
	  quit;
	  %end;
	  %else %do;
	  data all_attrition_agg;
	  	set all_attrition_agg;
	  	grouplabel=group;
	  	headerlabel='';
	  %end;

	/* Create character variables of remaining and excluded columns */
	  data all_attrition_agg;
	  	set all_attrition_agg;
	  	agg_remaining_char=strip(put(agg_remaining,comma12.));
	  	agg_excluded_char=strip(put(agg_excluded,comma12.));
	  	if missing(agg_remaining) then agg_remaining_char = 'N/A';
	  	if missing(agg_excluded) then agg_excluded_char = 'N/A';
	  	if report_descr = 'Number of members' then do;
	  		agg_remaining_char = strip(put(agg_remaining,comma12.));
	  		agg_excluded_char = 'N/A';
	  	end;
	  	/* Overwrite cell values for T4 analyses */
	  	%if %index(&reporttype,T4) %then %do;
	  	if report_descr = 'Total number of claims with cohort-identifying codes during the query period' then 
	  	   report_descr = 'Total number of live birth deliveries during the query period';
	  	%end;
	  run;

	  proc sort data = all_attrition_agg; 
	  by group claim_level;
	  run;

	  /* Output final episode rows and place final episode count */
	  data all_attrition_agg;
	  	set all_attrition_agg;
	  	length episodecount 8. episodecountchar $20;
	  	retain episodecount episodecountchar;
	  	by group claim_level;
	  	if first.group then do;
	  		episodecount=.;
	  		episodecountchar = 'N/A';
	  	end;
	  	if last.claim_level and claim_level = 'Episode' then do;
	  		episodecount=agg_remaining;
	  		episodecountchar=agg_remaining_char;
	  	end;
	  	output;
	  	if last.group then do;
	  		%if %index(&reporttype,T4) %then %do;
	  		report_descr = "Number of Pregnancy episodes";
	  		%end;
	  		%else %do;
	  		report_descr = "Number of episodes";
	  		%end;
	  		%if %index(&reporttype,T4) %then %do;
	  		level=26.5;
	  		%end;
	  		%else %do;
	  		level=99;
	  		%end;
	  		claim_level='Episode';
	  		agg_remaining = episodecount;
	  		agg_remaining_char = episodecountchar;
	  		agg_excluded = .;
	  		agg_excluded_char = 'N/A';
	  		output;
	  	end;
	  	drop episodecount episodecountchar;
	  run;

	  /* Output patient/episode level tables */
	  %if ^%index(&reporttype,T4L1) %then %do;
	  proc sort data = all_attrition_agg out=agg_patient_attrition(where=(t%substr(&reporttype,2,1)cohortdef in ('01','04'))) sortseq=linguistic(numeric_collation=on);
	  	by group level;
	  run;
	  %end;

	  proc sort data = all_attrition_agg out=agg_episode_attrition(where=(t%substr(&reporttype,2,1)cohortdef in ('02','03'))) sortseq=linguistic(numeric_collation=on);
	  	by group level;
	  run;


%mend attrition_createdata;