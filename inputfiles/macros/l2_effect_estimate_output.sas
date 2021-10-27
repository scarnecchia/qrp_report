****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_effect_estimate_output.sas  
* Created (mm/dd/yyyy): 03/26/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro drives the creation of Effect Estimate Tables proc report output
*                                        
*  Program inputs:                                                                                   
*   - l2_effectestimates_&periodid.
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:                                                                       
*            
*  Programming Notes:         
*   Utility macro %assign_superscripts used to dynamically assign footnote superscripts
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro l2_effect_estimate_output();

    %put =====> MACRO CALLED: l2_effect_estimate_output;

    %if &numl2comparisons > 0 %then %do; 

        %if &look_start ^= &look_end %then %do;
        data l2_effectestimates_&look_end.;
            set l2_effectestimates_:;
        run;
        %end;

        /* Loop through all order values */
        %do corder = 1 %to &numl2comparisons;

        %let tablecount = 1;

		data _null_;
            set l2comparisonfile(where=(order=&corder.));
            call symputx('runid', runid);
            call symputx('analysisgrp', analysisgrp);
            call symputx('conditional', upcase(outputconditional));
        run;

    	/* Subset dataset on analysisgrp with all covarnums */
    	data table&tablenum;
    		set l2_effectestimates_&look_end.(where=(analysisgrp="&analysisgrp."));
    	run;

    	%let medicalproduct = medicalproduct;

    	/* Merge in group labels if they exist */
      	%isdata(dataset=labelfile);

	    %if %eval(&nobs>0) %then %do;

        /* stack all potential group values with label value */
        data labelfile_est;
            set labelfile
                table&tablenum(keep=medicalproduct rename=medicalproduct=group in=a)
                table&tablenum(keep=analysisgrp rename=analysisgrp=group in=b);
            if missing(label) then do;
            labeltype='grouplabel';
            runid="&runid";
            end;
        run;

        /* Remove duplicate group values */
        proc sort data = labelfile_est nodupkey;
            by group;
        run;

	   	%let medicalproduct = medicalproduct_labeled;
	    proc sql noprint undo_policy=none;
	        create table table&tablenum as
	        select c.*, case when not missing(c.label) then label else medicalproduct end as medicalproduct_labeled
	        from (select distinct a.*, b.label 
	          			from table&tablenum a 
	          			left join labelfile_est b
	          			on coalescec(a.medicalproduct, a.analysisgrp) = b.group
                        where b.runid = "&runid.") c
            order by c.analysisgrpsort, c.covarnum, c.catnum, c.subgroupcat, c.sort1, c.sort2 %if &look_start ^= &look_end %then %do; ,c.monitoringperiod %end;;
	    quit;
	    %end;


        proc sql noprint;
        	/*extract QRP input file associated with analysisgrp*/
            select distinct strip(file) into: pscsfile trimmed
            from pscs_masterinputs
            where analysisgrp = "&analysisgrp." and runid = "&runid";

            /*Get all values of covarnum for a given analysisgrp */
            select distinct covarnum 
            into :covarnumlist separated by ' '
            from table&tablenum;

            /*Determine whether to print Monitoring Period column*/
           	select count(distinct monitoringperiod) into: printMP
	        from table&tablenum;

	        /* Store (un)formatted value of analysisgrp for title */
            %let analysisgrpfmt = &analysisgrp.;
            %if &nobs > 0 %then %do;
	        select label into: analysisgrpfmt trimmed
	        from labelfile
            where group = "&analysisgrp." and runid = "&runid.";
            %end;
        quit;

        %if &covarnumlist = 0 %then %let tablecount = 0;

	    %let MPColumn = ;
	    %let MPDefine = ;

	    %if %eval(&printMP. > 1) %then %do;
	        %let MPColumn = MonitoringPeriod;
	        %let MPDefine = define MonitoringPeriod /
	            order order=data 'Monitoring*Period' style(column)=[just=c vjust=middle] style(header)=[just=C background=white borderbottomcolor=black] format=$timefmt.;
	    %end;

        /* Create output datasets based on covarnum */
        %do covarnumcount = 1 %to %sysfunc(countw(&covarnumlist));
        	%let covarnum = %scan(&covarnumlist,&covarnumcount);

        %let caliper&corder. = ;
        %let ratio&corder. = ;
        %let percentile&corder. = ;
        %let weightscheme=;
        %let weightschemelong = ;
        %let pstrim = ;

        %if &pscsfile. = psmatchfile | &pscsfile. = stratificationfile | &pscsfile. = iptwfile %then %do;
            data _null_; 
            	set infolder.&&&runid._&pscsfile.(where=(lowcase(analysisgrp)="&analysisgrp."));
                call symputx("psestimategrp", lowcase(psestimategrp));
            run; 
            data _null_; 
            	set infolder.&&&runid._psestimationfile(where=(lowcase(psestimategrp)="&psestimategrp."));
                call symputx("eoi", lowcase(eoi));
            run; 
        %end;
        %if &pscsfile. = psmatchfile %then %do;
            data _null_; 
            	set infolder.&&&runid._psmatchfile(where=(lowcase(analysisgrp)="&analysisgrp."));
                call symputx("caliper&corder.",cat('; Caliper= ',strip(put(caliper,8.2))));
                if upcase(ratio) = "F" then do;
                    call symputx("ratio&corder.","Fixed Ratio 1:"||strip(put(ceiling,8.)));
                end;
                else if upcase(ratio) = "V"  then do;
                    call symputx("ratio&corder.","Variable Ratio 1:"||strip(put(ceiling,8.))); 
                    call symputx('conditional', 'Y');
                end;
	       run; 
        %end;
        %if &pscsfile. = stratificationfile %then %do;
            data _null_; 
                set infolder.&&&runid._stratificationfile(where=(lowcase(analysisgrp)="&analysisgrp."));
                if not missing(percentiles) then do;
                call symputx("percentile&corder",cat('; Percentiles= ',strip(put(percentiles,8.))));
                end;
                if not missing(strataweight) then do;
                call symputx("weightscheme",strip(upcase(strataweight)));
                if upcase(strataweight)= 'ATE' then call symputx("weightschemelong","Average Treatment Effect");
                else if upcase(strataweight)= 'ATT' then call symputx("weightschemelong","Average Treatment Effect in the Treated");
                end;
                if missing(strataweight) then call symputx('conditional', 'Y');
                if pstrim > . then call symputx('pstrim', ', Trimmed');
            run;
        %end;
        %if &pscsfile. = iptwfile %then %do;
            data _null_; 
                set infolder.&&&runid._iptwfile(where=(lowcase(analysisgrp)="&analysisgrp."));
                call symputx("weightscheme",upcase(IPWEIGHT));
                if upcase(ipweight)= 'ATE' then call symputx("weightschemelong","Average Treatment Effect");
                else if upcase(ipweight)= 'ATES' then call symputx("weightschemelong","Average Treatment Effect, Stabilized");
                else if upcase(ipweight)= 'ATT' then call symputx("weightschemelong","Average Treatment Effect in the Treated");
                call symputx('pstrim', ', Trimmed');
            run;
        %end;
        %if &pscsfile. = covstratfile %then %do;
      	data _null_; 
                set infolder.&&&runid._covstratfile(where=(lowcase(analysisgrp)="&analysisgrp."));
                   call symputx("eoi", lowcase(eoi));
                   *convert covariate stratifiers vars to printable format;
                    cnt = countw(stratvars);
                    format tmpstratvars stratvars2 $50.;
                    tmpstratvars = stratvars;
                    if cnt =2 then do;
                        tmpstratvars = tranwrd(strip(tmpstratvars),' ', ' and ');
                    end;
                    if cnt >2 then do;
                        stratvars1 = tranwrd(strip(tmpstratvars),' ', ', ');
                        lastcomma = find(stratvars1,',',-length(stratvars1));
                        tmpstratvars = cat(substr(stratvars1, 1, lastcomma),' and', substr(stratvars1, lastcomma+1));
                    end;

                    stratvars2 = tranwrd(propcase(strip(tmpstratvars)), 'Agegroup', 'Age Group');
                    formattedstratvars = tranwrd(stratvars2,'And', 'and'); 
                    call symputx("formattedstratvars", formattedstratvars);
                    call symputx('conditional', 'Y');
      	run;
        %end;

        %tableletter();

        /* Save datasets to reportdata */
        %isdata(dataset=repdata.table&tablenum.&tableletter.);
        %if %eval(&nobs.<1) %then %do;

        data repdata.table&tablenum.&tableletter;
            set table&tablenum.(where=(covarnum=&covarnum));
            %if &pscsfile = iptwfile or (&pscsfile = stratificationfile and %length(&weightscheme) > 0) %then %do;
            if analysis = "Unweighted" then do;
                HR_95CI = 'N/A';
                HR_pvalue = 'N/A';
            end;
            %end;
            /* Convert monitoring period to character so format applies correctly */
            %if &look_start ^= &look_end %then %do;
            MP_char = strip(put(MonitoringPeriod,3.));
            drop MonitoringPeriod;
            rename MP_char=MonitoringPeriod;
            %end;
        run;
        %end;

        /* Select Footnotes */  
         data _footnotes;
           length footnote_order 3; 
           /* Always displayed across all types */
           set lookup.lookup_footnotes_effectest (where=(order in ( 0
              
              %if "&conditional" = "Y" and %length (&&Ratio&corder) > 0 %then %do;
              4
              %end;
			  %if &pscsfile. = iptwfile and %length(&weightscheme) > 0 %then %do;
			  1
			  %end;
              %if %length(&weightscheme) > 0 %then %do;
              5
              %end;
              %if &covarnum = 1012 %then %do;
              2
              %end;
              %if &covarnum = 1014 %then %do;
              3
              %end;
            )));
           by order;
           footnote_order = _n_;
        run;

        proc sql noprint;
          select count(order) into: num_fn trimmed
          from _footnotes;
          
          %if &num_fn > 0 %then %do;
          select description into: fn1 - :fn&num_fn.
          from _footnotes
          order by order;
          %end;
        quit;

        /* Assign macro variables for superscripts */
		%assign_superscripts(type =title, order = 2 3);
		%assign_superscripts(type =weight, order =1);
		%assign_superscripts(type =line, order =4 5);

        /* Determine what text to append to title based on covarnum */
        %if &covarnum = 0 %then %do;
        %let titleend = %str();
        %end;
        %else %if &covarnum = 9000 %then %do; 
        %let titleend = %str(and Data Partner);
        %end;
        %else %do;
        %let subcategorization = ;

        proc sql noprint;
            select distinct title 
            into :subcategorization separated by '@'
            from repdata.table&tablenum.&tableletter
            where covarnum = &covarnum;

            %if &covarnum < 1000 %then %do;
            select distinct strip(studyname) into: subgrouplabel
            from infolder.&&&runid._covariatecodes
            where covarnum = &covarnum.;
            %end;
        quit;

        %if &covarnum = 1000 %then %let subgrouplabel = Sex;
        %else %if &covarnum = 1001 %then %let subgrouplabel = Age Group;
        %else %if &covarnum = 1002 %then %let subgrouplabel = Year;
        %else %if &covarnum = 1003 %then %let subgrouplabel = Monitoring Period;
        %else %if &covarnum = 1012 %then %let subgrouplabel = Race;
        %else %if &covarnum = 1013 %then %let subgrouplabel = Hispanic Origin;
        %else %if &covarnum = 1014 %then %let subgrouplabel = Delivery Status;
        %else %if &covarnum = 2000 %then %let subgrouplabel = Match Method;
        %else %if &covarnum = 2001 %then %let subgrouplabel = Birth Type;

        %let titleend = %str(and &subgrouplabel);
        %end;

        %let s11 = ;
        %if &reporttype = T4L2 %then %do;
        %isdata(dataset=SelectionProbabilitiesFile);
        %if &nobs > 0 %then %do; 
            data _null_;
            set SelectionProbabilitiesFile(where=(analysisgrp="&analysisgrp." and runid = "&runid" and covarnum = &covarnum.));
                call symputx('s11', s11);
            run;
        %end;
        %end;

        /**********************************************************************
            Output Results
        ***********************************************************************/

        ods escapechar="^";
        %if &destination = excel %then %do;
        ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="green");
        %end;
        ods proclabel = "Table &tablenum.&tableletter.";

        %if &reporttype = T2L2 %then %let user_label = Number of^n New Users;
        %else %let user_label = Number of^n Pregnant Patients; 

        proc report data=repdata.table&tablenum.&tableletter nofs nowd spanrows missing
    		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR] split='*'
    		style(report)=[rules=none frame=void cellpadding =1.75pt];

            columns (
                %if &covarnum ne 0 %then %do; title %end; analysis &medicalproduct &MPColumn. n 
				  %if &reporttype = T2L2 %then %do; FUTime_Ychar AvgFuTime_Dchar AvgFuTime_Ychar %end;
                %if %index(%lowcase(&redactcolumns.),sumevents) = 0 %then %do;
                    EVchar
                %end;
                %if %index(%lowcase(&redactcolumns.),sumevents) > 0 %then %do;
                    totalevents
                %end;
                %if &reporttype = T2L2 %then %do;
                IR_1000PYchar Risk_1000NUchar IRDiff_1000PYchar RD_1000NUchar HR_95CI HR_pvalue
                %end;
                %else %do;
                Risk_1000NUchar RD_1000NUchar rrchar OR_95CI
                %if %length(&s11) > 0 %then %do;
                ADJOR_95CI
                %end;
                %end;
                );
            
            %if &covarnum ne 0 %then %do;
            define title / order order=data noprint;
            %end;
            define analysis / order order=data noprint  ;
            define &medicalproduct / display 'Medical Product'
                style(column)=[width=1.6in just=l indent=15] style(header)=[just=L background=bgr borderleftcolor=bgr];
            &MPDefine. ;
            define n / display "&user_label"
               style(column)=[just=c background=background_n_fmt. width=.7in] style(header)=[just=C background=bgr borderleftcolor=bgr];
            %if &reporttype = T2L2 %then %do;
            define FUTime_Ychar / display 'Person Years^n at Risk'
                style(column)=[just=c background=$backgroundfmt. width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define AvgFuTime_Dchar / display 'Average Person Days^n at Risk'
                style(column)=[just=c width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define AvgFuTime_Ychar / display 'Average Person Years^n at Risk'
                style(column)=[just=c width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            %end;
            %if %index(%lowcase(&redactcolumns.),sumevents) = 0 %then %do;
            define EVchar / display 'Number of Events'
                style(column)=[just=c background=$backgroundfmt. width=.7in] style(header)=[just=C background=bgr borderleftcolor=bgr];
            %end;
            %if %index(%lowcase(&redactcolumns.),sumevents) > 0 %then %do;
            define totalevents / order 'Total Number of Events'
                style(column)=[vjust=middle just=c background=$backgroundfmt. width=.7in] style(header)=[just=C background=bgr borderleftcolor=bgr];
            %end;
            %if &reporttype = T2L2 %then %do;
            define IR_1000PYchar / display 'Incidence^n Rate per 1,000^n Person Years'
                style(column)=[just=c width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define Risk_1000NUchar / display 'Risk per 1,000^n New Users'
                style(column)=[just=c width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define IRDiff_1000PYchar / order 'Incidence Rate^n Difference per 1,000^n Person Years'
                style(column)=[vjust=middle just=C width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define RD_1000NUchar / order 'Risk Difference per 1,000^n New Users'
                style(column)=[vjust=middle just=C width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define HR_95CI / order 'Hazard Ratio^n (95% Confidence Interval)'
                style(column)=[vjust=middle just=C width=1.2in] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define HR_pvalue / order 'Wald P-Value'
                style(column)=[vjust=middle just=C width=.65in] style(header)=[just=C background=bgr borderleftcolor=bgr];
            %end;
            %else %do;
            define Risk_1000NUchar / display 'Risk per 1,000^n Pregnant Patients'
                style(column)=[just=c width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define RD_1000NUchar / order 'Risk Difference per 1,000^n Pregnant Patients'
                style(column)=[vjust=middle just=C width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define rrchar / order 'Risk Ratio'
                style(column)=[vjust=middle just=C width=.7in tagattr="type:string"] style(header)=[just=C background=bgr borderleftcolor=bgr];
            define OR_95CI / order 'Odds Ratio^n (95% Confidence Interval)'
                style(column)=[vjust=middle just=C width=1.2in] style(header)=[just=C background=bgr borderleftcolor=bgr];

            %if %length(&s11) > 0 %then %do;
            define ADJOR_95CI / order 'Odds Ratio Adjusted for Selection Bias^n (95% Confidence Interval)'
                style(column)=[vjust=middle just=C width=1.2in] style(header)=[just=C background=bgr borderleftcolor=bgr];  
            %end;

            %end;

            /*Add title*/
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white 
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
            line "Table &tablenum.&tableletter.. Effect Estimates for &analysisgrpfmt. in the &database. from &startdateformatted. to &&enddate&look_end.formatted., by Analysis Type &titleend.&super_title.";
            endcomp;

            /*Add spanning description of analysis*/
            %if &covarnum = 0 %then %do;
            compute before analysis / style=[background=LIBGR foreground=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
            %end;
            %else %do;
            compute before analysis / style=[background=white foreground=black just=L font_style=italic bordertopcolor=black borderbottomcolor=black];
            %end;

                length text $100;
                
                /*Site Adjusted Analysis for IPTW/PS Weighted Stratification*/
                %if %length(&weightscheme) > 0 %then %do;
                if analysis = 'Unadjusted' then do; 
                    text='Site-Adjusted Analysis, Unweighted'; 
                    num=100;
                end;
                %end;
                %else %do;
                if analysis = 'Unadjusted' then do; 
                    text='Site-Adjusted Analysis'; 
                    num=100;
                end;
                %end;

                /*PS Match Conditional/Unconditional*/
                %if &pscsfile. = psmatchfile %then %do;
                else if analysis = 'Conditional' then do; 
                    text="&&Ratio&corder. Propensity Score Matched Conditional Analysis&&caliper&corder.&super_line."; 
                    num=100; 
                end;
                else if analysis = 'Unconditional' then do; 
                    text="&&Ratio&corder. Propensity Score Matched Unconditional Analysis&&caliper&corder."; 
                    num=100; 
                end; 
                %end;

                /*Covariate Stratified*/
                %if &pscsfile. = covstratfile %then %do;
                else if analysis = 'Conditional' then do; 
                    text="&formattedstratvars. Adjusted Analysis^{super 1}"; 
                    num=100; 
                end;
                %end;

                /*PS Stratified*/
                %if &pscsfile. = stratificationfile and %length(&weightscheme) = 0 %then %do;
                else if analysis = 'Conditional' then do; 
                    text="Propensity Score Adjusted Stratified Analysis&&percentile&corder.&pstrim.&super_line."; 
                    num=100; 
                end;
                %end;

                /*IPTW/PS Weighted Stratification*/
                %if %length(&weightscheme) > 0 %then %do;
                else if analysis = 'Unweighted' then do; 
                    %if &pscsfile. = iptwfile %then %do;
                    text="Inverse Probability of Treatment Weighted Analysis; Unweighted&pstrim."; 
                    %end;
                    %else %do;
                    text="Propensity Score Stratum Adjusted Analysis; Unweighted&pstrim.";
                    %end;
                    num=100; 
                end;
                else if analysis = 'Weighted' then do; 
                    %if &pscsfile. = iptwfile %then %do;
                    text="Inverse Probability of Treatment Weighted Analysis&super_weight.; Weight = &weightscheme.&pstrim.&super_line."; 
                    %end;
                    %else %do;
                    text="Propensity Score Stratum Adjusted Analysis; Weight = &weightscheme.&pstrim.&super_line.";
                    %end;
                    num=100; 
                end;
                %end;
                else do; 
                    text = "";
                    num=0;
                end;
                line text $Varying. num; 
            endcomp;

            %if &covarnum ne 0 %then %do;
            /*Add spanning label for subgroup category*/
                compute before title / style=[background=LIBGR foreground=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
                    length text $100;
                    %if &covarnum ne 9000 %then %do;
                        %if %eval(&covarnum. >=1000) %then %do;
                            %do x = 1 %to %sysfunc(countw(%bquote(&subcategorization.),@));
                                %let cat = %scan(%bquote(&subcategorization.), &x., @);
                                if title = "&cat" then do;
                                    /* Apply format for age categories */
                                    %if &covarnum = 1001 %then %let cat = %sysfunc(putc(&cat,$agefmt.));
                                    text = "&subgrouplabel: &cat.";
                                    num=100;
                                end;
                                else 
                            %end;
                        %end;
                        %if %eval(&covarnum. <1000) %then %do;
                            if title = "0" then do;
                                text = "No &subgrouplabel";
                                num=100;
                            end;
                            else if title = "1" then do;
                                text = "&subgrouplabel";
                                num=100;
                            end;
                            else
                        %end;
                    %end;
                    %else %do;
                     %do dps = 1 %to &num_dp.;
                            %let maskedID = %scan(&masked_dplist., &dps.);
                            if title = "&maskedID" then do;
                                text = "Data Partner %substr(&maskedID., 3)";
                                num=100;
                            end;
                            else
                     %end;
                    do; 
                        text = "";
                        num=0;
                    end;
                    %end;

                    line text $Varying. num; 
                endcomp;
            %end;

            /* Add Footnotes */
            %if &num_fn > 0 %then %do;
            compute after / style=[background=white just=L foreground=black vjust=b bordertopwidth = &bordersize borderbottomcolor=white bordertopcolor=black 
                                   nobreakspace=off font_size=&footfontsize.];
            line '';
            %do f = 1 %to &num_fn.;
            line "^{super &f.}&&fn&f.";
            %end;
            endcomp;
            %end;
            %else %do;
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
            endcomp;
            %end;
        run;

        %end;

        proc datasets nowarn noprint lib=work;
            delete label_est table&tablenum _footnotes;
        quit;

        %let tablenum = %eval(&tablenum + 1);

        %end;

    %end;

%mend l2_effect_estimate_output;
