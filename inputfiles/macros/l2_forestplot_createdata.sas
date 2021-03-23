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
      proc sql noprint;
        create table forest_l2_effectestimates_&periodid. as
        select a.*, b.runid, b.file, b.ipweight, b.strataweight, b.percentiles, b.ceiling, b.caliper, b.ratio, b.outputforestplot
        from l2_effectestimates_&periodid. a
        left join
        (select c.analysisgrp, c.file, c.ipweight, c.strataweight, c.percentiles, c.ceiling, c.caliper, c.ratio, d.runid, d.outputforestplot
          from pscs_masterinputs c
          inner join 
          l2comparisonfile d
          on c.analysisgrp = d.analysisgrp
          where d.outputforestplot = 'Y') as b
        on a.analysisgrp = b.analysisgrp
        where b.outputforestplot = 'Y';

        select distinct runid
        into :micohort_runid separated by ' '
        from forest_l2_effectestimates_&periodid.;
      quit;

      /* Stack all potential micohort files to join onto effect estimates table */
      %if &reporttype = T4L2 %then %do;
          data stack_micohort;
            length runid $5;
            set 
            %do n = 1 %to %sysfunc(countw(&micohort_runid));
              %let runid = %scan(&micohort_runid.,&n);
              %if %sysfunc(exist(infolder.&&&runid._micohortfile)) %then %do;
              infolder.&&&runid._micohortfile(in=&runid)
              %end;
            %end;
            ;
            %do n = 1 %to %sysfunc(countw(&micohort_runid));
              %let runid = %scan(&micohort_runid.,&n);
              if &runid then runid = "&runid";
            %end;
          run;
      %end;

      /* Link agegroupnum for T2/T4 */
      proc sql noprint undo_policy=none;
        create table forest_l2_effectestimates_&periodid. as
        select a.*, b.agegroupnum
        from forest_l2_effectestimates_&periodid. a
        %if &reporttype = T2L2 %then %do;
        left join agefmtsort b
        on a.medicalproduct = b.cohortgrp and a.runid = b.runid and a.subgroupcat = b.agegroup
        %end;
        %else %do;
        left join stack_micohort c
        on scan(a.medicalproduct,1,'_') = c.milgrp
        left join agefmtsort b 
        on b.cohortgrp = c.groupname and a.runid = b.runid and a.subgroupcat = b.agegroup
        %end;
        ;
      quit;

      /* Check to see if covariates file exists */
      %isdata(dataset=covarname);

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
                 est.agegroupnum,
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
                 est.agegroupnum,
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
          length title $200 label $&label_length;
          %if %eval(&nobs = 0) %then %do;
          label='';
          %end;
          /*Assign labels*/
          sort3 = 0;
          if id1 then do;
              id = 2;
              /*covarnum 0 = Overall - apply analysisgrp label*/
              if covarnum = 0 then do;
                  id = 1;
                  if missing(label) then title=analysisgrp;
                  else title=label;
                  sort3 = -2;
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
                  title = 'Monitoring Period';
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
                  sort3= -1;
              end;
              /*covarnum 1-999 = covariates*/
              else if covarnum >=1 and covarnum <=999 then do;
                  if subgroupcat = '0' then do;
                  title = catx(' ','No', covarlabel);
                  sort3=0;
                  end;
                  if subgroupcat = '1' then do;
                  title = covarlabel;
                  sort3=1;
                  end;
              end;
              /*covarnum 1000 = Sex*/
              else if covarnum = 1000 then do;
                  title = put(subgroupcat,$sexfmt.);
                  sort3 = put(subgroupcat,$sexsort.);
              end;
              /*covarnum 1012 = Race*/
              else if covarnum = 1012 then do;
                  title = put(subgroupcat,$racefmt.);
                  sort3 = put(subgroupcat,$racesort.);
              end;
              /*covarnum 1013 = Hispanic*/
              else if covarnum = 1013 then do;
                  title = put(subgroupcat,$hispanicfmt.);
                  sort3 = put(subgroupcat,$hispanicsort.);
              end;
              /*covarnum 1014 = Pre-Post Indicator*/
              else if covarnum = 1014 then do;
                  title = put(subgroupcat,$deliveryfmt.);
                  sort3 = put(subgroupcat,$deliverysort.);
              end;
              /*covarnum 2000 = Match Method*/
              else if covarnum = 2000 then do;
                  title = put(subgroupcat,$matchfmt.);
                  sort3 = put(subgroupcat,$matchsort.);            
              end;
              /*covarnum 2001 = Birth Type */
              else if covarnum = 2001 then do;
                  title = put(subgroupcat,$birthtypefmt.);
                  sort3 = put(subgroupcat,$birthtypesort.);
              end;
              /*covarnum 1001 = Age Groups*/
              else if covarnum = 1001 then do;
                  title = subgroupcat;
                  sort3 = agegroupnum;
              end;
              /*covarnum 1003 = Time*/
              else if covarnum = 1003 then do;
                  title = put(subgroupcat,$timefmt.);
                  sort3 = put(subgroupcat,$timesort.);
              end;
              /*covarnum 1002 = Year*/
              /*covarnum 9000 = By Data Partner*/
              else if covarnum in (1002, 9000) then do; 
                title = subgroupcat; 
                sort3=1;
              end;
          end;
      run;

      proc sort data = forest_&periodid. nodupkey;
        by analysisgrpsort analysis id covarnum sort3 subgroupcat sort1 sort2 runid;
      run;

      /* Merge in all analysis type input files and create footnotes, labels and sheet names */
      data forest_&periodid;
        length forest_title $100 footnote $200;
          set forest_&periodid;
            lag_title = lag(title);
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
          /* Set adjusted ORs if they have been requested */
          %if "&reporttype." = "T4L2" %then %do;
          if not missing(adjor) then do;
          or_95ci=adjor_95ci;
          or=adjor;
          lcl=adjor_LCL;
          ucl=adjor_UCL;
          end;
          %end;
          if lag_title = title then delete;
      run;

      proc sort data =forest_&periodid out=forest_&periodid(keep = title analysisgrp analysisgrpsort analysis footnote forest_title plotorder
                                                                                 %if "&reporttype." = "T2L2" %then %do;
                                                                                 HR_95ci HR  
                                                                                 %end;
                                                                                 %else %if "&reporttype." = "T4L2" %then %do;
                                                                                 or_95ci or
                                                                                 %end;
                                                                                 LCL UCL id file
                                                                                 );
      by analysisgrpsort analysis COVARNUM sort3 subgroupcat sort1 sort2;
      run;
      
      proc datasets nowarn noprint lib=work;
        delete id_: forest_l2_effectestimates_&periodid. stack_micohort;
      quit;

%mend l2_forestplot_createdata;