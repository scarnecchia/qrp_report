****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: appendix_driver.sas  
* Created (mm/dd/yyyy): 02/25/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the drives the creation of the report appendices
*                                        
*  Program inputs:                                                                                   
*
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
	proc sql noprint; select count(codeform) into :codecount from _labels; quit;

	proc sql noprint;
		select codeform, codelabel
		into :uniquecodeform separated by " ",
			 :uniquecodelabel separated by "*"
		from _labels;
	quit;

	%put &uniquecodeform.; 
	%put &uniquecodelabel.;

	/* Dynamic Assignment of labels to macrovariable for Diagnosis/Procedure Appendices */
	%let _label = ;
	%let l=0;

	data _null_;
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
	run;
	%put &_label1;
	%mend getLabels;


    %isdata(dataset=appendixfile);
    %if %eval(&nobs.>0) %then %do;

    /*********************************************************************************************/
    /* Initialize empty appendixreport table                                                     */
    /*********************************************************************************************/

    data appendixreport;
        length report $20 type $12 ord $3 tag $70 appendix $15 titletype $70 title $1000;
        call missing(report, type, ord, tag, appendix, titletype, title);
    run;
    %let tablecount = 2;
	
	libname codes XLSX "&INFOLDER.codes.xlsx";	
	
	proc sort data = appendixfile;
	by order headerorder;
	run;

	proc sql noprint; 
		select max(order), count(codestab)
		into :maxapporder, :codestabcnt
		from appendixfile;
	%let codestabcnt=&codestabcnt.; 
		select codestab
		into :codestab1-:codestab&codestabcnt.
		from appendixfile;
	quit; 
	
	%let var_lis = BrandName Form Route Strength Unit; /*variable list for NDC*/
	
	/* Create codelist appendices */
	%do i = 1 %to &maxapporder.;
	 
		proc sql noprint;
			select codestab, count(distinct headerorder), 
			case when (header is missing) then '@' else header end as header, appendixtype
			into :codetabs separated by "*", 
				 :headerorder, 
				 :header separated by "*",
				 :_type trimmed
			from appendixfile
			where order=&i;	
		quit;

		%do j = 1 %to &headerorder;
	   		%let eachCodeList = %scan(&codetabs, &j, %str(*));
	   		%let currHeader = %qscan(%bquote(&header.), &j, %str(*));
	   		%if &currHeader = %str(@) %then %let currHeader = ;
			
			%do k = 1 %to %sysfunc(countw(&eachCodelist));
			data _%scan(&eachCodelist,&k);
			%if %varexist(codes.%scan(&eachCodelist,&k),ndc) = 1 %then %do;
			 length brandname $1000 unit strength $50 route form $200 genericname $250 ndc $11;
			%end;
			%else %do;
			 length code1 $20 descrip $600 codetype1 $3 codecat1 $2 codeform $5;
			%end;
			 set codes.%scan(&eachCodelist,&k);
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
					code1=cats(compress(code1,' '));
					codeform = compress(strip(codecat1)||strip(codetype1), );
					keep header code1 descrip codetype1 codecat1 codeform appendix_sort header_sort;
			    %end;
			    %else %do;
					%do lds = 1 %to %sysfunc(countw(&var_lis));
					  %scan(&var_lis, &lds) = %scan(&var_lis, &lds);
					%end;
					codecat1='RX';
					ndc = cats(compress(ndc,' '));
					Strength = strip(Strength);
					keep header ndc genericname BrandName Form Route Strength Unit appendix_sort header_sort;
				%end;
			run; 
			
			%if %varexist(_%scan(&eachCodelist,&k),ndc) = 1 %then %do;
				proc sort data=_%scan(&eachCodelist,&k) nodupkey;
					by header ndc;          
				run;
			%end;
				/* Create one dataset for each AppendixOrder */
				%if &k=1 and &j=1 %then %do;
					data &_type._&i.;
					 set _%scan(&eachCodelist,&k);
					run;
				%end;
				%else %do;
					data &_type._&i.;
					 set &_type._&i. _%scan(&eachCodelist,&k);
					run;
				%end;
			%end; /*eachCodelist k-loop*/
		%end; /*headerorder j-loop*/
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
			%agg_apprptndc(_report = "&_type._&i.", _rpttyp = "&_type.", _ord = &tableletter, _titletype = &apptitle.);
			%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
			          caption = %bquote(Generic and Brand Names of Medical Products Used to Define &apptitle. in this Request));
			%addtotoc(tabnum= Appendix %upcase(&tableletter.).1, 
			          caption = %bquote(National Drug Codes (NDCs) for Medical Products Used to Define &apptitle. in this Request));
		%end;
		%else %do;
			%tableletter(); 	
			%getLabels(_indata = &_type._&i.);
			%agg_apprptdxpx(_report = "&_type._&i.", _rpttyp = "&_type.", _ord = &tableletter, _titletype = &apptitle.);
			%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
			          caption = %bquote(&_label1. Codes Used to Define &apptitle. in this Request));
		%end;		
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