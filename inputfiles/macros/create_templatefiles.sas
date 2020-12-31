*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_templatefiles.sas  
* Created (mm/dd/yyyy): 12/31/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates all files that reside in the templatefiles. These are example input files
*          that either represent report defaults or can be modified for inclusion in the reporting package
* 
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*   
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

%macro create_templatefiles();

    /*Multiple Events Tables*/

    %let stratalist = agegroup| year| sex| year month| race| hispanic| zip3| state| hhs_reg| cb_reg| adherence;

    data lookup_t2multevent;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 includeinreport;
        format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 $55.;

        includeinreport = 'N';

        /*Table T1*/
        dataset = 't2multevent';
        table = 'T1';

            /*Overall table*/
            tablesub = 'overall';
            tablesubstrat = '';
            levelnum =1;
            levelid1 = '';
            levelid2 = '';
            output;
            tablesub = 'overall';
            tablesubstrat = 'followup_cat';
            levelnum =1;
            levelid1 = 'followup_cat';
            levelid2 = '';
            output;
            tablesub = 'overall';
            tablesubstrat = 'epi_count';
            levelnum =1;
            levelid1 = 'epi_count';
            levelid2 = '';
            output;

            /*Stratified tables*/
            %do i =1 %to 11;
            %let sub = %scan(%str(&stratalist.), &i, '|');
                tablesub = "&sub";
                tablesubstrat = '';
                levelnum =1;
                levelid1 = "&sub";
                levelid2 = '';
                output;
                tablesub = "&sub";
                tablesubstrat = 'followup_cat';
                levelnum =1;
                levelid1 = "&sub followup_cat";
                levelid2 = '';
                output;
                tablesub = "&sub";
                tablesubstrat = 'epi_count';
                levelnum =1;
                levelid1 = "&sub epi_count";
                levelid2 = '';
                output;
            %end;

        /*Table T2*/
        table = 'T2';
            /*Overall table*/
            tablesub = 'overall';
            tablesubstrat = '';
            levelnum =1;
            levelid1 = '';
            levelid2 = 'time_to_epi';
            output;
            tablesub = 'overall';
            tablesubstrat = 'followup_cat';
            levelnum =1;
            levelid1 = 'followup_cat';
            levelid2 = 'followup_cat time_to_epi';
            output;
            tablesub = 'overall';
            tablesubstrat = 'epi_count';
            levelnum =1;
            levelid1 = 'epi_count';
            levelid2 = 'epi_count time_to_epi';
            output;
            tablesub = 'overall';
            tablesubstrat = 'time_to_epi';
            levelnum =1;
            levelid1 = 'time_to_epi';
            levelid2 = 'time_to_epi';
            output;
            tablesub = 'overall';
            tablesubstrat = 'adherence';
            levelnum =1;
            levelid1 = 'adherence';
            levelid2 = 'adherence time_to_epi';
            output;
            tablesub = 'overall';
            tablesubstrat = 'adherence_#';
            levelnum =1;
            levelid1 = 'adherence_#';
            levelid2 = 'adherence_# time_to_epi';
            output;

            /*Stratified tables*/
            %do i =1 %to 10;
            %let sub = %scan(%str(&stratalist.), &i, '|');
                tablesub = "&sub";
                tablesubstrat = '';
                levelnum =1;
                levelid1 = "&sub.";
                levelid2 = "&sub. time_to_epi";
                output;
                tablesub = "&sub.";
                tablesubstrat = 'followup_cat';
                levelnum =1;
                levelid1 = "&sub. followup_cat";
                levelid2 = "&sub. followup_cat time_to_epi";
                output;
                tablesub = "&sub.";
                tablesubstrat = 'epi_count';
                levelnum =1;
                levelid1 = "&sub. epi_count";
                levelid2 = "&sub. epi_count time_to_epi";
                output;
                tablesub = "&sub.";
                tablesubstrat = 'time_to_epi';
                levelnum =1;
                levelid1 = "&sub. time_to_epi";
                levelid2 = "&sub. time_to_epi";
                output;
                tablesub = "&sub.";
                tablesubstrat = 'adherence';
                levelnum =1;
                levelid1 = "&sub. adherence";
                levelid2 = "&sub. adherence time_to_epi";
                output;
                tablesub = "&sub.";
                tablesubstrat = "adherence_#";
                levelnum =1;
                levelid1 = "&sub. adherence_#";
                levelid2 = "&sub. adherence_# time_to_epi";
                output;
            %end;

        /*Table T3*/
        table = 'T3';
        dataset = 't2epigap';
        tablesub = 'overall';
        tablesubstrat = '';
        levelnum =1;
        levelid1 = 'epi_gap';
        levelid2 = '';
        output;

        /*Table T4*/
        table = 'T4';
        dataset = 't2epigap';
        tablesub = 'overall';
        tablesubstrat = '';
        levelnum =1;
        levelid1 = 'epi_gap';
        levelid2 = '';
        output;
    run;



    /*T1Cida, T2Cida, and T2concomitantuse Tables*/

	%let stratOneLevel = agegroup| year| sex| year month| race| hispanic| zip3| state| hhs_reg| cb_reg| zip_uncertain;

	%let stratCovar = &stratOneLevel.| covar#;

    %let stratTwoLevel = 
					 sex agegroup| sex agegroup year| sex agegroup year month| agegroup year| agegroup year month| sex year| sex year month| 
					 year month agegroup race| year month agegroup Hispanic| year month sex Hispanic| year month sex race| year month Hispanic race|
					 zip3 zip_uncertain| zip3 sex| zip3 sex zip_uncertain| zip3 agegroup| zip3 agegroup zip_uncertain| zip3 year| zip3 year zip_uncertain|
					 zip3 race| zip3 race zip_uncertain| zip3 hispanic| zip3 hispanic zip_uncertain| 
					 state zip_uncertain| state sex| state sex zip_uncertain| state agegroup| state agegroup zip_uncertain| state year| 
					 state year zip_uncertain| state race| state race zip_uncertain| state hispanic| state hispanic zip_uncertain| 
					 zip_uncertain sex| zip_uncertain agegroup| zip_uncertain year|
	                 hhs_reg zip_uncertain| hhs_reg sex| hhs_reg sex zip_uncertain| hhs_reg agegroup| hhs_reg agegroup zip_uncertain|
					 hhs_reg year| hhs_reg year zip_uncertain| hhs_reg race| hhs_reg race zip_uncertain| hhs_reg hispanic| hhs_reg hispanic zip_uncertain|
					 cb_reg zip_uncertain| cb_reg sex| cb_reg sex zip_uncertain| cb_reg agegroup| cb_reg agegroup zip_uncertain| cb_reg year| 
					 cb_reg year zip_uncertain| cb_reg race| cb_reg race zip_uncertain| cb_reg hispanic| cb_reg hispanic zip_uncertain| 
					 race sex| race agegroup| race year| race year month| 
					 hispanic sex| hispanic agegroup| hispanic year| hispanic year month| year agegroup race| year sex race|
					 year agegroup hispanic| year sex hispanic| year race hispanic;

    %let stratcida = &stratCovar. | &stratTwoLevel.;
	%let stratnoCovar = &stratOneLevel. | &stratTwoLevel.;

	%macro cida (name);

	    data lookup_&name.;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 includeinreport;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 $55.;

	        includeinreport = 'N';

	        /*Table T1*/
	        dataset = "&name.";
	        table = 'T1';

	            /*Overall table*/
	            tablesub = 'overall';
	            tablesubstrat = '';
	            levelnum =1;
	            levelid1 = '';
	            levelid2 = '';
	            output;

	            /*Stratified tables*/
	            %do i =1 %to 84;
	            %let sub = %scan(%str(&stratcida.), &i, '|');
	                tablesub = "&sub";
	                tablesubstrat = '';
	                levelnum =1;
	                levelid1 = "&sub";
	                levelid2 = '';
	                output;
	            %end;

	            %do i =1 %to 83;
	            %let sub = %scan(%str(&stratnoCovar.), &i, '|');
	                tablesub = "&sub covar#";
	                tablesubstrat = '';
	                levelnum =1;
	                levelid1 = "&sub covar#";
	                levelid2 = '';
	                output;
	            %end;

		run;

	%mend cida;
	%cida(t1cida);
	%cida(t2cida);
	%cida(t2conc);


	/*t1censor & t2censor Tables*/

    %let stratacensor = agegroup| year| sex;

    data lookup_t1t2_censor;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 includeinreport;
        format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 $55.;

        includeinreport = 'N';
		%macro censortables3(dsn,num);
		%do t=1 %to 3;
			/*Table T&t.*/
			dataset = "&dsn.";
			table = "T&t.";

            /*Overall table*/
            tablesub = 'overall';
            tablesubstrat = '';
            levelnum =1;
            levelid1 = 'censdays_value_cat';
            %if %eval(&t. ne 2) %then %do;
            levelid2 = 'censdays_value';
            %end;
            %else %do;
            levelid2 = '';
            %end;
            output;

            /*Stratified tables*/
            %do i =1 %to 3;
            %let sub = %scan(%str(&stratacensor.), &i, '|');
                tablesub = "&sub";
                tablesubstrat = '';
                levelnum =1;
				levelid1 = "&sub. censdays_value_cat";
                levelid2 = '';
                output;
            %end;
		%end;
		%do f=1 %to &num.;
			/*Figure F&f.*/
			dataset = "&dsn.";
			table = "F&f.";

            /*Overall table*/
            tablesub = 'overall';
            tablesubstrat = '';
            levelnum =1;
            levelid1 = 'censdays_value';
            levelid2 = '';
            output;
		%end;
		%mend censortables3;
		%censortables3(t1censor,2);
		%censortables3(t2censor,3);


	/*Overlap Tables*/

    %let stratalist = agegroup| year| sex| year month| race| hispanic| zip3| state| hhs_reg| cb_reg;

    data lookup_t2overlap;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 includeinreport;
        format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 $34. levelid2 $55.;

        includeinreport = 'N';

        /*Table T1*/
        dataset = 't2overlap';
        table = 'T1';

        /*Overall table*/
        tablesub = 'overall';
        tablesubstrat = '';
        levelnum =1;
        levelid1 = '';
        levelid2 = '';
        output;
        tablesub = 'overall';
        tablesubstrat = 'followup_cat';
        levelnum =1;
        levelid1 = 'followup_cat';
        levelid2 = '';
        output; 
		tablesub = 'overall';
        tablesubstrat = 'total_days_overlap';
        levelnum =1;
        levelid1 = 'total_days_overlap';
        levelid2 = '';
        output; 
		tablesub = 'overall';
        tablesubstrat = 'adherence';
        levelnum =1;
        levelid1 = 'adherence';
        levelid2 = '';
        output; 
		tablesub = 'overall';
        tablesubstrat = 'adherence_#';
        levelnum =1;
        levelid1 = 'adherence_#';
        levelid2 = '';
        output; 

        /*Stratified tables*/
        %do i =1 %to 10;
        %let sub = %scan(%str(&stratalist.), &i, '|');
            tablesub = "&sub";
            tablesubstrat = '';
            levelnum =1;
            levelid1 = "&sub";
            levelid2 = '';
            output;
            tablesub = "&sub";
            tablesubstrat = 'followup_cat';
            levelnum =1;
            levelid1 = "&sub followup_cat";
            levelid2 = '';
            output;     
			tablesub = "&sub";
            tablesubstrat = 'total_days_overlap';
            levelnum =1;
            levelid1 = "&sub total_days_overlap";
            levelid2 = '';
            output;     
			tablesub = "&sub";
            tablesubstrat = 'adherence';
            levelnum =1;
            levelid1 = "&sub adherence";
            levelid2 = '';
            output;     
			tablesub = "&sub";
            tablesubstrat = 'adherence_#';
            levelnum =1;
            levelid1 = "&sub adherence_#";
            levelid2 = '';
            output;      
        %end;
	run;

    /*Table T2*/
	data lookup_t2overlap;
	set lookup_t2overlap
		lookup_t2overlap(in=b);
    if b then table = 'T2';
	run;

	/***************************************************************************************************************************
	  T5episdur, T5disp, T5gaps, T5first, T5censor
	 ***************************************************************************************************************************/
	%let stratLevel = overall|sex|agegroup|race|hispanic|sex agegroup|sex race|sex hispanic|agegroup race|agegroup hispanic;
	%let stratfirst = overall|sex|agegroup|race|hispanic;
    
    %let stratlevels = %sysfunc(countw(&stratLevel.,'|'));
    %let stratflevels = %sysfunc(countw(&stratfirst.,'|'));

	    data lookup_t5_all;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 includeinreport;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 $55.;

	        includeinreport = 'N';

	        dataset = "t5episdur";
			  %do t = 2 %to 3;
                 %do s = 1 %to &stratlevels.;
                    table = "T&t.";
				    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				    tablesubstrat= "cumepisodelength";
				    levelnum =1;
				    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
				      levelid1 = "";
				      levelid2 = "cumepisodelength";
				    %end;
				    %else %do;
	                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				      levelid2 = "cumepisodelength %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				    %end;
	                output;
			     %end;
			  %end;
			  %do t = 4 %to 9;
                 %do s = 1 %to &stratlevels.;
                    table = "T&t.";
				    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				    tablesubstrat= "episodenum episodelength";
				    levelnum =1;
				    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
				      levelid1 = "episodenum";
				      levelid2 = "episodenum episodelength";
				    %end;
				    %else %do;
	                  levelid1 = "episodenum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				      levelid2 = "episodelength %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				    %end;
	                output;
			     %end;
			  %end;

			  dataset = "t5disp";
			  %do t = 10 %to 11;
                 %do s = 1 %to &stratlevels.;
                    table = "T&t.";
				    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				    tablesubstrat= "daysupp";
				    levelnum =1;
				    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
				      levelid1 = "";
				      levelid2 = "daysupp";
				    %end;
				    %else %do;
	                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				      levelid2 = "daysupp %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				    %end;
	                output;
			     %end;
			  %end;

			  dataset = "t5gaps";
			  %do t = 12 %to 14;
                 %do s = 1 %to &stratlevels.;
                    table = "T&t.";
				    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				    tablesubstrat= "gaplength gapnum";
				    levelnum =1;
				    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
				      levelid1 = "gaplength gapnum";
				      levelid2 = "";
				    %end;
				    %else %do;
	                  levelid1 = "gaplength gapnum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
				      levelid2 = "";
				    %end;
	                output;
			     %end;
			  %end;

			  dataset = "t5censor";
			  table = "T15";
			  tablesub= "overall";
			  tablesubstrat= "episodenum";
			  levelnum =1;
			  levelid1 = "episodenum";
			  levelid2 = "";
	          output;

			  dataset = "t5first";
			  %do f = 1 %to 3;
                 %do s = 1 %to &stratflevels.;
                    table = "F&f.";
				    tablesub= "%sysfunc(left(%scan(%str(&stratfirst.), &s, '|')))";
				    tablesubstrat= "mntsfromstart";
				    levelnum =1;
				    %if %sysfunc(left(%scan(%str(&stratfirst.), &s, '|'))) = overall %then %do;
				      levelid1 = "mntsfromstart";
				      levelid2 = "";
				    %end;
				    %else %do;
	                  levelid1 = "mntsfromstart %sysfunc(left(%scan(%str(&stratfirst.), &s, '|')))";
				      levelid2 = "";
				    %end;
	                output;
			     %end;
			  %end;

			  dataset = "t5censor";
			  %do f = 4 %to 5;
                table = "F&f.";
			    tablesub= "overall";
			    tablesubstrat= "episodenum episodelength";
			    levelnum =1;
			    levelid1 = "episodenum episodelength";
			    levelid2 = "";
				output;
			  %end;
		    run;
	
	/* Combine all lookup tables into one */
	data levellookup;
	  set lookup_:;
	run;

%mend;
%create_templatefiles();
