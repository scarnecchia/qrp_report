****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: appendix_output.sas  
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

%macro appendix_output();

    %put =====> MACRO CALLED: appendix_output;
	
	/**********************************/
	/* Geographic Location Appendices */
	/**********************************/	
	%macro appendixGEOG(_data=, _rptlabel=, _tab=);
		%if %index(&_rptlabel.,HHS) %then %do; %let geog = HHS; %end;
		%else %do; %let geog = Census Bureau; %end;

		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);
		proc report data =  &_data nofs nowd spanrows missing headskip
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			columns (region staterri);
			define region / display "&geog. Region" style(column)=[width=1.5in just=L] style(header)=[background = lightgrey];
			define staterri/ display "States and Territories" style(column)=[just=L] style(header)=[background = lightgrey];
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black 
			                               borderbottomcolor=black tagattr="wrap:yes" nobreakspace=off];
	        line "&apptitle.";
			endcomp;
		run;
	%mend appendixGEOG;	
	
	/**************************************************/
	/* Create NDC Reports - Generic and Brand Names   */
	/**************************************************/
	%macro appendixNDC(_data=, _rptlabel=, _tab=);
		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);
	
		%if %index(&_tab,.) %then %do;
			proc sort data=&_data. nodup
					   out=_data_ndc; 
				by appendix_sort header_sort ndc;
			run;		
		%end;
		%else %do; 
			proc sort data=&_data. nodupkey 
					   out=_data_ndc (keep=appendix_sort header_sort header genericname 
												  %if %varexist(&_data,brandname) = 1 %then %do; brandname %end;);
				by appendix_sort header_sort genericname %if %varexist(&_data,brandname) = 1 %then %do; brandname %end; ;
			run;
		%end;

		proc contents data = _data_ndc noprint
		               out = _varnames (keep=name);
	    run;

		%let optionalvars = ;
		proc sql noprint;
			select propcase(name)
			into : optionalvars separated by ' '
			from _varnames
			where lowcase(name) not in ('header','ndc','appendix_sort','header_sort','genericname');
		quit;
		%put optionalvars = &optionalvars.;
	
		proc report data =  _data_ndc nofs nowd spanrows missing headskip
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];

			columns (header %if %varexist(_data_ndc,ndc) = 1 %then %do; ndc %end; genericname &optionalvars.);
			define header /order noprint order=data ' ';
			%if %varexist(_data_ndc,ndc) = 1 %then %do;
			define ndc / display "NDC" style(column)=[tagattr='type:text' width=1in just=L] style(header)=[background = white]; 
			%end;
			define genericname/ display "Generic Name" style(column)=[width=2.5in just=L] style(header)=[background = white];
			%if %str("&optionalvars") ne %str("") %then %do;
				%do x = 1 %to %sysfunc(countw(&optionalvars));
					define %scan(&optionalvars, &x)/ %if %lowcase("%scan(&optionalvars, &x)") = "brandname" %then %do;
													  display "Brand Name" style(column)=[width=2.5in just=L] style(header)=[background = white];
													 %end;
													 %else %do;
													  display "%scan(&optionalvars, &x)" style(column)=[just=L] style(header)=[background = white];
													 %end; 
				%end;
			%end;
			
			compute before header / style=[backgroundcolor=darkgray color = black just=C font_weight=bold bordertopcolor=black borderbottomcolor=black];
			length text $100;
				text = header;
				num = 100;
				line text $varying. num;
			endcomp;
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black 
			                               borderbottomcolor=black tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
			line "&apptitle.";
			endcomp;
		run;
	%mend appendixNDC;

	/********************************************/
	/* Create Diagnosis and Procedure Reports   */
	/********************************************/	
	%macro appendixDXPX(_data=, _rptlabel=, _tab=);

		proc sort data=&_data nodup
		           out=_data_pxdx;
			by appendix_sort header_sort code1;
		run;

		proc contents data = _data_pxdx noprint
		               out = _varnames (keep=name);
	    run;

		%let optionalvars = ;
		proc sql noprint;
			select propcase(name)
			into : optionalvars separated by ' '
			from _varnames
			where lowcase(name) not in ('header','appendix_sort','header_sort','code1','descrip','codetype1','codecat1','codeform');
		quit;
		%put optionalvars = &optionalvars.;

		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);

		proc report data =  _data_pxdx nofs nowd spanrows missing headskip
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			
			columns (codeform header code1 descrip codecat1 codetype1 &optionalvars.);
			define header /order noprint order=data ' ';
			define code1 / display "Code" style(column)=[tagattr="type:String" width=.75in just=L] style(header)=[background = white];
			define descrip/ display "Description" style(column)=[just=L] style(header)=[background = white];
			define codecat1/ display "Code Category" style(column)=[width=.75in just=L] style(header)=[background = white];	
			define codetype1/ display "Code Type" style(column)=[width=.75in just=L] style(header)=[background = white];		
			%if %str("&optionalvars") ne %str("") %then %do;
				%do x = 1 %to %sysfunc(countw(&optionalvars));
					define %scan(&optionalvars, &x)/ display "%scan(&optionalvars, &x)" style(column)=[just=L] style(header)=[background = white];
				%end;
			%end;
			define codeform/noprint;
			
			compute before header / style=[backgroundcolor=darkgray color = black just=C font_weight=bold bordertopcolor=black borderbottomcolor=black ];
			length text $100;
				text = header;
				num = 100;
				line text $varying. num;
			endcomp;

			compute codetype1;
					if codecat1 = "DX" then  do;
						call define(_col_, "format", "$dxfmt.");
					end;		
					else if codecat1 = "PX" then  do;
						call define(_col_, "format", "$pxfmt.");
					end;									
			endcomp;
			compute codecat1;
				call define(_col_, "format", "$cc1fmt.");
			endcomp;
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black 
			                               borderbottomcolor=black tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
				line "&apptitle.";
			endcomp;
		run;
	%mend appendixDXPX;
	
	/**********************************/
	/* Geographic Location Appendices */
	/**********************************/	
	%macro appendixhdps(_data=, _rptlabel=, _tab=);
		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);
		
		proc report data=&_data nofs nowd
            style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black background=lightgrey] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			
            column (psestimategrp dpidsiteid code codecat codetype frequency ranking);
		    		
            define psestimategrp / noprint;
		    define dpidsiteid    / display 'Data Partner'  style(column)=[width=1.2in just=C];
            define code          / display 'Code'          style(column)=[width=1.2in just=C];
            define codecat       / display 'Code Category' style(column)=[width=1.2in just=C]; 
            define codetype      / display 'Code Type'     style(column)=[width=1.2in just=C]; 
            define frequency     / display 'Frequency'     style(column)=[width=1.2in just=C];
            define ranking       / display 'Ranking'       style(column)=[width=1.2in just=C]; 
			
		  compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black];
            line "&apptitle.";
          endcomp;
		
        run;
		
	%mend appendixhdps;	

	/********************************************/
	/* Create Weight Distribution Appendix      */
	/********************************************/	
	%macro appendixWeightDist(_data=, _rptlabel=, _tab=);

		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);

		/* Create flag to see if convergence was met */
		  %let convergence = 1;
		  data _null_;
		  	set repdata.&_data;
		  	if missing(min) and missing(max) and missing(mean) and missing(sd) then call symputx('convergence',0);
		  run;

		  proc report data=repdata.&_data nofs nowd  
                  style(header)=[rules=none foreground = black font_weight=bold vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
                  style(report)=[rules=none frame=box];

                  column (dpidsiteid N min max mean sd); 

                  define dpidsiteid / display 'Data Partner (Masked)' 
                    style(column)=[width=1in just=C]  style(header)=[just=C background=lightgrey borderbottomcolor=black];
                  define N / display 'Number of Patients' 
                    style(column)=[width=1.25in just=C tagattr='type:string']  style(header)=[just=C background=lightgrey borderbottomcolor=black];
                  define min / display 'Minimum' 
                    style(column)=[width=1.25in just=C]  style(header)=[just=C background=lightgrey borderbottomcolor=black] format=weightdist.;
                  define max / display 'Maximum' 
                    style(column)=[width=1.25in just=C] style(header)=[just=C background=lightgrey borderbottomcolor=black] format=weightdist.; 
                  define mean / display 'Mean' 
                  style(column)=[width=1.25in just=C] style(header)=[just=C background=lightgrey borderbottomcolor=black] format=weightdist.; 
                  define sd / display 'Standard^n Deviation' 
                  style(column)=[width=1.25in just=C] style(header)=[just=C background=lightgrey borderbottomcolor=black] format=weightdist.; 

                  compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black 
			                    borderbottomcolor=black tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
				  line "&apptitle.";
				  endcomp;


                %if &convergence. = 0 %then %do;
                  compute after / style=[just=L foreground=black bordertopcolor=black];
                    line "Note: N/A represent PS models that did not reach convergence.";
                  endcomp;
                %end;
          run;

	%mend appendixWeightDist;

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
	
	ods startpage=now;
    %if &destination. = excel %then %do;
    ods excel options(sheet_name="Appendix A" tab_color='purple' sheet_interval="table");
    %end;
	ods proclabel = "Appendix A";

    proc report data = output.dpinfo nofs nowd
		style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
		style(report)=[rules=none frame=box cellpadding =1.75pt];
	
		columns (MaskedID dpmindate dpenddate);
		define MaskedID / Display 'Masked DP ID^{super 1}' style(column)=[width=2in] style(header)=[background = lightgrey];
		define dpmindate / Display 'DP Start Date' style(column)=[width=2in] style(header)=[background = lightgrey];
		define dpenddate / Display 'DP End Date^{super 2}' style(column)=[width=2in] style(header)=[background = lightgrey];

        compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black];
        line "Appendix A. Dates of Available Data for Each Data Partner (DP) as of Request Distribution Date &datedistributed.";
        endcomp;

        compute after / style=[background=white just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black cellheight=1.15in nobreakspace=off font_size=&footfontsize.];
        line "^{super 1}Participating Data Partners include &dpnamelist.";
        line "^{super 2}End Date represents the earliest of: (1) query end date, or (2) most recent year-month of data for which all of a Data Partner's data tables (enrollment, dispensing, etc.) have at least 80% of the record count relative to the prior month.";
        endcomp;
    run;
	

