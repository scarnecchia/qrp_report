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
						 figure=);

		/* Obtain x and y axis values */
		%let xmin = ;
		%let xmax = ;
		%let xtick = ;
		%let ymin = ;
		%let ymax = ;
		%let ytick = ;
		%let atrisktable = ;

        %let datamin= ;
        %let datamax = ;

        /*select min and max day from input dataset*/
        proc sql noprint;
            select min(day), max(day) into :datamin, :datamax
            from &dataset(where=(&where.));
        quit;

        data _null_;
            set figurefile(where=(figure="&figure."));

            /*set min/max defaults if missing*/
            if missing(xmin) then xmin = &datamin.;
            if missing(xmax) then xmax = &datamax.;

            if missing(ymin) then ymin = 0;
            if missing(ymax) then ymax = 1;

            /*set default tick if missing:
                - 6 total tick marks (min, max, and 4 interim)
                - for x axis - round to the nearest divisor of 1, 5, or 30
                               depending on length of axis                */
            if missing(xtick) then do;
                xmaxminusmin = xmax-xmin;
                if xmaxminusmin <=10 then xtick = round(xmaxminusmin/5, 1);
                else if xmaxminusmin <=120 then xtick = round(xmaxminusmin/5, 5);
                else xtick = round(xmaxminusmin/5, 30);
                xloopcount = 6;
            end;
            else do;
                xloopcount=ceil(divide(xmax-xmin,xtick))+1;
            end;
            if missing(ytick) then do;
                ymaxminusmin = ymax-ymin;
                if ymaxminusmin >.04 then ytick = round(ymaxminusmin/5, .01);
                else ytick = round(ymaxminusmin/5, .001);
                yloopcount = 6;
            end;
            else do;
                yloopcount=ceil(divide(ymax-ymin,ytick));
            end;

            call symputx('xmin', xmin);
            call symputx('xmax', xmax);
            call symputx('xtick', xtick);
            call symputx('ymin', ymin);
            call symputx('ymax', ymax);
            call symputx('ytick', ytick);
            call symputx('xloopcount', xloopcount);
            call symputx('yloopcount', yloopcount);
            call symputx('atrisktable', includeatrisktable);
        run;

        %let xtickmarks = ;
        %let ytickmarks = ;

        %let xloop = &xmin.;
        %let yloop = &ymin.;

        /*xaxis*/
        %let loopcount = 1;
        %do %while(%sysevalf(&loopcount. <=&xloopcount.));
        %if %eval(&loopcount. ne &xloopcount.) %then %do;
        %let xtickmarks = &xtickmarks%str( )&xloop.;
        %end;
        %else %do;
        %let xtickmarks = &xtickmarks%str( )%sysfunc(min(&xmax.,&xloop.));
        %end;
        %let xloop=%sysevalf(&xloop + &xtick);
        %let loopcount = %eval(&loopcount+1);
        %end;
        
        /*yaxis*/
        %let loopcount = 1;
        %do %while(%sysevalf(&loopcount. <=&yloopcount.));
        %if %eval(&loopcount. ne &yloopcount.) %then %do;
        %let ytickmarks = &ytickmarks%str( )&yloop.;
        %end;
        %else %do;
        %let ytickmarks = &ytickmarks%str( )%sysfunc(max(&ymax.,&yloop.));
        %end;
        %let yloop=%sysevalf(&yloop + &ytick);
        %let loopcount = %eval(&loopcount+1);
        %end;

        %tableletter();	
		%isdata(dataset=repdata.Figure&figurenum.&tableletter.);
		%if %eval(&nobs=0) %then %do;
		data repdata.Figure&figurenum.&tableletter.;
		set &dataset(where=(&where));
		/* Only selects days for corresponding tickmarks */
		%if &atrisktable = Y %then %do;
		if day in (&xtickmarks) then dayatrisk=day;
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
			where scan(lower(name),1,'_') in ('km' 'cdf');

			%if &atrisktable = Y %then %do;
			select lower(name)
			into :atriskcols separated by ' '
			from _kmcolnames 
			where scan(lower(name),1,'_') = 'episodes';
			%end;
		quit;

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
            ods excel options(sheet_interval="none" sheet_name = "Figure &figurenum.&tableletter." tab_color="blue" flow='none');
        %end;

		proc odstext pagebreak=yes;
			p "Figure &figurenum.&tableletter.. &figtitle" / style=[just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
		run;

		/* Create KM/CDF plots */
		proc sgplot data=repdata.Figure&figurenum.&tableletter;  
			%do km = 1 %to %sysfunc(countw(&kmcols));
				%let kmcol = %scan(&kmcols,&km);
			step x=day y=&kmcol / lineattrs=(thickness=1.5 pattern=solid);
			%end;
			xaxis label = "&xaxislabel" values=(&xtickmarks) valueattrs=(size=7 color=black) labelattrs=(size=7); 
			yaxis label = "&yaxislabel" values=(&ytickmarks) valueattrs=(size=7 color=black) labelattrs=(size=7);
			%if &atrisktable = Y %then %do;
				xaxistable &atriskcols / %if ^%index(&reporttype,L2) and ((&reporttype=T2L1 and &figure ^= F1) or (&reporttype=T5 and &figure ^= F5)) %then %do; 
										class=grouplabel 
										%end; 
										labelattrs=(size=7)
										x=dayatrisk location=outside nomissingclass nomissingchar pad=(top=10px);
			%end;
			keylegend / valueattrs=(size=7 color=black) position=bottom  noborder linelength=.25in;
		run;

		%if &figfn = Y %then %do;
		proc odstext pagebreak=yes;
			p "A single episode may contribute to multiple categories if a patient was censored due to multiple criteria on the same day." /
				style=[just=L font_size=8pt bordertopcolor=black borderbottomcolor=black];
		run;
		%end;

	%mend output_cdf_km;

		*reset tablecount; 
		%let tablecount = 1;
		%let tableletter =a;

		/***************************************************************************************/
        /* L1 Figures                                                                          */
        /***************************************************************************************/

		%if %sysfunc(prxmatch(m/T1|T2L1|T5|T6/i,&reporttype.)) > 0 %then %do;

			/*Loop through each figure */
			%if %length(&figurelist) > 0 %then %do;
			%do f = 1 %to %sysfunc(countw(&figurelist));
			%let figure = %scan(&figurelist,&f);

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
						 		 yaxislabel=%str(Cumulative probability that censoring reason has not occurred),
								 figure=&figure);
				%end;

				%else %if &reporttype = T2L1 %then %do;
					%if &figure = F1 %then %do;
						%let title = Kaplan-Meier Estimate of Event of Interest Not Occurring;
						%let xaxislabel=%str(Follow-up time (days));
						%let yaxislabel=%str(Cumulative probability that event of interest has not occurred);
					%end;
					%else %if &figure = F2 %then %do;
						%let title = Reasons for End of Follow-Up Among &grouplabel;
						%let xaxislabel=%str(Follow-up time (days));
						%let yaxislabel=%str(Cumulative probability that censoring reason has not occurred);
					%end;
					%else %if &figure = F3 %then %do;
						%let title = Reasons for End of Observable Data Among &grouplabel;
						%let xaxislabel=%str(Time (days));
						%let yaxislabel=%str(Cumulative probability that censoring reason has not occurred);
					%end;
						%output_cdf_km(dataset=figure&figure,
									 where=%str(order = &order.),
									 figtitle=%quote(&title in the &database. from &startdateformatted. to &enddateformatted.),
									 figfn=Y,
									 xaxislabel=&xaxislabel,
						 		 	 yaxislabel=&yaxislabel,
									 figure=&figure);
				%end;

				%else %if &reporttype = T5 %then %do;
					%if &figure = F4 %then %let title = Reasons for End of First Treatment Episode Among &grouplabel;

					%isdata(dataset=figuref5);
	                %if %eval(&nobs.>0) %then %do;
	                    /*Censor reason*/
	                      data _null_;
	                        set figurefile(where=(figure="F5"));
	                        call symputx('censordisplay', censordisplay);
	                      run; 
	                %end;

	                %if &figure = F5 %then %let title = End of First Treatment Episode due to &&&censordisplay._label;
						%output_cdf_km(dataset=figure&figure,
									 where=%str(order=&order.),
									 figtitle=%quote(&title in the &database. from &startdateformatted. to &enddateformatted.),
									 figfn=,
									 xaxislabel=%str(Episode length (days)),
						 		 	 yaxislabel=%str(Cumulative probability that censoring reason has not occurred),
									 figure=&figure);
				%end;

				%else %if &reporttype = T6 %then %do;
					%if &figure = F4 %then %do;
						%let title = Kaplan-Meier Estimate of First Switch Not Occurring;
						%let yaxislabel = %str(Cumulative probability that first switch has not occurred);
					%end;
					%else %if &figure = F5 %then %do;
						%let title = Kaplan-Meier Estimate of Second Switch Not Occurring;
						%let yaxislabel = %str(Cumulative probability that second switch has not occurred);
					%end;
					%else %if &figure = F6 %then %do;
						%let title = Reasons for Censoring at First Switch Evaluation;
						%let yaxislabel = %str(Cumulative probability that censoring reason has not occurred);
					%end;
					%else %if &figure = F7 %then %do;
						%let title = Reasons for Censoring at First Second Evaluation;
						%let yaxislabel = %str(Cumulative probability that censoring reason has not occurred);
					%end;
						%output_cdf_km(dataset=figure&figure,
									 where=%str(order=&order.),
									 figtitle=%quote(&title in the &database. from &startdateformatted. to &enddateformatted.),
									 figfn=,
									 xaxislabel=%str(Follow-up time (days)),
						 		 	 yaxislabel=&yaxislabel,
									 figure=&figure);
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

			/* Increment figure number if other figures are specified */
			%if %sysfunc(prxmatch(m/F1|F2/i,&figurelist.)) > 0 %then %let figurenum = %eval(&figurenum.+1); 

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

                    /*Loop through each figure */
					%do f = 1 %to %sysfunc(countw(&figurelist));
						%let figure = %scan(&figurelist,&f);

                        %do j = %eval(&look_start) %to %eval(&look_end);

                        /*F3*/
                        %isdata(dataset=figureF3_analysis&loopcount._&j.);
                        %if %eval(&nobs.>0) and &figure = F3 %then %do;

                        %output_cdf_km(dataset=figureF3_analysis&loopcount._&j.,
									 where=1,
									 figtitle=%quote(Unadjusted Kaplan-Meier Estimate of &outcomelabel. Not Occurring Among &eoilabel. and &reflabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.),
									 figfn=,
									 xaxislabel=%str(Follow-up time (days)),
									 yaxislabel=%str(Cumulative probability that &outcomelabel. has not occurred),
									 figure=&figure);
                        %end;
                        /*F4*/
                        %isdata(dataset=figureF4_analysis&loopcount._&j.);
                        %if %eval(&nobs.>0) and &figure = F4 %then %do;
                        %output_cdf_km(dataset=figureF4_analysis&loopcount._&j.,
									 where=1,
									 figtitle=%quote(Conditional Kaplan-Meier Estimate of &outcomelabel. Not Occurring Among &eoilabel. and &reflabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.),
									 figfn=,
									 xaxislabel=%str(Follow-up time (days)),
									 yaxislabel=%str(Cumulative probability that &outcomelabel. has not occurred),
									 figure=&figure);
                        %end;
                        /*F5*/
                        %isdata(dataset=figureF5_analysis&loopcount._&j.);
                        %if %eval(&nobs.>0) and &figure = F5 %then %do;
                        %output_cdf_km(dataset=figureF5_analysis&loopcount._&j.,
									 where=1,
									 figtitle=%quote(Unconditional Kaplan-Meier Estimate of &outcomelabel. Not Occurring Among &eoilabel. and &reflabel. in the &database. from &startdateformatted. to &&enddate&j.formatted.),
									 figfn=,
									 xaxislabel=%str(Follow-up time (days)),
									 yaxislabel=%str(Cumulative probability that &outcomelabel. has not occurred),
									 figure=&figure);
                        %end;

	                    %end; /* Monitoring Period */
	                %end; /* figurelist */
	            %end; /* psfile */
	                                          
			%end; /* loopcount */

		%end; /* reporttype */

	%put =====> END MACRO: figure_cdf_km_output;

%mend;
