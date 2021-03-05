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
	/* Geographic Location Appendices */
	/**********************************/	
	%macro appendixGEOG(_data=, _rptlabel=, _tab=);
		%if %upcase(&_data.)=GEOG_CB %then %do;
			proc sql noprint;
				create table geogreg 
				(region char(10), staterri char(250));
				insert into geogreg
					values("Northeast","Connecticut, Maine, Massachusetts, New Hampshire, Rhode Island, Vermont, New Jersey, New York, Pennsylvania")
					values("Midwest","Illinois, Indiana, Michigan, Ohio, Wisconsin, Iowa, Kansas, Minnesota, Missouri, Nebraska, North Dakota, South Dakota")
					values("South",	"Delaware, District of Columbia, Florida, Georgia, Maryland, North Carolina, South Carolina, Virginia, West Virginia, Alabama,Kentucky, Mississippi, Tennessee, Arkansas, Louisiana, Oklahoma, Texas")
					values("West","Arizona, Colorado, Idaho, Montana, Nevada, New Mexico, Utah, Wyoming, Alaska, California, Hawaii, Washington")
					values("Other","Northern Mariana Islands, Marshall Islands, Puerto Rico, US Virgin Islands, American Samoa, Micronesia, Guam, Palau");
			quit;
			%let geog = Census Bureau;
		%end;
		%else %do;
			proc sql noprint;
				create table geogreg 
					(region char(10), staterri char(200));
				insert into geogreg
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
			quit;
			%let geog = HHS;
		%end;
		ods excel options(sheet_name= "&_tab." tab_color='purple' sheet_interval="table" flow="tables");
		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);

		proc report data =  geogreg nofs nowd spanrows missing headskip
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			columns (region staterri);
			define region / display "&geog. Region" style(column)=[width=1.5in just=L] style(header)=[background = lightgrey];
			define staterri/ display "States and Territories" style(column)=[just=L] style(header)=[background = lightgrey];
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black];
				line "&apptitle.";
			endcomp;
		run;
	%mend appendixGEOG;	
	
	/************************/
	/* Create NDC Reports   */
	/************************/
	%macro appendixNDC(_data=, _rptlabel=, _tab=);
		proc sort data=&_data nodup;
			by appendix_sort header_sort ndc;
		run;

		proc contents data = &_data noprint
		               out = _varnames (keep=name);
	    run;

		%let optionalvars = ;
		proc sql noprint;
			select propcase(name)
			into : optionalvars separated by ' '
			from _varnames
			where lowcase(name) not in ('header','appendix_sort','header_sort','ndc','genericname');
		quit;
		%put optionalvars = &optionalvars.;

		ods excel options(sheet_name= "&_tab." tab_color='purple' sheet_interval="table"  flow="tables" row_heights='50');
		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);
	
		proc report data =  &_data nofs nowd spanrows missing headskip
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			
			columns (header ndc genericname &optionalvars.);
			define header /order noprint order=data ' ';
			define ndc / display "NDC" style(column)=[tagattr='type:text' width=1in just=L] style(header)=[background = lightgrey]; 
			define genericname/ display "Generic Name" style(column)=[just=L] style(header)=[background = lightgrey];
			%if %str("&optionalvars") ne %str("") %then %do;
				%do x = 1 %to %sysfunc(countw(&optionalvars));
					define %scan(&optionalvars, &x)/ %if %lowcase("%scan(&optionalvars, &x)") = "brandname" %then %do;
													  display "Brand Name" style(column)=[just=L] style(header)=[background = lightgrey];
													 %end;
													 %else %do;
													  display "%scan(&optionalvars, &x)" style(column)=[just=L] style(header)=[background = lightgrey];
													 %end; 
				%end;
			%end;
			
			compute before header / style=[backgroundcolor=darkgray color = black just=C font_weight=bold bordertopcolor=black borderbottomcolor=black];
			length text $100;
				text = header;
				num = 100;
				line text $varying. num;
			endcomp;
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black tagattr="wrap:yes"];
			line "&apptitle.";
			endcomp;
		run;
	%mend appendixNDC;

	/**************************************************/
	/* Create NDC Reports - Generic and Brand Names   */
	/**************************************************/
	%macro appendixNDC_GenBr(_data=, _rptlabel=, _tab=);

		ods excel options(sheet_name= "&_tab." tab_color='purple' sheet_interval="table"  flow="tables" row_heights='50');
		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);

		proc sort data=&_data nodupkey out=&_data._NDC_GenBr(keep=appendix_sort header_sort header genericname 
																%if %varexist(&_data,brandname) = 1 %then %do; brandname %end; 
														   );
		by appendix_sort header_sort genericname %if %varexist(&_data,brandname) = 1 %then %do; brandname %end; ;
		run;
	
		proc report data =  &_data._NDC_GenBr nofs nowd spanrows missing headskip
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			
			columns (header genericname %if %varexist(&_data,brandname) = 1 %then %do; brandname %end;);
			define header /order noprint order=data ' ';
			define genericname/ display "Generic Name" style(column)=[width=2.5in just=L] style(header)=[background = lightgrey];
			%if %varexist(&_data,brandname) = 1 %then %do;
			 define BrandName/ display "Brand Name" style(column)=[width=1.5in just=L] style(header)=[background = lightgrey];
			%end;
			
			compute before header / style=[backgroundcolor=darkgray color = black just=C font_weight=bold bordertopcolor=black borderbottomcolor=black];
			length text $100;
				text = header;
				num = 100;
				line text $varying. num;
			endcomp;
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black tagattr="wrap:yes"];
			line "&apptitle.";
			endcomp;
		run;
	%mend appendixNDC_GenBr;

	/********************************************/
	/* Create Diagnosis and Procedure Reports   */
	/********************************************/	
	%macro appendixDXPX(_data=, _rptlabel=, _tab=);

		proc sort data=&_data nodup;
			by appendix_sort header_sort code1;
		run;

		proc contents data = &_data noprint
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
		
		ods excel options(sheet_name= "&_tab." tab_color='purple' sheet_interval="table"  flow="tables" row_heights='50');
		ods proclabel = "&_tab.";
		%let apptitle  =  %bquote(&_tab.. &_rptlabel.);

		proc report data =  &_data nofs nowd spanrows missing headskip
			style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
			style(report)=[rules=none frame=box cellpadding =1.75pt];
			
			columns (codeform header code1 descrip codecat1 codetype1 &optionalvars.);
			define header /order noprint order=data ' ';
			define code1 / display "Code" style(column)=[tagattr="type:String" width=.75in just=L] style(header)=[background = lightgrey];
			define descrip/ display "Description" style(column)=[just=L] style(header)=[background = lightgrey];
			define codecat1/ display "Code Category" style(column)=[width=.75in just=L] style(header)=[background = lightgrey];	
			define codetype1/ display "Code Type" style(column)=[width=.75in just=L] style(header)=[background = lightgrey];		
			%if %str("&optionalvars") ne %str("") %then %do;
				%do x = 1 %to %sysfunc(countw(&optionalvars));
					define %scan(&optionalvars, &x)/ display "%scan(&optionalvars, &x)" style(column)=[just=L] style(header)=[background = lightgrey];
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
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black tagattr="wrap:yes"];
				line "&apptitle.";
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
	
	/*Trick excel to create new sheet*/
	ods startpage=now;
	ods excel options(sheet_interval="table");
	ods exclude _all_;
	data _null_;
	file print;
	put _all_;
	run;
	ods select all;
	ods startpage=no;
	/*Added to prevent PDF pagebreak, may need to be removed when adding more tables/figures*/

    ods excel options(sheet_name="Appendix A" tab_color='purple');
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

        compute after / style=[background=white just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black cellheight=1.15in nobreakspace=off];
        line "^{super 1}Participating Data Partners include &dpnamelist.";
        line "^{super 2}End Date represents the earliest of: (1) query end date, or (2) most recent year-month of data for which all of a Data Partner's data tables (enrollment, dispensing, etc.) have at least 80% of the record count relative to the prior month.";
        endcomp;
    run;
	

