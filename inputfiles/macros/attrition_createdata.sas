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
*	- agg_mil_attrition
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
	%isdata(dataset=master_inclusioncodes);
	%let inclnobs = &nobs;

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

	%if &milnobs > 0 %then %do;
	/* Create EOI/REF rows based off MIL group */
	data attrition_groups;
		set attrition_groups;
		if missing(groupname) then output;
		if not missing(groupname) then do;
		group=catx('_',group,'ref');
		output;
		group=tranwrd(group,'ref','eoi');
		output;
		end;
	run;

	/* Rejoin to attrition groups table to only keep relevant MIL groups */
	%let milgrps=;
	%let milcohorts=;
	proc sql noprint undo_policy=none;
		select quote(strip(group)) 
		into :milgrps 
		separated by " "
		from attrition_groups
		where group contains 'eoi' or group contains 'ref';

		select quote(strip(groupname))
		into :milcohorts 
		separated by " "
		from master_mil
		where not missing(groupname);
	quit;
	%end;
	
	/* Join only required groups to attrition table */
    proc sql noprint;
   		create table all_attrition_groups as 
   		select distinct A.runid, A.dpidsiteid, A.group, 
   						A.level, A.claim_level, A.descr, 
						A.remaining, A.excluded, d.t%substr(&reporttype,2,1)cohortdef
						%if &milnobs > 0 %then %do; ,b.group as milgrp %end;
						%if %index(&reporttype,T4) %then %do; ,d.t%substr(&reporttype,2,1)cohortdef2 %end;
   		from agg_attrition a
   		inner join 
   		attrition_groups b
   		on a.group = b.group and a.runid = b.runid
   		%if &milnobs > 0 %then %do;
   		or a.group = b.groupname and a.runid = b.runid
   		%end;
   		%if &t2addonnobs > 0 %then %do;
   		or (a.group = b.primary) or (a.group = b.secondary) and a.runid = b.runid
   		%end;
   		left join 
   		master_typefile d
   		on a.group = d.group and a.runid = d.runid
   		%if &milnobs > 0 %then %do;
   		or d.group = b.groupname and d.runid = b.runid
   		%end;
   		;

   		%if &inclnobs > 0 %then %do;
   		select count(distinct condlevel)
   		into :ncond trimmed
   		from master_inclusioncodes;

   		select distinct condlevel 
   		into :condlevel1-:condlevel&ncond 
   		from master_inclusioncodes;
   		%end;
   	quit;

   	data all_attrition_groups;
   		set all_attrition_groups(in=a) 
   		    agg_mil_attrition(in=b where=(analysisgrp in (&milgrps)));
   		if a then do;
   			if group in (&milcohorts) and group=milgrp then delete;
   			if group^=milgrp then group=milgrp;
   			flag=0;
   		end;
   		if b then do;
   			group=analysisgrp;
   			claim_level='Episode';
   			level=level+1000;
   			t4cohortdef='02';
   			flag=1;
   		end;
   		drop analysisgrp;
   	run;

   	/* Assign cond level rows */
   	data lookup_attrition;
   		set lookup.lookup_attrition;
   		%if &inclnobs > 0 %then %do;
   		length condlevel $50 descr1 $200;
   		if index(descr,"Information: Members excluded for") or index(descr,"Information: Episodes excluded for") then do;
   			%do n = 1 %to &ncond;
   			descr1 = catx(' ',descr,"%upcase(&&condlevel&n)");
   			if index(descr,"Information: Members excluded for lacking") or index(descr,"Information: Episodes excluded for lacking") 
   			then condlevel=catx(' ','No evidence of ',"&&condlevel&n");
			else condlevel=catx(' ','Evidence of ',"&&condlevel&n");
   			output;
   			%end;
   		end;
   		else do;
   			descr1=descr;
   			output;
   		end;
   		if not missing(descr1) then descr=descr1;
   		drop descr;
   		rename descr1=descr;
   		%end;
   	run;

    proc sql noprint undo_policy=none;
        /* Join lookup table to groups table requested by user */
        create table all_attrition_agg as
   		select distinct a.runid, a.dpidsiteid, a.group, a.level, a.claim_level, a.t%substr(&reporttype,2,1)cohortdef, 
   			   a.descr, a.remaining, a.excluded, a.flag, b.report_descr %if &inclnobs > 0 %then %do; ,b.condlevel %end;
        from all_attrition_groups a
        left join 
             lookup_attrition b 
        on a.claim_level = b.claim_level and a.descr = b.descr;

        /* Sum across all DPs */
		create table all_attrition_agg as 
		select distinct runid, group, report_descr, level, claim_level, flag, t%substr(&reporttype,2,1)cohortdef,
             sum(remaining) as agg_remaining, sum(excluded) as agg_excluded
             %if &inclnobs > 0 %then %do; ,condlevel %end;
             from all_attrition_agg
        group by runid, group, report_descr, level %if &inclnobs > 0 %then %do; ,condlevel %end;;

        /* Sum again, but only to collapse rows 2, 3 and 4 together and 15 and 16 together for excluded */
        create table all_attrition_agg as 
        select distinct runid, group, report_descr, claim_level, t%substr(&reporttype,2,1)cohortdef, max(input(level,best.)) as level,
        	   agg_remaining format=comma12., sum(agg_excluded) as agg_excluded format=comma12., flag
        	   %if &inclnobs > 0 %then %do; ,condlevel %end;
        from all_attrition_agg
        group by runid, group, report_descr, claim_level, t%substr(&reporttype,2,1)cohortdef, agg_remaining %if &inclnobs > 0 %then %do; ,condlevel %end;;
    quit;

    /* Set in condlevel value and delete un-needed rows */
	data all_attrition_agg(keep=runid group level claim_level flag agg_remaining agg_excluded report_descr grouplabel headerlabel t%substr(&reporttype,2,1)cohortdef);
		set all_attrition_agg;
		length grouplabel headerlabel $40;
	  	grouplabel=group;
	  	headerlabel='';
	  	%if &milnobs > 0 %then %do;
	  	if group in (&milgrps) then headerlabel=scan(group,1,'_');
	  	%end;
		%if &inclnobs > 0 %then %do;
		if not missing(condlevel) then report_descr=condlevel;
		%end;
		if missing(report_descr) then delete;
	run;

    /* Merge in group labels and headers if they exist */
    %isdata(dataset=labelfile);
	  %if %eval(&nobs>0) %then %do;

	  %if &milnobs > 0 %then %do;
	  data labelfile;
	  	set labelfile;
	  	if group = "%scan(%sysfunc(dequote(&milgrps)),1,%str(_))" then labeltype = 'header';
	  run;
	  %end;

	  proc sql noprint undo_policy=none;
	        create table all_attrition_agg as
	        select a.*, case when not missing(b.label) then b.label else a.group end as grouplabel, 
	        			case when not missing(c.label) then c.label else '' end as headerlabel
	        from all_attrition_agg (drop=grouplabel headerlabel) a 
	        left join labelfile(where=(lowcase(labeltype) = 'grouplabel')) b
	        on a.group = b.group
	        left join labelfile(where=(lowcase(labeltype) = 'header')) c
	        on a.group = c.group;
	  quit;
	  %end;

	/* Create character variables of remaining and excluded columns */
	  data all_attrition_agg;
	  	set all_attrition_agg;
	  	agg_remaining_char=strip(put(agg_remaining,comma12.));
	  	agg_excluded_char=strip(put(agg_excluded,comma12.));
	  	if missing(agg_excluded) then agg_excluded_char = 'N/A';
	  	if index(level,'.') then do;
	  		if missing(agg_remaining) then agg_remaining_char = 'N/A';
	  	end;
	  	if report_descr = 'Number of members' then do;
	  		agg_remaining_char = strip(put(agg_remaining,comma12.));
	  		agg_excluded_char = 'N/A';
	  	end;
	  	/* Overwrite cell values for T4 analyses */
	  	%if %index(&reporttype,T4) %then %do;
	  	if report_descr = 'Total number of claims with cohort-identifying codes during the query period' then 
	  	   report_descr = 'Total number of live birth deliveries during the query period';
	  	%end;
	  	if int(level) ^= level then level = int(level)+0.1;
	  run;

	  proc sort data = all_attrition_agg; 
	  by group %if &milgrps > 0 %then %do; flag %end; claim_level level ;
	  run;

	  /* Output final episode rows and place final episode count */
	  data all_attrition_agg;
	  	set all_attrition_agg;
	  	length episodecount 8. episodecountchar $20;
	  	retain episodecount episodecountchar;
	  	by group claim_level;
	  	lag_rem=lag(agg_remaining);
	  	if first.group then do;
	  		episodecount=.;
	  		episodecountchar = 'N/A';
	  	end;
	  	if last.claim_level and claim_level = 'Episode' then do;
	  		episodecount=agg_remaining;
	  		episodecountchar=agg_remaining_char;
	  	end;
	  	output;
	  	if last.group %if %length(&milgrps) > 0 %then %do; and flag ^= 1 %end; then do;
	  		%if %index(&reporttype,T4) %then %do;
	  		report_descr = "Number of pregnancy episodes";
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
	  		if t%substr(&reporttype,2,1)cohortdef in ('01','04') and level=99 then do;
	  		agg_remaining = lag_rem;
	  		agg_remaining_char = strip(put(agg_remaining,comma12.));
	  		end;
	  		output;
	  	end;
	  	drop episodecount episodecountchar lag_rem flag;
	  run;

	  /* Output patient/episode level tables */
	  %if ^%index(&reporttype,T4L1) %then %do;
	  proc sort data = all_attrition_agg out=agg_patient_attrition(where=(t%substr(&reporttype,2,1)cohortdef in ('01','04'))) sortseq=linguistic(numeric_collation=on);
	  	by level report_descr group;
	  run;
	  %end;

	  proc sort data = all_attrition_agg out=agg_episode_attrition(where=(t%substr(&reporttype,2,1)cohortdef in ('02','03'))) sortseq=linguistic(numeric_collation=on);
	  	by level report_descr group;
	  run;


%mend attrition_createdata;