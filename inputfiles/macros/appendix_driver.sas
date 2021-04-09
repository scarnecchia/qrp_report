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
*   -appendixreport: dataset containing appendix information for appendix_output.sas
*   -datasets containing data to be output in appendix_output.sas
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
    /* Create HDPS Var Info appendices                                                           */
    /*********************************************************************************************/
    /* Create appendix for each unique runid periodid combination */	
	%do n = 1 %to &numrunid.;
      %let runid = %scan(&runidlist, &n); 
	  %do periodid = %eval(&look_start.) %to %eval(&look_end.);
	    
		/* Flag to indicate if an HDPS table exists */
		%let hdps_found = 0;
		
	    %isdata(dataset=&runid._agghdps_&periodid.);
        %if %eval(&nobs.>0) %then %do;
		  %let hdps_found = 1;
		  
	      /* Determine the psestimategrps on the agghdps file */
	       proc sql noprint;
	         select count(distinct(psestimategrp)) into: num_psgrps trimmed
		     from repdata.&runid._varinfo_aggregate_&periodid.;
		     
		     select distinct(rank_variable)
          		   ,psestimategrp
				   ,topnhdps
			   into: rank1 - :rank&num_psgrps.
			        ,:psestimate1 - :psestimate&num_psgrps.
					,:topnhdps1 - :topnhdps&num_psgrps.
		     from repdata.&runid._varinfo_aggregate_&periodid.;
		   quit;
		   
		   %do ps = 1 %to &num_psgrps.;
		     /* Output one dataset per Appendix */
			 %if %eval(&num_psgrps.) > 1 %then %do;
			   %let tableid = %upcase(&tableletter.)&ps.;
			 %end;
			 %else %do;
			   %let tableid = %upcase(&tableletter.);
			 %end;
			  
		     data appendix&tableid.;
			   set repdata.&runid._varinfo_aggregate_&periodid. (where = (psestimategrp = "&&psestimate&ps."));
			 run;
		   
	         %addtotoc(tabnum = Appendix &tableid., 
		  	  	       caption = %bquote(Top &&topnhdps&ps. codes ranked by &&rank&ps. selected by the high dimensional propensity score algorithm, by Data Partner; &&psestimate&ps.),
		  	  	       appendixtype = appendixhdps);
		   %end;
	    %end;
	  %end;
	  /* Increment table count on last runid if HDPS Var Info appendix was output */
	  %if &n. = &numrunid. and &hdps_found. = 1 %then %do;
		%let tablecount = %eval(&tablecount + 1);
	  %end;
	%end;

    /*********************************************************************************************/
    /* Weight Distribution appendices                                      			 			 */
    /*********************************************************************************************/	
	%isdata(dataset=aggwd);
	%if &nobs > 0  and &numl2comparisons > 0 %then %do;

    /* Loop through all order values */
    %do corder = 1 %to &numl2comparisons;

		data _null_;
            set l2comparisonfile(where=(order=&corder.));
            call symputx('runid', runid);
            call symputx('analysisgrp', analysisgrp);
        run;

        proc sql noprint;
        	/*extract QRP input file associated with analysisgrp*/
            select distinct strip(file) into: pscsfile trimmed
            from pscs_masterinputs
            where analysisgrp = "&analysisgrp." and runid = "&runid";
        quit;

         %if &pscsfile = stratificationfile | &pscsfile = iptwfile %then %do;


                %let outputdistweight = Y;
                %if &pscsfile = stratificationfile %then %do;
                    data _null_;
                        set infolder.&&&runid._stratificationfile(where=(lowcase(analysisgrp)="&analysisgrp."));
                        if missing(strataweight) then do;
                        	call symputx('outputdistweight', 'N');
                        end;
                        else do;
                            call symputx('weightdisttitle', 'Propensity Score Stratum');
					    	if upcase(strataweight)= 'ATE' then call symputx("weightschemelong","Average Treatment Effect (ATE)");
                            else if upcase(strataweight)= 'ATT' then call symputx("weightschemelong","Average Treatment Effect in the Treated (ATT)");
                        end;
                        call symputx('weightdisttitle', 'Propensity Score Stratum');
                    run;
                %end;
                %else %if &pscsfile = iptwfile %then %do;
                    %let weightdisttitle= Inverse Probability of Treatment;
                    data _null_;
                        set infolder.&&&runid._iptwfile(where=(lowcase(analysisgrp)="&analysisgrp."));
                            if upcase(ipweight)= 'ATE' then call symputx("weightschemelong","Average Treatment Effect (ATE)");
                            else if upcase(ipweight)= 'ATES' then call symputx("weightschemelong","Average Treatment Effect, Stabilized (ATES)");
                            else if upcase(ipweight)= 'ATT' then call symputx("weightschemelong","Average Treatment Effect in the Treated (ATT)");
                    run;
                %end;

                %if &outputdistweight. = Y %then %do;

                %do periodid = %eval(&look_start) %to %eval(&look_end);

                /* Assign numeric suffix associated with look number to Appendix if there are multiple looks */
                %let look = ;
                %let looktab = ;
                %if %eval(&look_end.) > %eval(&look_start.) %then %do;
                   %let look = &periodid.;
                   %let looktab = .&periodid;
                %end;

                %let analysisgrplabel = ;
                %isdata(dataset=labelfile);
                %if &nobs > 0 %then %do;
                proc sql noprint;
		        select c.label 
		        into :analysisgrplabel trimmed
		        from (select a.*, b.label
		        	  from aggwd a left join labelfile(where=(labeltype='grouplabel')) b
		              on a.analysisgrp = b.group
		              where a.analysisgrp = "&analysisgrp" and b.runid = "&runid") as c;
		    	quit;
		    	%end;

		    	%if %length(&analysisgrplabel) = 0 %then %let analysisgrplabel = &analysisgrp;

                data weightdistribution;
                    set aggwd(where=(analysisgrp="&analysisgrp." and runid="&runid" and time=&periodid));
                    keep analysisgrp dpidsiteid N min max mean sd time;
                run;

                /* Duplicate rows may exist when multiple MPs are specified, need to de-dup on MP and dpID */
                proc sort data = weightdistribution nodupkey;
                	by time dpidsiteid;
                run;

                %isdata(dataset=weightdistribution);
                %if &nobs > 0 %then %do;
                /*N, min, max*/
                proc means data=weightdistribution nway noprint;
                    var N min max;
                    where not missing(min) and not missing(max) and not missing(mean) and not missing(sd);
                    output out=part1(drop=_:) sum(N)=n min(min)=min max(max)=max;
                run;

                /*Mean*/
                proc means data=weightdistribution nway noprint;
                    var mean;
                    weight N;
                    where not missing(min) and not missing(max) and not missing(mean) and not missing(sd);
                    output out=part2(drop=_:) mean(mean)=mean;
                run;

                /*SD*/
                proc transpose data=weightdistribution(where=(not missing(min) and not missing(max) and not missing(mean) and not missing(sd))) out=sd(drop=_name_) prefix=_sd_;
                    id dpidsiteid;
                    var sd;
                run;
                proc transpose data=weightdistribution(where=(not missing(min) and not missing(max) and not missing(mean) and not missing(sd))) out=n(drop=_name_) prefix=_ncount_;
                    id dpidsiteid;
                    var n;
                run;

                options mergenoby = nowarn;
                data part3;
                    merge sd n;

                    array npts(*) _ncount_:;
                    array stddev(*) _sd_:;
                           
                    weighted_std = 0;
                    std = 0;
                    count = 0;

                    totpts = sum(of _ncount_:);

                    do i = 1 to dim(npts);
                    ** Calculate weighted standard deviation;
                        if ^missing(stddev(i)) then weighted_std = weighted_std + (stddev(i)**2)*(npts(i) - 1);
                        if ^missing(stddev(i)) then count = count + 1 ;
                    end;

                    ** Calculate pooled standard deviation;
                    if ^missing(weighted_std) AND (totpts gt 0) then sd = sqrt(divide(weighted_std, (totpts - count)));
                    else sd = .;
                          
                    keep sd;
                run;

                data aggdistribution;
                    merge part1 part2 part3;
                run;

                options mergenoby = warn;

                %if %eval(&look_end - &look_start) = 0 or &periodid = 1 %then %tableletter();
                %isdata(dataset=repdata.appendix&tableletter.&look.)
                %if &nobs < 1 %then %do;
                data repdata.appendix&tableletter.&look.;
                	length dpidsiteid $10 nchar $20;
                    set aggdistribution(in=a) weightdistribution;
                    if a then dpidsiteid="Aggregated";
                    if missing(n) then Nchar='N/A';
                    else Nchar=strip(put(n,comma12.));
                    if n = 0 then do;
                    	min=.z;
                    	max=.z;
                    	mean=.z;
                    	sd=.z;
                    end;
                    drop n;
                    rename nchar=n;
                run;

                proc sort data=repdata.appendix&tableletter.&look.;
                    by dpidsiteid;
                run;

				%addtotoc(tabnum= Appendix %upcase(&tableletter.&looktab.), 
					  caption = %bquote(Distribution of &weightdisttitle. Weights for &analysisgrplabel., by Data Partner, Weight: &weightschemelong.),
					  appendixtype = appendixWeightDist);
                %end; /* Nobs > 0 repdata.appendix&tableletter.&look */

                %end; /* Nobs > 0 weightdistribution */

                %end; /* periodid */

              %end; /* &pscsfile = stratificationfile | &pscsfile = iptwfile */

              proc datasets lib=work nolist;
				delete part: aggdistribution sd n weightdistribution;
			  quit;

            %end;/* Outputweightdist = Y */

        %end; /* corder */

	    proc datasets lib=work nolist;
			delete aggwd;
		quit;

	%end; /* &nobs > 0  and &numl2comparisons > 0 */
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
		
		%if %eval(&geog_cb.>0)%then %do;
			%tableletter(); 	
			%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
					  caption = %bquote(List of States and Territories Included in Each Census Bureau Region),
					  appendixtype = appendixGEOG);
			proc sql noprint;
				create table Appendix&tableletter. 
				(region char(10), staterri char(250));
				insert into Appendix&tableletter.
					values("Northeast","Connecticut, Maine, Massachusetts, New Hampshire, Rhode Island, Vermont, New Jersey, New York, Pennsylvania")
					values("Midwest","Illinois, Indiana, Michigan, Ohio, Wisconsin, Iowa, Kansas, Minnesota, Missouri, Nebraska, North Dakota, South Dakota")
					values("South",	"Delaware, District of Columbia, Florida, Georgia, Maryland, North Carolina, South Carolina, Virginia, West Virginia, Alabama, Kentucky, Mississippi, Tennessee, Arkansas, Louisiana, Oklahoma, Texas")
					values("West","Arizona, Colorado, Idaho, Montana, Nevada, New Mexico, Utah, Wyoming, Alaska, California, Hawaii, Washington, Oregon")
					values("Other","Northern Mariana Islands, Marshall Islands, Puerto Rico, US Virgin Islands, American Samoa, Micronesia, Guam, Palau")
					values("Missing","Missing")
					values("Invalid","Recorded geographic location does not match any identifiers per the Sentinel Common Data Model definition");
			quit;
		%end;
	
		%if %eval(&geog_hhs.>0)%then %do;
			%tableletter(); 	
			%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
					  caption = %bquote(List of States and Territories Included in Each Health and Human Services (HHS) Region),
					  appendixtype = appendixGEOG);
			proc sql noprint;
				create table Appendix&tableletter. 
					(region char(10), staterri char(200));
				insert into Appendix&tableletter.
					values("Region 01",	"Connecticut, Maine, Massachusetts, New Hampshire, Rhode Island, Vermont")
					values("Region 02",	"New Jersey, New York, Puerto Rico, Virgin Islands")
					values("Region 03",	"Delaware, Maryland, Pennsylvania, Virginia, West Virginia, District of Columbia")
					values("Region 04",	"Alabama, Florida, Georgia, Kentucky, Mississippi, North Carolina, South Carolina, Tennessee")
					values("Region 05",	"Illinois, Indiana, Michigan, Minnesota, Ohio, Wisconsin.")
					values("Region 06",	"Arkansas, Louisiana, New Mexico, Oklahoma, Texas")
					values("Region 07",	"Iowa, Kansas, Missouri, Nebraska")
					values("Region 08",	"Colorado, Montana, North Dakota, South Dakota, Utah, Wyoming")
					values("Region 09",	"Arizona, California, Hawaii, Nevada, American Samoa, Federated States of Micronesia, Guam, Palau")
					values("Region 10",	"Alaska, Idaho, Oregon, Washington")
					values("Region 11",	"Northern Mariana Islands, Marshall Islands")
					values("Missing", "Missing")
					values("Invalid", "Recorded geographic location does not match any identifiers per the Sentinel Common Data Model definition");
			quit;
		%end;
	%end;

    /*********************************************************************************************/
    /* Create appendices based on the data in the AppendixFile                                   */
    /*********************************************************************************************/	
    %isdata(dataset=appendixfile);
    %if %eval(&nobs.>0) %then %do;
	
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
			%if %sysfunc(fileexist(&INPUT.&eachCodeFile..xlsx)) & %str("&eachCodeFile") ne %str("") %then %do;
				libname codes XLSX "&INPUT.&eachCodeFile..xlsx";	
				/* Resume writing to log */
				proc printto log="&OUTPUT.qrp_report_log.log";
				run;
				
				%do k = 1 %to %sysfunc(countw(&eachCodelist));
				
					%if %xlsx_exist(codes,%scan(&eachCodelist,&k)) %then %do;
						%let optionalvars = ;
						proc sql noprint;
							select name
							into : optionalvars separated by ' '
							from dictionary.columns
							where libname='CODES' and memname=%upcase("%scan(&eachCodelist,&k)")
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
							%if %sysfunc(exist(_&_type._&i))=0 %then %do;
								data _&_type._&i.;
								 set _%scan(&eachCodelist,&k);
								run;
							%end;
							%else %do;
								proc sql noprint undo_policy=none;
								create table _&_type._&i. as
								select * from _&_type._&i.
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
		%if %sysfunc(exist(_&_type._&i)) %then %do;
			proc datasets lib=work nolist;
				modify _&_type._&i;
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
			
			%if %varexist(_&_type._&i.,ndc)>0 %then %do;
				%tableletter(); 
				%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
						  caption = %bquote(List of Generic and Brand Names of Medical Products Used to Define &apptitle. in this Request),
						  appendixtype = appendixNDC_GenBr);
				%addtotoc(tabnum= Appendix %upcase(&tableletter.).1, 
						  caption = %bquote(List of National Drug Codes (NDCs) for Medical Products Used to Define &apptitle. in this Request),
						  appendixtype = appendixNDC);
			    data Appendix&tableletter.;
				 set _&_type._&i.;
				run; 
			%end;
			%else %do;
				%tableletter();		
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
								from _&_type._&i.;  
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

				/* Dynamic Assignment of labels to macro variable for Diagnosis/Procedure Appendices */
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
				%addtotoc(tabnum= Appendix %upcase(&tableletter.), 
						  caption = %bquote(List of &_label1. Codes Used to Define &apptitle. in this Request),
						  appendixtype = appendixDXPX);
			    data Appendix&tableletter.;
				 set _&_type._&i.;
				run; 
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
