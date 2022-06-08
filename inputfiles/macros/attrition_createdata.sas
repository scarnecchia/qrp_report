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
*   - agg_adjusted_attrition
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

	/* Link EOI/REF groups back to analysisgrps */
	%if %index(&reporttype,T2L2) %then %do;
	proc sql noprint;
		create table _whatgroups as 
		select distinct runid, analysisgrp, case when missing(eoi) then eoi2 else eoi end as eoi,
							  case when missing(ref) then ref2 else ref end as ref
		from (select a.runid, a.analysisgrp, a.eoi, a.ref, b.eoi as eoi2, b.ref as ref2
		      from pscs_masterinputs (where = (missing(subgroup))) a 
			  left join 
			  psest_masterinputs b 
			  on a.psestimategrp = b.psestimategrp);
	quit;

	/* Transpose data to have runid, group and groupname structure */
	data _null_;
		if _n_=1 then do; 
		dcl hash attr(multidata:'y') ;   
		attr.definekey("analysisgrp") ;   
		attr.definedata("runid","group") ;  
		attr.definedone() ;   
		end;
		/* For L2 requests, cohort groups and analysisgrp values are concatenated with @ delimiter. */
		/* Length needs to be increased to accomodate this */
		length group $81;
		set _whatgroups end=lr;
		array t eoi ref;
		do over t;
		group=t;
		attr.add();
		end;
		if lr then attr.output(dataset:"_tempgrps");
	run;

	/* Append groups */
	data attrition_groups;
		length runid $5 group $81; 
		set attrition_groups _tempgrps;
	run;
	%end;

	%let milgrps=;
	%let milgrplabels=;
	%if &milnobs > 0 %then %do;
	/* Create EOI/REF rows based off MIL group */
	data attrition_groups;
		/* For L2 requests, cohort groups and analysisgrp values are concatenated with @ delimiter. */
		/* Length needs to be increased to accomodate this */
		length group $81;
		set attrition_groups;
		if missing(groupname) then output;
		if not missing(groupname) then do;
		group=catx('_',group,'ref');
		output;
		if substrn(group,max(1,length(group)-3),4) = '_ref' then group=tranwrd(group,'_ref','_eoi');
		output;
		end;
	run;

	%if %index(&reporttype,T4L2) %then %do;
	/* Link all analysisgrp, pregnancy cohorts and EOI/REF groups back to each other */
	proc sql noprint;
		create table _whatgroups as 
		select distinct runid, analysisgrp, case when missing(eoi) then eoi2 else eoi end as eoi,
							  case when missing(ref) then ref2 else ref end as ref, groupname 
		from (select a.runid, a.analysisgrp, a.eoi, a.ref, b.eoi as eoi2, b.ref as ref2, c.groupname 
		      from pscs_masterinputs (where = (missing(subgroup))) a 
			  left join 
			  psest_masterinputs b 
			  on a.psestimategrp = b.psestimategrp
			  left join 
			  master_mil c 
			  on substr(coalescec(a.eoi,b.eoi),1,findc(coalescec(a.eoi,b.eoi), '_',-length(coalescec(a.eoi,b.eoi)))-1) = c.group) 
		;
	quit;

	/* Transpose data to have runid, group and groupname structure */
	data _null_;
		if _n_=1 then do; 
		dcl hash attr(multidata:'y') ;   
		attr.definekey("analysisgrp") ;   
		attr.definedata("runid","group", "groupname") ;  
		attr.definedone() ;   
		end;
		/* For L2 requests, cohort groups and analysisgrp values are concatenated with @ delimiter. */
		/* Length needs to be increased to accomodate this */
		length group $81;
		set _whatgroups end=lr;
		array t eoi ref;
		do over t;
		group=catx('@',analysisgrp,t);
		attr.add();
		end;
		if lr then attr.output(dataset:"_tempgrps");
	run;

	/* Append groups */
	data attrition_groups;
		set attrition_groups _tempgrps;
	run;
	%end;

	proc sql noprint undo_policy=none;
		%if %index(&reporttype,T4L1) %then %do;
		select distinct quote(strip(group)) 
		%end;
		%else %do;
		select distinct quote(strip(scan(group,-1,'@')))
		%end; 
		into :milgrps 
		separated by " "
		from attrition_groups
		where substrn(group,max(1,length(group)-3),4) in ('_eoi','_ref');

		select distinct quote(substr(group,1,findc(group, '_',-length(group))-1))
		into :milgrplabels
		separated by " "
		from attrition_groups 
		where substrn(group,max(1,length(group)-3),4) in ('_eoi','_ref');
	quit;
	%end;

	%let analysisgrps=;
	%if %index(&reporttype,L2) %then %do;
	/* Store analysisgrp values in macro variable */
	proc sql noprint undo_policy=none;
		select distinct quote(strip(group))
		into :analysisgrps 
		separated by ' '
		from attrition_groups;
 	quit;

 	/* Transpose attrition rows to match L1 structure */
	data _null_;
		if _n_=1 then do; 
		dcl hash H(multidata:'y') ;   
		h.definekey("analysisgrp") ;   
		h.definedata("runid","dpidsiteid", "group", "level", "claim_level", "descr","remaining","excluded") ;  
		h.definedone() ;   
		end;
		set agg_adjusted_attrition_&periodid(where=(analysisgrp in (&analysisgrps))) end=lr;
		/* For L2 requests, cohort groups and analysisgrp values are concatenated with @ delimiter. */
		/* Length needs to be increased to accomodate this */
		length group $81;
		array t eoi ref;
		array z eoi_remaining ref_remaining;
		array y eoi_excluded ref_excluded;
		do over t;
		group=catx('@',analysisgrp,t);
		remaining=z;
		excluded=y;
		claim_level='L2';
		h.add();
		end;
		if lr then h.output(dataset:"agg_adj_attrition_&periodid");
	run;

	proc sql noprint undo_policy=none;
		create table agg_adj_attrition_&periodid as
		select a.runid, a.dpidsiteid, a.group, put(a.level+2000,7.) as level, 
			   a.claim_level, a.descr, a.remaining, a.excluded, b.t%substr(&reporttype,2,1)cohortdef
		from agg_adj_attrition_&periodid a
		left join 
		master_typefile b
		on scan(a.group,-1,'@') = b.group
		order by a.runid, a.dpidsiteid, a.group, a.level, a.claim_level, a.descr, a.remaining, a.excluded;
	quit;
	%end;
	
	/* Join only required groups to attrition table */
    proc sql noprint;
   		create table all_attrition_groups as 
   		select distinct A.runid, A.dpidsiteid, A.group, 
   						A.level, A.claim_level, A.descr, 
						A.remaining, A.excluded, d.t%substr(&reporttype,2,1)cohortdef
						%if &milnobs > 0 %then %do; ,b.group as milgrp %end;
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

   	%if %index(&reporttype,L2) %then %do;
   	proc sql noprint undo_policy=none;
   		create table all_attrition_groups as 
   		select distinct a.*, b.group as l2eoirefgroups
   		from all_attrition_groups a 
   		left join 
   		agg_adj_attrition_&periodid b 
   		on a.group = scan(b.group,-1,'@')
   		order by a.runid, a.dpidsiteid, a.level, 
   				 a.claim_level, a.descr, a.remaining, a.excluded;

   		select distinct quote(scan(l2eoirefgroups,1,'@'))
   		into :analysisgrps
   		separated by ' '
   		from all_attrition_groups
   		where not missing(l2eoirefgroups);

   		%if %index(&reporttype,T4L2) %then %do;
   		create table agg_mil_attrition as 
   		select a.*, b.group as l2eoirefgroups
   		from agg_mil_attrition 
   		%if %varexist(agg_mil_attrition,l2eoirefgroups) = 1 %then %do; 
   		(drop=l2eoirefgroups)
   		%end;
   		a 
   		inner join 
   		agg_adj_attrition_&periodid b 
   		on a.analysisgrp = scan(b.group,-1,'@');
   		%end;
   	quit;
   	%end;


   	%if %length(&milgrps) > 0 or %length(&analysisgrps) > 0 %then %do;
   	data all_attrition_groups;
   		length group $81;
   		set all_attrition_groups(in=a) 
   			%if %length(&milgrps) > 0 %then %do; 
   		    agg_mil_attrition(in=b where=(analysisgrp in (&milgrps)))
   		    %end;
   		    %if %length(&analysisgrps) > 0 %then %do;
   		    agg_adj_attrition_&periodid(in=c)
   		    %end;
   		    ;
   		if a then do;
   			/* Reassign group values with milgrp EOI/REF equivalents */
   			%if %length(&milgrps) > 0 %then %do;
 			if group^=milgrp and not missing(milgrp) then group=milgrp;
 			%end;
 			%if %length(&analysisgrps) > 0 %then %do;
 			if scan(l2eoirefgroups,-1,'@') = group then do; 
 				if group^=l2eoirefgroups and not missing(l2eoirefgroups) then group=l2eoirefgroups;
 			end;
 			%end;
   		end;
   		/* Add to level so MIL rows are sorted towards the bottom */
   		%if %length(&milgrps) > 0 %then %do;
   		if b then do;
   			group=analysisgrp;
   			%if %index(&reporttype,T4L2) %then %do;
   			group=l2eoirefgroups;
   			%end;
   			claim_level='MIL';
   			level=strip(put(input(level,best.)+1000,bestd7.));
   			t4cohortdef='02';
   		end;
   		drop analysisgrp;
   		%end;
   		%if %length(&analysisgrps) > 0 and %index(&reporttype,T4) %then %do;
   		if c then do;
   			t4cohortdef='02';
   		end;
   		%end;
   	run;
   	%end;

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
   			   a.descr, a.remaining, a.excluded, b.report_descr %if &inclnobs > 0 %then %do; ,b.condlevel %end;
        from all_attrition_groups a
        left join 
             lookup_attrition b 
        on a.claim_level = b.claim_level and a.descr = b.descr;

        /* Sum across all DPs */
		create table all_attrition_agg as 
		select distinct runid, group, report_descr, level, claim_level, t%substr(&reporttype,2,1)cohortdef,
             sum(remaining) as agg_remaining, sum(excluded) as agg_excluded
             %if &inclnobs > 0 %then %do; ,condlevel %end;
             from all_attrition_agg
        group by runid, group, report_descr, level %if &inclnobs > 0 %then %do; ,condlevel %end;;

        /* Sum again, but only to collapse rows 2, 3 and 4 together and 15 and 16 together for excluded */
        create table all_attrition_agg as 
        select runid, group, report_descr, claim_level, t%substr(&reporttype,2,1)cohortdef, max(input(level,best.)) as level,
        	   min(agg_remaining) as agg_remaining format=comma12., sum(agg_excluded) as agg_excluded format=comma12.
        	   %if &inclnobs > 0 %then %do; ,condlevel %end;
        from all_attrition_agg
        group by runid, group, report_descr, claim_level, t%substr(&reporttype,2,1)cohortdef %if &inclnobs > 0 %then %do; ,condlevel %end;;
    quit;

    /* Set in condlevel value and delete unneeded rows */
	data all_attrition_agg(keep=runid group level claim_level agg_remaining agg_excluded report_descr grouplabel headerlabel
					      %if %length(&milgrps) > 0 %then %do; millabel %end;
						  t%substr(&reporttype,2,1)cohortdef);
		set all_attrition_agg;
		length grouplabel headerlabel $&label_length;
	  	grouplabel=group;
	  	headerlabel='';
	  	%if %length(&milgrps) > 0 %then %do;
	  	if group in (&milgrps) then do;
	  		/* create headerlabel for when no labelfile is specified, millabel for when it is specified */
	  		headerlabel=substr(group,1,findc(group, '_',-length(group))-1);
	  		millabel=substr(group,1,findc(group, '_',-length(group))-1);
	  	end;
	  	%end;
	  	%if %length(&analysisgrps) > 0 %then %do;
	  	if scan(group,1,'@') in (&analysisgrps) then do;
	  		headerlabel=scan(group,1,'@');
	  		grouplabel=scan(group,-1,'@');
	  		millabel=scan(group,1,'@');
	  	end;
	  	%end;
		%if &inclnobs > 0 %then %do;
		if not missing(condlevel) then report_descr=condlevel;
		%end;
		if missing(report_descr) then delete;
	run;

    /* Merge in group labels and headers if they exist */
   %isdata(dataset=labelfile);
	%if %eval(&nobs>0) %then %do;

        %let labelfileattrition = labelfile;

        /* Add grouplabel to header so MILGrpLabel ends up in same location in report */
	    %if %length(&milgrps) > 0 or %length(&analysisgrps) > 0 %then %do;
	       data _templabelfileattrition;
	  	        set labelfile;
	  	        %if %length(&milgrps) > 0 %then %do;
	  	        %do i = 1 %to %sysfunc(countw(&milgrplabels,%str( )));
	  		       %let milgrp = %scan(&milgrplabels,&i,%str( ));
	  		       if group = &milgrp and labeltype = 'grouplabel' then do;
                        labeltype = 'header';
                        output;
                   end;
	  	        %end;
	  	        %end;

	  	        %if %length(&analysisgrps) > 0 %then %do;
	  	        %do j = 1 %to %sysfunc(countw(&analysisgrps,%str( )));
	  		       %let analysisgrp = %scan(&analysisgrps,&j,%str( ));
	  		           if group = &analysisgrp and labeltype = 'grouplabel' then do;
                        labeltype = 'header';
                        output;
                       end;
	  	        %end;
	  	        %end;
	       run;

           *append new header row with rest of table, remove new header row if header already exists*/
           %let labelfileattrition=labelfileattrition;
           %isdata(dataset=_templabelfileattrition);
           %if %eval(&nobs.>0) %then %do;
            data _templabelfileattrition;
                set labelfile(in=a)
                    _templabelfileattrition(in=b);
                    if a then _newrow = 'N';
                    if b then _newrow = 'Y';
            run;

            proc sort data=_templabelfileattrition;
                by runid group labeltype _newrow;
            run;

            data labelfileattrition(drop=_newrow);
                set _templabelfileattrition;
                by runid group labeltype _newrow;

                if first.labeltype ne last.labeltype then do;
                    if _newrow = 'Y' then delete;
                end;
            run;

            %let labelfileattrition = labelfileattrition;
           %end;
        %end;

	    proc sql noprint undo_policy=none;
	        create table all_attrition_agg as
	        select a.*, case when not missing(b.label) then b.label 
	        			else 
	        			%if %length(&analysisgrps) > 0 %then %do; 
	        			scan(a.group,-1,'@') 
	        			%end; 
	        			%else %do; 
	        			a.group 
	        			%end; 
	        			end as grouplabel, 
	        			case when not missing(c.label) then c.label  
	        				 %if %length(&milgrps) > 0 %then %do;
	        				 when missing(c.label) then a.millabel
	        				 %end;
	        				 %if %length(&analysisgrps) > 0 %then %do;
	        				 when missing(c.label) and index(a.group,'@') then scan(a.group,1,'@')
	        				 %end;
	        				 else ''
	        			end as headerlabel
	        from all_attrition_agg (drop=grouplabel headerlabel) a 
	        left join &labelfileattrition.(where=(lowcase(labeltype) = 'grouplabel')) b
	        on a.group = b.group %if %length(&analysisgrps) > 0 %then %do; or scan(a.group,-1,'@') = b.group %end;
	        left join &labelfileattrition.(where=(lowcase(labeltype) = 'header')) c
	        on a.group = c.group %if %length(&milgrps) > 0 %then %do; 
                                 or (case when findc(a.group, '_') > 0 then substr(a.group,1,findc(a.group, '_',-length(a.group))-1) = c.group 
                                    else a.group = c.group end) 
                                 %end;
	        					 %if %length(&analysisgrps) > 0 %then %do; or (scan(a.group,1,'@') = c.group or scan(a.group,-1,'@') = c.group) %end;
	        ;
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
	  	%if %index(&reporttype,L2) %then %do;
	  	/* If the header labels are missing, this means duplicate rows are carried through for additional analysis groups */
	  	/* Delete this so only requested analysis groups remain in final table */
	  	if missing(headerlabel) then delete;
	  	%end;
	  run;

	  proc sort data = all_attrition_agg; 
	  by group claim_level level;
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
	    %if %index(&reporttype,T4) %then %do; /*last row is # of matched non-pregnant episodes, so need to take 2nd to last row*/
        if report_descr = 'Had sufficient post-index continuous enrollment' then do;
        %end;
        %else %do;
	  	if last.claim_level and claim_level = 'Episode' then do;
        %end;
	  		episodecount=agg_remaining;
	  		episodecountchar=agg_remaining_char;
	  	end;
	  	%if %index(&reporttype,L2) %then %do;
	  	if report_descr in ('Number of events in comparative analysis', 'Number of patients with a truncated inverse probability of treatment weight')
	  	then agg_excluded_char = 'N/A';
	  	%end;
		%if %sysfunc(prxmatch(m/redactevents|sumevents/i,&customizecolumns.)) > 0 and 
                %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            if index(lowcase(report_descr), 'event')>0  and claim_level='L2' then do;
			  agg_remaining = .;
			  agg_remaining_char = 'N/A';
			  agg_excluded = .;
			  agg_excluded_char = 'N/A';
			end;
			%end;
	  	output;
        %if &reporttype. ne T5 %then %do;
	  	if last.group then do;
	  		%if %index(&reporttype,T4) %then %do;
	  		report_descr = "Number of pregnancy episodes";
	  		%end;
	  		%else %do;
	  		report_descr = "Number of episodes";
	  		%end;
	  		%if %index(&reporttype,T4) %then %do;
	  		level=27.5;
	  		%end;
	  		%else %do;
	  		level=99;
	  		%end;
	  		claim_level='Episode';
	  		agg_remaining = episodecount;
	  		agg_remaining_char = episodecountchar;
	  		agg_excluded = .;
	  		agg_excluded_char = 'N/A';
	  		if t%substr(&reporttype,2,1)cohortdef in ('01') and level=99 then do;
	  		agg_remaining = lag_rem;
	  		agg_remaining_char = strip(put(agg_remaining,comma12.));
	  		end;
	  		output;
	  	end;
        %end;
	  	drop episodecount episodecountchar lag_rem;
	  run;

	  /* Join in order variable to sort groups based on input file ordering */
	  proc sql noprint undo_policy=none;
	  	create table all_attrition_agg as 
	  	select a.*, c.attrorder
	  	from all_attrition_agg a 
	  	left join
	  		(select b.runid, b.group, min(b.order) as attrorder
	  			from inputfiles b 
	  			group by b.runid, b.group
	  		) c 
	  	on scan(a.group,1,'@') = c.group;
	  quit;

	  %if %index(&reporttype,L2) %then %do;

	    %let attrperiodid=_&periodid;
	    proc sql noprint undo_policy=none;
		/* Create ordering variable based off eoi/ref values */
		create table all_attrition_agg as 
		select a.*, case when scan(a.group,-1,'@') = d.eoi then 1
						 when scan(a.group,-1,'@') = d.ref then 2
						 else 2 
						 end as eoireforder
		from all_attrition_agg a 
		left join
		(select distinct a.runid, a.group as analysisgrp, coalescec(b.eoi,c.eoi) as eoi, coalescec(b.ref,c.ref) as ref 
		from inputfiles a 
		left join pscs_masterinputs (where = (missing(subgroup))) b 
		on a.group = b.analysisgrp
		left join psest_masterinputs c 
		on b.psestimategrp = c.psestimategrp) d
		on scan(a.group,1,'@') = d.analysisgrp and scan(a.group,-1,'@') = coalescec(d.eoi,d.ref);
	    quit;

	  %end; 

	  /* Output patient/episode level tables */
	  %if ^%index(&reporttype,T4L1) %then %do;
	  proc sort data = all_attrition_agg out=agg_patient_attrition&attrperiodid(where=(t%substr(&reporttype,2,1)cohortdef in ('01','04'))) sortseq=linguistic(numeric_collation=on);
	  	by level report_descr attrorder %if %index(&reporttype,L2) %then %do; eoireforder %end; group;
	  run;
	  %end;

	  proc sort data = all_attrition_agg out=agg_episode_attrition&attrperiodid(where=(t%substr(&reporttype,2,1)cohortdef in ('02','03'))) sortseq=linguistic(numeric_collation=on);
	  	by level report_descr attrorder %if %index(&reporttype,L2) %then %do; eoireforder %end; group;
	  run;

      proc datasets nowarn noprint lib=work;
        delete labelfileattrition _templabelfileattrition;
      quit;


%mend attrition_createdata;
