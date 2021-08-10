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
%macro t5tables_driver();

    %put =====> MACRO CALLED: t5tables_driver ;

	*** Distribution of days supplied per dispensing (using AdjustedCodeCount) ***;
	%if %sysfunc(prxmatch(m/T1|T2/i,&tablelist.)) > 0 %then %do;
	    %t5tables_createdata(dataset=agg_t5disp,
                           whereclause= 1,
                           catvar=daysupp,
                           countvar=adjustedcodecount,
                           cattableid=T1,
                           disttableid=/*T2*/);
	%end;

	*** Distribution of total episode duration ***;
	%if %sysfunc(prxmatch(m/T3|T4/i,&tablelist.)) > 0 %then %do;
	%t5tables_createdata(dataset=agg_t5episdur,
                           whereclause= 1,
                           catvar=cumepisodelength,
                           countvar=npts,
                           cattableid=T3,
                           disttableid=/*T4*/);

	%end;

	*** Distribution of episode duration ***;
    %if %sysfunc(prxmatch(m/T5|T6/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5episdur,
                           whereclause= 1,
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T5,
                           disttableid=/*T6*/);

	%end; 
	%if %sysfunc(prxmatch(m/T7|T8/i,&tablelist.)) > 0 %then %do;
		%t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=(episodenum <=1),
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T7,
                           disttableid=/*T8*/);

	%end;

	%if %sysfunc(prxmatch(m/T9|T10/i,&tablelist.)) > 0 %then %do;
           %t5tables_createdata(dataset=agg_t5episdur,
                           whereclause=(episodenum >=2),
                           catvar=episodelength,
                           countvar=episodes,
                           cattableid=T9,
                           disttableid=/*T10*/);
	%end;
				     

	%put =====> END MACRO: t5tables_driver ;

%mend t5tables_driver;
