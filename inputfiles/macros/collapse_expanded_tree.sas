****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: collapse_expanded_tree.sas  
* Created (mm/dd/yyyy): 09/23/2024
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro transforms and manipulates attrition table data to be output
*                                        
*  Program inputs:                                                                                   
*   - expanded tree lookup file
* 
*  Program outputs: 
*	- collapsed tree lookup file 
* 
* 
*  PARAMETERS:    
*   - lookupfile = expanded tree lookup file
*   - outfile  = collapsed tree lookup file with parent/child structure
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

%macro collapse_expanded_tree(lookupfile=, outfile=);

	%put =====> MACRO CALLED: collapse_expanded_tree;

	/* Transform the expanded tree variable of &lookupfile into a parent/child structure */
	proc sql noprint;
		select max(level) into: maxlevel
		from &lookupfile.;
	quit;

	/*level 1 is child without parent*/
	proc sql noprint;
		create table level1 as
		select distinct node as child
		from &lookupfile.(keep=node level where=(level=1));
	quit;

	/*Loop through each level to obtain paired child/parent*/
	%do i = 2 %to %eval(&maxlevel.);
		proc sql noprint;
			create table level&i. as
			select distinct x.node as child,
				  		    y.node as parent
			from &lookupfile.(where=(level=&i.)) as x
			inner join &lookupfile.(where=(level=%eval(&i.-1))) as y
			on x.code =y.code and x.codetype = y.codetype and x.codecat = y.codecat;
		quit;
	%end;

	/*stack*/;
	data &outfile.;
		set %do i= %eval(&maxlevel.) %to 1 %by -1;
			level&i.
			%end;
			;
	run;

	proc datasets nowarn noprint lib=work;
		delete level:;
	quit;

	%put =====> END MACRO: collapse_expanded_tree;

%mend collapse_expanded_tree;
