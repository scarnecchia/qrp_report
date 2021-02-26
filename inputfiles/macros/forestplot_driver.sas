****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: forestplot_driver.sas  
* Created (mm/dd/yyyy): 02/23/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Creates and outputs forest plots for level 2 analyses
*                                       
*  Program inputs:                                                                                   
*   - l2_effectestimates_&periodid.sas7bdat
* 
*  Program outputs:                                                                                                                                       
*   - [runid]_forest_[periodid].sas7bdat
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

%macro forestplot_driver;

      ods graphics on / width=6.5in scale=on;

    /* loop through each runid */
    %do n = 1 %to &numrunid;
      %let runid = %scan(&runidlist,&n);

      %do j = %eval(&look_start) %to %eval(&look_end); /*loop through periods*/

        %let tablecount=1;
        %let tableletter=a;

        %if "&reporttype." = "T2L2" %then %do;
        %let ForestRatioTitle = Hazard Ratios (HR);
        %let ForestRatioFoot = Hazard ratio;
        %let ForestRatioLabel = HR (95% CI);
        %let ForestCI95 = HR_95CI;
        %let ForestPointEst = HR;
        %let ForestLowerCI = LCL;
        %let ForestUpperCI = UCL;
        %end;
        %else %if "&reporttype." = "T4L2" %then %do;
        %let ForestRatioTitle = Odds Ratios (OR);
        %let ForestRatioFoot = Odds ratio;
        %let ForestRatioLabel = OR (95% CI);
        %let ForestCI95 = OR_95CI;
        %let ForestPointEst = OR;
        %let ForestLowerCI = LCL;
        %let ForestUpperCI = UCL;
        %isdata(dataset=selectionprobabilities);
        %if %eval(&nobs) > 0 %then %do;
        %let ForestRatioTitle = Adjusted Odds Ratios (OR);
        %let ForestRatioFoot = Adjusted odds ratio;
        %let ForestRatioLabel = Adjusted OR (95% CI);
        %let ForestCI95 = ADJOR_95CI;
        %let ForestPointEst = ADJOR;
        %let ForestLowerCI = Adj_LCL;
        %let ForestUpperCI = Adj_UCL;
        %end;
        %end; 

        /*7 potential plots:
            1. Site-adjusted
            2. PS matched conditional analysis
            3. PS matched unconditional analysis
            4. PS stratified analysis (missing strataweight)
            5. PS stratum weighted analysis
            6. IPTW
            7. Covariate stratification */

        %do plot = 1 %to 7;

            /*set forest plot variables for this loop*/
            %let forestfootnote = Y;
            %let forestnohrfootnote = N;
            %let nummaxforestfootnote = 9;
            %let unicode_list = 00b9 00b2 00b3 2074 2075 2076 2077 2078 2079;

            %let displayperiodid = ;
            %if %eval(&look_start) ne %eval(&look_end) %then %let displayperiodid =%str( (MP &j.));

            data forest;
            set output.&runid._forest_&j(where=(plotorder=&plot));
              obsid=_n_;
              if id ne 1 then refid=obsid;
              /* Reduce indent for methods heading */
              if id=1 then indentWt=0;
              if id=2 then indentWt=.5;
              if id=3 then indentWt=1;
              call symputx("plotheight", cats(_n_*0.225+0.7,'in'),'G');
              call symputx("forest_title",forest_title);

              /*if HR cannot be computed for any row in plot, then:
                 - only 8 additional footnotes are possible
                 - start assigning footnotes at 2
                 - modify &displayperiodid to add superscript */
              if &ForestCI95 = '-' then do;
                call symputx('forestnohrfootnote', 'Y');
                call symputx('nummaxforestfootnote', 8);
                call symputx('unicode_list', '00b2 00b3 2074 2075 2076 2077 2078 2079');
                call symputx('displayperiodid', cat("&displayperiodid", "^{super 1}"));
              end;
            run;

            /* Only create forest plots if analysis exists */
            %isdata(dataset=forest);
            %if %eval(&nobs)>0 %then %do;

                /*Site-adjusted and covariate stratification do not have footnotes*/
                %if %eval(&plot.=1) | %eval(&plot.=7) %then %let forestfootnote = N;

                /* Create superscripts */
                %if &forestfootnote = Y %then %do;
                    
                    proc sql noprint;
                        /*number of footnotes*/
                        select count(distinct footnote) into: number_forest_footnotes
                        from forest(where=(id=1));
                        create table footnotes as
                        select analysisgrpsort, footnote
                        from forest(where=(id=1));
                    quit;

                    %if %eval(&number_forest_footnotes > &nummaxforestfootnote.) %then %do;
                    %put WARNING: (Sentinel) There are more than &nummaxforestfootnote. footnotes that will be printed.;
                    %put WARNING: (Sentinel) More than &nummaxforestfootnote. footnotes are not supported.;
                    %put WARNING: (Sentinel) Plot creation will be by bypassed.;
                    %goto plotleaveloop;
                    %end;

                    /*Build format statement*/
                    %let footnoteformat = ;
                    %let allfootnotes = ;

                    %do countgrp = 1 %to %eval(&number_forest_footnotes.);
                        %let unicode = %scan(&unicode_list,&countgrp);

                        /*build allfootnotes list*/
                        data _null_;
                            set footnotes;
                            if _n_=1 then do;
                                %if %eval(&countgrp.=1) %then %do;
                                call symputx("allfootnotes", footnote);
                                %end;
                                %else %do;
                                call symputx("allfootnotes", catx('@',%str("&allfootnotes."), footnote));
                                %end;
                                call symputx("currentfootnote", footnote);
                            end;
                        run;

                        /*Datasteps are used to maintain footnote order*/

                        data footnotes;
                            set footnotes(where=(footnote ne %str("&currentfootnote.")));
                        run;
                        data foot&countgrp.(keep=analysisgrp title);
                            set forest(where=(id=1));
                            if footnote = "&currentfootnote" then output;
                        run;

                        %isdata(dataset=foot&countgrp.);
                        %do f = 1 %to %eval(&nobs.);
                            data _null_;
                                set foot&countgrp.;
                                if _n_ = &f. then do;
                                    if not missing(title) then call symputx('analysistitle', title);
                                end;
                            run;

                            %let footnoteformat = &footnoteformat. 
                                                 "&analysistitle" = "&analysistitle(*ESC*){unicode '&unicode'x}" ;
                        %end;
                    %end;

                    proc format;
                        value $ grpuni
                        &footnoteformat.;
                    run;
                %end; /*Create footnote format*/

                /*Trick excel to create new sheet*/
                ods startpage=now;
                ods excel options(sheet_interval="table");
                ods exclude all;
                data _null_;
                file print;
                put _all_;
                run;
                ods select all;
                ods startpage=no;

                %tableletter();
                ods excel options(sheet_interval="none" sheet_name = "Figure &forestfig.&TABLELETTER" tab_color="yellow");
                proc odstext pagebreak=yes;
                p "Figure &forestfig.&TABLELETTER.. Forest Plot of &ForestRatioTitle and 95% Confidence Intervals (CI) for &forest_title.&displayperiodid." /
                style=[fontfamily=arial font_size=8pt color=black just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
                p " ";
                run;

                %forestplot_template(plotheight=&plotheight, pointest=&Forestpointest, 
                                     lowerci=&Forestlowerci, upperci=&Forestupperci, 
                                     ci95=&Forestci95, cilabel=&forestratiolabel);

                proc sgrender data=forest template=forestAxisTable;
                dynamic _headerColor='cxd0d0d0';
                %if &forestfootnote = Y %then %do;
                format title $grpuni.;
                %end;
                run;

                %if "&forestnohrfootnote" = "Y" %then %do;
                    proc odstext pagebreak=yes;
                    p "^{super 1}&ForestRatioFoot could not be calculated for all analyses" / style=[fontfamily=arial font_size=7.5pt just=L];
                    run;
                %end;

                %if &forestfootnote=Y %then %do;
                %do fncount = 1 %to %eval(&number_forest_footnotes.);
                    %let fn = %scan(%bquote(&allfootnotes),&fncount,@);
                        %if "&forestnohrfootnote" = "Y" %then %let fncount1= %eval(&fncount.+1);
                        %else %let fncount1= &fncount;
                    proc odstext pagebreak=yes;
                    p "^{super &fncount1}&fn" / style=[fontfamily=arial font_size=7.5pt just=L];
                    run;
                %end;
                %end;

                /*Clean up*/
                proc datasets nowarn noprint lib=work;
                    delete forest: foot:;
                quit;

            %end; /*produce plot*/
            %plotleaveloop:
        %end; /*loop through plots*/
      %end; /*loop through looks*/
    %end; /*loop through runid */

%mend forestplot_driver;