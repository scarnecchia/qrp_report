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
*   - figure123.sas7bdat
* 
*  PARAMETERS: 
*   - N/A
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

    %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) %then %let npts = npts;
    %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) %then %let adjustedcodecount = adjustedcodecount;
    %if %sysfunc(prxmatch(m/F3/i,&figurelist.)) %then %let daysupp = daysupp;

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

        proc sort data=agg_t5first_all(where=(level="&levelid")) 
			out=_temp_figure123_&strat.(keep=group runid mntsfromstart &npts. &daysupp. &adjustedcodecount. &stratvars. 
                                             %if &figuresub. = agegroup %then %do; agegroup %end; );
			by runid group &stratvars. mntsfromstart;
		run;
			
		data figure123_&strat.;
			set _temp_figure123_&strat.;
			by runid group &stratvars. mntsfromstart;

			*Calculate cumulative values;
			%if "&stratvars." ne "" %then %do;
			if first.&stratvars. then do;
			%end;
			%if "&stratvars." = "" %then %do;
			if first.group then do;
			%end;
                %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) %then %do;
				cumulative_npts = npts;
                %end;
                %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) %then %do;
				cumulative_adjustedcodecount = adjustedcodecount;
                %end;
                %if %sysfunc(prxmatch(m/F3/i,&figurelist.)) %then %do;
				cumulative_daysupp = daysupp;
                %end;
			end;
			else do;
                %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) %then %do;
				cumulative_npts = sum(cumulative_npts, npts);
                %end;
                %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) %then %do;
				cumulative_adjustedcodecount = sum(cumulative_adjustedcodecount, adjustedcodecount);
                %end;
                %if %sysfunc(prxmatch(m/F3/i,&figurelist.)) %then %do;
				cumulative_daysupp = sum(cumulative_daysupp, daysupp);
                %end;
			end;
			retain %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) %then %do; cumulative_npts %end;
                   %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) %then %do; cumulative_adjustedcodecount %end;
                   %if %sysfunc(prxmatch(m/F3/i,&figurelist.)) %then %do; cumulative_daysupp %end; ;

			*assign stratification order. Formats applied in proc sgplot in order to print unicode characters;
            sortorder=1;
            %if &figuresub. ne overall %then %do;
                %if &figuresub. = agegroup %then %do;
                    sortorder = agegroupnum;
                %end;
                %else %do;
                    sortorder = input(put(&figuresub., &figuresub.sort.),1.);
                %end;
            %end;

            /*format for axis and legend labels*/
            %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) %then %do; 
                format cumulative_npts npts comma12.0;
                label npts ='Monthly'
                      cumulative_npts ='Cumulative';
            %end;
            %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) %then %do; 
                format cumulative_adjustedcodecount adjustedcodecount comma12.0;
                label adjustedcodecount ='Monthly'
                      cumulative_adjustedcodecount ='Cumulative';
            %end;
            %if %sysfunc(prxmatch(m/F3/i,&figurelist.)) %then %do; 
                format cumulative_daysupp daysupp comma12.0;
                label daysupp ='Monthly'
                      cumulative_daysupp ='Cumulative';
            %end;
		run;

        %if %eval(&strat.=1) %then %do;
            data figure123;
                set figure123_&strat.;
                length figuresub $10;
                figuresub = "&figuresub.";
            run;
        %end;
        %else %do;
            data figure123;
                set figure123 figure123_&strat.(in=a);
                if a then do;
                figuresub = "&figuresub.";
                end;
            run;
        %end;

    %end; /*loop through stratifications*/

    /*--------------------------------------------------------------------------------------------*/
    /* Assign group label and order                                                               */
    /*--------------------------------------------------------------------------------------------*/
    proc sql noprint undo_policy=none;
		create table figure123 as
		select x.*,
               %if &labelfileexists = Y %then %do;
               case when not missing(lbla.label) then lbla.label  
                else y.group 
                end as grouplabel length=&label_length.,
               %end;
               %else %do;
   			   y.group as grouplabel length=&label_length.,
               %end;
			   y.order
		from figure123 as x
		inner join groupsfile(where=(includeinfigure='Y')) as y
		on x.group = y.group and x.runid = y.runid
        %if &labelfileexists = Y %then %do;
        left join labelfile(where=(labeltype='grouplabel')) as lbla
        on x.group = lbla.group and x.runid = lbla.runid
        %end; 
        order by y.order, x.figuresub, x.sortorder, x.mntsfromstart;
	quit;

    proc datasets nowarn noprint lib=work;
        delete agg_t5first_all _temp_figure123_: figure123_:;
    quit;

    %end; /*agg_first exists*/

	%put =====> END MACRO: figure_t5_createdata;

%mend figure_t5_createdata;
