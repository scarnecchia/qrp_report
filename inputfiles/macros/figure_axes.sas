****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_axes.sas  
* Created (mm/dd/yyyy): 09/08/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro computes X and Y axis tick marks
* 
*  Program inputs:                                                                                   
*   - N/A
* 
*  Program outputs:                                                                                                                                       
*   - N/A
*
*  PARAMETERS:    
*   - data: figure data
*   - figure: figure #
*   - where: where clause to restrict figure data 
*   - xtickmarks: macro variable name for x tick mark list
*   - ytickmarks: macro variable name for y tick mark list
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

%macro figure_axes(data=, figure=, where=, xtickmarks=, ytickmarks=);
    
  %put =====> MACRO CALLED: figure_axes;

  	%let xmax = ;
	%let xtick = ;
	%let ymin = ;
	%let ymax = ;
	%let ytick = ;
    %let datamin= ;
    %let datamax = ;
    %let fxtickmarks = ;
    %let fytickmarks = ;

  /*select min and max day from input dataset*/
   proc sql noprint;
       select min(day), max(day) into :datamin, :datamax
       from &data(where=(&where.));
   quit;

  /*Extract axis parameters from figurefile*/
    data _null_;
        set figurefile(where=(figure="&figure."));

        /*set min/max defaults if missing*/
        if missing(xmin) then xmin = &datamin.;
        if missing(xmax) then xmax = &datamax.;

        if missing(ymin) then ymin = 0;
        if missing(ymax) then ymax = 1;

        /*set default tick if missing:
            - 6 total tick marks (min, max, and 4 interim)
            - for x axis - round to the nearest divisor of 1, 5, or 30
                           depending on length of axis                */
        if missing(xtick) then do;
            xmaxminusmin = xmax-xmin;
            if xmaxminusmin <=10 then xtick = round(xmaxminusmin/5, 1);
            else if xmaxminusmin <=120 then xtick = round(xmaxminusmin/5, 5);
            else xtick = round(xmaxminusmin/5, 30);
            if xtick = 0 then xtick = 1;
        end;
        xloopcount=round(divide(xmax-xmin,xtick))+1;

        if missing(ytick) then do;
            ymaxminusmin = ymax-ymin;
            if ymaxminusmin >.04 then ytick = round(ymaxminusmin/5, .01);
            else ytick = round(ymaxminusmin/5, .001);
            if ytick = 0 then ytick = .001;
        end;
        yloopcount=round(divide(ymax-ymin,ytick))+1;

        call symputx('xmin', xmin);
        call symputx('xmax', xmax);
        call symputx('xtick', xtick);
        call symputx('ymin', ymin);
        call symputx('ymax', ymax);
        call symputx('ytick', ytick);
        call symputx('xloopcount', xloopcount);
        call symputx('yloopcount', yloopcount);
    run;

    %put &xmin &xmax &xtick &ymin &ymax &ytick;

    %let xloop = &xmin.;
    %let yloop = &ymin.;

    /*xaxis*/
    %let axisloopcount = 1;
    %do %while(%sysevalf(&axisloopcount. <=&xloopcount.));
    %if %eval(&axisloopcount. ne &xloopcount.) %then %do;
    %let fxtickmarks = &fxtickmarks%str( )&xloop.;
    %end;
    %else %do;
    %let fxtickmarks = &fxtickmarks%str( )%sysfunc(min(&xmax.,&xloop.));
        /*Add max value if gap between last tick mark and max value is >tick/2*/
        %if %scan(&fxtickmarks., -1) ne &xmax. %then %do;
            %let diff = %sysevalf(&xmax.-%scan(&fxtickmarks., -1));
            %let div2 = %sysfunc(divide(&xtick.,2));
            %if %sysevalf(&diff.>&div2.) %then %do;
                %let fxtickmarks = &fxtickmarks%str( )&xmax.;
            %end;
        %end;
    %end;
    %let xloop=%sysevalf(&xloop + &xtick);
    %let axisloopcount = %eval(&axisloopcount+1);
    %end;
    
    /*yaxis*/
    %let axisloopcount = 1;
    %do %while(%sysevalf(&axisloopcount. <=&yloopcount.));
    %if %eval(&axisloopcount. ne &yloopcount.) %then %do;
    %let fytickmarks = &fytickmarks%str( )&yloop.;
    %end;
    %else %do;
    %let fytickmarks = &fytickmarks%str( )%sysfunc(min(&ymax.,&yloop.));
        /*Add max value if gap between last tick mark and max value is >tick/2*/
        %if %scan(&fytickmarks., -1) ne &ymax. %then %do;
            %let diff = %sysevalf(&ymax.-%scan(&fytickmarks., -1));
            %let div2 = %sysfunc(divide(&ytick.,2));
            %if %sysevalf(&diff.>&div2.) %then %do;
                %let fytickmarks = &fytickmarks%str( )&ymax.;
            %end;
        %end;
    %end;
    %let yloop=%sysfunc(round(%sysevalf(&yloop + &ytick),.001));
    %let axisloopcount = %eval(&axisloopcount+1);
    %end;    

    %let &xtickmarks = &fxtickmarks;
    %let &ytickmarks = &fytickmarks;

    %put =====> END MACRO: figure_axes;

%mend figure_axes;
