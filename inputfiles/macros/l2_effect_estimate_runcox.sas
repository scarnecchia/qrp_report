****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_runcox.sas  
* Created (mm/dd/yyyy): 07/30/2015
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*   Obtain stratified cox PH estimates with confidence intervals with individual level data 
* 
*  Program inputs:                                                                                   
*   - where = logic condition limiting the records to only those required to run the regression
*   - strata = Stratification variable
*	- Analysis  = Unadjusted, Conditional, Unconditional
*	- subgroupcat = subgroup category
* 
*  Program outputs:                                                                                                                                       
*   - CoxPHest: the dataset containing the hazard ratios and standard errors 
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_runcox(where=,strata=, analysis=, subgroupcat=);

    %put =====> MACRO CALLED: l2_effect_estimate_runcox ;

    data forest;
    set cat_dp_pl;
    where &where. and missing(studyclass)=0;
    run;

    %isdata(dataset=forest);
    %if %eval(&NOBS.>=2) & %eval(&redactevents.=0) %then %do;

        * Obtain stratified cox PH estimates with confidence intervals;
        proc phreg data = forest;
            strata &strata.;
            class &classvars.;
            model followuptime*event(0) = EXPOSURE &noclassvars. &classvars. / ties = breslow rl;
            ods output ParameterEstimates=pest;
        run;

        DATA coxPHest; 
            RETAIN analysisgrp COVARNUM catnum MonitoringPeriod HR_95CI HR_pvalue;
            SET pest (RENAME = (hazardratio = HR)
                      RENAME = (estimate = HR_coef)
                      RENAME = (stderr = HR_se)
                      RENAME = (HRLOWERCL=LCL) 
                      RENAME = (HRUPPERCL=UCL));
            where lowcase(parameter) = "exposure";
            FORMAT analysisgrp $40. COVARNUM catnum best. HR LCL UCL 5.2 MonitoringPeriod 2.0;
            length analysisgrp $40 HR_95CI $30 analysis $13. subgroupcat $10 HR_pvalue $6;

            analysisgrp = "&analysisgrp.";
            COVARNUM  = &covarnum.;
            catnum = &cat.;
            MonitoringPeriod = put(&periodid., 2.);
            Analysis= &analysis.;
            subgroupcat = &subgroupcat.;

            HR_95CI = strip(put(HR, 5.2))|| " ("||strip(put(LCL, 5.2))||", "|| strip(put(UCL, 5.2))||")";

            if probchisq < 0.001 then do;
                HR_pvalue = '<0.001';
            end;
            else do;
                HR_pvalue = put(probchisq, 6.3);
            end;

            /*blank out HR and pvalue that cannot be calculated*/
            if index(HR_95CI, 'E') > 0 or index(HR_95CI, '0.00') or index(HR_95CI, '-') or index(HR_95CI,' . ') then do;
                HR_95CI = '-';
                HR_pvalue = '-';
            end;

            label hr_95CI = "Hazard Ratio (95% CI)";
            label HR_pvalue = "Wald P-Value";
            label HR_se = "StdErr of Coefficient";
            label HR_coef = "Coefficient from model";
            label HR = "Hazard Ratio";
            label LCL = "95% LCL";
            label UCL = "95% UCL";

            KEEP analysisgrp COVARNUM catnum analysis subgroupcat MonitoringPeriod HR_95CI HR_pvalue HR LCL UCL HR_coef HR_se ;
        RUN;
    %end;
    %else %do;  *create empty dataset;
        data coxPHest;
            FORMAT analysisgrp $40. COVARNUM catnum best. HR LCL UCL HR_coef 5.2 HR_se 8.4; 
            length subgroupcat $10. analysis $13. analysisgrp $40;

            analysisgrp = "&analysisgrp.";
            COVARNUM  = &covarnum.;
            catnum = &cat.;
            Analysis= &analysis.;
            subgroupcat = &subgroupcat.;

            format MonitoringPeriod 2.;
            length HR_95CI $30. HR_pvalue $6.;
            MonitoringPeriod = put(&periodid., 2.);

            HR_95CI = "-";
            HR_se = .;
            HR_coef = .;
            HR_pvalue = "-";
            HR = .;
            LCL = .;
            UCL = .;

            %if %eval(&redactevents.>0) %then %do;
                HR_pvalue = '';
                HR_95CI='';
            %end;
        run; 

    %end;*End create empty dataset;

    proc datasets library=work nowarn noprint;
        append base= logitEst data=Coxphest force;
        delete pest forest Coxphest;
    quit;

    %put NOTE: ******** END OF MACRO: l2_effect_estimate_runcox ********;

%mend l2_effect_estimate_runcox;
