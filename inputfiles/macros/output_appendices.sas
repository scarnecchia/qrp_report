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
	

	/**********************************/
	/* Geographic Location Appendix   */
	/**********************************/
	%macro geog_cb(tab);
		proc sql noprint;
			create table cb 
			(cbreg char(10), staterri char(250));
			insert into cb
				values("Northeast", "Connecticut, Maine, Massachusetts, New Hampshire, Rhode Island, Vermont, New Jersey, New York, Pennsylvania")
				values("Midwest",	"Illinois, Indiana, Michigan, Ohio, Wisconsin, Iowa, Kansas, Minnesota, Missouri, Nebraska, North Dakota, South Dakota")
				values("South",	"Delaware, District of Columbia, Florida, Georgia, Maryland, North Carolina, South Carolina, Virginia, West Virginia, Alabama,Kentucky, Mississippi, Tennessee, Arkansas, Louisiana, Oklahoma, Texas")
				values("West",	"Arizona, Colorado, Idaho, Montana, Nevada, New Mexico, Utah, Wyoming, Alaska, California, Hawaii, Washington")
				values("Other",	"Northern Mariana Islands, Marshall Islands, Puerto Rico, US Virgin Islands, American Samoa, Micronesia, Guam, Palau");
		quit;

		%let sheetname = &tab;
		ods excel options(sheet_name="&sheetname." tab_color='purple');
		ods proclabel = "&sheetname.";
		%let apptitle  =  %bquote(&sheetname.. List of States and Territories Included in Each Census Bureau Region);

			proc report data =  cb nofs nowd spanrows missing headskip split="*"
				style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
				style(report)=[rules=none frame=box cellpadding =1.75pt];
				columns ("&apptitle." cbreg staterri);
				define cbreg / display "Census Bureau Region" style(column)=[width=1.5in just=L] style(header)=[background = lightgrey];
				define staterri/ display "States and Territories" style(column)=[just=L] style(header)=[background = lightgrey];
				run;
	%mend geog_cb;

	%macro geog_hhs(tab);
		proc sql noprint;
			create table hhs 
				(hhsreg char(10), staterri char(200));
			insert into hhs
				values("Region 01",	"Connecticut, Maine, Massachusetts, New Hampshire, Rhode Island, Vermont")
				values("Region 02",	"New Jersey, New York, Puerto Rico, Virgin Islands")
				values("Region 03",	"Delaware, Maryland, Pennsylvania, Virginia, West Virginia, District of Columbia")
				values("Region 04",	"Alabama, Florida, Georgia, Kentucky, Mississippi, North Carolina, South Carolina, Tennessee")
				values("Region 05",	"Illinois, Indiana, Michigan, Minnesota, Ohio, Wisconsin")
				values("Region 06",	"Arkansas, Louisiana, New Mexico, Oklahoma, Texas")
				values("Region 07",	"Iowa, Kansas, Missouri, Nebraska")
				values("Region 08",	"Colorado, Montana, North Dakota, South Dakota, Utah, Wyoming")
				values("Region 09",	"Arizona, California, Hawaii, Nevada, American Samoa, Federated States of Micronesia, Guam, Palau")
				values("Region 10",	"Alaska, Idaho, Oregon, Washington")
				values("Region 99",	"Missing");
		quit ;

		%let sheetname = &tab;
		ods excel options(sheet_name="&sheetname." tab_color='purple');
		ods proclabel = "&sheetname.";
		%let apptitle  =  %bquote(&sheetname.. List of States and Territories Included in Each Health and Human Services (HHS) Region);

			proc report data =  hhs nofs nowd spanrows missing headskip split="*"
				style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
				style(report)=[rules=none frame=box cellpadding =1.75pt];
				column ("&apptitle." hhsreg staterri);
				define hhsreg / display "HHS Region" style(column)=[width=.75in just=L] style(header)=[background = lightgrey];
				define staterri/ display "States and Territories" style(column)=[just=L] style(header)=[background = lightgrey];
				run;
	%mend geog_hhs;

	/************************/
	/* Create NDC Reports   */
	/************************/

	%macro appendixNDC(type, reporttype_label, _appendix);
		proc sort data=&type nodup;
			by appendix_sort header_sort ndc;
		run;

		ods excel options(sheet_name= "&_appendix." tab_color='purple');
		ods proclabel = "&_appendix.";
		%let apptitle  =  %bquote(&_appendix.. &reporttype_label.);
		
		proc report data =  &type nofs nowd spanrows missing headskip split="*"
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			columns ("&apptitle." header ndc genericname brandname form route strength unit);
			define header /order noprint order=data ' ';
			define ndc / display "NDC" style(column)=[tagattr='type:text' width=.75in just=L] style(header)=[background = lightgrey]; 
			define genericname/ display "Generic Name" style(column)=[just=L] style(header)=[background = lightgrey]; 
			define BrandName/ display "Brand Name" style(column)=[just=L] style(header)=[background = lightgrey]; 
			define Form/ display "Form" style(column)=[width=1.5in just=L] style(header)=[background = lightgrey]; 
			define Route/ display "Route" style(column)=[width=.75in just=L] style(header)=[background = lightgrey]; 
			define Strength/ display "Strength" style(column)=[width=.75in just=L] style(header)=[background = lightgrey]; 
			define Unit/ display "Unit" style(column)=[width=1.5in just=L] style(header)=[background = lightgrey]; 
				compute before header / style=[backgroundcolor=darkgray color = black just=C font_weight=bold bordertopcolor=black borderbottomcolor=black];
				length text $100;
					text = header;
					num = 100;
					line text $varying. num;
				endcomp;
			run;
	%mend appendixNDC;

	/**************************************************/
	/* Create NDC Reports - Generic and Brand Names   */
	/**************************************************/
	%macro appendixNDC_GenBr(type, reporttype_label, _appendix);

		ods excel options(sheet_name= "&_appendix." tab_color='purple');
		ods proclabel = "&_appendix.";
		%let apptitle  =  %bquote(&_appendix.. &reporttype_label.);

		proc sort data=&type nodupkey out=&type._NDC_GenBr(keep=appendix_sort header_sort header genericname brandname);
		by appendix_sort header_sort genericname BrandName;
		run;
		
		proc report data =  &type._NDC_GenBr nofs nowd spanrows missing headskip split="*"
		style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
		style(report)=[rules=none frame=box cellpadding =1.75pt];
			column ("&apptitle." header genericname brandname);
			define header /order noprint order=data ' ';
			define genericname/ display "Generic Name" style(column)=[width=2.5in just=L] style(header)=[background = lightgrey];
			define BrandName/ display "Brand Name" style(column)=[width=1.5in just=L] style(header)=[background = lightgrey];
				compute before header / style=[backgroundcolor=darkgray color = black just=C font_weight=bold bordertopcolor=black borderbottomcolor=black];
				length text $100;
					text = header;
					num = 100;
					line text $varying. num;
				endcomp;
			run;
	%mend appendixNDC_GenBr;

	/********************************************/
	/* Create Diagnosis and Procedure Reports   */
	/********************************************/

	proc format;
		value $codecat1f
			  "DX" = "Diagnosis"
			  "PX" = "Procedure";
		value $DXPX09f
			"09" = "ICD-9-CM";
		value $DX10f
			"10" = "ICD-10-CM"; 			 		  
		value $PX10f
			"10" =  "ICD-10-PCS";
		value $PXC4f
			"C4" = "CPT-4"; 			 
		value $PXHCH3f
			"HC" = "HCPCS"
			"H3" = "HCPCS"; 			  			 
		value $PXC2f
			"C2" = "CPT-2"; 			 
		value $PXC3f
			"C3" = "CPT-3"; 			 
		value $PXNDf
			"ND" = "NDC"; 			 
		value $PXREf
			"RE" = "RE";
	run;
	
	%macro appendixDXPX(type, reporttype_label, _appendix);

		proc sort data=&type nodup;
			by appendix_sort header_sort code1;
		run;

		ods excel options(sheet_name= "&_appendix." tab_color='purple');
		ods proclabel = "&_appendix.";
		%let apptitle  =  %bquote(&_appendix.. &reporttype_label.);

		proc report data =  &type nofs nowd spanrows missing headskip split="*"
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			column ("&apptitle." codeform header code1 descrip  codecat1 codetype1);
			define header /order noprint order=data ' ';
			define code1 / display "Code" style(column)=[width=.75in just=L] style(header)=[background = lightgrey];
			define descrip/ display "Description" style(column)=[just=L] style(header)=[background = lightgrey];
			define codetype1/ display "Code Type" style(column)=[width=.75in just=L] style(header)=[background = lightgrey];
			define codecat1/ display "Code Category" style(column)=[width=.75in just=L] style(header)=[background = lightgrey];
			define codeform/noprint;
				compute before header / style=[backgroundcolor=darkgray color = black just=C font_weight=bold bordertopcolor=black borderbottomcolor=black];
				length text $100;
					text = header;
					num = 100;
					line text $varying. num;
				endcomp;
				compute codetype1;
						if codeform = "DX10" then  do;
							call define(_col_, "format", "$DX10f.");
						end;
						else if codeform = "DX09" then  do;
							call define(_col_, "format", "$DXPX09f.");
						end;
						else if codeform = "PX09" then  do;
							call define(_col_, "format", "$DXPX09f.");
						end;
						else if codeform = "PX10" then  do;
							call define(_col_, "format", "$PX10f.");
						end;					
						else if codeform = "PXC4" then  do;
							call define(_col_, "format", "$PXC4f.");
						end;					
						else if codeform = "PXHC" then  do;
							call define(_col_, "format", "$PXHCH3f.");
						end;					
						else if codeform = "PXH3" then  do;
							call define(_col_, "format", "$PXHCH3f.");
						end;					
						else if codeform = "PXC2" then  do;
							call define(_col_, "format", "$PXC2f.");
						end;					
						else if codeform = "PXC3" then  do;
							call define(_col_, "format", "$PXC3f.");
						end;					
						else if codeform = "PXND" then  do;
							call define(_col_, "format", "$PXNDf.");
						end;					
						else if codeform = "PXRE" then  do;
							call define(_col_, "format", "$PXREf.");
						end;										
				endcomp;
				compute codecat1;
					call define(_col_, "format", "$codecat1f.");
				endcomp;
			run;
	%mend appendixDXPX;

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
	

	proc sql noprint;
	select report, type, ord, tag, appendix, titletype, title
	into  :reports separated by "*", 
		  :report_types separated by "*", 
		  :lettercounts separated by "*", 
		  :report_tags separated by "*", 
		  :appendices separated by "*", 
		  :titletypes separated by "*",
		  :labels separated by "*"
	from appendixreport;
	quit;

	%let appendixcount = %sysfunc(countw(&lettercounts.)); 
	%put &appendixcount.;

		%do p=1 %to %eval(&appendixcount.);
			%let _tags = %scan(&report_tags., &p, %str(*));
			%let data = %scan(&report_types., &p.);
			%let tab = 	%scan(&appendices., &p., %str(*));
			%let _report = %scan(&reports., &p., %str(*));
			%let _titletype = %scan(&titletypes., &p., %str(*));
			%let appendix = %scan(&appendices., &p., %str(*));
			%let label =  %scan(%bquote(&labels.), &p.,%str(*));
			%put &data.;
			%if "%upcase(&data.)" = "GEOG" %then %do;
				 %if "%upcase(&_report.)" = "GEOG_CB" %then %do;
					  %geog_cb(&tab);
				 %end;
				 %else %if "%upcase(&_report.)" = "GEOG_HHS" %then %do;
					  %geog_hhs(&tab);
				 %end;
			%end;
			%else %if "%upcase(&_tags.)" = "APPENDIXDXPX"  %then %do;
				%appendixDXPX(&_report., %bquote(&label.), &appendix.);
			%end;
			%else %if "%upcase(&_tags.)" = "APPENDIXNDC_GENBR"  %then %do;
				%appendixNDC_GenBr(&_report., %bquote(&label.), &appendix.);
			%end;
			%else %if "%upcase(&_tags.)" = "APPENDIXNDC"  %then %do;
				%appendixNDC(&_report., %bquote(&label.), &appendix.);
			%end;
		%end;


   
***************************************************************************************************;
*                                          
***************************************************************************************************;




    %put =====> END MACRO: output_appendices ;

%mend output_appendices;
