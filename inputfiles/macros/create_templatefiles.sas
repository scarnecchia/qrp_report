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
*   -TableColumnsFile     
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
libname tempfl "";
%macro create_templatefiles();

    *************************************
     REPORTTYPE = T1 and T2L1 Files:
        - T1TableFile
        - T1FigureFile
        - T2L1TableFile
        - T2L1FigureFile
    *************************************;

    /*t1cida, t2cida, and t2concomitantuse tables*/

    %let stratOneLevel = sex| agegroup| year| year month| year quarter| race| hispanic| zip3| state| zip_uncertain| cb_reg| hhs_reg;
    %let stratCovar = &stratOneLevel.| covar#;
    %let stratTwoLevel = 
                     sex agegroup| sex agegroup year| sex agegroup year month| sex agegroup year quarter| agegroup year| agegroup year month| agegroup year quarter| sex year| sex year month| 
                     sex year quarter| year month agegroup race| year quarter agegroup race| year month agegroup Hispanic| year quarter agegroup Hispanic| year month sex Hispanic|
                     year quarter sex Hispanic| year month sex race| year quarter sex race| year month Hispanic race| year quarter Hispanic race|
                     zip3 zip_uncertain| zip3 sex| zip3 sex zip_uncertain| zip3 agegroup| zip3 agegroup zip_uncertain| zip3 year| zip3 year zip_uncertain|
                     zip3 race| zip3 race zip_uncertain| zip3 hispanic| zip3 hispanic zip_uncertain| 
                     state zip_uncertain| state sex| state sex zip_uncertain| state agegroup| state agegroup zip_uncertain| state year| 
                     state year zip_uncertain| state race| state race zip_uncertain| state hispanic| state hispanic zip_uncertain| 
                     zip_uncertain sex| zip_uncertain agegroup| zip_uncertain year|
                     hhs_reg zip_uncertain| hhs_reg sex| hhs_reg sex zip_uncertain| hhs_reg agegroup| hhs_reg agegroup zip_uncertain|
                     hhs_reg year| hhs_reg year zip_uncertain| hhs_reg race| hhs_reg race zip_uncertain| hhs_reg hispanic| hhs_reg hispanic zip_uncertain|
                     cb_reg zip_uncertain| cb_reg sex| cb_reg sex zip_uncertain| cb_reg agegroup| cb_reg agegroup zip_uncertain| cb_reg year| 
                     cb_reg year zip_uncertain| cb_reg race| cb_reg race zip_uncertain| cb_reg hispanic| cb_reg hispanic zip_uncertain| 
                     race sex| race agegroup| race year| race year month| race year quarter| 
                     hispanic sex| hispanic agegroup| hispanic year| hispanic year month| hispanic year quarter| year agegroup race| year sex race|
                     year agegroup hispanic| year sex hispanic| year race hispanic;

    %let stratcida = &stratCovar. | &stratTwoLevel.;
    %let stratnoCovar = &stratOneLevel. | &stratTwoLevel.;

    %macro createt1t2cidatemplates(name);
        data lookup_&name.;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55. categories $100.;

            includeinreport = 'N';
            categories = '';
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
                %do i =1 %to %sysfunc(countw(&stratcida., %str(|)));
                %let sub = %scan(%str(&stratcida.), &i, '|');
                    tablesub = "&sub";
                    tablesubstrat = '';
                    levelnum =1;
                    levelid1 = "&sub";
                    levelid2 = '';
                    output;
                %end;

                %do i =1 %to %sysfunc(countw(&stratnoCovar., %str(|)));
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
    %let stratacensor = | sex| agegroup| year;
    %macro templatecensortablefigures(type,dsn,numstart,num);
        data lookup_&dsn.;
            retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories censorreason;
            format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 levelid3 $55. categories $100.  censorreason $85.; 

            includeinreport = 'N';
            categories = '';
            call missing(levelid3, censorreason);

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
            %do f=&numstart. %to &num.;
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
    %templatecensortablefigures(1,t1censor,1,1);
    %templatecensortablefigures(2,t2followuptime,1,2);
    %templatecensortablefigures(2,t2censor,3,3);

    /*Multiple Events Tables*/
    %let stratalist = sex| agegroup| year| year month| year quarter| race| hispanic| zip3| state| cb_reg| hhs_reg| adherence;
    data lookup_t2multevent;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories;
        format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 levelid3 $55. categories $100.;

        includeinreport = 'N';
        categories = '';
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
            %do i =1 %to %sysfunc(countw(&stratalist., %str(|)));
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
            %do i =1 %to %sysfunc(countw(&stratalist., %str(|))) - 1;
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
    %let stratalist = sex| agegroup| year|  year month| year quarter| race| hispanic| zip3| state| cb_reg| hhs_reg;
    data lookup_t2overlap;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories;
        format table $5. dataset $15. tablesubstrat tablesub $25. levelid1 levelid2 levelid3 $55. categories $100.;

        includeinreport = 'N';
        categories = '';
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
        %do i =1 %to %sysfunc(countw(&stratalist., %str(|)));
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

            xmin = .;
            xmax = .;
            xtick = .;
            ymin = .;
            ymax = .;
            ytick = .;
            includeatrisktable = 'N';
            format censordisplay $50.;
            censordisplay = '';
            drop categories censorreason;
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

            xmin = .;
            xmax = .;
            xtick = .;
            ymin = .;
            ymax = .;
            ytick = .;
            includeatrisktable = 'N';
            format censordisplay $50.;
            censordisplay = '';
            drop categories censorreason;
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

        xmin = .;
        xmax = .;
        xtick = .;
        ymin = .;
        ymax = .;
        ytick = .;
        includeatrisktable = 'N';
        format censordisplay $50.;
        censordisplay = '';

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

        /*note - not relevant for T4L2 figures*/
        xmin = .;
        xmax = .;
        xtick = .;
        ymin = .;
        ymax = .;
        ytick = .;
        includeatrisktable = 'N';
        format censordisplay $50.;
        censordisplay = '';

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
    %let stratLevel = overall;
    %let stratlevels = %sysfunc(countw(&stratLevel.,'|'));

    data tempfl.t4l1tablefile;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55. categories $100.;

        includeinreport = 'N';
        categories = '';
        call missing(levelid2);
        call missing(levelid3);

        dataset = "t4preg";
        %do p = 1 %to 4;
        %do s = 1 %to &stratlevels.;
            table = "T&p";
            tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
            levelnum =2;
            %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
              levelid1 = "";
              levelid2 = "moiname";
            %end;
            %else %do;
              levelid1 = "";
              levelid2 = "moiname %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
            %end;
            tablesubstrat = 't4preg';
            output;
            tablesubstrat = 't4nopreg';
            output;
         %end;
         %end;
    run;


    *************************************
     REPORTTYPE = T5 files:
        - T5TableFile
        - T5FigureFile
    *************************************;
    %let stratLevel = overall|sex|agegroup|year|year month|year quarter|race|hispanic|sex agegroup|sex race|sex hispanic|agegroup race|agegroup hispanic;
    %let stratfirst = overall|sex|agegroup|race|hispanic;
    
    %let stratlevels = %sysfunc(countw(&stratLevel.,'|'));
    %let stratflevels = %sysfunc(countw(&stratfirst.,'|'));

    data lookup_t5tablefigurefile;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55. categories $100. censorreason $85.;

        includeinreport = 'N';
        categories = '';
        call missing(levelid3, tablesubstrat, censorreason);

        dataset = "t5disp";
        %do t = 1 %to 2;
            %do s = 1 %to &stratlevels.;
                %if %eval(&s.<=3) | %eval(&s.>=7) %then %do;
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
        %end;

        dataset = "t5episdur";
        %do t = 3 %to 4; 
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
        %do t = 5 %to 6; 
             %do s = 1 %to &stratlevels.;
                table = "T&t.";
                tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                levelnum =2;
                %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
                  levelid1 = "";
                  levelid2 = "episodelength";
                %end;
                %else %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                  levelid2 = "episodelength %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                %end;
                output;
             %end;
        %end;
        %do t = 7 %to 10; 
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
                  levelid2 = "episodenum episodelength %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                %end;
                output;
             %end;
          %end;

        dataset = "t5gaps";
        %do s = 1 %to &stratlevels.;
                table = "T11";
                tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                levelnum =2;
                %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
                  levelid1 = "gapnum";
                  levelid2 = "gapnum gaplength";
                %end;
                %else %do;
                  levelid1 = "gapnum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                  levelid2 = "gapnum gaplength %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                %end;
                output;
         %end;
        %do t = 12 %to 13;
             %do s = 1 %to &stratlevels.;
                table = "T&t.";
                tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                levelnum =2;
                %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
                  levelid1 = "gapnum";
                  levelid2 = "gapnum gaplength";
                %end;
                %else %do;
                  levelid1 = "gapnum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                  levelid2 = "gapnum gaplength %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                %end;
                output;
             %end;
        %end;
        
        dataset = "t5censor";
        table = "T14";
        tablesub= "overall";
        levelnum =1;
        levelid1 = "episodenum";
        levelid2 = "";
        output;
        dataset = "t5censor";
        table = "T15";
        tablesub= "overall";
        levelnum =1;
        levelid1 = "episodenum episodelength";
        levelid2 = "";
        output;
        dataset = "t5censor";
        table = "T16";
        tablesub= "overall";
        levelnum =1;
        levelid1 = "";
        levelid2 = "";
        output;
        dataset = "t5censor";
        table = "T17";
        tablesub= "overall";
        levelnum =2;
        levelid1 = "";
        levelid2 = "episodelength";
        output;

        /*Dose tables*/
        dataset = "t5disp";
        %do s = 1 %to &stratlevels.;
            %if %eval(&s.<=3) | %eval(&s.>=7) %then %do;
            table = "T18";
            tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
            levelnum =2;
            %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
              levelid1 = "";
              levelid2 = "cfdd_output_cat";
              levelid3 = "cfdd";
            %end;
            %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid2 = "cfdd_output_cat %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid3 = "";
            %end;
            output;
            %end;
        %end;
        dataset = "t5dose";
        %do s = 1 %to &stratlevels.;
            table = "T19";
            tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
            levelnum =2;
            %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
              levelid1 = "";
              levelid2 = "afdd_output_cat";
              levelid3 = "afdd";
            %end;
            %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid2 = "afdd_output_cat %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid3 = "";
            %end;
            output;
        %end;
        %do s = 1 %to &stratlevels.;
            table = "T20";
            tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
            levelnum =2;
            %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
              levelid1 = "episodenum";
              levelid2 = "afdd_output_cat episodenum";
              levelid3 = "afdd episodenum";
            %end;
            %else %do;
              levelid1 = "episodenum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid2 = "afdd_output_cat episodenum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid3 = "";
            %end;
            output;
        %end;
        %do s = 1 %to &stratlevels.;
            table = "T21";
            tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
            levelnum =2;
            %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
              levelid1 = "";
              levelid2 = "cumdose_output_cat";
              levelid3 = "cumdose";
            %end;
            %else %do;
              levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid2 = "cumdose_output_cat %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid3 = "";
            %end;
            output;
        %end;
        %do s = 1 %to &stratlevels.;
            table = "T22";
            tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
            levelnum =2;
            %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
              levelid1 = "episodenum";
              levelid2 = "cumdose_output_cat episodenum";
              levelid3 = "cumdose episodenum";
            %end;
            %else %do;
              levelid1 = "episodenum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid2 = "cumdose_output_cat episodenum %sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
              levelid3 = "";
            %end;
            output;
        %end;
            
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

            xmin = .;
            xmax = .;
            xtick = .;
            ymin = .;
            ymax = .;
            ytick = .;
            includeatrisktable = 'N';
            format censordisplay $50.;
            censordisplay = '';
            drop categories censorreason;
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
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55. categories $100. censorreason $125.;

        includeinreport = 'N';
        categories = '';
        call missing(tablesubstrat, censorreason);

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
        levelnum =1;
        levelid1 = "ttswitch";
        levelid2 = "";
        output;
        dataset = "t6plotb";
        table = "T10";
        tablesub= "overall";
        levelnum =1;
        levelid1 = "ttswitch";
        levelid2 = "";
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
            levelnum =1;
            levelid1 = "ttswitch";
            levelid2 = "";
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

            xmin = .;
            xmax = .;
            xtick = .;
            ymin = .;
            ymax = .;
            ytick = .;
            includeatrisktable = 'N';
            format censordisplay $50.;
            censordisplay = '';
            drop categories censorreason;
        run;
   
    *************************************
     REPORTTYPE = ITS files:
        - ITSTableFile
        - ITSFigureFile
    *************************************;
    %let stratLevel = overall|sex|agegroup|race|hispanic;
    %let stratlevels = %sysfunc(countw(&stratLevel.,'|'));
    %let intervallist = year|month year|quarter year;

    data lookup_its_tablefigurefile;
        retain table dataset tablesub tablesubstrat levelnum levelid1 levelid2 levelid3 includeinreport categories;
        format table $5. dataset $15. tablesubstrat $25. tablesub $40. levelid1 levelid2 levelid3 $55. categories $100.;

        includeinreport = 'N';
        categories = '';
        call missing(tablesubstrat);

        dataset = "t2its";
        %do t = 1 %to 2;
            %do int = 1 %to 3;
            %do s = 1 %to &stratlevels.;
                table = "T&t.";
                tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                levelnum =1;
                %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&intervallist.), &int, '|')))";
                  levelid2 = "";
                  levelid3 = "";
                %end;
                %else %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) %sysfunc(left(%scan(%str(&intervallist.), &int, '|')))";
                  levelid2 = "";
                  levelid3 = "";
                %end;
                output;
             %end;
             %end;
        %end;

        dataset = "t2itsprev";
        %do t = 1 %to 2;
            %do int = 1 %to 3;
            %do s = 1 %to &stratlevels.;
                table = "T&t.";
                tablesub= "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|')))";
                levelnum =1;
                %if %sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) = overall %then %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&intervallist.), &int, '|')))";
                  levelid2 = "";
                  levelid3 = "";
                %end;
                %else %do;
                  levelid1 = "%sysfunc(left(%scan(%str(&stratLevel.), &s, '|'))) %sysfunc(left(%scan(%str(&intervallist.), &int, '|')))";
                  levelid2 = "";
                  levelid3 = "";
                %end;
                output;
             %end;
             %end;
        %end;
    run;
    
    /*Output ITS files*/
        /*ITStablefile*/
        data tempfl.ITStablefile;
            set lookup_its_tablefigurefile(where=(substr(table,1,1)='T'));
        run;
        /*ITSfigurefile*/
        data tempfl.ITSfigurefile;
            set lookup_its_tablefigurefile(where=(table='T1'));
            table = 'F1';
            drop tablesubstrat;
            rename tablesub=figuresub;
            rename table=figure;

            xmin = .;
            xmax = .;
            xtick = .;
            ymin = .;
            ymax = .;
            ytick = .;
            includeatrisktable = 'N';
            format censordisplay $50.;
            censordisplay = '';
            drop categories;
        run;

    /*Clean up*/
    proc datasets nowarn noprint;
        delete lookup:;
    quit;
    
    
  %macro create_t1t2_tablecolumns();

    *************************************
     TableColumnsFile for T1 and T2L1:
        - T1cida
        - T2cida
        - T2conc
    *************************************;
    
     data tablecolumnsfile;
       attrib Table             length = $10    format = $10.
              IncludeinReport   length = $1     format = $1.
              Column            length = $50    format = $50.
              Order             length = 3      format = 3.
              ColumnLabel       length = $100   format = $100.
              ColumnFormat      length = $10    format = $10.
              CIrate            length = $1     format = $1.
              ColumnWidth       length = 8
              DefOrder          length = 3      format = 3.;                                                                                     
        Table = "t1cida"; Column = "Npts";                                  ColumnLabel = "Number of Patients";                                                                                     ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 1;     DefOrder = 1;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2conc";                                                   ColumnLabel = "Number of Patients with a Concomitant Episode";                                                                                                                                                                                          output;
        Table = "t1cida"; Column = "Episodes";                              ColumnLabel = "Number of Index Dates";                                                                                  ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 2;     DefOrder = 2;    output;
        Table = "t2cida";                                                   ColumnLabel = "Number of Exposure Episodes";                                                                                                                                                                                                            output;
        Table = "t2conc";                                                   ColumnLabel = "Number of Concomitant Episodes";                                                                                                                                                                                                         output;
        Table = "t1cida"; Column = "DenNumPts";                             ColumnLabel = "Number of Eligible Members";                                                                             ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 3;     DefOrder = 7;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 19;    DefOrder = 11;   output;
        Table = "t1cida"; Column = "DenNumMemDays";                         ColumnLabel = "Total Eligible Member-Days";                                                                             ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 4;     DefOrder = 8;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 21;    DefOrder = 12;   output;
        Table = "t1cida"; Column = "DenNumMemDays/365.25";                  ColumnLabel = "Total Eligible Member-Years";                                                                            ColumnFormat = "comma13.1";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 5;     DefOrder = 9;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 20;    DefOrder = 13;   output;
        Table = "t1cida"; Column = "(Npts/DenNumPts)*X";                    ColumnLabel = "Number of Patients per X Eligible Members";                                                              ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "N";    IncludeinReport = "N";    Order = 6;     DefOrder = .;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 22;                     output;
        Table = "t1cida"; Column = "(npts/dennumpts)*X";                    ColumnLabel = "Number of Patients per X Eligible Members (95% Confidence Interval)";                                    ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "P";    IncludeinReport = "N";    Order = 7;     DefOrder = .;    output;
        Table = "t1cida"; Column = "npts/dennumpts";                        ColumnLabel = "Number of Patients per Eligible Member (95% Confidence Interval)";                                       ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "P";    IncludeinReport = "N";    Order = 8;     DefOrder = .;    output;
        Table = "t1cida"; Column = "npts/dennummemdays";                    ColumnLabel = "Number of Patients per Eligible Member-Day (95% Confidence Interval)";                                   ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 9;     DefOrder = .;    output;
        Table = "t1cida"; Column = "npts/(dennummemdays/365.25)";           ColumnLabel = "Number of Patients per Eligible Member-Year (95% Confidence Interval)";                                  ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 10;    DefOrder = .;    output;
        Table = "t1cida"; Column = "(npts/dennummemdays)*X";                ColumnLabel = "Number of Patients per X Eligible Member-Days (95% Confidence Interval)";                                ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 11;    DefOrder = .;    output;
        Table = "t1cida"; Column = "(npts/[dennummemdays/365.25])*X";       ColumnLabel = "Number of Patients per X Eligible Member-Years (95% Confidence Interval)";                               ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 12;    DefOrder = .;    output;
        Table = "t1cida"; Column = "AdjustedCodeCount";                     ColumnLabel = "Number of Index Date Defining-Dispensings (Adjusted for Same-Day Dispensings)";                          ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 13;    DefOrder = 3;    output;
        Table = "t2cida";                                                   ColumnLabel = "Number of Exposure Episode Defining-Dispensings (Adjusted for Same-Day Dispensings)";                                                                                                                    Order = 24;                     output;
        Table = "t2conc";                                                                                                                                                                                                                                                                           Order = 19;                     output;
        Table = "t1cida"; Column = "RawCodeCount";                          ColumnLabel = "Number of Index Date Defining-Dispensings (Not Adjusted for Same-Day Dispensings)";                      ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 14;    DefOrder = 4;    output;
        Table = "t2cida";                                                   ColumnLabel = "Number of Exposure Episode Defining-Dispensings (Not Adjusted for Same-Day Dispensings)";                                                                                                                Order = 26;                     output;
        Table = "t2conc";                                                                                                                                                                                                                                                                           Order = 21;                     output;
        Table = "t1cida"; Column = "AdjustedCodeCount/Npts";                ColumnLabel = "Number of Index Date Defining-Dispensings per Patient (Adjusted for Same-Day Dispensings)";              ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 15;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Number of Exposure Episode Defining-Dispensings per Patient (Adjusted for Same-Day Dispensings)";                                                                                                        Order = 25;                     output;
        Table = "t2conc";                                                                                                                                                                                                                                                                           Order = 20;                     output;
        Table = "t1cida"; Column = "RawCodeCount/Npts";                     ColumnLabel = "Number of Index Date Defining-Dispensings per Patient (Not Adjusted for Same-Day Dispensings)";          ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 16;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Number of Exposure Episode Defining-Dispensings per Patient (Not Adjusted for Same-Day Dispensings)";                                                                                                    Order = 27;                     output;
        Table = "t2conc";                                                                                                                                                                                                                                                                           Order = 22;                     output;
        Table = "t1cida"; Column = "DaySupp";                               ColumnLabel = "Total Days Supply in Index Date Defining-Records";                                                       ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 17;    DefOrder = 5;    output;
        Table = "t2cida";                                                   ColumnLabel = "Total Days Supply During Exposure Episodes";                                                                                                                                                             Order = 28;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Total Days Supply During Concomitant Episodes";                                                                                                                                                          Order = 23;                     output;
        Table = "t1cida"; Column = "DaySupp/Npts";                          ColumnLabel = "Mean Days Supply per Patient";                                                                           ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 18;    DefOrder = .;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 29;                     output;
        Table = "t2conc";                                                                                                                                                                                                                                                                           Order = 24;                     output;
        Table = "t1cida"; Column = "DaySupp/Episodes";                      ColumnLabel = "Mean Days Supply per Index Date";                                                                        ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 19;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Mean Days Supply per Exposure Episode";                                                                                                                                                                  Order = 30;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Mean Days Supply per Concomitant Episode";                                                                                                                                                               Order = 25;                     output;
        Table = "t1cida"; Column = "DaySupp/AdjustedCodeCount";             ColumnLabel = "Mean Days Supply per Index Date Defining-Record (Adjusted for Same-Day Dispensings)";                    ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 20;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Mean Days Supply per Exposure Episode (Adjusted for Same-Day Records)";                                                                                                                                  Order = 31;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Mean Days Supply per Concomitant Episode (Adjusted for Same-Day Records)";                                                                                                                               Order = 26;                     output;
        Table = "t1cida"; Column = "DaySupp/RawCodeCount";                  ColumnLabel = "Mean Days Supply per Index Date Defining-Record (Not Adjusted for Same-Day Dispensings)";                ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 21;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Mean Days Supply per Exposure Episode (Not Adjusted for Same-Day Records)";                                                                                                                              Order = 32;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Mean Days Supply per Concomitant Episode (Not Adjusted for Same-Day Records)";                                                                                                                           Order = 27;                     output;
        Table = "t1cida"; Column = "AmtSupp";                               ColumnLabel = "Total Amount Supplied in Index Date Defining-Records";                                                   ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 22;    DefOrder = 6;    output;
        Table = "t2cida";                                                   ColumnLabel = "Total Amount Supplied During Exposure Episodes";                                                                                                                                                         Order = 33;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Total Amount Supplied During Concomitant Episodes";                                                                                                                                                      Order = 28;                     output;
        Table = "t1cida"; Column = "AmtSupp/Npts";                          ColumnLabel = "Mean Amount Supplied per Patient";                                                                       ColumnFormat = "comma13.2";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "N";    Order = 23;    DefOrder = .;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 34;                     output;
        Table = "t2conc";                                                                                                                                                                                                                                                                           Order = 29;                     output;
        Table = "t1cida"; Column = "AmtSupp/Episodes";                      ColumnLabel = "Mean Amount Supplied per Index Date";                                                                    ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 24;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Mean Amount Supplied per Exposure Episode";                                                                                                                                                              Order = 35;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Mean Amount Supplied per Concomitant Episode";                                                                                                                                                           Order = 30;                     output;
        Table = "t1cida"; Column = "AmtSupp/AdjustedCodeCount";             ColumnLabel = "Mean Amount Supplied per Index Date Defining-Record (Adjusted for Same-Day Dispensings)";                ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 25;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Mean Amount Supplied per Exposure Episode (Adjusted for Same-Day Records)";                                                                                                                              Order = 36;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Mean Amount Supplied per Concomitant Episode (Adjusted for Same-Day Records)";                                                                                                                           Order = 31;                     output;
        Table = "t1cida"; Column = "AmtSupp/RawCodeCount";                  ColumnLabel = "Mean Amount Supplied per Index Date Defining-Record (Not Adjusted for Same-Day Dispensings)";            ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 26;    DefOrder = .;    output;
        Table = "t2cida";                                                   ColumnLabel = "Mean Amount Supplied per Exposure Episode (Not Adjusted for Same-Day Records)";                                                                                                                          Order = 37;                     output;
        Table = "t2conc";                                                   ColumnLabel = "Mean Amount Supplied per Concomitant Episode (Not Adjusted for Same-Day Records)";                                                                                                                       Order = 32;                     output;
        Table = "t1cida"; Column = "timetocensor/365.25";                   ColumnLabel = "Total Observable Years";                                                                                 ColumnFormat = "comma13.1";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "N";    Order = 27;    DefOrder = .;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 38;                     output;
        Table = "t1cida"; Column = "timetocensor";                          ColumnLabel = "Total Observable Days";                                                                                  ColumnFormat = "comma13.0";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 28;    DefOrder = .;    output;
        Table = "t2cida";                                                                                                                                                                                                                                                                           Order = 39;                     output;
        Table = "t2cida"; Column = "All_Events";                            ColumnLabel = "Total Number of Events";                                                                                 ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 3;     DefOrder = 8;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "Eps_wEvents";                           ColumnLabel = "Number of Exposure Episodes with an Event";                                                              ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 4;     DefOrder = 7;    output;
        Table = "t2conc";                                                   ColumnLabel = "Number of Concomitant Episodes with an Event";                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "Eps_wEvents/Npts";                      ColumnLabel = "Proportion of Patients with an Event";                                                                   ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 5;     DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "Eps_wEvents/Episodes";                  ColumnLabel = "Proportion of Exposure Episodes with an Event";                                                          ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 6;     DefOrder = .;    output;
        Table = "t2conc";                                                   ColumnLabel = "Proportion of Concomitant Episodes with an Event";                                                                                                                                                                                       output;
        Table = "t2cida"; Column = "eps_wevents/episodes";                  ColumnLabel = "Proportion of Exposure Episodes with an Event (95% Confidence Interval)";                                ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "P";    IncludeinReport = "N";    Order = 7;     DefOrder = .;    output;
        Table = "t2conc";                                                   ColumnLabel = "Proportion of Concomitant Episodes with an Event (95% Confidence Interval)";                                                                                                                                                             output;
        Table = "t2cida"; Column = "(eps_wevents/episodes)*X";              ColumnLabel = "Number of Exposure Episodes with an Event per X Exposure Episodes (95% Confidence Interval)";            ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "P";    IncludeinReport = "N";    Order = 8;     DefOrder = .;    output;
        Table = "t2conc";                                                   ColumnLabel = "Number of Concomitant Episodes with an Event per X Concomitant Episodes (95% Confidence Interval)";                                                                                                                                      output;
        Table = "t2cida"; Column = "followuptime/365.25";                   ColumnLabel = "Total Years at Risk";                                                                                    ColumnFormat = "comma13.1";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 9;     DefOrder = 10;   output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "followuptime";                          ColumnLabel = "Total Days at Risk";                                                                                     ColumnFormat = "comma14.0";    ColumnWidth = .82;    CIrate = "N";    IncludeinReport = "Y";    Order = 10;    DefOrder = 9;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "Eps_wEvents/(followuptime/365.25)";     ColumnLabel = "Number of Exposure Episodes with an Event per Patient-Year at Risk";                                     ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 11;    DefOrder = .;    output;
        Table = "t2conc";                                                   ColumnLabel = "Event Rate per Patient-Year at Risk";                                                                                                                                                                                                    output;
        Table = "t2cida"; Column = "eps_wevents/(followuptime/365.25)";     ColumnLabel = "Event Rate per Patient-Year at Risk (95% Confidence Interval)";                                          ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 12;    DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "(Eps_wEvents/(followuptime/365.25))*X"; ColumnLabel = "Event Rate per X Patient-Years at Risk";                                                                 ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 13;    DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "(eps_wevents/(followuptime/365.25))*X"; ColumnLabel = "Event Rate per X Patient-Years at Risk (95% Confidence Interval)";                                       ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 14;    DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "eps_wevents/(followuptime/30.35)";      ColumnLabel = "Event Rate per Patient-Month at Risk (95% Confidence Interval)";                                         ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 15;    DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "(eps_wevents/(followuptime/30.35))*X";  ColumnLabel = "Event Rate per X Patient-Months at Risk (95% Confidence Interval)";                                      ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 16;    DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "eps_wevents/followuptime";              ColumnLabel = "Event Rate per Patient-Day at Risk (95% Confidence Interval)";                                           ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 17;    DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "(eps_wevents/followuptime)*X";          ColumnLabel = "Event Rate per X Patient-Days at Risk (95% Confidence Interval)";                                        ColumnFormat = "comma13.2";    ColumnWidth = 1.5;    CIrate = "R";    IncludeinReport = "N";    Order = 18;    DefOrder = .;    output;
        Table = "t2conc";                                                                                                                                                                                                                                                                                                           output;
        Table = "t2cida"; Column = "(Eps_wEvents/DenNumPts)*X";             ColumnLabel = "Number of Exposure Episodes with an Event per X Eligible Member-Years";                                  ColumnFormat = "comma13.2";    ColumnWidth = .72;    CIrate = "N";    IncludeinReport = "N";    Order = 23;    DefOrder = .;    output;
     run;                                                                                                                                                                                                                                                                                                       

    proc sort data = tablecolumnsfile ;
        by table deforder;
    run;
     
    /* Re-assign order for default table */
    data tempfl.t1t2_tablecolumnsfile_default (drop = deforder);
        set tablecolumnsfile (where = (includeinreport = "Y"));
        order=deforder;
    run;                                                                                                                                                                                                                                                                                                         

    proc sort data = tablecolumnsfile;
        by table order;
    run; 
    
    /* Assign includeinreport to N for all variables on the tablecolumnsfile_all dataset */
    data tempfl.t1t2_tablecolumnsfile_all;
        set tablecolumnsfile (drop=deforder);
        includeinreport = "N";
    run;
     
  %mend create_t1t2_tablecolumns;
  %create_t1t2_tablecolumns();
  
  %macro create_t4_tablecolumns();

    *************************************
     TableColumnsFile for T4
    *************************************;
    
     data tempfl.t4_tablecolumnsfile_default;
       attrib Table             length = $10    format = $10.
              Column            length = $50    format = $50.
              Order             length = 3      format = 3.
              ColumnLabel       length = $100   format = $100.
              IncludeinReport   length = $1     format = $1.
              ColumnFormat      length = $10    format = $10.
              ColumnWidth       length = 8;
       
       table = "T1"; Column = "usepre";                ColumnLabel = "Use in the Pre-Pregnancy Period";                ColumnFormat = "comma14.0";  order = 1;  IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "usepre/episodes";       ColumnLabel = "Use in the Pre-Pregnancy Period";                ColumnFormat = "percent8.1"; order = 2;  IncludeinReport = "Y"; columnwidth=.7; output; 
       table = "T1"; Column = "anyt";                  ColumnLabel = "Use During Any Trimester";                       ColumnFormat = "comma14.0";  order = 3;  IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "anyt/episodes";         ColumnLabel = "Use During Any Trimester";                       ColumnFormat = "percent8.1"; order = 4;  IncludeinReport = "Y"; columnwidth=.7; output; 
       table = "T1"; Column = "anyt1";                 ColumnLabel = "Use in First Trimester";                         ColumnFormat = "comma14.0";  order = 5;  IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "anyt1/episodes";        ColumnLabel = "Use in First Trimester";                         ColumnFormat = "percent8.1"; order = 6;  IncludeinReport = "Y"; columnwidth=.7; output;    
       table = "T1"; Column = "anyt2";                 ColumnLabel = "Use in Second Trimester";                        ColumnFormat = "comma14.0";  order = 7;  IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "anyt2/episodes";        ColumnLabel = "Use in Second Trimester";                        ColumnFormat = "percent8.1"; order = 8;  IncludeinReport = "Y"; columnwidth=.7; output; 
       table = "T1"; Column = "anyt3";                 ColumnLabel = "Use in Third Trimester";                         ColumnFormat = "comma14.0";  order = 9;  IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "anyt3/episodes_3trim";  ColumnLabel = "Use in Third Trimester";                         ColumnFormat = "percent8.1"; order = 10; IncludeinReport = "Y"; columnwidth=.7; output; 
       table = "T1"; Column = "allt";                  ColumnLabel = "Use in All Trimesters";                          ColumnFormat = "comma14.0";  order = 11; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "allt/episodes_3trim";   ColumnLabel = "Use in All Trimesters";                          ColumnFormat = "percent8.1"; order = 12; IncludeinReport = "Y"; columnwidth=.7; output; 
       table = "T1"; Column = "onlyt1";                ColumnLabel = "Use Only During First Trimester";                ColumnFormat = "comma14.0";  order = 13; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "onlyt1/episodes";       ColumnLabel = "Use Only During First Trimester";                ColumnFormat = "percent8.1"; order = 14; IncludeinReport = "Y"; columnwidth=.7; output; 
       table = "T1"; Column = "onlyt2";                ColumnLabel = "Use Only During Second Trimester";               ColumnFormat = "comma14.0";  order = 15; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "onlyt2/episodes";       ColumnLabel = "Use Only During Second Trimester";               ColumnFormat = "percent8.1"; order = 16; IncludeinReport = "Y"; columnwidth=.7; output; 
       table = "T1"; Column = "onlyt3";                ColumnLabel = "Use Only During Third Trimester";                ColumnFormat = "comma14.0";  order = 17; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T1"; Column = "onlyt3/episodes_3trim"; ColumnLabel = "Use Only During Third Trimester";                ColumnFormat = "percent8.1"; order = 18; IncludeinReport = "Y"; columnwidth=.7; output; 
                                                 
       table = "T2"; Column = "sumusepre";             ColumnLabel = "Exposure Episodes in the Pre-Pregnancy Period";  ColumnFormat = "comma14.0";  order = 19; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumanyt";               ColumnLabel = "Exposure Episodes During Any Trimester";         ColumnFormat = "comma14.0";  order = 20; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumanyt1";              ColumnLabel = "Exposure Episodes in First Trimester";           ColumnFormat = "comma14.0";  order = 21; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumanyt2";              ColumnLabel = "Exposure Episodes in Second Trimester";          ColumnFormat = "comma14.0";  order = 22; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumanyt3";              ColumnLabel = "Exposure Episodes in Third Trimester";           ColumnFormat = "comma14.0";  order = 23; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumallt";               ColumnLabel = "Exposure Episodes in All Trimesters";            ColumnFormat = "comma14.0";  order = 24; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumonlyt1";             ColumnLabel = "Exposure Episodes Only During First Trimester";  ColumnFormat = "comma14.0";  order = 25; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumonlyt2";             ColumnLabel = "Exposure Episodes Only During Second Trimester"; ColumnFormat = "comma14.0";  order = 26; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T2"; Column = "sumonlyt3";             ColumnLabel = "Exposure Episodes Only During Third Trimester";  ColumnFormat = "comma14.0";  order = 27; IncludeinReport = "Y"; columnwidth=.9; output; 
                                                                                                                                                    
       table = "T3"; Column = "sumrawcntpre";          ColumnLabel = "Codes in the Pre-Pregnancy Period";              ColumnFormat = "comma14.0";  order = 28; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T3"; Column = "sumrawcntanyt";         ColumnLabel = "Codes During Any Trimester";                     ColumnFormat = "comma14.0";  order = 29; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T3"; Column = "sumrawcntanyt1";        ColumnLabel = "Codes in First Trimester";                       ColumnFormat = "comma14.0";  order = 30; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T3"; Column = "sumrawcntanyt2";        ColumnLabel = "Codes in Second Trimester";                      ColumnFormat = "comma14.0";  order = 31; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T3"; Column = "sumrawcntanyt3";        ColumnLabel = "Codes in Third Trimester";                       ColumnFormat = "comma14.0";  order = 32; IncludeinReport = "Y"; columnwidth=.9; output;     
       table = "T3"; Column = "sumrawcntallt";         ColumnLabel = "Codes in All Trimesters";                        ColumnFormat = "comma14.0";  order = 33; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T3"; Column = "sumrawcntonlyt1";       ColumnLabel = "Codes Only During First Trimester";              ColumnFormat = "comma14.0";  order = 34; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T3"; Column = "sumrawcntonlyt2";       ColumnLabel = "Codes Only During Second Trimester";             ColumnFormat = "comma14.0";  order = 35; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T3"; Column = "sumrawcntonlyt3";       ColumnLabel = "Codes Only During Third Trimester";              ColumnFormat = "comma14.0";  order = 36; IncludeinReport = "Y"; columnwidth=.9; output; 
                                                                                                                                                    
       table = "T4"; Column = "sumadjcntpre";          ColumnLabel = "Codes in the Pre-Pregnancy Period";              ColumnFormat = "comma14.0";  order = 37; IncludeinReport = "Y"; columnwidth=.9; output;      
       table = "T4"; Column = "sumadjcntanyt";         ColumnLabel = "Codes During Any Trimester";                     ColumnFormat = "comma14.0";  order = 38; IncludeinReport = "Y"; columnwidth=.9; output;     
       table = "T4"; Column = "sumadjcntanyt1";        ColumnLabel = "Codes in First Trimester";                       ColumnFormat = "comma14.0";  order = 39; IncludeinReport = "Y"; columnwidth=.9; output;      
       table = "T4"; Column = "sumadjcntanyt2";        ColumnLabel = "Codes in Second Trimester";                      ColumnFormat = "comma14.0";  order = 40; IncludeinReport = "Y"; columnwidth=.9; output;    
       table = "T4"; Column = "sumadjcntanyt3";        ColumnLabel = "Codes in Third Trimester";                       ColumnFormat = "comma14.0";  order = 41; IncludeinReport = "Y"; columnwidth=.9; output; 
       table = "T4"; Column = "sumadjcntallt";         ColumnLabel = "Codes in All Trimesters";                        ColumnFormat = "comma14.0";  order = 42; IncludeinReport = "Y"; columnwidth=.9; output;   
       table = "T4"; Column = "sumadjcntonlyt1";       ColumnLabel = "Codes Only During First Trimester";              ColumnFormat = "comma14.0";  order = 43; IncludeinReport = "Y"; columnwidth=.9; output;   
       table = "T4"; Column = "sumadjcntonlyt2";       ColumnLabel = "Codes Only During Second Trimester";             ColumnFormat = "comma14.0";  order = 44; IncludeinReport = "Y"; columnwidth=.9; output;     
       table = "T4"; Column = "sumadjcntonlyt3";       ColumnLabel = "Codes Only During Third Trimester";              ColumnFormat = "comma14.0";  order = 45; IncludeinReport = "Y"; columnwidth=.9; output; 
       
     run; 
     
  %mend create_t4_tablecolumns;
  %create_t4_tablecolumns();

%mend;

%create_templatefiles();
