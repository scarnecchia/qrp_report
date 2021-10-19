****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: include_macros.sas  
* Created (mm/dd/yyyy): 10/18/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro %includes all .sas files in a specified directory except those explicitly 
*          listed in the program.
*                                        
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*
*  PARAMETERS:	
*   - PROGRAM_DIR: location of directory containing programs to be included
* 
*  Programming Notes:     
*  This program uses the %directory_listing utility macro that creates a SAS dataset with a 
*  listing of all files and folders in a directory.
*  This utility macro have the following parameters:
* 		- PATH: unquoted full directory path
* 		- OUTDS: two-level SAS dataset name for the output table
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro include_macros(PROGRAM_DIR=);

    %put =====> MACRO CALLED: include_macros;

	%macro directory_listing(PATH=, OUTDS=);

	    %put =====> MACRO CALLED: directory_listing;

	    %local DREF DC DID OCOUNT N;

	    /* Assign fileref for the directory */
	    %let DREF=md;
	    %let DC=%sysfunc(filename(DREF,&PATH.));

	    /* Assign directory ID by opening the path as a directory */
	    %let DID=%sysfunc(dopen(&DREF));
	    
	    %put NOTE: Creating dataset &OUTDS with listing of &PATH. directory ;

	    /* Assign macro variable with the number of objects in the directory */
	    %let OCOUNT=%sysfunc(dnum(&DID));
	    
	    /* Process each object in directory D */
	    %do N=1 %to &OCOUNT;

	        %local ONAME&N O&N OREF&N RC&N OID&N ;

	        /* Assign name of the object (i.e. filename + extension) */
	        %let ONAME&N=%qsysfunc(dread(&DID,&N));

	        /* Assign full path of the object */
	        %let O&N=&PATH.%qsysfunc(dread(&DID,&N));

	        /* Assign fileref for the object */
	        %let OREF&N=md&N;
	        %let RC&N=%sysfunc(filename(OREF&N,&&O&N));

	        /* Assign object ID by opening the object as a directory.
	           This value will be used to determine whether the object is a file or a directory */
	        %let OID&N=%sysfunc(dopen(&&OREF&N));

	        /* Close the object */
	        %let RC&N=%sysfunc(dclose(&&OID&N));

	        /* Clear fileref */
	        filename md&N clear;

	    %end;

	    /* Create output table with one record per object in the directory */
	    data &OUTDS;
	        attrib directory length=$1024
	               fullname  length=$100  
	               filename  length=$100 
	               filetype  length=$9    
	               ;
	        %do N=1 %to &OCOUNT;
	            directory="&PATH";
	            fullname="&&ONAME&N";
	            filename=scan(fullname, 1, '.');
	            if &&OID&N then filetype='folder';
	            else filetype=scan(fullname, 2, '.');
	            output;
	        %end;
	    run;

	    /* Close the directory */
	    %let DC=%sysfunc(dclose(&DID));

	    /* Clear fileref */
	    filename md clear;

	    %put NOTE: ********END OF MACRO: directory_listing ********;

	%mend directory_listing;



    %local NUM_FILES F MACROFILE;

    %directory_listing(PATH=&PROGRAM_DIR, OUTDS=_PROGRAM_DIR_listing);

    data _programs;
    set _PROGRAM_DIR_listing(where=(not indexw("create_lookup.sas create_templatefiles.sas include_macros.sas", lowcase(fullname))
                                    and lowcase(filetype)="sas")) 
                             end=eof1;
    if eof1 then do;
        call symput('NUM_FILES', put(_n_,best.));
    end;
    run;

    %put NOTE: %sysfunc(compbl(&NUM_FILES)) sas files will be included;

    %do F=1 %to %sysfunc(compbl(&NUM_FILES));
        data _null_;
            set _programs (firstobs=&F obs=&F);
            call symput('MACROFILE', strip(fullname));
        run;
        
		%put ====> NOTE: Including the &MACROFILE macro program;
        %include "&PROGRAM_DIR./&MACROFILE";
    %end;

    %put NOTE: ********END OF MACRO: include_macros******** ;

%mend include_macros;
