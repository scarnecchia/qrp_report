***************************************************************************************************
*                                      SENTINEL PROGRAM
***************************************************************************************************
*
* PROGRAM: qrp_report.sas
* CREATED (mm/dd/yyyy):
* LAST MODIFIED: 
* VERSION: 1.0.0
*
* PURPOSE: Aggregate QRP outputs from data partners and produce an Excel report
*
* MAJOR STEPS:
*
* KEY DEPENDENCIES/CONSTRAINTS/CAVEATS:
*
* PROGRAMMING NOTES:
*
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO:
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

/*-----------------------------------------------------------------------------------------------*/
/* Section 1: User inputs 															             */
/*-----------------------------------------------------------------------------------------------*/

/* Location of QRP request inputfiles folder */
%let INFOLDER =;

/* Location of data folder */
%let DATAROOT =;

/* Location of QRP report package */
%let REPORTROOT =;

/* Enter the name of the CREATEREPORTFILE file*/
%let CREATEREPORTFILE =;

***************************************************************************************************;
*******                                 END OF USER INPUT                                    ******
*******                         DO NOT EDIT BELOW THIS LINE                                  ******
*******     (Consult with SOC or Sentinel team leader if you feel edits are required)        ******
***************************************************************************************************;

/*-----------------------------------------------------------------------------------------------*/
/* NOTE: This is standard SOC environment setup code -- Do Not Edit                              */
/*-----------------------------------------------------------------------------------------------*/

/* System options */
options nosymbolgen nomlogic;
options ls=100 nocenter ;
options obs=MAX ;
options msglevel=i ;
options mprint mprintnest ;
options errorcheck=strict errors=0 ;
options merror serror ;
options dkricond=error dkrocond=error mergenoby=warn;
options dsoptions=nonote2err noquotelenmax ;
options reuse=no ;
options fullstimer ;
options missing = .;
options validvarname = v7;

/*-----------------------------------------------------------------------------------------------*/
/* Section 2 - SOC macros for cleaning paths and libname assignments 					         */
/*-----------------------------------------------------------------------------------------------*/

/* If reportroot is missing, assign default path */
%macro check_reportroot;
%if %symexist(reportroot) = 0 or %length(&reportroot) = 0 %then %do;
%global reportroot;
%let rc = %sysfunc(filename(fr,.));
%let reportroot = %sysfunc(pathname(&fr.));
/* Find all \ slashes and turn them into / for both Windows/Unix compatibility */
%let reportroot = %sysfunc(tranwrd(&reportroot,\,/));
/* Remove sasprograms subdirectory to get root path */
%let reportroot = %sysfunc(tranwrd(&reportroot,sasprograms,/));
%let rc= %sysfunc(filename(fr));
%end;
%mend check_reportroot;
%check_reportroot;

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
  &return  /* returns value to calling enivornment, like a function */
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

%macro initialize_paths;
/* DATAROOT is optional in header program */
%if %length(&DATAROOT) > 0 %then %let DATAROOT = %soc_clean_paths(&DATAROOT.);   
%let INFOLDER = %soc_clean_paths(&INFOLDER.);   
%let REPORTROOT = %soc_clean_paths(&REPORTROOT.);
%mend initialize_paths;
%initialize_paths;

%soc_lib(INFOLDER, &INFOLDER, options=%str(access=readonly));
%soc_lib(INPUT, &REPORTROOT.inputfiles/ &INFOLDER, options=%str(access=readonly));
%soc_lib(OUTPUT, &REPORTROOT.output/);

/*-----------------------------------------------------------------------------------------------*/
/* Section 3 - Include macros 															         */
/*-----------------------------------------------------------------------------------------------*/

/*driver macros*/
%include "&reportroot.inputfiles/macros/create_report.sas";

/*utility macros*/
%include "&reportroot.inputfiles/macros/utility_macros.sas";

/*set up*/
%include "&reportroot.inputfiles/macros/initialize_macro_variables.sas";
%include "&reportroot.inputfiles/macros/process_inputfiles.sas";
%include "&reportroot.inputfiles/macros/createlibref.sas";
%include "&reportroot.inputfiles/macros/report_formats_labels.sas";

/*baseline macros*/
%include "&reportroot.inputfiles/macros/baseline_driver.sas";
%include "&reportroot.inputfiles/macros/baseline_aggregate.sas";
%include "&reportroot.inputfiles/macros/baseline_expand_parameters.sas";
%include "&reportroot.inputfiles/macros/baseline_compute.sas";

/*Aggregate macro*/
%include "&reportroot.inputfiles/macros/aggregate_report_tables.sas";

/*report formatting and output macros*/
%include "&reportroot.inputfiles/macros/output_report_dates.sas";


/*-----------------------------------------------------------------------------------------------*/
/* Section 4 - Call create_report.sas 															 */
/*-----------------------------------------------------------------------------------------------*/
%create_report();
