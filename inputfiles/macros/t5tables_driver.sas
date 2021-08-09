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
	%if %sysfunc(prxmatch(m/T4|T7/i,&tablelist.)) > 0 %then %do;
	%t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=,
                           catvar=cumepisodelength,
                           countvar=npts,
                           cattableid=T4,
                           disttableid=/*T7*/);

	%end;

	*** Distribution of episode duration ***;
	data _chk_table;
		set tablefile (where=(table in ('T1', 'T5','T6', 'T7', 'T8', 'T9', 'T10')));
	run;
	%isdata(dataset=_chk_table);

	%if &nobs>0 %then %do;
		
		%if %sysfunc(prxmatch(m/T8|T9/i,&tablelist.)) > 0 %then %do;
			%t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=(episodenum <=1),
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T8,
                           disttableid=/*T9*/);

		%end;

		%if %sysfunc(prxmatch(m/T10|T5/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=(episodenum >=2),
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T10,
                           disttableid=/*T5*/);
		%end;
				     
		%if %sysfunc(prxmatch(m/T6|T1/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=,
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T6,
                           disttableid=/*T1*/);

		%end;
	%end; 

    *** Distribution of days supplied per dispensing (using AdjustedCodeCount) ***;
	%if %sysfunc(prxmatch(m/T2|T12/i,&tablelist.)) > 0 %then %do;
	    %t5tables_createdata(dataset=agg_t5disp,
                           whereclause=,
                           catvar=daysupp,
                           countvar=adjustedcodecount,
                           cattableid=T2,
                           disttableid=/*T12*/);
	%end;

	%put =====> END MACRO: t5tables_driver ;

%mend t5tables_driver;