***************************************************************************************************;
* Geographic Appendices and Code List Appendices (Index defining codes, Exposure incidence defining 
* codes, Censor defining codes, Outcome defining codes, Outcome incidence defining codes, Inclusion  
* defining codes and Covariate defining codes)                                      
***************************************************************************************************;
    %isdata(dataset=tableofcontents);
    %if %eval(&nobs.>0) %then %do;
		proc sql noprint;
		select compress(tabnum,,'ka'), tabnum, appendixtype, caption, count(*)
		into  :apxdata separated by "*", 
			  :apxname separated by "*",
			  :apxtype separated by "*", 
			  :apxtitle separated by "*",
			  :appendixcnt
		from tableofcontents
		where appendixtype is not missing;

		/* need to keep digit on tabnum */
		%let apxweightdata = ;
		select compress(tabnum,,'kad')
		into  :apxweightdata separated by "*"
		from tableofcontents
		where appendixtype = 'appendixWeightDist';
		quit;

		%if %eval(&appendixcnt.>0) %then %do;
	
			%do p=1 %to %eval(&appendixcnt.);
				%let _apxdata = %scan(&apxdata., &p, %str(*));
				%if %length(&apxweightdata) > 0 %then %do;	
				%let _apxweightdata = %scan(&apxweightdata., &p, %str(*));	
				%end;		
				%let _apxtype = %scan(&apxtype., &p., %str(*));				
				%let _apxname = %scan(&apxname., &p., %str(*));			
				%let _apxtitle = %scan(%bquote(&apxtitle.), &p.,%str(*));	
				ods startpage=now;
                %if &destination. = excel %then %do;
		        ods excel options(sheet_name= "&_apxname." tab_color='purple' sheet_interval="table" flow="tables");
                %end;
				%if "%upcase(&_apxtype.)" = "APPENDIXGEOG" %then %do;	
					%appendixGEOG(_data=&_apxdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
				%end;
				%else %if "%upcase(&_apxtype.)" = "APPENDIXDXPX" %then %do;
					%appendixDXPX(_data=&_apxdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
				%end;
				%else %if "%upcase(&_apxtype.)" = "APPENDIXNDC_GENBR" %then %do;
					%appendixNDC(_data=&_apxdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
				%end;
				%else %if "%upcase(&_apxtype.)" = "APPENDIXNDC" %then %do;
					%appendixNDC(_data=&_apxdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
				%end;
				%else %if "%upcase(&_apxtype.)" = "APPENDIXHDPS" %then %do;
					%appendixhdps(_data=&_apxdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
			    %end;
				%else %if "%upcase(&_apxtype.)" = "APPENDIXWEIGHTDIST" %then %do;
				    %appendixWeightDist(_data=&_apxweightdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
				%end;
			%end;
		%end;
	%end;

    /********************************************/
    /* delete temp datasets                     */
    /********************************************/
	proc datasets lib=work nolist;
		delete _:;
	quit;

    %put =====> END MACRO: appendix_output ;

%mend appendix_output;
