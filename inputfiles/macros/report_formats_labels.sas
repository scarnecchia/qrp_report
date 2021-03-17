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
*   -deliveryfmt
*   -deliverysort
*   -birthtypefmt
*   -birthtypesort
*   -matchfmt
*   -matchsort
*   -timefmt
*   -timesort
*
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

%macro report_formats_labels();

    %put =====> MACRO CALLED: report_formats_labels ;

/***************************************************************************************************
*  Create demographic variable formats                                            
***************************************************************************************************/

    /* Age Format*/
    data _agefmt(keep=label_fmt sort_fmt)
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
				formatAge=strip("(*ESC*){unicode '2265'x} ")||""||strip(start);
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
			label_fmt='"'||strip(var2)||'"="'||strip(formatAge)||'"';
            sort_fmt="'"||strip(var2)||"'="||strip(count);
			output _agefmt;
            output agefmtsort; 
		end;
		drop nwordsvar nwords;
    run;

	proc sql noprint;
      select distinct label_fmt into: AGEFMT  separated by ' '    
      from _agefmt;
      select distinct sort_fmt into: AGEORDER separated by ' '
      from _agefmt;
    quit; 

	%put &=AGEFMT;

    %put &=AGEORDER;

    proc datasets nowarn noprint lib=work;
        delete _agefmt;
    quit;

    /***************************/
    /* MASTER FORMAT STATEMENT */
    /***************************/
    proc format;  

        /*Age Format*/
        value $agefmt
        &AGEFMT.;

        value $agesort
        &AGEORDER.;

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

        /* Delivery Status format */
        value $deliveryfmt
        "PRE" = "Pre-Term (0-258 days)"
        "TERM" = "Term (259-280 days)"
        "POST" = "Post-Term (281-301 days)"
        "NONE" = "Unknown Term";

        value $deliverysort
        "PRE" = 1
        "TERM" = 2
        "POST" = 3
        "NONE" = 4;

        /* Birth Type format */
        value $birthtypefmt
        "0" = "Unspecified # of live births"
        "1" = "1 live birth"
        "2" = "2 live births"
        "3" = "3 live births"
        "4" = "4 live births"
        "5" = "5 live births"
        "8" = "Multiple live births, unspecified number"
        "9" = "Conflicting code(s) for number of live births";

        value $birthtypesort
        "0" = 1
        "1" = 2
        "2" = 3
        "3" = 4
        "4" = 5
        "5" = 6
        "8" = 7
        "9" = 8;

        /* Match method format */
        value $matchfmt
        "BC" = "Birth Certificate"
        "RE" = "Birth Registry"
        "SI" = "Health plan subscriber or family number"
        "LA" = "Exact or probabilistic last name and address match based upon health plan administrative data"
        "OT" = "Other"
        "N1" = "No subscriber/family IDs available for linkage"
        "N2" = "No name/address available for linkage"
        "N3" = "Neither subscriber/family IDs nor name/address available for linkage"
        "NA" = "No linkage made; any other reasons";

        value $matchsort
        "BC" = 1
        "RE" = 2
        "LA" = 3
        "SI" = 4
        "N3" = 5
        "NA" = 6
        "N2" = 7
        "N1" = 8
        "OT" = 9;

        /* Time format */
        value $timefmt
        %do n = &look_start %to &look_end;
        "&n" = "&startdateformatted to &&enddate&n.formatted"
        %end;
        ;

        value $timesort
        %do n = &look_start %to &look_end;
        "&n" = &n
        %end;
        ;
    run;


/***************************************************************************************************
*  Create stacked dataset containing covariate labels for all runs                                              
***************************************************************************************************/

    %let MAXLEN_STUDYNAME = 0;
    /*loop through each runID, create datasets &runid._covarname*/
    %do r = 1 %to %eval(&numrunid.);
        %let runid = %scan(&runidlist., &r.);
        %if %sysfunc(exist(infolder.&&&runid._covariatecodes.))=1 %then %do;

        	/* Get studyname length per runid */
        	proc contents data = infolder.&&&runid._covariatecodes. out=studylen(keep=name length) noprint;
        	run;

            proc sql noprint;    
                create table covarname_&runid. as 
                select distinct covarnum, studyname, "&runid" as runid length=5
                from infolder.&&&runid._covariatecodes.;

               	select length
               	into: MAXLEN_STUDYNAME_&r
               	from studylen
               	where lower(name)='studyname';
            quit;

            /* Need to set maximum studyname length across all runs */
            %if &MAXLEN_STUDYNAME < &&MAXLEN_STUDYNAME_&r %then %let MAXLEN_STUDYNAME = &&MAXLEN_STUDYNAME_&r;
        %end;
    %end;

    %if %eval(&MAXLEN_STUDYNAME) > 0 %then %do;
     data covarname;
     	length studyname $&MAXLEN_STUDYNAME;
        set covarname:;
     run;
    %end;

    /*Delete temporary dataset*/
   proc datasets nowarn noprint nolist lib=work; 
        delete studylen covarname_:; 
   quit;    
   

/***************************************************************************************************
*  Create the formats for use with the Diagnosis and Procedure appendices output                                                         
***************************************************************************************************/
	proc format;
		value $pxfmt	
			"09" = "ICD-9-CM"
			"10" = "ICD-10-PCS"
			"C4" = "CPT-4"
			"HC" = "HCPCS"
			"H3" = "HCPCS"
			"C2" = "CPT-2"	
			"C3" = "CPT-3"	
			"ND" = "NDC"		
			"RE" = "RE";
		value $dxfmt
			"09" = "ICD-9-CM"
			"10" = "ICD-10-CM"; 
		value $cc1fmt
			"DX" = "Diagnosis"
			"PX" = "Procedure";
	run;
	
%mend report_formats_labels;
	
