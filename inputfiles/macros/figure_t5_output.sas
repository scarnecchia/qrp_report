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

%macro figure_t5_output(figure=, figurenum=, title=, where=, figuresub=, yaxislabel1=, yaxislabel2=, yvar=);

	%put =====> MACRO CALLED: figure_t5_output;

    /*Save dataset to REPORTDATA folder*/
    %isdata(dataset=repdata.figure&tablenum.);
    %if %eval(&nobs.<1) %then %do;
        data repdata.figure&tablenum.;
            set figure123(where=(&where.));
        run;
    %end;

    /*assign axes*/
    %let t5xtickmarks = ;
    %let t5ytickmarks = ;

    %figure_axes(data=repdata.figure&tablenum., figure=&figure., figuresub=&figuresub., where=&where., xtickmarks=t5xtickmarks, ytickmarks=t5ytickmarks);

	ods startpage = now;
  	ods startpage = no;
  	ods graphics / height=7.5in;

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
        ods excel options(sheet_interval="none" sheet_name = "Figure &figurenum." tab_color="blue" flow='none');
    %end;

    %if &destination. = pdf %then %do;
	ODS PDF BOOKMARKGEN = ON; 
	ods proclabel = "Figure &figurenum.";
	%end;

    proc odstext;
		p "Figure &figurenum.. &title" / style=[just=L font_weight=bold bordertopcolor=black borderbottomcolor=black tagattr='mergeacross:18'];
	run;

	%if &destination. = pdf %then %do;
	ODS PDF BOOKMARKGEN = OFF; 
	%end;

    /*proc sgplot*/
/*	proc sgplot data=repdata.Figure&figurenum. noborder;*/
/*		styleattrs datacontrastcolors=(DarkBlue DarkGreen DarkPurple DarkRed DarkOrange Black DarkBrown Magenta */
/*									  Yellow Skyblue Chartreuse Pink Maroon Grey LightPurple Tomato Olive Aqua */
/*									  LightRed GreenYellow DarkSlateGray DarkCyan Violet Goldenrod MediumAquamarine);*/
/**/
/*		series x= mntsfromstart y=&yvar. / name='raw' lineattrs=(pattern=solid thickness=2);*/
/*        vbar mntsfromstart / reponse=cumulative_&yvar. nostatlabel / name=cumulative;*/
/*        xaxis label = "Months since Study Start" values=(&t5xtickmarks) valueattrs=(size=&fontsize. family=&font.) labelattrs=(size=&fontsize family=&font); */
/*		yaxis label = "&yaxislabel" values=(&t5ytickmarks) valueattrs=(size=&fontsize. family=&font.) labelattrs=(size=&fontsize family=&font);*/
/*        y2axis */
/*		keylegend 'raw' 'cumulative' / valueattrs=(size=&footfontsize family=&font) across=3 position=bottom noborder linelength=.25in;*/
/**/
/*    run;*/
/**/
/*    %let fontsize = 8;*/
/*    %let font = calibri;*/
/*    %let footfontsize = 7;*/
/**/
/*	proc sgplot data=one noborder;*/
/*		styleattrs datacontrastcolors=(DarkBlue DarkGreen DarkPurple DarkRed DarkOrange Black DarkBrown Magenta */
/*									  Yellow Skyblue Chartreuse Pink Maroon Grey LightPurple Tomato Olive Aqua */
/*									  LightRed GreenYellow DarkSlateGray DarkCyan Violet Goldenrod MediumAquamarine);*/
/**/
/*        vbar mntsfromstart / response=cumulative_npts nostatlabel name='cumulative' y2axis;*/
/*		vline mntsfromstart / response=npts name='raw' lineattrs=(pattern=solid thickness=2);*/
/*        xaxis label = "Months since Study Start" valueattrs=(size=&fontsize. family=&font.) labelattrs=(size=&fontsize family=&font); */
/*		yaxis label = "Monthly number of patients" values=(0 20 40 60 80) valueattrs=(size=&fontsize. family=&font.) labelattrs=(size=&fontsize family=&font);*/
/*        y2axis label = "Cumulative number of patients in study" values=(0 200 400 600 800 1200 1500) valueattrs=(size=&fontsize. family=&font.) labelattrs=(size=&fontsize family=&font);*/
/*		keylegend 'raw' 'cumulative' / valueattrs=(size=&footfontsize family=&font) across=3 position=bottom noborder linelength=.25in;*/
/**/
/*    run;*/
/*	*/
	%if &destination. = pdf %then %do;
	 ODS PDF BOOKMARKGEN = ON;
	%end; 

	%put =====> END MACRO: figure_t5_output;

%mend figure_t5_output;
