****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: qrp_report.sas
* Created (mm/dd/yyyy): 11/30/2020
* Last modified: 11/30/2020
* Version: 1.0.0
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*   Create QRP reports based on analysis types
*   The following can be requested:
*		-Type 1 
*		-Type 2 
*		  -Multiple Events 
*		  -Overlap 
*		  -Concomitant Use
*		  -PSA
*		-Type 4
*		  -PSA
*		-Type 5
*		-Type 6
*
*  Program inputs:
*
*  Program outputs:
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
***************************************************************************************************;

/* Location of QRP request inputfiles folder */
%let INFOLDER =;

/* Assign path name for data folder (optional) */
%let DATAROOT =;

/* Location of QRP report package */
%let REPORTROOT =;

/* Enter the name of the CREATEREPORT_FILE file*/
%let CREATEREPORTFILE =;

****************************************************************************************
*******                             END OF USER INPUT                             ******
*******                        DO NOT EDIT BELOW THIS LINE                        ******
******* (Consult with SOC or Sentinel team leader if you feel edits are required) ******
****************************************************************************************;

/*---------------------------------------------------------------------*/
/* NOTE: This is standard SOC environment setup code -- Do Not Edit   */
/*---------------------------------------------------------------------*/

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

/* If reportroot is missing, assign default path */
%if %symexist(reportroot) = 0 or %length(&reportroot) = 0 %then %do;
%global reportroot;
%let rc = %sysfunc(filename(fr,.));
%let reportroot = %sysfunc(pathname(&fr.));
/* Find all \ slashes and turn them into / for both Windows/Unix compatibility */
%let reportroot = %sysfunc(tranwrd(&reportroot,\,/));
/* Remove inputfiles/macros subdirectory to get root path */
%let reportroot = %sysfunc(tranwrd(&reportroot,sasprograms,/));
%let rc= %sysfunc(filename(fr));
%end;

*-------------------------------------------------------------------------------------------------
* 1- Include macros
*-------------------------------------------------------------------------------------------------;

/*driver macros*/
%include "&reportroot./inputfiles/macros/create_report.sas";

/*utility macros*/
%include "&reportroot./inputfiles/macros/utility_macros.sas";

/*set up*/
%include "&reportroot./inputfiles/macros/initialize_macro_variables.sas";
%include "&reportroot./inputfiles/macros/process_inputfiles.sas";