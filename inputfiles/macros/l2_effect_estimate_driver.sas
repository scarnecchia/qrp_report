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
    * Loop through each AnalysisGrp                               
    ***********************************************************************************************;

    %do loopcont = 1 %to &numl2comparisons.; 
     
        /*Initialize macro variables for the analysisgrp loop*/
        %let pscsfile = ;
        %let outputconditional = N;
        %let outputunconditional = N;
        %let classvars = ;
        %let noclassvars = ;
        %let stratavar = ; /*variable that indicates conditional groupings (matchID or percentile*/
        %let covarnumlist =;
        %let numsubgroup = 0; /*number of subgroups*/
        %let convrule = 0,1,2;


        %let numsubcat=0;  /*store number of subgroups to loop through. 0 = overall analysis*/  
/*        %let categorization=; *the list of categorization;*/
/*        %let var=;*/
/*        %let cat=0;*/


        /*set parameters from l2comparisonfile for this loop*/
        data _null_;
            set l2comparisonfile;
            call symputx('runid', runid);
            call symputx('analysisgrp', analysisgrp);
            call symputx('outputconditional', outputconditional);
            call symputx('outputunconditional', outputunconditional);
            call symputx('classvars', classvars);
            call symputx('noclassvars', noclassvars);
            call symputx('convrule', convrule);
        run;
        %put now computing effect estimates for &analysisgrp.;
       
        /*extract QRP input file associated with analysisgrp*/
        proc sql noprint;
            select strip(file) into: pscsfile trimmed
            from pscs_masterinputs
            where analysisgrp = "&analysisgrp.";
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
            %let grp1 = ;
            %let grp2 = ;
            %let unconditional_distributed = N;
            %let ratio = ;
            %let ceiling = ;
            %let analysisgrpweight = ;
            %let suppresscolumns = N;
            %let psestimategrp = ;
            %let stratavar = ;;
            %let analysisgrpweight = ;
            %let individualreturn = N;
            %let marginalweights = N;
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
                    call symputx("unconditional_distributed", lowcase(unconditional));
                    call symputx("stratavar", 'matchid');
                    call symputx('ratio',upcase(ratio)) ;
                    call symputx('ceiling',put(ceiling, best.)) ;
                    if upcase(ratio) = "V" then call symputx("suppresscolumns", "Y");
                %end;

                %if &pscsfile. = stratificationfile %then %do;
                    call symputx("psestimategrp", lowcase(psestimategrp));
                    call symputx("stratavar", 'percentile');
                    call symputx("analysisgrpweight",strip(upcase(strataweight)));
                    /*set individualreturn to N*/
                    if missing(strataweight)=0 then do;
                        call symputx('individualreturn', 'N');
                        call symputx('marginalweights', 'Y');
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
                    call symputx('GRP2', ref) ;     
                    call symputx("stratavar", 'covarstrat');
                %end;
            run;

            %if &pscsfile. = psmatchfile | &pscsfile. = stratificationfile | &pscsfile. = iptwfile %then %do;
                data _null_; 
                    set infolder.&&&runid._psestimationfile(where=(lowcase(psestimategrp)="&psestimategrp."));
                    call symputx('GRP1', eoi) ;
                    call symputx('GRP2', ref) ;     
                run;
            %end;

            /*Extract selectprobabilities parameters*/
            %if %str("&reporttype") = %str("T4L2") %then %do;
                %isdata(dataset=SelectionProbabilitiesFile);
                %if %eval(&nobs.>0) %then %do;
                data _null_;
                    set SelectionProbabilitiesFile(where=(analysisgrp="&analysisgrp." and covarnum = &covarnum.));
                    call symputx('s11', s11);
                    call symputx('s01', s01);
                    call symputx('s10', s10);
                    call symputx('s00', s00);
                run;
                %end;
            %end; 

            %put EOI: &grp1;
            %put REF: &grp2;

            /******************/
            /* Aggregate data */
            /******************/
            %if &individualreturn. = Y %then %do;
                /*[runid]_adjusted_&periodid.*/
                %aggregate_l2_datasets(infile=&runid._adjusted_&periodid.,
                                       outfile=aggpl,
                                       pscsfile=&pscsfile.,
                                       convrule=%str(&convrule.),
                                       convdata=&runid._estimates_&periodid.,
                                       settomissvars=%str(matchID,pscore,percentile));

                /*if individual-level data does not exist set individualreturn = N*/
                %if %sysfunc(exist(aggpl))=0 %then %do; 
                    %let individualreturn=N;
                %end;

                /*ReportType = T4L2 used [runid]_riskdiff_&periodid. when indlevel = Y*/
                %if %str("&reporttype") = "T4L2" %then %do;
                %aggregate_l2_datasets(infile=&runid._riskdiff_&periodid.,
                                       outfile=aggrd,
                                       pscsfile=&pscsfile.,
                                       convrule=%str(&convrule.),
                                       convdata=&runid._estimates_&periodid.,
                                       settomissvars=%str(Exp,UnExp,EVExp,EVUnExp,FUTimeExp,FUTimeUnExp,weight,weighted_diff));
                %end;

               
            %end;
            %if &individualreturn. = N %then %do;

