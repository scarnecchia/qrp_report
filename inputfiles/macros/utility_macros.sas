****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: utility_macros.sas  
*
* Created (mm/dd/yyyy): 12/20/2015
* Last modified: 06/30/2019
* Version: 1.2
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This program includes two macros:
*   - %isdata() macro determines whether a dataset is empty or not
*   - &colmaxmin() macro runs a proc means
*   - %createcovarlabel() macro takes a covariate input file and creates dataset with COVARNUM and a label
*   - %recodecovars() macro creates a list of covariates to correctly group in output
*   - %create_comma_charlist() macro creates a list of variables, each in quotation marks and separated by a comma
*   - %tableletter() macro dynamically increases table numbering              
*   - %soc_clean_paths()
*   - %soc_dirExist()
*   - %soc_quotepath()
*   - %soc_lib()
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
*--------------------------------------------------------------------------------------------------
*  CHANGE LOG: 
*
*   Version   Date       Initials      Comment (reference external documentation when available)
*   -------   --------   --------   ---------------------------------------------------------------
*   1.1       10/30/17   AP         Made length of covariate labels data-driven
*
*   1.2       06/30/19   AP         Add SOC setup macros
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


%macro colmaxmin(op, data, var, name);
    %global &name;
    proc means data = &data &op noprint;
        var &var;
        output out = &op&var &op.=&op&var;
    run;
    data _null_;
        set work.&op&var;
        call symput ("&name", &op&var);
    run;
%mend;

%macro createcovarlabel();
    proc sql;    
        create table covarname as 
        select distinct covarnum, studyname 
        from infolder.&covariatecodes.;
    quit;

    %global labellength;
    proc sql noprint;
        select max(length(studyname)) into :labellength
        from covarname;
    quit;

    %if %eval(&labellength) <70 %then %let labellength = 70;

    data covarname; 
    length MetVar $30 covarlabel $&labellength;
    set covarname; 
        MetVar = cats("COVAR", covarnum);
        covarlabel = studyname;
        drop covarnum studyname;
    run;
    proc sort data=covarname; by metvar; run;
%mend;

%macro recodecovars();
%let RecordedHistory =%upcase(&RecordedHistory.);
%let HistoryofUse = %upcase(&HistoryofUse.);
%let UtilizationIntensity = %upcase(&UtilizationIntensity.);

%global FinalRecordedHistory;
%global FinalHistoryofUse;
%global FinalUtilization;
%global printcomorbscore;

    %if %length(&RecordedHistory) > 0 %then %do;
        %let countvars = %sysfunc(Countw(%quote(&RecordedHistory), %str(,)));
            %do RHCount = 1 %to &countvars.;
                %let RHWord = %scan(%quote(&RecordedHistory),&RHCount, %str(,));
                    %if %index(&RHWord.,%str(-)) = 0 %then %do;
                        %if &RHCount = 1 %then %do;
                            %let FinalRecordedHistory = "&RHWord.";
                        %end;
                        %else %let FinalRecordedHistory = &FinalRecordedHistory., "&RHWord.";
                    %end;
                    %else %do;
                        %let start = %sysfunc(substr(%scan(%quote(&RHWord.),1,%str(-)), 6));
                        %let end = %sysfunc(substr(%scan(%quote(&RHWord.),2,%str(-)), 6));
                        %do covar = &start. %to &end.;
                            %if &RHCount = 1 and &covar = &start. %then %do;
                                %let FinalRecordedHistory = "COVAR&covar.";
                            %end;
                            %else %let FinalRecordedHistory = &FinalRecordedHistory. , "COVAR&covar.";
                        %end;
                    %end;
            %end;
    %end;
    %else %let FinalRecordedHistory = '';

    %if %length(&HistoryofUse) > 0 %then %do;
        %let countvars = %sysfunc(Countw(%quote(&HistoryofUse), %str(,)));
            %do HOUCount = 1 %to &countvars.;
                %let HOUWord = %scan(%quote(&HistoryofUse),&HOUCount, %str(,));
                    %if %index(&HOUWord.,%str(-)) = 0 %then %do;
                        %if &HOUCount = 1 %then %do;
                            %let FinalHistoryofUse = "&HOUWord.";
                        %end;
                        %else %let FinalHistoryofUse = &FinalHistoryofUse., "&HOUWord.";
                    %end;
                    %else %do;
                        %let start = %sysfunc(substr(%scan(%quote(&HOUWord.),1,%str(-)), 6));
                        %let end = %sysfunc(substr(%scan(%quote(&HOUWord.),2,%str(-)), 6));
                        %do covar = &start. %to &end.;
                            %if &HOUCount = 1 and &covar = &start. %then %do;
                                %let FinalHistoryofUse = "COVAR&covar.";
                            %end;
                            %else %let FinalHistoryofUse = &FinalHistoryofUse. , "COVAR&covar.";
                        %end;
                    %end;
            %end;
    %end;
    %else %let FinalHistoryofUse = '';

    %if %length(&UtilizationIntensity) > 0 %then %do;
        %let countvars = %sysfunc(Countw(%quote(&UtilizationIntensity), %str(,)));
        %do UtilCount = 1 %to &countvars.;
            %let Utilword = %scan(%quote(&UtilizationIntensity),&UtilCount, %str(,));
                %if &UtilCount = 1 %then %do;
                    %let FinalUtilization = "&Utilword.";
                %end;
                %else %let FinalUtilization = &FinalUtilization., "&Utilword.";
        %end;
    %end;
    %else %let FinalUtilization = '';

    %put &FinalRecordedHistory;
    %put &FinalHistoryofUse;
    %put &FinalUtilization;

