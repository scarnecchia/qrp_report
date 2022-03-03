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
    		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
    		style(report)=[rules=none frame=void cellpadding =1.75pt];
			columns (region staterri);
			define region / display "&geog. Region" style(column)=[width=1.5in just=L] style(header)=[background = bgr borderleftcolor = BGR];
			define staterri/ display "States and Territories" style(column)=[just=L] style(header)=[background = bgr borderleftcolor = BGR];

			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white 
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off];
	        line "&apptitle.";
			endcomp;
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
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
    		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
    		style(report)=[rules=none frame=void cellpadding =1.75pt];

			columns (header %if %varexist(_data_ndc,ndc) = 1 %then %do; ndc %end; genericname &optionalvars.);
			define header /order noprint order=data ' ';
			%if %varexist(_data_ndc,ndc) = 1 %then %do;
			define ndc / display "NDC" style(column)=[tagattr='type:text' width=1in just=L] style(header)=[background = bgr borderleftcolor = BGR];
			%end;
			define genericname/ display "Generic Name" style(column)=[width=2.5in just=L] style(header)=[background = bgr borderleftcolor = BGR];
			%if %str("&optionalvars") ne %str("") %then %do;
				%do x = 1 %to %sysfunc(countw(&optionalvars));
					define %scan(&optionalvars, &x)/ %if %lowcase("%scan(&optionalvars, &x)") = "brandname" %then %do;
													  display "Brand Name" style(column)=[width=2.5in just=L] style(header)=[background = bgr borderleftcolor = BGR];
													 %end;
													 %else %do;
													  display "%scan(&optionalvars, &x)" style(column)=[just=L] style(header)=[background = bgr borderleftcolor = BGR];
													 %end; 
				%end;
			%end;
			
			compute before header / style=[background=LIBGR just=c font_weight=bold bordertopcolor=black borderbottomcolor=black];
			length text $100;
				text = header;
				num = 100;
				line text $varying. num;
			endcomp;
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white 
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
			line "&apptitle.";
			endcomp;
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
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
    		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
    		style(report)=[rules=none frame=void cellpadding =1.75pt];
			
			columns (codeform header code1 descrip codecat1 codetype1 &optionalvars.);
			define header /order noprint order=data ' ';
			define code1 / display "Code" style(column)=[tagattr="type:String" width=.75in just=L] style(header)=[background = bgr borderleftcolor = BGR];
			define descrip/ display "Description" style(column)=[just=L] style(header)=[background = bgr borderleftcolor = BGR];
			define codecat1/ display "Code Category" style(column)=[width=.75in just=L] style(header)=[background = bgr borderleftcolor = BGR];	
			define codetype1/ display "Code Type" style(column)=[width=.75in just=L] style(header)=[background = bgr borderleftcolor = BGR];		
			%if %str("&optionalvars") ne %str("") %then %do;
				%do x = 1 %to %sysfunc(countw(&optionalvars));
					define %scan(&optionalvars, &x)/ display "%scan(&optionalvars, &x)" style(column)=[just=L] style(header)=[background = bgr borderleftcolor = BGR];
				%end;
			%end;
			define codeform/noprint;
			
			compute before header / style=[background=LIBGR just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
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

			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white 
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
			line "&apptitle.";
			endcomp;
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
            endcomp;
		run;
	%mend appendixDXPX;
	
	/**********************************/
	/* HDPS varinfo appendix          */
	/**********************************/	
	%macro appendixhdps(_data=, _rptlabel=, _tab=);
		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);
		
		proc report data=repdata.&_data nofs nowd
    		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
    		style(report)=[rules=none frame=void cellpadding =1.75pt];
	
            column (dpidsiteid code codecat codetype frequency ranking);
		    		
		    define dpidsiteid    / display 'Masked DP ID'  style(column)=[width=1.2in just=C] style(header)=[background = bgr borderleftcolor = BGR];
            define code          / display 'Code'          style(column)=[width=1.2in just=C] style(header)=[background = bgr borderleftcolor = BGR];
            define codecat       / display 'Code Category' style(column)=[width=1.2in just=C] style(header)=[background = bgr borderleftcolor = BGR]; 
            define codetype      / display 'Code Type'     style(column)=[width=1.2in just=C tagattr='type:string'] style(header)=[background = bgr borderleftcolor = BGR]; 
            define frequency     / display 'Frequency'     style(column)=[width=1.2in just=C] style(header)=[background = bgr borderleftcolor = BGR];
            define ranking       / display 'Ranking'       style(column)=[width=1.2in just=C] style(header)=[background = bgr borderleftcolor = BGR]; 

			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white 
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off];
            line "&apptitle.";
            endcomp;
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
            endcomp;
        run;
		
	%mend appendixhdps;	

	/********************************************/
	/* Create Weight Distribution Appendix      */
	/********************************************/	
	%macro appendixWeightDist(_data=, _rptlabel=, _tab=);		

		%let numsubgroups=0;
		%let covarlabel=;
		%let nocovarlabel=;

		proc sql noprint;
			select count (distinct subgroup) into :numsubgroups from repdata.&_data;
			select combinedlabel into :covarlabel from repdata.&_data where substr(compress(combinedlabel, ' &'),1,10)="StudyCovar"; 
			select combinedlabel into :nocovarlabel from repdata.&_data where substr(compress(combinedlabel, ' &'),1,12)="NoStudyCovar"; 
		quit

        ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);

		/* Create flag to see if convergence was met */
		%let convergence = 1;
		data _null_;
		  set repdata.&_data;
		  if missing(min) and missing(max) and missing(mean) and missing(sd) then call symputx('convergence',0);
		run;

		proc report data=repdata.&_data nofs nowd  
            style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
        	style(report)=[rules=none frame=void cellpadding =1.75pt];

            column (%if &numsubgroups. > 0 %then %do; combinedlabel %end; dpidsiteid N min max mean sd); 

			%if &numsubgroups. > 0 %then %do;
				define combinedlabel / order order=data noprint;
			%end;
            define dpidsiteid / display 'Masked DP ID' 
                style(column)=[width=1in just=C]  style(header)=[just=C background = bgr borderleftcolor = BGR];
            define N / display 'Number of Patients' 
                style(column)=[width=1.25in just=C tagattr='type:string']  style(header)=[just=C background = bgr borderleftcolor = BGR];
            define min / display 'Minimum' 
                style(column)=[width=1.25in just=C] style(header)=[just=C background = bgr borderleftcolor = BGR] format=weightdist.;
            define max / display 'Maximum' 
                style(column)=[width=1.25in just=C] style(header)=[just=C background = bgr borderleftcolor = BGR] format=weightdist.; 
            define mean / display 'Mean' 
              style(column)=[width=1.25in just=C] style(header)=[just=C background = bgr borderleftcolor = BGR] format=weightdist.; 
            define sd / display 'Standard^n Deviation' 
              style(column)=[width=1.25in just=C] style(header)=[just=C background = bgr borderleftcolor = BGR] format=weightdist.; 

			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white 
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
			line "&apptitle.";
			endcomp;

			%if &numsubgroups. > 0 %then %do;
			compute before combinedlabel / style=[background=LIBGR foreground=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
	            length text $100;					
				if prxmatch('/^NoStudyCovar/',compress(combinedlabel, ' &')) > 0 then do;
					text = "&nocovarlabel.";
				end;
				else if prxmatch('/^StudyCovar/',compress(combinedlabel, ' &')) > 0 then do;
					text = "&covarlabel.";
				end;
				else do;
					text = combinedlabel;
				end;				
	            num=100;
				line text $Varying. num; 
			endcomp;
			%end;

            %if &convergence. = 0 %then %do;
            compute after / style=[background=white just=L foreground=black vjust=b bordertopwidth = &bordersize borderbottomcolor=white bordertopcolor=black 
                                   nobreakspace=off font_size=&footfontsize.];
                line "Note: N/A represent PS models that did not reach convergence.";
            endcomp;
            %end;
            %else %do;
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
            endcomp;
            %end;

          run;

	%mend appendixWeightDist;

	/********************************************/
	/* Types 6 Product Dates                    */
	/********************************************/	
	%macro appendixt6dates(_data=, _rptlabel=, _tab=);

        ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);
		
		proc report data=repdata.&_data nofs nowd
    		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
    		style(report)=[rules=none frame=void cellpadding =1.75pt];
	
            column order grouplabel dpidsiteid  cdate;

		    define order / group "" order=data noprint;
            define grouplabel / group noprint order=data;
            define dpidsiteid / group  "" order=data style(column)=[just=L width=2.5in];
            define cdate  / display 'Computed Start Marketing Date'  style(column)=[width=5in just=C] style(header)=[background = bgr borderleftcolor = BGR]; 

			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off];
            line "&apptitle.^{super 1}";
            endcomp;

            compute before grouplabel /
                style=[background=LIBGR just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
                length text $150;
                text= grouplabel; 
                num= 150;
            	line text $varying. num; 
            endcomp;

            /*indent*/
            compute dpidsiteid;
                call define(_col_,'style','style={indent=20}');
            endcomp;

            /*footnote*/
            compute after / style=[background=white just=L foreground=black vjust=b bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white
                                   nobreakspace=off tagattr="wrap:yes" font_size=&footfontsize.];
            line "^{super 1}Computed Start Marketing Date represents the first observed dispensing date among all valid users within each cohort within each Data Partner site.";
            endcomp;
        run;
		
    %mend;


***************************************************************************************************;
* Appendix A: list of DPs                                            
***************************************************************************************************;

    /*Put dpname into list for Appendix A*/
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
		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
		style(report)=[rules=none frame=void cellpadding =1.75pt];
	
		columns (MaskedID dpmindate dpenddate);
		define MaskedID / Display 'Masked DP ID^{super 1}' style(column)=[width=2in] style(header)=[background = bgr borderleftcolor = BGR];
		define dpmindate / Display 'DP Start Date' style(column)=[width=2in] style(header)=[background = bgr borderleftcolor = BGR];
		define dpenddate / Display 'DP End Date^{super 2}' style(column)=[width=2in] style(header)=[background = bgr borderleftcolor = BGR];

        compute before _page_ / style=[background=white background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor = white borderbottomwidth = &bordersize];
        line "Appendix A. Dates of Available Data for Each Data Partner (DP) as of Request Distribution Date &datedistributed.";
        endcomp;

        compute after / style=[background=white just=L foreground=black vjust=b bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white cellheight=1.15in nobreakspace=off font_size=&footfontsize.];
        line "^{super 1}Participating Data Partner(s) include(s) &dpnamelist..";
        line "^{super 2}End Date represents the earliest of: (1) query end date, or (2) last day of the most recent month for which all of a Data Partner's data tables (enrollment, dispensing, etc.) have at least 80% of the record count relative to the prior month.";
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
		select case when upcase(appendixtype) = "APPENDIXNDC" then compress(tabnum,,'ka')
		       else compress(tabnum,,'kad') end
		      ,tabnum
			  ,appendixtype
			  ,caption
			  ,count(*)
		into  :apxdata separated by "*", 
			  :apxname separated by "*",
			  :apxtype separated by "*", 
			  :apxtitle separated by "*",
			  :appendixcnt
		from tableofcontents
		where appendixtype is not missing;
		quit;

		%if %eval(&appendixcnt.>0) %then %do;
	
			%do p=1 %to %eval(&appendixcnt.);
				%let _apxdata = %scan(&apxdata., &p, %str(*));
				%let _apxtype = %scan(&apxtype., &p., %str(*));				
				%let _apxname = %scan(&apxname., &p., %str(*));			
				%let _apxtitle = %scan(%bquote(&apxtitle.), &p.,%str(*));	
				ods startpage=now;
                %if &destination. = excel %then %do;
		        ods excel options(sheet_name= "&_apxname." tab_color='purple' sheet_interval="table" flow="tables");
                %end;
				%if "%upcase(&_apxtype.)" = "APPENDIXT6DATES" %then %do;	
					%appendixt6dates(_data=&_apxdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
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
				    %appendixWeightDist(_data=&_apxdata., _rptlabel=%bquote(&_apxtitle.), _tab=&_apxname.);
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
