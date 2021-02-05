****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_runrd_rs.sas  
* Created (mm/dd/yyyy): 07/01/2015
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*   This program calculates risk differences using aggregated data.
* 
*  Program inputs:                                                                                   
*   - where = logic condition limiting the records to only those required to calculate RD
*	- Analysis  = Unadjusted, Conditional, Unconditional
*	- subgroupcat = subgroup category
*   - donotreport = blanks out columns that are not reported correctly
*
*  Program outputs:                                                                                                                                       
*   - est: the dataset containing the risk differences and confidence intervals
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_runrd_rs(where=, analysis=, subgroupcat=, donotreport=);

    %put =====> MACRO CALLED: l2_effect_estimate_runrd_rs;

    * Aggregate data across DP;
    proc means data=cat_dp_rd nway noprint;
        var Exp UnExp EVExp EVUnexp FUTimeExp FUTimeUnexp weight weighted_diff;
        where &where.;
        ID covarnum;
        output out=forRD    sum(Exp)=N1
                            sum(UnExp)=N0
                            sum(EVExp)=Ev1
                            sum(EVUnexp)=Ev0
                            sum(FUTimeExp)=FuTime1
                            sum(FUTimeUnexp)=FuTime0
                            sum(weight)=weight
                            sum(weighted_diff)=weighted_diff;
    run;

    *In case data is missing to eliminate e.r.r.o.r message;
    data forrd_exp;
        set forRD;
        where N1 ne .;
    run;
    %isdata(dataset=forrd_exp); 
    %if %eval(&nobs.=0) %THEN %DO;
        data forRD;
            set cat_dp_rd(obs=1 keep=covarnum) 
                forRD;
            N1=0;N0=0;Ev1=0;Ev0=0;FuTime0=0;FuTime0=0;
        run;

        *weighted RD calculations for empty case;
        %let stratifiedratediff =.;
        %let lower =.;
        %let upper =.;
    %end;

    * Obtain stratified incidence rate difference estimate with confidence intervals;
    * include counts of patients, cases and follow up time in output dataset;
    proc sql noprint;
        select sum(N1) into: N_1
        from forRD;
        select sum(N0) into: N_0
        from forRD;
        select sum(weight) into :denom
        from forRD;
        select sum(weighted_diff) into :num
        from forRD;
    quit;

    %if %eval(&nobs.>0) %THEN %DO;
       %if %eval(&denom. <= 0) %then %do;
            %let stratifiedratediff =.;
            %let lower =.;
            %let upper =.;
            %end;
            %else %do;

            *weigthed RD calculations;
            %let stratifiedratediff = %SYSEVALF(&num./&denom.);
            %put &stratifiedratediff;
            %let vari = %SYSEVALF(1/&denom.);
            %let lower = %SYSEVALF(&stratifiedratediff. - 1.96*(&vari.**.5));
            %let upper = %SYSEVALF(&stratifiedratediff. + 1.96*(&vari.**.5));
            %put &lower &upper;
        %end;

        %put N_1 = &N_1.;
        %put analysisgrp = &analysisgrp.;
        %put cat = &cat.;
        %put covarnum = &covarnum.;

        /*calculate metrics for exposure group and comparator group*/
        data est_wide;
            length medicalproduct0 medicalproduct1 $40 subgroupcat $10. analysisgrp $40. analysis $13.;
            retain analysisgrp COVARNUM catnum MonitoringPeriod analysis subgroupcat medicalproduct:
                n0 n1 FUTime_Y: AvgFUTime_D: AvgFUTime_Y: EV0 EV1 IR_1000PY: risk_1000NU: IRDiff_1000PY RD_1000NU;
            set forRD (drop = _type_ _freq_);

            format analysisgrp $40. COVARNUM catnum best. MonitoringPeriod 2.;
    
            analysisgrp = "&analysisgrp.";
            COVARNUM  = &covarnum.;
            catnum = &cat.;
            MonitoringPeriod = put(&periodid., 2.);
            analysis= &analysis.;
            subgroupcat = &subgroupcat.;

            %do exp=1 %to 0 %by -1;

                /***Columns included in report***/
                
                /*Number of New Users - n0/n1*/
                /*Person Years at Risk - FUTime_Y0/FUTime_Y1 */
                /*Average Person Days at Risk - AvgFUTime_D0/AvgFUTime_D1 */
                /*Average Person Years at Risk - AvgFUTime_Y0/AvgFUTime_Y1 */
                /*Number of Events - ev0/ev1*/
                /*Incidence Rate per 1000 Person Years - IR_1000PY0/IR_1000PY1*/
                /*Risk per 1000 New Users - risk_1000NU0/risk_1000NU1*/

                MedicalProduct&exp. = "&&grp&exp.";
                FUTime_Y&exp. = round(FUTime&exp./365.25,0.01);
        
                if n&exp. > 0 then do;
                    AvgFUTime_D&exp.=round(FUTime&exp./n&exp.,0.01);
                    AvgFUTime_Y&exp.=round((FUTime&exp./365.25) / n&exp.,0.01);
                    risk_1000NU&exp. = 1000*(EV&exp. / n&exp.);

                    /***Intermediate columns for NNT AR PAR***/
                    risk_1NU&exp. = EV&exp./n&exp.;
                end;
                else do;
                    AvgFUTime_D&exp. = 0;
                    AvgFUTime_Y&exp.= 0;
                    risk_1000NU&exp. = 0;
                    risk_1NU&exp. = 0;
                end;
                if FUTime_Y&exp. > = 0 then do;
                    IR_1000PY&exp. = 1000*(EV&exp. / FUTime_Y&exp.);
                end;
                else do;
                    IR_1000PY&exp. = 0;
                end;

            %end;

            /*Incidence Rate Difference per 1000 Person Years*/
            IRDiff_1000PY =  IR_1000PY1  - IR_1000PY0;

            /*Difference in Risk per 1000 New Users*/
            RD_1000NU =  risk_1000NU1 -  risk_1000NU0;

            /***Columns not included in report***/
            if (risk_1NU1 - risk_1NU0) > 0 then NNT = 1/(risk_1NU1 - risk_1NU0);
                else NNT = .;

            if risk_1NU1 > 0 then AR = (risk_1NU1 - risk_1NU0) / risk_1NU1;
                else AR = .;

            if (n0+n1) > 0 then poprisk = (EV0+EV1)/(n0+n1);
                else poprisk = .;
            
            if poprisk > 0 then PAR = (poprisk-risk_1NU0)/poprisk;
                else PAR = .;

            label poprisk = "Pop. Risk among new users of exposure AND control";
            label NNT = "Number needed to treat (or harm)";
            label AR = "Attributable Risk %";
            label PAR = "Population Attributable Risk %";

            *total number of events;
            totalevents = sum(ev0, ev1);

            /*Stratified incident rate diff*/
            length RD_95CI $50.;
            stratifiedrd = put(&stratifiedratediff., 8.5); 
            lower = put(&Lower, 8.5);
            upper =put(&Upper, 8.5);
            RD_95CI = (stratifiedrd||" ("||lower||", "||upper||")");
            label rd_95CI = "Incidence Rate Difference per (Nominal 95% Confidence Interval)";

            format n0 n1 ev0 ev1 comma10. FUTime_Y: AvgFUTime_D: AvgFUTime_Y: comma12.2 IR_1000PY: risk_1000NU: IRDiff_1000PY: RD_1000NU: nnt  comma8.2
            ar par percentn12.2 poprisk best8.4;

            keep analysisgrp COVARNUM catnum MonitoringPeriod analysis subgroupcat medicalproduct:
                n0 n1 FUTime_Y: AvgFUTime_D: AvgFUTime_Y: EV0 EV1 IR_1000PY: risk_1000NU: IRDiff_1000PY RD_1000NU poprisk nnt ar par RD_95CI totalevents;
        run;

        /*transform dataset to 1 line per exposure*/
        data est;
            set 
            %do exp = 1 %to 0 %by -1;
            est_wide(keep= analysisgrp COVARNUM catnum MonitoringPeriod analysis subgroupcat totalevents
                    n&exp medicalproduct&exp FUTime_Y&exp AvgFUTime_D&exp AvgFUTime_Y&exp EV&exp IR_1000PY&exp risk_1000NU&exp 
                    IRDiff_1000PY RD_1000NU poprisk nnt ar par
                rename=(n&exp = n)
                rename=(medicalproduct&exp = medicalproduct)
                rename=(FUTime_Y&exp = FUTime_Y)
                rename=(AvgFUTime_D&exp = AvgFUTime_D)
                rename=(AvgFUTime_Y&exp = AvgFUTime_Y)
                rename=(EV&exp = EV)
                rename=(IR_1000PY&exp = IR_1000PY)
                rename=(risk_1000NU&exp = risk_1000NU))
            %end;
            ;

            *Convert to character variables and redact (will keep unredacted as numeric locally);
            EVchar = strip(put(EV, comma10.));
            IR_1000PYchar = strip(put(IR_1000PY, comma8.2));
            IRDiff_1000PYchar = strip(put(IRDiff_1000PY, comma8.2));
            RD_1000NUchar = strip(put(RD_1000NU, comma8.2));
            risk_1000NUchar = strip(put(risk_1000NU, comma8.2));

            FUTime_Ychar = strip(put(FUTime_Y, comma12.2));
            AvgFUTime_Dchar = strip(put(AvgFUTime_D, comma12.2));
            AvgFUTime_Ychar = strip(put(AvgFUTime_Y, comma12.2));

            %if %eval(&REDACTEVENTS.>0) | %str("&donotreport.") = %str("Y") %then %do;
                EVchar = '';
                IR_1000PYchar = '';
                IRDiff_1000PYchar = '';
                RD_1000NUchar = '';
                risk_1000NUchar = '';
            %end;
            %if %eval(&REDACTPT.>0) | %str("&donotreport.") = %str("Y") %then %do;
                FUTime_Ychar = '';
                AvgFUTime_Dchar = '';
                AvgFUTime_Ychar = '';
            %end;

            /*Assign sort vars - will eventually sort dataset */
            /*by analysis*/
            length sort1 sort2 analysisgrpsort 3;
            if analysis = 'Unadjusted' then sort1 = 1;
            else if analysis = 'Conditional' | analysis = 'Unweighted' then sort1 = 2;
            else sort1 = 3;

            /*by exposure*/
            if _n_ = 1 then sort2 =1;
            else sort2 = 2;

            /*by analysisgrp*/
            analysisgrpsort = &loopcont.;
        run;
    %end;
    %else %do;  *create empty dataset;
        data est;
                length medicalproduct $40 subgroupcat $10. analysisgrp $40. analysis $13.;
                format MonitoringPeriod 2. analysisgrp $40.;
            %do exp = 1 %to 0 %by -1;

                analysisgrp = "&analysisgrp.";
                COVARNUM  = &covarnum.;
                catnum = &cat.;
                MonitoringPeriod = put(&periodid., 2.);
                Analysis= &Analysis.;
                subgroupcat = &subgroupcat.;
                MedicalProduct = "&&group&exp.";

                n = .;
                FUTime_Y = .;
                AvgFUTime_D = .;
                AvgFUTime_Y = .;
                EV = .;
                IR_1000PY = .;
                risk_1000NU = .;
                IRDiff_1000PY = .;
                RD_1000NU = .;
                poprisk = .;
                nnt = .;
                ar = .;
                par =.;

                RD_95CI = "";

                label poprisk = "Pop. Risk among new users of exposure AND control";
                label NNT = "Number needed to treat (or harm)";
                label AR = "Attributable Risk %";
                label PAR = "Population Attributable Risk %";
                label rd_95CI = "Incidence Rate Difference per (Nominal 95% Confidence Interval)";

                format n ev comma10. FUTime_Y AvgFUTime_D AvgFUTime_Y  comma12.2 IR_1000PY risk_1000NU IRDiff_1000PY RD_1000NU nnt  comma8.2
                ar par percentn12.2 poprisk best8.4;

                *Convert to character variables and redact (will keep unredacted as numeric locally);
                EVchar = put(EV, comma10.);
                IR_1000PYchar = put(IR_1000PY, comma8.2);
                IRDiff_1000PYchar = put(IRDiff_1000PY, comma8.2);
                RD_1000NUchar = put(RD_1000NU, comma8.2);
                risk_1000NUchar = put(risk_1000NU, comma8.2);
                FUTime_Ychar = put(FUTime_Y, comma12.2);
                AvgFUTime_Dchar = put(AvgFUTime_D, comma12.2);
                AvgFUTime_Ychar = put(AvgFUTime_Y, comma12.2);
                %if %eval(&REDACTEVENTS.>0) | %str("&donotreport.") = %str("Y") %then %do;
                    EVchar = '';
                    IR_1000PYchar = '';
                    IRDiff_1000PYchar = '';
                    RD_1000NUchar = '';
                    risk_1000NUchar = '';
                %end;
                    %if %eval(&REDACTPT.>0) | %str("&donotreport.") = %str("Y") %then %do;
                    FUTime_Ychar = '';
                    AvgFUTime_Dchar = '';
                    AvgFUTime_Ychar = '';
                %end;
                    
                /*Assign sort vars - will eventually sort dataset */
                /*by analysis*/
                length sort1 sort2 analysisgrpsort 3;
                if analysis = 'Unadjusted' then sort1 = 1;
                else if analysis = 'Conditional' | analysis = 'Unweighted' then sort1 = 2;
                else sort1 = 3;

                /*by exposure*/
                if &exp. = 1 then sort2 =1;
                else sort2 = 2;

                /*by analysisgrp*/
                analysisgrpsort = &loopcont.;

                keep analysisgrp COVARNUM catnum MonitoringPeriod analysis subgroupcat medicalproduct analysisgrpsort sort1 sort2
                n FUTime_Y AvgFUTime_D AvgFUTime_Y EV IR_1000PY risk_1000NU IRDiff_1000PY RD_1000NU poprisk nnt ar par RD_95CI 
                EVchar IR_1000PYchar IRDiff_1000PYchar RD_1000NUchar risk_1000NUchar FUTime_Ychar AvgFUTime_Dchar AvgFUTime_Ychar;

            output;
            %end;
        run;
    %end;

    proc datasets library=work nowarn noprint;
        append base= RDEst data=est force;
        delete est: forRD forrd_exp;
    quit;

    %put NOTE: ******** END OF MACRO: l2_effect_estimate_runrd_rs ********;

%mend l2_effect_estimate_runrd_rs;
