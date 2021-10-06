****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: createlibref.sas  
* Created (mm/dd/yyyy): 11/28/2017
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro creates concatenated libref from a list of DPs and a file path,
*	automatically defaults to most recent version, and checks for the existence of each folder path 
*                                        
*  Program inputs:                                                                                   
*  	-
* 
*  Program outputs:                                                                                                                                       
*  	-
* 
*  PARAMETERS: 
*   - dplist: list of DPs separated by a space
*   - dpinfofile: file containing list of DPs and optional path
*   - dataroot: location of /data folder in the standard structure /data/[version]/[dp]/msoc/ 
*   - signaturefile: signature file from which to extract DP metadata            
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

%macro createlibref(dplist=,
                    dpinfofile = , 
	    		    dataroot = ,
	   			    signaturefile = );

	**********************************************************
	macro %dynamiclibref automatically creates libnames for
	each DP based on K:/Sentinel folder structure 
	*********************************************************;
	%macro dynamiclibref(dp_list=);

		filename root "&dataroot.";
		/*Retrieve each version*/
		data files_and_folders;
			length name $50;
			drop rc did i;
			did=dopen("root");
			if did > 0 then do;
				do i=1 to dnum(did);
					name=upcase(dread(did,i));
					output;
				end;
				rc=dclose(did);
			end;
			else put 'Could not open directory';
		run;

		/*Defensive coding*/
		proc sort data=files_and_folders; 
			by descending name; 
		run; 

		/*Put name of versions into macro variable*/
		proc sql noprint;
			select lowcase(name) into: versions separated by ' '
			from files_and_folders
			where substr(upcase(name),1,1) = 'V' or substr(upcase(name),1,1) = 'B';
		quit;
		%put &versions;

		/*For each DP, confirm the existence of the directory. Only include directories that exist in the final concatenated libname*/
        %let dp_list = %lowcase(&dp_list);
		%let DpCnt = %sysfunc(Countw(&dp_list)); /*Number of DPs to loop*/
		%let VerCnt = %sysfunc(Countw(&versions)); /*Number of versions to loop*/

		%do a = 1 %to &DpCnt;
			%let DPSITEID = %scan(&dp_list,&a); /*Current DP*/
					
			/*reset in_version counter*/
			%let in_version = ;

			%do b = 1 %to &VerCnt;
				%let CurrVer = %scan(&versions,&b); /*Current version*/
				/*does directory exist for current version?*/
				%let dir = &dataroot./&CurrVer./&DPSITEID./msoc/;
					
				%let rc = %sysfunc(filename(fileref,&dir)) ;
				%if %sysfunc(fexist(&fileref)) %then %let in_version = &in_version &CurrVer;
				%else %put NOTE: The directory "&dir" does not exist ;				
			%end;
			%put The libname for &DPSITEID contains the following Package Versions: &in_version;

			%if %length(&in_version) = 0 %then %do;
				%put WARNING: There are no valid directories for DP="&DPSITEID." Check for the existence of this DP directory or designate a bypass directory path;
			%end;
			%else %do;
				/*Loop through each valid directory to create concatenated libname*/
				%let DirCnt = %sysfunc(Countw(&in_version)); /*Number of versions to include in libname*/	
				%let VerList = ;
				%do c = 1 %to &DirCnt;
					%let CurrDir = %scan(&in_version,&c); 
						%let &DPSITEID&c = &dataroot.&CurrDir./&DPSITEID./msoc/.;
						/*assign final concatenated libname*/
						%if &c = 1 %then %do;
							libname &DPSITEID ("&&&DPSITEID.&c.") access=readonly;
						%end;
						%else %do;
							libname &DPSITEID&c "&dataroot.&CurrDir./&DPSITEID./msoc/.";
							libname &DPSITEID (&DPSITEID &&DPSITEID.&c.) access=readonly;
						%end;
				%end;			
						
				/*Update signature file with VersionID*/
				%if "&signaturefile" ne "" %then %do;
				%if %sysfunc(exist(&DPSITEID..&signaturefile.)) %then %do;
					data _signature; set &DPSITEID..&signaturefile.; 
						format DP $6.;
						DP = "&DPSITEID."; 	
						where upcase(var) in ('VERID', 'REQID', 'MPVER', 'DPMINDATE', 'DPMAXDATE');
					run;	

					proc transpose data = _signature out = _signature (drop = _NAME_ rename =(col1 = ReqID  col2 = DPversion col3 = QRPversion
																							col4 = DPMINDATE col5 = DPMAXDATE));
						by DP;
						var value;
					run;

					proc append data=_signature base=dpsignature force; run;

					proc datasets nowarn noprint lib=work; delete _signature; quit;
				%end;
				%else %put NOTE: Signature file for "&DPSITEID." does not exist;
				%end;
			%end;
		%end;
	%mend dynamiclibref;

	***************************************************************
	macro %bypass_autoversion uses an input file to assign libnames
	***************************************************************;
	%macro bypass_autoversion();

		%macro wrapper();
    		%global DPCOMMALIST;
    		%let countvars = %sysfunc(Countw(%quote(&DPLIST.)));
    		%do c = 1 %to &countvars.;
    			%let word = %scan(%quote(&DPLIST),&c.);
    				%if &c. = 1 %then %do;
    					%let DPCOMMALIST = "&word.";
    				%end;
    				%else %do;
    					%let DPCOMMALIST = &DPCOMMALIST. , "&word.";
    				%end;
    		%end;
		%mend;
		%wrapper();
	
		/*Put list of DPs we are bypassing into macro variable*/

		%let bypassDPList = ;
		%let BypassCnt = 0; 

		proc sql noprint;
			select DP into: bypassDPlist separated by ' '
			from dppath
			where lowcase(DP) in (&DPCOMMALIST.);
		quit;

		/*Loop through list and assign correct libname */
		%if %length(&bypassDPList) > 0 %then %let BypassCnt = %sysfunc(Countw(&bypassDPlist)); 
		%let ModDPList = %lowcase(&DPLIST);

		%do cnt = 1 %to &BypassCnt;
			%let DPSITEID = %lowcase(%scan(&bypassDPlist,&cnt));
			data _null_;
				set dppath;
				call symputx("PATH",lowcase(strip(path)));
				where lowcase(DP) = "&DPSITEID.";
			run;		
            
            %if %soc_dirExist(&path.) %then %do;
			  /* Prevent library path from being written to log */
			     proc printto log=log;
			     run;
			
			     libname &DPSITEID "&PATH." access=readonly;
				 
			  /* Resume writing to log */
				 proc printto log="&OUTPUT.qrp_report_log&reportid..log";
				 run;
            %end;
            %else %do;
                %put ERROR: (Sentinel) Path specified in DPINFOFILE for &DPSITEID. does not exist. Package will abort.;
                %abort;
            %end;

			/*Update signature file with VersionID*/
			%if "&signaturefile" ne "" %then %do;
			%if %sysfunc(exist(&DPSITEID..&signaturefile.)) %then %do;
				data _signature; set &DPSITEID..&signaturefile.; 
					format DP $6.;
					DP = "&DPSITEID."; 	
					where upcase(var) in ('VERID', 'REQID', 'MPVER', 'DPMINDATE', 'DPMAXDATE');
				run;	

				proc transpose data = _signature out = _signature (drop = _NAME_ rename =(col1 = ReqID  col2 = DPversion col3 = QRPversion
																						col4 = DPMINDATE col5 = DPMAXDATE));
					by DP;
					var value;
				run;

				proc append data=_signature base=dpsignature force; run;

				proc datasets nowarn noprint lib=work; delete _signature; quit;
			%end;
			%else %put NOTE: Signature file for "&DPSITEID." does not exist;
			%end;

			/*Modify DPlist if additional DPs will be assigned libname automatically*/
			%if %eval(&BypassCnt) ne %eval(&NUM_DP) %then %do;
				%let ModDPList = %sysfunc(compbl(%sysfunc(transtrn(&ModDPList, &DPSITEID,))));
			%end;
		%end;

		%if %eval(&BypassCnt) ne %eval(&NUM_DP) %then %do;
			%put &ModDPList;
			%dynamiclibref(dp_list = &ModDPList);
		%end;
	%mend bypass_autoversion;

	***********
	macro calls
	***********;

	%let num_dp = %sysfunc(countw(&dplist));
    %let dplist = %lowcase(&dplist);

	%if %length(&dpinfofile.)> 0 %then %do;

        /*Create file with list of DPs where path is not missing*/
        data dppath;
            set &dpinfofile.(where=(missing(path)=0));
        run;

		%let nobs=0;
		%if %sysfunc(exist(dppath))=1 and %length(dppath) ne 0 %then %do;
			data _null_;
			dsid=open("dppath");
			call symputx("NOBS",attrn(dsid,"NLOBS"));
			run;
		%end;	

		%if %eval(&nobs.>0) %then %do;
			%bypass_autoversion();
		%end;
		%else %do;
			%dynamiclibref(dp_list = &dplist);
		%end;
	%end;
	%else %do;
		%dynamiclibref(dp_list = &dplist);
	%end;

    *save signature file and merge in maskedDP info if available;
    %if "&signaturefile" ne "" %then %do;
        %let nobs=0;
	    %if %sysfunc(exist(dpsignature))=1 %then %do;
            data _null_;
            dsid=open("dpsignature"); 
            call symputx("NOBS",attrn(dsid,"NLOBS"));
			run;
		%end;	

        %if %eval(&nobs.>0) %then %do;
            %let nobs=0;
    	    %if %sysfunc(exist(output.dpinfo))=1 %then %do;
                data _null_;
                dsid=open("output.dpinfo"); 
                call symputx("NOBS",attrn(dsid,"NLOBS"));
    			run;
    		%end;	
            %if %eval(&nobs.>0) %then %do;
                proc sql noprint undo_policy=none;
                    create table output.dpinfo as
                    select distinct y.maskedID,
                                    x.* 
                    from output.dpinfo as y
                    full join dpsignature as x
                    on x.dp = y.dp;
                quit;
            %end;
            %else %do;
                data output.dpinfo;
                    set dpsignature;
                run;
            %end;
        %end;
    %end;

	*clean-up;
	proc datasets nowarn noprint lib=work;
		delete files_and_folders list_dp dppath dpsignature;
	quit;

%mend createlibref;
