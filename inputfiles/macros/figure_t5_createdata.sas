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

        select distinct figuresub into :figuresublist separated by ' '
        from figurefile(where=(figure in ('F1', 'F2', 'F3')));
    quit;

    /*define stratification variables for class statement*/
    %let stratvars = &figuresublist.;
    %if %index(&stratvars., agegroup)>0 %then %let stratvars = &stratvars. agegroupnum;
    %if %index(&stratvars., overall)>0 %then %let stratvars = %sysfunc(tranwrd(&stratvars.,overall, %str())) ;

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

    /*--------------------------------------------------------------------------------------------*/
    /* Loop through each FigureSub                                                                */
    /*--------------------------------------------------------------------------------------------*/

    %do strat = 1 %to %sysfunc(countw(&figuresublist.));
        %let figuresub=%scan(&figuresublist., &strat.);
				
		/*reset macro vars*/
		%let levelid = ;
        %let stratvars = ;

        %if %str(&figuresub.) ne %str(overall) %then %do;
            %let stratvars = &figuresub.;
            %if &figuresub. = agegroup %then %let stratvars = agegroupnum;
        %end;

		data _null_;
 			set figurefile(where=(figuresub="&figuresub." and figure in ('F1', 'F2', 'F3')));
			if _n_ = 1 then do; /*same values for all figures*/
	        call symputx('levelid', levelid1);
			end;
		run;

        proc sort data=agg_t5first_all(where=(level="&levelid" and mntsfromstart >=0)) 
			out=_temp_figure123_&strat.(keep=group runid mntsfromstart &npts. &daysupp. &adjustedcodecount. &stratvars. 
                                             %if &figuresub. = agegroup %then %do; agegroup %end; );
			by runid group &stratvars. mntsfromstart;
		run;
			
		data output.figure123_&strat.;
			set _temp_figure123_&strat.;
			by runid group &stratvars. mntsfromstart;

			*Calculate cumulative values;
			%if "&stratvars." ne "" %then %do;
			if first.&stratvars. then do;
			%end;
			%if "&stratvars." = "" %then %do;
			if first.group then do;
			%end;
                %if %sysfunc(prxmatch(m/F1/i,&figure.)) %then %do;
				cumulative_npts = npts;
                %end;
                %if %sysfunc(prxmatch(m/F2/i,&figure.)) %then %do;
				cumulative_adjustedcodecount = adjustedcodecount;
                %end;
                %if %sysfunc(prxmatch(m/F3/i,&figure.)) %then %do;
				cumulative_daysupp = daysupp;
                %end;
			end;
			else do;
                %if %sysfunc(prxmatch(m/F1/i,&figure.)) %then %do;
				cumulative_npts = sum(cumulative_npts, npts);
                %end;
                %if %sysfunc(prxmatch(m/F2/i,&figure.)) %then %do;
				cumulative_adjustedcodecount = sum(cumulative_adjustedcodecount, adjustedcodecount);
                %end;
                %if %sysfunc(prxmatch(m/F3/i,&figure.)) %then %do;
				cumulative_daysupp = sum(cumulative_daysupp, daysupp);
                %end;
			end;
			retain %if %sysfunc(prxmatch(m/F1/i,&figure.)) %then %do; cumulative_npts %end;
                   %if %sysfunc(prxmatch(m/F2/i,&figure.)) %then %do; cumulative_adjustedcodecount %end;
                   %if %sysfunc(prxmatch(m/F3/i,&figure.)) %then %do; cumulative_daysupp %end; ;


/*			*assign label;*/
/*			%if "&stratvars." = "sex" %then %do;*/
/*				if &stratvars. = 'F' then label = 'Female';*/
/*				if &stratvars. = 'M' then label = 'Male'; */
/*				if &stratvars. = 'O' then label = 'Other';*/
/*			%end;*/
/*			%if "&stratvars." = "agegroup" %then %do;*/
/*				label = agegroup;*/
/*			%end;*/
/*			%if "&stratvars." = "race" %then %do;*/
/*				if &stratvars. = '0' then label = 'Unknown';*/
/*				if &stratvars. = '1' then label = 'American Indian/Alaska Native';*/
/*				if &stratvars. = '2' then label = 'Asian';*/
/*				if &stratvars. = '3' then label = 'Black/African American';*/
/*				if &stratvars. = '4' then label = 'Native Hawaiian/Other Pacific Islander';*/
/*				if &stratvars. = '5' then label = 'White';*/
/*				%end;*/
/*			%if "&stratvars." = "hispanic" %then %do;*/
/*				if &stratvars.= 'N' then label = 'Not Hispanic Origin';*/
/*				if &stratvars. = 'Y' then label = 'Hispanic Origin';*/
/*				if &stratvars. = 'U' then label = 'Unknown';*/
/*			%end;*/
		run;


    %end; /*loop through stratifications*/

    proc datasets nowarn noprint lib=work;
        delete agg_t5first_all _temp_figure123_:;
    quit;

    %end;

	%put =====> END MACRO: figure_t5_createdata;

%mend figure_t5_createdata;
