****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: figure_cdf_km_output.sas  
* Created (mm/dd/yyyy): 07/28/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro includes a proc sgplot to produce Kaplan-Meier and Cumulative Distribution
*          Function (CDF) curves with an at-risk table
*                                        
*  Program inputs:                                                                                   
*   - Dataset(s) computed in figure_cdf_km_createdata.sas (L1 plots) or 
*     l2_effect_estimate_km_createdata.sas (L2 plots)
* 
*  Program outputs: 
*   - Dataset(s) to output/repdata for each figure
* 
* 
*  PARAMETERS:  
*   
*            
*  Programming Notes:         
*  Utility macro %output_cdf_km created to execute proc sgplot for each km/cdf plot 
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro figure_cdf_km_output();

	%put =====> MACRO CALLED: figure_cdf_km_output;

	%macro output_cdf_km(dataset=,
						 where=,
						 figtitle=,
						 figfn=,
						 xaxislabel=,
						 yaxislabel=,
						 figure=,
						 font=,
						 analysis=,
						 analysisgrp=,
						 monitoringperiod=,
						 eoi=,
						 ref=,
						 eoilabel=,
						 reflabel=,
						 kmrefpop=);

		/* Obtain x and y axis values */
		%let num_fn = 0;
        %let kmxtickmarks = ;
        %let kmytickmarks = ;

        data _null_;
            set figurefile(where=(figure="&figure."));
            call symputx('atrisktable', includeatrisktable);
        run;

        /*assign axes*/
        %figure_axes(data=&dataset., figure=&figure., figuresub=overall, where=&where., xtickmarks=kmxtickmarks, xvar=day, ytickmarks=kmytickmarks, yvar=);

        %tableletter();	
		%isdata(dataset=repdata.Figure&figurenum.&tableletter.);
		%if %eval(&nobs=0) %then %do;
		data repdata.Figure&figurenum.&tableletter.;
		set &dataset(where=(&where));
		/* Only selects days for corresponding tickmarks */
		%if &atrisktable = Y %then %do;
		if day in (&kmxtickmarks) then xaxisatrisk=day;
		%end;
		/* Add columns for Sentinel Views */
		%if &reporttype = T2L2 and (&figure=F3 or &figure=F4 or &figure=F5) %then %do;
		length monitoringperiod 3 analysis $13 analysisgrp eoi ref $40;
	    analysis="&analysis";
        analysisgrp="&analysisgrp";
        monitoringperiod=&monitoringperiod;
        eoi="&eoi";
        ref="&ref";
        eoilabel="&eoilabel";
        reflabel="&reflabel";
        %end;
		run;
		%end;

		/* Obtain all KM and Episode columns from data */
		proc contents data = repdata.Figure&figurenum.&tableletter. noprint 
					  out=_kmcolnames(keep=name);
		run;

		%let kmcols = ;
		%let atriskcols = ;
		proc sql noprint;
			select lower(name) 
			into :kmcols separated by ' '
			from _kmcolnames
			where
			%if &kmrefpop = unweighted %then %do;
			lower(name) in ('km_evexp' 'km_evunexp') and lower(name) ^= 'km_evunexp_wght'
			%end;
			%else %if &kmrefpop = weighted %then %do;
			lower(name) in ('km_evexp' 'km_evunexp_wght')
			%end;
			%else %do;
			scan(lower(name),1,'_') in ('km' 'cdf')
			%end;
			order by lower(name);

			%if (&reporttype = T2L2 or &reporttype = T4L2) and &kmrefpop. = unweighted %then %do;
			select lower(name) 
			into :lowercicols separated by ' '
			from _kmcolnames
			where lower(name) in ('lowerci_exp' 'lowerci_unexp')
			order by lower(name);
			
			select lower(name) 
			into :uppercicols separated by ' '
			from _kmcolnames
			where lower(name) in ('upperci_exp' 'upperci_unexp')
			order by lower(name);
			%end;

			%if &atrisktable = Y %then %do;
			select lower(name)
			into :atriskcols separated by ' '
			from _kmcolnames 
			where
			%if &kmrefpop = unweighted %then %do;
			lower(name) in ('episodes_atriskexp' 'episodes_atriskunexp') and lower(name) ^= 'episodes_atriskunexp_wght'
			%end;
			%else %if &kmrefpop = weighted %then %do;
			lower(name) in ('episodes_atriskexp' 'episodes_atriskunexp_wght')
			%end;
			%else %do;
			scan(lower(name),1,'_') = 'episodes'
			%end;
			order by lower(name);
			%end;
		quit;

		/* Check for when no episodes occur in data */
		%isdata(dataset=repdata.Figure&figurenum.&tableletter.);
		%if %eval(&nobs=1) %then %do;
		data repdata.Figure&figurenum.&tableletter.;
		set repdata.Figure&figurenum.&tableletter.;
		if &xmin ne 0 then xaxisatrisk=0;
		run;
		%end;

		ods startpage = now;
  		ods startpage = no;
  		ods graphics / height=7in;

		/* Trick Excel into making a new sheet */
		%if &destination. = excel %then %do;
                ods excel options(sheet_interval="table");
                ods exclude all;
                data _null_;
                file print;
                put _all_;
                run;
                ods select all;
		%end;

        %if &destination. = excel %then %do;
            ods excel options(sheet_interval="none" sheet_name = "Figure &figurenum.&tableletter." tab_color="DarkBlue" flow='none');
        %end;

        %if &destination. = pdf %then %do;
		ODS PDF BOOKMARKGEN = ON; 
		ods proclabel = "Figure &figurenum.&tableletter.";
		%end;

		%if &figfn = Y %then %do;
		data _footnotes;
            length footnote_order 3; 
            set lookup.lookup_footnotes(where = (type = "kmcdf"));
            by order;
            footnote_order = _n_;
            call symputx('num_fn', 1);
        run;

        proc sql noprint;
            select description into: fn1 - :fn&num_fn.
            from _footnotes
            order by order;
        quit;

        %assign_superscripts(type=kmcdf, order = 1);
        %end;
        %else %do;
        	%let super_kmcdf=;
        %end;

        proc odstext;
			p "Figure &figurenum.&tableletter.. &figtitle.&super_kmcdf." / style=[just=L font_weight=bold bordertopcolor=black borderbottomcolor=black tagattr='mergeacross:18'];
		run;

		%if &destination. = pdf %then %do;
		ODS PDF BOOKMARKGEN = OFF; 
		%end;

		%let datacolors=DarkBlue DarkGreen DarkPurple DarkRed DarkOrange Black DarkBrown Magenta Yellow Skyblue Chartreuse Pink Maroon Grey LightPurple Tomato Olive Aqua LightRed GreenYellow DarkSlateGray DarkCyan Violet Goldenrod MediumAquamarine;

		/* Create KM/CDF plots */
		proc sgplot data=repdata.Figure&figurenum.&tableletter noborder;
			%if (&reporttype. ne T2L2 and &reporttype. ne T4L2) %then %do;
				styleattrs datacontrastcolors=(DarkBlue DarkGreen DarkPurple DarkRed DarkOrange Black DarkBrown Magenta 
											  Yellow Skyblue Chartreuse Pink Maroon Grey LightPurple Tomato Olive Aqua 
											  LightRed GreenYellow DarkSlateGray DarkCyan Violet Goldenrod MediumAquamarine);
			%end; /*L1 report type*/

			%do km = 1 %to %sysfunc(countw(&kmcols));				
				%let kmcol = %scan(&kmcols,&km);
				
				%if (&reporttype. = T2L2 or &reporttype. = T4L2) %then %do;
					%let kmcolor=%scan(&datacolors., &km.);

					* L2 report type: use colors specified in datacolors macro variable since datacontrastcolors does not work with band statement;
					step x=day y=&kmcol. / lineattrs=(color=&kmcolor. thickness=2 pattern=solid);

					* Plot CI only if unweighted;
					%if &kmrefpop. = unweighted %then %do;
						%let lowercicol = %scan(&lowercicols,&km);
						%let uppercicol = %scan(&uppercicols,&km);

						band x=day lower=&lowercicol. upper=&uppercicol. / fillattrs=(color=&kmcolor. transparency=0.8) legendlabel='95% CI';
					%end;
				%end; /*L2 report type*/
				%else %do;
					* L1 report type: use colors specified in datacontrastcolors to allow more than 25 curves to be handled correctly;
					step x=day y=&kmcol. / lineattrs=(thickness=2 pattern=solid);
				%end; /*L1 report type*/	
			%end;
			xaxis label = "&xaxislabel" values=(&kmxtickmarks) valueattrs=(size=&fontsize. family=&font.) labelattrs=(size=&fontsize family=&font); 
			yaxis label = "&yaxislabel" values=(&kmytickmarks) valueattrs=(size=&fontsize. family=&font.) labelattrs=(size=&fontsize family=&font);
			%if &atrisktable = Y %then %do;
				xaxistable &atriskcols / %if %sysfunc(prxmatch(m/T1|T6/i,&reporttype.)) or (&reporttype=T2L1 and &figure ^= F1) or (&reporttype=T5 and &figure = F4) %then %do; 
										class=grouplabel /* Only one group per plot, but class statement applies label to xaxis table columns */
										%end; 
										labelattrs=(size=&fontsize family=&font)
										valueattrs=(size=&fontsize family=&font)
										x=xaxisatrisk location=outside nomissingclass nomissingchar;
										format &atriskcols comma12.;
			%end;
			keylegend / valueattrs=(size=&footfontsize family=&font) across=3 position=bottom noborder linelength=.25in exclude=("95% CI");
		run;

		%if &figfn = Y %then %do;
		/* Only one footnote for now - May change in the future */
		proc odstext;
			%do fnote = 1 %to &num_fn.;
				p "^{super &fnote.}&&fn&fnote." / style=[just=L font_size=&footfontsize];
			%end;
		run; 
		%end;

	%if &destination. = pdf %then %do;
	 ODS PDF BOOKMARKGEN = ON;
	%end; 

	%mend output_cdf_km;
		*reset tablecount; 
		%let tablecount = 1;
		%let tableletter =a;

		/* Determine font for KM/CDF plot */
        %if &sysscp = WIN %then %let fontfamily="Calibri";
        %else %let fontfamily="Albany AMT";

		/***************************************************************************************/
        /* L1 Figures                                                                          */
        /***************************************************************************************/

		%if %sysfunc(prxmatch(m/T1|T2L1|T5|T6/i,&reporttype.)) > 0 %then %do;

			/*Loop through each figure */
			%if %length(&figurelist) > 0 %then %do;
			%do f = 1 %to %sysfunc(countw(&figurelist));
			  %let figure = %scan(&figurelist,&f);
			    %let figurenum = &f;
		 		%isdata(dataset=figure&figure.);
		 		%let fignobs = &nobs;
                %if %eval(&fignobs.>0) %then %do;

                /*number of distinct groups in figure to loop through determine whether to add letter to figure #*/
                proc sql noprint;
                    select distinct order
                    into :fgrouporderlist separated by ' '
                    from figure&figure.
                    order by order;
                quit;
         
                %if %sysfunc(countw(&fgrouporderlist.)) = 1 %then %let tablecount = 0;
                %else %let tablecount = 1;

                %do g = 1 %to %sysfunc(countw(&fgrouporderlist.));
                    %let order = %scan(&fgrouporderlist., &g.);
                    %let grouplabel = ;
                    %let switch2indicator = ;
                    data _null_;
                        set figure&figure.(where=(order = &order.));
                        if _n_ = 1 then do;
                        call symputx('grouplabel', grouplabel);
                        end;
                    run;

				/* Call SGPLOT macro */
				%if &reporttype = T1 %then %do;
					%output_cdf_km(dataset=figure&figure,
								 where=%str(order = &order.),
								 figtitle=%quote(Reasons for End of Observable Data Among &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.),
								 figfn=Y,
								 xaxislabel=%str(Time (days)),
						 		 yaxislabel=%str(Cumulative probability that censoring reason(*ESC*){unicode '000A'x} has not occurred),
								 figure=&figure,
								 font=&fontfamily,
								 kmrefpop=);
				%end;

				%else %if &reporttype = T2L1 %then %do;
					%if &figure = F1 %then %do;
						%let title = Kaplan-Meier Estimate of Event of Interest Not Occurring;
						%let xaxislabel=%str(Follow-up time (days));
						%let yaxislabel=%str(Cumulative probability that event of interest(*ESC*){unicode '000A'x} has not occurred);
					%end;
					%else %if &figure = F2 %then %do;
						%let title = Reasons for End of Follow-Up Among &grouplabel;
						%let xaxislabel=%str(Follow-up time (days));
						%let yaxislabel=%str(Cumulative probability that censoring reason(*ESC*){unicode '000A'x} has not occurred);
					%end;
					%else %if &figure = F3 %then %do;
						%let title = Reasons for End of Observable Data Among &grouplabel;
						%let xaxislabel=%str(Time (days));
						%let yaxislabel=%str(Cumulative probability that censoring reason(*ESC*){unicode '000A'x} has not occurred);
					%end;
						%output_cdf_km(dataset=figure&figure,
									 where=%str(order = &order.),
									 figtitle=%quote(&title in the &database. from &startdateformatted. to &enddateformatted.),
									 figfn=Y,
									 xaxislabel=&xaxislabel,
						 		 	 yaxislabel=&yaxislabel,
									 figure=&figure,
									 font=&fontfamily,
									 kmrefpop=);
				%end;

				%else %if &reporttype = T5 %then %do;
					%isdata(dataset=figuref5);
	                %if %eval(&nobs.>0) %then %do;
	                    /*Censor reason*/
	                      data _null_;
	                        set figurefile(where=(figure="F5"));
	                        call symputx('censordisplay', censordisplay);
	                      run; 
	                %end;

	                %if &figure = F4 %then %let title = Reasons for End of First Treatment Episode Among &grouplabel;
	                %if &figure = F5 %then %let title = End of First Treatment Episode due to &&&censordisplay._label;
						%output_cdf_km(dataset=figure&figure,
									 where=%str(order=&order.),
									 figtitle=%quote(&title in the &database. from &startdateformatted. to &enddateformatted.),
									 figfn=,
									 xaxislabel=%str(Episode length (days)),
						 		 	 yaxislabel=%str(Cumulative probability that censoring reason(*ESC*){unicode '000A'x} has not occurred),
									 figure=&figure,
									 font=&fontfamily,
									 kmrefpop=);
				%end;

				%else %if &reporttype = T6 %then %do;
					%if &figure = F4 %then %do;
						%let title = Kaplan-Meier Estimate of First Switch Not Occurring Among &grouplabel.;
						%let xaxislabel = %str(Follow-up time until first switch or censoring (days));
						%let yaxislabel = %str(Cumulative probability that first switch(*ESC*){unicode '000A'x} has not occurred);
					%end;
					%else %if &figure = F5 %then %do;
						%let title = Kaplan-Meier Estimate of Second Switch Not Occurring Among &grouplabel.;
						%let xaxislabel = %str(Follow-up time since first switch until second switch or censoring (days));
						%let yaxislabel = %str(Cumulative probability that second switch(*ESC*){unicode '000A'x} has not occurred);
					%end;
					%else %if &figure = F6 %then %do;
						%let title = Reasons for Censoring at First Switch Evaluation Among &grouplabel.;
						%let xaxislabel = %str(Follow-up time until first switch or censoring (days));
						%let yaxislabel = %str(Cumulative probability that censoring reason(*ESC*){unicode '000A'x} has not occurred);
					%end;
					%else %if &figure = F7 %then %do;
						%let title = Reasons for Censoring at Second Switch Evaluation Among &grouplabel.;
						%let xaxislabel = %str(Follow-up time since first switch until second switch or censoring (days));
						%let yaxislabel = %str(Cumulative probability that censoring reason(*ESC*){unicode '000A'x} has not occurred);
					%end;
                      

						%output_cdf_km(dataset=figure&figure,
									 where=%str(order=&order.),
									 figtitle=%quote(&title in the &database. from &startdateformatted. to &enddateformatted.),
									 figfn=,
									 xaxislabel=&xaxislabel,
						 		 	 yaxislabel=&yaxislabel,
									 figure=&figure,
									 font=&fontfamily,
									 kmrefpop=);
				%end;
     
				%end; /* order loop */
				%let figurenum=%eval(&figurenum+1);

				%end; /* fignobs */

			%end; /* f */
		%end; /* figurelist */

		%end; /* reporttype */


		/***************************************************************************************/
        /* T2L2 Figures                                                                        */
        /***************************************************************************************/

		%else %if &reporttype. = T2L2 & %sysfunc(prxmatch(m/F3|F4|F5/i,&figurelist.)) > 0 %then %do;
		   /* If there is only 1 figure, rewrite figure # - this method is used instead of determining apriori b/c of 
              the numerous permutations of situations that can lead to 1 figure */ 
		   
           proc sql noprint;
             select count(caption) into: countkm
             from tableofcontents
             where index(caption, 'Kaplan-Meier Estimate')>0;
           quit;

           %if &countkm = 1 %then %let tablecount = 0;

		   %do j = %eval(&look_start) %to %eval(&look_end);

        	/*loop through each analysisgrp - dataset only exists if curve computed*/
			%do loopcount = 1 %to &numl2comparisons.;   

                    data _null_;
                        set l2comparisonfile(where=(order=&loopcount.));
		                call symputx('runid', runid);
		                call symputx('analysisgrp', analysisgrp);
		                call symputx('kmrefpop',kmrefpop);
                    run;
                    
					/* KM plots not available for PS Stratum Weighted analysis */
                    proc sql noprint;
                    	%let strataweight = ;
                        select distinct strip(file)
           					  ,strataweight
						into: pscsfile trimmed
						    ,:strataweight trimmed
                        from pscs_masterinputs
                        where analysisgrp = "&analysisgrp." and runid = "&runid" and missing(subgroup);
                    quit;

                    %if &pscsfile. = psmatchfile | &pscsfile. = stratificationfile | &pscsfile. = iptwfile %then %do;

                        /*assign labels*/
                        data _null_; 
                            set pscs_masterinputs(where=(analysisgrp="&analysisgrp." and missing(subgroup)));
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
						%let AnalysisGroupLabel = &analysisgrp.;
						%let PSEstimateGroupLabel = &psestimategrp.;

                        %isdata(dataset=labelfile);
                        %if %eval(&nobs.>0) %then %do;
                            data _null_;
                                set labelfile(in=a where=(group="&analysisgrp" and runid = "&runid" and labeltype = "outcomelabel"))
                                    labelfile(in=b where=(group="&grp1." and runid = "&runid." and labeltype = "grouplabel"))
                                    labelfile(in=c where=(group="&grp0." and runid = "&runid." and labeltype = "grouplabel"))
									labelfile(in=d where=(group="&analysisgrp" and runid = "&runid" and labeltype = "grouplabel"))
									labelfile(in=e where=(group="&psestimategrp" and runid = "&runid" and labeltype = "grouplabel"))
									;

                                if a then call symputx('outcomelabel', label);
                                if b then call symputx('eoilabel', label);
                                if c then call symputx('reflabel', label);
								if d then call symputx('AnalysisGroupLabel', label);
								if e then call symputx('PSEstimateGroupLabel', label);
                            run;
                        %end;                    
                
						%let numsubgroups=0;
						%let subgroup=;
						%let subgroupcat=;
						%let subgrouptitle=;

						proc sort nodupkey data=Pscs_masterinputs(where=(analysisgrp="&analysisgrp." and runid="&runid." and not missing(subgroup))) 
											   out=_subgroups(keep=subgroup subgroupcat subgrouporder subgroupcatorder combinedlabel);
						by subgrouporder subgroupcatorder;
						run;

						proc sql noprint;
						select count(*) into :numsubgroups from _subgroups;
						quit;

						%let F3nobs = 0;
						%let F4nobs = 0;
						%let F5nobs = 0;

						%let numkm = 0;
						proc sql noprint;
						    select count(caption) into: numkm
						    from tableofcontents
						    where index(tabnum, "Figure &figurenum.")>0;
						quit;

						%if %eval(&numkm.)=1 %then %do;
						    %let tablecount = 0;
						%end; 

						%do sub=0 %to &numsubgroups.;

							%if &sub. > 0 %then %do;
								data _null_;
								set _subgroups;
								if _N_=&sub.;
								call symputx("SubGroup",lowcase(strip(subgroup)));
							    call symputx("SubgroupCat",upcase(strip(subgroupcat)));
								call symputx("subgrouptitle",combinedlabel);
								run;

							%end;			

							%put Looping on subgroup &SubGroup.: &SubgroupCat.;

							/*Loop through each figure */
							%do f = 1 %to %sysfunc(countw(&figurelist));
								%let figure = %scan(&figurelist,&f);								

		                        /*F3, F4 and/or F5*/
		                        %isdata(dataset=figure&figure._analysis&loopcount._&j.);
								%let &figure.nobs = &nobs.;
		                        %if %eval(&nobs.>0) %then %do;

									%let max_day=0;
									
									proc sql noprint;
										select max(day) into :max_day
										from figure&figure._analysis&loopcount._&j. 
										where subgroup="&subgroup." and subgroupcat="&subgroupcat.";
									quit;

									%if &max_day. > 0 %then %do;
				                        %if &figure = F3 %then %let titlestart=Unadjusted;
				                        %else %let titlestart=Adjusted;

										%if &titlestart. = Unadjusted %then %let PSEstimateGroupLabelT=;
										%else %do; %let PSEstimateGroupLabelT=&PSEstimateGroupLabel.; %end;

										%if &titlestart. = Unadjusted %then %let pop=Whole Population;
										%else %if &figure = F4 and &pscsfile. = psmatchfile %then %let pop=Conditional Matched Population after;
										%else %if &figure = F5 and &pscsfile. = psmatchfile %then %let pop=Unconditional Matched Population after;
										%else %if &pscsfile. = stratificationfile | &pscsfile. = iptwfile %then %let pop=Weighted Population after;

										%if &figure ^= F4 or &kmrefpop. = unweighted %then %let cititle=%str(and 95% Confidence Interval);
										%else %let cititle=; 

				                        %output_cdf_km(dataset=figure&figure._analysis&loopcount._&j.,
													 where=%str(subgroup="&subgroup" and subgroupcat="&subgroupcat"),
													 figtitle=%quote(&titlestart. Kaplan-Meier Estimate&cititle. of &outcomelabel. Not Occurring Among &AnalysisGroupLabel. from the &pop. &PSEstimateGroupLabelT. in the &database. from &startdateformatted. to &&enddate&j.formatted.&subgrouptitle.),
													 figfn=,
													 xaxislabel=%str(Follow-up time (days)),
													 yaxislabel=%str(Cumulative probability that &outcomelabel.(*ESC*){unicode '000A'x} has not occurred),
													 figure=&figure,
													 font=&fontfamily,
													 analysis=&titlestart,
													 analysisgrp=&analysisgrp,
													 monitoringperiod=&j,
													 eoi=&GRP1,
													 ref=&GRP0,
													 eoilabel=&eoilabel,
													 reflabel=&reflabel,
													 %if &figure ^= F4 %then %do; 
													 kmrefpop=unweighted 
													 %end;
													 %else %do; 
													 kmrefpop=&kmrefpop 
													 %end;);

									%end; /* sufficient data to plot the figure */
		                        %end; /* &nobs.>0 */
							%end; /* figurelist */ 
	                	%end; /* subgroups */

						%if %eval(&F3nobs.>0) | %eval(&F4nobs.>0) | %eval(&F5nobs.>0) %then %do;
							%let figurenum=%eval(&figurenum+1); 
							%let tablecount = 1;
							%let tableletter =a; 
						%end;

	            	%end; /* psfile */	  
			 	%end; /* loopcount */
			%end; /* Monitoring Period */
		%end; /* reporttype */

    proc datasets nowarn nolist noprint lib=work;
        delete _kmcols sample;
    quit;

	ods graphics / reset=height;

	%put =====> END MACRO: figure_cdf_km_output;

%mend;
