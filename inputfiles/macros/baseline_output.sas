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
        %end;
        ods proclabel = "Table 1&tableletter.";
        proc report data=repdata.table1&tableletter. nofs nowd spanrows split='*'
            style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
		    style(report)=[rules=none frame=box cellpadding =1.5pt];

            column (metvar grouper label
                    %if &computebalance. = Y %then %do; ("^S={background=white}&cohortheaderlabel." %end;
                    ("^S={background=white borderleftcolor=white}&grp1_label." exp_mean&dpnum._char exp_std&dpnum._char)
                    %if &includecomp. = Y %then %do;
                    ("^S={background=white borderleftcolor=white}&grp2_label." comp_mean&dpnum._char comp_std&dpnum._char)
                    %end;
                    %if &computebalance. = Y %then %do; ) %end;
                    %if %eval(&maxswitch.=2) %then %do;
                    ("^S={background=white borderleftcolor=white}&grp3_label." switch2_mean&dpnum._char switch2_std&dpnum._char)
                    %end;
                    %if &computebalance. = Y %then %do; 
                    ('^S={background=white}Covariate Balance' '^S={background=white borderleftcolor=ligr}' ad&dpnum._char sd&dpnum._char)
                    %end; );

            define metvar / noprint;
            define grouper / order noprint order=data '';
            define label / display "&characteristiclabel. Characteristics" style(column)=[width=&labelwidth.in just=L] 
                           style(header)=[background = lightgrey just=L borderleftcolor=lightgrey borderrightcolor=lightgrey cellheight=&headerheight.in]; 

            define exp_mean&dpnum._char  / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"] 
                            style(header)=[background = lightgrey borderleftcolor=lightgrey borderrightcolor=lightgrey cellheight=&headerheight.in]; 
            define exp_std&dpnum._char / display "Percent/^n Standard&linebreak. Deviation" style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background = lightgrey borderleftcolor=lightgrey borderrightcolor=lightgrey cellheight=&headerheight.in]; 
            %if &includecomp. = Y %then %do;
            define comp_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            define comp_std&dpnum._char / display "Percent/^n Standard Deviation" style(column)=[width=&width.in tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            %end;
            %if %eval(&maxswitch.=2) %then %do;
            define switch2_mean&dpnum._char / display 'Number/Mean' style(column)=[width=&width.in background = $backgroundfmt. tagattr="type:string"]
                            style(header)=[background=lightgrey cellheight=&headerheight.in];
            define switch2_std&dpnum._char / display "Percent/^n Standard Deviation" style(column)=[width=&width.in tagattr="type:string"]
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
              if prxmatch('/AGE\d|YEAR*|RACE*|HISPANIC*|SEX*|ASIAN|WHITE|AMERICAN*|BLACK*|PACIFIC*|MALE|FEMALE/',metvar) > 0 then do;
                call define(_col_,'style','style={indent=25}');
              end;
            endcomp;

            /*Add title*/
            compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
            line "&title.";
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
                call symputx('unique_psestimate',unique_psestimate);

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
        %end;

        %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
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
                    %end; ;
                if a then do;
                    if labeltype = 'grouplabel' then call symputx('grouplabel',strip(label));
                    if labeltype = 'baselinelabel' then call symputx('baselinelabel',cat(', ',strip(label), ','));
                end;
                %if %length(&baselinegroupnum.)>0 %then %do;
                if b then do; if labeltype = 'grouplabel' then call symputx('grouplabel2',strip(label)); end;
                %end;
                %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 & &psfile. ne covstratfile %then %do;
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
            %let grp1_label = &grouplabel.;
        %end;
        %else %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            %let grp1_label = &eoilabel. ;
            %let grp2_label = &reflabel. ;
        %end;
        %else %if %sysfunc(prxmatch(m/T6/i,&reporttype.)) > 0 %then %do;
            %let grp1_label = &switch0grplabel.;
            %let grp2_label = &switch0grplabel. to &switch1grplabel.;
            %if %eval(&maxswitch=2) %then %do;
            %let grp3_label = &switch1grplabel. to &switch2grplabel.;
            %end;
        %end;
        %else %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;

        %end;
       
        %if %length(&baselinegroupnum.)>0 %then %do;
            %let grp2_label = &grouplabel2.;
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
        %macro baselinereport(table, dpnum);
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
            %baselinereport(Aggregated, 0);
   
            /*Output seperate table for each Data Partner - loop through each DP*/
            %if &stratifybydp. = Y %then %do;    
                %do dps = 1 %to %eval(&num_dp.);
        	        %let maskedID = %scan(&masked_dplist,&dps); 
                    %if %eval(&unique_psestimate.) = 1 %then %do;
                        %baselinereport(&maskedid., &dps.);
                    %end;
                %end;
            %end; /*DP stratification*/
        %end; /*loop through each periodid*/
    %end; /*loop through each row in baselinefile*/
    %end; /*include baseline tables */

    %put =====> END MACRO: baseline_output ;

%mend baseline_output;
