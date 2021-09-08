****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_t5_createdata.sas  
* Created (mm/dd/yyyy): 09/08/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Create dataset formatted to produce Figures for Type 5 report.
*
*  Program inputs:                                                                                   
*  	-agg_t5_firsteps
* 
*  Program outputs:                                                                                                                           
*   - 
* 
*  PARAMETERS: 
*   - 
*
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

%macro figure_t5_createdata();

	%put =====> MACRO CALLED: figure_t5_createdata;

    /*--------------------------------------------------------------------------------------------*/
    /* Dataset exists                                                                             */
    /*--------------------------------------------------------------------------------------------*/

    %isdata(dataset=agg_t5first);
    %if %eval(&nobs.>0) %then %do;
    
    /*--------------------------------------------------------------------------------------------*/
    /* Determine all levelIDs, metrics and stratifications requested                              */
    /*--------------------------------------------------------------------------------------------*/
    proc sql noprint;
        select distinct quote(levelid1) into :levellist separated by ','
        from figurefile(where=(figure in ('F1', 'F2', 'F3')));

        select distinct figuresub
        into :stratvars separated by ' '
        from figurefile(where=(figuresub ne 'overall' and figure in ('F1', 'F2', 'F3')));
    quit;

    /*add agegroupnum*/
    %if %index(&stratvars., agegroup)>0 and %index(&stratvars., agegroupnum)=0 %then %do;
        %let stratvars = &stratvars. agegroupnum;
    %end;

    /*F1 = npts*/ %let npts = ;
    /*F2 = adjustedcodecount*/ %let adjustedcodecount = ;
    /*F3 = daysupp*/ %let daysupp = ;

    %if %sysfunc(prxmatch(m/F1/i,&figure.)) %then %let npts = npts;
    %if %sysfunc(prxmatch(m/F2/i,&figure.)) %then %let adjustedcodecount = adjustedcodecount;
    %if %sysfunc(prxmatch(m/F3/i,&figure.)) %then %let daysupp = daysupp;

    /*--------------------------------------------------------------------------------------------*/
    /* Aggregate data across all DPs                                                              */
    /*--------------------------------------------------------------------------------------------*/

	proc means data=agg_t5first(where=(level in (&levellist.))) noprint nway;
		var &npts. &daysupp. &adjustedcodecount.;
		class group runid level mntsfromstart &stratvars. / missing;
		output out=agg_t5first_all(drop=_:) sum=;
	run;




    proc datasets nowarn noprint lib=work;
        delete agg_t5first_all;
    quit;

    %end;

	%put =====> END MACRO: figure_t5_createdata;

%mend figure_t5_createdata;