%mend recodecovars;

%macro create_comma_charlist(inlist=, outlist=);
    %global &outlist.;

    %let countvars = %sysfunc(Countw(%quote(&inlist.)));
        %do ccc = 1 %to &countvars.;
            %let word = %scan(%quote(&inlist),&ccc.);
                %if &ccc. = 1 %then %do;
                    %let &outlist. = "&word.";
                %end;
                %else %do;
                    %let &outlist. = &&&outlist. , "&word.";
                %end;
        %end;
    %let &outlist = &&&outlist;
%mend create_comma_charlist;


/*Determine letter for table title*/
%macro tableletter();
    %let div = %sysfunc(int(&tablecount. / 27)); %put &div.;
    %let secondplace = %eval(&tablecount - (26*&div));%put &secondplace.;

    %if %eval(&div = 0) %then %do;
        %let tableletter = %scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &tablecount.);
    %end;
    %else %do;
        %let tableletter = %scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &div.)%scan(a b c d e f g h i j k l m n o p q r s t u v w x y z, &secondplace);
    %end;

    %let tablecount = %eval(&tablecount + 1); /*+1 to counter*/
%mend;


/*SOC setup macros*/
%macro soc_clean_paths(paths);
      %local j ln subpath temppath;  
      %if %length(%superq(paths)) eq 0 %then %do;
      %put The parameter path must be non-missing.; %abort cancel; %end;
      %let paths=%qsysfunc(translate(&paths,%str(/),%str(\)));
      %do j=1 %to %qsysfunc(countw(&paths.,%str( )));
      %let subpath=%qscan(&paths,&j,%str( )); %let ln=%length(&subpath);
      %if %qsubstr(&subpath,&ln,1) ne %str(/) %then %do; %let subpath=&subpath./; %end;
      %let d_exist = %soc_dirExist(&subpath) ;  
      %if &d_exist eq 0 %then %do; %put Path &subpath. does not exist; %abort cancel; %end; 
      %let temppath=&temppath. &subpath.; %end;
      %let paths=%qleft(&temppath);
      &paths   /* returns value to calling environment, like a function */
%mend soc_clean_paths;

%macro soc_dirExist(dir) ; 
      %if %length(&dir.) eq 0 %then %do; 
      %put The parameter dir must be non-missing.; %abort cancel; %end;
      %local rc fileref return; %let rc=%qsysfunc(filename(fileref,&dir.)); 
      %let return=%qsysfunc(fexist(&fileref.));  
      &return  /* returns value to calling environment, like a function */
      %let rc=%qsysfunc(filename(fileref));  
%mend soc_dirExist;

%macro soc_quotepath(list);
      %local j d_exist path_ct path subpath temppath; %let list_ct=%qsysfunc(countw(&list,%str( )));
      %do j=1 %to &list_ct.;
      %let subpath=%qscan(&list,&j,%str( )); %let d_exist = %soc_dirExist(&subpath);  
      %if &d_exist eq 0 %then %do; %put Path &subpath does not exist; %abort cancel; %end;
      %let subpath="&subpath."; %let temppath=&temppath. &subpath.; %end;
      %let list=%qleft(&temppath);
      &list /* returns value to calling enivornment, like a function */
%mend soc_quotepath;

%macro soc_lib(ref, paths, options=) ;
      %local libpaths; %if %length(&ref) eq 0 %then %do; %put libref is blank; %abort cancel; %end;
      %if %length(%superq(paths)) eq 0 %then %do ;
      %put SOC-NOTE: For libref &ref the path is blank, libname assignment skipped; %end;
      %let libpaths= %soc_quotepath(&paths) ;
      libname &ref. %unquote((&libpaths.)) &options.;
%mend soc_lib;

