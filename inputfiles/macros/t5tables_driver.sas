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
	%if %sysfunc(prxmatch(m/T1\b|T2\b/i,&tablelist.)) > 0 %then %do;
	    %t5tables_createdata(dataset=agg_t5disp,
                             whereclause= 1,
                             catvar=daysupp,
                             countvar=adjustedcodecount,
                             cattableid=T1,
                             disttableid=/*T2*/,
                             qrpcategories=N);
	%end;

	*** Distribution of total episode duration ***;
	%if %sysfunc(prxmatch(m/T3\b|T4\b/i,&tablelist.)) > 0 %then %do;
	   %t5tables_createdata(dataset=agg_t5episdur,
                            whereclause= 1,
                            catvar=cumepisodelength,
                            countvar=npts,
                            cattableid=T3,
                            disttableid=/*T4*/,
                            qrpcategories=N);
	%end;

	*** Distribution of episode duration ***;
    %if %sysfunc(prxmatch(m/T5\b|T6\b/i,&tablelist.)) > 0 %then %do;
        %t5tables_createdata(dataset=agg_t5episdur,
                             whereclause= 1,
                             catvar=episodelength,
                             countvar=episodes,
                             cattableid=T5,
                             disttableid=/*T6*/,
                             qrpcategories=N);

	%end; 
	%if %sysfunc(prxmatch(m/T7\b|T8\b/i,&tablelist.)) > 0 %then %do;
		%t5tables_createdata(dataset=agg_t5episdur,
                             whereclause=(episodenum <=1),
                             catvar=episodelength,
                             countvar=episodes,
                             cattableid=T7,
                             disttableid=/*T8*/,
                             qrpcategories=N);

	%end;

	%if %sysfunc(prxmatch(m/T9\b|T10\b/i,&tablelist.)) > 0 %then %do;
        %t5tables_createdata(dataset=agg_t5episdur,
                             whereclause=(episodenum >=2),
                             catvar=episodelength,
                             countvar=episodes,
                             cattableid=T9,
                             disttableid=/*T10*/,
                             qrpcategories=N);
	%end;

    *********************;
    *** Dose analysis ***;
    *********************;
        /*current filled daily dose*/
    	%if %sysfunc(prxmatch(m/T18\b/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5disp,
                               whereclause=1,
                               catvar=cfdd_output_cat,
                               countvar=adjustedcodecount,
                               cattableid=T18,
                               disttableid=);
    	%end;
        /*average filled daily dose*/
    	%if %sysfunc(prxmatch(m/T19\b/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5dose,
                               whereclause=1,
                               catvar=afdd_output_cat,
                               countvar=episodes,
                               cattableid=T19,
                               disttableid=);
    	%end;
    	%if %sysfunc(prxmatch(m/T20\b/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5dose,
                               whereclause=(episodenum=1),
                               catvar=afdd_output_cat,
                               countvar=npts,
                               cattableid=T20,
                               disttableid=);
    	%end;
        /*cumulative dose*/
    	%if %sysfunc(prxmatch(m/T21\b/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5dose,
                               whereclause=1,
                               catvar=cumdose_output_cat,
                               countvar=npts,
                               cattableid=T21,
                               disttableid=);
    	%end;
    	%if %sysfunc(prxmatch(m/T22\b/i,&tablelist.)) > 0 %then %do;
            %t5tables_createdata(dataset=agg_t5dose,
                               whereclause=(episodenum=1),
                               catvar=cumdose_output_cat,
                               countvar=npts,
                               cattableid=T22,
                               disttableid=);
    	%end;

	%put =====> END MACRO: t5tables_driver ;

%mend t5tables_driver;
