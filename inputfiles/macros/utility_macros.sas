
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