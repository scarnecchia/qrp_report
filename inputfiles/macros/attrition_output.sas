****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: attrition_output.sas  
* Created (mm/dd/yyyy): 05/18/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro outputs patient and/or episode level attrition data
*                                        
*  Program inputs:                                                                                   
*   - agg_patient_attrition
*	- agg_episode_attrition
* 
*  Program outputs: 
* 
*   -repdata.table&tablenum.&tableletter.
* 
*  PARAMETERS:
*   -tabletype - patient - Output patient-level attrition table
*              - episode - Output episode-level attrition table                                                                     
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

%macro attrition_output(tabletype=);
    %if &&attrition_&tabletype > 0 %then %do;
    %tableletter();

        /*initialize macro variables for footnotes*/
        %let num_fn = 0;
        %if %lowcase(&tabletype.) = episode %then %let num_fn = 1;
        %if %index(&reporttype,T4) %then %let num_fn = 2;		

        %let exclincl = N;
        %let milexcl = N;
        %let claim_level_descr = &tabletype.;

        data repdata.table&tablenum.&tableletter.;
            set agg_&tabletype._attrition&attrperiodid;
            if index(lowcase(report_descr), 'evidence of')>0 then do;
                call symputx('num_fn', %eval(&num_fn.+1));
                if claim_level = 'MIL' then call symputx('milexcl', 'Y'); /*to mark which row to apply superscript*/
                if claim_level ne 'MIL' then call symputx('exclincl', 'Y');
            end;
            %if %index(&reporttype,T4) %then %do; call symputx('claim_level_descr', 'Pregnancy episodes'); %end;
            %else %if &tabletype = episode %then %do; call symputx('claim_level_descr', 'Episodes'); %end;
            %else %if &tabletype = patient %then %do; call symputx('claim_level_descr', 'Patients'); %end;

            %if %index(&reporttype,T2L2) %then %do;
            length monitoringperiod 3;
            monitoringperiod=&j;
            %end;
        run;
				
        %if %eval(&num_fn.>0) %then %do;

		     proc sort data =lookup.lookup_footnotes out = lookup_footnotes; 
              by order;
			run;

            data _footnotes;               
               set lookup_footnotes (where = (
			        /*only need the title footnote when attrition contains both member and episode*/
                    %if %lowcase(&tabletype.) = episode  %then %do;
					  (type = "attrition" and order < 99)
					%end;
					%else  %do;
                      (type = "attrition" and 99 > order > 0)
					%end;
                    %if %index(&reporttype,T4) > 0 %then %do; or (type='type4' and order in (-2)) %end;					
               ));
               by order;			   
            run;      

            proc sql noprint;
              select description into: fn1 - :fn&num_fn.
              from _footnotes
              order by order;
            quit;

            /* Assign macro variables for superscipts */
			%if %lowcase(&tabletype.) = episode  %then %do;
              %assign_superscripts(type =title_me, order =  -3);
    		%end;
			%else %do; %assign_superscripts(type =title_me, order = ); %end;
			%assign_superscripts(type =title, order = -2);
    		%assign_superscripts(type =exclincl, order = 1);

            proc datasets noprint nowarn lib = work;
	          delete _footnotes;
	         quit;
        %end;
        %if %eval(&num_fn.=0) %then %do;
            /* Assign macro variables for superscipts */
		    %assign_superscripts(type =title_me, order = );
    		%assign_superscripts(type =title, order = );
    		%assign_superscripts(type =exclincl, order = );
        %end;

		/* Add footnote for collapsed levels if L2 analysis. Will be the last footnote in the table. */
		%if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
			%let num_fn = %eval(&num_fn. + 1);
			proc sql noprint;
              select description into :fn&num_fn.
              from lookup.lookup_footnotes
              where type = "attrition" and order eq 99;
            quit;
		%end;

		/* Collapse adjusted attrition levels 2 to 7 */
		%if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
			data _L2noncollapse
				 _L2collapse;
			set repdata.table&tablenum.&tableletter.(where=(claim_level eq "L2"));
			if 2002 <= level <= 2007 then output _L2collapse;
			else output _L2noncollapse;
			run;

			proc means data=_L2collapse nway noprint;
			class runid group claim_level eoireforder grouplabel headerlabel attrorder %if %index(&reporttype,T2) %then %do; T2CohortDef monitoringperiod %end; %else %do; T4CohortDef %end;;
			var agg_remaining agg_excluded;
			output out=_L2collapse(drop=_:) sum=;
			run;

			data _L2collapse;
			set _L2collapse;
			agg_remaining_char=strip(put(agg_remaining,comma12.));
		  	agg_excluded_char=strip(put(agg_excluded,comma12.));	  				
			run;

			data repdata.table&tablenum.&tableletter.;
			set repdata.table&tablenum.&tableletter.(where=(claim_level ne "L2"))
				_L2collapse(in=b)
				_L2noncollapse;
			if b then do;
				report_descr="Excluded due to ineligibility for comparative analysis^{super &num_fn.}";
				level=2002;
			end;
			run;
		%end;

        %if &destination = excel %then %do;
        ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="teal" flow="1:400");
        %end;
        ods proclabel = "Table &tablenum.&tableletter.";
        proc report data=repdata.table&tablenum.&tableletter. nofs nowd spanrows missing
            style(header)=[rules=none frame=void vjust=b borderbottomcolor=bgr bordertopcolor=bgr background=bgr borderleftcolor=bgr] split='*'
            style(report)=[rules=none frame=void cellpadding=1.75pt];
            column report_descr (headerlabel,(grouplabel,(agg_remaining_char agg_excluded_char))) dummyvar;
            define report_descr / group order=data ' ' style(column)=[just=L] 
                                                       style(header)=[background = bgr borderleftcolor= bgr borderrightcolor=bgr];
            define headerlabel / nozero across order=data ' ' style(header)=[rules=none vjust=b borderbottomcolor=black background=bgr borderrightcolor=black 
                                                                  borderleftcolor=black borderleftwidth=1 borderrightwidth=1];

            define grouplabel / nozero across order=data ' '  style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black background=bgr borderrightcolor=black 
                                                                  borderleftcolor=black borderleftwidth=1 borderrightwidth=1];

            define agg_remaining_char / display 'Remaining' style(column)=[background=$backgroundfmt. tagattr="type:string"] 
                                                            style(header)=[background = bgr borderleftcolor=black borderleftwidth=1 borderrightcolor=bgr] format=$nafmt.;

            define agg_excluded_char / display 'Excluded' style(column)=[background=$backgroundfmt. tagattr="type:string"]
                                                          style(header)=[background = bgr borderleftcolor=bgr borderrightcolor=black borderrightwidth=1] format=$nafmt.;
			
			define dummyvar / computed noprint;

            /*indent exclusion/inclusion criteria and add footnote*/
            compute report_descr;
                if find(report_descr,'evidence of','i') then call define (_col_,"style","style=[pretext='     ' asis=on fontstyle=italic]");
                %if %eval(&num_fn > 0) %then %do;
                    %if &exclincl = Y %then %do;
                        if report_descr = 'Met inclusion and exclusion criteria' then report_descr = catt(report_descr,"&super_exclincl.");
                    %end;
                    %if &milexcl = Y %then %do;
                        if report_descr = 'Mother met inclusion and exclusion criteria' then report_descr = catt(report_descr,"&super_exclincl.");
                    %end;
                %end;
            endcomp;

            compute dummyvar;
             dummyvar=1;
            endcomp;

            /*Add title*/
            compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                           borderbottomwidth=&bordersize tagattr="wrap:no" cellheight=.3in];
            line "Table &tablenum.&tableletter.. Summary of %sysfunc(propcase(&tabletype))-Level&super_title_me. Cohort Attrition in the &database. from &startdateformatted. to &&enddate&j.formatted.&super_title.";
            endcomp;

          
            /*Add header rows*/
            compute before report_descr / style=[background=libgr foreground=black just=L font_weight=bold bordertopcolor=black bordertopwidth=1 borderbottomcolor=black];
            length text $100;
            %if &tabletype = episode %then %do;
            if report_descr = 'Enrolled at any point during the query period' then do; 
                text='Members meeting enrollment and demographic requirements'; 
                num=100;
            end;
			else if report_descr = 'Had any cohort-defining claim during the query period' or
                    report_descr = 'Had a pregnancy outcome claim during the query period' then do; 
                text='Members with a valid index event'; 
                num=100;
            end;
            else if report_descr = 'Total number of claims with cohort-identifying codes during the query period' then do; 
                text='Cohort episodes with a valid index date'; 
                num=100;
            end;
            else if report_descr = 'Total number of pregnancy outcomes during the query period' then do; 
                text='Pregnancy outcomes with a valid index date'; 
                num=100;
            end;				
            else if report_descr = 'Pregnancy episodes met initial cohort eligibility requirements' then do; 
                text='Members meeting mother-infant linkage requirements'; 
                num=100;
            end;				
            else if report_descr = 'Had sufficient pre-index continuous enrollment' then do; 
                %if %index(&reporttype,T4) %then %do;
                text='Pregnancy episodes with required pre-index history'; 
                %end;
                %else %do;
                text='Cohort episodes with required pre-index history'; 
                %end;
                num=100;
            end;
            else if report_descr = 'Had sufficient continuous enrollment post pregnancy outcome' then do; 
                %if %index(&reporttype,T4) %then %do;
                text='Pregnancy episodes with required post-index follow-up'; 
                %end;
                %else %do;
                text='Cohort episodes with required post-index follow-up'; 
                %end;
                num=100;
            end;
            else if report_descr = 'Number of members' then do; 
                text='Final cohort'; 
                num=100;
            end;
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            else if index(report_descr, 'Excluded due to ineligibility for comparative analysis') > 0 then do;
                text='Members meeting comparative cohort eligibility requirements';
                num=100;
            end;
            else if report_descr='Number of events in comparative analysis' then do;
                text='Additional information';
                num=100;
            end;
            %end;
            else do;
              text=' ';
              num=0;
            end;
            line text $Varying. num; 
            endcomp;
            %end;

            %else %if &tabletype = patient %then %do;
            if report_descr = 'Enrolled at any point during the query period' then do; 
                text='Members meeting enrollment and demographic requirements'; 
                num=100;
            end;
		    else if report_descr = 'Had any cohort-defining claim during the query period' then do; 
                text='Members with a valid index event'; 
                num=100;
            end;
			else if report_descr = 'Had sufficient pre-index continuous enrollment' then do; 
                text='Members with required pre-index history'; 
                num=100;
            end;
            else if report_descr = 'Had sufficient pre-index continuous enrollment' then do; 
                text='Members with required pre-index history'; 
                num=100;
            end;
            else if report_descr = 'Had sufficient post-index continuous enrollment' then do; 
                text='Members with required post-index follow-up'; 
                num=100;
            end;
            else if report_descr = 'Number of members' then do; 
                text='Final cohort'; 
                num=100;
            end;
            %if %sysfunc(prxmatch(m/T2L2|T4L2/i,&reporttype.)) > 0 %then %do;
            else if index(report_descr, 'Excluded due to ineligibility for comparative analysis') > 0 then do;
                text='Members meeting comparative cohort eligibility requirements';
                num=100;
            end;
            else if report_descr='Number of events in comparative analysis' then do;
                text='Additional information';
                num=100;
            end;
            %end;
            else do;
              text=' ';
              num=0;
            end;
            line text $Varying. num; 
            endcomp;
            %end;

            /* Add Footnotes */
            %if %eval(&num_fn > 0) %then %do;
                compute after / style=[just=L borderbottomcolor=white bordertopcolor=black vjust=T fontsize=&footfontsize. bordertopwidth = &bordersize];
    		    %do f = 1 %to &num_fn.;
			     line "^{super &f.}&&fn&f.";
				%end;
                endcomp;
            %end;
            %else %do;
                /*Add thick line to bottom of report*/
                compute after _page_ / style=[bordertopcolor=black bordertopwidth=&bordersize borderbottomcolor=white borderleftcolor=white borderrightcolor=white];
                line ' ';
                endcomp;
            %end;
        run;

    %end; /* attrition table type */

%mend attrition_output;
