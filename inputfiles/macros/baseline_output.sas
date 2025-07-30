****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_output.sas  
* Created (mm/dd/yyyy): 03/10/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of Baseline Characteristics Tables proc report output
*                                        
*  Program inputs:                                                                                   
*   - table1_&periodid.
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:                                                                       
*            
*  Programming Notes:         
*   Utility macro %baseline_procreport created to execute the proc report for each baseline table 
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro baseline_output();

    %put =====> MACRO CALLED: baseline_output;

    %if %eval(&numbaselinetablegrp.>0) %then %do;

    /* Set to 2 for effect estimate tables */
    %let tablenum = 2;

    /*********************************************************************************************/
    /*   proc report                                                                             */
    /*********************************************************************************************/  
    %macro baseline_procreport(order = ,
                               table = ,
                               weight = ,
                               title= ,
                               characteristiclabel =, 
                               labcharacteristics =,
                               dpnum = ,
                               numcolumns = ,
                               grp1_label=,
                               grp2_label=,
                               grp3_label=, 
                               computebalance = ,
                               includenonpregnant = );

        /*save data to reportdata folder*/
        %isdata(dataset=repdata.table1&tableletter.);
        %if %eval(&nobs.<1) %then %do;
            %let dataset = table1_&periodid.;

            /*if T6 - merge all switchsteps and create new columns*/
            %if &reporttype. = T6 %then %do;
                proc sql noprint;
                    create table table1&tableletter. as
                    select x.label,
                           x.grouper,
                           x.sortorder1, 
                           x.sortorder2,
                           x.sortorder3,
                           x.sortorder4,
                           x.metvar,
                           x.vartype,
                           x.analysisgrp,
                           'Unadjusted' as table,
                           'Unweighted' as weight,
                           x.exp_mean&dpnum.,
                           x.exp_mean&dpnum._char,
                           x.exp_std&dpnum.,
                           x.exp_std&dpnum._char,
                           y.exp_mean&dpnum. as comp_mean&dpnum.,
                           y.exp_mean&dpnum._char as comp_mean&dpnum._char,
                           y.exp_std&dpnum. as comp_std&dpnum.,
                           y.exp_std&dpnum._char as comp_std&dpnum._char,
                           %if %eval(&maxswitch.=2) %then %do;
                           z.exp_mean&dpnum. as switch2_mean&dpnum.,
                           z.exp_mean&dpnum._char as switch2_mean&dpnum._char,
                           z.exp_std&dpnum. as switch2_std&dpnum.,
                           z.exp_std&dpnum._char as switch2_std&dpnum._char,
                           %end;
                           x.order
                    from table1_&periodid.(where=(order = &order. and table = 'Switchstep_0')) as x
                    left join table1_&periodid.(where=(order = &order. and table = 'Switchstep_1')) as y
                    on x.metvar = y.metvar and x.sortorder1 = y.sortorder1 and x.sortorder2 = y.sortorder2
                    					   and x.sortorder3 = y.sortorder3 and x.sortorder4 = y.sortorder4
                   %if %eval(&maxswitch.=2) %then %do;
                    left join table1_&periodid.(where=(order = &order. and table = 'Switchstep_2')) as z
                    on x.metvar = z.metvar and x.sortorder1 = z.sortorder1 and x.sortorder2 = z.sortorder2 and x.sortorder3 = z.sortorder3 and x.sortorder4 = z.sortorder4
                   %end;
                   order by x.sortorder1, x.sortorder2, x.sortorder3, x.sortorder4;
                quit;
            
                %let dataset = table1&tableletter.;
            %end;

            data repdata.table1&tableletter.;
                set &dataset.(where=(order = &order. and table = &table. and weight in (&weight.)
							  %if &reporttype=T2L2 or &reporttype=T4L2 %then %do;
							  	and subgroup="&subgroup." and subgroupcat="&subgroupcat."
							  %end;));
                keep label grouper metvar vartype analysisgrp table weight exp_mean&dpnum. exp_mean&dpnum._char exp_std&dpnum. exp_std&dpnum._char
                %if &includecomp. = Y %then %do; comp_mean&dpnum. comp_std&dpnum. comp_mean&dpnum._char comp_std&dpnum._char %end;
                %if %eval(&maxswitch.=2) %then %do; switch2_mean&dpnum. switch2_std&dpnum. switch2_mean&dpnum._char switch2_std&dpnum._char %end;
                %if &computebalance. = Y %then %do; ad&dpnum. sd&dpnum. ad&dpnum._char sd&dpnum._char %end;
                %if &reporttype = T2L2 %then %do;
                monitoringperiod
                %end;
				%if &reporttype=T2L2 or &reporttype=T4L2 %then %do;
				subgroup subgroupcat
				%end;
				%if %index(&reporttype,T4) > 0 %then %do;
				codepop
				%end;
                ;
            run;
        %end;

		/* Select Footnotes */  		
		%if %index(&reporttype,T4) > 0 %then %let fn_labcovar = 21;
		%else %let fn_labcovar = 20;
		%global covarlablabels;
		%let covarlablabels=;
		/* Get labels for lab covariates specified in covinps */
		%if %length(&covinps.) > 0 and %str("&labcharacteristics") ^= %str("missing") %then %do;		
				%let tempvarlabs=%upcase(&labcharacteristics);

				%baseline_expand_parameters(var=tempvarlabs);
	  
				proc sort data= covarname(keep=studyname cov_varname where=(upcase(cov_varname) in (&tempvarlabs))) out=labcovar(rename=cov_varname=cov);
				by cov_varname;
				run; 

				data covinps;	
				format cov $30.;	
				do obs=1 by 1 until (cov=' ');
					cov=lowcase(strip(scan(tranwrd(symget('covinps'),'"',""),obs)));
					if cov ne " " then output;
				end;
				drop obs;
				run;

				proc sort data=covinps;
				by cov;
				run;

				data covinps;
				merge covinps
					  labcovar(in=b);
				by cov;
				NoLab=0;
				if not b then NoLab=1;
				run;

				proc sql noprint undo_policy=none;
				create table covinps as 
				select * from covinps
				where upcase(cov) in (&covinps.);
				quit;

				proc sql noprint;
				select studyname into :covarlablabels separated by ' ' from covinps where NoLab=0;
				quit;

				%create_comma_charlist(inlist=&covarlablabels, outlist=covarlablabels);

				%put &=covarlablabels;
	    %end;
		
		%let standard_riskscores_withfn = &riskscorelibrary.;		
		%let riskscore_footnotes=N;
		%do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' '));
			%let riskscorename=%upcase(%scan(&standard_riskscores_withfn., &rskscore., %str( )));
			%if &&&riskscorename. = Y %then %let riskscore_footnotes=Y;
		%end;

	
			/* Because the order of the following footnotes can change and because there can be 
			   many diferent combination of superscripts involving them, we must reassess order 
			   and assign superscript dynamically for each covariate
			*/

			%do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' '));
				%let fn_%scan(&standard_riskscores_withfn., &rskscore., %str( ))=N;
			%end;						
			%let fn_covinps=N;			
			%let fn_labcovar=N;
			%let fn_nopreg_i_covar=N;
			%let fn_i_covar=N;
			%let fn_mi_covar=N;
			%let fn_nonlive=N;
			%let fn_gestage=N;

			%let table1_dataset=table1;

			* For each footnote, indentify the first row where the superscript should appear;
			data table1;
			set repdata.table1&tableletter.;

			%do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' '));
				fn_%scan(&standard_riskscores_withfn., &rskscore., %str( ))=.;
			%end;						
			fn_covinps=.;			
			fn_labcovar=.;
			fn_nopreg_i_covar=.;
			fn_i_covar=.;
			fn_mi_covar=.;
			fn_nonlive=.;
			fn_gestage=.;

			%if &riskscore_footnotes. eq Y %then %do; 
				%do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' '));
					%let riskscorename=%upcase(%scan(&standard_riskscores_withfn., &rskscore., %str( )));

					%if &&&riskscorename. = Y %then %do;
						if metvar ="&riskscorename." then do;
							fn_&riskscorename=_N_;
							call symput("fn_&riskscorename.","Y");							
						end;
					%end;
				%end;
			%end;
			%if %length(&covinps.) > 0 %then %do;		
				if (grouper ne "Laboratory Characteristics" and metvar in (&covinps.)) 
				or (missing(metvar) and ((upcase(label) in (&covinps) and upcase(label)^='AGE') | (upcase(label)='AGE' and %index(%upcase(&covinps., AGEGROUP))>0)))
					%if %length(&covarlablabels.) > 0 %then %do; 
				   	 or	(grouper eq "Laboratory Characteristics" and upcase(label) in (&covarlablabels.))
					%end;
				then do;
					fn_covinps=_N_;
					call symput("fn_covinps","Y");
				end;		
			%end;			
			%if %str("&labcharacteristics.") ^= %str("missing") %then %do;
				if grouper="Laboratory Characteristics" and metvar="" then do;
					fn_labcovar=_N_;
					call symput("fn_labcovar","Y");
				end;	
			%end;
			* For type 4 reports, process additional footnotes related to gestational age, non live birth outcomes and mother-infant or infant covariates (CODEPOP= MI or I);
			%if %index(&reporttype,T4) > 0 %then %do;
				if codepop="I" and (grouper ne "Laboratory Characteristics" or (grouper="Laboratory Characteristics" and metvar="")) then do;
					fn_i_covar=_N_;
					call symput("fn_i_covar","Y");

					%if &includenonpregnant. eq Y %then %do;
						fn_nopreg_i_covar=_N_;
						call symput("fn_nopreg_i_covar","Y");
					%end;
				end;
				if codepop="MI" and (grouper ne "Laboratory Characteristics" or (grouper="Laboratory Characteristics" and metvar="")) then do;
					fn_mi_covar=_N_;
					call symput("fn_mi_covar","Y");
				end;
				if upcase(metvar) in ("GA_BIRTH" "GA_FIRST") then do;
					fn_gestage=_N_;
					call symput("fn_gestage","Y");
				end;
				if upcase(metvar) = "PREPOSTIND_NA" then do;
					fn_nonlive=_N_;
					call symput("fn_nonlive","Y");
				end;
			%end;
			run;

			proc means data=table1 nway noprint;
			var %do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' ')); fn_%scan(&standard_riskscores_withfn., &rskscore., %str( )) %end; 
				fn_covinps fn_labcovar fn_nopreg_i_covar fn_i_covar fn_mi_covar fn_gestage fn_nonlive;
			output out=_fnmin(drop=_:) min=;
			run;

			data _null_;
			set _fnmin;
			%do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' '));				
				%let riskscorename=%upcase(%scan(&standard_riskscores_withfn., &rskscore., %str( )));
				call symputx("fn_&riskscorename.",fn_&riskscorename.); 					
			%end;
			%if &fn_covinps. ne N %then %do; 		call symputx('fn_covinps',fn_covinps); 			%end;			
			%if &fn_labcovar. ne N %then %do; 			call symputx("fn_labcovar",fn_labcovar); 				%end;
			%if &fn_nopreg_i_covar. ne N %then %do; 	call symputx("fn_nopreg_i_covar",fn_nopreg_i_covar);	%end;
			%if &fn_i_covar. ne N %then %do; 			call symputx("fn_i_covar",fn_i_covar); 					%end;
			%if &fn_mi_covar. ne N %then %do; 			call symputx("fn_mi_covar",fn_mi_covar); 				%end;
			%if &fn_gestage. ne N %then %do; 			call symputx("fn_gestage",fn_gestage); 					%end;
			%if &fn_nonlive. ne N %then %do; 			call symputx("fn_nonlive",fn_nonlive);	 				%end;
			run;

			* Because fn_labcovar must be output prior to some other dynamic footnotes we need to push them forward if they were computed the same value;  
			%if &fn_covinps. ne N and &fn_labcovar. ne N %then %do;
				%if &fn_covinps. eq &fn_labcovar. %then %let fn_covinps=&fn_labcovar..1;				
			%end;
			%if &fn_nopreg_i_covar. ne N and &fn_labcovar. ne N %then %do;
				%if &fn_nopreg_i_covar. eq &fn_labcovar. %then %let fn_nopreg_i_covar=&fn_labcovar..1;			
			%end;
			%if &fn_i_covar. ne N and &fn_labcovar. ne N %then %do;
				%if &fn_i_covar. eq &fn_labcovar. %then %let fn_i_covar=&fn_labcovar..1;				
			%end;
			%if &fn_mi_covar. ne N and &fn_labcovar. ne N %then %do;
				%if &fn_mi_covar. eq &fn_labcovar. %then %let fn_mi_covar=&fn_labcovar..1;				
			%end;					

		proc sort data=lookup.lookup_footnotes out=_footnotes;
		by order;
		run;

		data _footnotes;
		   length footnote_order 3; 
		   /* Always displayed across all types */		  
		   set _footnotes (where =  ((type = "baseline" and order in (14 15		   		   	          
		   %if %length(&covinps.) > 0 %then %do; -4 %end;
		   /* T4 L1 or L2 non live birth outcomes requested*/
		   %if %index(&reporttype,T4) > 0 and &nonlivefn. = Y %then %do; 17 %end;
		   /* T4 L1 or L2 gestational age specified*/
		   %if %index(&reporttype,T4) > 0 and &gestationalage. = Y %then %do; 18 %end;
		   /* if race is collapsed in table*/
           %if &collapse_vars. = race %then %do; 16 %end; 
		   /* T1, T2L1, T6 when cohortdef is not 01 and T4L1 when a non-MIL */
		   %if ((%str("&reporttype") = %str("T1") | %str("&reporttype") = %str("T2L1") | %str("&reporttype") = %str("T6")) and %sysfunc(prxmatch(m/02|03/i,&cohortdef.))) > 0 
		       | (%str("&reporttype") = %str("T4L1") and %str("&cohort.") ne %str("mi")) %then %do; 1 %end;
		   /* Sdthreshold greater than 0 */
		   %if &sdthreshold. > 0 %then %do; 2 %end;
		   %if %index(&reporttype,L2) %then %do;
		   /* L2 weighted table for PS stratification where weight is ATE */
		     %if &psfile. = stratificationfile and %index(&weight.,Weighted) > 0 %then %do;
			   %if "&weightscheme." = "ATE" %then %do; 4 %end;
		   /* L2 weighted table for PS stratification where weight is ATT */
			   %else %if "&weightscheme." = "ATT" %then %do; 5 %end;
		   /* L2 weighted table for PS stratification where weight is Blank */
			   %else %do; 6 %end;
			 %end;
			 %if &psfile. = iptwfile and %index(&table.,Adjusted) > 0 and %index(&weight.,Weighted) > 0 %then %do;
		   /* L2 weighted table for IPTW where weight is ATE */
			   %if "&weightscheme." = "ATE" %then %do; 7 %end;
		   /* L2 weighted table for IPTW where weight is ATES */
			   %else %if "&weightscheme." = "ATES" %then %do; 8 %end;
		   /* L2 weighted table for IPTW where weight is ATT */
			   %else %if "&weightscheme." = "ATT" %then %do; 9 %end;
			 %end;
		   /* L2 weighted table for variable ratio matching */
			 %if &psfile = psmatchfile and &ratio. = V  and %index(&table.,Adjusted) > 0 %then %do; 10 %end;
		   %end; 
		   /* T4L2, T4L1 with MIL */
		   %if (%str("&reporttype.") = %str("T4L1") and %str("&cohort.") = %str("mi")) | %str("&reporttype.") = %str("T4L2") %then %do; 11 %end;
		   /* T6 Switching */
		   %if %str("&reporttype.") = %str("T6") %then %do; 
		     /* 1st switch */
		     %if %eval(&maxswitch > 0) %then %do; 12 %end;
		   /* 2nd Switch */
		     %if %eval(&maxswitch=2) %then %do; 13 %end;
		   %end;
		   /* CCI is specified */
		   %if &CCI = Y %then %do; 19 %end;
		   /* PEDCOMORB score is specified */
		   %if &PEDCOMORB = Y %then %do; 25 %end;
		   /* HASBLED score is specified */
		   %if &HASBLED = Y %then %do; 26 %end;
		   /* CHA2DS2VASC score is specified */
		   %if &CHA2DS2VASC = Y %then %do; 27 %end;
		   /* OBSCOMORB score is specified */
		   %if &OBSCOMORB = Y %then %do; 28 %end;
		   /* ADCSI score is specified */
		   %if &ADCSI = Y %then %do; 29 %end;
		   /* FRAILTY score is specified */
		   %if &FRAILTY = Y %then %do; 30 %end;
		   /* Lab characteristics specified. */
		   %if %str("&labcharacteristics.") ^= %str("missing") %then %do;
		   	  %if %index(&reporttype,T4) > 0 %then %do; 21 %end;
			  %else %do; 20 %end;
		   %end;		
		   %if %index(&reporttype,T4) > 0 %then %do;
			  /* Non pregnant cohort with infant covariates */
			  %if &fn_nopreg_i_covar. ne N %then %do; 22 %end;
			  /*Infant covariates */
			  %if &fn_i_covar. ne N %then %do; 23 %end;
			  /* Mother and Infant covariates */
			  %if &fn_mi_covar. ne N %then %do; 24 %end;
		   %end; 
		   ))
            %if %index(&reporttype,T4) > 0 %then %do;
            or (type='type4' and order in (-2 
                %if &includenonpregnant = Y %then %do; -1 %end; ))
            %end;
                ));
		  by order;
		  footnote_order = _n_;
		  
			* Overwrite original order with dynamically computed order;
			order_orig=order;			
			%if &fn_CCI. ne N %then %do; 
				if order_orig=19 then order=&fn_CCI.; 		
			%end;
			%if &fn_pedcomorb. ne N %then %do; 
				if order_orig=25 then order=&fn_pedcomorb.; 		
			%end;
			%if &fn_hasbled. ne N %then %do; 
				if order_orig=26 then order=&fn_hasbled.; 		
			%end;
			%if &fn_cha2ds2vasc. ne N %then %do; 
				if order_orig=27 then order=&fn_cha2ds2vasc.; 		
			%end;
			%if &fn_obscomorb. ne N %then %do; 
				if order_orig=28 then order=&fn_obscomorb.; 		
			%end;
			%if &fn_adcsi. ne N %then %do; 
				if order_orig=29 then order=&fn_adcsi.; 		
			%end;
			%if &fn_frailty. ne N %then %do; 
				if order_orig=30 then order=&fn_frailty.; 		
			%end;
			%if &fn_labcovar. ne N %then %do; 
				if order_orig in (20,21) then order=&fn_labcovar.; 		
			%end;
			%if &fn_nopreg_i_covar. ne N %then %do; 
				if order_orig=22 then order=&fn_nopreg_i_covar.;				
			%end;
			%if &fn_i_covar. ne N %then %do; 
				if order_orig=23 then order=&fn_i_covar.; 		
			%end;
			%if &fn_mi_covar. ne N %then %do; 
				if order_orig=24 then order=&fn_mi_covar.; 		
			%end;
			%if &fn_gestage. ne N %then %do; 
				if order=18 then order=&fn_gestage.; 		
			%end;
			%if &fn_nonlive. ne N %then %do; 
				if order_orig=17 then order=&fn_nonlive.; 		
			%end;		  		  
	    run;
		
			* Compute new superscript and footnote values based on dynamic values;
			proc sort data=_footnotes;
			by order order_orig;
			run;

			data _footnotes;
			set _footnotes;
			footnote_order = _n_ %if %length(&covinps.) > 0 %then %do; -1 %end;;			
			%if &fn_CCI. ne N %then %do; 
				if order_orig=19 then call symputx("fn_CCI",footnote_order);
			%end;
			%if &fn_pedcomorb. ne N %then %do; 
				if order_orig=25 then call symputx("fn_pedcomorb",footnote_order);
			%end;
			%if &fn_hasbled. ne N %then %do; 
				if order_orig=26 then call symputx("fn_hasbled",footnote_order);
			%end;
			%if &fn_cha2ds2vasc. ne N %then %do; 
				if order_orig=27 then call symputx("fn_cha2ds2vasc",footnote_order);
			%end;
			%if &fn_obscomorb. ne N %then %do; 
				if order_orig=28 then call symputx("fn_obscomorb",footnote_order);
			%end;
			%if &fn_adcsi. ne N %then %do; 
				if order_orig=29 then call symputx("fn_adcsi",footnote_order);
			%end;
			%if &fn_frailty. ne N %then %do; 
				if order_orig=30 then call symputx("fn_frailty",footnote_order);
			%end;
			%if &fn_labcovar. ne N %then %do; 
				if order_orig in (20,21) then call symputx("fn_labcovar",order);
			%end;
			%if &fn_nopreg_i_covar. ne N %then %do; 
				if order_orig=22 then call symputx("fn_nopreg_i_covar",footnote_order);
			%end;
			%if &fn_i_covar. ne N %then %do; 
				if order_orig=23 then call symputx("fn_i_covar",footnote_order);
			%end;
			%if &fn_mi_covar. ne N %then %do; 
				if order_orig=24 then call symputx("fn_mi_covar",footnote_order);
			%end;
			%if &fn_gestage. ne N %then %do; 
				if order_orig=18 then call symputx("fn_gestage",footnote_order);
			%end;
			%if &fn_nonlive. ne N %then %do; 
				if order_orig=17 then call symputx("fn_nonlive",footnote_order);
			%end;
			run;

			data table1;
			set table1;
			%do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' '));
				%let riskscorename=%upcase(%scan(&standard_riskscores_withfn., &rskscore., %str( )));

				%if &&fn_&riskscorename. ne N %then %do; 
					if fn_&riskscorename ne . then fn_&riskscorename=&&fn_&riskscorename.;
				%end;
			%end;
			
			%if &fn_covinps. ne N %then %do;	
				if fn_covinps ne . then fn_covinps=&fn_covinps.;
			%end;			
			%if &fn_labcovar. eq N %then %do;
				%if %index(&reporttype,T4) > 0 %then %do;
					call symputx("fn_labcovar",21);
				%end;
				%else %do;
					call symputx("fn_labcovar",20);
				%end;
			%end;
			drop fn_labcovar;
			%if &fn_nopreg_i_covar. ne N %then %do; 
				if fn_nopreg_i_covar ne . then fn_nopreg_i_covar=&fn_nopreg_i_covar.;
			%end;
			%if &fn_i_covar. ne N %then %do; 
				if fn_i_covar ne . then fn_i_covar=&fn_i_covar.;
			%end;
			%if &fn_mi_covar. ne N %then %do; 
				if fn_mi_covar ne . then fn_mi_covar=&fn_mi_covar.;
			%end;	
			%if &fn_gestage. ne N %then %do; 
				if fn_gestage ne . then fn_gestage=&fn_gestage.;
			%end;
			%if &fn_nonlive. ne N %then %do; 
				if fn_nonlive ne . then fn_nonlive=&fn_nonlive.;
			%end;
			run;

			* Build dynamic superscript and add them to the label;
			%let num_riskscores = %sysfunc(countw(&standard_riskscores_withfn., ' '));
			%let num_dynamic_footnotes  = %eval(&num_riskscores. + 6);

			data table1;
			set table1;
			* Because a covariate can have more than 1 superscript, we need to sort them in ascending order;
			array fn[&num_dynamic_footnotes.] $32 _temporary_;
			call missing(of fn[*]);
			%do rskscore=1 %to %sysfunc(countw(&standard_riskscores_withfn., ' '));
				%let riskscorename=%upcase(%scan(&standard_riskscores_withfn., &rskscore., %str( )));
				fn[&rskscore.]=put(fn_&riskscorename., best.);
			%end;		

			fn[&num_riskscores. + 2]=put(fn_nopreg_i_covar, best.);
			fn[&num_riskscores. + 3]=put(fn_i_covar, best.);
			fn[&num_riskscores. + 4]=put(fn_mi_covar, best.);		
			fn[&num_riskscores. + 5]=put(fn_gestage, best.);
			fn[&num_riskscores. + 6]=put(fn_nonlive, best.);		
			call sortc(of fn[*]);

			length superscript $50;
			if not missing(fn_covinps) then do; 
				if N(of fn[*]) = 0 then do;
					superscript = '*';
				end;
				else if N(of fn[*]) > 0 then do; 
					superscript = catt('*',',', compress(catx(',', of fn[*]),'.,'));
				end;
			end;
			else do;
				superscript = catx(',',of fn[*]);
				superscript=compress(strip(tranwrd(superscript,".,","")),".");
			end;
			if superscript ne "" then superscript=cat('^{Super ',strip(superscript),'}');	
			if label = "Gestational age at pregnancy outcome (weeks)" then do;
				label=cat("Gestational age at pregnancy outcome (weeks)^{Super ", strip(put(fn_gestage, best.)), "}");
				if fn_covinps ne . then label=cat("Gestational age at pregnancy outcome (weeks)^{Super ", strip(put(fn_gestage, best.)), "}^{Super ,}^{Super *}");
			end;	
			else if label = "Gestational age of first exposure (weeks)" then do;
				label=cat("Gestational age of first exposure (weeks)^{Super ", strip(put(fn_gestage, best.)), "}");
				if fn_covinps ne . then label=cat("Gestational age of first exposure (weeks)^{Super ", strip(put(fn_gestage, best.)), "}^{Super ,}^{Super *}");
			end;
			else label=catt(label, superscript);			
			run;		

        /*Set first word for SDthreshold footnote*/
		%if %str(&sdthreshold.) ne %str() %then %do;
             %if %index(&reporttype,L2) %then %let covar_characteristic = Covariates;
             %else %let covar_characteristic = Characteristics;
    %end;	

	proc sql noprint;
	  select count(order) into: num_fn trimmed
	  from _footnotes;

	  select description into: fn1 - :fn&num_fn.
	  from _footnotes
	  order by order, order_orig;
	quit;

    
		/* Assign macro variables for superscipts */
		%assign_superscripts(type =title, order =-2 -1);
		%assign_superscripts(type =character, order =1 2 4 5 6 7 8 9 10 11 );
		%assign_superscripts(type =max_cell_width, order =4 5 6 7 8 9 10 19 );
		%assign_superscripts(type =switch1, order =12);
		%assign_superscripts(type =switch2, order =13);
		%assign_superscripts(type =stdev, order =14);
        %assign_superscripts(type =race, order =15);
        %assign_superscripts(type =unknownrace, order =16);
		%assign_superscripts(type =nonlive, order =17);	
		%assign_superscripts(type =gestage, order =18);				
		%assign_superscripts(type =labcovar, order =&fn_labcovar.);

		
        /*determine optimal report formatting*/
        %let labelwidth = 3.5;
        %let width = 1.15;
        %let linebreak = ;
        %let headerheight = .3;
        %if %eval(&numcolumns.=4) %then %do;
            %let labelwidth = 3;
            %let width = 1.15;
            %let linebreak = ;
            %let headerheight = .3;
        %end;
        %else %if %eval(&numcolumns.=6) %then %do;
            %let labelwidth = 3;
            %let width = .85;
            %let linebreak = ^n;
            %let headerheight = .45;
        %end;
		
        %if %length(&pregnancylabel.)>0 %then %let cohortheaderlabel = Cohort;
        %else %let cohortheaderlabel = Medical Product;

        %if &destination. = excel %then %do;
        ods excel options(sheet_name="Table 1&tableletter." tab_color = "lightgreen" flow="1:400");
        %let linebreak = ; /*reset line break and headerheight*/
        %let headerheight = .3;
        %if %eval(&numcolumns.=6) %then %let width = 1;
        %end;
        ods proclabel = "Table 1&tableletter.";
        proc report data=&table1_dataset. nofs nowd spanrows split='*'
            style(header)=[rules=none frame=void background=BGR borderleftcolor = BGR vjust=b] split='*'
		    style(report)=[rules=none frame=void cellpadding =1.5pt];

            column (metvar grouper label
                    %if &computebalance. = Y %then %do; ("^S={background=BGR}&cohortheaderlabel." %end;
                    ("^S={background=BGR}&grp1_label." exp_mean&dpnum._char exp_std&dpnum._char)
                    %if &includecomp. = Y %then %do;
                    ("^S={background=BGR}&grp2_label.&super_switch1." comp_mean&dpnum._char comp_std&dpnum._char)
                    %end;
                    %if &computebalance. = Y %then %do; ) %end;
                    %if %eval(&maxswitch.=2) %then %do;
                    ("^S={background=BGR}&grp3_label.&super_switch2." switch2_mean&dpnum._char switch2_std&dpnum._char)
                    %end;
                    %if &computebalance. = Y %then %do; 					
						%if %index(&reporttype,L2) %then %do;
							('^S={background=BGR}Covariate Balance' '^S={background=BGR}' ad&dpnum._char sd&dpnum._char)
						%end;
						%else %do;
							('^S={background=BGR}Characteristic Balance' '^S={background=BGR}' ad&dpnum._char sd&dpnum._char)
						%end;
                    %end; );

            define metvar / noprint;
            define grouper / order noprint order=data '';
            define label / display "&characteristiclabel. Characteristics&super_character." style(column)=[width=&labelwidth.in just=L] 
                           style(header)=[background = LIBGR just=L cellheight=&headerheight.in]; 

            define exp_mean&dpnum._char  / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string format:@"] 
                            style(header)=[background = LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in]; 
            define exp_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string format:@"]
                            style(header)=[background = LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in]; 
            %if &includecomp. = Y %then %do;
            define comp_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string format:@"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            define comp_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string format:@"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            %end;
            %if %eval(&maxswitch.=2) %then %do;
            define switch2_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string format:@"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            define switch2_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string format:@"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            %end;

            %if &computebalance. = Y %then %do;
            define ad&dpnum._char / display 'Absolute^n Difference' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string format:@"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            define sd&dpnum._char / display 'Standardized^n Difference' style(column)=[width=&width.in tagattr="type:string format:@"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            %end;

            /*Add Characteristic header lines and superscript to Lab characteristic header */
            compute before grouper / style=[background=LIBGR color=black just=L font_weight=bold];
              length text $100;
              if grouper ne "&characteristiclabel. Characteristics" then do;
              	if grouper = "Laboratory Characteristics" then do; 
              	text=catt(grouper,"&super_labcovar.");
              	end;
              	else do;
                text=grouper;
            	end;
                num=100;
              end;
              else do; 
                text = "";
                num=0;
              end;
              line text $Varying. num; 
            endcomp;

            
            compute label;
			  /*Add static superscripts to labels*/
              if index(label,'Race') > 0 then label = catt(label,"&super_race.");			  			  			  

			  /*Indent demographic header lines, riskscore category lines and lab covariate record lines*/			
			  %if %length(&riskscoreslist.) > 0 %then %do;
				%do rskscore=1 %to %sysfunc(countw(&riskscoreslist., ' '));
					%let riskscorename=%upcase(%scan(&riskscoreslist., &rskscore., %str( )));
					if prxmatch("/&riskscorename._CAT*/",metvar) > 0 then do;
						call define(_col_,'style','style={indent=25}');
					end;
				%end;
			  %end; 
              if prxmatch('/AGE\d|YEAR*|RACE*|HISPANIC*|SEX*|PREG_OUTCOME*/',metvar) > 0 then do;
                call define(_col_,'style','style={indent=25}');
              end;
              %if %str("&labcharacteristics.") ^= %str("missing") %then %do; 
              if prxmatch('/^(Test record|No test record|Test record with missing or unknown units)$|Test record in/', strip(label)) then do;
              		call define(_col_,'style','style={indent=25}');
              end;
              else if prxmatch('/^(Borderline|Negative|Positive|Invalid categorical result|Undetermined|Mean, standard deviation)$|\|/', strip(label)) then do; 
              	    call define(_col_,'style','style={indent=50}');
              	    call define(_row_,'style','style={fontstyle=italic}');
              end;
              %end;
			  

              /*assign unknown race footnote*/
              %if &collapse_vars. = race %then %do;
                 if metvar = 'RACE_0' then label = catt(label,"&super_unknownrace.");
              %end;

            endcomp;

			/*Change font color to blue if abs(SD) > threshold value*/
        	%if &computebalance. = Y and %length(&sdthreshold.) > 0 %then %do;
            compute sd&dpnum._char;
                if upcase(strip(sd&dpnum._char)) not in ("", ".", "N/A", "NAN") then do;
                    if abs(input(sd&dpnum._char, 8.3)) > &sdthreshold. then do;
                      call define(_row_,'style/merge','style={foreground=blue}');
                    end;
                end;
            endcomp;
        	%end;

            /*Add title*/
            compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor = white
			                              borderbottomwidth = &bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
            line "&title.&super_title.";
            endcomp;
			/* Add Footnotes */
			compute after / style=[just=L nobreakspace=off borderbottomcolor=white bordertopcolor=black  vjust=T fontsize=&footfontsize.
			                        height=3.0in bordertopwidth = &bordersize];
			  %if %length(&covinps) > 0 %then %do;
			  %do f = 1 %to &num_fn.;
			  	%if &f = 1 %then %do;
			  		line "^{super *}&&fn&f.";
			  	%end;
			  	%else %do;
            line "^{super %eval(&f.-1)}&&fn&f.";
          %end;
			  %end;
			  %end;
			  %else %do;
			  	%do f = 1 %to &num_fn.;
			  	  line "^{super &f.}&&fn&f.";
			  	%end;
			  %end;

            endcomp;

            *Remove collapsed rows;
            %if &collapse_vars. = race %then %do;
                where exp_mean&dpnum. ne .R %if &includecomp. = Y %then %do; & comp_mean&dpnum. ne .R %end; 
                %if %eval(&maxswitch.=2) %then %do; & switch2_mean&dpnum. ne .R %end; ;
            %end;
        run;   

        /*clean up*/
        proc datasets nowarn noprint lib=work;
            delete _footnotes  _fnmin;
        quit;

    %mend baseline_procreport;

    /*counter for determining table letter*/
    %let tablecount = 1;

    /*loop through each baseline table*/
    %do b = 1 %to &numbaselinetablegrp.;
        %let analysisgrp = ;
        %let analysisgrp2 = ;
        %let baselinegroupnum = ;
        %let pregnancylabel = ;
        %let pregnancylabel2 = ;
        %let includenonpregnant = N;
        %let includecomp = N;
        %let computebalance =N;
        %let maxswitch = 0;
        %let covinps= ;

        /*for L2 tables - need to reference PS/CS specific files to pull additional parameters*/
        %let ratio = F;
        %let psfile = ;
        %let weightlabel = ;
        %let weightscheme = ;
        %let pstrim = ;
        %let percentiles=;
        %let ratiolabel = ;
        %let caliperlabel = ;
        %let truncationlabel = ;
        %let psestimategrp = ;
        %let unadjusted = ;
        %let eoi = ;
        %let ref = ;
        %let switch0group = ;
        %let switch1group = ;
        %let switch2group = ;

        /*parameters for %baseline_procreport*/
        %if %sysfunc(prxmatch(m/T4L1|T4L2/i,&reporttype.)) >0 %then %let characteristiclabel = Mother;
        %else %let characteristiclabel = Patient;
        %let grp1_label=;
        %let grp2_label=;
        %let grp3_label=;

        data _null_;
            set baselinefile(where=(order=&b.));
            if _n_ = 1 then do;
                call symputx('analysisgrp', strip(analysisgrp));
                call symputx('runid', runid);
                call symputx('cohort', cohort);
				call symputx('cohortdef',cohortdef);
				%do rskscore=1 %to %sysfunc(countw(&riskscorelibrary., ' '));
					%let riskscore=%scan(&riskscorelibrary., &rskscore., %str( ));					
					call symputx("&riskscore.",&riskscore.);
				%end;				
				call symputx('nonlivefn',nonlivefn);
				call symputx('gestationalage',gestationalage);
                call symputx('unique_psestimate',unique_psestimate);
				call symputx('unique_psestimate_orig',unique_psestimate);
                if missing(sdthreshold) then call symputx('sdthreshold', '');
                else call symputx('sdthreshold', sdthreshold);	
                if missing(labcharacteristics) then call symputx('labcharacteristics',"missing");
                else call symputx('labcharacteristics', labcharacteristics);
                %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;	
                if missing(covinps)=0 then call symputx('covinps', strip(upcase(covinps)));
                call symputx('computebalance', 'Y');
                %end;
                %else %do;
                if computebalance = 'Y' then call symputx('computebalance', 'Y');
                %end;

                %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
                if cohort in ('preg', 'nopreg') then do;
 				call symputx('pregnancylabel',preg_outcome_label);
 				end;
                call symputx('includenonpregnant', upcase(includenonpregnant));

                %end;
                if missing(baselinegroupnum)=0 then call symputx('baselinegroupnum', baselinegroupnum);
                
                /*if reporttype = T2L2, T4L2, T6, or computebalance = Y or includenonpreggroup = Y,
                  or BASELINEGROUPNUM is specified then include COMP columns*/
                if "&reporttype."="T2L2" | "&reporttype."="T4L2" | "&reporttype."="T6" 
				   | upcase(computebalance)= 'Y' | upcase(includenonpregnant) = 'Y' | missing(baselinegroupnum)=0 then do;
                   call symputx('includecomp', 'Y');
                end;
                else do;
                   call symputx('includecomp', 'N');
                end;
            end;
            /*if baselinegroupnum is specified, a 2nd row will exist in the file*/
            if _n_ = 2 then do;
                if missing(baselinegroupnum)=0 then do;
                    call symputx('analysisgrp2',analysisgrp);
                    %if %index(&reporttype,T4L1) %then %do;
                    call symputx('pregnancylabel2', preg_outcome_label);
                    %end;
                end;
            end;
        run;
		/* Get list of riskscores that will be output */
		%let riskscoreslist=;
		%isdata(dataset=riskscorefile);
		%if %eval(&nobs.>0) %then %do;
			proc sql noprint;
			    select distinct riskscore into :riskscoreslist separated by " "
			    from riskscorefile where runid="&runid.";
			quit;
		%end;

        /* Assign patient/episode label for lab footnote based on cohortdef value */
        %if %str("&labcharacteristics.") ^= %str("missing") %then %do; 
        	%if %sysfunc(prxmatch(/01|04/,&cohortdef)) %then %let patientepi = patients; 
        	%else %if %sysfunc(prxmatch(/02|03/,&cohortdef)) %then %let patientepi = episodes;
        %end;

        /*Additional meta-data and group-specific names for each reporttype*/
        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            data _null_;
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp." and missing(subgroup) ne 0));
                call symputx('psfile', strip(file));
                call symputx('psestimategrp', psestimategrp);
                call symput('unadjusted', 'Unadjusted '); /*for unadjusted table label*/

                if file = 'psmatchfile' then do;
                    call symputx('ratio',upcase(ratio));
                    if upcase(ratio)='F' then call symputx("ratiolabel",'Fixed Ratio 1:'||strip(put(ceiling, 8.)));
                    if upcase(ratio)='V' then call symputx("ratiolabel",'Variable Ratio 1:'||strip(put(ceiling, 8.)));
                    call symputx("caliperlabel", cat(', Caliper: ', caliper));
                end;
                if file = 'stratificationfile' then do;
                    call symputx('pstrim', pstrim);
                    call symputx('percentiles', percentiles);
                    if missing(strataweight) =0 then call symputx('weightscheme', strataweight);
                    if upcase(strataweight)= 'ATE' or missing(strataweight) then call symputx("weightlabel","Average Treatment Effect (ATE)");
                    else if upcase(strataweight)= 'ATT' then call symputx("weightlabel","Average Treatment Effect in the Treated (ATT)");
                end;
                if file = 'iptwfile' then do;
                    if upcase(ipweight)= 'ATE' then call symputx("weightlabel","Average Treatment Effect (ATE)");
                    else if upcase(ipweight)= 'ATES' then call symputx("weightlabel","Average Treatment Effect, Stabilized (ATES)");
                    else if upcase(ipweight)= 'ATT' then call symputx("weightlabel","Average Treatment Effect in the Treated (ATT)");
					call symputx('weightscheme', upcase(ipweight));
                    call symputx('truncationlabel',strip(put(truncweight, best.)));
                end;
            run;

            /*pull EOI and REF group names*/
            %if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;
            data _null_;
                set infolder.&&&runid._&psfile.(where=(analysisgrp="&analysisgrp."));
                call symputx('psestimategrp', psestimategrp);
            run;
            data _null_;
                set infolder.&&&runid._psestimationfile(where=(psestimategrp="&psestimategrp."));
                call symputx('eoi', strip(eoi));
                call symputx('ref', strip(ref));
            run;
            %end;
            %else %if &psfile. = covstratfile %then %do;
            data _null_;
                set infolder.&&&runid._covstratfile(where=(analysisgrp="&analysisgrp."));
                call symputx('eoi', strip(eoi));
                call symputx('ref', strip(ref));
            run;
            %end;

			/*Defensive check for sdthreshold and covinpsparameters*/
			%if %eval(&unique_psestimate.) ne 1 %then %do;
				proc sql noprint;
				create table baseline_unique_check as
				select a.analysisgrp,
					   a.psestimategrp,
					   a.sdthreshold,
					   a.covinps
				from baselinefile as a
				left join pscs_masterinputs as b
				on a.analysisgrp = b.analysisgrp and
				a.psestimategrp = a.psestimategrp
				where b.subgroup=""
				order by a.order;
				quit;

				proc sql noprint;
				select count (distinct sdthreshold) into :sdthreshold_count trimmed
				from baseline_unique_check
				where psestimategrp = "&psestimategrp";

				select count (distinct covinps) into :covinps_count trimmed
				from baseline_unique_check
				where psestimategrp = "&psestimategrp";
				quit;

				%if %eval(&sdthreshold_count. > 1) or %eval(&covinps_count. > 1) %then %do;
					%put WARNING: (Sentinel) SDTHRESHOLD or covinpsvalue differs across analyses that share the same psestimategrp.;
					%put PSESTIMATEGRP=&psestimategrp has &sdthreshold_count SDTHRESHOLD distinct value(s) and &covinps_count covinpsdistinct value(s);
					
					/* If multiple values are detected for a same psestimategrp, assign the first available value for this psestimategrp (already sorted by order)*/
					data _null_;
					set baseline_unique_check(where=(psestimategrp = "&psestimategrp"));
					if _N_=1;
					if missing(sdthreshold) then call symputx('sdthreshold', '');
	                else call symputx('sdthreshold', sdthreshold);
					call symputx('covinps', strip(upcase(covinps)));
					run;
				%end;
			%end;
        %end;
        %else %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
            /*determine maximum switch*/
            proc sql noprint;
                select max(switchevalstep) into: maxswitch trimmed
                from infolder.&&&runid._treatmentpathways(where=((analysisgrp="&analysisgrp.")));
            quit;

            data _null_;
                set infolder.&&&runid._treatmentpathways(where=((analysisgrp="&analysisgrp.")));
                if switchevalstep = 0 then call symputx('switch0group', strip(group));
                if switchevalstep = 1 then call symputx('switch1group', strip(group));
                %if %eval(&maxswitch=2) %then %do;
                if switchevalstep = 2 then call symputx('switch2group', strip(group));   
                %end; 
            run;
        %end;

		%if %length(&covinps.) > 0 %then %baseline_expand_parameters(var=covinps);

        /*For L1 tables, determine if only 1 baseline table and set &tablecount to 0. Will occur if all the following are true:
        - 1 monitoring period
        - DP stratification = N
        - max(order) in baselinefile = 1
         For L2 tables, tablecount assigned in macro baselinereport*/
        %if %eval(&b.=1) & %eval(&look_start.) = %eval(&look_end.) & &stratifybydp. = N & %eval(&numbaselinetablegrp.=1) %then %do;
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) = 0 %then %do;
                %let tablecount = 0;
            %end;       
        %end;

        /*Assign labels*/
        %let baselinelabel = ;
        %let grouplabel = &analysisgrp.;
        %let psestimatelabel = &psestimategrp.;
        %if %length(&baselinegroupnum.)>0 %then %do;
        %let grouplabel2 = &analysisgrp2.;
        %end;

        %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
            %let switch0grplabel = &switch0group.;
            %let switch1grplabel = &switch1group.;
            %if %eval(&maxswitch=2) %then %do;
            %let switch2grplabel = &switch2group.;
            %end;
        %end;

        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            %let eoilabel = &eoi.;
            %let reflabel = &ref.;
        %end;

        %isdata(dataset=labelfile);
        %if %eval(&nobs.>0) %then %do;
            data _null_;
                set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid"))
                    %if %length(&baselinegroupnum.)>0 %then %do;
                        labelfile(in=b where=(group="&analysisgrp2" and runid = "&runid"))
                    %end; 
                    %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                        labelfile(in=c where=(group="&psestimategrp" and runid = "&runid"))
                        labelfile(in=d where=(group="&eoi" and runid = "&runid"))
                        labelfile(in=e where=(group="&ref" and runid = "&runid"))
                    %end; 
                    %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
                        labelfile(in=f where=(group="&switch0group." and runid = "&runid"))
                        labelfile(in=g where=(group="&switch1group." and runid = "&runid"))
                        %if %eval(&maxswitch=2) %then %do;
                        labelfile(in=h where=(group="&switch2group." and runid = "&runid"))
                        %end;
                    %end;;
                if a then do;
                    if labeltype = 'grouplabel' then call symputx('grouplabel',strip(label));
                    if labeltype = 'baselinelabel' then call symputx('baselinelabel',cat(', ',strip(label), ','));
                end;
                %if %length(&baselinegroupnum.)>0 %then %do;
                if b then do; if labeltype = 'grouplabel' then call symputx('grouplabel2',strip(label)); end;
                %end;
                %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                if c then do; if labeltype = 'grouplabel' then call symputx('psestimatelabel',strip(label)); end;
                if d then do; if labeltype = 'grouplabel' then call symputx('eoilabel',strip(label)); end;
                if e then do; if labeltype = 'grouplabel' then call symputx('reflabel',strip(label)); end;
                %end;
                %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
                if f then do; if labeltype = 'grouplabel' then call symputx('switch0grplabel',strip(label)); end;
                if g then do; if labeltype = 'grouplabel' then call symputx('switch1grplabel',strip(label)); end;
                %if %eval(&maxswitch=2) %then %do;
                if h then do; if labeltype = 'grouplabel' then call symputx('switch2grplabel',strip(label)); end;
                %end;
                %end;;
            run;
        %end;

        /*Set group labels*/
        %if %sysfunc(prxmatch(m/T1|T3|T5|T2L1/i,&reporttype.)) > 0 %then %do;
            %let grp1_label = %bquote(&grouplabel.);
        %end;
        %else %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            %let grp1_label = %bquote(&eoilabel.);
            %let grp2_label = %bquote(&reflabel.);
        %end;
        %else %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
            %let grp1_label = %bquote(&switch0grplabel.);
            %let grp2_label = %bquote(&switch0grplabel. to &switch1grplabel.);
            %if %eval(&maxswitch=2) %then %do;
            %let grp3_label = %bquote(&switch1grplabel. to &switch2grplabel.);
            %end;
        %end;		
        %else %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
			 %let grp1_label = %sysfunc(tranwrd(%bquote(&grouplabel.&pregnancylabel.), %str(and Non-Pregnant Cohort), %str()));
			 %if &includenonpregnant. = Y  %then %let grp2_label = %bquote(&grouplabel. Non-Pregnant Cohort);       
        %end;
  
		%if %length(&baselinegroupnum.)>0 %then %do;
            %let grp2_label = %bquote(&grouplabel2.);
            %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 and &cohort ne mi %then %do;
            	%let grp2_label = %bquote(&grouplabel2. &pregnancylabel2.);
            %end;
        %end;

        /*Determine number of columns to optimize formatting*/
        %let numcolumns = 2;
        %if &includecomp. = Y %then %do;
            %let numcolumns = %eval(&numcolumns.+2);
        %end;
        %if &computebalance. = Y %then %do;
            %let numcolumns = %eval(&numcolumns.+2);
        %end;
        %if %eval(&maxswitch=2) %then %do;
            %let numcolumns = %eval(&numcolumns.+2);
        %end;

        /*1 block of code for both aggregate and DP tables*/
        %macro baselinereport(dpnum=, aggregated=, dpinparenthesis=, dpcomma=);

			* Process L2 subgroups;
			%let numsubgroups=0;
			%let subgroup=;
			%let subgroupcat=;
			%let subgrouptitle=;

			%if &reporttype = T2L2 or &reporttype = T4L2 %then %do;
				proc sort nodupkey data=Pscs_masterinputs(where=(analysisgrp="&analysisgrp." and runid="&runid." and not missing(subgroup))) 
								   out=_subgroups(keep=subgroup subgroupcat subgrouporder subgroupcatorder combinedlabel);
				by subgrouporder subgroupcatorder;
				run;

				proc sql noprint;
				select count(*) into :numsubgroups from _subgroups;
				quit;
			%end;

			%do sub=0 %to &numsubgroups.;

				%if &sub. > 0 %then %do;
					data _null_;
					set _subgroups;
					if _N_=&sub.;
					call symputx("SubGroup",lowcase(strip(subgroup)));
				    call symputx("SubgroupCat",upcase(strip(subgroupcat)));
					call symputx("subgrouptitle",combinedlabel);
					run;
					
					%let captionlabel = %bquote(&grouplabel.&pregnancylabel&baselinelabel.);
					%let unique_psestimate = 1;
				%end;	
				%else %do;
					%let captionlabel = %bquote(&grouplabel.&pregnancylabel&baselinelabel.);
			        %if %length(&baselinegroupnum.)>0  %then %do;
			        %let captionlabel = %bquote(&grouplabel.&pregnancylabel and &grouplabel2.&pregnancylabel2&baselinelabel.);
			        %end;
			        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) >0 & &psfile. ne covstratfile %then %do;
			        %let captionlabel = %bquote(&psestimatelabel.);
			        %end; 

					%let unique_psestimate = &unique_psestimate_orig;
				%end;
		
                /*For L2 queries, set &tablecount to 0 if covariate stratification AND no subgroups*/
				%if &psfile. = covstratfile and &numsubgroups. = 0 and %eval(&look_start.) = %eval(&look_end.) and 
					&stratifybydp. = N and %eval(&numbaselinetablegrp.=1) %then %let tablecount = 0;

	            %if %eval(&unique_psestimate.) = 1 %then %do;					
	             %tableletter(); 
	             %baseline_procreport(order = &b., table = 'Unadjusted', weight ='Unweighted',
	              title =%quote(Table 1&tableletter.. &aggregated.&unadjusted.Characteristics of &captionlabel. &dpinparenthesis.in the &database. from &startdateformatted. to &&enddate&periodid.formatted.&subgrouptitle.),
	              characteristiclabel =&characteristiclabel.,
	              labcharacteristics = %quote(&labcharacteristics),
	              dpnum = &dpnum.,
	              numcolumns =&numcolumns.,
	              grp1_label=%quote(&grp1_label.),
	              grp2_label=%quote(&grp2_label.), 
	              grp3_label=%quote(&grp3_label.),
	              computebalance = &computebalance.,
	              includenonpregnant=&includenonpregnant.);
	            %end;

	            /*For L2 tables - up to 2 additional adjusted tables*/
	            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
	                /*PS Match Adjusted*/
	                %if &psfile. = psmatchfile %then %do;
	                %tableletter(); 
	                %baseline_procreport(order = &b., table = 'Adjusted', weight = %str('Unweighted', 'Weighted'),
	                  title =%quote(Table 1&tableletter.. &aggregated.Adjusted Characteristics of &grouplabel. (Propensity Score Matched&dpcomma., &ratiolabel.&caliperlabel.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.&subgrouptitle.),
	                  characteristiclabel =&characteristiclabel.,
					  labcharacteristics = %quote(&labcharacteristics),
	                  dpnum = &dpnum.,
	                  numcolumns =&numcolumns.,
	                  grp1_label=%quote(&grp1_label.),
	                  grp2_label=%quote(&grp2_label.), 
	                  grp3_label=%quote(&grp3_label.),
	                  computebalance = &computebalance.,
	                  includenonpregnant=&includenonpregnant.);
	                %end;

	                /*Unweighted - IPTW, PS Stratum, PS Stratification (tree analysis only) */
	                %if (&psfile. = iptwfile & %eval(&unique_psestimate.) = 1) | (&psfile. = stratificationfile & ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") & %eval(&pstrim.>=0)) |
                        (&psfile. = stratificationfile & &treeaggindicator. = Y) %then %do;
						%if &include_unweighted_trim. = Y %then %do;
			                %tableletter(); 
			                %baseline_procreport(order = &b., table = 'Adjusted', weight = 'Unweighted',
			                  title=%quote(Table 1&tableletter.. &aggregated.Unweighted Characteristics of &grouplabel. (Unweighted, Trimmed&dpcomma.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.&subgrouptitle.),
			                  characteristiclabel =&characteristiclabel.,
							  labcharacteristics = %quote(&labcharacteristics),
			                  dpnum = &dpnum.,
			                  numcolumns =&numcolumns.,
			                  grp1_label=%quote(&grp1_label.),
			                  grp2_label=%quote(&grp2_label.), 
			                  grp3_label=%quote(&grp3_label.),
			                  computebalance = &computebalance.,
			                  includenonpregnant=&includenonpregnant.);
						%end;
	                %end;
						
	                /*Weighted - IPTW, PS Stratum, PS Stratification*/
	                %if &psfile. = iptwfile | &psfile. = stratificationfile %then %do;
	                    %if &psfile. = iptwfile %then %let stratumtitle = Inverse Probability of Treatment Weighted, Trimmed&dpcomma., Weight: &weightlabel., Truncation: &truncationlabel.%nrbquote(%);
	                    %else %if "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %let stratumtitle = Propensity Score Stratum Weighted, Trimmed&dpcomma., Percentiles: &percentiles., Weight: &weightlabel.;
	                    %else %let stratumtitle =Propensity Score Stratified&dpcomma., Percentiles: &percentiles.;
	                    %tableletter(); 
	                    %baseline_procreport(order = &b., table = 'Adjusted', weight = 'Weighted',
	                      title=%quote(Table 1&tableletter.. &aggregated.Weighted Characteristics of &grouplabel. (&stratumtitle.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.&subgrouptitle.),
	                      characteristiclabel =&characteristiclabel.,
						  labcharacteristics = %quote(&labcharacteristics),
	                      dpnum = &dpnum.,
	                      numcolumns =&numcolumns.,
	                      grp1_label=%quote(&grp1_label.),
	                      grp2_label=%quote(&grp2_label.), 
	                      grp3_label=%quote(&grp3_label.),
	                      computebalance = &computebalance.,
	                      includenonpregnant=&includenonpregnant.);
	                %end;
	            %end; /*Additional L2 tables*/
		  	%end; /*Subgroups looping*/
        %mend;

        /*loop through each periodid*/
        %do periodid = %eval(&look_start.) %to %eval(&look_end.);
            /*Aggregated*/
            %baselinereport(dpnum=0, 
                            %if %eval(&num_dp.)=1 %then %do;
                            aggregated=,
                            %end;
                            %else %do;
                            aggregated=%str(Aggregated ),
                            %end;
                            dpinparenthesis=, dpcomma=);
   
            /*Output seperate table for each Data Partner - loop through each DP*/
            %if &stratifybydp. = Y %then %do;    
                %do dps = 1 %to %eval(&num_dp.);
        	        %let maskedID = %scan(&masked_dplist,&dps); 
                    %baselinereport(dpnum=&dps., aggregated = , dpinparenthesis=%str((&maskedid.) ), dpcomma=%str(, &maskedid.));
                %end;
            %end; /*DP stratification*/
        %end; /*loop through each periodid*/
    %end; /*loop through each row in baselinefile*/
    %end; /*include baseline tables */

    %put =====> END MACRO: baseline_output ;

%mend baseline_output;
