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


*-------------------------------------------------------------------------------------------------
* 1- Include macros
*-------------------------------------------------------------------------------------------------;

/*driver macros*/
%include "&packageroot./inputfiles/macros/create_report.sas";

/*utility macros*/
%include "&packageroot./inputfiles/macros/utility_macros.sas";

/*set up*/
%include "&packageroot./inputfiles/macros/initialize_macros_variables.sas";
%include "&packageroot./inputfiles/macros/processinputfiles.sas";