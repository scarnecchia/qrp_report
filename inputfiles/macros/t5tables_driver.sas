****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t5tables_driver.sas  
* Created (mm/dd/yyyy): 08/06/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The driver macro produces tables for a Type 5 report
*                                       
*  Program inputs:          
* 
*  Program outputs:                                                                                                                                       
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
%macro t5tables_driver;

    %put =====> MACRO CALLED: t5tables_driver ;
	/**************************************************************************************************
	* Distribution and Censor Counts tables												
 	***************************************************************************************************/

	*** Distribution of total episode duration ***;
	%if %sysfunc(prxmatch(m/T1|T2/i,&datasetlist.)) > 0 %then %do;
	%t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=%nrstr(lowcase(group) in (&&grouplist_&n..))),
                           catvar=cumepisodelength,
                           countvar=npts,
                           cattableid=T1,
                           disttableid=/*T2*/);

	%end;

	*** Distribution of episode duration ***;
	data _chk_table;
		set tablefile (where=(table in ('T3', 'T4', 'T5','T6', 'T7', 'T8')));
	run;
	%isdata(dataset=_chk_table);

	%if &nobs>0 %then %do;
		proc sql noprint;
			select distinct levelid1, levelid2 into: levelist1 separated by " ", :levelist2 separated by " "
			from _chk_table;
		quit;

		%create_comma_charlist(inlist=&levelist1, outlist=levelist1n);
		%create_comma_charlist(inlist=&levelist2, outlist=levelist2n);

		%put &=levelist1n &=levelist2n;

		proc contents data=agg_t5episdur out=agg_episdur_outnames(keep=name) noprint;
		run;
		proc sql noprint;
			select distinct name into: classvarlist separated by ' '
			from agg_episdur_outnames
			where lowcase(name) ne 'npts' & index(lowcase(name), 'episode') = 0;
		quit;
		%put &classvarlist;
		
		%if %sysfunc(prxmatch(m/T3|T4/i,&datasetlist.)) > 0 %then %do;

			proc means data=agg_episdur_first noprint nway;
				var episodes;
				class &classvarlist. episodelength / missing;
				output out=agg_episdur_first(drop=_:) sum=;
			run;
            
			%t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=%nrstr(lowcase(group) in (&&grouplist_&n..)))
                                       and (level in (&levelist1n., &levelist2n.) and episodenum <=1),
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T3,
                           disttableid=/*T4*/);

		%end;

		%if %sysfunc(prxmatch(m/T5|T6/i,&datasetlist.)) > 0 %then %do;

		    proc means data=agg_episdur_secondpl noprint nway;
				var episodes;
				class &classvarlist. episodelength  / missing;
				output out=agg_episdur_secondpl(drop=_:) sum=;
			run;
            %t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=%nrstr(lowcase(group) in (&&grouplist_&n..))) and
                                       (level in (&levelist1n., &levelist2n.) and episodenum >=2),
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T5,
                           disttableid=/*T6*/);
		%end;
				     
		%if %sysfunc(prxmatch(m/T7|T8/i,&datasetlist.)) > 0 %then %do;

			proc means data=agg_episdur_all noprint nway;
				var episodes;
				class &classvarlist. episodelength  / missing;
				output out=agg_episdur_all(drop=_:) sum=;
			run;
            %t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=%nrstr(lowcase(group) in (&&grouplist_&n..))) and
                                       (level in (&levelist1n., &levelist2n.)),
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T7,
                           disttableid=/*T8*/);

		%end;
	%end;  

	%put =====> END MACRO: t5tables_driver ;

%mend t5tables_driver;
