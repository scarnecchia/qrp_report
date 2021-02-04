****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: aggregate_l2_datasets.sas  
* Created (mm/dd/yyyy): 02/03/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*	This macro aggregates L2 MSOC datasets from each DP into one dataset;
*   
*  Program inputs:                      
*  - infile        = the name of the file to aggregate across DPs
*  - outfile       = the name of the final file
*  - pscsfile      = QRP input file that defines analysis
*  - convrule      = comma delimited list of indicator numbers to consider model having converged
*  - convdata      = dataset that contains convergence status (QRP [runid]_estimates_[periodid])
*  - settomissvars = comma delimited variables to set to missing if model does not converge
* 
*  Program outputs:                                                                                                                                       
*	- a dataset &&dataout. containing DP data with DP indentification variable
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

%macro aggregate_l2_datasets(infile=,
                             outfile=,
                             pscsfile=,
                             convrule=,
                             convdata=,
                             settomissvars=);

    %put =====> MACRO CALLED: aggregate_l2_datasets;

  	proc datasets library = work nolist nowarn; 
        delete &dataout.; 
    quit;

    %do dps = 1 %to %eval(&num_dp.); 
        %let dpsiteid = %scan(&random_dplist,&dps); 
    	%let maskedID = %scan(&masked_dplist,&dps); 

        *Manage convergence status - if model did not meet convergence status, then set variables list in 
         SETTOMISSVARS to missing;
        %let converge = 1;
        %if &pscsfile. = psmatchfile | &pscsfile. = stratificationfile | &pscsfile. = iptwfile %then %do;
            %if %sysfunc(exist(&dpidsiteid..&convdata))=1 %then %do;
                data _null_;
                	set &dpidsiteid..&convdata.(where=(lowcase(psestimategrp)="&psestimategrp"));
                	if status in(%quote(&convrule.)) then call symputx("converge",1);
                	else call symputx("converge",0);
                run;
            %end;
        %end;

        %if %sysfunc(exist(&dpidsiteid..&infile))=1 %then %do;
			data _temp_&dps.; 
				set &dpsiteid..&datain.(where=(lowcase(analysisgrp)="&analysisgrp"));
				length dpidsiteid $6.;
				dpidsiteid = "&dpsiteid.";
        	  	dum0=1;
          		dp=input("&dps.",best.);

                /*set variables to missing if convergence not met*/
                %if %eval(&converge.=0) %then %do;
                    call missing(&settomissvars.);
                %end;
            run; 

            /*Append to &dataout*/
            proc append data=_temp_&dps. base=&dataout. force; run;
        %end;
        %else %do;
    	   %put WARNING: (Sentinel) &infile does not exist for &dpsiteid..;
        %end;

        /*Write warning to log if data exist by analysisgrp is missing from file*/
        %isdata(dataset=_temp_&dps);
		%if %eval(&nobs.=0) %then %do;
            %put WARNING: (Sentinel File &infile exists for DP &DPIDSITEID., but analysisgrp &analysisgrp. is missing;  
        %end;  


        /*Delete temporary dataset*/
        proc datasets nowarn noprint nolist lib=work; 
            delete _temp_&dps.; 
        quit;	
    		
    %end;*loop through DPs;

	%put NOTE: ******** END OF MACRO: aggregate_l2_datasets ********;

%mend aggregate_l2_datasets; 
