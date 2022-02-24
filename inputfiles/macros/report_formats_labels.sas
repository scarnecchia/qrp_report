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
*   -agegroupfmt
*   -sexfmt
*   -sexsort
*   -racefmt
*   -racesort
*   -hispanicfmt
*   -hispanicsort
*   -prepostindfmt
*   -prepostindsort
*   -birth_typefmt
*   -birth_typesort
*   -matchmethodfmt
*   -matchmethodsort
*   -periodidfmt
*   -periodidsort
*   -hhs_regfmt
*   -cb_regfmt
*   -monthfmt
*   -quarterfmt
*   -nafmt
*   -subgrouporderfmt
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
			output _agefmt;
            output agefmtsort; 
		end;
		drop nwordsvar nwords;
    run;

	proc sql noprint;
      select distinct label_fmt into: agegroupfmt  separated by ' '    
      from _agefmt;
    quit; 

	%put &=agegroupfmt;

    proc datasets nowarn noprint lib=work;
        delete _agefmt;
    quit;

    /***************************/
    /* MASTER FORMAT STATEMENT */
    /***************************/
    proc format;  

        /*Age Format*/
        value $agegroupfmt
        &agegroupfmt.;

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
		
		/*Zip_uncertain Format*/
        value $zip_uncertainfmt
        "Y"   = "Yes"
        "N"   = "No";

        value $zip_uncertainsort
        "Y"  = 1
        "N"  = 2
		""   = 3;
		
		value $hhs_regfmt 
        '01'='HHS Region (01)'
        '02'='HHS Region (02)'
        '03'='HHS Region (03)'
        '04'='HHS Region (04)'
        '05'='HHS Region (05)'
        '06'='HHS Region (06)'
        '07'='HHS Region (07)'
        '08'='HHS Region (08)'
        '09'='HHS Region (09)'
        '10'='HHS Region (10)'
        '11'='HHS Region (11)'
        'Invalid'='HHS Region (Invalid)'
        'Missing'='HHS Region (Missing)'
        'Other'='HHS Region (Other)';
		
		value $hhs_regsort 
        '01'=1
        '02'=2
        '03'=3
        '04'=4
        '05'=5
        '06'=6
        '07'=7
        '08'=8
        '09'=9
        '10'=10
        '11'=11
        'Invalid'=12
        'Missing'=13
        'Other'=14;

        value $cb_regfmt
        'MW' = 'Midwest'
        'NE' = 'Northeast'
        'S' = 'South'
        'W' = 'West'
        'Invalid' = 'CB Region (Invalid)'
        'Missing' = 'CB Region (Missing)'
        'Other' = 'CB Region (Other)';
         
		value $cb_regsort
        'MW' = 1
        'NE' = 2
        'S' = 3
        'W' = 4
        'Invalid' = 5
        'Missing' = 6
        'Other' = 7;
		
        /* Preterm/Postterm status format */
        value $prepostindfmt
        "PRE" = "Pre-Term (0-258 days)"
        "TERM" = "Term (259-280 days)"
        "POST" = "Post-Term (281-301 days)"
        "NONE" = "Unknown Term";

        value $prepostindsort
        "PRE" = 1
        "TERM" = 2
        "POST" = 3
        "NONE" = 4;

        /* Birth Type format */
        value $birth_typefmt
        "0" = "Unspecified # of live births"
        "1" = "1 live birth"
        "2" = "2 live births"
        "3" = "3 live births"
        "4" = "4 live births"
        "5" = "5 live births"
        "8" = "Multiple live births, unspecified number"
        "9" = "Conflicting code(s) for number of live births";

        value $birth_typesort
        "0" = 1
        "1" = 2
        "2" = 3
        "3" = 4
        "4" = 5
        "5" = 6
        "8" = 7
        "9" = 8;

        /* Match method format */
        value $matchmethodfmt
        "BC" = "Birth Certificate"
        "RE" = "Birth Registry"
        "SI" = "Health plan subscriber or family number"
        "LA" = "Exact or probabilistic last name and address match based upon health plan administrative data"
        "OT" = "Other"
        "N1" = "No subscriber/family IDs available for linkage"
        "N2" = "No name/address available for linkage"
        "N3" = "Neither subscriber/family IDs nor name/address available for linkage"
        "NA" = "No linkage made; any other reasons";

        value $matchmethodsort
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
        value $periodidfmt
        %do n = 1 %to &look_end;
        "&n" = "&startdateformatted to &&enddate&n.formatted"
        %end;
        ;

        value $periodidsort
        %do n = 1 %to &look_end;
        "&n" = &n
        %end;
        ;

        value weightdist
        .='N/A'
        .z='.'
        other=[8.3];

        value $nafmt
        ' ' = 'N/A'
        other=[$50.];

        value monthfmt 
           1='January'
           2='February'
           3='March'
           4='April'
           5='May'
           6='June'
           7='July'
           8='August'
           9='September'
          10='October'
          11='November'
          12='December'
       other='';

	   value quarterfmt 
           1='Quarter 1'
           2='Quarter 2'
           3='Quarter 3'
           4='Quarter 4'           
       other='';


        /*master order for subgroups - explicitely defined for L2s, determined by order in 
          TABLEFILE for L1s*/
        value $subgrouporderfmt
            /*1 reserved for overall*/
            'sex' = 2
            'agegroup' = 3
            'year' = 4
            'race' = 5
            'hispanic' = 6
            'prepostind' = 7
            'matchmethod' = 8
            'birth_type' = 9
            'periodid' = 10;
    run;

/***************************************************************************************************
*  Small cell count formats                                            
***************************************************************************************************/

    %if &small_cellcounts. = Y %then %let smallcellcolor = yellow;
    %else %let smallcellcolor = white;

    proc format;  
        value $backgroundfmt 
		'1'  = "&smallcellcolor."
		'2'  = "&smallcellcolor."
		'3'  = "&smallcellcolor."
		'4'  = "&smallcellcolor."
		'5'  = "&smallcellcolor."
		'6'  = "&smallcellcolor."
		'7'  = "&smallcellcolor."
		'8'  = "&smallcellcolor."
		'9'  = "&smallcellcolor."
		'10' = "&smallcellcolor.";
		
	    value background_n_fmt 
		1-10 = "&smallcellcolor.";
    run;

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
	
