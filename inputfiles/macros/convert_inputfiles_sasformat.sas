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
*  Macro 1: convert_inputfiles determines if CSV input files exists, reads in JSON data dictionary,
*           and creates SAS syntax for data step
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
*  Macro 2: get_sas_format uses the format in the data dictionary to read in CSV file and apply variable lengths
*
*  Program inputs: 
*   - Raw SAS dataset
*   - QRP data dictionary
*                                     
*  Program outputs:
*   - Formatting SAS datasets 
*                                                                                                  
*  PARAMETERS:    
*   -path           =   inputfiles path 
*   -lib            =   SAS libname where the csv files are located
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

        /*grab the json file information for sas_formats contents*/
        filename dd "&json_lib./data_dictionary.json";
        libname newlib JSON fileref=dd access=readonly;

        proc datasets lib=newlib nolist nodetails memtype=data;
            copy out=work;
            select input_files_parameters input_files;
        quit;

        proc sql noprint;
            create table tmplib.format_values as
            select a.id, 
                   a.sas_format,
                   b.id as inputfile,

                   /*format*/
                    case when index(lowcase(sas_format), 'date')>0 or index(sas_format, '$')>0 then cat("format ",strip(a.id)," ",strip(a.sas_format), ".;")
                    else ""
                    end as format_statement,

                   /*informat*/
                    case when index(lowcase(sas_format), 'date')>0 or index(sas_format, '$')>0 then cat("informat ",strip(a.id)," ",strip(a.sas_format), ".;")
                     else ""
                     end as informat_statement,

                    /*length*/
                    case when not missing(sas_format) and index(sas_format, '$')=0 and index(lowcase(sas_format), 'date')=0 then cat("length ",strip(a.id)," ",strip(a.sas_format), ";")
                         when index(sas_format, '$')=0 and index(lowcase(sas_format), 'date')>0 then cat("length ",strip(a.id)," ", "4;")
                    else ""
                    end as length_statement,

                    /*input statement*/
                    case when index(sas_format,"$")>0 then cat(strip(a.id)," ","$")
                    else strip(a.id) 
                    end as input_statement

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


%macro get_sas_format(path=, lib=, inputfile = , parameter=);
    /*check if input file is CSV*/
    %let applyformats= N;
   
    data _null_;
        set &lib..filenames;
        if upcase(fname) = upcase("&inputfile") then call symputx('applyformats', 'Y');
    run;

    /*if CSV file, apply variable lengths*/
    %if &applyformats = Y %then %do;

        /*Note if file will be overwritten*/
        %isdata(dataset=&lib..&inputfile.);
        %if %eval(&nobs.>0) %then %do;
            %put NOTE: (Sentinel) Inputfile &inputfile already exists as a SAS dataset and will be overwritten with contents of CSV file;
        %end;

        /* Store the relevant inputfile variables that need dynamic length assigned */
        %let dynamic_format_list =;
        proc sql noprint;
            select id
            into :dynamic_format_list separated by ' '
            from tmplib.format_values
            where upcase(inputfile)="%upcase(&parameter)" and missing(sas_format);
        quit;

        /*import csv in order to acertain variable order for input statement*/
        proc import file ="&path./&inputfile..csv"
            out = tmpfile
            dbms = csv
            replace;
        run;

        %if %length(&dynamic_format_list) > 0 %then %do;
            %do i = 1 %to %sysfunc(countw(&dynamic_format_list));
                %let format_variable = %scan(&dynamic_format_list,&i);
                %varlength(var = &format_variable, indata = tmpfile);

                /* This will assign the format for each inputfile/variable combo */
                data tmplib.format_values;
                    set tmplib.format_values;
                    length full_inputfile_name $32;
                    if upcase(inputfile) = "%upcase(&parameter)" and id = "&format_variable" and missing(sas_format) then do; 
                    sas_format="$&&&format_variable._len";
                    format_statement="format &format_variable $&&&format_variable._len..;";
                    informat_statement="informat &format_variable $&&&format_variable._len..;";
                    input_statement="&format_variable $";
                    full_inputfile_name = "&inputfile";
                    end;
                run;
            %end; /* i */
        %end; /* %length(&dynamic_format_list) > 0 */

        proc contents data=tmpfile noprint out=tmpfilecontents; run;

        proc sql noprint;
            select format_statement, 
                   informat_statement, 
                   length_statement,  
                   input_statement
            into 
                :format_statement separated by " ", 
                :informat_statement separated by " ", 
                :length_statement separated by " ",
                :input_statement separated by " "
            from (
                  select x.*,
                         y.varnum
                  from tmplib.format_values(where=(upcase(inputfile) = upcase("&parameter"))) as x
                  left join tmpfilecontents as y
                  on upcase(x.id) = upcase(y.name)) as a
            order by varnum;
        quit;

        /*create new input file*/
		data &lib..&inputfile.;
            &length_statement.;

            infile "&path./&inputfile..csv"
        	delimiter = ","
        	missover 
        	dsd
        	firstobs=2;

            &format_statement.;
            &informat_statement.;
            input &input_statement.;
        run;

        proc datasets nowarn noprint lib=work;
            delete tmpfile tmpfilecontents;
        quit;
		
    %end; /*csv file exists*/

%mend get_sas_format;
