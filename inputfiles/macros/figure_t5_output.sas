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
        delete _collaspseddata;
    quit;

	ods startpage = now;
  	ods startpage = no;
  	ods graphics / height=7in;

	proc template;
	 define style styles.blackLine;
	 parent= styles.htmlblue;
	 class GraphAxisLines/
	   contrastcolor = black
	   color = black
	   ;end; run;

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
        ods excel options(sheet_interval="none" sheet_name = "Figure &figurenum." tab_color="blue" flow='none') style = styles.blackLine;
    %end;

    %if &destination. = pdf %then %do;
	ODS PDF BOOKMARKGEN = ON; 
	ods proclabel = "Figure &figurenum.&figureletter.";
	%end;

    proc odstext;
		p "Figure &figurenum.&figureletter.. &title" / style=[just=L font_weight=bold bordertopcolor=black borderbottomcolor=black tagattr='mergeacross:18'];
	run;

	%if &destination. = pdf %then %do;
	ODS PDF BOOKMARKGEN = OFF;   
	%end;

	proc sgplot data=repdata.figure&figurenum.&figureletter. noborder;
		styleattrs datacontrastcolors=(DarkBlue DarkGreen DarkPurple DarkRed DarkOrange Black DarkBrown Magenta 
									  Yellow Skyblue Chartreuse Pink Maroon Grey LightPurple Tomato Olive Aqua 
									  LightRed GreenYellow DarkSlateGray DarkCyan Violet Goldenrod MediumAquamarine);
        /*assign labels*/
        %if &figuresub. ne overall %then %do;
            format &figuresub. %if &figuresub.=agegroup %then %do; $agefmt. %end; %else %do; $&figuresub.fmt. %end; ;
        %end;
        vbar mntsfromstart 
             / response=&yvar. %if &figuresub. ne overall %then %do; group=&figuresub. grouporder=data stat = sum %end; nostatlabel name='raw' missing ;
		vline mntsfromstart
            / response=cumulative_&yvar. %if &figuresub. ne overall %then %do; group=&figuresub. grouporder=data stat = sum %end; name='cumulative' missing y2axis markers lineattrs=(pattern=solid thickness=2);
        xaxis label = "Months after Study Start" values=(1 to &datamax. by 1) fitpolicy=thin valueattrs=(color=black size=&fontsize. family=&font.) 
             labelattrs=(color=black size=&fontsize family=&font) ; 
		yaxis label = "&yaxislabel1" values=(&t5ytickmarks.) valueattrs=(color=black size=&fontsize. family=&font.) labelattrs=(color=black size=&fontsize family=&font);
        y2axis label = "&yaxislabel2" valueattrs=(color=black size=&fontsize. family=&font.) labelattrs=(color=black size=&fontsize family=&font);
		keylegend 'raw' 'cumulative' / valueattrs=(size=&footfontsize family=&font) across=3 position=bottom noborder linelength=.25in;
    run;
	
	%if &destination. = pdf %then %do;
	 ODS PDF BOOKMARKGEN = ON;
	%end; 

	%put =====> END MACRO: figure_t5_output;

%mend figure_t5_output;

