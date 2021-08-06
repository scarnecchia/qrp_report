****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t5tables_createdata.sas  
* Created (mm/dd/yyyy): 08/06/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro produces tables for a Type 5 report
*                                        
*  Program inputs:                                                                                   
*   - agg_t5episdur.sas7bdat                                               
*   - agg_t5disp.sas7bdat
*   - agg_t5first.sas7bdat
* 
*
*  Program outputs:                                                                                                                           
*   - TBD
* 
*  PARAMETERS: 
*   - dataset: aggregate dataset from %aggregate_report_tables
*   - whereclause: where clause to restrict input dataset
*   - catvar: variable that will be categorized
*   - countvar: metric counting counts
*   - cattableid: category table ID from TABLEFILE
*   - disttableid: distribution table ID from TABLEFILE
*
* 
*  Programming Notes:                                                                                
*  - Censor tables are computed in a separate macro (censortable_createdata.sas)    
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro t5tables_createdata(dataset=,
                           whereclause=,
                           catvar=,
                           countvar=,
                           cattableid=,
                           disttableid=);

    %put =====> MACRO CALLED: t5tables_createdata ;
	
    /*--------------------------------------------------------------------------------------------*/
    /* Determine all levelIDs and stratifications requested                                       */
    /*--------------------------------------------------------------------------------------------*/
    proc sql noprint;
        select distinct quote(levelid1), quote(levelid2) 
        into :levellist1 separated by ',',
             :levellist2 separated by ','
        from tablefile
        where table in (%if %str("cattableid") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("disttableid") ne %str("") %then %do; "&disttableid" %end;);
        select distinct tablesub
        into :tablesub separated by ' '
        from tablefile
        where table in (%if %str("cattableid") ne %str("") %then %do; "&cattableid" %end;
                        %if %str("disttableid") ne %str("") %then %do; "&disttableid" %end;)
              and tablesub ne 'overall';
    quit;

    /*dedup stratvars list*/
    %nonrep(invar=tablesub, outvar=stratvars);

    /*--------------------------------------------------------------------------------------------*/
    /* Aggregate data                                                                             */
    /*--------------------------------------------------------------------------------------------*/
    proc means data=&dataset.(where=(&whereclause. and level in (&levellist1. &levellist2.))) noprint nway;
		var &countvar.;
		class runid group level &stratvars. &catvar. / missing;
		output out=_t5data_summed(drop=_:) sum=;
	run;

    %if &stratifybydp. = Y %then %do;
        data _t5data_summed;
            set &dataset.(keep=runid group level &stratvars. &catvar. &countvar.
                       where=(&whereclause. and level in (&levellist1. &levellist2.)))
                _t5data_summed(in=a);
            length dpidsiteid $6.;
            if a then dpidsiteid = 'All';
        run;
    %end;



    /*Clean up*/
    proc datasets nowarn noprint lib=work;
        delete _t5data_summed;
    quit;

    %put =====> END MACRO: t5tables_createdata ;

%mend t5tables_createdata;
