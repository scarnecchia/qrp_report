****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_tableofcontents.sas  
* Created (mm/dd/yyyy): 02/09/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro createas a dataset with 1 row per table and figure that is used as the 
*          report table of contents
*                                        
*  Program inputs:                                                                                   
*
*  Program outputs:          
*   -tableofcontents: dataset containing table of contents 
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

%macro create_tableofcontents();
    %put =====> MACRO CALLED: create_tableofcontents;

    /*********************************************************************************************/
    /* Utility macro to add row to tableofcontents file                                          */
    /*********************************************************************************************/
    %macro addtotoc(tabnum=, caption=, appendixtype=);
    data tableofcontents;
        set tableofcontents end=eof;
        output;
        if eof then do;
            tabnum = "&tabnum.";
            caption = "&caption.";
			appendixtype = "&appendixtype.";
            output;
        end;
    run;
    %mend;

    /*********************************************************************************************/
    /* Initialize empty table and table number                                                   */
    /*********************************************************************************************/
    data tableofcontents;
        length tabnum $25 caption $500 appendixtype $30;
        call missing(tabnum, caption, appendixtype);
    run;

    %let number = 1;
    %let tablenum = 1;

    /*********************************************************************************************/
    /* Build table of contents                                                                   */
    /*********************************************************************************************/

    /*********************************************************************************************/
    /* Glossary rows */
    /*********************************************************************************************/
    %addtotoc(tabnum=Glossary (CIDA), caption=List of Terms to Define Cohort Identification and Descriptive Analysis (CIDA) Found in this Report);
	%if %str("&reporttype") = %str("T2L2") | %str("&reporttype") = %str("T4L2") %then %do;
	  %addtotoc(tabnum=Glossary (PSA), caption=List of Terms to Define Propensity Score Analysis (PSA) Found in this Report);				 
    %end;

    /*********************************************************************************************/
    /* Baseline Table                                                                            */
    /*********************************************************************************************/

    %if %eval(&numbaselinetablegrp.>0) %then %do;

        /*counter for determining table letter*/
        %let tablecount = 1;

        /* counter for determining table number */
        %let tablenum = 2;

        /*loop through each baseline table*/
        %do b = 1 %to &numbaselinetablegrp.;
            %let analysisgrp = ;
            %let analysisgrp2 = ;
            %let baselinegroupnum = ;
            %let pregnancylabel = ;
            %let includenonpregnant = N;

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

            data _null_;
                set baselinefile(where=(order=&b.));
                if _n_ = 1 then do;
                    call symputx('analysisgrp', analysisgrp);
                    call symputx('runid', runid);
                    call symputx('cohort', cohort);
                    call symputx('unique_psestimate',unique_psestimate);
                    %if %sysfunc(prxmatch(m/T4L1/i,&reporttype.)) > 0 %then %do;
                    if cohort in ('preg', 'nopreg') then do;
                        if upcase(includenonpregnant) = 'Y' then call symput('pregnancylabel', ' Pregnancy Cohort and Non-Pregnancy Cohort');
                        else call symput('pregnancylabel', ' Pregnancy Cohort');
                    end;
                    call symputx('includenonpregnant', upcase(includenonpregnant));
                    %end;
                    if missing(baselinegroupnum)=0 then call symputx('baselinegroupnum', baselinegroupnum);
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
            %end;

            /*determine if only 1 baseline table and set &tablecount to 0. Will occur if all the following are true:
            - 1 monitoring period
            - DP stratification = N
            - max(order) in baselinefile = 1
            - if reporttype = T2L2, T4L2- then analysis must be covariate stratification*/
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

            %isdata(dataset=labelfile);
            %if %eval(&nobs.>0) %then %do;
                data _null_;
                    set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid"))
                        %if %length(&baselinegroupnum.)>0 %then %do;
                        labelfile(in=b where=(group="&analysisgrp2" and runid = "&runid"))
                        %end; 
                        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                        labelfile(in=c where=(group="&psestimategrp" and runid = "&runid"))
                        %end; ;
                    if a then do;
                        if labeltype = 'grouplabel' then call symputx('grouplabel',label);
                        if labeltype = 'baselinelabel' then call symputx('baselinelabel',cat(', ',strip(label), ','));
                    end;
                    %if %length(&baselinegroupnum.)>0 %then %do;
                    if b then do;
                        if labeltype = 'grouplabel' then call symputx('grouplabel2',label);
                    end;
                    %end;
                    %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 & &psfile. ne covstratfile %then %do;
                    if c then do;
                        if labeltype = 'grouplabel' then call symputx('psestimatelabel',label);
                    end;
                    %end;
                run;
            %end;

            %let captionlabel = %bquote(&grouplabel.&pregnancylabel&baselinelabel.);
            %if %length(&baselinegroupnum.)>0 %then %do;
            %let captionlabel = %bquote(&grouplabel.&pregnancylabel and &grouplabel2.&pregnancylabel&baselinelabel.);
            %end;
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) >0 & &psfile. ne covstratfile %then %do;
            %let captionlabel = %bquote(&psestimatelabel.);
            %end;         

            /*1 block of code for both aggregate and DP tables*/
            %macro baselinetoc(table);
                %if %eval(&unique_psestimate.) = 1 %then %do;
                 %tableletter(); 
                 %addtotoc(tabnum=Table 1&tableletter., 
                 caption=%quote(&unadjusted.Characteristics of &captionlabel. (&table.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                %end;

                /*For L2 tables - up to 2 additional adjusted tables*/
                %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
                    /*PS Match Adjusted*/
                    %if &psfile. = psmatchfile %then %do;
                    %tableletter(); 
                    %addtotoc(tabnum=Table 1&tableletter., 
                    caption=%quote(Adjusted Characteristics of &grouplabel. (Propensity Score Matched, &table.), &ratiolabel.&caliperlabel., in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;

                    /*Unweighted - IPTW and PS Stratum*/
                    %if (&psfile. = iptwfile & %eval(&unique_psestimate.) = 1) | (&psfile. = stratificationfile & ("&weightscheme." = "ATE" | "&weightscheme." = "ATT") & %eval(&pstrim.>=0)) %then %do;
                    %tableletter(); 
                    %addtotoc(tabnum=Table 1&tableletter., 
                     caption=%quote(Unweighted Characteristics of &grouplabel. (Unweighted, Trimmed, &table.) in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;

                    /*Weighted - IPTW, PS Stratum, PS Stratification*/
                    %if &psfile. = iptwfile | &psfile. = stratificationfile %then %do;
                        %if &psfile. = iptwfile %then %let stratumtitle = (Inverse Probability of Treatment Weighted, Trimmed, &table.), Weight: &weightlabel., Truncation: &truncationlabel.;
                        %else %if "&weightscheme." = "ATE" | "&weightscheme." = "ATT" %then %let stratumtitle = (Propensity Score Stratum Weighted, Trimmed, &table.), Percentiles: &percentiles., Weight: &weightlabel.;
                        %else %let stratumtitle =(Propensity Score Stratified, &table.), Percentiles: &percentiles.;
                        %tableletter(); 
                        %addtotoc(tabnum=Table 1&tableletter., 
                        caption=%quote(Weighted Characteristics of &grouplabel. &stratumtitle., in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));
                    %end;
                %end; /*Additional L2 tables*/
            %mend;

            /*loop through each periodid*/
            %do periodid = %eval(&look_start.) %to %eval(&look_end.);
                /*Aggregated*/
                %baselinetoc(Aggregated);
       
                /*Output seperate table for each Data Partner - loop through each DP*/
                %if &stratifybydp. = Y %then %do;    
                    %do dps = 1 %to %eval(&num_dp.);
        		        %let maskedID = %scan(&masked_dplist,&dps); 
                        %baselinetoc(&maskedid.);
                    %end;
                %end; /*DP stratification*/
            %end; /*loop through each periodid*/
        %end; /*loop through each row in baselinefile*/
    %end; /*include baseline tables in toc*/

    /*********************************************************************************************/
    /* Covariate Profile Table                                                                   */
    /*********************************************************************************************/
    %if &numprofilecovarstoinclude > 0 %then %do;

    /* reset counter to reset table letter */
    %let tablecount = 1;

    %do periodid = %eval(&look_start.) %to %eval(&look_end.);

    proc sql noprint ;
        select 'order='||strip(put(order,8.))||' and runid='||quote(strip(runid))||' and group='||quote(strip(group))||' and cohort='||quote(strip(cohort))
        into :whereexpr separated by '@'
        from (select order, runid, group, case when(cohort is missing) then 'all' else cohort end as cohort
              from baselinefile
              where not missing(profilecovarstoinclude))
        order by order;
    quit;

    %do wherenum = 1 %to %sysfunc(countw(&whereexpr, @));
        %let where = %scan(&whereexpr,&wherenum, @);

            data _temp_agg_order_profile;
                set aggregate_profile(where=(periodid=&periodid and &where));
                grouplabel='';
                if cohort = 'mi' then group2=scan(group,1,'_');
                else group2=group;

                if cohort = 'switch' then switchlabel = ' ';
                call symputx('runid',runid);
            run;

            %let profileswitches = 0;
            %if &reporttype = T6 %then %do;
            proc sql noprint;
            select max(switchstep) into :profileswitches
            from _temp_agg_order_profile;
            quit;
            %end;

            %isdata(dataset=_temp_agg_order_profile);
            %if &nobs > 0 %then %do;

            %do s = 0 %to &profileswitches;

            %if &reporttype = T6 %then %do;
            data _temp_agg_profile;
                set _temp_agg_order_profile (where=(switchstep = &s));
            run;

            /* Join treatment file onto profile table to obtain product group */
            proc sql noprint undo_policy=none;
                create table _temp_agg_profile as
                select a.*, b.group as productswitchgroup
                from _temp_agg_profile a 
                inner join infolder.&&&runid._treatmentpathways b
                on a.group = b.analysisgrp and a.switchstep = b.switchevalstep;
            quit;
            %end;
            %else %do;
            proc datasets lib=work nolist;
                change _temp_agg_order_profile = _temp_agg_profile;
            run;
            %end;

            /* Check for existence of label file and join to profile dataset. Set grouplabel to missing if no labelfile */
            %isdata(dataset=labelfile);
            %if &nobs > 0 %then %do;
            proc sql noprint undo_policy=none;
                create table _temp_agg_profile as
                select a.group, a.runid, a.order, a.periodid, b.label as grouplabel
                %if %index(&where,%str(cohort="mi")) %then %do;
                ,c.label as grouplabel2, a.group2
                %end;
                %if %index(&where,%str(cohort="switch")) %then %do;
                ,d.label as switchlabel, a.productswitchgroup
                %end;
                from _temp_agg_profile(drop=grouplabel %if &reporttype = T6 %then %do; switchlabel %end;) a 
                left join labelfile(where=(lowcase(labeltype)='grouplabel')) b
                on a.group = b.group and a.runid = b.runid
                %if %index(&where,%str(cohort="mi")) %then %do;
                left join labelfile(where=(lowcase(labeltype)='grouplabel')) c
                on a.group2 = c.group and a.runid = c.runid
                %end;
                %if %index(&where,%str(cohort="switch")) %then %do;
                left join labelfile(where=(lowcase(labeltype)='grouplabel')) d
                on a.productswitchgroup = d.group and a.runid = d.runid
                %end;
                ;
            quit;
            %end;
            %else %do;
            data  _temp_agg_profile;
            set _temp_agg_profile;
            grouplabel2='';
            switchlabel='';
            run;
            %end;
                
            data _null_;
                set _temp_agg_profile(keep=group grouplabel order
                                       %if %index(&where,%str(cohort="mi")) %then %do;
                                       group2 grouplabel2
                                       %end;
                                       %if %index(&where,%str(cohort="switch")) %then %do;
                                       productswitchgroup switchlabel
                                       %end;
                                        );
                if _n_ = 1;
                if not missing(grouplabel) then call symputx('grouplabel',grouplabel);
                else call symputx('grouplabel',group);

                %if %index(&where,%str(cohort="nopreg")) %then %do;
                if not missing(grouplabel) then call symputx('grouplabel',catx(' ',grouplabel,'Non-Pregnancy'));
                else call symputx('grouplabel',catx(' ',group,'Non-Pregnancy'));
                %end;

                %else %if %index(&where,%str(cohort="preg")) %then %do;
                if not missing(grouplabel) then call symputx('grouplabel',catx(' ',grouplabel,'Pregnancy'));
                else call symputx('grouplabel',catx(' ',group,'Pregnancy'));
                %end;

                %else %if %index(&where,%str(cohort="mi")) %then %do;
                if not missing(grouplabel) then do;
                if not missing(grouplabel2) then call symputx('grouplabel',grouplabel2);
                else call symputx('grouplabel',group2);
                end;
                else do;
                call symputx('grouplabel',group2);
                end;
                %end;

                %else %if &reporttype = T6 %then %do;

                %if &s = 0 %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',grouplabel);
                end;
                else do;
                call symputx('grouplabel',group);
                end;
                %end;

                %else %if &s = 1 %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',grouplabel);
                end;
                else do;
                call symputx('grouplabel',group);
                end;
                %end;

                %else %if &s = 2 %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',grouplabel);
                end;
                else do;
                call symputx('grouplabel',group);
                end;
                %end;

                %end;
            run;

             %tableletter();
             %if &numprofilecovarstoinclude = 1 and &reporttype ^= T6 %then %let tableletter =;
             %else %if &numprofilecovarstoinclude = 1 and &profileswitches = 0 and &reporttype = T6 %then %let tableletter =;
             %addtotoc(tabnum=Table &tablenum.&tableletter.,
             caption=%quote(Characteristic Profile of &grouplabel in the &database. from &startdateformatted. to &&enddate&periodid.formatted.));

             %end; /* _temp_agg_order_profile */
        %end; /* switch loop */

        proc datasets library=work nowarn noprint;
        delete _temp_agg_profile _temp_agg_order_profile;
        quit;

    %end; /* where loop */

    %end; /* periodid loop */
	
    %let tablenum = %eval(&tablenum + 1);
    %end; /* &numprofilecovarstoinclude > 0 */

    /*********************************************************************************************/
    /* Effect estimate table                                                                     */
    /*********************************************************************************************/

    %if &numl2comparisons > 0 %then %do; 

        /*loop through each baseline table*/
        %do c = 1 %to &numl2comparisons;

        /* reset counter to reset table letter */
        %let tablecount = 1;

            data _null_;
                set l2comparisonfile(where=(order=&c.));
                call symputx('analysisgrp', analysisgrp);
                call symputx('runid', runid);
            run;

            /* Merge in group labels if they exist */
            %let grouplabel = &analysisgrp;
            %isdata(dataset=labelfile);
            %if %eval(&nobs>0) %then %do;
            data _null_;
                set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid")) ;
                if labeltype = 'grouplabel' then call symputx('grouplabel',label);
            run;
            %end;

            /* Store covarnums to determine covar labels */
            proc sql noprint;
                select distinct covarnum
                into :covarlist
                separated by ' '
                from l2_effectestimates_&look_end.
                where analysisgrp="&analysisgrp.";
            quit;

            %if &covarlist = 0 %then %let tablecount = 0;

            /* loop covarnums and assign subgroup label */
            %do covarcount = 1 %to %sysfunc(countw(&covarlist));
                %let covarnum = %scan(&covarlist,&covarcount);

                %if &covarnum = 0 %then %do;
                %let titleend = %str();
                %end;

                %else %if &covarnum = 9000 %then %do; 
                %let titleend = %str(and Data Partner);
                %end;

                %else %do;
                %if &covarnum < 1000 %then %do;
                proc sql noprint;
                select distinct strip(studyname) into: subgrouplabel
                from infolder.&&&runid._covariatecodes
                where covarnum = &covarnum.;
                quit;
                %end;

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
                %tableletter();
                %addtotoc(tabnum=Table &tablenum.&tableletter.,
                caption=%quote(Effect Estimates for &grouplabel. in the &database. from &startdateformatted. to &&enddate&look_end.formatted., by Analysis Type &titleend.));
            %end; /* covarcount */
            %let tablenum = %eval(&tablenum + 1);
         %end; /* numl2comparison do loop */
    %end; /* numl2comparison */

 
    /*********************************************************************************************/
    /* Type 5 summary tables                                                                     */
    /*********************************************************************************************/
	%if %str("&reporttype") = %str("T5") %then %do;

        /*****************************************************************************************/
        /* Type 5 Tables T1-T13                                                                  */
        /*****************************************************************************************/

        /*Example order of tables:
          2a: Categorical - overall
          2b: Continuous - all
          2c: Categorical - by age group
          2d: Continuous - by age group */
 
        %macro t5toc(cattableid=, disttableid=, cattitle=, disttitle=);

            /*if both categorical and continuous tables specified, then need to ascertain master order between both tables*/
            %if %str("&cattableid.") ne %str("") & %str("&disttableid.") ne %str("") %then %do;
                /*Because a user can select different stratifications for each table need to ascertain a master order from tablefile regardless of whether includeinreport = Y*/
                /*if user excludes includeinreport = N from file, order may not match SOC standard order of operations */
                proc sort data=input.&tablefile.(keep=table tablesub where=(table in ("&cattableid","&disttableid"))) out=_temptablefile;
                    by table;
                run;
				
                data _temptablefile;
                    set _temptablefile;
                    by table;
                    length order 3;
                    if first.table then order = 1;
                    else order = order+1;
                    retain order;
                run;

                proc sort data=_temptablefile nodupkey;
                    by tablesub;
                run;
				
                proc sort data=tablefile(keep=table tablesub stratificationorder tabletitle) out=_temptablefile1;
                    by tablesub; 
                run;

                *create dataset that maps categorical and continuous tables;
                data _tempmap;
                    merge _temptablefile
                          _temptablefile1(rename=table=cattable rename=stratificationorder=catstratificationorder where=(cattable="&cattableid"))
                          _temptablefile1(rename=table=disttable rename=stratificationorder=diststratificationorder where=(disttable="&disttableid"));
                    by tablesub;
                    if missing(catstratificationorder) &  missing(diststratificationorder) then delete;
                run;

                proc sort data=_tempmap;
                    by order ;
                run;
            %end;
            %else %do;
                data _tempmap;
                    set tablefile(keep=table tablesub stratificationorder tabletitle 
                                  where=(table in (%if %str("&cattableid.") ne %str("") %then %do; "&cattableid" %end;
                                                   %if %str("&disttableid.") ne %str("") %then %do; "&disttableid" %end;)));
                run;
            %end;

            /*Loop through each tablesub, determine whether to output categorical and/or continuous table*/
            %isdata(dataset=_tempmap);
            %let t5tableobs = &nobs.;
            %let tablecount=1;
            %do i = 1 %to %eval(&t5tableobs.);

                %let cattablestratorder = 0;
                %let disttablestratorder = 0;

                data _null_;
                    set _tempmap;
                    if _n_ = &i. then do;
                        if tablesub = 'overall' and "&stratifybydp." = "Y" then call symputx('tabletitle', ', by Data Partner');
                        else call symputx('tabletitle', tabletitle);
                        /*Both requested - determine whether to print both tables*/
                        %if %str("&cattableid.") ne %str("") & %str("&disttableid.") ne %str("") %then %do;
                            if missing(cattable) | missing(disttable) then call symputx('numtables', 1);
                            else call symputx('numtables', 2);

                            if missing(cattable)=0 then call symputx('cattablestratorder', catstratificationorder);
                            if missing(disttable)=0 then call symputx('disttablestratorder', diststratificationorder);
                        %end;
                        %else %do;
                            call symputx('numtables', 1);
                            /*determine which table*/
                            if table = "&cattableid" then call symputx('cattablestratorder', stratificationorder);
                            if table = "&disttableid" then call symputx('disttablestratorder', stratificationorder);
                        %end;
                    end;
                run;

                /*reset table letter counter if only 1 table*/
                %if %eval(&t5tableobs.=1) & %eval(&numtables.=1) %then %let tablecount=0;

                %if %eval(&cattablestratorder.>0) %then %do;
                %tableletter();
                %addtotoc(tabnum=Table &tablenum.&tableletter.,
                caption=%bquote(&cattitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.));
                %end;
                %if %eval(&disttablestratorder.>0) %then %do;
                %tableletter();
                %addtotoc(tabnum=Table &tablenum.&tableletter.,
                caption=%bquote(&disttitle. for &reporttitle. in the &database. from &startdateformatted. to &enddateformatted.&tabletitle.));
                %end;
            %end;

			
            /*Save the table of contents datasets for use during the Type 5 report output process*/
			%isdata(dataset=t5_tempmap);
			%if %eval(&nobs.>0) %then %do;
				data t5_tempmap;
				 set t5_tempmap _tempmap (in=a);
				  %if %varexist(_tempmap,stratificationorder) = 1 %then %do;
					  if a and stratificationorder ne . then do;
						 %if %str("&cattableid.") ne %str("") %then %do;
							 cattable="&cattableid";
							 catstratificationorder = stratificationorder;
						 %end;
						 %else %if %str("&disttableid.") ne %str("") %then %do;
							 disttable="&disttableid";
							 diststratificationorder = stratificationorder;
						 %end;
					  end;
				  %end;
				run; 
			%end;
			%else %do;
				/*dummy t5_tempmap file*/
				data t5_tempmap;
				 set _tempmap;
				  %if %varexist(_tempmap,stratificationorder) = 1 %then %do;
					  if stratificationorder ne . then do;
						 %if %str("&cattableid.") ne %str("") %then %do;
							 length cattable $3;
							 cattable="&cattableid";
							 catstratificationorder = stratificationorder;
						 %end;
						 %else %if %str("&disttableid.") ne %str("") %then %do;
							 length disttable $3;
							 disttable="&disttableid";
							 diststratificationorder = stratificationorder;
						 %end;
					  end;
				  %end;
				run; 
			%end;
			
            proc datasets nowarn noprint lib=work;
                delete _temp:;
            quit;

            %let tablenum = %eval(&tablenum+1);
        %mend;

        /*T1/T2 - Days Supplied per Dispensing*/
	    %if %sysfunc(prxmatch(m/T1\b|T2\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=%if %sysfunc(prxmatch(m/T1\b/i,&tablelist.)) > 0 %then %do; T1 %end;,
               disttableid=%if %sysfunc(prxmatch(m/T2\b/i,&tablelist.)) > 0 %then %do; T2 %end;,
               cattitle=Categorical Summary of Days Supplied per Dispensing,
               disttitle=Continuous Summary of Days Supplied per Dispensing); 
        %end;

        /*T3/T4 - Cumulative episode duration*/
    	%if %sysfunc(prxmatch(m/T3\b|T4\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=%if %sysfunc(prxmatch(m/T3\b/i,&tablelist.)) > 0 %then %do; T3 %end;,
               disttableid=%if %sysfunc(prxmatch(m/T4\b/i,&tablelist.)) > 0 %then %do; T4 %end;,
               cattitle=Categorical Summary of Patients%str(%') Cumulative Exposure Duration,
               disttitle=Continuous Summary of Patients%str(%') Cumulative Exposure Duration); 
    	%end;

    	/*T5/T6 - Episode duration - all episodes*/
        %if %sysfunc(prxmatch(m/T5\b|T6\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=%if %sysfunc(prxmatch(m/T5\b/i,&tablelist.)) > 0 %then %do; T5 %end;,
               disttableid=%if %sysfunc(prxmatch(m/T6\b/i,&tablelist.)) > 0 %then %do; T6 %end;,
               cattitle=Categorical Summary of All Treatment Episodes,
               disttitle=Continuous Summary of All Treatment Episodes); 
    	%end; 

    	/*T7/T8 - Episode duration - first episode*/
    	%if %sysfunc(prxmatch(m/T7\b|T8\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=%if %sysfunc(prxmatch(m/T7\b/i,&tablelist.)) > 0 %then %do; T7 %end;,
               disttableid=%if %sysfunc(prxmatch(m/T8\b/i,&tablelist.)) > 0 %then %do; T8 %end;,
               cattitle=Categorical Summary of First Treatment Episodes,
               disttitle=Continuous Summary of First Treatment Episodes); 
    	%end;

    	/*T9/T10 - Episode duration - second and subsequent episodes*/
    	%if %sysfunc(prxmatch(m/T9\b|T10\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=%if %sysfunc(prxmatch(m/T9\b/i,&tablelist.)) > 0 %then %do; T9 %end;,
               disttableid=%if %sysfunc(prxmatch(m/T10\b/i,&tablelist.)) > 0 %then %do; T10 %end;,
               cattitle=Categorical Summary of Second and Subsequent Treatment Episodes,
               disttitle=Continuous Summary of Second and Subsequent Treatment Episodes); 
    	%end;

    	/*T11 - All episode gaps*/
        %if %sysfunc(prxmatch(m/T11\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=,
               disttableid=T11,
               cattitle=,
               disttitle=Continuous Summary of All Treatment Episode Gaps); 
    	%end;
    	/*T12 - First episode gap*/
        %if %sysfunc(prxmatch(m/T12\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=,
               disttableid=T12,
               cattitle=,
               disttitle=Continuous Summary of First Treatment Episode Gaps); 
    	%end;
    	/*T13 - Second and subequent episode gaps*/
        %if %sysfunc(prxmatch(m/T13\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=,
               disttableid=T13,
               cattitle=,
               disttitle=Continuous Summary of Second and Subsequent Treatment Episode Gaps); 
    	%end;

        /*****************************************************************************************/
        /* Type 5 censor tables (T14-T17)                                                        */
        /*****************************************************************************************/
        


        /*****************************************************************************************/
        /* Type 5 Dose Tables T18-T22                                                            */
        /*****************************************************************************************/
        %if %sysfunc(prxmatch(m/T18\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=T18,
               disttableid=,
               cattitle=Summary of Filled Daily Dose in Each Dispensing,
               disttitle=); 
    	%end;
        %if %sysfunc(prxmatch(m/T19\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=T19,
               disttableid=,
               cattitle=Summary of Average Filled Daily Dose in Each Treatment Episode,
               disttitle=); 
    	%end;
        %if %sysfunc(prxmatch(m/T20\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=T20,
               disttableid=,
               cattitle=Summary of Average Filled Daily Dose in Each Patient%str(%')s First Valid Episode,
               disttitle=); 
    	%end;
        %if %sysfunc(prxmatch(m/T21\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=T21,
               disttableid=,
               cattitle=Summary of Cumulative Filled Dose in All Treatment Episodes,
               disttitle=); 
    	%end;
        %if %sysfunc(prxmatch(m/T22\b/i,&tablelist.)) > 0 %then %do;
        %t5toc(cattableid=T22,
               disttableid=,
               cattitle=Summary of Cumulative Filled Dose in Each Patient%str(%')s First Treatment Episode,
               disttitle=); 
    	%end;
		
		
        /*Additional variables for ordering Type 5 table report output*/			
		data t5_tempmap;
		 set t5_tempmap;
		 length t5order 3;
		 t5order=_n_;
		run; 
			
		proc sort data = t5_tempmap;
		by table t5order;
		run;
		
		data t5_tempmap;
		 set t5_tempmap;
		 by table;
		 length numtables tableorder 3;
		 if first.table and last.table
			%if %varexist(t5_tempmap,cattable) = 1 & %varexist(t5_tempmap,disttable) = 1 %then %do; and (cattable = '' or disttable = '') %end;
		  then numtables=1;
		 else numtables=2;
		 retain tableorder;
		 if first.table then tableorder=0;
		 tableorder+1;
		run; 
			
		proc sort data = t5_tempmap;
		by t5order table;
		run;
			
    %end; /*type 5 tables*/
     
    /*********************************************************************************************/
    /*   Code Distribution Tables                                                                */
    /*********************************************************************************************/ 
    %if &output_code_distribution. eq Y %then %do;

    /* This macros output a specific distribution type (EXP or HOI) entries in the table of content */
	%macro codedistribution_type_toc(distindextype=);
        /* Compute group label to display in title */
		%let grouplabel=;
		%isdata(dataset=labelfile);
    	%if %eval(&nobs>0) %then %do;
			proc sql noprint;
			select label into :grouplabel trimmed from labelfile
			where lower(group)="&group." and runid = "&runid" and
			%if &distindextype. eq exp %then %do;
				lower(labeltype)="grouplabel";
			%end;
			%else %do;
				lower(labeltype)="outcomelabel";
			%end;
			quit;
		%end;

		%if %str("&grouplabel.") eq %str("") %then %let grouplabel = %trim(&group.);

		/* Full Code Distribution Table */
		%tableletter();
		%addtotoc(tabnum=Table &tablenum.&tableletter.,
                  caption=%quote(Full Code Distribution of &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.));

		/* Total Code Counts Table */
		%tableletter();
		%addtotoc(tabnum=Table &tablenum.&tableletter.,
                  caption=%quote(Total Code Counts of &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.));
	%mend codedistribution_type_toc; 

	/* reset counter to reset table letter */
	%let tablecount=1;
    
	proc sql noprint;
	select count(*) into :numgroupscodedist trimmed 
	from GroupsDist;
	quit;
	
    %do loopcount = 1 %to &numgroupscodedist.; 

		%let codedistexp = N;
		%let codedisthoi = N;

        data _null_;
            set GroupsDist;
			if &loopcount. = _N_;
            call symputx('runid', runid);
            call symputx('group', group);			
            if index(upcase(codedist), "EXP") > 0 then call symputx('codedistexp', 'Y');
			if index(upcase(codedist), "HOI") > 0 then call symputx('codedisthoi', 'Y');
        run;

		%if &codedistexp. eq Y %then %do;
			* Defensive: make sure the requested data is available;
			%let obscount=0;

			proc sql noprint;
			select count(*) into :obscount from codedistdata
			where lower(group) = "&group." and runid = "&runid" and lower(distindextype) = "exp";
			quit;

			%if %eval(&obscount. > 0) %then %codedistribution_type_toc(distindextype=exp);
		%end;
		%if &codedisthoi. eq Y %then %do;
			* Defensive: make sure the requested data is available;
			%let obscount=0;

			proc sql noprint;
			select count(*) into :obscount from codedistdata
			where lower(group) = "&group." and runid = "&runid" and lower(distindextype) = "hoi";
			quit;

			%if %eval(&obscount. > 0) %then %codedistribution_type_toc(distindextype=hoi);
		%end;
				
	%end; *numgroupscodedist;
	%let tablenum = %eval(&tablenum + 1);
    %end;

    /*********************************************************************************************/
    /* Attrition table                                                                           */
    /*********************************************************************************************/
    %isdata(dataset=agg_patient_attrition);
    %let attrition_patient = &nobs;
    %isdata(dataset=agg_episode_attrition);
    %let attrition_episode = &nobs;
	
    /* reset counter to reset table letter */
    %let tablecount=1;
	
    %if &attrition_patient > 0 or &attrition_episode > 0 %then %do;

		%if (&attrition_patient > 0 and &attrition_episode = 0) or (&attrition_patient = 0 and &attrition_episode > 0) %then %do;
			%let tablecount = 0;
		%end;

		%if &attrition_episode > 0 %then %do;
			%tableletter();
			%addtotoc(tabnum=Table &tablenum.&tableletter.,
					  caption=%quote(Summary of Episode Level Cohort Attrition in the &database. from &startdateformatted. to &enddateformatted.));			 
		%end; 

		%if &attrition_patient > 0 %then %do;
			%tableletter();	
			%addtotoc(tabnum=Table &tablenum.&tableletter.,
					  caption=%quote(Summary of Patient Level Cohort Attrition in the &database. from &startdateformatted. to &enddateformatted.));
		%end;
	
        %let tablenum = %eval(&tablenum + 1);

    %end; /* attrition_groups file */


    /*** END TABLES **/

    /*********************************************************************************************/
    /*   Figures                                                                                 */
    /*********************************************************************************************/  

    %isdata(dataset=figurefile);
    %if %eval(&nobs.>0) %then %do;

        %let figurenum = 1; /* Add +1 for additional figure types that are requested */
        %let tablecount = 1;

        /***************************************************************************************/
        /* L1 Figures                                                                          */
        /***************************************************************************************/
        %if %sysfunc(prxmatch(m/T1|T2L1|T5|T6/i,&reporttype.)) > 0 %then %do;

            /*utility macro to loop through groups*/
            %macro l1kmtoc(figure=, title =);
			  %if %sysfunc(prxmatch(m/F1|F2|F3/i,&figurelist.)) > 0 %then %do;
			    %let figure_dataset = figure123;
			  %end;
			  %else %do;
			     %let figure_dataset = figure&figure.;
			  %end;

                %isdata(dataset=&figure_dataset.);
                %if %eval(&nobs.>0) %then %do;

                /*number of distinct groups in figure to loop through determine whether to add letter to figure #*/
                proc sql noprint;
                    select distinct order
                    into :fgrouporderlist separated by ' '
                    from &figure_dataset.
                    order by order;
                quit;
                   
                %if %sysfunc(countw(&fgrouporderlist.)) = 1 %then %let tablecount = 0;
                %else %let tablecount = 1;

                %do g = 1 %to %sysfunc(countw(&fgrouporderlist.));
                    %let order = %scan(&fgrouporderlist., &g.);
                    %let grouplabel = ;
                    %let switch2indicator = ;
                    
                    data _null_;
                        set &figure_dataset.(where=(order = &order.));
                        if _n_ = 1 then do;
                        call symputx('grouplabel', grouplabel);
                        end;
                    run;

                    %tableletter();	
            		%addtotoc(tabnum=Figure &figurenum.&tableletter.,
            				  caption=%quote(&title. Among &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.));
                %end; /*loop through each figure*/
                %let figurenum = %eval(&figurenum.+1); 
                %end; /*figure dataset exists*/
            %mend;

            /**********************************************************************************************
             T1: 1 figure: 
                1) F1: t1censor = Reasons for End of Observable Data by Group (1-CDF) - 1 figure per group
            /**********************************************************************************************/
            %if &reporttype. = T1 %then %do;
                %l1kmtoc(figure=F1, title =Reasons for End of Observable Data);
            %end; /*T1*/

            /**********************************************************************************************
             T2L1: 3 figures:
                1) F1: t2followuptime = Kaplan-Meier Estimate of Event of Interest Not Occurring
                2) F2: t2followuptime = Reasons for End of Follow-Up by Group (1-CDF)
                3) F3: t2censor = Reasons for End of Observable Data by Group (1-CDF)
            /**********************************************************************************************/
            %if &reporttype. = T2L1 %then %do;

                /*F1: 1 figure per report*/
                %isdata(dataset=figuref1);
                %if %eval(&nobs.>0) %then %do;
                	%addtotoc(tabnum=Figure &figurenum.,
                			  caption=%quote(Kaplan-Meier Estimate of Event of Interest Not Occurring in the &database. from &startdateformatted. to &enddateformatted.));
                    %let figurenum = %eval(&figurenum.+1); 
                %end;

                /*F2: 1 figure per group*/
                %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) > 0 %then %do;
                    %l1kmtoc(figure=F2, title =Reasons for End of Follow-Up);
                %end; /*figuref2*/

                /*F3: 1 figure per group*/
                %if %sysfunc(prxmatch(m/F3/i,&figurelist.)) > 0 %then %do;
                    %l1kmtoc(figure=F3, title =Reasons for End of Observable Data);
                %end; /*figuref3*/
            %end; /*T2L1*/

            /**********************************************************************************************
             T5: 5 figures:
                1) F1: Patient Entry into Study by Month
                2) F2: Number of Prescription Dispensings in Patients First Episodes by Month
                3) F3: Total Days Supply in Patients First Episodes by Month
                4) F4: t5censor = Reasons for End of First Treatment Episode by Group
                5) F5: t5censor = End of First Treatment Episode due to [Censoring Reason] by Group 
            /**********************************************************************************************/
			
            %if &reporttype. = T5 %then %do;
			  /* F1 */
			  %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) > 0 %then %do;
			    %l1kmtoc(figure=F1, title =Patient Entry into Study by Month);
			  %end;

			  /* F2 */
		      %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) > 0 %then %do;
			    %l1kmtoc(figure=F2, title =Number of Prescription Dispensings in Patients%str(%') First Episodes by Month Patient Entered into Study);
		      %end;

			  /* F3 */
		      %if %sysfunc(prxmatch(m/F3/i,&figurelist.)) > 0 %then %do;
			    %l1kmtoc(figure=F3, title =Total Days Supply in Patients%str(%') First Episodes by Month Patient Entered into Study);
		      %end;

              /*F4: 1 figure per group*/
              %if %sysfunc(prxmatch(m/F4/i,&figurelist.)) > 0 %then %do;
                %l1kmtoc(figure=F4, title =Reasons for End of First Treatment Episode);
              %end; /*figuref4*/

                /*F5: 1 figure per report*/
			  %if %sysfunc(prxmatch(m/F5/i,&figurelist.)) > 0 %then %do;
                data _null_;
                  set figurefile(where=(figure="F5"));
                  call symputx('censordisplay', censordisplay);
                run;
                %l1kmtoc(figure=F5, title =%quote(End of First Treatment Episode due to &&&censordisplay._label in the &database. from &startdateformatted. to &enddateformatted.));
              %end;  	
             
            %end; /*T5*/

            /**********************************************************************************************
             T6: 7 figures:
                1) F1 (not yet implemented)
                2) F2 (not yet implemented)
                3) F3 (not yet implemented)
                4) F4: t6plota = Kaplan-Meier Estimate of First Switch Not Occurring
                5) F5: t6plotb = Kaplan-Meier Estimate of Second Switch Not Occurring
                6) F6: t6plota = Reasons for Censoring at First Switch Evaluation by Analysisgrp
                7) F7: t6plotb = Reasons for Censoring at Second Switch Evaluation by Analysisgrp
            /***********************************************************************************************/
            %if &reporttype. = T6 %then %do;
                /*F4 - F7: 1 figure per group*/
                %if %sysfunc(prxmatch(m/F4/i,&figurelist.)) > 0 %then %do;
                    %l1kmtoc(figure=F4, title =Kaplan-Meier Estimate of First Switch Not Occurring);
                %end; /*figuref4*/
                %if %sysfunc(prxmatch(m/F5/i,&figurelist.)) > 0 %then %do;
                    %l1kmtoc(figure=F5, title =Kaplan-Meier Estimate of Second Switch Not Occurring);
                %end; /*figuref5*/
                %if %sysfunc(prxmatch(m/F6/i,&figurelist.)) > 0 %then %do;
                    %l1kmtoc(figure=F6, title =Reasons for Censoring at First Switch Evaluation);
                %end; /*figuref6*/
                %if %sysfunc(prxmatch(m/F7/i,&figurelist.)) > 0 %then %do;
                    %l1kmtoc(figure=F7, title =Reasons for Censoring at Second Switch Evaluation);
                %end; /*figuref7*/
            %end; /*T6*/

        %end; /*L1 figures*/

        /***************************************************************************************/
        /* L2 Figures                                                                          */
        /***************************************************************************************/
        %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;

	        /*F1: PS distribution histograms*/
	        %if %sysfunc(prxmatch(m/F1/i,&figurelist.)) > 0 %then %do;

				proc sql noprint;
					select count(distinct AnalysisGrp) into: numPScomparisons
            		from l2comparisonfile(where=(OutputPSDistribution="Y"));
				quit;

				%do loopcount = 1 %to &numl2comparisons.; 

					data _NULL_;
		            set l2comparisonfile(where=(order=&loopcount.));
		            call symputx('runid', runid);
		            call symputx('analysisgrp', analysisgrp);
		            call symputx('OutputPSDistribution', OutputPSDistribution);
		       		run;

				  %if &OutputPSDistribution. = Y %then %do;

					%isdata(dataset=labelfile);
					%let grouplabel=&analysisgrp.;

				    %if %eval(&nobs>0) %then %do;
					  data _NULL_;
					  set labelfile(where=(lowcase(labeltype)='grouplabel'));
					  if group="&analysisgrp." and runid = "&runid";
		              call symputx('grouplabel', Label);
					  run;
					  %put &grouplabel.;
					%end;

					%let andafter=;

					proc sql noprint;
		            select strip(file) into: psfile
		            from pscs_masterinputs
		            where analysisgrp = "&analysisgrp.";
			        quit;

                    %if &psfile. = psmatchfile | &psfile. = stratificationfile | &psfile. = iptwfile %then %do;
				      data _null_; 
	                  set pscs_masterinputs (where=(lowcase(analysisgrp)="&analysisgrp."));
	                    call symputx("psestimategrp", lowcase(psestimategrp));
	                        %if &psfile. = psmatchfile  %then %do;
	                            if upcase(ratio) = "F" then do;
								    call symput("andafter", " and After");
	                            end;
	                        %end;
	                        %if &psfile = iptwfile %then %do;
							   call symput("andafter", " and After");
	                        %end;
							%else %if &psfile = stratificationfile %then %do;
							   if upcase(strataweight) in ("ATE", "ATT") then do;
							     call symput("andafter", " and After");
							   end;
	                        %end;
	                  run; 

		            %do j = %eval(&look_start) %to %eval(&look_end);

						%if &numPScomparisons.=1 and %eval(&look_end)=1 %then %do;
							%let tablecount = 0;
						%end;
		                %tableletter();
		                %addtotoc(tabnum=Figure &figurenum.&tableletter.,
		                caption=%quote(Histograms Depicting Propensity Score Distributions Before&andafter Adjustment for &grouplabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.))
		            %end; /* loop periods */
				%end; /*psfile*/
			  %end; /* OutputPSDistribution */
			 %end; /* loop comparisons */
			 %let figurenum = %eval(&figurenum.+1); 
	        %end; /*Histograms*/

	        /*F2: Forest Plots*/
	        %if %sysfunc(prxmatch(m/F2/i,&figurelist.)) > 0 %then %do;
	            %if %sysfunc(prxmatch(m/T2L2/i,&reporttype.)) > 0 %then %let ForestRatioTitle = Hazard Ratios (HR);
	            %else %let ForestRatioTitle = Odds Ratios (OR);

				%let tableletter=a;
				%let tablecount = 1;

	            %do j = %eval(&look_start) %to %eval(&look_end);
	                %do plot = 1 %to 7;
	                    %let forest_title = ;
	                    data _null_;
	                    set forest_&j(where=(plotorder=&plot));
	                      call symputx("forest_title",forest_title);
	                    run;

	                    %if %length(&forest_title) > 0 %then %do;
	                    %tableletter();
	                    %addtotoc(tabnum=Figure &figurenum.&tableletter.,
	                    caption=%quote(Forest Plot of &ForestRatioTitle and 95% Confidence Intervals (CI) for &forest_title in the &database. from &startdateformatted. to &&enddate&j.formatted.))
	                    %end; /* Forest title exists */
	                %end; /* loop plots */
	            %end; /* loop periods */

                %let figurenum = %eval(&figurenum.+1); 
	        %end; /*Forest plots */

            /*F3-F5: KM Plots - Type 2 only*/
            %if &reporttype. = T2L2 & %sysfunc(prxmatch(m/F3|F4|F5/i,&figurelist.)) > 0 %then %do;

                *reset tablecount; 
				%let tablecount = 1;

                /*loop through each analysisgrp - dataset only exists if curve computed*/
				%do loopcount = 1 %to &numl2comparisons.;   
                    data _null_;
                        set l2comparisonfile(where=(order=&loopcount.));
		                call symputx('runid', runid);
		                call symputx('analysisgrp', analysisgrp);
                    run;

                    proc sql noprint;
                        select distinct strip(file) into: pscsfile trimmed
                        from pscs_masterinputs
                        where analysisgrp = "&analysisgrp." and runid = "&runid";
                    quit;

                    %if &pscsfile. = psmatchfile | &pscsfile. = stratificationfile %then %do;

                        /*assign labels*/
                        data _null_; 
                            set pscs_masterinputs(where=(analysisgrp="&analysisgrp." and covarnum = 0));
                            call symputx("psestimategrp", lowcase(psestimategrp));
                        run;
                        data _null_; 
                            set infolder.&&&runid._psestimationfile(where=(lowcase(psestimategrp)="&psestimategrp."));
                            call symputx('GRP1', eoi);
                            call symputx('GRP0', ref); 
                        run;

                        %let outcomelabel = Event of Interest;
                        %let eoilabel = &grp1.;
                        %let reflabel = &grp0.;

                        %isdata(dataset=labelfile);
                        %if %eval(&nobs.>0) %then %do;
                            data _null_;
                                set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid" and labeltype = "outcomelabel"))
                                    labelfile(in=b where=(group="&grp1." and runid = "&runid." and labeltype = "grouplabel"))
                                    labelfile(in=c where=(group="&grp0." and runid = "&runid." and labeltype = "grouplabel"));

                                if a then call symputx('outcomelabel', label);
                                if b then call symputx('eoilabel', label);
                                if c then call symputx('reflabel', label);
                            run;
                        %end;

                        /*loop through periodid*/
                        %do j = %eval(&look_start) %to %eval(&look_end);

                        /*F3*/
                        %isdata(dataset=figureF3_analysis&loopcount._&j.);
                        %if %eval(&nobs.>0) %then %do;
                        %tableletter();	
                    	%addtotoc(tabnum=Figure &figurenum.&tableletter.,
                    			  caption=%quote(Unadjusted Kaplan-Meier Estimate of &outcomelabel. Not Occurring Among &eoilabel. and &reflabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.));
                        %end;
                        /*F4*/
                        %isdata(dataset=figureF4_analysis&loopcount._&j.);
                        %if %eval(&nobs.>0) %then %do;
                        %tableletter();	
                    	%addtotoc(tabnum=Figure &figurenum.&tableletter.,
                    			  caption=%quote(Conditional Kaplan-Meier Estimate of &outcomelabel. Not Occurring Among &eoilabel. and &reflabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.));
                        %end;
                        /*F5*/
                        %isdata(dataset=figureF5_analysis&loopcount._&j.);
                        %if %eval(&nobs.>0) %then %do;
                        %tableletter();	
                    	%addtotoc(tabnum=Figure &figurenum.&tableletter.,
                    			  caption=%quote(Unconditional Kaplan-Meier Estimate of &outcomelabel. Not Occurring Among &eoilabel. and &reflabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.));
                        %end;

                        %end; /*loop through periodid*/
                    %end; /*only PSmatch or stratification*/
                %end;
            
                /*if there is only 1 figure, rewrite figure # - this method is used instead of determining apriori b/c of 
                  the numerous permutations of situations that can lead to 1 figure */
                proc sql noprint;
                    select count(caption) into: countkm
                    from tableofcontents
                    where index(caption, 'Kaplan-Meier Estimate')>0;
                quit;

                %if %eval(&countkm.)=1 %then %do;
                    data tableofcontents;
                        set tableofcontents;
                        if index(caption, 'Kaplan-Meier Estimate')>0 then do;
                        tabnum = "Figure &figurenum.";
                        end;
                    run;
                %end;
                                           
			 %let figurenum = %eval(&figurenum.+1); 

            %end; /*KM plots*/
        %end; /*L2 figures*/

    %end; /* Figure file */
	

    /*****************/
    /* Appendices    */
    /*****************/

    /*Appendix A*/
    %addtotoc(tabnum=Appendix A, caption=Dates of Available Data for Each Data Partner (DP) as of Request Distribution Date &datedistributed.);
	
	/* The remaining appendices are created in appendix_driver.sas */
	
    /*********************/
    /* Remove empty rows */
    /*********************/
    data tableofcontents;
       set tableofcontents;
       if missing(tabnum)=0;
    run;

    %put =====> END MACRO: create_tableofcontents ;

%mend create_tableofcontents;
