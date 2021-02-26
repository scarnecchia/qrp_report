****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: output_appendices.sas  
* Created (mm/dd/yyyy): 02/24/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro produces all report appendices
*                                        
*  Program inputs:                                                                                   
*
* 
*  Program outputs:  
*   - Appendix A (List of DPs) is always produced 
*   - For ReportType = L2T2 and T4L2, an aggregated VARINFO appendix is produced if any analysis
*     uses HDPS
*   - For ReportType = L2T2, a weight distribution appendix is produced if any analysis uses
*     IPTW or PS stratum weighting
*   - For ReportType = L1T2 or L1T2 an appendix listing HHS or CB region is produced if either
*     stratification is requested in the report
*   - For ReportType = T6, an appendix listing the computed start marketing date foe each cohort
*     at each data parter is produced
*   - If an APPENDIXFILE is specified, code list appendices are generated
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

%macro output_appendices();

    %put =====> MACRO CALLED: output_appendices;

***************************************************************************************************;
* Appendix A: list of DPs                                            
***************************************************************************************************;

    /*Put dpname into list for appendix A*/
    %let dpnamelist = ;
    %do a = 1 %to &num_dp.;
        data _null_;
            set dpinfofile;
            if _n_ = &a. then call symputx('tempdpname', strip(dpname));
        run;
        %if %eval(&num_dp.=1) %then %do;
            %let dpnamelist = &tempdpname.;
        %end;
        %else %do;
            %if &a. ne &num_dp. %then %do;
                %if %eval(&a.=1) %then %let dpnamelist = %str(&tempdpname.; and);
                %else %let dpnamelist = %str(&dpnamelist. &tempdpname.; and);
            %end;
            %else %do;
                %let dpnamelist = %str(&dpnamelist. &tempdpname.);
            %end;
        %end;
    %end;

    ods excel options(sheet_name="Appendix A" tab_color='purple');
	ods proclabel = "Appendix A";

    proc report data = output.dpinfo nofs nowd
		style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
		style(report)=[rules=none frame=box cellpadding =1.75pt];
	
		columns (MaskedID dpmindate dpenddate);
		define MaskedID / Display 'Masked DP ID^{super 1}' style(column)=[width=2in] style(header)=[background = lightgrey];
		define dpmindate / Display 'DP Start Date' style(column)=[width=2in] style(header)=[background = lightgrey];
		define dpenddate / Display 'DP End Date^{super 2}' style(column)=[width=2in] style(header)=[background = lightgrey];

        compute before _page_ / style=[just=c background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black];
        line "Appendix A. Dates of Available Data for Each Data Partner (DP) as of Request Distribution Date &datedistributed.";
        endcomp;

        compute after / style=[just=c background=white just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black cellheight=1.15in nobreakspace=off];
        line "^{super 1}Participating Data Partners include &dpnamelist.";
        line "^{super 2}End Date represents the earliest of: (1) query end date, or (2) most recent year-month of data for which all of a Data Partner’s data tables (enrollment, dispensing, etc.) have at least 80% of the record count relative to the prior month.";
        endcomp;
    run;


   
***************************************************************************************************;
*                                          
***************************************************************************************************;




    %put =====> END MACRO: output_appendices ;

%mend output_appendices;
