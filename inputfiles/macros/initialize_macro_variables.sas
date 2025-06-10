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
*   -Macro variables read in from REPORT_PARAMETERS are set to global in create_report_driver.sas                                                                        
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
    %global num_dp random_dplist masked_dplist;
    %let num_dp = 0;
	%let masked_dplist =;

    /*variables related to query*/
    %global runidlist numrunid typenum basecohortused drop_cens_output_qrpreport;
    %let runidlist = ;
    %let numrunid = 0;
    %let typenum = ;
    %let basecohortused = N;
	%let drop_cens_output_qrpreport = N;

    /*variables assigned to the start and end date of the query - used in all titles*/
    %global startdateformatted enddateformatted minqueryyear maxqueryyear;
    %let startdateformatted = ;
    %let enddateformatted = ;
    %let minqueryyear = ;
    %let maxqueryyear = ;    

	/* Type 3 Tree weekdays dataset variable */
    %global t3treewkdaysdset;
    %let t3treewkdaysdset = ;

    /*tablefile and figurefile variables*/
    %global datasetlist figurelist tablelist tdatasetlist tdatasetlistnum includegroupinfigure;
    %let datasetlist = ;
	%let tdatasetlist = ;
	%let tdatasetlistnum = ;
    %let figurelist = ;
    %let tablelist = ;
    %let includegroupinfigure = ;

    /*baseline table variables*/
    %global numbaselinetablegrp numprofilecovarstoinclude labcharacteristics riskscoreslist_quoted riskscores_with_cats riskscorelibrary;
    %let numbaselinetablegrp =0;
    %let numprofilecovarstoinclude=0;
    %let labcharacteristics=;
	%let riskscoreslist_quoted=;
	%let riskscores_with_cats=;
	%let riskscorelibrary=ADCSI CHA2DS2VASC CCI FRAILTY HASBLED OBSCOMORB PEDCOMORB;

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

	/*T4L1 report variables*/
	%global gestwktables_runid_list;
	%let gestwktables_runid_list=;

    /*label file variables */
    %global reporttitle labelfileexists label_length cens_elig_label cens_dth_label cens_dpend_label cens_qryend_label cens_episend_label cens_spec_label
            cens_event_label cens_switch1_label cens_switch2_label includeheaderrow includemoiheaderrow;
    %let reporttitle = Exposures of Interest;
	%let labelfileexists = N;		
    %let label_length = 250;
    %let cens_elig_label =Disenrollment;
    %let cens_dth_label =Evidence of Death;
    %let cens_dpend_label =End of Data;
    %let cens_qryend_label =End of Study Period;
    %let cens_episend_label =End of Exposure Episode;
    %let cens_spec_label =Occurrence of User-Defined Censoring Criteria;
    %let cens_event_label =Occurrence of Outcome of Interest;
    %let cens_switch1_label =First Switch; 
    %let cens_switch2_label =Second Switch; 
    %let includeheaderrow = N;
    %let includemoiheaderrow = N;

    /*censor reasons*/
    %global defaultcensororder;
    %let defaultcensororder = cens_episend cens_event cens_spec cens_dth cens_elig cens_dpend cens_qryend cens_switch;

    /*Age stratification format */
    %global agegroupfmt;

    /* Race categories and race count - 0 not included in list because other categories get collapsed in RACE=0*/
    %global racelist racecount;
    %let racelist = 1 2 3 4 5 M;
    %let racecount = %sysfunc(countw(&racelist));

    /*Output counter variables*/
    %global tableletter tablecount;

    /*output_agg_data to msocdata*/
    %global output_agg_data;
    %let output_agg_data = Y;
	
	/* zipfile is a local macro variable in qrp therefore when leave behind report is requested do not set to global */
    %if &leavebehindreport. = N %then %do; %global zipfile; %end;
	%let zipfile = ;

    /* covariate stratifications in summary tables */
    %global numsummarystratcovars;
    %let numsummarystratcovars = 0;

    /* baseline covariates */
    %global includecovars baselinelabellength labcovars charlabslist;
    %let includecovars = N;
    %let baselinelabellength = 80;
    %let labcovars = ;
    %let charlabslist = %str("missing");

	/* Total number of unique stratifications by file type*/
	%global numstrata_t1cida numstrata_t2cida numstrata_t2conc numstrata_t4cida;
    %let numstrata_t1cida = 0;
	%let numstrata_t2cida = 0;
	%let numstrata_t2conc = 0;
	%let numstrata_t4cida = 0;

    /*figure specific variables*/
    %global unicode_list xmin;
    %let unicode_list = 00b9 00b2 00b3 2074 2075 2076 2077 2078 2079; /*1-9 in unicode*/
	%let xmin = 0 ;

	/* To determine if appendixfile only should be processed */
	%global produceappendixfileonly;
	%let produceappendixfileonly=N;

	/* To determine if tree aggregation should be executed and csv files produced */
	%global treeaggindicator treeanalysisaggindicator treepoissonaggindicator treepoissonindicator treeanalysisindicator;
	%let treeaggindicator=N;
	%let treeanalysisaggindicator=N;
	%let treepoissonaggindicator=N;
    %let treepoissonindicator=N;
    %let treeanalysisindicator=N;
	
    %put =====> MACRO ENDED: initialize_macro_variables ;

%mend initialize_macro_variables;
