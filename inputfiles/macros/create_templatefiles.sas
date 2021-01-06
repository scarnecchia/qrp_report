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
*  Program outputs: The following template files are created:
*   -TableFile (one file is created per REPORTTTYPE)
*   -FigureFile (one file is created per REPORTTYPE)
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

/*Define libname for location of templatefiles folder*/
libname tempfl "U:\git\qrp_report\templatefiles";

%macro create_templatefiles();

    *************************************
     REPORTTYPE = T1 and T2L1 Files:
        - T1TableFile
        - T1FigureFile
        - T2L1TableFile
        - T2L1FigureFile
    *************************************;

    /*t1cida, t2cida, and t2concomitantuse tables*/

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

	%macro createt1t2cidatemplates(name);
	    data lookup_&name.;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55.;

	        includeinreport = 'N';
            call missing(levelid3);

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
	%mend createt1t2cidatemplates;
	%createt1t2cidatemplates(t1cida);
	%createt1t2cidatemplates(t2cida);
	%createt1t2cidatemplates(t2conc);

	/*t1censor & t2censor Tables*/
    %let stratacensor = agegroup| year| sex;
    %macro templatecensortablefigures(type,dsn,num);
        data lookup_&dsn.;
            retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport;
            format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 levelid3 $55.;

            includeinreport = 'N';
            call missing(levelid3);

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
        run;
    %mend templatecensortablefigures;
	%templatecensortablefigures(1,t1censor,2);
	%templatecensortablefigures(2,t2followuptime,3);
	%templatecensortablefigures(2,t2censor,2);

    /*Multiple Events Tables*/
    %let stratalist = agegroup| year| sex| year month| race| hispanic| zip3| state| hhs_reg| cb_reg| adherence;
    data lookup_t2multevent;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport;
        format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 levelid3 $55.;

        includeinreport = 'N';
        call missing(levelid3);

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

	/*Overlap Tables*/
    %let stratalist = agegroup| year| sex| year month| race| hispanic| zip3| state| hhs_reg| cb_reg;
    data lookup_t2overlap;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport;
        format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 levelid3 $55.;

        includeinreport = 'N';
        call missing(levelid3);

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
  
    /*Output T1 and T2L1 files*/
        /*t1tablefile*/
        data tempfl.t1tablefile;
            set lookup_t1cida
                lookup_t1censor(drop=tablesubstrat where=(substr(table,1,1)='T'));
        run;
        /*t1figurefile*/
        data tempfl.t1figurefile;
            set lookup_t1censor(drop=tablesubstrat where=(substr(table,1,1)='F'));
            rename tablesub=figuresub;
            rename table=figure;
        run;

        /*t2l1tablefile*/
        data tempfl.t2l1tablefile;
            set lookup_t2cida
                lookup_t2followuptime(where=(substr(table,1,1)='T'))
                lookup_t2censor(where=(substr(table,1,1)='T'))
                lookup_t2conc
                lookup_t2multevent
                lookup_t2overlap;
        run;

        /*t2l1figurefile*/
        data tempfl.t2l1figurefile;
            set lookup_t2followuptime(drop=tablesubstrat where=(substr(table,1,1)='F'))
            lookup_t2censor(drop=tablesubstrat where=(substr(table,1,1)='F'));
            rename tablesub=figuresub;
            rename table=figure;
        run;

    *************************************
     REPORTTYPE = T2L2 file:
        - T2L2FigureFile
    *************************************;
    data tempfl.t2l2figurefile;
        retain figure dataset figuresub levelnum levelid1 levelid2 levelid3 includeinreport;
        format figure $5. dataset $15. figuresub $25. levelid1 levelid2 levelid3 $55.;
        call missing(dataset, levelid1, levelid2, levelid3);
        levelnum = 0;
        includeinreport = 'N';

        /*PS Histograms*/
        figure = 'F1';
        figuresub = 'overall';
        output;

        /*Forest Plots*/
        figure = 'F2';
        figuresub = 'overall';
        output;

        /*Unadjusted KM Curve*/
        figure = 'F3';
        figuresub = 'overall';
        output;

        /*Conditional KM Curve*/
        figure = 'F4';
        figuresub = 'overall';
        output;

        /*Unconditional KM Curve*/
        figure = 'F5';
        figuresub = 'overall';
        output;
    run;

    *************************************
     REPORTTYPE = T4L2 file:
        - T4L2FigureFile
    *************************************;
    data tempfl.t4l2figurefile;
        retain figure dataset figuresub levelnum levelid1 levelid2 levelid3 includeinreport;
        format figure $5. dataset $15. figuresub $25. levelid1 levelid2 levelid3 $55.;
        call missing(dataset, levelid1, levelid2, levelid3);
        levelnum = 0;
        includeinreport = 'N';

        /*PS Histograms*/
        figure = 'F1';
        figuresub = 'overall';
        output;

        /*Forest Plots*/
        figure = 'F2';
        figuresub = 'overall';
        output;
    run;

    *************************************
     REPORTTYPE = T4L1 file:
        - T4L1TableFile
    *************************************;



    *************************************
     REPORTTYPE = T5 files:
        - T5TableFile
        - T5FigureFile
    *************************************;
	%let stratLevel = overall|sex|agegroup|race|hispanic|sex agegroup|sex race|sex hispanic|agegroup race|agegroup hispanic;
	%let stratfirst = overall|sex|agegroup|race|hispanic;
    
    %let stratlevels = %sysfunc(countw(&stratLevel.,'|'));
    %let stratflevels = %sysfunc(countw(&stratfirst.,'|'));

	data lookup_t5tablefigurefile;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55.;

        includeinreport = 'N';
        call missing(levelid3);
        call missing(tablesubstrat);

        dataset = "t5episdur";
		%do t = 1 %to 2;
            %do s = 1 %to &stratlevels.;
                table = "T&t.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			    levelnum =2;
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
		%do t = 3 %to 8;
             %do s = 1 %to &stratlevels.;
                table = "T&t.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			    levelnum =2;
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
		%do t = 9 %to 10;
            %do s = 1 %to &stratlevels.;
                table = "T&t.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			    levelnum =2;
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
		%do t = 11 %to 13;
             %do s = 1 %to &stratlevels.;
                table = "T&t.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
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
		table = "T14";
		tablesub= "overall";
		levelnum =2;
		levelid1 = "";
		levelid2 = "episodenum";
        output;

		dataset = "t5first";
		%do f = 1 %to 3;
             %do s = 1 %to &stratflevels.;
                table = "F&f.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratfirst.), &s, '|')))";
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
		    levelnum =1;
		    levelid1 = "episodenum episodelength";
		    levelid2 = "";
			output;
		 %end;
    run;
	
    /*Output T5 files*/
        /*t5tablefile*/
        data tempfl.t5tablefile;
            set lookup_t5tablefigurefile(where=(substr(table,1,1)='T'));
        run;
        /*t5figurefile*/
        data tempfl.t5figurefile;
            set lookup_t5tablefigurefile(where=(substr(table,1,1)='F'));
            drop tablesubstrat;
            rename tablesub=figuresub;
            rename table=figure;
        run;

   
    *************************************
     REPORTTYPE = T6 files:
        - T6TableFile
        - T6FigureFile
    *************************************;
    %let stratLevel = overall|sex|agegroup|race|hispanic|sex agegroup|sex race|sex hispanic|agegroup race|agegroup hispanic;
	%let stratfirst = overall|sex|agegroup|race|hispanic;
    
    %let stratlevels = %sysfunc(countw(&stratLevel.,'|'));
    %let stratflevels = %sysfunc(countw(&stratfirst.,'|'));

	data lookup_t6tablefigurefile;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55.;

        includeinreport = 'N';
        call missing(tablesubstrat);

        dataset = "t6counts";
		%do t = 1 %to 2;
            %do s = 1 %to &stratlevels.;
                table = "T&t.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			    levelnum =3;
			    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
			      levelid1 = "";
			      levelid2 = "year";
                  levelid3 = "month year";
			    %end;
			    %else %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			      levelid2 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) year";
			      levelid3 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) month year";
			    %end;
                output;
		     %end;
		%end;

        dataset = "t6trend";
        table = "T3";
        %do s = 1 %to &stratlevels.;
		    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
		    levelnum =2;
		    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
		      levelid1 = "year";
		      levelid2 = "month year";
              levelid3 = "";
		    %end;
		    %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) year";
		      levelid2 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) month year";
		      levelid3 = "";
		    %end;
            output;
	     %end;

        dataset = "t6counts";
        table = "T4";
        %do s = 1 %to &stratlevels.;
		    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
		    levelnum =3;
		    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
		      levelid1 = "";
		      levelid2 = "year";
              levelid3 = "month year";
		    %end;
		    %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
		      levelid2 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) year";
		      levelid3 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) month year";
		    %end;
            output;
	     %end;

        dataset = "t6disp";
        table = "T5";
        %do s = 1 %to &stratlevels.;
		    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
		    levelnum =1;
		    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
		      levelid1 = "daysupp";
		      levelid2 = "";
              levelid3 = "";
		    %end;
		    %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) daysupp";
		      levelid2 = "";
		      levelid3 = "";
		    %end;
            output;
	     %end;

        dataset = "t6episdur";
        table = "T6";
        %do s = 1 %to &stratlevels.;
		    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
		    levelnum =1;
		    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
		      levelid1 = "cumepisodelength";
		      levelid2 = "";
              levelid3 = "";
		    %end;
		    %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) cumepisodelength";
		      levelid2 = "";
		      levelid3 = "";
		    %end;
            output;
	     %end;

        dataset = "t6uptake";
        table = "T7";
        %do s = 1 %to &stratlevels.;
		    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
		    levelnum =1;
		    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
		      levelid1 = "uptakedays";
		      levelid2 = "";
              levelid3 = "";
		    %end;
		    %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) uptakedays";
		      levelid2 = "";
		      levelid3 = "";
		    %end;
            output;
        %end;

		dataset = "t6censor";
		table = "T8";
		tablesub= "overall";
		levelnum =1;
		levelid1 = "episodelength";
		levelid2 = "";
        output;

		dataset = "t6plota";
		table = "T9";
		tablesub= "overall";
		levelnum =2;
		levelid1 = "";
		levelid2 = "ttswitch";
        output;
		dataset = "t6plotb";
		table = "T10";
		tablesub= "overall";
		levelnum =2;
		levelid1 = "";
		levelid2 = "ttswitch";
        output;

        dataset = "T6switchepisdur";
        table = "T11";
        %do s = 1 %to &stratlevels.;
		    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
		    levelnum =1;
		    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
		      levelid1 = "episodelength";
		      levelid2 = "";
              levelid3 = "";
		    %end;
		    %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) episodelength";
		      levelid2 = "";
		      levelid3 = "";
		    %end;
            output;
        %end;

		%do t = 12 %to 15;
            %if %eval(&t.=12) | %eval(&t.=14) %then %do; dataset = "t6plota"; %end;
            %if %eval(&t.=13) | %eval(&t.=15) %then %do; dataset = "t6plotb"; %end;
            %do s = 1 %to &stratlevels.;
                table = "T&t.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			    levelnum =2;
			    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
			      levelid1 = "";
			      levelid2 = "ttswitch";
                  levelid3 = "";
			    %end;
			    %else %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			      levelid2 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) ttswitch";
			      levelid3 = "";
			    %end;
                output;
		     %end;
		%end;

        dataset = "t6counts";
		%do f = 1 %to 3;
            %do s = 1 %to &stratlevels.;
                table = "F&f.";
			    tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			    levelnum =3;
			    %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
			      levelid1 = "";
			      levelid2 = "year";
                  levelid3 = "month year";
			    %end;
			    %else %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
			      levelid2 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) year";
			      levelid3 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) month year";
			    %end;
                output;
		     %end;
		%end;
    
        %do f = 4 %to 7;
            %if %eval(&f.=4) | %eval(&f.=6) %then %do; dataset = "t6plota"; %end;
            %if %eval(&f.=5) | %eval(&f.=7) %then %do; dataset = "t6plotb"; %end;
            table = "F&f.";
		    tablesub= "overall";
		    levelnum =2;
		    levelid1 = "";
		    levelid2 = "ttswitch";
            levelid3 = "";
			output;
		%end;

    run;
	
    /*Output T6 files*/
        /*t6tablefile*/
        data tempfl.t6tablefile;
            set lookup_t6tablefigurefile(where=(substr(table,1,1)='T'));
        run;
        /*t6figurefile*/
        data tempfl.t6figurefile;
            set lookup_t6tablefigurefile(where=(substr(table,1,1)='F'));
            drop tablesubstrat;
            rename tablesub=figuresub;
            rename table=figure;
        run;
   
    *************************************
     REPORTTYPE = ITS files:
        - ITSTableFile
        - ITSFigureFile
    *************************************;

    /*Clean up*/
    proc datasets nowarn noprint;
        delete lookup:;
    quit;

%mend;

%create_templatefiles();
