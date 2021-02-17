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
*   - %tableletter() macro increments a letter suffix
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

*Macro for incrementing table/figure letter suffix;
%macro tableletter();
  %if %eval(&tablecount = 0) %then %do;
    %let tableletter = ;
  %end;
  %else %do;
      %if %eval(%sysfunc(mod(&tablecount.,26))=0) %then %do;
        %let div = %eval((&tablecount. / 26)-1); %put &div.;
        %let secondplace = %eval(&tablecount - (26*&div));%put &secondplace.;
      %end; 
      %else %do;
        %let div = %sysfunc(int(&tablecount. / 26)); %put &div.;
        %let secondplace = %eval(&tablecount - (26*&div));%put &secondplace.;
      %end;

      %if %eval(&div = 0) %then %do;
        %let tableletter = %scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &tablecount.);
      %end;
      %else %do;
        %let tableletter = %scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &div.)%scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &secondplace);
      %end;
  %end;

  %put tableletter = &tableletter.;
  %let tablecount = %eval(&tablecount + 1); /*+1 to counter*/
%mend;
