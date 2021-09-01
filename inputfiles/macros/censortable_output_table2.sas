****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: censortable_output_table2.sas  
* Created (mm/dd/yyyy): 08/27/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates table 2 output
*                                        
*  Program inputs:                                                                                   
* 
*  Program outputs:                                                                                                                                       
*
*  PARAMETERS: •	
*   Tablename – dataset name (t1censor/t2censor/t2followuptime/t5censor/t5censor_first)
*	Title – table title
*	Where – where clause to filter the &tablename dataset
*   Reasonlist – list of reasons to include in table  
*   Tablenum - number for table 
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
%macro censortable_output_table2 (Tablename=, Title=, Where=, Reasonlist=, tablenum=, stratification = );
                            
ods excel options(sheet_name="Table &tablenum.");
    ods proclabel = "Table &tablenum.";

    proc report data = repdata.&Tablename.&tablenum. nofs nowd spanrows missing headskip split="*"
    	style(header)=[rules=none background=white font_weight=bold font_size=8pt color=black just = c fontfamily=arial vjust=b] split='*'
    	style(report)=[rules=none frame=box background=white foreground=black cellpadding =&line_spacing.pt color=black];
    		
    	columns ("^{style[just=l background=ligr borderrightcolor=ligr]&title}"
             grouplabel maskedID %if %str("&stratification") = "DP" %then %do; display_dp %end; %if %str("&STRATIFICATION") ^= "DP" and %str("&STRATIFICATION") ne %str("") %then %do; &STRATIFICATION display_&STRATIFICATION %end;  Epi_Tot  
             %do i = 1 %to &&&Tablename._num.;
                %let CEN_VAR = %lowcase(%scan(&&&Tablename._reason, &i));
                    %if "&cen_var" = "cens_elig" %then %let cenlabel = Disenrollment;
                    %if "&cen_var" = "cens_dth" %then %let cenlabel = Death;
                    %if "&cen_var" = "cens_qryend" %then %let cenlabel = Query End Date;
                    %if "&cen_var" = "cens_dpend" %then %let cenlabel = Data Partner End Date;
                    %if "&cen_var" = "cens_event" %then %let cenlabel = Event;
                    %if "&cen_var" = "cens_spec" %then %let cenlabel = Additional Criteria;
                    %if "&cen_var" = "cens_episend" %then %let cenlabel = Episode End Date;
                ("^S={just=c background=white borderbottomcolor=black}&cenlabel" &cen_var &cen_var._pct)
             %end;
            );

        /*if overall - print grouplabel, if stratified - group label will be in compute block*/
        %if %str("&stratification.") = %str("") %then %do;
    	define grouplabel / group "" order=data
    	  style(column)=[font_size=8pt color=black fontfamily=arial width =1.5in just=l] style(header)=[just=C background=white borderbottomcolor=black];
        %end;

        define maskedID /group noprint;

        %if %str("&stratification") = "DP" %then %do; 
        define display_DP / computed "" order=data
         style(column)=[font_size=8pt color=black fontfamily=arial width =.5in just=l indent=10] style(header)=[just=C background=white borderbottomcolor=black];
        define grouplabel /group noprint;
        %end;

        %if %str("&STRATIFICATION") ^= "DP" and %str("&STRATIFICATION") ne %str("")  %then %do;
        define &STRATIFICATION / group noprint;
        define display_&STRATIFICATION / computed "" order=data %if %bquote("&AGEGROUPFMT") ne %str("") and &STRATIFICATION = agegroup %then %do; format=$agefmt. %end;
         style(column)=[font_size=8pt color=black fontfamily=arial width =  %if %bquote("&AGEGROUPFMT") ne %str("") and &STRATIFICATION = agegroup %then %do; 1in %end; %else %do; .5in %end; just=l indent=10] style(header)=[just=C background=white borderbottomcolor=black];
        define grouplabel /group noprint;
        %end;

        define epi_tot / group "Total Number of Episodes" format = comma12.0
    	  style(column)=[font_size=8pt color=black fontfamily=arial width =.6in just=c background= background_n_fmt.] 
		  style(header)=[just=C background=white borderbottomcolor=black];

        %do i = 1 %to &&&Tablename._num;
            %let cen_var = %scan(&&&Tablename._reason, &i., ' ');
            define &cen_var. / sum 'Number of Episodes' format=comma12.0
               style(column)=[font_size=8pt fontfamily=arial just=C width=55pt background= background_n_fmt.] 
			   style(header)=[just=C background=white borderbottomcolor=black];
            define &cen_var._pct / sum '% Total Episodes' format=percent7.1
               style(column)=[font_size=8pt fontfamily=arial just=C width=43pt] style(header)=[just=C background=white borderbottomcolor=black];
        %end;

        %if %str("&stratification.") ne %str("") %then %do;
        compute before grouplabel / style=[background=ligr fontfamily=arial font_size=8pt just=L font_weight=bold bordertopcolor=black borderbottomcolor=black];
            text= grouplabel; 
            num= 150;
			line text $Varying. num; 
	    endcomp;

        compute before maskedID;
           tempid = maskedID;
        endcomp;

        %if %str("&STRATIFICATION") = "DP" %then %do;
        compute display_dp / character length=5;
        	display_dp = tempid;
        endcomp;
        %end;

        %if %str("&STRATIFICATION") ^= "DP" and %str("&STRATIFICATION") ne %str("")  %then %do;
        compute display_&STRATIFICATION / character length=20;
            display_&STRATIFICATION = &STRATIFICATION;
        endcomp;
        %end;

        %end;


        where &where.;
    run;

%mend censortable_output_table2;
