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

	/* Transform the node variable of &lookupfile into a parent/child structure */
	data &outfile.;
	format child parent $14.;
	set &lookupfile.;
	do i = 1 to level;
		child=node;
		last_dot = length(node) - length(scan(node, -1, '.'));
		parent=substr(node,1,last_dot-1);
		if child=parent then parent="";
		nodelength=length(node);
		output;
		node=parent;
	end;
	keep nodelength child parent;
	run;

	proc sort nodupkey data=&outfile. out=&outfile.(drop=nodelength);
	by descending nodelength child parent;
	run;

	%put =====> END MACRO: collapse_expanded_tree;

%mend collapse_expanded_tree;
