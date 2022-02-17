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
	%isdata(dataset=agghdps);
    %if &nobs > 0 and &numl2comparisons > 0 %then %do;
	   /* Rank hdps vars */
	   proc sort data = agghdps;
		  by dpidsiteid psestimategrp analysisgrp subgroup subgroupcat periodid descending ranking;
	   run;
		
	   data agghdps;
	     set agghdps;
	     by dpidsiteid psestimategrp analysisgrp subgroup subgroupcat periodid descending ranking;
	     hdpsnum+1;
	     if first.periodid then hdpsnum = 1;
	   run;

        /*loop through each periodid*/
	    %do periodid = %eval(&look_start.) %to %eval(&look_end.);

        /* Loop through each ANALYSISGRP and determine if HDPS was used */
        %do corder = 1 %to &numl2comparisons;

            data _null_;
                set l2comparisonfile(where=(order=&corder.));
                call symputx('runid', runid);
    		  	call symputx('psestimategrp', psestimategrp);
    		  	call symputx('unique_psestimate',unique_psestimate);
    		  	if missing(topnhdps) then call symputx('topnhdps',25);
    		  	else call symputx('topnhdps',topnhdps);
    			call symputx('analysisgrp', analysisgrp);
            run;

            /* Set default values */
		    %let pscsfile = ;
		    %let hdps = N;
            %let rank = ;
		  
            data _null_; 
                set infolder.&&&runid._psestimationfile(where=(lowcase(psestimategrp)="&psestimategrp."));
                call symputx('HDPS',hdps);
                if missing(ranking) or lowcase(ranking) = 'exp_assoc' then call symputx('rank','Exposure Association');
                else if lowcase(ranking) = 'bias' then call symputx('rank','Bias Potential');
                else call symputx('rank','Outcome Association');			 
            run;
	  
	        %if &hdps. = Y %then %do;
                
                /*Assign labels*/
                %let psestimategrplabel = &psestimategrp.;
                %let analysisgrplabel = &analysisgrp.;
                %if &labelfileexists. = Y %then %do;
                    proc sql noprint;
                        select label 
	                     into :psestimategrplabel trimmed
	                     from labelfile(where=(labeltype='grouplabel' and group ="&psestimategrp" and runid = "&runid."));
                        select label 
	                     into :analysisgrplabel trimmed
	                     from labelfile(where=(labeltype='grouplabel' and group ="&analysisgrplabel" and runid = "&runid."));
                    quit;
                %end;


                /* Loop for each subgroup subgroupcat combination */
                proc sort nodupkey data = pscs_masterinputs (where = (lowcase(analysisgrp) = "&analysisgrp" and (missing(subgroup) | reestimateps = 'Y'))) out = _subgrp;
                    by subgrouporder subgroupcatorder;
                run;

                %isdata(dataset=_subgrp);
                %let numsubgroup = &nobs.;
                %do sub = 1 %to &numsubgroup.;

                    /*skip overall table if unique_psestimate >1*/
                    %if &sub. = 1 & %eval(&unique_psestimate.>1) %then %goto skiphdps;

                    *assign titlesuffix, subgroup, subgroupcat, group label (psestimategrp vs analysisgrp) and where clause to subset agghdps;
                    %let titlesuffix = ;
                    %let wherecl = ;
                    %let grouplabel = ;
                    %let subgroup = ;
                    %let subgroupcat = ;
                    data _null_;
                        set _subgrp;
                        if _n_ = &sub. then do;
                            call symputx('subgroup', subgroup);
                            call symputx('subgroupcat', subgroupcat);
                            if subgroup ne '' then do;
                                call symputx('titlesuffix', cat(', ',strip(tabletitle), ": ", strip(subgroupcatlabel)));
                                call symputx('wherecl', %str(analysisgrp = "&analysisgrp.")); 
                                call symputx('grouplabel', %quote("&analysisgrplabel")); 
                            end;
                            else do;
                                call symputx('wherecl', %str(psestimategrp = "&psestimategrp."));
                                call symputx('grouplabel', %quote("&psestimategrplabel")); 
                            end;
                        end;
                    run;

    		        /* Subset data and confirm data exists on agghdps for desired psestimategrp or analysisgrp, runid, periodid, subgroup, subgroupcat*/
                    data _temphdps(drop=hdpsnum);
                        set agghdps (where = (&wherecl. and runid = "&runid." and periodid = &periodid. and subgroup = "&subgroup." and subgroupcat = "&subgroupcat." and hdpsnum le &topnhdps.));
                        /*round ranking to 3 decimals*/
                        format ranking 8.3;
                        ranking = round(ranking, .001);
	  	            run;		

                    %isdata(dataset=_temphdps);
			        %if &nobs. > 0 %then %do;
			            /* Increment table letter when periodid equals look start or subgroup is populated*/
                        %if (%eval(&periodid. = &look_start.) and &sub. = 0) or &sub. > 0 %then %tableletter(); 
			       
    		            /* Assign numeric suffix associated with table number*/
                        %let look = %upcase(&tableletter.);
                        %let looktab = %upcase(&tableletter.);
                        %if %eval(&look_end.) > %eval(&look_start.) %then %do;
                          %let look = %upcase(&tableletter.)&periodid.;
                          %let looktab = %upcase(&tableletter.).&periodid;
                        %end;
    	  	           
    			        /* Save to repdata folder */
                        proc datasets library = work;
                            copy out=repdata memtype=data;
                            select _temphdps(memtype=data);
                        quit;
                        proc datasets library = repdata;
                            change _temphdps = appendix&look;
                        quit; 
                           
                        /*add to tabe of contents*/
      	                %addtotoc(tabnum = Appendix &looktab., 
        	         	          caption = %bquote(Top &topnhdps. Codes Ranked by &rank. Selected by the High Dimensional Propensity Score Algorithm, by Data Partner (DP); &grouplabel.&titlesuffix.),
        	         	          appendixtype = appendixhdps);
                   %end; /* hdps data for runid and psestimategrp/analysisgrp */

               %skiphdps:
			   %end; /* subgroup loop */
	       %end; /* HDPS */
	    %end; /* comparison file order */
        %end; /* periodid */
    %end; /* L2 with HDPS*/

    /*********************************************************************************************/
    /* Weight Distribution appendices                                      			 			 */
    /*********************************************************************************************/	
	%isdata(dataset=aggwd);
	%if &nobs > 0 and &numl2comparisons > 0 %then %do;
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
            where analysisgrp = "&analysisgrp." and runid = "&runid" and missing(subgroup);
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
				
				 /* Loop for each subgroup subgroupcat combination */
				proc sort nodupkey data = pscs_masterinputs (where = (lowcase(analysisgrp) = "&analysisgrp" and not missing(subgroup))) out = _subgrp;
			      by subgroup;
                run;
			    
				%let subgrouplist =;
				%let numsubgroup = 0;
				%let subgroup = ; 
				%let titlesuffix = ;
				
                %isdata(dataset=_subgrp);
				%let numsubgroup = &nobs.;
                %if %eval(&nobs.>0) %then %do;
                    proc sql noprint;
                        select subgroup 
                        into :subgrouplist separated by ' '
                        from _subgrp;
                    quit;
                %end;
				
				%do sub=0 %to &numsubgroup.;  *Note: 0 is for full analysis;
				  %if &sub. > 0 %then %do; 
				     %let subgroup = %scan(&subgrouplist, &sub.);
                     %let titlesuffix = %str(, &subgroup.);					 
				  %end;
				  
                  %let subcategorization=; *the list of categorization;
				  
				  /* Identify subgroup categories */	
		          proc sort nodupkey data = pscs_masterinputs (where = (lowcase(analysisgrp) = "&analysisgrp" and subgroup = "&subgroup.")) out = _subgrp_cat;
			        by subgroupcat;
                  run;
			      
                  %isdata(dataset=_subgrp_cat);
                  %if %eval(&nobs.>0) %then %do;
                      proc sql noprint;
                        select count(*)
						      ,subgroupcat 
                        into :numsubcat
						    ,:subcategorization separated by ' '
					    from _subgrp_cat;
                      quit;
                  %end;
				  
				  %do cat=1 %to &numsubcat.; 
                    %if %str(&subgroup.) = %str() %then %do; 
					   %let subgroupcat = ; 
					%end;
					%else %do; 
					   %let subgroupcat = %scan(&subcategorization., &cat., ' '); 
					%end;
					
                    data weightdistribution;
                        set aggwd(where=(analysisgrp="&analysisgrp." and runid="&runid" and periodid=&periodid and subgroup = "&subgroup" and subgroupcat = "&subgroupcat."));
                        keep analysisgrp subgroup subgroupcat dpidsiteid N min max mean sd periodid;
                    run;
				    
                    /* Duplicate rows may exist when multiple MPs are specified, need to de-dup on MP and dpID  */
                    proc sort data = weightdistribution nodupkey;
                    	by periodid dpidsiteid subgroup subgroupcat;
                    run;
					
                    %isdata(dataset=weightdistribution);
                    %if &nobs > 0 %then %do;
                      /*N, min, max */
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
					  
					  data appendixsubgroup_&sub._&cat.;
					    length dpidsiteid $10;
                        set aggdistribution(in=a) 
					   	    weightdistribution;
                        if a then do;
						  dpidsiteid="Aggregated";
						  subgroup = "&subgroup.";
						  subgroupcat = "&subgroupcat.";
						  periodid = "&periodid";
						  analysisgrp = "&analysisgrp.";
						end;
					  run;
						
					%end; /* Nobs > 0 weightdistribution */
                  %end; /* Subgroup Categorization */
	
                  /* Increment table letter when periodid equals look start or subgroup is populated*/
				  %if (%eval(&periodid. = &look_start.) and &sub. = 0) or &sub. > 0 %then %tableletter(); 
				  
				  /* Stack appendix data by subgroup */
                  %isdata(dataset=repdata.appendix&tableletter.&look.)
                  %if &nobs < 1 %then %do;
                     data repdata.appendix&tableletter.&look.;
					     length nchar $20;
                         set appendixsubgroup_&sub._:;
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
				     	  caption = %bquote(Distribution of &weightdisttitle. Weights for &analysisgrplabel. &titlesuffix., by Data Partner (DP), Weight: &weightschemelong.),
				     	  appendixtype = appendixWeightDist);
                  %end; /* Nobs > 0 repdata.appendix&tableletter.&look */
                  %end; /* subgroup */
				%end;  /* periodid */
              %end; /* &pscsfile = stratificationfile | &pscsfile = iptwfile */

              proc datasets lib=work nolist;
				delete part: aggdistribution sd n weightdistribution appendixsubgroup:;
			  quit;

            %end;/* Outputweightdist = Y */

        %end; /* corder */

	    proc datasets lib=work nolist;
			delete aggwd;
		quit;

	%end; /* &nobs > 0  and &numl2comparisons > 0 */

    /*********************************************************************************************/
    /* Type 6 Computed Start Marketing Date                                                      */
    /*********************************************************************************************/		
    %if &reporttype. = T6 %then %do;

        /*Format Computed Start Marketing Date and apply group labels/sort order*/
        data appendixb;
            set agg_t6_productsdates(keep=runid dpidsiteid group computedstartmarketingdate);
                format cdate $10.;
                if missing(computedstartmarketingdate) then cdate = 'N/A';
                else cdate = put(computedstartmarketingdate, mmddyy10.);
                drop computedstartmarketingdate;
        run;

        proc sql noprint undo_policy=none;
      	     create table appendixb as
      	     select distinct a.dpidsiteid
                  , a.cdate
                  , b.order
	  		     %if &labelfileexists. = Y %then %do;
  	     	      , case when not missing(c.label) then c.label 
                    else a.group end as grouplabel
                 %end;
  	     	     %else %do;
          	     ,a.group as grouplabel
          	     %end;
  	         from appendixb a 
    	     inner join inputfiles b
      	     on a.runid = b.runid and a.group = b.group 
    	     %if &labelfileexists. = Y %then %do;
      	       left join labelfile(where=(labeltype='grouplabel')) c
      	       on a.group = c.group and a.runid = c.runid
      	    %end;
            ;
        quit;

        /*Check observations exist - if no product groups are requested in report, the appendix will not be produced*/
        %isdata(dataset=appendixb);
        %if %eval(&nobs.>0) %then %do;
    		%tableletter(); 	
            %addtotoc(tabnum= Appendix %upcase(&tableletter.), 
    				  caption = %bquote(Computed Start Marketing Dates for Each Cohort at Each Data Partner (DP)),
    				  appendixtype = APPENDIXT6DATES);

            proc sort data=appendixb sortseq=linguistic (numeric_collation=on) out=repdata.appendix&tableletter.;
                by order dpidsiteid;
            run;

            proc datasets nowarn noprint lib=work;
                delete appendixb;
            quit;
        %end;
    %end;

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
				proc printto log="&OUTPUT.qrp_report_log&reportid..log";
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
				proc printto log="&output.qrp_report_log&reportid..log";
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
