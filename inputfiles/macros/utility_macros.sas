****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: utility_macros.sas  
*
* Created (mm/dd/yyyy): 12/20/2015
* Last modified: 12/1/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program includes the following macros:
*   - %isdata() macro determines whether a dataset is empty or not
*   - %create_comma_charlist() macro converts space delimited list to comma delimited list with quotes
*   - %alphabetizevarutil() macro alphabetizes variables in a data step
*
*  Program inputs:                                                                                   
*   -
* 
*  Program outputs:                                                                                                                                       
*   -
* 
*  PARAMETERS:                                                                       
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

*Macro to determine whether a dataset is empty or not;
%MACRO ISDATA(dataset=);
    %GLOBAL NOBS;
    %let NOBS=0;
    %if %sysfunc(exist(&dataset.))=1 and %LENGTH(&dataset.) ne 0 %then %do;
        data _null_;
        dsid=open("&dataset.");
        call symputx("NOBS",attrn(dsid,"NLOBS"));
        run;
    %end;   
%PUT &NOBS.;
%MEND ISDATA;

*Macro for converting macro variable with space deliminated list to comma deliminated list with quotation around each word;
%macro create_comma_charlist(inlist=, outlist=);
  %global &outlist.;

  %let countvars = %sysfunc(Countw(%quote(&inlist.), ' '));
    %do c = 1 %to &countvars.;
      %let word = %scan(%quote(&inlist),&c., ' ');
        %if &c. = 1 %then %do;
          %let &outlist. = "&word.";
        %end;
        %else %do;
          %let &outlist. = &&&outlist. , "&word.";
        %end;
    %end;
  %let &outlist = %upcase(&&&outlist);
%mend create_comma_charlist;

*Macro to alphabetize variables in a data step;
%macro alphabetizevarutil(array=, in=, out=);
    array &array.[10] $50 _temporary_;
      call missing(of &array.[*]);
       do i = 1 to dim(&array.) until(p eq 0);
        call scan(&in.,i,p,l);
          &array.[i] = substrn(&in.,p,l);
    end;
    call sortc(of &array.[*]);
    length &out. $100;
    &out. = catx(' ',of &array.[*]);
    drop i p l &in.;
%mend;
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