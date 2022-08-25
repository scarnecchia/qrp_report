****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: convert_inputfiles_sasformat.sas  
* Created (mm/dd/yyyy): 08/11/2022
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*  This file contains two macros:
*
*  Macro 1: convert_inputfiles determines if CSV input files exists, reads in as SAS datasets, and 
*           reads in JSON data dictionary
*
*  Program inputs: 
*   - csv files 
*   - QRP data dictionary
*                                     
*  Program outputs:
*   - Raw SAS datasets 
*                                                                                                  
*  PARAMETERS:                              
*   -lib            =   inputfiles directory where the csv files are located
*   -json_lib       =   integration directory where the json files are located
*
*
*  Macro 2: get_sas_format uses the format in the data dictionary to apply variable lengths
*
*  Program inputs: 
*   - Raw SAS dataset
*   - QRP data dictionary
*                                     
*  Program outputs:
*   - Formatting SAS datasets 
*                                                                                                  
*  PARAMETERS:                              
*   -lib            =   inputfiles directory where the csv files are located
*   -inputfile      =   input file name
*   -parameter      =   input parameter name
*
*
*  Programming Notes:                                                                                                                                       
*                                                                                  
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*******************************************************************************************************;

%macro convert_inputfiles (LIB =, JSON_LIB=);

    %put =====> MACRO CALLED: convert_inputfiles ;

    libname tmplib "&lib";

    /*read in all CSV files and get the names*/
    data tmplib.filenames(where=(substr(fname1, length(fname1)-2, 3)= 'csv'));
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

    %isdata(dataset=tmplib.filenames);
    %if %eval(&nobs.>0) %then %do;

        %let list_set= ;
        proc sql noprint;
            select fname into: list_set 
            separated by " " from tmplib.filenames
        quit;

        %put &list_set;


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

        proc sql noprint;
            create table tmplib.format_values as
            select a.id, a.sas_format, b.id as inputfile,
                case when index(lowcase(sas_format), 'date')>0 then cat(strip(a.id)," ",4)
                else cat(strip(a.id)," ",strip(a.sas_format)) 
                end as id_format
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


%macro get_sas_format(lib=, inputfile = , parameter=);
    /*check if input file is CSV*/
    %let applyformats= N;
   
    data _null_;
        set &lib..filenames;
        if upcase(fname) = upcase("&inputfile") then call symputx('applyformats', 'Y');
    run;

    /*if CSV file, apply variable lengths*/
    %if &applyformats = Y %then %do;

        %let date_id = ;
        proc sql noprint;
            select id_format, id into 
            :sas_format separated by " ", 
            :sas_id separated by " " 
            from &lib..format_values
            where upcase(inputfile) = upcase("&parameter");

            select id
            into :date_id separated by " "
            from &lib..format_values
            where upcase(inputfile) = upcase("&parameter") and index(lowcase(sas_format), 'date9')>0;
        quit;

        data &lib..&inputfile.;
            set  &lib..&inputfile. (rename =(%do var = 1 %to %sysfunc(countw(&sas_id));
                                                 %let current_var = %scan(&sas_id, &var);
                                                 &current_var. = csv_&current_var.
                                             %end;)
                                    );
            length &sas_format.;

            %do var = 1 %to %sysfunc(countw(&sas_id));
                %let current_var = %scan(&sas_id, &var);
                &current_var. = csv_&current_var.;
            %end;

            %if %length(&date_id.)>0 %then %do;
                %do var = 1 %to %sysfunc(countw(&date_id));
                    %let current_var = %scan(&date_id, &var);
                    format &current_var. date9.;
                %end;
            %end;

            /*clean up character variables*/
            array charvars[*] $ _char_;
            do i=1 to dim(charvars);
                charvars{i}=strip(charvars{i});
                if charvars{i}='.' then call missing(charvars{i});
            end;

            drop i csv_:;
        run;

        proc datasets nowarn noprint lib=work;
            delete &inputfile.;
        quit;

    %end; /*csv file exists*/

%mend get_sas_format;
