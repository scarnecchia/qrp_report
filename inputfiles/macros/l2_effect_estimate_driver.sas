****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_driver.sas  
* Created (mm/dd/yyyy): 02/03/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the computation of effect estimates and summary statistcs for L2 reports
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

%macro l2_effect_estimate_driver();

    %put =====> MACRO CALLED: l2_effect_estimate_driver;

    %isdata(dataset=l2comparisonfile);
    %if %eval(&nobs.>0) %then %do;

    ***********************************************************************************************;
    * Utility macros to subset data and assign category dummy vars                         
    ***********************************************************************************************;
    %macro subsetdata(datain=, dataout=, covarnum=, cat=);
        data &dataout.;
            set &datain.;
            where covarnum=&covarnum. and Dum&cat.=1;
        run;
    %mend;

    %macro subgroupdummyvar(datain=, dataout=, covarnum=, numcat=, categorization = );
        data &dataout.;
            set &datain.(where=(covarnum=&covarnum.) drop=dum:);
            dum0=1;
            array dum{*} dum1-dum&NumCat.;
            do SubComp=1 to &NumCat.;
                if scan("&categorization.",SubComp,' ')=subgroupcat then dum(SubComp)=1; 
                else dum(SubComp)=0; 
            end;
            SubComp=SubComp-1;
        run;
    %mend;
	
	***********************************************************************************************;
    * Add unique psestimategrp flag to the l2comparisonfile                      
    ***********************************************************************************************;
	 proc sql noprint;
	   create table _l2comparisonfile_ps as
	     select base.*
	 	       ,pscs.psestimategrp
	     from l2comparisonfile as base
	 	 left join pscs_masterinputs (where = (covarnum = 0)) as pscs
	 	  on base.runid = pscs.runid
	      and base.analysisgrp = pscs.analysisgrp
	      order by runid, psestimategrp, order;
	 quit;
	 
	 data l2comparisonfile;
	   set _l2comparisonfile_ps; 
	   length unique_psestimate 3;
	   retain unique_psestimate;
	   by runid psestimategrp order;
	   unique_psestimate +1;
       if missing(psestimategrp) or first.psestimategrp then unique_psestimate = 1;
	 run;
	 
	 proc sort data = l2comparisonfile;
	   by order;
	 run;

    ***********************************************************************************************;
    * Loop through each AnalysisGrp                               
    ***********************************************************************************************;
    %do loopcount = 1 %to &numl2comparisons.; 
     
        /*Initialize macro variables for the analysisgrp loop*/
        %let pscsfile = ;
        %let classvars = ;
        %let noclassvars = ;
        %let stratavar = ; /*variable that indicates conditional groupings (matchID or percentile)*/
        %let covarnumlist =;
        %let numsubgroup = 0; /*number of subgroups*/
        %let convrule = ;

        /*set parameters from l2comparisonfile for this loop*/
        data _null_;
            set l2comparisonfile(where=(order=&loopcount.));
            call symputx('runid', runid);
            call symputx('analysisgrp', analysisgrp);
            call symputx('outputconditional', outputconditional);
            call symputx('outputunconditional', outputunconditional);
            call symputx('classvars', classvars);
            call symputx('noclassvars', noclassvars);
			call symputx('unique_psestimate', unique_psestimate);
            if not missing(convrule) then call symputx('convrule', convrule);
        run;
        %put now computing effect estimates for &analysisgrp.;
       
        /*extract QRP input file associated with analysisgrp*/
        proc sql noprint;
            select distinct strip(file) into: pscsfile trimmed
            from pscs_masterinputs
            where analysisgrp = "&analysisgrp." and runid = "&runid";
        quit;
        
        %if %str("&pscsfile.") = %str("") %then %do;
            %put WARNING: (Sentinel) &analysisgrp. not found in QRP input files. Effect Estimates will not be computed;
            %goto nextloop;
        %end;

        /*How many subgroup analyses for this analysisgrp*/
        %if &pscsfile. ne iptwfile %then %do;
            data _Subgrp;
                set infolder.&&&runid._&pscsfile.;
                where lowcase(analysisgrp) = "&analysisgrp" and covarnum ne 0;
            run;

            %isdata(dataset=_Subgrp);
            %if %eval(&nobs.>0) %then %do;
                proc sql noprint;
                    select covarnum 
                    into :covarnumlist separated by ' '
                    from _Subgrp;

                    select count(*) into :numsubgroup
                    from _subgrp;
                quit;
                %put Number of Subgroups for &analysisgrp.: &numsubgroup.;
            %end;
        %end;

        /******************************/
        /* loop through each covarnum */
        /******************************/
        %do sub=0 %to &numsubgroup.;  *Note: 0 is for full analysis;
            %if &sub. = 0 %then %let covarnum = 0;
            %else %let covarnum = %scan(&covarnumlist, &sub.);

            /*Initialize macro variables for the covarnum loop*/
            %let grp0 = ;
            %let grp1 = ;
            %let unconditional_distributed = N;
            %let outputconditional = N;
            %let outputunconditional = N;
            %let ratio = ;
            %let ceiling = ;
            %let analysisgrpweight = ;
            %let suppresscolumns = N;
            %let psestimategrp = ;
            %let stratavar = ;
            %let analysisgrpweight = ;
            %let individualreturn = N;
            %let marginalweights = N;
            %let cat=0; /*indicator for subgroup categories*/
            %let subcategorization=; *the list of categorization;
            %let subgroupvar=;
            %let numsubcat=0;  /*store number of subgroups to loop through. 0 = overall analysis*/  
            %let ormethod = logit; /*method for computing odds ratio*/
			%let hdps = N; /* indicator for hdps vars */

            /*probabilties for Type 4 ORs*/
            %let s11=;
            %let s01=;
            %let s10=;
            %let s00=;

            /*Use risk set or individual level return*/
            %if "%upcase(&&&runid._indlevel)" = "Y" %then %do;  
                %let individualreturn = Y;
            %end;

            /*extract names of eoi and ref groups and associated parameters for the analysisgrp*/
            %put extracting parameters from &pscsfile. for analysisgrp = &analysisgrp. and covarnum = &covarnum.;
            data _null_; 
                set pscs_masterinputs(where=(analysisgrp="&analysisgrp." and covarnum = &covarnum.));

                %if &pscsfile. = psmatchfile %then %do;
                    call symputx("psestimategrp", lowcase(psestimategrp));
                    call symputx("unconditional_distributed", upcase(unconditional));
                    call symputx("stratavar", 'matchid');
                    call symputx('ratio',upcase(ratio));
                    call symputx('ceiling',put(ceiling, best.));
                    /*type 4 fixed ratio match - conditional = N and unconditional = Y*/
                    /*type 2 fixed ratio match - options defined by user below*/
                    /*type 2 variable ratio match - conditional = Y and unconditional = N*/
                    %if &reporttype. = T4L2 %then %do;
                        if upcase(ratio) = "F" then call symputx('outputunconditional', 'Y');
                    %end;
                    if upcase(ratio) = "V" then do;
                        call symputx("suppresscolumns", "Y");
                        call symputx('outputconditional', 'Y');
                    end;
                %end;

                %if &pscsfile. = stratificationfile %then %do;
                    call symputx("psestimategrp", lowcase(psestimategrp));
                    call symputx("stratavar", 'percentile');
                    call symputx("analysisgrpweight",strip(upcase(strataweight)));
                    call symputx('ormethod', 'cmh');
                    /*set individualreturn to N*/
                    if missing(strataweight)=0 then do;
                        call symputx('individualreturn', 'N');
                        call symputx('marginalweights', 'Y');
                    end;
                    else do;
                    call symputx('outputconditional', 'Y');
                    end;
                %end;

                %if &pscsfile. = iptwfile %then %do;
                    call symputx("psestimategrp", lowcase(psestimategrp));
                    call symputx("analysisgrpweight",strip(upcase(ipweight)));
                    /*set individualreturn to N*/
                    if missing(ipweight)=0 then do;
                        call symputx('individualreturn', 'N');
                        call symputx('marginalweights', 'Y');
                    end;
                %end;

                %if &pscsfile. = covstratfile %then %do;
                    call symputx('GRP1', eoi) ;
                    call symputx('GRP0', ref) ;     
                    call symputx("stratavar", 'covarstrat');
                    call symputx('outputconditional', 'Y');
                %end;
            run;

            %if &pscsfile. = psmatchfile | &pscsfile. = stratificationfile | &pscsfile. = iptwfile %then %do;
                data _null_; 
                    set infolder.&&&runid._psestimationfile(where=(lowcase(psestimategrp)="&psestimategrp."));
                    call symputx('GRP1', eoi);
                    call symputx('GRP0', ref); 
                    call symputx('HDPS',hdps);
                    if missing(ranking) then call symputx('ranking','exp_assoc');
                    else if lowcase(ranking) = 'bias' then call symputx('ranking','bias_assoc');
                    else call symputx('ranking',strip(lowcase(ranking)));					
                run;
            %end;

            /*Set OutputConditional and OutputUnconditional parameters - only an option for PS Fixed Ratio Match for Type 2*/
            %if &pscsfile. = psmatchfile & &ratio.= F & &reporttype. = T2L2 %then %do;
                data _null_;
                    set l2comparisonfile(where=(order=&loopcount.));
                    call symputx('outputconditional', outputconditional);
                    %if &unconditional_distributed = Y %then %do;
                    call symputx('outputunconditional', outputunconditional);
                    %end;
                run;
            %end;

            /******************/
            /* Aggregate data */
            /******************/
			/* Riskdiffdata does not exist for TREE analysis */
			%if %index(&reporttype.,TREE) = 0 %then %do;
              %aggregate_l2_datasets(infile=&runid._riskdiffdata_&periodid.,
                                     outfile=aggrd,
                                     pscsfile=&pscsfile.,
                                     %if &pscsfile. = stratificationfile & "&reporttype" = "T4L2" %then %do;
                                     whereclause=%str(lowcase(analysisgrp)="&analysisgrp" and percentile ^='0'), 
                                     %end;
                                     %else %do;
                                     whereclause=%str(lowcase(analysisgrp)="&analysisgrp"), 
                                     %end;
                                     convrule=%quote(&convrule.),
                                     convdata=&runid._estimates_&periodid.,
                                     settomissvars=%str(Exp,UnExp,EVExp,EVUnExp,FUTimeExp,FUTimeUnExp,weight,weighted_diff)
                                     %if &pscsfile. = stratificationfile & "&reporttype" = "T4L2" %then %do;
                                     , renameclause=%str( rename=percentilevalue = percentile)
                                     %end;
                                     );
			%end;
            %if &individualreturn. = Y %then %do;
                /*[runid]_adjusted_&periodid.*/
                %aggregate_l2_datasets(infile=&runid._adjusted_&periodid.,
                                       outfile=aggpl,
                                       pscsfile=&pscsfile.,
                                       whereclause=%str(lowcase(analysisgrp)="&analysisgrp"), 
                                       convrule=%quote(&convrule.),
                                       convdata=&runid._estimates_&periodid.,
                                       settomissvars=%str(matchID,pscore,percentile));

                /*if individual-level data does not exist set individualreturn = N*/
                %if %sysfunc(exist(aggpl))=0 %then %do; 
                    %put WARNING: (Sentinel) &analysisgrp. does not exist on &runid._adjusted_&periodid. for covarnum &covarnum.. Risk set data will be used;
                    %let individualreturn=N;
                %end;
            %end; /*aggregate individual level data*/
            %if &individualreturn. = N & "&reporttype" = "T2L2" %then %do;
                %aggregate_l2_datasets(infile=&runid._risksetdata_&periodid.,
                                       outfile=aggrs,
                                       pscsfile=&pscsfile.,
                                       whereclause=%str(lowcase(analysisgrp)="&analysisgrp"), 
                                       convrule=%quote(&convrule.),
                                       convdata=&runid._estimates_&periodid.,
                                       settomissvars=%str(risksetpop,Followuptime,RiskSetID,ExposureProbability));
                /*compute log odds on aggrs dataset*/
                data aggrs;
                    set aggrs;
                    if ExposureProbability not in(0,1) then do;
                        odds=Exposureprobability/(1-Exposureprobability);
                        logodds=log(odds);
                    end;
                run;
				%if &covarnum = 0 %then %do;
                   %if &marginalweights. = Y %then %do;
                   %aggregate_l2_datasets(infile=&runid._marginalweights_&periodid.,
                                          outfile=aggmw,
                                          pscsfile=&pscsfile.,
                                          whereclause=%str(lowcase(analysisgrp)="&analysisgrp"), 
                                          convrule=%quote(&convrule.),
                                          convdata=&runid._estimates_&periodid.,
                                          settomissvars=%str(Followuptime,RiskSetID,SumEC,SumC,SumE,SumUnE,SumSquareEC,SumSquareUnEC,SumSquareE,SumSquareUnE));
				   					   
				   %aggregate_l2_datasets(infile=&runid._weightdistribution_&periodid.,
                                          outfile=aggwd,
                                          pscsfile=&pscsfile.,
                                          whereclause=%str(lowcase(analysisgrp)="&analysisgrp"), 
                                          convrule=%quote(&convrule.),
                                          convdata=&runid._estimates_&periodid.,
                                          settomissvars=%str(n, min, max, mean, sd),
                                          runidvar=&runid.);					   
                   %end; /* aggregate weighted and marginalweights data */	
                %end; /* Only run for overall data */		   
            %end; /*aggregate risk set data*/
			%if &hdps. = Y and &unique_psestimate. = 1 and &covarnum. = 0 %then %do;
			   %aggregate_l2_datasets(infile=&runid._varinfo_&periodid.,
                                      outfile=agghdps,
                                      pscsfile=&pscsfile.,
                                      whereclause=%str(lowcase(psestimategrp)="&psestimategrp" and lowcase(selected_for_ps) = "true"), 
                                      convrule=%quote(&convrule.),
                                      convdata=&runid._estimates_&periodid.,
									  settomissvars=%str(codecat, codetype, frequency, ranking, code),
									  renameclause = %str(rename = (code_id = code  &ranking._ranking_var = ranking)),
                                      runidvar=&runid.);	
			%end;/*aggregate hdps vars for unique psestimategrps*/
           
            /****************************************************************************************/
            /* For overall analysis - subset data where covarnum = 0 and execute computation macros */
            /****************************************************************************************/
            %if &sub. = 0 %then %do;
			    /* Riskdiffdata does not exist for TREE analysis */
			    %if %index(&reporttype.,TREE) = 0 %then %do;
                  %subsetdata(datain=aggrd, dataout=cat_dp_rd, covarnum=&covarnum., cat=&cat.);
				%end;
                %if &individualreturn. = Y %then %do;
                    %subsetdata(datain=aggpl, dataout=cat_dp_pl, covarnum=&covarnum., cat=&cat.);
                %end;
                %if &individualreturn. = N %then %do;
                    %if %str("&reporttype") = "T2L2" %then %do;
                    %subsetdata(datain=aggrs, dataout=cat_dp_rs, covarnum=&covarnum., cat=&cat.);
                    %end;
                    %if &marginalweights. = Y %then %do;
                    %subsetdata(datain=aggmw, dataout=cat_dp_mw, covarnum=&covarnum., cat=&cat.);
                    %end;
                %end;
                
                /*Extract selectprobabilities parameters*/
                %if %str("&reporttype") = %str("T4L2") %then %do;
                    %isdata(dataset=SelectionProbabilitiesFile);
                    %if %eval(&nobs.>0) %then %do;
                    data _null_;
                        set SelectionProbabilitiesFile(where=(analysisgrp="&analysisgrp." and runid = "&runid" and covarnum = &covarnum.));
                        call symputx('s11', s11);
                        call symputx('s01', s01);
                        call symputx('s10', s10);
                        call symputx('s00', s00);
                    run;
                    %end;
                %end; 

                /*****************************************************************/
                /* Execute macros to calculate effect estimates and risk metrics */
                /*****************************************************************/

                ods select none;

                /*************************************************************************************
                /* Type 2 tables
                    %l2_effect_estimate_runlogithr = HR Logit model (risk set)
                    %l2_effect_estimate_runcox = Cox model (patient level)
                    %l2_effect_estimate_runrobusthr - Robust marginal sandwich estimator (risk set) 
                    %l2_effect_estimate_runrd_rs = Incidence rates, risk differences                  

                   Type 4 tables
                    %l2_effect_estimate_runlogitor = OR Logit model or CMH (risk set and patient level)
                    %l2_effect_estimate_runrd_rs = risk ratio, risk differences (risk set)

                   Macro calls for risk metrics are the same for ReportType = T2L2 and T4L2 for risk set
                   data. ReportType = T2L2 can also compute risk metrics using individual level data
                /**************************************************************************************/

                /*Unadjusted*/
				/* Empty rdest dataset will be created for TREE analysis */
                %l2_effect_estimate_runrd_rs(where=analysis="Unadjusted" and subgroupcat="", analysis= "Unadjusted", subgroupcat = , donotreport=N);
                %if %str("&reporttype.") = %str("T2L2") %then %do;
                    %if &individualreturn. = Y %then %do;
                    %l2_effect_estimate_runcox(where=missing(subgroupcat), strata=dpidsiteid, analysis= "Unadjusted", subgroupcat = );
                    %end;
                    %if &individualreturn. = N %then %do;
                    %l2_effect_estimate_runlogithr(where=analysis="Unadjusted", analysis= "Unadjusted", subgroupcat = );
                    %end;
                %end;
                %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                    %if &individualreturn. = Y %then %do;
                    %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(subgroupcat), analysis="Unadjusted",
                                                   subgroupcat=, ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
				
                    %end;
                    %if &individualreturn. = N %then %do;
                    %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Unadjusted", analysis="Unadjusted",
                                                   subgroupcat=, ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                    %end;
                %end;
                /*Conditional - 
                    *analysis conditioned on matchid (PS maching) - Type 2 only
                    *analysis conditioned on percentile (PS stratification) - Type 2 and 4
                    *analysis conditioned on covariate (Covariate stratification) - Type 2 and 4 */
                %if &outputconditional. = Y %then %do; 
				    /* Empty rdest dataset will be created for TREE analysis */
                    %l2_effect_estimate_runrd_rs(where=analysis="Conditional" and subgroupcat="", 
                                                 analysis= "Conditional", 
                                                 subgroupcat = , 
                                                 donotreport=&suppresscolumns.);
                      %if %str("&reporttype.") = %str("T2L2") %then %do;
                        %if &individualreturn. = Y %then %do;
                        %l2_effect_estimate_runcox(where=missing(subgroupcat) and missing(&stratavar.)=0, 
                                                   strata=%quote(dpidsiteid &stratavar.),
                                                   analysis= "Conditional", 
                                                   subgroupcat = );
                        %end;
                        %if &individualreturn. = N %then %do;
                        %l2_effect_estimate_runlogithr(where=analysis="Conditional",
                                                     analysis= "Conditional", 
                                                     subgroupcat = );
                        %end;
                    %end;
                    %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                        %if &individualreturn. = Y %then %do;
                        %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(subgroupcat) and missing(&stratavar.)=0, analysis="Conditional",
                                                       subgroupcat=, ormethod=&ormethod., s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                        %end;
                        %if &individualreturn. = N %then %do;
                        %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Conditional", analysis="Conditional",
                                                       subgroupcat=, ormethod=&ormethod., s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                        %end;
                    %end;
                %end;
           
                /*Unconditional - only for FRM PS match analysis*/
                %if &outputunconditional = Y %then %do;
				    /* Empty rdest dataset will be created for TREE analysis */
                    %l2_effect_estimate_runrd_rs(where=analysis="Unconditional" and subgroupcat="", 
                                                 analysis= "Unconditional", 
                                                 subgroupcat = , 
                                                 donotreport=N);
                    %if %str("&reporttype.") = %str("T2L2") %then %do;
                        %if &individualreturn. = Y %then %do;
                        %l2_effect_estimate_runcox(where=missing(subgroupcat) and missing(&stratavar.)=0, 
                                                   strata=%quote(dpidsiteid), 
                                                   analysis= "Unconditional", 
                                                   subgroupcat = );
                        %end;
                        %if &individualreturn. = N %then %do;
                        %l2_effect_estimate_runlogithr(where=analysis="Unconditional", analysis= "Unconditional", subgroupcat = );
                        %end;
                    %end;
                    %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                        %if &individualreturn. = Y %then %do;
                        %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(subgroupcat) and missing(&stratavar.)=0, analysis="Unconditional",
                                                       subgroupcat=, ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                        %end;
                        %if &individualreturn. = N %then %do;
                        %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Unconditional", analysis="Unconditional",
                                                       subgroupcat=, ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                        %end;
                    %end;
                %end;
                
                /*PS IPTW/Weighted Stratification analysis - Type 2 only
                    - Unweighted (risk metrics)
                    - Weighted (Risk metrics and effect estimate)*/
                %if &marginalweights. = Y %then %do;
                %l2_effect_estimate_runrobusthr(where=analysis="Weighted", analysis="Weighted", subgroupcat=);
                %l2_effect_estimate_runrd_rs(where=analysis="Unweighted" and subgroupcat="", analysis= "Unweighted", subgroupcat = , donotreport=N);
                %l2_effect_estimate_runrd_rs(where=analysis="Weighted" and subgroupcat="", analysis= "Weighted", subgroupcat = , donotreport=N);
                %end;

                /**********************************************************************************/
                /* Stratify overall tables by DP                                                  */
                /**********************************************************************************/
                %if "&stratifybyDP" = "Y" %then %do;
                    %let covarnum = 9000; /*set to 9000 for DP stratification*/

                    %do dps = 1 %to &num_dp;
                        %let dpname =%scan(&masked_dplist.,&dps.); 
                        %put &dpname.; 

                        /*Unadjusted*/
						/* Empty rdest dataset will be created for TREE analysis */
                        %l2_effect_estimate_runrd_rs(where=analysis="Unadjusted" and subgroupcat="" and dpidsiteid="&dpname.", 
                                                     analysis= "Unadjusted", subgroupcat = &dpname., donotreport=N);
                        %if "&reporttype." = "T2L2" | "&reporttype." = "TREE2" %then %do;
                            %if &individualreturn. = Y %then %do;
                            %l2_effect_estimate_runcox(where=missing(subgroupcat) and dpidsiteid="&dpname.", 
                                                       strata=dpidsiteid, 
                                                       analysis= "Unadjusted", 
                                                       subgroupcat = &dpname.);
                            %end;
                            %if &individualreturn. = N %then %do;
                            %l2_effect_estimate_runlogithr(where=analysis="Unadjusted" and dpidsiteid="&dpname.", analysis= "Unadjusted",subgroupcat = &dpname.);
                            %end;
                        %end;
                        %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                            %if &individualreturn. = Y %then %do;
                            %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(subgroupcat) and dpidsiteid="&dpname", analysis="Unadjusted",
                                                           subgroupcat=&dpname., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                            %end;
                            %if &individualreturn. = N %then %do;
                            %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Unadjusted" and dpidsiteid="&dpname", analysis="Unadjusted",
                                                           subgroupcat=&dpname., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                            %end;
                        %end;

                        /*Conditional*/ 
                        %if &outputconditional. = Y %then %do;
                            /* Empty rdest dataset will be created for TREE analysis */					
                            %l2_effect_estimate_runrd_rs(where=analysis="Conditional" and subgroupcat="" and dpidsiteid="&dpname.", 
                                                         analysis= "Conditional", 
                                                         subgroupcat = &dpname., 
                                                         donotreport=&suppresscolumns.);
                            %if %str("&reporttype.") = %str("T2L2") %then %do;
                                %if &individualreturn. = Y %then %do;
                                %l2_effect_estimate_runcox(where=missing(subgroupcat) and missing(&stratavar.)=0 and dpidsiteid="&dpname.", 
                                                           strata=%quote(dpidsiteid &stratavar.), 
                                                           analysis= "Conditional", 
                                                           subgroupcat =&dpname.);
                                %end;
                                %if &individualreturn. = N %then %do;
                                %l2_effect_estimate_runlogithr(where=analysis="Conditional" and dpidsiteid="&dpname.", analysis= "Conditional", subgroupcat = &dpname.);
                                %end;
                            %end;
                            %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                                %if &individualreturn. = Y %then %do;
                                %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(subgroupcat) and dpidsiteid="&dpname", analysis="Conditional",
                                                               subgroupcat=&dpname., ormethod=&ormethod., s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                                %end;
                                %if &individualreturn. = N %then %do;
                                %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Conditional" and dpidsiteid="&dpname", analysis="Conditional",
                                                               subgroupcat=&dpname., ormethod=&ormethod., s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                                %end;
                            %end;
                        %end;
                   
                        /*Unconditional - only for FRM PS match analysis*/
                        %if &outputunconditional. = Y %then %do;
						    /* Empty rdest dataset will be created for TREE analysis */
                            %l2_effect_estimate_runrd_rs(where=analysis="Unconditional" and subgroupcat="" and dpidsiteid="&dpname.", 
                                                         analysis= "Unconditional", 
                                                         subgroupcat = &dpname., 
                                                         donotreport=N);
                            %if %str("&reporttype.") = %str("T2L2") %then %do;
                                %if &individualreturn. = Y %then %do;
                                %l2_effect_estimate_runcox(where=missing(subgroupcat) and missing(&stratavar.)=0 and dpidsiteid="&dpname.", 
                                                           strata=%quote(dpidsiteid), 
                                                           analysis= "Unconditional", 
                                                           subgroupcat = &dpname.);
                                %end;
                                %if &individualreturn. = N %then %do;
                                %l2_effect_estimate_runlogithr(where=analysis="Unconditional" and dpidsiteid="&dpname.", analysis= "Unconditional", subgroupcat = &dpname.);
                                %end;
                            %end;
                            %else %if "&reporttype." = "T4L2" | "&reporttype." = "TREE4" %then %do;
                                %if &individualreturn. = Y %then %do;
                                %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(subgroupcat) and missing(&stratavar.)=0 and dpidsiteid="&dpname", analysis="Unconditional",
                                                               subgroupcat=&dpname., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);

                                %end;
                                %if &individualreturn. = N %then %do;
                                %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Unconditional" and dpidsiteid="&dpname", analysis="Unconditional",
                                                               subgroupcat=&dpname., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                                %end;
                            %end;
                        %end;
                        
                        /*PS IPTW/Weighted Stratification analysis:
                            - Unweighted (risk metrics)
                            - Weighted (Risk metrics and effect estimate)*/
                        %if &marginalweights. = Y %then %do;
                        %l2_effect_estimate_runrobusthr(where=analysis="Weighted" and dpidsiteid="&dpname.", analysis="Weighted", subgroupcat=&dpname.);
                        %l2_effect_estimate_runrd_rs(where=analysis="Unweighted" and subgroupcat="" and dpidsiteid="&dpname.",
                                                     analysis= "Unweighted", subgroupcat = &dpname., donotreport=N);
                        %l2_effect_estimate_runrd_rs(where=analysis="Weighted" and subgroupcat="" and dpidsiteid="&dpname.", 
                                                     analysis= "Weighted", subgroupcat = &dpname., donotreport=N);
                        %end;
                    %end; *dp;  
                %end; /*stratifybyDP = Y*/

                proc datasets library=work nowarn nolist;
                    delete cat_dp:;
                quit;

            %end; /*end overall metric computations*/


            /**********************************************************************************/
            /* For subgroup analyses - determine subgroup categories and number of categories */
            /**********************************************************************************/

            %if &sub. ne 0 & &marginalweights. = N %then %do;
                %l2_effect_estimate_subgroups(covarnum=&covarnum., computecategories=Y);
				/* Riskdiffdata does not exist for TREE analysis */
			    %if %index(&reporttype.,TREE) = 0 %then %do;
                  %subgroupdummyvar(datain=aggrd, dataout=aggrd&sub., covarnum=&covarnum., numcat=&numsubcat., categorization =&subcategorization.);
				%end;
                *Assign generic dummies for automatic selection;
                %if &individualreturn. = Y %then %do;
                    %subgroupdummyvar(datain=aggpl, dataout=aggpl&sub., covarnum=&covarnum., numcat=&numsubcat., categorization =&subcategorization.);
                %end;
                %if &individualreturn. = N & %str("&reporttype") = "T2L2" %then %do;
                    %subgroupdummyvar(datain=aggrs, dataout=aggrs&sub., covarnum=&covarnum., numcat=&numsubcat., categorization =&subcategorization.);
                %end;

                /*Loop through each subgroup category*/
                %do cat=1 %to &numsubcat.;
                    %let subgroupcat = %scan(&subcategorization., &cat., ' ');

                    /*Restrict data to subgroup category*/
					/* Riskdiffdata does not exist for TREE analysis */
			        %if %index(&reporttype.,TREE) = 0 %then %do;
                      %subsetdata(datain=aggrd&sub., dataout=cat_dp_rd, covarnum=&covarnum., cat=&cat.);
                    %end;
					%if &individualreturn. = Y %then %do;
                    %subsetdata(datain=aggpl&sub., dataout=cat_dp_pl, covarnum=&covarnum., cat=&cat.);
                    %end;
                    %if &individualreturn. = N & %str("&reporttype") = "T2L2" %then %do;
                    %subsetdata(datain=aggrs&sub., dataout=cat_dp_rs, covarnum=&covarnum., cat=&cat.);
                    %end;

                    /*Extract selectprobabilities parameters*/
                    %if %str("&reporttype") = %str("T4L2") %then %do;
                        %let s11 = ;
                        %let s01 = ;
                        %let s10 = ;
                        %let s00 = ;
                        %isdata(dataset=SelectionProbabilitiesFile);
                        %if %eval(&nobs.>0) %then %do;
                        data _null_;
                            set SelectionProbabilitiesFile(where=(analysisgrp="&analysisgrp." and runid = "&runid" and covarnum = &covarnum. and value = "&subgroupcat"));
                            call symputx('s11', s11);
                            call symputx('s01', s01);
                            call symputx('s10', s10);
                            call symputx('s00', s00);
                        run;
                        %end;
                    %end;

                    /***************************************************************************************/
                    /* Execute macros to calculate effect estimates and risk metrics for subgroup category */
                    /***************************************************************************************/

                    /*Unadjusted*/
					/* Empty rdest dataset will be created for TREE analysis */
                    %l2_effect_estimate_runrd_rs(where=Analysis="Unadjusted", Analysis= "Unadjusted", subgroupcat = &subgroupcat., donotreport=N);
                    %if "&reporttype." = "T2L2" | "&reporttype." = "TREE2" %then %do;
                      %if &individualreturn. = Y %then %do;
                      %l2_effect_estimate_runcox(where=missing(subgroupcat)=0, strata=%quote(dpidsiteid &subgroupvar.), Analysis= "Unadjusted", subgroupcat = &subgroupcat.);
                      %end;
                      %if &individualreturn. = N %then %do;
                      %l2_effect_estimate_runlogithr(where=analysis="Unadjusted", Analysis= "Unadjusted", subgroupcat = &subgroupcat.);
                      %end;
                    %end;
                    %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                        %if &individualreturn. = Y %then %do;
                        %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(subgroupcat)=0, analysis="Unadjusted",
                                                       subgroupcat=&subgroupcat., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                        %end;
                        %if &individualreturn. = N %then %do;
                        %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Unadjusted", analysis="Unadjusted",
                                                       subgroupcat=&subgroupcat., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                        %end;
                    %end;

                    /*Conditional*/ 
                    %if &outputconditional. = Y %then %do; 
					    /* Empty rdest dataset will be created for TREE analysis */
                        %l2_effect_estimate_runrd_rs(where=Analysis="Conditional", Analysis= "Conditional", subgroupcat = &subgroupcat., donotreport=&suppresscolumns.);
                        %if %str("&reporttype.") = %str("T2L2") %then %do;
                            %if &individualreturn. = Y %then %do;
                            %l2_effect_estimate_runcox(where=missing(&stratavar.)=0 and missing(subgroupcat)=0, strata=%quote(dpidsiteid &stratavar. &subgroupvar.), Analysis= "Conditional", subgroupcat = &subgroupcat.);
                            %end;
                            %if &individualreturn. = N %then %do;
                            %l2_effect_estimate_runlogithr(where=analysis="Conditional", Analysis= "Conditional", subgroupcat = &subgroupcat.);
                            %end;
                        %end;
                        %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                            %if &individualreturn. = Y %then %do;
                            %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(&stratavar.)=0 and missing(subgroupcat)=0, analysis="Conditional",
                                                           subgroupcat=&subgroupcat., ormethod=&ormethod., s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                            %end;
                            %if &individualreturn. = N %then %do;
                            %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Conditional", analysis="Conditional",
                                                           subgroupcat=&subgroupcat., ormethod=&ormethod., s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                            %end;
                        %end;
                    %end;
               
                    /*Unconditional - only for FRM PS match analysis*/
                    %if &outputunconditional. = Y %then %do;
					    /* Empty rdest dataset will be created for TREE analysis */
                        %l2_effect_estimate_runrd_rs(where=Analysis="Unconditional", Analysis= "Unconditional", subgroupcat = &subgroupcat., donotreport=N);
                        %if "&reporttype." = "T2L2" | "&reporttype." = "TREE2" %then %do;
                          %if &individualreturn. = Y %then %do;
                          %l2_effect_estimate_runcox(where=missing(&stratavar.)=0 and missing(subgroupcat)=0, strata=%quote(dpidsiteid &subgroupvar.), Analysis= "Unconditional", subgroupcat = &subgroupcat.);
                          %end;
                          %if &individualreturn. = N %then %do;
                          %l2_effect_estimate_runlogithr(where=analysis="Unconditional", Analysis= "Unconditional", subgroupcat = &subgroupcat.);
                          %end;
                        %end;
                        %else %if %str("&reporttype.") = %str("T4L2") %then %do;
                            %if &individualreturn. = Y %then %do;
                            %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=missing(&stratavar.)=0 and missing(subgroupcat)=0, analysis="Unconditional",
                                                           subgroupcat=&subgroupcat., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                            %end;
                            %if &individualreturn. = N %then %do;
                            %l2_effect_estimate_runlogitor(individualreturn =&individualreturn., where=analysis="Unconditional", analysis="Unconditional",
                                                           subgroupcat=&subgroupcat., ormethod=logit, s00=&s00., s01=&s01., s10=&s10., s11=&s11.);
                            %end;
                        %end;
                    %end;

                proc datasets library=work nowarn noprint;
                    delete cat_:;
                quit;
                
                %end; /*loop through each subgroup category*/
 
            %end; /* if subgroups exist*/

            proc datasets library=work nowarn noprint;
                delete aggpl: aggrd: aggrs: aggmv: cat_:;
            quit;

        %end; /*end loop through each covarnum*/

    %nextloop:

    %end; /*loop through each analysisgrp*/

    /*Merge together risk metrics and effect estimates*/
    proc sql noprint;
        create table l2_effectestimates_&periodid. as
        select r.*, case when (r.covarnum) = 1000 then put(r.subgroupcat,$sexfmt.)
                         when (r.covarnum) = 1012 then put(r.subgroupcat,$racefmt.)
                         when (r.covarnum) = 1013 then put(r.subgroupcat,$hispanicfmt.)
                         when (r.covarnum) = 1014 then put(r.subgroupcat,$deliveryfmt.)
                         when (r.covarnum) = 2000 then put(r.subgroupcat,$matchfmt.)
                         when (r.covarnum) = 2001 then put(r.subgroupcat,$birthtypefmt.)
                         when (r.covarnum) = 1003 then put(r.subgroupcat,$timefmt.)
                         when (r.covarnum) in (1001, 1002, 9000) then r.subgroupcat
                         else r.subgroupcat
                         end as title length=200,
            %if "&reporttype." = "T2L2" | "&reporttype." = "TREE2" %then %do;
            HR_95CI, HR_pvalue, HR, LCL, UCL, HR_coef, HR_se
            %end;
            %else %if "&reporttype." = "T4L2" | "&reporttype." = "TREE4" %then %do;
            or_95ci, or, LCL, UCL, or_se, adjor_95ci, adjor, adjor_LCL, adjor_UCL
            %end;
        from rdest as r
        /* left join b/c IPTW contains rows that do not have a computed HR*/
        left join logitest as c
        on r.monitoringperiod = c.monitoringperiod
          and r.analysisgrp = c.analysisgrp
          and r.covarnum = c.covarnum
          and r.catnum = c.catnum
          and r.analysis=c.analysis
          and r.subgroupcat = c.subgroupcat;
    quit;

    proc sort data=l2_effectestimates_&periodid. sortseq=linguistic(Numeric_Collation=ON);
        by analysisgrpsort covarnum catnum subgroupcat sort1 sort2;
    run;

    proc datasets lib=work nolist nowarn; 
        delete rdest logitest; 
    quit;

    %end; /*L2ComparisonFile input file exists*/

    %put =====> END MACRO: l2_effect_estimate_driver ;

%mend l2_effect_estimate_driver;
