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
*
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
						 xmin=,
						 xmax=,
						 xtick=,
						 ymin=,
						 ymax=,
						 ytick=,
						 figfn=,
						 atrisktable=,
						 figure=);

	%isdata(dataset=repdata.Figure&figurenum.&tableletter.);
		%if %eval(&nobs=0) %then %do;
		data repdata.Figure&figurenum.&tableletter.;
		set &dataset(where=(&where));
		run;
		%end;


		/* Create KM/CDF plots */
		proc sgplot data=Figure&figurenum.&tableletter;  
			step x=day y=km_estimate lineattrs=(thickness=1.5 pattern=solid) name="s";
			xaxis label = "Days" labelattrs=(size=7 color=black) valueattrs=(size=7 color=black) values=(&xmin. to &xmax. by &xtick.); 
			yaxis label = "Survival Probability" labelattrs=(size=7 color=black) valueattrs=(size=7 color=black) values = (&ymin. to &ymax. by &ytick.); %end; ;
			%if &atrisktable = Y %then %do;
				/*Pass groups here */
				xaxistable  / label="TEST" labelattrs=(size=6)  location=outside nomissingclass nomissingchar;
			%end;
			keylegend "s" / valueattrs=(size=7 color=black) location=inside position=bottom across=1 noborder linelength=.25in;
		run;
	%mend output_cdf_km;

	/*Loop through each figure */
	%do f = 1 %to %sysfunc(countw(&figurelist));
		%let figure = %scan(&figurelist,&f);

		/* Obtain x and y axis values */
		proc sql noprint;
		   select case when xmin > 0 then xmin
		          else 0 end
		         ,case when xmax > 0 then xmax 
		          else (select max(day) from figure&figure)
		         ,case when xtick > 0 then xtick
		          else (select round(max(day)/6,30) from figure&figure)
		         ,case when ymin > 0 then ymin
		         else 0 end 
		         ,case when ymax > 0 then ymax
		         else 1 end 
		         ,case when ytick > 0 then ytick 
		         else 0.2 end
		   into: xmin trimmed
		       ,:xmax trimmed
		       ,:xtick trimmed
		       ,:ymin trimmed 
		       ,:ymax trimmed 
		       ,:ytick trimmed 
		   from figurefile
		   where figure = "&figure.";
		quit;

	%end;

	%put =====> END MACRO: figure_cdf_km_output;

%mend;