***************************************************************************************************;
* Geographic and Other Appendices                                         
***************************************************************************************************;
    %isdata(dataset=appendixreport);
    %if %eval(&nobs.>0) %then %do;
		proc sql noprint;
		select report, type, ord, tag, appendix, title
		into  :reports separated by "*", 
			  :report_types separated by "*", 
			  :lettercounts separated by "*", 
			  :report_tags separated by "*", 
			  :appendices separated by "*", 
			  :labels separated by "*"
		from appendixreport;
		quit;
		
		proc sql noprint;
		select compress(tabnum,,'ka'), tabnum, appendixtype, caption, count(*)
		into  :indata separated by "*", 
			  :appendix separated by "*",
			  :type separated by "*", 
			  :title separated by "*",
			  :appendixcnt
		from tableofcontents
		where appendixtype is not missing;
		run;

	
			%do p=1 %to %eval(&appendixcnt.);
				%let _indata = %scan(&indata., &p, %str(*));				
				%let _type = 	%scan(&type., &p., %str(*));				
				%let _appendix = 	%scan(&appendix., &p., %str(*));			
				%let _title =  %scan(%bquote(&title.), &p.,%str(*));					
				%if %index(%upcase(&_type.),GEOG) %then %do;
					%appendixGEOG(_data=&_type., _rptlabel=%bquote(&_title.), _tab=&_appendix.);
				%end;
				%else %if "%upcase(&_type.)" = "APPENDIXDXPX"  %then %do;
					%appendixDXPX(_data=&_indata., _rptlabel=%bquote(&_title.), _tab=&_appendix.);
				%end;
				%else %if "%upcase(&_type.)" = "APPENDIXNDC_GENBR"  %then %do;
					%appendixNDC_GenBr(_data=&_indata., _rptlabel=%bquote(&_title.), _tab=&_appendix.);
				%end;
				%else %if "%upcase(&_type.)" = "APPENDIXNDC"  %then %do;
					%appendixNDC(_data=&_indata., _rptlabel=%bquote(&_title.), _tab=&_appendix.);
				%end;
			%end;
	%end;


    %put =====> END MACRO: output_appendices ;

%mend output_appendices;
