/* jenner-check bundle autoexec: cap rows and define the utility macros used    */
/* by this bundle, taken from inputfiles/macros/utility_macros.sas.             */
options obs=100;

/* %isdata: returns NLOBS of a dataset in &NOBS (0 if empty or absent). */
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
