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

%do periodid = %eval(&look_start.) %to %eval(&look_end.);

    /* Reset table letter at top of dataset loop */
    %let tablecount = 1;

    /* Get group orders */
    proc sql noprint ;
        select distinct order
        into :profiletableorders separated by ' '
        from aggregate_profile
        where periodid=&periodid.;
    quit;

    %do d = 1 %to %sysfunc(countw(&profiletableorders,' '));
        %let profiletableorder = %scan(&profiletableorders,&d, ' ');

        data _temp_agg_profile;
            set aggregate_profile(where=(order=&profiletableorder and periodid=&periodid));
        run;

        %isdata(dataset=labelfile);
        %if &nobs > 0 %then %do;
        proc sql noprint undo_policy=none;
            create table _temp_agg_profile as
            select a.*, b.label as grouplabel
            from _temp_agg_profile a 
            left join labelfile(where=(lowcase(labeltype)='grouplabel')) b
            on a.group = b.group and a.runid = b.runid;
        quit;
        %end;
        %else %do;
        data _temp_agg_profile;
            set _temp_agg_profile;
            call missing(grouplabel);
        run;
        %end;

        data final_agg_profilegroup&d._&periodid.;
            set _temp_agg_profile;
            if upcase(covarsort) not in ('A','O','C') then covarsort = 'C'; /*set C as default*/
            call symputx('covarsort', upcase(covarsort));
            if not missing(grouplabel) then call symputx('grouplabel',grouplabel);
            else call symputx('grouplabel',group);
            if lowcase(strip(profilecovarstoinclude)) = 'all' then profilecovarstoinclude = 'covar:';
            call symputx('profilecovarsnocomma', compress(compbl(tranwrd(profilecovarstoinclude,',',', ')),','));
        run;

        *Total npts and n_episodes;
        %let totalpatients =0;
        %let totalepisodes =0;
        proc sql noprint;
            select sum(sum_npts), sum(sum_nepisodes) 
            into :totalpatients, :totalepisodes
            from final_agg_profilegroup&d._&periodid.;
        quit;
        %put &totalpatients &totalepisodes;

        *Determine covariate label and order;
        data covarlabel;
            set final_agg_profilegroup&d._&periodid.(keep=&profilecovarsnocomma. obs=0);
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
            set final_agg_profilegroup&d._&periodid. end=eof;
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
    
        proc sort data=covarswithlabel nodupkey out=repdata.table&tablenum.&tableletter(drop=covar:);
            by sortorder
                %if &covarsort = A %then %do;
                label
                %end;
                %else %do;
                %do i = 1 %to %eval(&numcovars.);
                    descending  %scan(&covarlist., &i.) 
                %end;
                %end;
                ;
        run;

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
                              style(column)=[rules=none width=4.5in just=L] ;
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

        %end;

        %let tablenum = %eval(&tablenum+1);

%end;

%mend baseline_profile_output;