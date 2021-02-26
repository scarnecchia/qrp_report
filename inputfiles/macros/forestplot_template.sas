****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: forestplot_template.sas  
*
* Created (mm/dd/yyyy): 02/23/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Outputs formatted forest plots
*                                       
*  Program inputs:                                                                                   
*   -[runid]_forest
* 
*  Program outputs:                                                                                                                                       
*   -
* 
*  PARAMETERS:
*  plotheight - Specifies height of forest plot                                                                       
*            
*  Programming Notes:                                                                                
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
*--------------------------------------------------------------------------------------------------
***************************************************************************************************;

%macro forestplot_template(plotheight=, pointest=, lowerci=, upperci=, ci95=, cilabel=);

ods path(prepend) work.templat(update);

proc template;
    define statgraph forestAxisTable;
    dynamic _headerColor;
    begingraph / designheight=&plotheight designwidth=7in;

    discreteattrmap name='text' / trimleading=true;
    value '1' / textAttrs=(size=7 weight=bold family="arial");
    value '2' / textAttrs=(size=7 weight=normal family="arial");
    value '3' / textAttrs=(size=7 weight=normal family="arial");
    enddiscreteattrmap;

    discreteattrvar attrvar=txtDAV var=id attrmap='text';

    layout lattice / columns=1;

    /*--Column headers--*/
    /*--Need to make proportional to table size - or add header to table?*/
    sidebar / align=top;
    layout lattice / columns=2 rowweights=uniform columnweights=(0.6 .4)
    backgroundcolor=_headerColor opaque=true;
    entry textAttrs=(size=7 weight=bold family="arial") hAlign=left "Analysis";
    endLayout;
    endsidebar;

    /* Single cell with inner margins for left and right tables */
    layout overlay / xAxisOpts=(label="&cilabel" type=log display=(line ticks tickvalues label)
    tickValueAttrs=(size=8 weight=bold)
    labelAttrs=(size=8 weight=bold)
    offsetMin=0.1
    lineextent=data)
    yAxisOpts=(reverse=true display=none) wallDisplay=none;

    /* Odds Ratio plot */
    /*    referenceLine y=ref / lineAttrs=(thickness=15 color=_bandColor);*/
    scatterPlot y=obsId x=&pointest / markerAttrs=(symbol=squareFilled color=black)
    xErrorLower=&lowerci xErrorUpper=&upperci errorBarCapShape=none errorbarattrs=(color=black);
    referenceLine x=1;

    /* Right-side table */
    innerMargin / align=left gutter=0.1in;
    axisTable y=obsId value=title / textGroup=txtDAV
    indentWeight=indentwt display=(values);
    endInnerMargin;
    innerMargin / align=right gutter=0.1in;
    axisTable y=obsId value=&ci95 / display=(values);
    endInnerMargin;

    endLayout; /* overlay */

endLayout; /* lattice */
endgraph;
end;
run;

%mend forestplot_template;