/**/
/*                %aggdata(file=risksetdata, prefix=aggRS);*/
/*                  %aggdata(file=riskdiffdata,prefix=aggRD);*/
/*                %if &marginalweights =Y %then %do;*/
/*                  %aggdata(file=marginalweights, prefix=agg&psanalysis.);*/
/*                %end;*/
/**/

               

            %end;

            
				    * adjust for convergence;
/*                    %if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;*/
/*						%if "&file."="risksetdata" %then %do;*/
/*				          if %eval(&converge. eq 0) then call missing(risksetpop,Followuptime,RiskSetID,ExposureProbability);*/
/*						%end;*/
/*						%if "&file."="riskdiffdata" %then %do;*/
/*				          if %eval(&converge. eq 0) then call missing(Exp,UnExp,EVExp,EVUnExp,FUTimeExp,FUTimeUnExp,weight,weighted_diff);*/
/*						%end;*/
/*						%if "&file."="survivaldata" %then %do;*/
/*				          if %eval(&converge. eq 0) then call missing(FollowUpDay,EVExp,EVUnExp,NExp,NUnExp);*/
/*						%end;*/
/*						%if "&file."="marginalweights" %then %do;*/
/*				          if %eval(&converge. eq 0) then call missing(Followuptime,RiskSetID,SumEC,SumC,SumE,SumUnE,SumSquareEC,SumSquareUnEC,SumSquareE,SumSquareUnE);*/
/*						%end;*/
/*					%end;*/

            				

            




    
         
            /*****************************************************************/
            /* Execute macros to calculate effect estimates and risk metrics */
            /*****************************************************************/

            ods select none;

            /*  %RunLogit = HR Logit model (risk set)
                %RunRd = Incidence rates, risk differences (risk set)
                %RunCox = Cox model (patient level) - &strata = variables cox model is stratified by
                %RunRd_Pl = Incidence rates, risk differences (patient level) 
                %RunrobustHR - */




            proc datasets library=work nowarn noprint;
                delete aggRS_dp aggRD_dp aggPL_dp;
            quit;

        %end; /*end loop through each covarnum*/




       
    %end; /*loop through each analysisgrp*/


       
        

       


        /* Create naming convention when iptw or strata weight analyses are being run */
/*        %global psanalysis;*/
/*        %let psanalysis = ;*/
/*        %if %length(&analysisweight) > 0 %then %do;*/
/*        %if &pscsfile. = iptwfile %then %let psanalysis = IPTW;*/
/*        %else %if &pscsfile = stratificationfile %then %let psanalysis = STRATAWEIGHT;*/
/*        %end;*/

  

/*        */
/**/
/*    proc datasets nowarn noprint lib=work;*/
/*        delete ;*/
/*    quit;*/

    %nextloop:

    %end; /*L2ComparisonFile input file exists*/

    %put =====> END MACRO: l2_effect_estimate_driver ;

%mend l2_effect_estimate_driver;
