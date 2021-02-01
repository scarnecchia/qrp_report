****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: template.sas  
*
* Created (mm/dd/yyyy): 02/01/2021
* Last modified: 02/01/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program is used to create a template for qrp reports
*  
*  Program inputs:                                                                                   
* 
*  Program outputs:    
* 
*  PARAMETERS:                                                                       
*            
*  Programming Notes:    
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

/*-----------------------------------------------------------------------------------------------------------
   Macro to create template to use in reports
  -----------------------------------------------------------------------------------------------------------*/
  %macro template;
     proc template;
     define style qrp_report;
     notes "QRP Report Style";
       style data/
          backgroundcolor = white
     	  color = black
     	  fontfamily = "Arial"
     	  fontsize = 9pt
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
     	  topmargin = 1.0in
     	  leftmargin = .5in
     	  rightmargin = .5in
     	  bottommargin = .75in
     	  ;
  	   style title /
          color = black
     	  foreground=black
     	  just = L 
          bordertopcolor=black 
          borderbottomcolor=black
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  fontfamily = "Arial"
     	  fontweight = bold
     	  fontsize = 9pt
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  frame = box
     	  ;
       style header /
          color = black
     	  foreground=black
     	  just = C 
          bordertopcolor=black 
          borderbottomcolor=black
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  fontfamily = "Arial"
     	  fontweight = bold
     	  fontsize = 9pt
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  frame = box
     	  ;
     	style footer /
          color = black
     	  fontfamily = "Arial"
     	  fontweight = bold
     	  fontsize = 9pt
     	  cellpadding =1.75pt
          backgroundcolor = white
     	  frame = void
     	  ;
      style subheader/
          color = black
     	  fontfamily = "Arial"
     	  fontweight = bold
     	  fontsize = 9pt
     	  cellpadding =1.75pt
          backgroundcolor = ligr
     	  frame = void
     	  just = L
     	  bordertopcolor=black 
          borderbottomcolor=black
     	  bordercolor = ligr
     	  borderstyle = solid
     	  borderwidth = 1pt
     	  frame = box;
     	  ;
        end;
     run;
	 
%mend template;