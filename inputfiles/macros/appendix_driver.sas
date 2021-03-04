****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: appendix_driver.sas  
* Created (mm/dd/yyyy): 02/25/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of the report appendices
*                                        
*  Program inputs:   
*   - TABLEFILE     
*   - APPENDIXFILE                                                                           
*	-Excel file(s) containing code lists
* 
*  Program outputs:   
*   -tableofcontents: dataset containing table of contents  
*   -appendixreport: dataset containing appendix information for output_appendices.sas
*   -datasets containing data to be output in output_appendices.sas
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

%macro appendix_driver();

    %put =====> MACRO CALLED: appendix_driver;

    /*********************************************************************************************/
    /* Utility macros to add row to appendixreport file                                          */
    /*********************************************************************************************/
	%macro agg_apprptndc(_report =, _rpttyp = , _ord= , _titletype =);
    data appendixreport;
        set appendixreport end=eof;
        output;
        if eof then do;
			report = %upcase(&_report.);	
			type = %upcase(&_rpttyp.);
			ord = "&_ord";
			tag ="appendixNDC_GenBr"; 
			appendix = "Appendix %upcase(&_ord.)";
			titletype = "&_titletype.";
			title = "Generic and Brand Names of Medical Products Used to Define &_titletype. in this Request";
            output;
			tag ="appendixNDC";
			appendix = "Appendix %upcase(&_ord.).1";
			title = "National Drug Codes (NDCs) for Medical Products Used to Define &_titletype. in this Request";
            output;
        end;
    run;
	%mend agg_apprptndc;
	
	%macro agg_apprptdxpx(_report =, _rpttyp = , _ord= , _titletype =);
    data appendixreport;
        set appendixreport end=eof;
        if report ne '' then output;
        if eof then do;
			report = %upcase(&_report.);	
			type = %upcase(&_rpttyp.);
			ord = "&_ord";
			tag ="appendixDXPX";
			appendix = "Appendix %upcase(&_ord.)";
			titletype = "&_titletype.";
			title = "&_label1. Codes Used to Define &_titletype. in this Request";
            output;
        end;
    run;
	%mend agg_apprptdxpx;

	%macro agg_apprptgeog(_report =, _title =);
    data appendixreport;
        set appendixreport end=eof;
        if report ne '' then output;
        if eof then do;
			report = %upcase(&_report.);	
			type = "GEOG";
			ord = "&tableletter.";
			tag ="appendixGEOG";
			appendix = "Appendix %upcase(&tableletter.)";
			title = "List of States and Territories Included in Each &_title. Region";
            output;
        end;
    run;
	%mend agg_apprptgeog;
	
    /*********************************************************************************************/
    /* Utility macro to get appropriate PX DX label for appendix file                            */
    /*********************************************************************************************/	
	%macro getLabels(_indata=);
		/* Create labels for all codecat-codetype combinations */
		%global _label1;
		
		proc sql noprint;
					create table _labels as
						select  codeform, 
						(CASE (codeform)
						when ("DX09") then   "International Classification of Diseases, Ninth Revision, Clinical Modification (ICD-9-CM)"
						when ("DX10") then   "International Classification of Diseases, Tenth Revision, Clinical Modification (ICD-10-CM)"
						when ("PX09") then   "International Classification of Diseases, Ninth Revision, Clinical Modification (ICD-9-CM)"
						when ("PX10") then   "International Classification of Diseases, Tenth Revision, Procedural Coding System (ICD-10-PCS)"
						when ("PXC4") then   "Current Procedural Terminology, Fourth Edition (CPT-4)"
						when ("PXHC") then   "Healthcare Common Procedure Coding System, Level II (HCPCS)"
						when ("PXH3") then   "Healthcare Common Procedure Coding System, Level III (HCPCS)"
						when ("PXC2") then   "Current Procedural Terminology, Second Edition (CPT-2)"
						when ("PXC3") then   "Current Procedural Terminology, Third Edition (CPT-3)"
						when ("PXND") then   "National Drug Code (NDC)"
						when ("PXRE") then   "Revenue (RE)"
						else ""
						END) as codelabel 
						from &_indata.;  
		quit;				

		/*Remove duplicates to narrow down to the only labels present,
			to be used in the report title*/
		proc sort nodupkey data=_labels;
			by codelabel;
		run;				

		/* Get count of unique labels present */
		proc sql noprint;
			select count(codeform), codelabel
			into :codecount,
				 :uniquecodelabel separated by "*"
			from _labels;
		quit;

		%put &codecount.; 
		%put &uniquecodelabel.;

		/* Dynamic Assignment of labels to macrovariable for Diagnosis/Procedure Appendices */
		%let _label = ;
		%let l=0;

		%if %eval(&codecount) = 1 %then %do;
		/*get only label*/
			%let _label1 = %qscan(%bquote(&uniquecodelabel.), 1, %str(*));		
		%end;
		%else %if %eval(&codecount) = 2 %then %do;
		/*get both labels*/
			%let _label1 = %qscan(%bquote(&uniquecodelabel.), 1, %str(*)) and %qscan(%bquote(&uniquecodelabel.), 2, %str(*)) ;		
		%end;
		/* if more than 2 labels present*/
		%else %if %eval(&codecount) ge 3  %then %do;
		/*get first label*/
			%let _label1 = %qscan(%bquote(&uniquecodelabel.), &l+1, %str(*));		
			/* then get all other labels*/
			%do %while (&l+1 lt &codecount - 1);
				%let l = %eval(&l + 1);
				%let _label1 = &_label1, %qscan(%bquote(&uniquecodelabel.), &l+1, %str(*));
					
			%end;
			%let _label1 = &_label1, and %qscan(%bquote(&uniquecodelabel.), &codecount., %str(*));
		%end;	

		%put &_label1;
	%mend getLabels;

    /*********************************************************************************************/
    /* Utility macro to get check if a tab exists on an excel codelist file                      */
    /*********************************************************************************************/		
	%macro xlsx_exist(libname,memname);
		%local ret dsid;
		%let ret=-1;
		%let dsid = %sysfunc(open(sashelp.vmember(where=(libname=%upcase("&libname") and memname=%upcase("&memname")))));
		%if &dsid %then %do;
		  %let ret=%eval(0=%sysfunc(fetch(&dsid)));
		  %let dsid=%sysfunc(close(&dsid));
		%end;
		&ret.
	%mend xlsx_exist;

    %let tablecount = 2; /* Appendix A is tablecount 1 */
	
    /*********************************************************************************************/
    /* Create geographic location appendices if requested                                        */
    /*********************************************************************************************/		
    %isdata(dataset=tablefile);
    %if %eval(&nobs.>0) %then %do;
	
		%let geog_cb=0;
		%let geog_hhs=0;
		
		data _null_;
			set tablefile;
			if indexw(tablesub,'cb_reg') then call symputx("geog_cb",1);
			if indexw(tablesub,'hhs_reg') then call symputx("geog_hhs",1);
		run;
		%put geog_cb=&geog_cb.;
		%put geog_hhs=&geog_hhs.;
		
		%if %eval(&geog_cb.>0)%then %do;
		/* Initialize empty appendixreport table (if it does not exist) */
		%if %sysfunc(exist(appendixreport))=0 %then %do;
			data appendixreport;
				length report $20 type $12 ord $3 tag $70 appendix $15 titletype $70 title $1000;
				call missing(report, type, ord, tag, appendix, titletype, title);
			run;
		%end;
			%tableletter(); 	
			%agg_apprptgeog(_report ="GEOG_CB", _title =Census Bureau);
			%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
					  caption = %bquote(List of States and Territories Included in Each Census Bureau Region));
		%end;
	
		%if %eval(&geog_hhs.>0)%then %do;
			/* Initialize empty appendixreport table (if it does not exist) */
			%if %sysfunc(exist(appendixreport))=0 %then %do;
				data appendixreport;
					length report $20 type $12 ord $3 tag $70 appendix $15 titletype $70 title $1000;
					call missing(report, type, ord, tag, appendix, titletype, title);
				run;
			%end;
			%tableletter(); 	
			%agg_apprptgeog(_report ="GEOG_HHS", _title =%str(Health and Human Services (HHS)));
			%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
					  caption = %bquote(List of States and Territories Included in Each Health and Human Services (HHS) Region));
		%end;
	%end;

    /*********************************************************************************************/
    /* Create appendices based on the data in the AppendixFile                                   */
    /*********************************************************************************************/	
    %isdata(dataset=appendixfile);
    %if %eval(&nobs.>0) %then %do;

    /* Initialize empty appendixreport table (if it does not exist) */
	%if %sysfunc(exist(appendixreport))=0 %then %do;
		data appendixreport;
			length report $20 type $12 ord $3 tag $70 appendix $15 titletype $70 title $1000;
			call missing(report, type, ord, tag, appendix, titletype, title);
		run;
	%end;
	
	proc sort data = appendixfile;
	by order headerorder;
	run;

	proc sql noprint; 
		select max(order)
		into :maxapporder
		from appendixfile;
	quit; 
	
	/* Create codelist appendices */
	%do i = 1 %to &maxapporder.;
	 
		proc sql noprint;
			select codestab, count(distinct headerorder), 
			case when (header is missing) then '@' else header end as header, codesfile, appendixtype
			into :codetabs separated by "*", 
				 :headerorder, 
				 :header separated by "*",
				 :codesfile separated by "*",
				 :_type trimmed
			from appendixfile
			where order=&i;	
		quit;

		%do j = 1 %to &headerorder;
	   		%let eachCodeList = %scan(&codetabs, &j, %str(*));
	   		%let eachCodeFile = %scan(&codesfile, &j, %str(*));
	   		%let currHeader = %qscan(%bquote(&header.), &j, %str(*));
	   		%if &currHeader = %str(@) %then %let currHeader = ;
			
			/* Prevent library path from being written to log */
			proc printto log=log;
			run;
			%if %sysfunc(fileexist(&INFOLDER.&eachCodeFile)) %then %do;
				libname codes XLSX "&INFOLDER.&eachCodeFile";	
				/* Resume writing to log */
				proc printto log="&reportroot.output/qrp_report_log.log";
				run;
				
				%do k = 1 %to %sysfunc(countw(&eachCodelist));
				
					%if %xlsx_exist(codes,%scan(&eachCodelist,&k)) %then %do;
						%let optionalvars = ;
						proc sql noprint;
							select name
							into : optionalvars separated by ' '
							from dictionary.columns
							where libname='CODES' and memname=upcase("%scan(&eachCodelist,&k)")
							%if %varexist(codes.%scan(&eachCodelist,&k),ndc) = 1 %then %do;
							  and lowcase(name) not in ('ndc','genericname','generic_name','studyname');
							%end;
							%else %do;
							  and lowcase(name) not in ('code1','descrip','codetype1','codecat1','codeform','studyname');
							%end;
						quit;			
						%put optionalvars = &optionalvars.;
						
						data _%scan(&eachCodelist,&k);
						%if %varexist(codes.%scan(&eachCodelist,&k),ndc) = 1 %then %do;
						 length genericname $250 ndc $11;
						%end;
						%else %do;
						 length code1 $20 descrip $600 codetype1 $3 codecat1 $2 codeform $5;
						%end;
						 set codes.%scan(&eachCodelist,&k) %if %varexist(codes.%scan(&eachCodelist,&k),generic_name) = 1 %then %do; (rename=(generic_name=genericname)) %end;;
							length header $300.;
							%if %length(&currHeader) > 0 %then %do;
								header = "&currHeader.";
							%end;
							%else %if %varexist(codes.%scan(&eachCodelist,&k),studyname)>0 %then %do;
								header = studyname;
							%end;
							appendix_sort = &i;
							header_sort = &j;
							%if %varexist(codes.%scan(&eachCodelist,&k),ndc)=0 %then %do;
								code1=cats(compress(code1,' '));
								codeform = compress(strip(codecat1)||strip(codetype1), );
								keep header code1 descrip codetype1 codecat1 codeform &optionalvars. appendix_sort header_sort;
							%end;
							%else %do;
								codecat1='RX';
								ndc = cats(compress(ndc,' '));
								Strength = strip(Strength);
								keep header ndc genericname &optionalvars. appendix_sort header_sort;
								%if %index(%lowcase(&optionalvars),brand_name)>0 %then %do; 
									rename brand_name = brandname;
								%end;
							%end;
						run; 
						
						%if %varexist(_%scan(&eachCodelist,&k),ndc) = 1 %then %do;
							proc sort data=_%scan(&eachCodelist,&k) (where=(ndc ne '')) nodupkey ;
								by header ndc;          
							run;
						%end;
							/* Create one dataset for each AppendixOrder */
							%if %sysfunc(exist(&_type._&i))=0 %then %do;
								data &_type._&i.;
								 set _%scan(&eachCodelist,&k);
								run;
							%end;
							%else %do;
								proc sql noprint undo_policy=none;
								create table &_type._&i. as
								select * from &_type._&i.
								outer union corr
								select * from _%scan(&eachCodelist,&k);
								quit;
							%end;
					%end; /*exist codestab check*/
					%else %do;
						%put WARNING: (Sentinel) %scan(&eachCodelist,&k) CodesTab does not exist.;
					%end;	
				%end; /*eachCodelist k-loop*/
			%end; /*fileexist codesfile check*/
			%else %do;				
				/* Resume writing to log */
				proc printto log="&reportroot.output/qrp_report_log.log";
				run;
				%put WARNING: (Sentinel) &eachCodeFile. CodesFile does not exist.;
			%end;	
		%end; /*headerorder j-loop*/
		%if %sysfunc(exist(&_type._&i)) %then %do;
			proc datasets lib=work nolist;
				modify &_type._&i;
					format _character_;
				run;
			quit;
		
			%if &_type. = index %then %do; %let apptitle = %bquote(Exposures); %end;
			%else %if &_type. = expinc %then %do; %let apptitle = %bquote(Exposure Incidence Criteria); %end;
			%else %if &_type. = covariate %then %do; %let apptitle = %bquote(Covariates); %end;
			%else %if &_type. = censor %then %do; %let apptitle = %bquote(Exposure Censoring Criteria); %end;
			%else %if &_type. = outcome %then %do; %let apptitle = %bquote(Outcomes); %end;
			%else %if &_type. = outcomeinc %then %do; %let apptitle = %bquote(Outcome Incidence Criteria); %end;
			%else %if &_type. = inclusion %then %do; %let apptitle = %bquote(Inclusion Criteria); %end;
			%else %if &_type. = exclusion %then %do; %let apptitle = %bquote(Exclusion Criteria); %end;
			
			%if %varexist(&_type._&i.,ndc)>0 %then %do;
				%tableletter(); 
				/* Initialize empty appendixreport table (if it does not exist) */
				%if %sysfunc(exist(appendixreport))=0 %then %do;
					data appendixreport;
						length report $20 type $12 ord $3 tag $70 appendix $15 titletype $70 title $1000;
						call missing(report, type, ord, tag, appendix, titletype, title);
					run;
				%end;
				%agg_apprptndc(_report = "&_type._&i.", _rpttyp = "&_type.", _ord = &tableletter, _titletype = &apptitle.);
				%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
						  caption = %bquote(Generic and Brand Names of Medical Products Used to Define &apptitle. in this Request));
				%addtotoc(tabnum= Appendix %upcase(&tableletter.).1, 
						  caption = %bquote(National Drug Codes (NDCs) for Medical Products Used to Define &apptitle. in this Request));
			%end;
			%else %do;
				%tableletter();
				/* Initialize empty appendixreport table (if it does not exist) */
				%if %sysfunc(exist(appendixreport))=0 %then %do;
					data appendixreport;
						length report $20 type $12 ord $3 tag $70 appendix $15 titletype $70 title $1000;
						call missing(report, type, ord, tag, appendix, titletype, title);
					run;
				%end; 			
				proc sql noprint;
							create table _labels as
								select  codeform, 
								(CASE (codeform)
								when ("DX09") then   "International Classification of Diseases, Ninth Revision, Clinical Modification (ICD-9-CM)"
								when ("DX10") then   "International Classification of Diseases, Tenth Revision, Clinical Modification (ICD-10-CM)"
								when ("PX09") then   "International Classification of Diseases, Ninth Revision, Clinical Modification (ICD-9-CM)"
								when ("PX10") then   "International Classification of Diseases, Tenth Revision, Procedural Coding System (ICD-10-PCS)"
								when ("PXC4") then   "Current Procedural Terminology, Fourth Edition (CPT-4)"
								when ("PXHC") then   "Healthcare Common Procedure Coding System, Level II (HCPCS)"
								when ("PXH3") then   "Healthcare Common Procedure Coding System, Level III (HCPCS)"
								when ("PXC2") then   "Current Procedural Terminology, Second Edition (CPT-2)"
								when ("PXC3") then   "Current Procedural Terminology, Third Edition (CPT-3)"
								when ("PXND") then   "National Drug Code (NDC)"
								when ("PXRE") then   "Revenue (RE)"
								else ""
								END) as codelabel 
								from &_type._&i.;  
				quit;				

				/*Remove duplicates to narrow down to the only labels present,
					to be used in the report title*/
				proc sort nodupkey data=_labels;
					by codelabel;
				run;				

				/* Get count of unique labels present */
				proc sql noprint;
					select count(codeform), codelabel
					into :codecount,
						 :uniquecodelabel separated by "*"
					from _labels;
				quit;

				%put &codecount.; 
				%put &uniquecodelabel.;

				/* Dynamic Assignment of labels to macrovariable for Diagnosis/Procedure Appendices */
				%global _label1;	
				%let _label = ;
				%let l=0;

				%if %eval(&codecount) = 1 %then %do;
				/*get only label*/
					%let _label1 = %qscan(%bquote(&uniquecodelabel.), 1, %str(*));		
				%end;
				%else %if %eval(&codecount) = 2 %then %do;
				/*get both labels*/
					%let _label1 = %qscan(%bquote(&uniquecodelabel.), 1, %str(*)) and %qscan(%bquote(&uniquecodelabel.), 2, %str(*)) ;		
				%end;
				/* if more than 2 labels present*/
				%else %if %eval(&codecount) ge 3  %then %do;
				/*get first label*/
					%let _label1 = %qscan(%bquote(&uniquecodelabel.), &l+1, %str(*));		
					/* then get all other labels*/
					%do %while (&l+1 lt &codecount - 1);
						%let l = %eval(&l + 1);
						%let _label1 = &_label1, %qscan(%bquote(&uniquecodelabel.), &l+1, %str(*));
							
					%end;
					%let _label1 = &_label1, and %qscan(%bquote(&uniquecodelabel.), &codecount., %str(*));
				%end;					
				*getLabels(_indata = &_type._&i.);
				%agg_apprptdxpx(_report = "&_type._&i.", _rpttyp = "&_type.", _ord = &tableletter, _titletype = &apptitle.);
				%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
						  caption = %bquote(&_label1. Codes Used to Define &apptitle. in this Request));
			%end;
		%end; /*TYPE dataset exists*/ 
	%end; /*maxapporder i-loop*/

    /********************************************/
    /* delete xls_sheets file and temp datasets */
    /********************************************/
	proc datasets lib=work nolist;
		delete _:;
	quit;

    %end; /*appendixfile input file exists*/
	

    %put =====> END MACRO: appendix_driver ;

%mend appendix_driver;
