****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: initialize_macro_variables.sas  
* Created (mm/dd/yyyy): 11/30/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro initializes global macro variables
*
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*
*  PARAMETERS:                                                                       
*            
*  Programming Notes:                                                                                
*   -Macro variables read in from CREATEREPORTFILE are set to global in processinputfiles.sas                                                                        
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro initialize_macro_variables();

    %put =====> MACRO CALLED: initialize_macro_variables ;

    /*variables related to DPs*/
    %global num_dp random_dplist masked_dplist database;
    %let num_dp = 0;
	%let masked_dplist =;
    %let database = ;

    /*variables related to query*/
    %global runidlist numrunid typenum;
    %let runidlist = ;
    %let numrunid = 0;
    %let typenum = ;

    /*variables assigned to the start and end date of the query - used in all titles*/
    %global startdateformatted enddateformatted minqueryyear maxqueryyear;
    %let startdateformatted = ;
    %let enddateformatted = ;
    %let minqueryyear = ;
    %let maxqueryyear = ;

    /*variables related to createreport input file*/
    %global ReportType small_cellcounts redactcolumns stratifybyDP seed groupsfile baselinefile tablefile
            figurefile labelfile itsregressionfile treeaggfile appendixfile selectionprobabilitiesfile CodeDescriptionsFile
            TableColumnsFile DPInfoFile L2ComparisonFile look_start look_end DateDistributed report_destination;

    %let ReportType= ;
    %let small_cellcounts = ;
    %let redactcolumns =;
    %let stratifybyDP = ;
    %let seed = ;
    %let groupsfile = ;
    %let baselinefile = ;
    %let tablefile = ;
    %let figurefile = ;
    %let labelfile = ;
    %let itsregressionfile = ;
    %let treeaggfile = ;
    %let appendixfile = ;
    %let selectionprobabilitiesfile = ;
    %let CodeDescriptionsFile = ;
    %let TableColumnsFile = ;
    %let DPInfoFile = ;
    %let L2ComparisonFile = ;
    %let look_start = 1;
    %let look_end = 1;
    %let datedistributed = ;
    %let report_destination = ;

    /*tablefile and figurefile variables*/
    %global datasetlist figurelist tablelist tdatasetlist tdatasetlistnum includegroupinfigure;
    %let datasetlist = ;
	%let tdatasetlist = ;
	%let tdatasetlistnum = ;
    %let figurelist = ;
    %let tablelist = ;
    %let includegroupinfigure = ;

    /*baseline table variables*/
    %global numbaselinetablegrp baselinerowitalics numprofilecovarstoinclude;
    %let numbaselinetablegrp =0;
	%let baselinerowitalics =;
    %let numprofilecovarstoinclude=0;

	/*groupsfile table variables*/
    %global output_code_distribution numgroups discardnegativetimegroups requestedfigs;
    %let numgroups = 0;
    %let output_code_distribution = N;
    %let discardnegativetimegroups = ;
    %let requestedfigs = ;

    /*L2 report variables*/
    %global numl2comparisons attrperiodid;
    %let numl2comparisons = 0;
    %let attrperiodid=;

    /*label file variables */
    %global reporttitle labelfileexists label_length cens_elig_label cens_dth_label cens_dpend_label cens_qryend_label cens_episend_label cens_spec_label
            cens_event_label cens_switch1_label cens_switch2_label includeheaderrow;
    %let reporttitle = Exposures of Interest;
	%let labelfileexists = N;		
    %let label_length = 250;
    %let cens_elig_label =Disenrollment;
    %let cens_dth_label =Evidence of death;
    %let cens_dpend_label =End of data partner data;
    %let cens_qryend_label =End of query period;
    %let cens_episend_label =End of exposure episode;
    %let cens_spec_label =Occurence of request-defined censoring criteria;
    %let cens_event_label =Occurence of event;
    %let cens_switch1_label =First switch; 
    %let cens_switch2_label =Second switch; 
    %let includeheaderrow = N;

    /*censor reasons*/
    %global defaultcensororder;
    %let defaultcensororder = cens_episend cens_event cens_spec cens_dth cens_elig cens_dpend cens_qryend;

    /*Age stratification format */
    %global agefmt;

    /*Output counter variables*/
    %global tableletter tablecount;

    /*output_agg_data to msocdata*/
    %global output_agg_data;
    %let output_agg_data = Y;
	
	/* zipfile is a local macro variable in qrp therefore when leave behind report is requested do not set to global */
    %if &leavebehindreport. = N %then %do; %global zipfile; %end;
	%let zipfile = ;
	
	/* covariate codes formats */
	%global maxlen_studyname;
    %let maxlen_studyname = 0;
	
	/* Total number of unique stratifications by file type*/
	%global numstrata_t1cida numstrata_t2cida numstrata_t2conc;
    %let numstrata_t1cida = 0;
	%let numstrata_t2cida = 0;
	%let numstrata_t2conc = 0;

	/* Leave behind report */
	%global reportid dpfile;

    %put =====> MACRO ENDED: initialize_macro_variables ;

%mend initialize_macro_variables;
