****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: reportformats.sas  
* Created (mm/dd/yyyy): 12/11/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates formats
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

%macro reportformats();

    %put =====> MACRO CALLED: reportformats ;

*Age Format;

 /*Look through each analytic group*/
 %do grp = 1 %to &numgroups.;

	%let MISSAGESTRAT=N;

	data _NULL_;
	set master_cohortfile (keep=agestrat cohortgrp);
	if _n_ = &grp.;
	if missing(agestrat)=1 then call symputx("MISSAGESTRAT","Y");
	run;
	%put &MISSAGESTRAT.;

	%IF %STR("&MISSAGESTRAT.")="Y" %THEN %DO;
		%LET AGESTRAT&grp.="00-01"="0-1 years" "02-04"="2-4 years" "05-09"="5-9 years" "10-14"="10-14 years" "15-18"="15-18 years" 
		"19-21"="19-21 years" "22-44"="22-44 years" "45-64"="45-64 years" "65-74"="65-74 years" "75+"=">=75 years";
	%END;

	%ELSE %DO;
		data _agefmt;
		set master_cohortfile (keep=agestrat cohortgrp);
		if _n_ = &grp.;
		format start end var $20.;
		nwords=countw(agestrat, " ");
		do count=1 to nwords;
			var=scan(agestrat, count, " ");
			nwordsvar=countw(var, "-");
			if nwordsvar=2 then do;
				 start=scan(var, 1, "-");
				 end=scan(var, 2, "-");
			end;
			else do;
				 start=scan(var, 1, "+");
				 end="High";
			end;
			var2=strip(compress(translate(upcase(start),"",'M',"",'W',"",'Y',"",'Q',"",'D')))||"-"||strip(end);
			if end="High" then do;
			var2=strip(compress(translate(upcase(start),"",'M',"",'W',"",'Y',"",'Q',"",'D')))||"+";
			end;
			*remove leading zeros;
			if start in: ("0") then start=substr(start,2);
			if end   in: ("0") then end=substr(end,2);
			if end="High" then do;
			 *if missing period = years;
				if index(start,upcase("M"))=0 AND index(start,upcase("W"))=0 AND index(start,upcase("Y"))=0 AND index(start,upcase("Q"))=0
				AND index(start,upcase("D"))=0 then start=strip(start)||"Y";
			 *convert MWYQD;
				start=tranwrd(UPCASE(start),'M',' months');
				start=tranwrd(UPCASE(start),'W',' weeks');		
				start=tranwrd(UPCASE(start),'Y',' years');
				start=tranwrd(UPCASE(start),'Q',' quarters');
				start=tranwrd(UPCASE(start),'D',' days');	
			    formatAge=strip(">=")||""||strip(lowcase(start));
			end;
			else do;
			 *if missing period = years;
				if index(end,upcase("M"))=0 AND index(end,upcase("W"))=0 AND index(end,upcase("Y"))=0 AND index(end,upcase("Q"))=0
				AND index(end,upcase("D"))=0 then end=strip(end)||"Y";
			 *convert MWYQD;
				start=translate(start,'','M','','W','','Y','','Q','','D');
				end=tranwrd(UPCASE(end),'M',' months');
				end=tranwrd(UPCASE(end),'W',' weeks');		
				end=tranwrd(UPCASE(end),'Y',' years');
				end=tranwrd(UPCASE(end),'Q',' quarters');
				end=tranwrd(UPCASE(end),'D',' days');		
				formatAge=strip(lowcase(start))||"-"||strip(lowcase(end));	
			end;
			label_fmt="'"||strip(var2)||"'='"||strip(formatAge)||"'";
			output _agefmt;
		end;
		drop nwordsvar nwords;
		run;

	  proc sql noprint;
      select distinct label_fmt into: AGESTRAT&grp.  separated by ' '    
      from _agefmt;
      quit; 

	%END; *non-missing agestrat;

 %END; *loop grp;

	%let AGESTRAT =;
 	%do grp = 1 %to &numgroups.; 
	%let AGESTRAT = &agestrat. &&AGESTRAT&grp.. ;
	%end;
	
	%put &=AGESTRAT;

	proc format;
    value $agefmt
          &AGESTRAT.;
    run;

*End Age format;


%mend reportformats;
%reportformats;
	

