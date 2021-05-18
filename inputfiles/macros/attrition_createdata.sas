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

/* Obtain required groups from inputfiles */

   %macro pat_epi_attrition(dataset=);
   data attrition_groups;
   	set 
   	%if %sysfunc(exist(input.&groupsfile.)) ne 0 %then %do;
		input.&groupsfile.
	%end;
	%if %sysfunc(exist(input.&l2comparisonfile.)) ne 0 %then %do;
        input.&l2comparisonfile. (rename=AnalysisGrp=group)
	%end;
    %if %sysfunc(exist(input.&baselinefile.)) ne 0 %then %do;
        input.&baselinefile.
    %end;
		;
		runid = lowcase(runid);
		group = lowcase(group);
	run;

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
   		inner join 
   		master_typefile d
   		on a.group = d.group and a.runid = d.runid
   		/* Join condlevel when inclusioncodes file exists */
   		%if &inclnobs > 0 %then %do;
   		left join 
   		master_inclusioncodes c
   		on b.group = c.group and b.runid = c.runid
   		%end;
   		;
   	quit;

    proc sql noprint undo_policy=none;
        /* Create patient and/or episode level table */
        create table &dataset as
   		select runid, dpidsiteid, group, level, claim_level, 
   		   	   case when level = '1' then 'Enrolled at any point during the query period'
   			   	    when level in ('2','3','4') then 'Had required coverage type (medical and/or drug coverage)'
   			   	    when level = '5' then 'Enrolled during specified age range'
   			   	    when level = '6' then 'Had requestable medical charts'
   			   	    when level = '7' then 'Met demographic requirements (sex, race, and Hispanic origin)'
   			   	    when level = '8' then 'Had any cohort-defining claim during the query period'
   			   	    when level = '9' then 'Total number of claims with cohort-identifying codes during the query period'
   			   	    when level = '10' then 'Claim recorded during specified age range'
   			   	    %if &datadrivenperiod = DATADRIVEN %then %do;
   			   	    when level = '11' then 'Claim recorded during current look period'
   			   	    %end;
   			   	    when level = '12' then 'Episode defining index claim recorded during the query period'
   			   	    when level = '13' then 'Met exposure incidence criteria'
   			   	    %if %index(&reporttype,T3) %then %do;
   			   	    when level = '14' then 'Had single National Drug Code on index date'
   			   	    %end;
   			   	    when level in ('15','16') then 'Had sufficient pre-index continuous enrollment'
   			   	    when level = '17' then 'Met exclusion and inclusion criteria'
   			   	    when index(level,'.') then substr(descr,find(descr,'lacking')+8)
   			   	    when level = '18' then 'Met event incidence criteria'
   			   	    when level = '19' then 'Had sufficient post-index continuous enrollment'
   			   	    %if %index(&reporttype,T2) or %index(&reporttype,T6) %then %do;
   			   	    when level = '20' then "Had minimum days' supply on index date"
   			   	    %end;
   			   	    when level = '21' then 'Had index episode of at least required length'
   			   	    %if %index(&reporttype,T2) %then %do;
   			   	    when level = '22' then 'Had index episode longer than blackout period'
   			   	    when level = '23' then 'Did not have an event during blackout period'
   			   	    %end;
   			   	    %if %index(&reporttype,T3) %then %do;
   			   	    when level = '24' then 'Had an event during the risk or control window'
   			   	    %end;
   			   	    %if &dataset = agg_episode_attrition %then %do;
   			   	    when level = '25' and t%substr(&reporttype,2,1)cohortdef = '03' then 'Episode occurred after first event'
   			   	    %end;
   			   	    when level = '30' then 'Number of episodes'
   			   	    end as descrlabel,
			   descr, remaining, excluded %if &inclnobs > 0 %then %do; ,condlevel %end;
        from all_attrition_groups
        %if &dataset = agg_patient_attrition %then %do;
        where t%substr(&reporttype,2,1)cohortdef in ('01','04')
        %end;
        %else %do;
        where t%substr(&reporttype,2,1)cohortdef in ('02','03')
        %if %index(&reporttype,T4) %then %do;
        and t%substr(&reporttype,2,1)cohortdef2 in ('01','02','99')
        %end;
        %end;
		;

		create table &dataset as 
		select distinct runid, group, level, remaining, excluded, descrlabel, 
             sum(remaining) as agg_remaining format=comma12., sum(excluded) as agg_excluded format=comma12.,
             case when level in ('2','3','4') then sum(case when level in ('2','3','4') then excluded else 0 end) else 0 end as collapse1 format=comma12.,
             case when level in ('15','16') then sum(case when level in ('15','16') then excluded else 0 end) else 0 end as collapse2 format=comma12.
             %if &inclnobs > 0 %then %do; ,condlevel %end;
             from &dataset
             group by runid, group, level;
    quit;

    /* Finalize summing and delete un-needed rows */
	data &dataset(keep=runid group level agg_remaining agg_excluded descrlabel condlevel);
		set &dataset;
		if level = '2' then do;
			if agg_excluded ^= collapse1 then agg_excluded = collapse1;
		end;
		if level = '15' then do;
			if agg_excluded ^= collapse2 then agg_excluded = collapse2;
		end;
		if missing(descrlabel) then delete;
	run;

    /* Merge in group labels and headers if they exist */
    %isdata(dataset=labelfile);
	  %if %eval(&nobs>0) %then %do;
	  proc sql noprint undo_policy=none;
	        create table &dataset as
	        select a.*, b.label, b.labeltype
	        from &dataset a left join labelfile(where=(lowcase(labeltype) in ('grouplabel', 'header'))) b
	        on a.group = b.group;
	  quit;
	  %end;

	  proc sort data = &dataset sortseq=linguistic(numeric_collation=on);
	  	by runid group level;
	  run;

	%mend pat_epi_attrition;

	%if ^%index(&reporttype,T4L1) %then %pat_epi_attrition(dataset=agg_patient_attrition);
	%pat_epi_attrition(dataset=agg_episode_attrition);


%mend attrition_createdata;