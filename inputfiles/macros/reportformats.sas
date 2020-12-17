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
		data _agefmt;
		set master_cohortfile (keep=agestrat);
		if missing(agestrat) then agestrat ="00-01 02-04 05-09 10-14 15-18 19-21 22-44 45-64 65-74 75+";
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
			var2=strip(start)||"+";
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
				formatAge=strip('^{unicode "2265"x} ')||""||strip(lowcase(start));
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
      select distinct label_fmt into: AGESTRAT  separated by ' '    
      from _agefmt;
      quit; 
	
	%put &=AGESTRAT;

	proc format;
    value $agefmt
          &AGESTRAT.;
    run;

    proc datasets nowarn noprint lib=work;
        delete _agefmt;
    quit;

*End Age format;

%mend reportformats;
	

