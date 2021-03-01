****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: report_template.sas  
*
* Created (mm/dd/yyyy): 02/01/2021
* Last modified: 02/01/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program is used to create a template for qrp reports using proc template
*  
*  Program inputs:                                                                                   
* 
*  Program outputs:    
*   -template named qrp_report_&outputtype.
* 
*  PARAMETERS:
*   - outputtype: The file type the template will be used for (ex: Excel)
*   - fontsize: The size of the font
*   - font: The font family                                                                    
*            
*  Programming Notes:    
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

/*-------------------------------------------------------------------------------------------------
   Macro to create template to use in reports
--------------------------------------------------------------------------------------------------*/

 %macro report_template(outputtype = ,tablefontsize = , footfontsize=, font =);

    proc template;
        define style qrp_report_&outputtype.;
        notes "QRP Report Style";
		%if %str("&outputtype.") = %str("excel") %then %do;
		  parent = styles.Excel;
		%end;
		%else %do;
		  parent = styles.Pearl;
		%end;
        style data/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &tablefontsize.
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  cellpadding =1.75pt
     	  frame = box
  	      just = C
     	  ;
        style body/
          backgroundcolor = white
     	  frame = void
     	  ;
  	     style title /
          color = black
     	  foreground=black
          bordertopcolor=black 
          borderbottomcolor=black
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &tablefontsize.
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  frame = box
     	  just = L 
     	  ;
        style header /
          color = black
     	  foreground=black
          bordertopcolor=black 
          borderbottomcolor=black
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &tablefontsize.
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  frame = box
     	  just = C 
     	  ;
     	style footer /
          color = black
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &footfontsize.
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  frame = void
     	  just = L 
     	  ;
        style subheader/
          color = black
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &tablefontsize.
     	  cellpadding =1.75pt
          backgroundcolor = ligr
     	  frame = void
     	  bordertopcolor=black 
          borderbottomcolor=black
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  frame = box
     	  just = L
     	  ;
		style systemtitle/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &tablefontsize.
		  fontweight = bold
     	  cellpadding =1.75pt
     	  frame = void
  	      just = L
     	  ;
		style linecontent/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &tablefontsize.
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  cellpadding =1.75pt
     	  frame = box
  	      just = L
     	  ;
		style paragraph/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &footfontsize.
     	  cellpadding =1.75pt
     	  frame = void
  	      just = L
     	  ;
		style note/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &footfontsize.
		  fontweight = bold
     	  cellpadding =1.75pt
     	  frame = void
  	      just = L
     	  ;
        end;
    run;

%mend report_template;
