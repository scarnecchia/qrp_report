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
*  - whereclause   = condition to restrict infile
*  - convrule      = comma or space delimited list of indicator numbers to consider model having converged
*  - convdata      = dataset that contains convergence status (QRP [runid]_estimates_[periodid])
*  - settomissvars = comma delimited variables to set to missing if model does not converge
*  - renameclause  = optional rename statement when reading in dataset 
*
*  Program outputs:                                                                                                                                       
*	- a dataset &outfile. containing DP data with DP indentification variable
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
                             whereclause=,
                             convrule=,
                             convdata=,
                             settomissvars=,
                             renameclause=,
                             runidvar=);

    %put =====> MACRO CALLED: aggregate_l2_datasets;

    %if &outfile ^= aggwd and %index(&infile.,varinfo) = 0 %then %do;
  	  proc datasets library = work nolist nowarn; 
        delete &outfile.; 
      quit;
    %end;

    %do dps = 1 %to %eval(&num_dp.); 
        %let dpidsiteid = %scan(&random_dplist,&dps); 
    	%let maskedID = %scan(&masked_dplist,&dps); 

        *Manage convergence status - if model did not meet convergence status, then set variables list in 
         SETTOMISSVARS to missing;
        %let converge = 1;
        %if %length(&convrule.)>0 %then %do;
        %if &pscsfile. = psmatchfile | &pscsfile. = stratificationfile | &pscsfile. = iptwfile %then %do;
            %if %sysfunc(exist(&dpidsiteid..&convdata))=1 %then %do;
                data _null_;
                	set &dpidsiteid..&convdata.(where=(lowcase(psestimategrp)="&psestimategrp"));
                	if status in(%quote(&convrule.)) then call symputx("converge",1);
                	else call symputx("converge",0);
                run;
            %end;
        %end;
        %end;

        %if %sysfunc(exist(&dpidsiteid..&infile))=1 %then %do;
			data _temp_&dps.; 
				set &dpidsiteid..&infile.(where=(&whereclause.)&renameclause.);
				length dpidsiteid $4.;
				dpidsiteid = "&maskedID.";
        	  	dum0=1;
          		dp=input("&dps.",best.);
                %if %length(&runidvar) > 0 %then %do;
                  length runid $5.;
                  runid="&runid.";
                %end;
				/* Assign codecat and codetype for HDPS Vars */
				%if %index(&infile.,varinfo) > 0 %then %do;
				   length ranking 8 frequency $18 codetype $5 codecat $2 periodid 3;
				   if index(dimension,'ICD') > 0 then do;
	                 codetype = reverse(substr(strip(reverse(dimension)),1,2));
	                 codecat = reverse(substr(strip(reverse(dimension)),3,2));
                   end;
                   else if index(dimension,'DRUGCLASS') > 0 then do;
	                 codetype = 'CLASS';
	                 codecat = 'RX';
                   end;
				   else do;
	                 codetype = scan(dimension,-1,'_');
	                 codecat = 'PX';
                   end;
				   
				   if index(var_name,'Frequent') > 0 then frequency = 'Frequent';
				   else if index(var_name,'Any') > 0 then frequency = 'Any';
				   else if index(var_name,'Often') > 0 then frequency = 'Often';
				   else frequency = substr(var_name, index(var_name, '_Q')+1);
				   
				   periodid = &periodid.;
				   
				   keep psestimategrp codecat codetype dpidsiteid frequency ranking code periodid runid;
				%end;
                
                /*set variables to missing if convergence not met*/
                %if %eval(&converge.=0) %then %do;
                    call missing(&settomissvars.);
                %end;
            run; 

            /*Append to &outfile*/
            proc append data=_temp_&dps. base=&outfile. force; run;
			
			/*If varinfo then append for msocdata output*/			
			%if %index(&infile.,varinfo) > 0 %then %do;
				data _temp_varinfo_&dps.; 
					set &dpidsiteid..&infile.(where=(lowcase(psestimategrp)="&psestimategrp"));
					length dpidsiteid $4.;
					dpidsiteid = "&maskedID.";
					%if %length(&runidvar) > 0 %then %do;
					  length runid $5.;
					  runid="&runid.";
					%end;
				run;
				
				proc append data=_temp_varinfo_&dps. base=agg_varinfo force; run;
	
			%end;
        %end;
        %else %do;
    	   %put WARNING: (Sentinel) &infile does not exist for &dpidsiteid..;
        %end;

        /*Write warning to log if data exist by analysisgrp is missing from file*/
        %isdata(dataset=_temp_&dps);
		%if %eval(&nobs.=0) %then %do;
            %put WARNING: (Sentinel File &infile exists for DP &DPIDSITEID., but analysisgrp &analysisgrp. is missing;  
        %end;  

        /*Delete temporary dataset*/
        proc datasets nowarn noprint nolist lib=work; 
            delete _temp_&dps. _temp_varinfo_&dps.; 
        quit;	
    		
    %end;*loop through DPs;
	

	%if &output_agg_data. = Y and &leavebehindreport. = N %then %do;
		%if %sysfunc(exist(msocdata.agg_%scan(&infile.,2,_)_&periodid.))=0 | &outfile = aggwd %then %do;
			data msocdata.agg_%scan(&infile.,2,_)_&periodid.;
			%if %index(&infile.,varinfo) > 0 %then %do;
				set agg_varinfo;
			%end;
			%else %do;
				set &outfile.;
			%end;
			run;
		%end;
		%else %do;
			data msocdata.agg_%scan(&infile.,2,_)_&periodid.;
				set msocdata.agg_%scan(&infile.,2,_)_&periodid.
			%if %index(&infile.,varinfo) > 0 %then %do;
				    agg_varinfo;
			%end;
			%else %do;
				    &outfile.;
			%end;
			run;
		%end;
	%end;
	
	%put NOTE: ******** END OF MACRO: aggregate_l2_datasets ********;

%mend aggregate_l2_datasets; 
