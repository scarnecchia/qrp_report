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
        select 'order='||strip(put(order,8.))||' and runid='||quote(strip(runid))||' and group='||quote(strip(group))||' and cohort='||quote(strip(cohort))||' and baselinegroupnum='||put(baselinegroupnum,8.)
        into :whereexpr separated by '@'
        from (select order, runid, group, case when(cohort is missing) then 'all' else cohort end as cohort, baselinegroupnum
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
                if cohort = 'switch' then switchlabel=' ';
                call symputx('runid',runid);
				call symputx('profilegroup',group);
				call symputx('profilecohort',cohort);
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

            %isdata(dataset=labelfile);
            %if &nobs > 0 %then %do;
            proc sql noprint undo_policy=none;
                create table _temp_agg_profile as
                select a.*, b.label as grouplabel
                            %if %index(&where,%str(cohort="switch")) %then %do; ,d.label as switchlabel %end;
                from _temp_agg_profile(drop=grouplabel %if &reporttype = T6 %then %do; switchlabel %end;) a 
                left join labelfile(where=(lowcase(labeltype)='grouplabel')) b
                on a.group = b.group and a.runid = b.runid
                %if %index(&where,%str(cohort="switch")) %then %do;
                left join labelfile(where=(lowcase(labeltype)='grouplabel')) d
                on a.productswitchgroup = d.group and a.runid = d.runid
                %end;
                ;
            quit;
            %end;
            %else %do;
            data _temp_agg_profile;
                set _temp_agg_profile;
                grouplabel2='';
                switchlabel='';
            run;
            %end;

            data final_agg_profile_&wherenum._&periodid.(drop=covarsort);
                set _temp_agg_profile;
                if upcase(covarsort) not in ('A','O','C') then covarsort = 'C'; /*set C as default*/
                call symputx('covarsort', upcase(covarsort));
                if not missing(grouplabel) then call symputx('grouplabel',grouplabel);
                else call symputx('grouplabel',group);
				call symputx('productlabel',grouplabel);

                %if %index(&where,%str(cohort="nopreg")) %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',catx(' ',grouplabel,'Non-Pregnancy'));
                call symputx('productlabel',catx(' ',grouplabel,'Non-Pregnancy'));
                end;
                else do;
                call symputx('grouplabel',catx(' ',group,'Non-Pregnancy'));
                call symputx('productlabel',catx(' ',group,'Non-Pregnancy'));
                end;
                %end;

                %else %if %index(&where,%str(cohort="preg")) %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',catx(' ',grouplabel,'Pregnancy'));
                call symputx('productlabel',catx(' ',grouplabel,'Pregnancy'));
                end;
                else do;
                call symputx('grouplabel',catx(' ',group,'Pregnancy'));
                call symputx('productlabel',catx(' ',group,'Pregnancy'));
                end;
                %end;

                %else %if &reporttype = T6 %then %do;

                %if &s = 0 %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',grouplabel);
                if not missing(switchlabel) then call symputx('productlabel', switchlabel);
                else call symputx('productlabel',productswitchgroup);
                end;
                else do;
                call symputx('grouplabel',group);
                call symputx('productlabel', productswitchgroup);   
                end;
                %end;

                %else %if &s = 1 %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',grouplabel);
                if not missing(switchlabel) then call symputx('productlabel',catx(' ',"&productlabel", 'to', switchlabel));
                else call symputx('productlabel',catx(' ',"&productlabel", 'to', productswitchgroup));
                end;
                else do;
                call symputx('grouplabel',group);
                call symputx('productlabel',catx(' ',"&productlabel",'to',productswitchgroup));    
                end;
                %end;

                %else %if &s = 2 %then %do;
                if not missing(grouplabel) then do;
                call symputx('grouplabel',grouplabel);
                if not missing(switchlabel) then call symputx('productlabel',catx(' ',"&productlabel", 'to', switchlabel));
                else call symputx('productlabel',catx(' ',"&productlabel", 'to', productswitchgroup));
                end;
                else do;
                call symputx('grouplabel',group);
                call symputx('productlabel',catx(' ',"&productlabel",'to',productswitchgroup));    
                end;
                %end;

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

			/* Exclude from covariates to report those anchored to INDEXDT_EXP for type 4 unexposed cohorts */
			%if %index(&reporttype,T4) > 0 %then %do;
				%let numprofilecovars_valid=0;

				/* If ALL covariates where requested, need to build the list */
				%if %str("&profilecovarsnocomma.") eq %str("covar:") %then %do;
					proc sql noprint;
					select distinct upcase(cov_varname) into :profilecovarsnocomma separated by " "
					from covarname;
					quit;
				%end;

				%let profilecovars_valid=&profilecovarsnocomma;
				%let profilecovarsquoted=%upcase(&profilecovarsnocomma);	
				%baseline_expand_parameters(var=profilecovarsquoted);
				
				%if &profilecohort. eq mi %then %do;
					%if %substr(&profilegroup.,%length(&profilegroup.)-3, 4) eq _eoi %then %let profile_unexposed=N; /* _eoi group always exposed */
					%else %do;
						%let profile_unexposed=;

						proc sql noprint;
						select controlmp into :profile_unexposed 
						from master_mil where ref="&profilegroup.";
						quit;

						%if %str(&profile_unexposed.) eq %str() %then %let profile_unexposed=Y;
						%else %let profile_unexposed=N;
					%end;
				%end;
				%else %let profile_unexposed=Y;

				proc sql noprint;
				select count(*) into: numprofilecovars_valid 
				from covarname
				where upcase(cov_varname) in (&profilecovarsquoted.) and runid="&runid" 
					  %if &profile_unexposed. eq Y %then %do;
					  and upcase(covfromanchor) ne "INDEXDT_EXP" and upcase(covtoanchor) ne "INDEXDT_EXP"
					  %end;;

				%if &profile_unexposed. eq Y %then %do;
				select cov_varname into: profilecovars_valid separated by " " 
				from covarname
				where upcase(cov_varname) in (&profilecovarsquoted.) and runid="&runid" 		 
					  and upcase(covfromanchor) ne "INDEXDT_EXP" and upcase(covtoanchor) ne "INDEXDT_EXP";		  
				%end;
				quit;

				%put &=numprofilecovars_valid;
			%end;
			%else %do;
				%let numprofilecovars_valid = &numprofilecovarstoinclude.;
				%let profilecovars_valid = &profilecovarsnocomma.;
			%end;

            *Determine covariate label and order;
            data covarlabel;
                set final_agg_profile_&wherenum._&periodid.(keep=&profilecovars_valid. obs=0);
            run;

            proc transpose data=covarlabel out=covarlabel1;
                var &profilecovars_valid.;
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
                call symputx('numprofilecovars', nobs);
                call symputx('labellength', length);
            run;
            %put &numprofilecovars. &alllabellength &labellength;

            *list of covariates in order;
            proc sql noprint;
                select _name_ into: covarlist separated by ' '
                from covarlabel1;
            quit;
            %put &covarlist.;

            *put covarlabel into macro variable;
            %do f=1 %to %eval(&numprofilecovars.);
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
                %do f=1 %to %eval(&numprofilecovars.);
                    %let covar = %scan(&covarlist., &f.);
                    if missing(&covar) then &covar = 0;
                %end;

                format label $&alllabellength..;
                length label $&alllabellength.;

                *number of covariates;
                totalcov=sum(of covar:);

                *all;
                if totalcov = &numprofilecovars_valid. and &numprofilecovars_valid. > 0 then do;
                    label = 'All Characteristics Present';
                    sortorder = &numprofilecovars.+1;
                end;
                *none;
                else if totalcov = 0 then do;
                    label = 'No Characteristics Present';
                    sortorder = &numprofilecovars.+2;
                end;

                %if %eval(&numprofilecovars_valid.>1) %then %do;
                *create a label for each covariate, then append for final label;
                else do;
                    %do i = 1 %to %eval(&numprofilecovars.);
                        length label&i. $&labellength.;
                        if %scan(&covarlist., &i.) = 1 then label&i. = "&&%scan(&covarlist., &i.)";
                        else label&i.='';
                    %end;

                    label = catx(' and ', %do i =1 %to %eval(&numprofilecovars.); 
                                %if %eval(&i.) = %eval(&numprofilecovars.) %then %do; label&i. %end;
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
                    %do i = 1 %to %eval(&numprofilecovars.);
                        %scan(&covarlist., &i.) = 1;
                    %end;
                    label = 'All Characteristics Present';
                    sortorder = &numprofilecovars.+1;
                    output;

                    sum_npts = 0;
                    sum_nepisodes = 0;
                    percent_npts=0;
                    percent_episodes=0;
                    %do i = 1 %to %eval(&numprofilecovars.);
                        %scan(&covarlist., &i.) = 0;
                    %end;
                    label = 'No Characteristics Present';
                    sortorder = &numprofilecovars.+2;
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
                %do i = 1 %to %eval(&numprofilecovars.);
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
        		style(header)=[rules=none vjust=b frame=void background=BGR borderleftcolor = BGR]
        		style(report)=[rules=none frame=void cellpadding =1.75pt];
            %if %index(&reporttype,T4) or %index(&reporttype,T6) %then %do;
            columns (label ("^S={background=white}&productlabel." sum_npts percent_npts sum_nepisodes percent_episodes));    
            %end;
            %else %do;
            columns (label sum_npts percent_npts sum_nepisodes percent_episodes);
            %end;
                define label / order=data 'Characteristic Category'
                                 style(header)=[background = bgr borderleftcolor = BGR] style(column)=[rules=none width=4.5in just=L];
                define sum_npts / 'Number of Patients'
                                style(header)=[background = bgr borderleftcolor = BGR] style(column)=[width=1in just=C background=background_n_fmt.] format=comma12.;
                define percent_npts /'% of Total*Number of*Patients'
                                style(header)=[background = bgr borderleftcolor = BGR] style(column)=[width=.65in just=C] ;
                define sum_nepisodes / 'Number of Episodes'
                                style(header)=[background = bgr borderleftcolor = BGR] style(column)=[width=1in just=C background=background_n_fmt.] format=comma12.;
                define percent_episodes / '% of Total*Number of*Episodes'
                                style(header)=[background = bgr borderleftcolor = BGR] style(column)=[width=.65in just=C] ;

            /* Add title */
			compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=white 
			                               borderbottomwidth=&bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
            line "&title.";
            endcomp;
            compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
            line ' ';
            endcomp;

            run;

            %end; /* _temp_agg_profile > 0  */
            %end; /* switch */

            proc datasets library=work nowarn noprint;
            delete _temp_agg_profile _temp_agg_order_profile;
            quit;

            %end; /* where */
%end; /* periodid */

%mend baseline_profile_output;
