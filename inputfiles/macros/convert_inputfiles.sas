****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: convert_inputfiles.sas  
* Created (mm/dd/yyyy): 08/11/2022
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*  Converts CSV inputfiles to SAS inputfiles and reads in JSON data dictionary
*   
*  Program inputs: 
*   - csv files 
*   - QRP data dictionary
*                                     
*  Program outputs:
*   - sas datasets 
*                                                                                                  
*  PARAMETERS:                              
*   -lib            =   inputfiles directory where the csv files are located
*   -json_lib       =   integration directory where the json files are located
*
*  Programming Notes:                                                                                                                                       
*                                                                                  
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*******************************************************************************************************;

%macro convert_inputfiles (package = , LIB =, JSON_LIB=);

    %put =====> MACRO CALLED: convert_inputfiles ;

    /*read in all CSV files and get the names*/
    data filenames&package.(where=(substr(fname1, length(fname1)-2, 3)= 'csv'));
        length fref $8 fname fname1 $200;
        did = filename(fref,"&lib");
        did = dopen(fref);
        do i = 1 to dnum(did);
            fname1 = dread(did,i);
            fname = substr(fname1, 1, length(fname1)-4);
            output;
        end;
        did =dclose(did);
        did = filename(fref);
     run;

     %isdata(dataset=filenames&package.);
     %if %eval(&nobs.>0) %then %do;

        %let list_set= ;
        proc sql noprint;
            select fname into: list_set 
            separated by " " from filenames&package.
        quit;

        %put &list_set;

        libname tmplib "&lib";

        %do f = 1 %to %sysfunc(countw(&list_set));
            %let inputfile = %scan(&list_set, &f.);

            /*Note if file will be overwritten*/
            %isdata(dataset=tmplib.&inputfile.);
            %if %eval(&nobs.>0) %then %do;
               %put NOTE: (Sentinel) Inputfile &inputfile already exists as a SAS dataset and will be overwritten wiith contents of CSV file;
            %end;

            proc import file ="&lib.&inputfile..csv"
                out = tmplib.&inputfile.
                dbms = csv
                replace;
            run;
        %end;

        /*grab the json file information for sas_formats contents*/
        filename dd "&json_lib./data_dictionary.json";
        libname newlib JSON fileref=dd access=readonly;

        proc datasets lib=newlib nolist nodetails memtype=data;
            copy out=work;
            select input_files_parameters input_files;
        quit;

        proc sql;
            create table format_values as
            select a.id, a.sas_format, b.id as inputfile, cat(strip(a.id)," ",strip(a.sas_format)) as id_format
            from input_files_parameters as a left join input_files as b
            on a.ordinal_input_files = b.ordinal_input_files;
        quit;

        /*clean up the datasets*/
        proc datasets library=WORK;
            delete input_files_parameters strip;
        quit;

    %end;

    %put NOTE: ********END OF MACRO: convert_inputfiles ********;

%mend convert_inputfiles;


/*get the variables and the sas_format for needed dataset*/
%macro get_sas_format (package=, lib=, inputfile = , parameter=);

    /*check if input file is CSV*/
    %let applyformats= N;
   
    data _null_;
        set filenames&package.;
        if upcase(fname) = upcase("&inputfile") then call symputx('applyformats', 'Y');
    run;

    %if &applyformats = Y %then %do;
      proc sql noprint;
        select id_format into: sas_format 
        separated by " " from format_values
        where upcase(inputfile) = upcase("&parameter");
      quit;

      data &lib..&inputfile.; 
/*        length &sas_format.;*/
        set &lib..&inputfile.;
      run;
    %end;

%mend;


