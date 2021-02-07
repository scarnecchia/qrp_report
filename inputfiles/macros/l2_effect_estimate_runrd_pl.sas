****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_runrd_pl.sas  
* Created (mm/dd/yyyy): 07/30/2015
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*	This program calculates risk differences using individual level data.
* 
*  Program inputs:                                                                                   
*	- where = logic condition limiting the records to only those required to run the regression
*  	- strata = Stratification variable
*	- Analysis  = Unadjusted, Conditional, Unconditional
*	- subgroupcat = subgroup category
*	- donotreport = blanks out columns that are not reported correctly (VRM, percentile)
* 
*  Program outputs:                                                                                                                                       
*	- rd_est_pl: the dataset containing the risk differences and confidence intervals
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_runrd_pl(where=,strata=, analysis=, subgroupcat=, donotreport=);

    %put =====> MACRO CALLED: l2_effect_estimate_runrd_pl;

	*Restrict to informative events/person-time for conditional analysis;
    %if &analysis = "Conditional" %then %do;
		data _completedata;
			set cat_dp_pl;
            where &where.;
	
		 	Exp=0;UnExp=0;EVExp=0;EVUnExp=0;FUTimeExp=0;FUTimeUnExp=0;
			if exposure=1 then do;
				Exp=1;
				FUTimeExp=Followuptime;
				if Event then EVExp=1;
			end;
			if exposure=0 then do;
				UnExp=1;
				FUTimeUnExp=Followuptime;
				if Event then EVUnExp=1;
		   	end;
		run;

        %isdata(dataset=_completedata);
        %if %eval(&nobs.<1) %then %do;
            %goto writeemptydataset;
        %end;

	    *find maximum followuptime in each arm for each &stratavar.;
	    proc means data=_completedata nway noprint;
	    var FUTimeExp FUTimeUnExp;
	    class dpidsiteid &stratavar. ;
	    output out=MAX_FU_TIME(drop=_:) max=maxFUTimeExp maxFUTimeUnExp;
	    run;

	    data MAX_FU_TIME;
	    set MAX_FU_TIME;
	    stopFU=min(maxFUTimeExp,maxFUTimeUnExp);
	    keep dpidsiteid &stratavar. stopFU;
	    run;

	    proc sql noprint undo_policy=none;
	    create table RS_file0 as
	    select dat.*,
	           fu.stopFU
	    from cat_dp_pl as dat left join
	         MAX_FU_TIME as fu
	    on dat.&stratavar. = fu.&stratavar. and dat.dpidsiteid = fu.dpidsiteid;
	    quit; 

	    data infdata;
	    set RS_file0;

	    if Followuptime > stopfu then do;
	      Followuptime= stopfu;
		  event = 0;
	    end;
	    run;
	%end;
	%else %do;
		data infdata;
			set cat_dp_pl;
		run;
	%end;

	*Identify events and person time by exposure and data partner;
	%do e = 0 %to 1; 
		proc sql noprint;
			create table n_case_&e as
			select &strata, sum(event) as n_case_&e, count(*) as n_&e
			from infdata
			where exposure = &e. and &where.
			group by &strata.
			order by &strata.;
					
			create table fu_&e as
			select &strata, sum(followuptime) as fu_&e
			from infdata
			where exposure = &e. and &where.
			group by &strata.
			order by &strata.;
		quit;
	%end; 

	* 1. Calculate weight within strata ;
	* 2. Calculate difference within strata ;
	* 3. Calculated weighted difference;

	data stratatotals;
		merge n_case_1 n_case_0 fu_1 fu_0;
		by %sysfunc(compress(&strata., ","));
		N1sq = fu_1**2;
		N0sq = fu_0**2;
		numerator = (N1sq*N0sq);
		denominator =  (n_case_1*N0Sq + n_case_0*N1sq) ;
		weight = 0;
		if denominator > 0 then do;
            weight = numerator/denominator ; *1.;
		    diff = (n_case_1/fu_1) - (n_case_0/fu_0); *2.;
		    weighted_diff = weight*diff; *3.;
		end;
	run; 

	* get number of patients, cases, and follow up time by exposure;
	proc sql;
		select sum(n_1) into: N_1
		from stratatotals;
		select sum(n_0) into: N_0
		from stratatotals;
	quit;

	proc means data = stratatotals noprint;
		var n_case_1 fu_1 n_case_0 fu_0 N_1 N_0;
		output out = sum sum = EV1 FuTime1 EV0 FuTime0 n1 n0;
	run;

	* Obtain stratified incidence rate difference estimate with confidence intervals;
		* include counts of patients, cases and follow up time in output dataset;
	proc sql noprint;
		select sum(weight) into :denom
		from stratatotals;
		select sum(weighted_diff) into :num
		from stratatotals;
	quit;

    %if &denom. = 0 %then %do;
		%let stratifiedratediff = .;
		%let lower = .;
		%let upper = .;
    %end;
    %else %do;
		%let stratifiedratediff = %SYSEVALF(&num./&denom.);
		%put &stratifiedratediff;
		%let vari = %SYSEVALF(1/&denom.);
		%let lower = %SYSEVALF(&stratifiedratediff. - 1.96*(&vari.**.5));
		%let upper = %SYSEVALF(&stratifiedratediff. + 1.96*(&vari.**.5));
		%put &lower &upper;
    %end;

    %isdata(dataset=sum); 
	%if %eval(&NOBS.>0) %then %do;
		data est_wide;
			length medicalproduct0 medicalproduct1 analysisgrp $40 subgroupcat $10. analysis $13.;
			retain analysisgrp COVARNUM catnum MonitoringPeriod analysis subgroupcat medicalproduct:
		           n0 n1 FUTime_Y: AvgFUTime_D: AvgFUTime_Y: EV0 EV1 IR_1000PY: risk_1000NU: IRDiff_1000PY RD_1000NU;
			set sum (drop = _type_ _freq_);

	 		FORMAT COVARNUM catnum best. MonitoringPeriod 2. analysisgrp $40.;
		
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

			*total number of events;
			totalevents = sum(ev0, ev1);

			label poprisk = "Pop. Risk among new users of exposure AND control";
		  	label NNT = "Number needed to treat (or harm)";
		  	label AR = "Attributable Risk %";
		  	label PAR = "Population Attributable Risk %";

			/*Stratified incident rate diff*/
			length RD_95CI $50.;
			stratifiedrd = put(&stratifiedratediff., 8.5); 
			lower = put(&Lower, 8.5);
			upper =put(&Upper, 8.5);
			RD_95CI = (stratifiedrd||" ("||lower||", "||upper||")");
			label rd_95CI = "Incidence Rate Difference per (Nominal 95% Confidence Interval)";

		 	format n0 n1 ev0 ev1 totalevents comma10. FUTime_Y: AvgFUTime_D: AvgFUTime_Y:  comma12.2 IR_1000PY: risk_1000NU: IRDiff_1000PY: RD_1000NU: nnt comma8.2
			ar par percentn12.2 poprisk best8.4;

		  	keep analysisgrp covarnum catnum MonitoringPeriod analysis subgroupcat medicalproduct:
				n0 n1 FUTime_Y: AvgFUTime_D: AvgFUTime_Y: EV0 EV1 IR_1000PY: risk_1000NU: IRDiff_1000PY RD_1000NU poprisk nnt ar par RD_95CI totalevents ;
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
                analysisgrpsort = &loopcount.;
		run;
	%end;
	%else %do; /*create empty dataset*/
        %writeemptydataset:

		data est;
            length medicalproduct analysisgrp $40 subgroupcat $10. analysis $13.;
			format MonitoringPeriod 2. analysisgrp $40.;
		    %do exp = 1 %to 0 %by -1;

    	    	analysisgrp = "&analysisgrp.";
    		    COVARNUM  = &covarnum.;
    		    catnum = &cat.;
    		  	MonitoringPeriod = put(&periodid., 2.);
    			analysis= &analysis.;
    			subgroupcat = &subgroupcat.;

    			MedicalProduct = "&&grp&exp.";

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
    			totalevents = .;

      			RD_95CI = "";

    			label poprisk = "Pop. Risk among new users of exposure AND control";
    			label NNT = "Number needed to treat (or harm)";
    			label AR = "Attributable Risk %";
    			label PAR = "Population Attributable Risk %";
    			label rd_95CI = "Incidence Rate Difference per (Nominal 95% Confidence Interval)";

    			format n ev totalevents comma10. FUTime_Y AvgFUTime_D AvgFUTime_Y  comma12.2 IR_1000PY risk_1000NU IRDiff_1000PY RD_1000NU nnt  comma8.2
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
                analysisgrpsort = &loopcount.;

    			keep analysisgrp COVARNUM catnum MonitoringPeriod analysis subgroupcat medicalproduct sort1 sort2 analysisgrpsort
    			n FUTime_Y AvgFUTime_D AvgFUTime_Y EV IR_1000PY risk_1000NU IRDiff_1000PY RD_1000NU poprisk nnt ar par RD_95CI totalevents
    			EVchar IR_1000PYchar IRDiff_1000PYchar RD_1000NUchar risk_1000NUchar FUTime_Ychar AvgFUTime_Dchar AvgFUTime_Ychar;

        		output;
    		%end;
		run;
	%end;

    proc datasets library=work nowarn noprint;
    	append base= RDEst data=est force;
    	delete stratatotals sum est: fu_: n_case: infdata _completedata MAX_FU_TIME RS_File0;
    quit;

    %put NOTE: ******** END OF MACRO: l2_effect_estimate_runrd_pl ********;

%mend l2_effect_estimate_runrd_pl;
