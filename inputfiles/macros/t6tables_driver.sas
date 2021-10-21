****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t6tables_driver.sas  
* Created (mm/dd/yyyy): 10/21/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The driver macro produces tables for a Type 6 report
*                                       
*  Program inputs:          
* 
*  Program outputs:                                                                                                                                       
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

%macro t6tables_driver();

    %put =====> MACRO CALLED: t6tables_driver ;

    /*--------------------------------------------------------------------------------------------*/
    /* Loop through each table                                                                    */
    /*--------------------------------------------------------------------------------------------*/

    %do t =1 %to %sysfunc(countw(&tablelist.));
        %let table = %scan(&tablelist., &t.);

         data _null_;
            set tablefile(where=(table = "&table"));
            if _n_ = 1 then do;
                call symputx('dataset', strip(dataset));
                call symputx('levelid1', levelid1);

                call symputx('censorreason', censorreason);
                
                /*assign group and day variables*/
                if dataset = 't6censor' then do;
                    call symputx('groupvar', 'group');
                    call symputx('dayvar', 'episodelength');
                end;
                else do;
                    call symputx('groupvar', 'analysisgrp');
                    call symputx('dayvar', 'ttswitch');
                end;
            end;
        run;

    	*** Censor tables ***;
    	%if %sysfunc(prxmatch(m/T8\b|T9\b|T10\b/i,&tablelist.)) > 0 %then %do;
            %censortable_createdata_t6(table=&table., 
                                       censordataset=agg_&dataset., 
                                       censorreason=&censorreason., 
                                       levelid=&levelid1.,
                                       groupvar=&groupvar.,
                                       dayvar=&dayvar.) ;
        %end;

    %end; /*loop through each table*/

%abort;

	%put =====> END MACRO: t6tables_driver ;

%mend t6tables_driver;
