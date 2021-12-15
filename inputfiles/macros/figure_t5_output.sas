****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_t5_output.sas  
* Created (mm/dd/yyyy): 09/08/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Produce type 5 figures F1-F3
*
*  Program inputs:                                                                                   
*  	- figure123.sas7bdat
* 
*  Program outputs:                                                                                                                           
*   - N/A
* 
*  PARAMETERS: 
*   -figure: figure
*   -figurenum: figure number for report
*   -figureletter: figure letter for report
*   -title: figure title
*   -where: where clause to restrict figure123.sas7bdat
*   -figuresub: row in figurefile to produce table
*   -yaxislabel1: Label for primary Y axis
*   -yaxislabel2: Label for secondary Y axis
*   -yvar: variable to use in plot
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

%macro figure_t5_output(figure=, figurenum=, figureletter=, title=, where=, figuresub=, yaxislabel1=, yaxislabel2=, yvar=);

	%put =====> MACRO CALLED: figure_t5_output;

    /*figuresub format to display formatted values in figure*/
    %if &figuresub. ne overall %then %do;
        %let t5figureformat = $&figuresub.fmt.; %end; 
    %end;

    /*footnotes*/
    %if &collapse_vars = race & &figuresub. = race %then %do;
		data _footnotes;
            length footnote_order 3; 
            set lookup.lookup_footnotes(where = (type = "t5tablefig"));
            by order;
            footnote_order = _n_;
            call symputx('num_fn', 1);
        run;

        proc sql noprint;
            select description into: fn1 - :fn&num_fn.
            from _footnotes
            order by order;
        quit;

        %assign_superscripts(type=raceunknown, order = 2);
        %let unicode_forplot = %scan(&unicode_list., 1);

        /*modify format*/
        proc format;
        value $racefmtsuper
        "0"   = "Unknown(*ESC*){unicode '&unicode_forplot'x}"
        "1"   = "American Indian or Alaska Native"
        "2"   = "Asian"
        "3"   = "Black or African American"
        "4"   = "Native Hawaiian or Other Pacific Islander"
        "5"   = "White";
        run;
        %let t5figureformat = $racefmtsuper.;
    %end;

    /*Save dataset to REPORTDATA folder*/
    %isdata(dataset=repdata.figure&figurenum.&figureletter.);
    %if %eval(&nobs.<1) %then %do;
        data repdata.figure&figurenum.&figureletter.;
            set figure123(where=(&where.));
        run;
    %end;

    /*stratified plot - collapse strata to determine correct Y axis*/
    %let axisdata = repdata.figure&figurenum.&figureletter.;
    %if &figuresub. ne overall %then %do;
        proc sql noprint;
            create table _collaspseddata as
            select mntsfromstart, sum(&yvar.) as &yvar.
            from repdata.figure&figurenum.&figureletter.
            group by mntsfromstart;
        quit;
        %let axisdata = _collaspseddata;
    %end;

	/* Obtain y axis values */
    %let t5ytickmarks = ;

    /*assign axes - compute Y axis and maximum month for xaxis*/
    %figure_axes(data=&axisdata., figure=&figure., figuresub=&figuresub., where=1 , xtickmarks=, xvar=, ytickmarks=t5ytickmarks, yvar=&yvar.);

    proc sql noprint;
       select max(mntsfromstart) into :datamax
       from &axisdata.;
    quit;

    proc datasets nowarn noprint lib=work;
        delete _collaspseddata _footnotes;
    quit;

	ods startpage = now;
  	ods startpage = no;
  	ods graphics / height=7in;

	/* Trick Excel into making a new sheet */
	%if &destination. = excel %then %do;
            ods excel options(sheet_interval="table");
            ods exclude all;
            data _null_;
            file print;
            put _all_;
            run;
            ods select all;
	%end;

    %if &destination. = excel %then %do;
        ods excel options(sheet_interval="none" sheet_name = "Figure &figurenum.&figureletter." tab_color="blue" flow='none');
    %end;

    %if &destination. = pdf %then %do;
	ODS PDF BOOKMARKGEN = ON; 
	ods proclabel = "Figure &figurenum.&figureletter.";
	%end;

    proc odstext;
		p "Figure &figurenum.&figureletter.. &title" / style=[just=L backgroundcolor=white font_weight=bold bordertopcolor=black borderbottomcolor=black tagattr='mergeacross:18'];
	run;

	%if &destination. = pdf %then %do;
	ODS PDF BOOKMARKGEN = OFF;   
	%end;

	proc sgplot data=repdata.figure&figurenum.&figureletter. noborder;
        /*styleattrs applied to plot with group= statement - overall plot colors applied in vbar/vline statement*/
		styleattrs datacontrastcolors=(DarkBlue DarkGreen DarkPurple DarkRed DarkOrange Black DarkBrown Magenta 
									  Yellow Skyblue Chartreuse Pink Maroon Grey LightPurple Tomato Olive Aqua 
									  LightRed GreenYellow DarkSlateGray DarkCyan Violet Goldenrod MediumAquamarine)
                   datacolors=(DarkBlue DarkGreen DarkPurple DarkRed DarkOrange Black DarkBrown Magenta 
									  Yellow Skyblue Chartreuse Pink Maroon Grey LightPurple Tomato Olive Aqua 
									  LightRed GreenYellow DarkSlateGray DarkCyan Violet Goldenrod MediumAquamarine);
        /*assign labels*/
        %if &figuresub. ne overall %then %do;
            format &figuresub. &t5figureformat. ;
        %end;
        vbar mntsfromstart / response=&yvar. %if &figuresub. ne overall %then %do; group=&figuresub. grouporder=data stat = sum %end; nostatlabel name='raw' missing 
             fillattrs=(transparency=.4 %if &figuresub. = overall %then %do; color=darkblue %end;)
             %if &figuresub. = overall %then %do; outlineattrs=(color=darkblue) %end; ;
		vline mntsfromstart / response=cumulative_&yvar. %if &figuresub. ne overall %then %do; group=&figuresub. grouporder=data stat = sum %end; name='cumulative' missing y2axis markers 
             lineattrs=(pattern=solid thickness=2 %if &figuresub. = overall %then %do; color=darkblue %end;)
             %if &figuresub. = overall %then %do; markerfillattrs=(color=darkblue) markerattrs=(color=darkblue) %end; ;
        xaxis label = "Months after Study Start" values=(1 to &datamax. by 1) fitpolicy=thin valueattrs=(color=black size=&fontsize. family=&font.) 
             labelattrs=(color=black size=&fontsize family=&font) ; 
		yaxis label = "&yaxislabel1" values=(&t5ytickmarks.) valueattrs=(color=black size=&fontsize. family=&font.) labelattrs=(color=black size=&fontsize family=&font);
        y2axis label = "&yaxislabel2" valueattrs=(color=black size=&fontsize. family=&font.) labelattrs=(color=black size=&fontsize family=&font);
		keylegend 'raw' 'cumulative' / valueattrs=(size=&footfontsize family=&font) across=3 position=bottom noborder linelength=.25in;
    run;

    /*Footnotes*/
    %if &collapse_vars = race & &figuresub. = race %then %do;
	   proc odstext;
		%do fnote = 1 %to &num_fn.;
        p "^{super &fnote.}&&fn&fnote." / style=[just=L font_size=&footfontsize];
		%end;
		run; 
    %end;
	
	%if &destination. = pdf %then %do;
	ODS PDF BOOKMARKGEN = ON;
	%end; 

	%put =====> END MACRO: figure_t5_output;

%mend figure_t5_output;
