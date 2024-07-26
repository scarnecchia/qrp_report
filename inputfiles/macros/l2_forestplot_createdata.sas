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
*   - forest_[periodid][t4hoimethod].sas7bdat
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

      /*create set up for forestplot by t4hoimethod*/
      %let t4hoimethod = ;
      %do ru = 1 %to &numrunid.;
        %let runidru = %scan(&runidlist., &ru.);
	    %if not %sysfunc(findw(&&&runidru._t4hoimethod, &t4hoimethod)) %then %do;
	      %let t4hoimethod = &t4hoimethod. &&&runidru._t4hoimethod;
	    %end;
	  %end;
      
	  %if "&reporttype." = "T2L2" %then %do;
        %let t4hoimethod_current = ; 
		%let t4_loop = 1;
	  %end;
	  %else %do;
        %let t4_loop =  %sysfunc(countw(&t4hoimethod.));
      %end;
	  %do t4 = 1 %to &t4_loop;
	    %let t4hoimethod_current = %scan(&t4hoimethod., &t4);

      /* Join all data together to estimate table for processing downstream for forest dataset */
      proc sql noprint;
        create table forest_l2_effectestimates_&periodid. as
        select a.*, b.runid, b.t4hoimethod, b.file, b.ipweight, b.strataweight, b.percentiles, b.ceiling, b.caliper, b.ratio, b.outputforestplot
        from l2_effectestimates_&periodid. a
        left join
        (select c.analysisgrp, c.t4hoimethod, c.file, c.ipweight, c.strataweight, c.percentiles, c.ceiling, c.caliper, c.ratio, d.runid, d.outputforestplot
          from pscs_masterinputs (where = (missing(subgroup) and t4hoimethod = "&t4hoimethod_current")) c
          inner join 
          l2comparisonfile d 
          on c.analysisgrp = d.analysisgrp and c.runid = d.runid 
          where d.outputforestplot = 'Y') as b
        on a.analysisgrp = b.analysisgrp 
        where b.outputforestplot = 'Y'  ;

      quit;
	
       /* Check to see if covariates file exists - unlike tables need complete covar studyname here because macro variables
         do not resolve in sgrender */
      %isdata(dataset=covarname);

      /*dataset id_1 will be used to apply a label */
      /*dataset id_2 contains effect estimates*/
      /*both are restricted to sort2 =1, in order to deduplicate the file*/
      proc sql noprint;
          create table id_1 as 
          select distinct est.analysisgrp,
                 est.analysis, 
                 est.analysisgrpsort, 
                 est.subgroup,
                 est.subgroupcatorder, 
                 /*need to unformat agegroup so it can be formatted in the proc sgrender because of the possible unicode character*/
                 case when subgroup = 'agegroup' then est.subgroupcat
                    else est.subgroupcatlabel
                    end as subgroupcatlabel,
                 est.subgroupcat, 
                 est.subgrouporder,
                 est.tabletitle,
                 est.sort1, 
                 est.sort2,
                 est.runid,
                 est.file,
                 est.ipweight,
                 est.strataweight,
                 est.percentiles,
                 est.ceiling,
                 est.caliper,
                 est.ratio
                 %if &labelfileexists. = Y %then %do;
                 , lbl.label
                 %end;
                 %if %eval(&nobs.>0) %then %do;
                 , cov.studyname as covarlabel
                 %end;
                 %else %do;
                 , '' as covarlabel
                 %end;
          from forest_l2_effectestimates_&periodid. as est
          %if &labelfileexists. = Y %then %do;
          left join labelfile(where=(lowcase(labeltype)='grouplabel')) lbl on est.analysisgrp = lbl.group
          %end;
          %if %eval(&nobs.>0) %then %do;
              left join covarname as cov
              on est.subgroup = cov.cov_varname and est.runid = cov.runid
          %end;

          where sort2 = 1 and analysis ne "Unweighted"  
          order by analysisgrpsort, est.subgroup, subgroupcatorder, subgroupcat, sort1, sort2;


          create table id_2 as 
          select est.analysisgrp, 
                 est.analysis,
                 %if "&reporttype." = "T2L2" or ("&reporttype." = "T4L2" and %varexist(logitest, HR_95CI) = 1) %then %do;
                 est.HR_95ci,
                 est.HR, 
                 %end;
                 %else %if "&reporttype." = "T4L2" and &t4hoimethod_current. = binary %then %do;
                 est.rr_95ci, 
                 est.rr,                  
                 %end;
                 est.LCL,
                 est.UCL, 
                 est.analysisgrpsort, 
                 est.subgroup, 
                 est.subgroupcatorder, 
                 /*need to unformat agegroup so it can be formatted in the proc sgrender because of the possible unicode character*/
                 case when subgroup = 'agegroup' then est.subgroupcat
                    else est.subgroupcatlabel
                    end as subgroupcatlabel,
                 est.subgroupcat, 
                 est.subgrouporder,
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
              on est.subgroup = cov.cov_varname and est.runid = cov.runid
           %end;
           where sort2 = 1 and 
                 analysis ne "Unweighted" 
           order by analysisgrpsort, est.subgroup, subgroupcatorder, subgroupcat, sort1, sort2;
      quit;

      /*Variable ID used for indentation:
          1 = Analysis group label
          2 = overall results and subgroup label
          3 = subgroup categories*/

      data forest_&periodid.&t4hoimethod_current;
          set id_1(in=id1)
              id_2(in=id2);
          length title $200 label $&label_length;
          %if &labelfileexists. = N %then %do;
          label='';
          %end;
          /*Assign labels*/
          if id1 then do;
              id = 2;
              /*subgroup '' = Overall - apply analysisgrp label*/
              if subgroup = '' then do;
                  id = 1;
                  if missing(label) then title=analysisgrp;
                  else title=label;
              end;
              /*subgroup 1-999 = covariates*/
              else if index(subgroup,'covar')>0 then do;
                  title = covarlabel;
              end;
              else do;
                title = tabletitle;
              end;
          end;
          if id2 then do;
              id = 3;
              /*subgroup  = Overall*/
              if subgroup = '' then do;
                  id = 2;
                  title = "Overall";
              end;
              /*subgroup = covariates*/
              else if index(subgroup,'covar')>0 then do;
                  if subgroupcat = '0' then do;
                  title = catx(' ','No', covarlabel);
                  end;
                  if subgroupcat = '1' then do;
                  title = covarlabel;
                  end;
              end;
              else do;
                  title = subgroupcatlabel;
              end;
          end;
      run;

      proc sort data = forest_&periodid.&t4hoimethod_current nodupkey;
        by analysisgrpsort analysis id subgrouporder subgroupcatorder subgroupcat sort1 sort2 runid;
      run;

      /* Merge in all analysis type input files and create footnotes, labels and sheet names */
      data forest_&periodid.&t4hoimethod_current.;
        length forest_title $100 footnote $200;
          set forest_&periodid.&t4hoimethod_current.;
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
                  if not missing(percentiles) then footnote=cat('Weighted using Average Treatment Effect, (ATE);',' Percentiles: ',strip(put(percentiles,8.)));
                  else footnote="Weighted using Average Treatment Effect, (ATE)";
                end;
                else if upcase(strataweight) = 'ATT' then do;
                  if not missing(percentiles) then footnote=cat("Weighted using Average Treatment Effect in the Treated, (ATT);",' Percentiles: ',strip(put(percentiles,8.)));
                  else footnote="Weighted using Average Treatment Effect in the Treated, (ATT)";
                end;
              end;
              if missing(strataweight) then do;
              plotorder=4;
              forest_title='Propensity Score Stratified Analyses';
                if not missing(percentiles) then footnote=cat("Percentiles: ",strip(put(percentiles,8.)));
                else footnote='';
              end;
            end;
            if file = 'psmatchfile' then do;
              if ratio = 'V' then ratiolabel='Variable';
              if ratio = 'F' then ratiolabel="Fixed";
                if analysis="Unconditional" then do;
                plotorder=3;
                forest_title="Propensity Score Matched Unconditional Analyses";
                footnote=cat(strip(ratiolabel)," Ratio 1:",strip(put(ceiling,8.))," Propensity Score Matched ",strip(analysis)," Analysis;"," Caliper=",strip(put(caliper,8.2)));
                end;
                if analysis="Conditional" then do;
                plotorder=2;
                forest_title="Propensity Score Matched Conditional Analyses";
                footnote=cat(strip(ratiolabel)," Ratio 1:",strip(put(ceiling,8.))," Propensity Score Matched ",strip(analysis)," Analysis;"," Caliper=",strip(put(caliper,8.2)));
                end;
            end;
            if file = 'covstratfile' then do;
            plotorder=7;
            forest_title='Covariate Stratified Analyses';
            end;

            end;
          
          %if "&reporttype" = "T2L2" or ("&reporttype." = "T4L2" and &t4hoimethod_current. = timetoevent) %then %do;
          format HR LCL UCL 5.2; 
          %end;
          if lag_title = title then delete;
      run;

      proc sort data = forest_&periodid.&t4hoimethod_current. (keep = runid title analysisgrp analysisgrpsort analysis subgrouporder subgroup subgroupcatorder subgroupcat subgroupcatlabel footnote forest_title plotorder sort1 sort2
                                               %if "&reporttype." = "T2L2" or ("&reporttype." = "T4L2" and %varexist(logitest, HR_95CI) = 1) %then %do;
                                               HR_95ci HR  
                                               %end;
                                               %else %if "&reporttype." = "T4L2" and &t4hoimethod_current. = binary %then %do;
                                               rr_95ci rr
                                               %end;
                                               LCL UCL id file
                                               );
      by analysisgrpsort analysis subgrouporder subgroupcatorder sort1 sort2;
      run;
      
      proc datasets nowarn noprint lib=work;
        delete id_: forest_l2_effectestimates_&periodid. stack_micohort;
      quit;
      %end;

	%let reporttype = T4L2;
%mend l2_forestplot_createdata;
