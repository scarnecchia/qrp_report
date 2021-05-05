****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_profile_output.sas  
* Created (mm/dd/yyyy): 04/29/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*   Transform and output covariate profile tables                                
*   
*  Program inputs:        
*   -                                                                           
*                                     
*  Program outputs:                                                                                                                                       
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
*--------------------------------------------------------------------------------------------------
*  CHANGE LOG: 
*
*   Version   Date       Initials      Comment (reference external documentation when available)
*   -------   --------   --------   ----------------------------------------------------------------
*
***************************************************************************************************;

%macro baseline_profile_output;

    /* Reset table letter at top of dataset loop */
    %let tablecount = 1;

%do periodid = %eval(&look_start.) %to %eval(&look_end.);

    proc sql noprint ;
        select 'order='||strip(put(order,8.))||' and runid='||quote(strip(runid))||' and group='||quote(strip(group))||' and cohort='||quote(strip(cohort))
        into :whereexpr separated by '@'
        from (select order, runid, group, case when(cohort is missing) then 'all' else cohort end as cohort
              from baselinefile
              where not missing(profilecovarstoinclude));
    quit;

    %do wherenum = 1 %to %sysfunc(countw(&whereexpr, @));
        %let where = %scan(&whereexpr,&wherenum, @);

            data _temp_agg_order_profile;
                set aggregate_profile(where=(periodid=&periodid and &where));
                grouplabel='';
            run;

            %let profileswitches = 0;
            %if &reporttype = T6 %then %do;
                proc sql noprint;
                select max(switchstep) into :profileswitches
                from _temp_agg_order_profile;
                quit;
            %end;

            /* Only loop when there are observations */
            %isdata(dataset=_temp_agg_order_profile);
            %if &nobs > 0 %then %do;

            /* Additional loop for profile switching */
            %do s = 0 %to &profileswitches;

            %if &reporttype = T6 %then %do;
            data _temp_agg_profile;
                set _temp_agg_order_profile (where=(switchstep = &s)); %end;
            run;
            %end;
            %else %do;
            proc datasets lib=work;
                change _temp_agg_order_profile = _temp_agg_profile;
            run;
            %end;

            %isdata(dataset=labelfile);
            %if &nobs > 0 %then %do;
            proc sql noprint undo_policy=none;
                create table _temp_agg_profile as
                select a.*, b.label as grouplabel
                from _temp_agg_profile(drop=grouplabel) a 
                left join labelfile(where=(lowcase(labeltype)='grouplabel')) b
                on a.group = b.group and a.runid = b.runid;
            quit;
            %end;

            data final_agg_profile_&wherenum._&periodid.(drop=covarsort);
                set _temp_agg_profile;
                if upcase(covarsort) not in ('A','O','C') then covarsort = 'C'; /*set C as default*/
                call symputx('covarsort', upcase(covarsort));
                %if %index(&where,%str(cohort="nopreg")) %then %do;
                if not missing(grouplabel) then call symputx('grouplabel',catx(' ',grouplabel,'Non-Pregnancy'));
                else call symputx('grouplabel',catx(' ', group, 'Non-Pregnancy'));
                %end;
                %else %if %index(&where,%str(cohort="preg")) %then %do;
                if not missing(grouplabel) then call symputx('grouplabel',catx(' ',grouplabel,'Pregnancy'));
                else call symputx('grouplabel',catx(' ', group, 'Pregnancy'));
                %end;
                %else %if &reporttype = T6 %then %do;
                %if &s = 0 %then %do;
                if not missing(grouplabel) then call symputx('grouplabel',catx(' ',grouplabel,'step 0'));
                else call symputx('grouplabel',catx(' ', group, 'step 0'));
                %end;
                %else %if &s = 1 %then %do;
                if not missing(grouplabel) then call symputx('grouplabel',catx(' ',grouplabel,'step 0 to step 1'));
                else call symputx('grouplabel',catx(' ', group, 'step 0 to step 1'));
                %end;
                %else %if &s = 2 %then %do;
                if not missing(grouplabel) then call symputx('grouplabel',catx(' ',grouplabel,'step 1 to step 2'));
                else call symputx('grouplabel',catx(' ', group, 'step 1 to step 2'));
                %end;
                %end;
                %else %do;
                if not missing(grouplabel) then call symputx('grouplabel',grouplabel);
                else call symputx('grouplabel',group);
                %end;
                if lowcase(strip(profilecovarstoinclude)) = 'all' then profilecovarstoinclude = 'covar:';
                call symputx('profilecovarsnocomma', compress(compbl(tranwrd(profilecovarstoinclude,',',', ')),','));
            run;

            *Total npts and n_episodes;
            %let totalpatients =0;
            %let totalepisodes =0;
            proc sql noprint;
                select sum(sum_npts), sum(sum_nepisodes) 
                into :totalpatients, :totalepisodes
                from final_agg_profile_&wherenum._&periodid.;
            quit;
            %put &totalpatients &totalepisodes;

            *Determine covariate label and order;
            data covarlabel;
                set final_agg_profile_&wherenum._&periodid.(keep=&profilecovarsnocomma. obs=0);
            run;

            proc transpose data=covarlabel out=covarlabel1;
                var &profilecovarsnocomma.;
            run;

            proc sort data=covarlabel1 sortseq=linguistic (numeric_collation=on);
                by %if &covarsort = A %then %do;
                    _label_;
                    %end;
                    %else %do;
                    _name_;
                    %end;
            run;

            *max length of covariate label;
            proc contents data=covarlabel1 out=covarcontents noprint; run;

            data _null_;
                set covarcontents(keep=name length nobs where=(upcase(name)="_LABEL_"));
                alllabellength = (length+5)*nobs;
                call symputx('alllabellength', alllabellength);
                call symputx('numcovars', nobs);
                call symputx('labellength', length);
            run;
            %put &numcovars. &alllabellength &labellength;

            *list of covariates in order;
            proc sql noprint;
                select _name_ into: covarlist separated by ' '
                from covarlabel1;
            quit;
            %put &covarlist.;

            *put covarlabel into macro variable;
            %do f=1 %to %eval(&numcovars.);
                %let covar = %scan(&covarlist., &f.);
                data _null_;
                    set covarlabel1(where=(upcase(_name_)=upcase("&covar.")));
                    call symputx("&covar.", _label_);
                run;
            %end;

            *create label for each row in table;
            data covarswithlabel;
                set final_agg_profile_&wherenum._&periodid. end=eof;
                /* set missing covariate values to 0 */
                %do f=1 %to %eval(&numcovars.);
                    %let covar = %scan(&covarlist., &f.);
                    if missing(&covar) then &covar = 0;
                %end;

                format label $&alllabellength..;
                length label $&alllabellength.;

                *number of covariates;
                totalcov=sum(of covar:);

                *all;
                if totalcov = &numcovars. then do;
                    label = 'All Characteristics Present';
                    sortorder = &numcovars.+1;
                end;
                *none;
                else if totalcov = 0 then do;
                    label = 'No Characteristics Present';
                    sortorder = &numcovars.+2;
                end;

                %if %eval(&numcovars.>1) %then %do;
                *create a label for each covariate, then append for final label;
                else do;
                    %do i = 1 %to %eval(&numcovars.);
                        length label&i. $&labellength.;
                        if %scan(&covarlist., &i.) = 1 then label&i. = "&&%scan(&covarlist., &i.)";
                        else label&i.='';
                    %end;

                    label = catx(' and ', %do i =1 %to %eval(&numcovars.); 
                                %if %eval(&i.) = %eval(&numcovars.) %then %do; label&i. %end;
                                %else %do; label&i., %end; %end;);

                    sortorder = totalcov;
                end;

                *only 1;
                if totalcov = 1 then label = cat(strip(label), ' only');
                %end;

                *Output metrics;
                format sum_npts sum_nepisodes comma12.0 percent_npts percent_episodes percent8.1;
                        
                if &totalpatients.>0 then do;
                    percent_npts = sum_npts/&totalpatients.;
                end;
                else do;
                    percent_npts=0;
                end;
                if &totalepisodes.>0 then do;
                    percent_episodes = sum_nepisodes/&totalepisodes.;
                end;
                else do;
                    percent_episodes=0;
                end;

                output;

                if eof then do;
                    *Defensive - add all/no row if not present;
                    sum_npts = 0;
                    sum_nepisodes = 0;
                    percent_npts=0;
                    percent_episodes=0;
                    %do i = 1 %to %eval(&numcovars.);
                        %scan(&covarlist., &i.) = 1;
                    %end;
                    label = 'All Characteristics Present';
                    sortorder = &numcovars.+1;
                    output;

                    sum_npts = 0;
                    sum_nepisodes = 0;
                    percent_npts=0;
                    percent_episodes=0;
                    %do i = 1 %to %eval(&numcovars.);
                        %scan(&covarlist., &i.) = 0;
                    %end;
                    label = 'No Characteristics Present';
                    sortorder = &numcovars.+2;
                    output;
                end;

                keep label sortorder sum_npts sum_nepisodes percent_npts percent_episodes covar:;
            run;

            %tableletter();
        
            /* Don't use table letter when there is only one group included */
             %if &numprofilecovarstoinclude = 1 and &reporttype ^= T6 %then %let tableletter =;
             %else %if &numprofilecovarstoinclude = 1 and &profileswitches = 0 and &reporttype = T6 %then %let tableletter =;

            %if &covarsort = A %then %do;
            proc sort data=covarswithlabel nodupkey out=repdata.table&tablenum.&tableletter(drop=covar:);
                by sortorder label;
            run;
            %end;
            %else %do;
            proc sort data=covarswithlabel nodupkey out=covarswithlabel;
                by sortorder label;
            run;

            proc sort data=covarswithlabel out=repdata.table&tablenum.&tableletter(drop=covar:);
                by sortorder 
                %do i = 1 %to %eval(&numcovars.);
                descending  %scan(&covarlist., &i.) 
                %end;
                ;
            run;
            %end;

            %let title = %quote(Table &tablenum.&tableletter.. Characteristic Profile of &grouplabel in the &database. from &startdateformatted. to &&enddate&periodid.formatted.);

            ods escapechar="^";
            %if &destination = excel %then %do;
            ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="rgba(0,176,80,0)");
            %end;
            ods proclabel = "Table &tablenum.&tableletter.";

            proc report data = repdata.table&tablenum.&tableletter nofs nowd headline headskip split="*" contents=''
                style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
                style(report)=[rules=none frame=box];
                        
            columns (label sum_npts percent_npts sum_nepisodes percent_episodes);           
                define label / order=data 'Characteristic Category'
                                  style(header)=[just=L] style(column)=[rules=none width=4.5in just=L];
                define sum_npts / 'Number of Patients'
                                style(column)=[width=1in just=C background=background_n_fmt.] format=comma12.;
                define percent_npts /'% of Total*Number of*Patients'
                                style(column)=[width=.65in just=C] ;
                define sum_nepisodes / 'Number of Episodes'
                                style(column)=[width=1in just=C background=background_n_fmt.] format=comma12.;
                define percent_episodes / '% of Total*Number of*Episodes'
                                style(column)=[width=.65in just=C] ;

            /* Add title */
            compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
            line "&title.";
            endcomp;

            run;

            proc datasets library=work nowarn noprint;
            delete _temp_agg_profile _temp_agg_order_profile;
            quit;

            %end; /* _temp_agg_profile > 0  */
            %end; /* where */
            %end; /* switch */
%end; /* periodid */

%mend baseline_profile_output;