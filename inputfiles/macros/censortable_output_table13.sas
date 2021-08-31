****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_output_table13.sas  
* Created (mm/dd/yyyy): 08/30/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro contains a proc report to produce 2 L1 censor tables
*                                        
*  Program inputs:                                                                                   
*   - t2censor
*   - t2followuptime
*   - t5censor
*   - t5censor_first
* 
*  Program outputs: 
* 
* 
*  PARAMETERS:       
*   - tablename: input dataset name
*   - tablenum: table number
*   - title: table title in report
*   - where: where clause to restrict input dataset
*   - tablesub: table stratifier
*   - continuousmetrics: Y/N indicator to print continuous metrics
*   - cattableheader: language to include across category header "Number of Episodes ...."
*   - conttableheader: language to include across continuous metrics
*   - episodesorpatients: Episodes or Patients label
*            
*  Programming Notes:         
*   
*                                                                           
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro censortable_output_table13(tablename=, 
                                  tablenum=,
                                  title=, 
                                  where=,
                                  tablesub=,
                                  continuousmetrics=, 
                                  cattableheader=,
                                  conttableheader=,
                                  episodesorpatients=);

    %put =====> MACRO CALLED: censortable_output_table13;

    /*Save dataset to REPORTDATA folder*/
    %isdata(dataset=repdata.table&tablenum.);
    %if %eval(&nobs.<1) %then %do;
        data repdata.table&tablenum.;
            set &tablename(where=(&where.));
            %if &continuousmetrics. = Y %then %do;
            dummy = '';
            %end;
        run;
    %end;

    %if &destination. = excel %then %do;
    ods excel options(sheet_name="Table &tablenum." tab_color = "green");
    %end;

    ods proclabel = "Table &tablenum.";
    proc report data=repdata.table&tablenum. nofs nowd spanrows missing split='*'
        style(header)=[rules=none frame=void background=BGR borderleftcolor = BGR vjust=b] split='*'
	    style(report)=[rules=none frame=void cellpadding =1.5pt];

    	columns %if &includeheaderrow = Y %then %do; headerlabel %end; grouplabel (%if &tablesub. ne overall %then %do; &tablesub. %end; epi_tot
                 ("^S={background=BGR}Number of Episodes &cattableheader." censdays_value_cat_format, (episodes epi_tot_pct) ) 
                 %if &continuousmetrics. = Y %then %do; (dummy, (min q1 median q3 max mean std) ) %end;);

        %if &includeheaderrow = Y %then %do; 
        define headerlabel / group noprint order=data ' ';
        %end;

        /*if overall - print grouplabel, if stratified - group label will be in compute block*/
        %if &tablesub. = overall %then %do;
        define grouplabel / group "" order=data style(column)=[just=L width =1.5in fontstyle=italic] style(header)=[background = BGR borderleftcolor = BGR]; 
        %end;
        %else %do;
        define &tablesub. / group  "" order=data style(column)=[just=L width=.9in];
        define grouplabel /group noprint;
        %end;

        define epi_tot / group "Total Number of &episodesorpatients"
            style(column)=[width =.8in tagattr="type:string" background= backgroundfmt.] 
            style(header)=[just=C background = BGR borderleftcolor = BGR];

        define censdays_value_cat_format / across '' order=data
            style(column)=[just=C tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define episodes / "Number of &episodesorpatients"
           style(column)=[just=C width=55pt background= backgroundfmt. tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define Epi_Tot_Pct / "Percent of &episodesorpatients"
           style(column)=[just=C width=43pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];

        %if &continuousmetrics. = Y %then %do;
        define dummy / across "Distribution of &conttableheader. in Days, by Episode" style(header)=[background = BGR borderleftcolor = BGR];
        define min /group 'Minimum' style(column)=[just=C width=37pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define q1 /group 'Q1' style(column)=[just=C width=27 tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define median /group 'Median' style(column)=[just=C width=30pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define q3 /group 'Q3' style(column)=[just=C width=27pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define max /group 'Maximum' style(column)=[just=C width=40pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define mean /group 'Mean' style(column)=[just=C width=27pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        define std /group 'Standard^n Deviation'  style(column)=[just=C width=44pt tagattr="type:string"] style(header)=[just=C background = BGR borderleftcolor = BGR];
        %end;

        /*Add title*/
        compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor = white
    	                              borderbottomwidth = &bordersize tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
        line "Table &tablenum.. &title.";
        endcomp;

        /*Add header if requested*/
        %if &includeheaderrow = Y %then %do; 
            compute before headerlabel / style=[background=LIBGR just=L font_weight=bold bordertopcolor=LIBGR borderbottomcolor=LIBGR];
            length text $100;
                text = headerlabel;
                num = 100;
                line text $varying. num;
            endcomp;
        %end;

        /*Add group label spanning header if stratified table and indent labels*/
        %if &tablesub. ne overall %then %do; 
            compute before grouplabel /
                    %if &includeheaderrow = Y %then %do; 
                    style=[background=white just=L fontstyle=italic bordertopcolor=white borderbottomcolor=white];
                    %end;
                    %else %do;
                    style=[background=LIBGR just=L font_weight=bold bordertopcolor=LIBGR borderbottomcolor=LIBGR];
                    %end;
                text= grouplabel; 
                num= 150;
            	line text $varying. num; 
            endcomp;

            /*indent*/
            compute &tablesub.;
                call define(_col_,'style','style={indent=25}');
            endcomp;
        %end;

        /*Footnotes*/

    run;

%mend censortable_output_table13;
