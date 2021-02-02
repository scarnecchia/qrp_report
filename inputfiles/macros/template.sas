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
     %macro template_source (outputtype = ,fontsize = , font =);
         proc template;
         define style qrp_report_&outputtype.;
         notes "QRP Report Style";
           style data/
              backgroundcolor = white
         	  color = black
         	  fontfamily = "&font."
         	  fontsize = &fontsize.
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
              bordertopcolor=black 
              borderbottomcolor=black
         	  bordercolor = ligr
         	  borderstyle = solid
         	  borderwidth = 1pt
         	  fontfamily = "&font."
         	  fontweight = bold
         	  fontsize = &fontsize.
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
         	  fontsize = &fontsize.
         	  cellpadding =1.75pt
              backgroundcolor = white
         	  frame = box
         	  just = C 
         	  ;
         	style footer /
              color = black
         	  fontfamily = "&font."
         	  fontweight = bold
         	  fontsize = &fontsize.
         	  cellpadding =1.75pt
              backgroundcolor = white
         	  frame = void
         	  just = L 
         	  ;
          style subheader/
              color = black
         	  fontfamily = "&font."
         	  fontweight = bold
         	  fontsize = &fontsize.
         	  cellpadding =1.75pt
              backgroundcolor = ligr
         	  frame = void
         	  bordertopcolor=black 
              borderbottomcolor=black
         	  bordercolor = ligr
         	  borderstyle = solid
         	  borderwidth = 1pt
         	  frame = box;
         	  just = L
         	  ;
            end;
         run;
	%mend template_source;
	%if %str("&sysscp.") = %str("WIN") %then %do;
	  %template_source (outputtype = excel, fontsize = 10pt, font = Calibri); 
	%end;
	%else %do;
	  %template_source (outputtype = excel, fontsize = 9pt, font = Arial); 
	%end;
	%template_source (outputtype = pdf, fontsize = 8pt, font= Arial); 
	
%mend template;