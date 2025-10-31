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
* PURPOSE: This program is used to create a template for qrp report outputs
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

 %macro report_template(outputtype = ,fontsize = , font =);

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
		  cellpadding =1.75pt
		  color = black
		  fontfamily = "&font."
		  fontsize = &fontsize.
		  borderstyle = hidden
		  borderwidth = 1pt
		  frame = void
		  just = C
		  ;
		style header /
          color = black
     	  foreground = black
		  bordertopcolor = black
          borderbottomcolor = black
		  borderleftcolor = white
		  borderrightcolor = white
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &fontsize.
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  just = C 
		  frame = hsides
     	  ;
		style linecontent/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &fontsize.
		  bordertopcolor = black
          borderbottomcolor = black
		  borderleftcolor = white
		  borderrightcolor = white
     	  borderstyle = solid
		  borderwidth = 1pt
     	  cellpadding =1.75pt
  	      just = L
		  frame = hsides
     	  ;
        style body/
          backgroundcolor = white
		  borderstyle = hidden
		  borderwidth = 1pt
		  fontfamily = "&font."
		  fontsize = &fontsize.
		  frame = void
     	  ;
  	     style title /
          color = black
     	  foreground = black
          borderbottomcolor = black
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &fontsize.
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  just = L 
		  frame = void
     	  ;
     	style footer /
          color = black
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &fontsize.
     	  cellpadding =1.75pt
          backgroundcolor = white
		  bordertopcolor = black
		  borderwidth = 2pt
     	  just = L 
		  frame = void
     	  ;
        style subheader/
          color = black
     	  fontfamily = "&font."
     	  fontweight = bold
     	  fontsize = &fontsize.
     	  cellpadding =1.75pt
          backgroundcolor = liggr
          borderbottomcolor = black
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  just = L
		  frame = void
     	  ;
		style systemtitle/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &fontsize.
		  fontweight = bold
     	  cellpadding =1.75pt
  	      just = L
		  frame = void
     	  ;
		style paragraph/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &fontsize.
     	  cellpadding =1.75pt
  	      just = L
		  frame = void
     	  ;
		style note/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "&font."
     	  fontsize = &fontsize.
		  fontweight = bold
     	  cellpadding =1.75pt
  	      just = L
		  frame = void
     	  ;

        class GraphAxisLines/
		   contrastcolor = black
		   color = black;
		end;
    run;

%mend report_template;
