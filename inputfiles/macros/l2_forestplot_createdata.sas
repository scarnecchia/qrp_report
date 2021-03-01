****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: l2_forestplot_createdata.sas  
* Created (mm/dd/yyyy): 02/23/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: Creates a dataset that can be fed into a proc template to produce a forest plot
*                                       
*  Program inputs:                                                                                   
*   - l2_effectestimates_&periodid.sas7bdat
* 
*  Program outputs:                                                                                                                                       
*   - forest_[periodid].sas7bdat
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

%macro l2_forestplot_createdata;

      /* Join all data together to estimate table for processing downstream for forest dataset */
      proc sql noprint undo_policy=none;
        create table forest_l2_effectestimates_&periodid. as
        select a.*, b.runid, b.file, b.ipweight, b.strataweight, b.percentiles, b.ceiling, b.caliper, b.ratio, b.outputforestplot
        from l2_effectestimates_&periodid. a
        left join
        (select c.analysisgrp, c.file, c.ipweight, c.strataweight, c.percentiles, c.ceiling, c.caliper, c.ratio, d.runid, d.outputforestplot
          from pscs_masterinputs c
          inner join 
          l2comparisonfile d
          on c.analysisgrp = d.analysisgrp
          where upper(d.outputforestplot) = 'Y') as b
        on a.analysisgrp = b.analysisgrp
        where upper(b.outputforestplot) = 'Y';
      quit;

      /*dataset id_1 will be used to apply a label */
      /*dataset id_2 contains effect estimates*/
      /*both are restricted to sort2 =1, in order to deduplicate the file*/
      proc sql noprint;
          create table id_1 as 
          select distinct est.analysisgrp,
                 est.analysis, 
                 est.analysisgrpsort, 
                 est.covarnum,
                 est.catnum, 
                 est.subgroupcat, 
                 est.sort1, 
                 est.sort2,
                 est.runid,
                 est.file,
                 est.ipweight,
                 est.strataweight,
                 est.percentiles,
                 est.ceiling,
                 est.caliper,
                 est.ratio,
                 %if %eval(&nobs.>0) %then %do;
                 cov.studyname as covarlabel
                 %end;
                 %else %do;
                 '' as covarlabel
                 %end;
          from forest_l2_effectestimates_&periodid. as est
          %if %eval(&nobs.>0) %then %do;
              left join covarname as cov
              on est.covarnum = cov.covarnum  and est.runid = cov.runid
          %end;
          where sort2 = 1 and 
                analysis ne "Unweighted" 
               order by analysisgrpsort, est.covarnum, catnum, subgroupcat, sort1, sort2;

          create table id_2 as 
          select est.analysisgrp, 
                 est.analysis,
                 %if "&reporttype." = "T2L2" %then %do;
                 est.HR_95ci,
                 est.HR, 
                 %end;
                 %else %if "&reporttype." = "T4L2" %then %do;
                 est.or_95ci, 
                 est.or, 
                 est.adjor_95ci, 
                 est.adjor, 
                 est.adjor_LCL, 
                 est.adjor_UCL,
                 %end;
                 est.LCL,
                 est.UCL, 
                 est.analysisgrpsort, 
                 est.covarnum, 
                 est.catnum, 
                 est.subgroupcat, 
                 est.sort1, 
                 est.sort2,
                 est.file,
                 est.runid,
                 est.ipweight,
                 est.strataweight,
                 est.percentiles,
                 est.ceiling,
                 est.caliper,
                 est.ratio,
                 %if %eval(&nobs.>0) %then %do;
                 cov.studyname as covarlabel
                 %end;
                 %else %do;
                 '' as covarlabel
                 %end;
           from forest_l2_effectestimates_&periodid. as est
           %if %eval(&nobs.>0) %then %do;
              left join covarname as cov
              on est.covarnum = cov.covarnum and est.runid = cov.runid
           %end;
           where sort2 = 1 and 
                 analysis ne "Unweighted" 
           order by analysisgrpsort, est.covarnum, catnum, subgroupcat, sort1, sort2;
      quit;

      %isdata(dataset=labelfile);

      %if %eval(&nobs>0) %then %do;
        proc sql noprint undo_policy=none;
          create table id_1 as
          select a.*, b.label, b.labeltype
          from id_1 a left join labelfile(where=(lowcase(labeltype)='grouplabel')) b
          on a.analysisgrp = b.group;
        quit;
      %end;

      /*Variable ID used for indentation:
          1 = Analysis group label
          2 = overall results and subgroup label
          3 = subgroup categories*/

      data forest_&periodid.;
          set id_1(in=id1)
              id_2(in=id2);
          length title $200;
          %if %eval(&nobs > 0) %then %do;
           length label $&label_length;
          %end;
          %else %do;
          label='';
          labeltype='grouplabel';
          %end;

          if missing(labeltype) then labeltype='grouplabel';
          /*Assign labels*/
          if id1 then do;
              id = 2;
              /*covarnum 0 = Overall - apply analysisgrp label*/
              if covarnum = 0 then do;
                  id = 1;
                  if missing(label) and labeltype='grouplabel' then title=analysisgrp;
                  else title=label;
              end;
              /*covarnum 1000 = Sex*/
              else if covarnum = 1000 then do;
                  title = 'Sex';
              end;
              /*covarnum 1-999 = covariates*/
              else if covarnum >=1 and covarnum <=999 then do;
                  title = covarlabel;
              end;
              /*covarnum 1001 = Age Group*/
              else if covarnum = 1001 then do;
                  title = 'Age Group';
              end;
              /*covarnum 1002 = Year*/
              else if covarnum = 1002 then do;
                  title = 'Year';
              end;
              /*covarnum 1003 = Time*/
              else if covarnum = 1003 then do;
                  title = 'Time';
              end;
              /*covarnum 1012 = Race*/
              else if covarnum = 1012 then do;
                  title = 'Race';
              end;
              /*covarnum 1013 = Hispanic*/
              else if covarnum = 1013 then do;
                  title = 'Hispanic Origin';
              end;
              /*covarnum 1014 = Pre-Post indicator*/
              else if covarnum = 1014 then do;
                  title = 'Delivery Status';
              end;
              /*covarnum 2000 = Match Method*/
              else if covarnum = 2000 then do;
                  title = 'Match Method';
              end;
              /*covarnum 2001 = Birth Type*/
              else if covarnum = 2001 then do;
                  title = 'Birth Type';
              end;
              /*covarnum 9000 = By Data Parnter*/
              else if covarnum = 9000 then do;
                  title = 'Data Partner';
              end;
          end;
          if id2 then do;
              id = 3;
              /*covarnum 0 = Overall*/
              if covarnum = 0 then do;
                  id = 2;
                  title = "Overall";
              end;
              /*covarnum 1-999 = covariates*/
              else if covarnum >=1 and covarnum <=999 then do;
                  if subgroupcat = '0' then title = catx(' ','No', covarlabel);
                  if subgroupcat = '1' then title = covarlabel;
              end;
              /*covarnum 1000 = Sex*/
              else if covarnum = 1000 then do;
                  if subgroupcat = 'M' then title = 'Male';
                  if subgroupcat = 'F' then title = 'Female';
              end;
              /*covarnum 1012 = Race*/
              else if covarnum = 1012 then do;
                  if subgroupcat = '0' then title = 'Unknown';
                  if subgroupcat = '1' then title = 'American Indian or Alaska Native';
                  if subgroupcat = '2' then title = 'Asian';
                  if subgroupcat = '3' then title = 'Black or African American';
                  if subgroupcat = '4' then title = 'Native Hawaiian or Other Pacific Islander';
                  if subgroupcat = '5' then title = 'White';
              end;
              /*covarnum 1013 = Hispanic*/
              else if covarnum = 1013 then do;
                  if subgroupcat = 'U' then title = 'Unknown';
                  if subgroupcat = 'Y' then title = 'Yes';
                  if subgroupcat = 'N' then title = 'No';
              end;
              /*covarnum 1014 = Pre-Post Indicator*/
              else if covarnum = 1014 then do;
                if subgroupcat = 'NONE' then title = 'Unknown Term';
                if subgroupcat = 'PRE' then title = 'Pre-Term';
                if subgroupcat = 'POST' then title = 'Post-Term';
                if subgroupcat = 'TERM' then title = 'Term';
              end;
              /*covarnum 2000 = Match Method*/
              else if covarnum = 2000 then do;
                if subgroupcat = 'BC' then title = 'Birth Certificate';
                if subgroupcat = 'RE' then title = 'Birth Registry';
                if subgroupcat = 'SI' then title = 'Health plan subscriber or family number';
                if subgroupcat = 'LA' then title = 'Exact or probabilistic last name and address match based upon health plan administrative data';
                if subgroupcat = 'OT' then title = 'Other';
                if subgroupcat = 'N1' then title = 'No subscriber/family IDs available for linkage';
                if subgroupcat = 'N2' then title = 'No name/address available for linkage';
                if subgroupcat = 'N3' then title = 'Neither subscriber/family IDs nor name/address available for linkage';
                if subgroupcat = 'NA' then title = 'No linkage made; any other reasons';
              end;
              /*covarnum 2001 = Birth Type */
              else if covarnum = 2001 then do;
                if subgroupcat = '0' then title = 'Unspecified # of live births';
                if subgroupcat = '1' then title = '1 live birth';
                if subgroupcat = '2' then title = '2 live births';
                if subgroupcat = '3' then title = '3 live births';
                if subgroupcat = '4' then title = '4 live births';
                if subgroupcat = '5' then title = '5 live births';
                if subgroupcat = '8' then title = 'Multiple live births, unspecified number';
                if subgroupcat = '9' then title = 'Conflicting code(s) for number of live births';
              end;
              /*covarnum 1001 = Age Groups*/
              /*covarnum 1002 = Year*/
              /*covarnum 1003 = Time*/
              /*covarnum 9000 = By Data Parnter*/
              else if covarnum in (1001, 1002, 1003, 9000) then do; 
                  title = subgroupcat; 
              end;
          end;
      run;

      proc sort data = forest_&periodid. nodupkey;
        by analysisgrpsort analysis id covarnum catnum subgroupcat sort1 sort2 runid;
      run;

      /* Need to delete extra rows for labels when multiple subgroups are created */
      data forest_&periodid.;
        set forest_&periodid;
        lag_title = lag(title);
        if lag_title = title then delete;
      run;

      /* Merge in all analysis type input files and create footnotes, labels and sheet names */
      data forest_&periodid;
        length forest_title $100 footnote $200;
          set forest_&periodid;
            if analysis = "Unadjusted" then do;
            plotorder=1;
            forest_title="Site-Adjusted Analyses";
            footnote='';
            end;
            else do;
            if file = 'iptwfile' then do;
            plotorder=6;
            forest_title="Inverse Probability of Treatment Weighted Analyses";
              if upcase(ipweight) = 'ATE' then footnote="Weighted using Average Treatment Effect, (ATE)";
              else if upcase(ipweight) = 'ATT' then footnote="Weighted using Average Treatment Effect in the Treated, (ATT)";
              else if upcase(ipweight) = 'ATES' then footnote="Weighted using Average Treatment Effect, Stabilized, (ATES)";
            end;
            if file = 'stratificationfile' then do;
              if not missing(strataweight) then do;
              plotorder=5;
              forest_title='Propensity Score Stratum Weighted Analyses';
                if upcase(strataweight) = 'ATE' then do;
                  if not missing(percentiles) then footnote=cat('Weighted using Average Treatment Effect, (ATE);',' Percentiles: ',strip(percentiles));
                  else footnote="Weighted using Average Treatment Effect, (ATE)";
                end;
                else if upcase(strataweight) = 'ATT' then do;
                  if not missing(percentiles) then footnote=cat("Weighted using Average Treatment Effect in the Treated, (ATT);",' Percentiles: ',strip(percentiles));
                  else footnote="Weighted using Average Treatment Effect in the Treated, (ATT)";
                end;
              end;
              if missing(strataweight) then do;
              plotorder=4;
              forest_title='Propensity Score Stratified Analyses';
                if not missing(percentiles) then footnote=cat("Percentiles: ",strip(percentiles));
                else footnote='';
              end;
            end;
            if file = 'psmatchfile' then do;
              if ratio = 'V' then ratiolabel='Variable';
              if ratio = 'F' then ratiolabel="Fixed";
                if analysis="Unconditional" then do;
                plotorder=3;
                forest_title="Propensity Score Matched Unconditional Analyses";
                footnote=cat(strip(ratiolabel)," Ratio 1:",strip(ceiling)," Propensity Score Matched ",strip(analysis)," Analysis;"," Caliper=",strip(caliper));
                end;
                if analysis="Conditional" then do;
                plotorder=2;
                forest_title="Propensity Score Matched Conditional Analyses";
                footnote=cat(strip(ratiolabel)," Ratio 1:",strip(ceiling)," Propensity Score Matched ",strip(analysis)," Analysis;"," Caliper=",strip(caliper));
                end;
            end;
            if file = 'covstratfile' then do;
            plotorder=7;
            forest_title='Covariate Stratified Analyses';
            end;

            end;
      run;

      proc sort data =forest_&periodid out=forest_&periodid(keep = title analysisgrp analysisgrpsort analysis footnote forest_title plotorder
                                                                                 %if "&reporttype." = "T2L2" %then %do;
                                                                                 HR_95ci HR  
                                                                                 %end;
                                                                                 %else %if "&reporttype." = "T4L2" %then %do;
                                                                                 or_95ci or adjor_95ci adjor adjor_LCL adjor_UCL
                                                                                 %end;
                                                                                 LCL UCL id file
                                                                                 );
      by analysisgrpsort analysis COVARNUM catnum subgroupcat sort1 sort2;
      run;

      proc datasets nowarn noprint lib=work;
        delete id_:;
      quit;

%mend l2_forestplot_createdata;
