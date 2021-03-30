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
    /*********************************************************************************************/
    /*   Define macro variables for superscripts that correspond to required footnotes           */
    /*********************************************************************************************/  	
	%macro assign_superscripts(type =, order =);
	  %global super_&type.;
	  %let super_&type. =;
	  
	  proc sql noprint;
	    select cat('^{Super ',footnote_order,'}') into: super_&type. separated by '^{Super ,}'
	    from _footnotes where order in (&order.);
	  quit;
	  
	%mend assign_superscripts;

    /*********************************************************************************************/
    /*   proc report                                                                             */
    /*********************************************************************************************/  
    %macro baseline_procreport(order = ,
                               table = ,
                               weight = ,
                               title= ,
                               characteristiclabel =, 
                               dpnum = ,
                               numcolumns = ,
                               grp1_label=,
                               grp2_label=,
                               grp3_label=, 
                               computebalance = );

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
                           x.metvar,
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
                   %if %eval(&maxswitch.=2) %then %do;
                    left join table1_&periodid.(where=(order = &order. and table = 'Switchstep_2')) as z
                    on x.metvar = z.metvar and x.sortorder1 = z.sortorder1 and x.sortorder2 = z.sortorder2
                   %end;
                   order by x.sortorder1, x.sortorder2;
                quit;
            
                %let dataset = table1&tableletter.;
            %end;

            data repdata.table1&tableletter.;
                set &dataset.(where=(order = &order. and table = &table. and weight in (&weight.)));
                keep label grouper metvar analysisgrp table weight exp_mean&dpnum.: exp_std&dpnum.:
                %if &includecomp. = Y %then %do; comp_mean&dpnum.: comp_std&dpnum.: %end;
                %if %eval(&maxswitch.=2) %then %do; switch2_mean&dpnum.: switch2_std&dpnum.: %end;
                %if &computebalance. = Y %then %do; ad&dpnum.: sd&dpnum.: %end;
                ;
            run;
        %end;
		
		/* Select Footnotes */  
	     data _footnotes;
		   length footnote_order 3; 
		   /* Always displayed across all types */
	       set lookup.lookup_footnotes (where = (order in (14 15
		   /* T1, T2L1, T6 when cohortdef is not 01 and T4L1 when a non-MIL */
		   %if ((%str("&reporttype") = %str("T1") | %str("&reporttype") = %str("T2L1") | %str("&reporttype") = %str("T6")) and %str("&cohortdef.") ne %str("01")) 
		       | (%str("&reporttype") = %str("T4L1") and %str("&cohort.") ne %str("mi"))%then %do; 1 %end;
		   /* Sdthreshold greater than 0 */
		   %if &sdthreshold. > 0 %then %do; 2 %end;
		   %if %index(&reporttype,L2) %then %do;
		   /* L2 baselinerowitalics specified */
		     %if %length(&baselinerowitalics.) > 0 %then %do; 3 %end;
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
		   /* T4L2 or T4L1 with MIL */
		   %if %index(&reporttype,T4) and %str("&cohort.") = %str("mi") %then %do; 11 %end;
		   /* T6 Switching */
		   %if %str("&reporttype.") = %str("T6") %then %do; 
		     /* 1st switch */
		     %if %eval(&maxswitch > 0) %then %do; 12 %end;
		   /* 2nd Switch */
		     %if %eval(&maxswitch=2) %then %do; 13 %end;
		   %end;
		   /* T4 L1 or L2 gestational age specified*/
		   %if %index(&reporttype,T4) and &ga_birth. = Y %then %do; 16 %end;
		   /* Comorbidscore is specified */
		   %if &comorbidscore = Y %then %do; 17 %end;
		   )));
		  by order;
		  footnote_order = _n_;
	    run;
		
		proc sql noprint;
		  select count(order) into: num_fn trimmed
		  from _footnotes;
		  
		  select description into: fn1 - :fn&num_fn.
		  from _footnotes
		  order by order;
		quit;
        
		/* Assign macro variables for superscipts */
		%assign_superscripts(type =character, order =1 2 3 4 5 6 7 8 9 10 11);
		%assign_superscripts(type =max_cell_width, order =4 5 6 7 8 9 10 16 17);
		%assign_superscripts(type =switch1, order =12);
		%assign_superscripts(type =switch2, order =13);
		%assign_superscripts(type =stdev, order =14);
		%assign_superscripts(type =race, order =15);
		%assign_superscripts(type =gestage, order =16);
		%assign_superscripts(type =comorbidscore, order =17);
		
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
        ods excel options(sheet_name="Table 1&tableletter." tab_color = "lightgreen");
        %let linebreak = ; /*reset line break and headerheight*/
        %let headerheight = .3;
        %if %eval(&numcolumns.=6) %then %let width = 1;
        %end;
        ods proclabel = "Table 1&tableletter.";
        proc report data=repdata.table1&tableletter. nofs nowd spanrows split='*'
            style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
		    style(report)=[rules=none frame=box cellpadding =1.5pt];

            column (metvar grouper label
                    %if &computebalance. = Y %then %do; ("^S={background=white}&cohortheaderlabel." %end;
                    ("^S={background=white borderleftcolor=white}&grp1_label." exp_mean&dpnum._char exp_std&dpnum._char)
                    %if &includecomp. = Y %then %do;
                    ("^S={background=white borderleftcolor=white}&grp2_label.&super_switch1." comp_mean&dpnum._char comp_std&dpnum._char)
                    %end;
                    %if &computebalance. = Y %then %do; ) %end;
                    %if %eval(&maxswitch.=2) %then %do;
                    ("^S={background=white borderleftcolor=white}&grp3_label.&super_switch2." switch2_mean&dpnum._char switch2_std&dpnum._char)
                    %end;
                    %if &computebalance. = Y %then %do; 
                    ('^S={background=white}Covariate Balance' '^S={background=white borderleftcolor=ligr}' ad&dpnum._char sd&dpnum._char)
                    %end; );

            define metvar / noprint;
            define grouper / order noprint order=data '';
            define label / display "&characteristiclabel. Characteristics&super_character." style(column)=[width=&labelwidth.in just=L] 
                           style(header)=[background = lightgrey just=L borderleftcolor=lightgrey borderrightcolor=lightgrey cellheight=&headerheight.in]; 

            define exp_mean&dpnum._char  / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"] 
                            style(header)=[background = lightgrey borderleftcolor=lightgrey borderrightcolor=lightgrey cellheight=&headerheight.in]; 
            define exp_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background = lightgrey borderleftcolor=lightgrey borderrightcolor=lightgrey cellheight=&headerheight.in]; 
            %if &includecomp. = Y %then %do;
            define comp_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            define comp_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            %end;
            %if %eval(&maxswitch.=2) %then %do;
            define switch2_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            define switch2_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            %end;

            %if &computebalance. = Y %then %do;
            define ad&dpnum._char / display 'Absolute^n Difference' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            define sd&dpnum._char / display 'Standardized^n Difference' style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            %end;

            /*Add Characteristic header lines*/
            compute before grouper / style=[background=ligr color=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
              length text $100;
              if grouper ne "&characteristiclabel. Characteristics" then do;
                text=grouper;
                num=100;
              end;
              else do; 
                text = "";
                num=0;
              end;
              line text $Varying. num; 
            endcomp;

            /*Indent demographic header lines*/
            compute label;
			  if index(label,'Race') > 0 then label = catt(label,"&super_race.");
			  else if index(label,'Charlson/Elixhauser') > 0 then label = catt(label,"&super_comorbidscore.");
			  else if label = "Mean gestational age at delivery" then label = "Mean gestational age&super_gestage. at delivery";
			  else if label = "Mean gestational age of first exposure (weeks)" then label = "Mean gestational age&super_gestage. of first exposure (weeks)";
              if prxmatch('/AGE\d|YEAR*|RACE*|HISPANIC*|SEX*|ASIAN|WHITE|AMERICAN*|BLACK*|PACIFIC*|MALE|FEMALE/',metvar) > 0 then do;
                call define(_col_,'style','style={indent=25}');
              end;

			  /*Italicize covariates*/
	          %if %length(&baselinerowitalics.) > 0 %then %do;             
              if upcase(metvar) in (&baselinerowitalics.) then do;
                call define(_row_,'style','style={fontstyle=italic}');					
              end;
        	  %end;
            endcomp;

			/*Change font color to blue if abs(SD) > threshold value*/
        	%if &computebalance. = Y and %length(&sdthreshold.) > 0 %then %do;
            compute sd&dpnum._char;
                if upcase(strip(sd&dpnum._char)) not in ("", ".", "N/A", "NAN") then do;
                    if abs(input(sd&dpnum._char, 8.3)) > &sdthreshold. then do;
                        %if %str(&baselinerowitalics) ne %str() %then %do;
                            if upcase(metvar) in (&baselinerowitalics.) then do;
                                call define(_row_,'style','style={fontstyle=italic foreground=blue}');
                            end;
                            else do;
                                call define(_row_,'style','style={foreground=blue}');
                            end;
                        %end;
                        %else %do;
                            call define(_row_,'style','style={foreground=blue}');
                        %end;
                    end;
                end;
            endcomp;
        	%end;

            /*Add title*/
            compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
            line "&title.";
            endcomp;
			/* Add Footnotes */
			compute after / style=[just=L %if %length(&super_max_cell_width.) > 0 %then %do; height=1.75in %end; nobreakspace=off];
             line '';
			  %do f = 1 %to &num_fn.;
                line "^{super &f.}&&fn&f.";
			  %end;
            endcomp;
        run;   
    %mend;

    /*counter for determining table letter*/
    %let tablecount = 1;

    /*loop through each baseline table*/
    %do b = 1 %to &numbaselinetablegrp.;
        %let analysisgrp = ;
        %let analysisgrp2 = ;
        %let baselinegroupnum = ;
        %let pregnancylabel = ;
        %let includenonpregnant = N;
        %let includecomp = N;
        %let computebalance =N;
        %let maxswitch = 0;

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
				call symputx('comorbidscore',comorbidscore);
				call symputx('ga_birth',ga_birth);
                call symputx('unique_psestimate',unique_psestimate);
                if missing(sdthreshold) then call symputx('sdthreshold', '');
                else call symputx('sdthreshold', sdthreshold);				
                call symputx('baselinerowitalics', strip(upcase(baselinerowitalics)));

                %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
                call symputx('computebalance', 'Y');
                %end;
                %else %do;
                if computebalance = 'Y' then call symputx('computebalance', 'Y');
                %end;

                %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
                if cohort in ('preg', 'nopreg') then do;
                    if upcase(includenonpregnant) = 'Y' then call symput('pregnancylabel', ' Pregnancy Cohort and Non-Pregnancy Cohort');
                    else call symput('pregnancylabel', ' Pregnancy Cohort');
                end;
                call symputx('includenonpregnant', upcase(includenonpregnant));
                %end;
                if missing(baselinegroupnum)=0 then call symputx('baselinegroupnum', baselinegroupnum);
                
                /*if reporttype = T2L2 or T4L2 or T6 or cohort = mi or includenonpreggroup = Y,
                  or BASELINEGROUPNUM is specified then include COMP columns*/
                if "&reporttype."="T2L2" | "&reporttype."="T4L2" | "&reporttype."="T6" | upcase(computebalance)= 'Y' |
                   upcase(includenonpregnant) = 'Y' | cohort = "mi" | missing(baselinegroupnum)=0 then do;
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
                end;
            end;
        run;

        /*Additional meta-data and group-specific names for each reporttype*/
        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            data _null_;
                set pscs_masterinputs(where=(analysisgrp = "&analysisgrp." and covarnum=0));
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
                    call symputx('truncationlabel',strip(put(truncweight, best.))||'%');
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

			/*Defensive check for sdthreshold and baselinerowitalics parameters*/
			%if %eval(&unique_psestimate.) ne 1 %then %do;
				proc sql noprint;
				create table baseline_unique_check as
				select a.analysisgrp,
					   a.psestimategrp,
					   a.sdthreshold,
					   a.baselinerowitalics
				from baselinefile as a
				left join pscs_masterinputs as b
				on a.analysisgrp = b.analysisgrp and
				a.psestimategrp = a.psestimategrp
				where b.covarnum=0
				order by a.order;
				quit;

				proc sql noprint;
				select count (distinct sdthreshold) into :sdthreshold_count trimmed
				from baseline_unique_check
				where psestimategrp = "&psestimategrp";

				select count (distinct baselinerowitalics) into :baselinerowitalics_count trimmed
				from baseline_unique_check
				where psestimategrp = "&psestimategrp";
				quit;

				%if %eval(&sdthreshold_count. > 1) or %eval(&baselinerowitalics_count. > 1) %then %do;
					%put WARNING: (Sentinel) SDTHRESHOLD or BASELINEROWITALICS value differs across analyses that share the same psestimategrp.;
					%put PSESTIMATEGRP=&psestimategrp has &sdthreshold_count SDTHRESHOLD distinct value(s) and &baselinerowitalics_count BASELINEROWITALICS distinct value(s);
					
					/* If multiple values are detected for a same psestimategrp, assign the first available value for this psestimategrp (already sorted by order)*/
					data _null_;
					set baseline_unique_check(where=(psestimategrp = "&psestimategrp"));
					if _N_=1;
					if missing(sdthreshold) then call symputx('sdthreshold', '');
	                else call symputx('sdthreshold', sdthreshold);
					call symputx('baselinerowitalics', strip(upcase(baselinerowitalics)));
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

		%if %length(&baselinerowitalics.) > 0 %then %do;
			%create_comma_charlist(inlist=&baselinerowitalics., outlist=baselinerowitalics);
		%end;

        /*determine if only 1 baseline table and set &tablecount to 0. Will occur if all the following are true:
        - 1 monitoring period
        - DP stratification = N
        - max(order) in baselinefile = 1
        - if reporttype = T2L2/T4L2 - then analysis must be covariate stratification*/
        %if %eval(&b.=1) & %eval(&look_start.) = %eval(&look_end.) & &stratifybydp. = N & %eval(&numbaselinetablegrp.=1) %then %do;
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) = 0 %then %do;
                %let tablecount = 0;
            %end;
            %else %do;
                %if &psfile. = covstratfile %then %let tablecount = 0;
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
        %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 & &cohort. = mi %then %do;
            %let eoilabel = &analysisgrp._eoi;
            %let reflabel = &analysisgrp._ref;
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
                    %end; 
                    %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 & &cohort. = mi %then %do;
                        labelfile(in=i where=(group="&analysisgrp._eoi" and runid = "&runid"))
                        labelfile(in=j where=(group="&analysisgrp._ref" and runid = "&runid"))
                    %end; ;
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
                %end; 
                %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 & &cohort. = mi %then %do;
                if i then do; if labeltype = 'grouplabel' then call symputx('eoilabel',strip(label)); end;
                if j then do; if labeltype = 'grouplabel' then call symputx('reflabel',strip(label)); end;
                %end; ;
            run;
        %end;

        %let captionlabel = %bquote(&grouplabel.&pregnancylabel&baselinelabel.);
        %if %length(&baselinegroupnum.)>0 %then %do;
        %let captionlabel = %bquote(&grouplabel.&pregnancylabel and &grouplabel2.&pregnancylabel&baselinelabel.);
        %end;
        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) >0 & &psfile. ne covstratfile %then %do;
        %let captionlabel = %bquote(&psestimatelabel.);
        %end;         

        /*Set group labels*/
        %if %sysfunc(prxmatch(m/T1|T5|T2L1/i,&reporttype.)) > 0 %then %do;
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
            %if &cohort = mi %then %do;
                /*MI exposure and reference cohorts*/
                %let grp1_label = %bquote(&eoilabel.);
                %let grp2_label = %bquote(&reflabel.);
            %end;
            %else %do;
                /*Pregnant and non-pregnant cohorts*/
                %let grp1_label = %bquote(&grouplabel. Pregnancy Cohort);
                %if &includenonpregnant. = Y %then %do;
                %let grp2_label = %bquote(&grouplabel. Non-Pregnancy Cohort);
                %end;
            %end;
        %end;
       
        %if %length(&baselinegroupnum.)>0 %then %do;
            %let grp2_label = %bquote(&grouplabel2.);
            %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
            %let grp2_label = %bquote(&grouplabel2. Pregnancy Cohort);
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
        %macro baselinereport(table=, dpnum=);
            %if %eval(&unique_psestimate.) = 1 %then %do;
             %tableletter(); 
             %baseline_procreport(order = &b., table = 'Unadjusted', weight ='Unweighted',
              title =%quote(Table 1&tableletter.. &unadjusted.Baseline Characteristics of &captionlabel. (&table.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.),
              characteristiclabel =&characteristiclabel.,
              dpnum = &dpnum.,
              numcolumns =&numcolumns.,
              grp1_label=&grp1_label.,
              grp2_label=&grp2_label., 
              grp3_label=&grp3_label.,
              computebalance = &computebalance.);
            %end;

            /*For L2 tables - up to 2 additional adjusted tables*/
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                /*PS Match Adjusted*/
                %if &psfile. = psmatchfile %then %do;
                %tableletter(); 
                %baseline_procreport(order = &b., table = 'Adjusted', weight = %str('Unweighted', 'Weighted'),
                  title =%quote(Table 1&tableletter.. Adjusted Baseline Characteristics of &grouplabel. (Propensity Score Matched, &table.), &ratiolabel.&caliperlabel., in the &database. from &startdateformatted. to &&enddate&periodid.formatted.),
                  characteristiclabel =&characteristiclabel.,
                  dpnum = &dpnum.,
                  numcolumns =&numcolumns.,
                  grp1_label=&grp1_label.,
                  grp2_label=&grp2_label., 
                  grp3_label=&grp3_label.,
                  computebalance = &computebalance.);
                %end;

                /*Unweighted - IPTW and PS Stratum*/
                %if (&psfile. = iptwfile & %eval(&unique_psestimate.) = 1) | (&psfile. = stratificationfile & ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") & %eval(&pstrim.>=0)) %then %do;
                %tableletter(); 
                %baseline_procreport(order = &b., table = 'Adjusted', weight = 'Unweighted',
                  title=%quote(Table 1&tableletter.. Unweighted Baseline Characteristics of &grouplabel. (Unweighted, Trimmed, &table.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.),
                  characteristiclabel =&characteristiclabel.,
                  dpnum = &dpnum.,
                  numcolumns =&numcolumns.,
                  grp1_label=&grp1_label.,
                  grp2_label=&grp2_label., 
                  grp3_label=&grp3_label.,
                  computebalance = &computebalance.);
                %end;
					
                /*Weighted - IPTW, PS Stratum, PS Stratification*/
                %if &psfile. = iptwfile | &psfile. = stratificationfile %then %do;
                    %if &psfile. = iptwfile %then %let stratumtitle = (Inverse Probability of Treatment Weighted, Trimmed, &table.), Weight: &weightlabel., Truncation: &truncationlabel.;
                    %else %if "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %let stratumtitle = (Propensity Score Stratum Weighted, Trimmed, &table.), Percentiles: &percentiles., Weight: &weightlabel.;
                    %else %let stratumtitle =(Propensity Score Stratified, &table.), Percentiles: &percentiles.;
                    %tableletter(); 
                    %baseline_procreport(order = &b., table = 'Adjusted', weight = 'Weighted',
                      title=%quote(Table 1&tableletter.. Weighted Baseline Characteristics of &grouplabel. &stratumtitle., in the &database. from &startdateformatted. to &&enddate&periodid.formatted.),
                      characteristiclabel =&characteristiclabel.,
                      dpnum = &dpnum.,
                      numcolumns =&numcolumns.,
                      grp1_label=&grp1_label.,
                      grp2_label=&grp2_label., 
                      grp3_label=&grp3_label.,
                      computebalance = &computebalance.);
                %end;
            %end; /*Additional L2 tables*/
        %mend;

        /*loop through each periodid*/
        %do periodid = %eval(&look_start.) %to %eval(&look_end.);
            /*Aggregated*/
            %baselinereport(table=Aggregated,dpnum=0);
   
            /*Output seperate table for each Data Partner - loop through each DP*/
            %if &stratifybydp. = Y %then %do;    
                %do dps = 1 %to %eval(&num_dp.);
        	        %let maskedID = %scan(&masked_dplist,&dps); 
                    %baselinereport(table=&maskedid.,dpnum=&dps.);
                %end;
            %end; /*DP stratification*/
        %end; /*loop through each periodid*/
    %end; /*loop through each row in baselinefile*/
    %end; /*include baseline tables */

    %put =====> END MACRO: baseline_output ;

%mend baseline_output;
