****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: report_formats_labels.sas  
* Created (mm/dd/yyyy): 12/11/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates formats and datasets that hold labels
*                                        
*  Program inputs:                                                                                   
* 
*  Program outputs:       
*   datasets:
*   -agefmtsort: one row per cohortgrp, agegroup, agegroupnum
*
*   formats;
*   -agefmt
*   -sexfmt
*   -sexsort
*   -racefmt
*   -racesort
*   -hispanicfmt
*   -hispanicsort
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

%macro report_formats_labels();

    %put =====> MACRO CALLED: report_formats_labels ;

/***************************************************************************************************
*  Create demographic variable formats                                            
***************************************************************************************************/

    /* Age Format*/
    data _agefmt(keep=label_fmt)
         agefmtsort(keep=var count cohortgrp runid rename=var=agegroup rename=count=agegroupnum);
		set master_cohortfile (keep=agestrat cohortgrp runid);
		if missing(agestrat) then agestrat ="00-01 02-04 05-09 10-14 15-18 19-21 22-44 45-64 65-74 75+";
		agestrat=upcase(agestrat);
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

			periodstart=compress(start,'0123456789');
			periodend=compress(end,'0123456789');
			var2=strip(start)||"-"||strip(end);
			if end="High" then do;
				var2=strip(start)||"+";
			end;
			same=0;
			if start = end then do;
				same=1;
			end;
			*remove leading zeros;
			if start in: ("0") and start ne "0" then start=substr(start,2);
			if end   in: ("0") and end ne "0" then end=substr(end,2);
			if end="High" then do;
			 *if missing period = years;
				if index(start,"M")=0 AND index(start,"W")=0 AND index(start,"Y")=0 AND index(start,"Q")=0
				AND index(start,"D")=0 then start=strip(start)||"Y";
			 *convert MWYQD;
				start=tranwrd(start,'M',' months');
				start=tranwrd(start,'W',' weeks');		
				start=tranwrd(start,'Y',' years');
				start=tranwrd(start,'Q',' quarters');
				start=tranwrd(start,'D',' days');	
				formatAge=strip('^{unicode "2265"x} ')||""||strip(start);
			end;
			else do;
			 *if missing period = years;
				if index(end,"M")=0 AND index(end,"W")=0 AND index(end,"Y")=0 AND index(end,"Q")=0
				AND index(end,"D")=0 then end=strip(end)||"Y";
			 *convert MWYQD;
				if periodstart = periodend then do;
					start=translate(start,'','M','','W','','Y','','Q','','D');
				end;
				if periodstart ne periodend then do;
					start=tranwrd(start,'M',' months');
					start=tranwrd(start,'W',' weeks');		
					start=tranwrd(start,'Y',' years');
					start=tranwrd(start,'Q',' quarters');
					start=tranwrd(start,'D',' days');	
				end;
				end=tranwrd(end,'M',' months');
				end=tranwrd(end,'W',' weeks');		
				end=tranwrd(end,'Y',' years');
				end=tranwrd(end,'Q',' quarters');
				end=tranwrd(end,'D',' days');		
				formatAge=strip(start)||"-"||strip(end);	
				if same=1 then do;
					formatAge=strip(end);	
				end;
			end;
			label_fmt="'"||strip(var2)||"'='"||strip(formatAge)||"'";
			output _agefmt;
            output agefmtsort; 
		end;
		drop nwordsvar nwords;
    run;

	proc sql noprint;
      select distinct label_fmt into: AGESTRAT  separated by ' '    
      from _agefmt;
    quit; 

	%put &=AGESTRAT;

    proc datasets nowarn noprint lib=work;
        delete _agefmt;
    quit;

    /***************************/
    /* MASTER FORMAT STATEMENT */
    /***************************/
    proc format;  

        /*Age Format*/
        value $agefmt
        &AGESTRAT.;

        /*Sex Format*/
        value $sexfmt
        "F"   = "Female"
        "M"   = "Male"
        "O"   = "Other";

        value $sexsort
        "F"   = 1
        "M"   = 2
        "O"   = 3;

        /*Race Format*/
        value $racefmt
        "0"   = "Unknown"
        "1"   = "American Indian or Alaska Native"
        "2"   = "Asian"
        "3"   = "Black or African American"
        "4"   = "Native Hawaiian or Other Pacific Islander"
        "5"   = "White";

        value $racesort     
        "1"   = 1
        "2"   = 2
        "3"   = 3
        "4"   = 4
        "0"   = 5
        "5"   = 6;

        /*Hispanic Format*/
        value $hispanicfmt
        "Y"   = "Yes"
        "N"   = "No"
        "U"   = "Unknown";

        value $hispanicsort
        "Y"   = 1
        "N"   = 2
        "U"   = 3;
    run;


/***************************************************************************************************
*  Create datasets containing run specific covariate labels                                              
***************************************************************************************************/

    /*loop through each runID, create datasets &runid._covarname*/
    %do r = 1 %to %eval(&numrunid.);
        %let runid = %scan(&runidlist., &r.);
        %if %sysfunc(exist(infolder.&&&runid._covariatecodes.))=1 %then %do;
            proc sql;    
                create table &runid._covarname as 
                select distinct covarnum, studyname 
                from infolder.&&&runid._covariatecodes.;
            quit;
        %end;
    %end;
    
%mend report_formats_labels;
	
