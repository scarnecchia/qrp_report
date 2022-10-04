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
                ;
            run;
        %end;

		/* Select Footnotes */  
		%let covnotinpsorder = 19;
		%let covnotinps_no =;
		%global covarlablabels;
		%let covarlablabels=;
		/*need to reorder the footnotes when covnotinps is populated because 
		  footnote placement is determined by METVAR values listed in the parameter*/
		/* L2 covnotinps specified */
		%if %length(&covnotinps.) > 0 %then %do; 
		%let covnotinps_no = %sysfunc(compbl(%sysfunc(tranwrd(%quote(&covnotinps), %str(,), %str()))));
		%let covnotinps_noquotes = %sysfunc(translate(%superq(covnotinps),%str( ),%str(%")));

			* Check if all covariates specified in &covnotinps are in &labcharacteristics. If this is the case we need to push the footnote further;
			%let num_covnotinps_nolab=1;
			%if %str("&labcharacteristics") ^= %str("missing") %then %do;
				%let tempvarlabs=%upcase(&labcharacteristics);

				%baseline_expand_parameters(var=tempvarlabs);
	  
				proc sort data= covarname(keep=studyname cov_varname where=(upcase(cov_varname) in (&tempvarlabs))) out=labcovar(rename=cov_varname=cov);
				by cov_varname;
				run; 

				data CovNotInPS;	
				format cov $30.;	
				do obs=1 by 1 until (cov=' ');
					cov=lowcase(strip(scan("&covnotinps_noquotes",obs)));
					if cov ne " " then output;
				end;
				drop obs;
				run;

				proc sort data=CovNotInPS;
				by cov;
				run;

				data CovNotInPS;
				merge CovNotInPS
					  labcovar(in=b);
				by cov;
				NoLab=0;
				if not b then NoLab=1;
				run;
				
				proc sql noprint;
				select sum(NoLab) into :num_covnotinps_nolab from CovNotInPS;
				quit;

				proc sql noprint undo_policy=none;
				create table CovNotInPS as 
				select * from CovNotInPS
				where upcase(cov) in (&Covnotinps.);
				quit;

				proc sql noprint;
				select studyname into :covarlablabels separated by ' ' from CovNotInPS;
				quit;

				%create_comma_charlist(inlist=&covarlablabels, outlist=covarlablabels);

				%put &=num_covnotinps_nolab;
				%put &=covarlablabels;
	        %end;
	
		  data _footnotes;
		    length order 8;
			format order 4.2;
		    set lookup.lookup_footnotes (where = (type = "baseline"));
			/*birth_enroll or enroll_diff*/
            %if %index(%trim(&covnotinps_no.), BIRTH_ENROLL) > 0  %then %do;
              if order = 19 then order = 14.2;
			  %let covnotinpsorder = 14.2;
			%end;
			%else %if %index(%trim(&covnotinps_no.), ENROLL_DIFF) > 0  %then %do;
              if order = 19 then order = 14.3;
			  %let covnotinpsorder = 14.3;
			%end;
            /*age*/
            %else %if %index(%trim(&covnotinps_no.), AGE) > 0  %then %do;
              if order = 19 then order = 14.4;
			  %let covnotinpsorder = 14.4;
			%end;
		    /*sex*/
            %else %if %index(%trim(&covnotinps_no.), SEX) > 0 %then %do;
              if order = 19  then order = 14.5;
			  %let covnotinpsorder = 14.5;
			%end;
		    /*race*/
            %else %if %index(%trim(&covnotinps_no.), RACE) > 0 %then %do;
              if order = 19  then do; 
                order = 16.3; 
                %let covnotinpsorder = 16.3;
			  end;
			%end;
    	    /*hispanic*/
            %else %if %index(%trim(&covnotinps_no.), HISPANIC) > 0 %then %do;
			 if order =19  then do; 
                order = 16.4; 
                %let covnotinpsorder = 16.4;
			  end;
			%end;
		    /*year*/
			%else %if %index(%trim(&covnotinps_no.), YEAR) > 0 %then %do;
             if order =19  then do; 
                order = 16.5; 
                %let covnotinpsorder = 16.5;
			  end;
			%end;
			/*prepostind*/
			%else %if %index(%trim(&covnotinps_no.), PREPOSTIND) > 0 %then %do;
             if order =19  then do; 
                order = 16.6; 
                %let covnotinpsorder = 16.6;
			  end;
			%end;

		    /*gestational age*/
			%else %if %index(%trim(&covnotinps_no.), GA_) > 0 %then %do;
              if order =19  then do; 
                order = 17.5; 
                %let covnotinpsorder = 17.5;
			  end;
			%end;
			%else %if %index(%trim(&covnotinps_no.), ADJUSTEDDISP_) > 0 %then %do;
              if order =19  then do; 
                order = 17.6; 
                %let covnotinpsorder = 17.6;
			  end;
			%end;
			%else %if %index(%trim(&covnotinps_no.), EXP_) > 0 %then %do;
              if order =19  then do; 
                order = 17.7; 
                %let covnotinpsorder = 17.7;
			  end;
			%end;
			%else %if %eval(&num_covnotinps_nolab = 0) %then %do;
              if order =19  then do; 
                order = 20.1; 
                %let covnotinpsorder = 20.1;
			  end;
			%end;
		  run;

		  proc sort data = _footnotes;
		    by order;
		  run;
        %end;

		data _footnotes;
		   length footnote_order 3; 
		   /* Always displayed across all types */
		   %if %length(&covnotinps.) > 0 %then %do; 
		     set _footnotes (where =  ((type = "baseline" and order in (14 &covnotinpsorder. 15
		   %end;
		   %else %do;
	         set lookup.lookup_footnotes (where = ((type = "baseline" and order in (14 15   
		   %end;
		   /* T4 L1 or L2 gestational age specified*/
		   %if %index(&reporttype,T4) > 0 and &gestationalage. = Y %then %do; 17 %end;
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
		   /* Comorbidscore is specified */
		   %if &comorbidscore = Y %then %do; 18 %end;
		   /* Lab characteristics specified. */
		   %if %str("&labcharacteristics.") ^= %str("missing") %then %do; 20 %end;		   
		   ))
            %if %index(&reporttype,T4) > 0 %then %do;
            or (type='type4' and order in (-2 
                %if &includenonpregnant = Y %then %do; -1 %end; ))
            %end;
                ));
		  by order;
		  footnote_order = _n_;
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
		  order by order;
		quit;

 
		/* Assign macro variables for superscipts */
		%assign_superscripts(type =title, order =-2 -1);
		%assign_superscripts(type =character, order =1 2 4 5 6 7 8 9 10 11 );
		%assign_superscripts(type =max_cell_width, order =4 5 6 7 8 9 10 18 );
		%assign_superscripts(type =switch1, order =12);
		%assign_superscripts(type =switch2, order =13);
		%assign_superscripts(type =stdev, order =14);
        %assign_superscripts(type =race, order =15);
        %assign_superscripts(type =unknownrace, order =16);
		%assign_superscripts(type =gestage, order =17);
		%assign_superscripts(type =comorbidscore, order =18 
          %if %length(&covnotinps.) > 0 and %index(%trim(&covnotinps_no.), COMORBIDSCORE) > 0 %then %do;
            &covnotinpsorder. %end;);
		%assign_superscripts(type =covar, order =&covnotinpsorder.);
		%assign_superscripts(type =labcovar, order =20);

		
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
        proc report data=repdata.table1&tableletter. nofs nowd spanrows split='*'
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

            define exp_mean&dpnum._char  / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"] 
                            style(header)=[background = LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in]; 
            define exp_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background = LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in]; 
            %if &includecomp. = Y %then %do;
            define comp_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            define comp_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            %end;
            %if %eval(&maxswitch.=2) %then %do;
            define switch2_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            define switch2_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation&super_stdev." style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            %end;

            %if &computebalance. = Y %then %do;
            define ad&dpnum._char / display 'Absolute^n Difference' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=LIBGR borderleftcolor = LIBGR cellheight=&headerheight.in];
            define sd&dpnum._char / display 'Standardized^n Difference' style(column)=[width=&width.in tagattr="type:string"]
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

            /*Indent demographic header lines and lab covariate record lines*/
            compute label;

              if index(label,'Race') > 0 then label = catt(label,"&super_race.");
			  else if index(label,'Charlson/Elixhauser') > 0 then label = catt(label,"&super_comorbidscore.");
			  %if %length(&covnotinps.) > 0 %then %do;
			    else if metvar in (&covnotinps.) and metvar eq 'GA_BIRTH' and label = "Gestational age at delivery"
                  then label = "Gestational age&super_gestage. at delivery&super_covar.";
			  %end;
			  else if label = "Gestational age at delivery" then label = "Gestational age&super_gestage. at delivery";
			  %if %length(&covnotinps.) > 0 %then %do;
			    else if metvar in (&covnotinps.) and metvar eq 'GA_FIRST' and label = "Gestational age of first exposure (weeks)"
                  then label = "Gestational age&super_gestage. of first exposure (weeks)&super_covar.";
			  %end;
			  else if label = "Gestational age of first exposure (weeks)" then label = "Gestational age&super_gestage. of first exposure (weeks)";
			  %if %length(&covnotinps.) > 0 and %length(&covarlablabels.) > 0 %then %do;
				else if upcase(label) in (&covarlablabels.) then label = catt(label, "&super_covar.");
			  %end;
              %if %length(&covnotinps.) > 0 %then %do;
			    /*Comborbidscore already included in &super_comorbidscore*/
                else if metvar in (&covnotinps.) and upcase(label) ne "TEST RECORD" and metvar ne 'COMORBIDSCORE' then label = catt(label, "&super_covar.");
              %end;
              if prxmatch('/AGE\d|YEAR*|RACE*|HISPANIC*|SEX*/',metvar) > 0 then do;
                call define(_col_,'style','style={indent=25}');
              end;
              %if %str("&labcharacteristics.") ^= %str("missing") %then %do; 
              if prxmatch('/^(Test record|No test record|Test records with missing or unknown units)$|Test record in/', strip(label)) then do;
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
                      call define(_row_,'style','style={foreground=blue}');
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
			                        height=1.75in bordertopwidth = &bordersize];
			  %do f = 1 %to &num_fn.;
                line "^{super &f.}&&fn&f.";
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
            delete _footnotes;
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
        %let includenonpregnant = N;
        %let includecomp = N;
        %let computebalance =N;
        %let maxswitch = 0;
        %let covnotinps = ;

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
				call symputx('gestationalage',gestationalage);
                call symputx('unique_psestimate',unique_psestimate);
				call symputx('unique_psestimate_orig',unique_psestimate);
                if missing(sdthreshold) then call symputx('sdthreshold', '');
                else call symputx('sdthreshold', sdthreshold);	
                if missing(labcharacteristics) then call symputx('labcharacteristics',"missing");
                else call symputx('labcharacteristics', labcharacteristics);
                %if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;	
                if missing(covnotinps)=0 then call symputx('covnotinps', strip(upcase(covnotinps)));
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
                
                /*if reporttype = T2L2, T4L2, T6, or cohort = mi or includenonpreggroup = Y,
                  or BASELINEGROUPNUM is specified then include COMP columns*/
                if "&reporttype."="T2L2" | "&reporttype."="T4L2" | "&reporttype."="T6" 
				   | upcase(computebalance)= 'Y' | upcase(includenonpregnant) = 'Y' | cohort = "mi" | missing(baselinegroupnum)=0 then do;
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

			/*Defensive check for sdthreshold and covnotinps parameters*/
			%if %eval(&unique_psestimate.) ne 1 %then %do;
				proc sql noprint;
				create table baseline_unique_check as
				select a.analysisgrp,
					   a.psestimategrp,
					   a.sdthreshold,
					   a.covnotinps
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

				select count (distinct covnotinps) into :covnotinps_count trimmed
				from baseline_unique_check
				where psestimategrp = "&psestimategrp";
				quit;

				%if %eval(&sdthreshold_count. > 1) or %eval(&covnotinps_count. > 1) %then %do;
					%put WARNING: (Sentinel) SDTHRESHOLD or covnotinps value differs across analyses that share the same psestimategrp.;
					%put PSESTIMATEGRP=&psestimategrp has &sdthreshold_count SDTHRESHOLD distinct value(s) and &covnotinps_count covnotinps distinct value(s);
					
					/* If multiple values are detected for a same psestimategrp, assign the first available value for this psestimategrp (already sorted by order)*/
					data _null_;
					set baseline_unique_check(where=(psestimategrp = "&psestimategrp"));
					if _N_=1;
					if missing(sdthreshold) then call symputx('sdthreshold', '');
	                else call symputx('sdthreshold', sdthreshold);
					call symputx('covnotinps', strip(upcase(covnotinps)));
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

		%if %length(&covnotinps.) > 0 %then %do;
			%create_comma_charlist(inlist=&covnotinps., outlist=covnotinps1);
            %let covnotinps = &covnotinps1.;
		%end;

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
			        %if %length(&baselinegroupnum.)>0 %then %do;
			        %let captionlabel = %bquote(&grouplabel.&pregnancylabel and &grouplabel2.&pregnancylabel&baselinelabel.);
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
	              grp1_label=&grp1_label.,
	              grp2_label=&grp2_label., 
	              grp3_label=&grp3_label.,
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
	                  grp1_label=&grp1_label.,
	                  grp2_label=&grp2_label., 
	                  grp3_label=&grp3_label.,
	                  computebalance = &computebalance.,
	                  includenonpregnant=&includenonpregnant.);
	                %end;

	                /*Unweighted - IPTW and PS Stratum*/
	                %if (&psfile. = iptwfile & %eval(&unique_psestimate.) = 1) | (&psfile. = stratificationfile & ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") & %eval(&pstrim.>=0)) %then %do;
	                %tableletter(); 
	                %baseline_procreport(order = &b., table = 'Adjusted', weight = 'Unweighted',
	                  title=%quote(Table 1&tableletter.. &aggregated.Unweighted Characteristics of &grouplabel. (Unweighted, Trimmed&dpcomma.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.&subgrouptitle.),
	                  characteristiclabel =&characteristiclabel.,
					  labcharacteristics = %quote(&labcharacteristics),
	                  dpnum = &dpnum.,
	                  numcolumns =&numcolumns.,
	                  grp1_label=&grp1_label.,
	                  grp2_label=&grp2_label., 
	                  grp3_label=&grp3_label.,
	                  computebalance = &computebalance.,
	                  includenonpregnant=&includenonpregnant.);
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
	                      grp1_label=&grp1_label.,
	                      grp2_label=&grp2_label., 
	                      grp3_label=&grp3_label.,
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
