****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: ms_logchecker.sas  
*
* Created (mm/dd/yyyy): 09/23/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*   Reads in the SAS log and checks for concerning lines that may indicate an issue with program execution.                               
*   
*  Program inputs:                                                                                   
*   - Logs to be reviewed
*
*  Program outputs:  
*   - Log checker log = log_checker.log
*   - SAS dataset = log_checker
*
*  PARAMETERS:     
*   - LogDir       = The directory (full path) containing one or more logs to be scanned. This is the directory where outputs will be saved. 
*   - Logname      = The name of the specific log file(s) to be scanned, with the ".log" suffix. If specifying more than one log file, separate with a space. 
*   - Keywords     = Additional, user-specified keywords that the tool will scan and report on, separate with a pipe
*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;
  %macro ms_logchecker(logdir =
                      ,logname =
				      ,keywords =);

    %put =====> MACRO CALLED: ms_logchecker v1.0;
  
  /*-----------------------------------------------------------------------------------------------------------
    Identify log(s) to read in
    -----------------------------------------------------------------------------------------------------------*/
    /* Capture run date and time */
    data _null_;
       call symput('curdate',strip(put(date(),worddate.) || ' @' || put(time(),hhmm.)));
    run;
    
    %let num_logs = 0;
    
    /* Search directory for all log files if no log file is specified */
    %if "&logname" = "%str()" %then %do;
       data _logfiles;
          keep file_name;
          length filref $8 file_name $80; 
          rc = filename(filref, "&logdir"); 
          if rc = 0 then do; 
             dir_id = dopen(filref); 
             rc = filename(filref);  
          end; 
          else do; 
             length msg $200.; 
             msg = sysmsg(); 
             put msg=; 
             dir_id = .; 
             putlog 'ERROR: (Sentinel) Unable to open directory.';
             abort cancel;
          end;
          n_files = dnum(dir_id);
          num_logs=0;
          do i = 1 to n_files; 
             file_name = dread(dir_id, i); 
             file_id = mopen(dir_id, file_name); 
             if file_id > 0 and reverse(compress(file_name)) =: 'gol.' 
							and index(file_name,"log_checker") = 0 then do;
                num_logs=num_logs+1;
                output;
             end;
          end;
          rc = dclose(dir_id);
          call symputx('num_logs',strip(put(num_logs,5.)));
       run;
  	
       proc sql noprint;
       select strip(file_name) into :logname separated by ' '
          from _logfiles;
       quit;
    %end;
    %else %do;
      %let num_logs = %sysfunc(countw("&logname",' '));
    %end;
    
  /*-----------------------------------------------------------------------------------------------------------
    If there are no files found abort and put error in the log
    -----------------------------------------------------------------------------------------------------------*/ 
    %if %eval(&num_logs = 0) %then %do;
       data _null_;
  	     put "ERROR: (Sentinel) No logs located in the specified folder &logdir.";
  	     abort;
  	   run;
    %end;  
    
  /*-----------------------------------------------------------------------------------------------------------
    Notes that indicate an issue with the program
    -----------------------------------------------------------------------------------------------------------*/
    %let notes = stopped|converted|uninitialized|division|invalid|missing values|w.d format|repeats of by values|merge statement|;
	%let notes = &notes.mathematical|character values have disabled|groups are not|will be overwritten|limit set by errors= option reached;
	%if "&keywords." ne "" %then %do;
	  %let notes = &notes.|&keywords.;
	%end;

	%let num_notes = %sysfunc(countw(&notes.,"|"));
	%do n = 1 %to &num_notes.;
	  %let note&n. =%sysfunc(scan(&notes.,&n.,'|'));
	%end;

  /*-----------------------------------------------------------------------------------------------------------
    Loop through all logs looking for errors, warnings, and notes
    -----------------------------------------------------------------------------------------------------------*/
    %do f = 1 %to &num_logs.;
        %let logfile = %scan(&logname,&f.,' ');
        data _input_log&f. (keep = logline_number logline logname macro level description);
	      length firstword secondword $1000 logline $32767 logname $50 level 3 macro $250 description $25 logline_number 8;
          infile "&logdir.&logfile.";
		  retain macro description;
		  input;
          logline_number + 1;
		  logname = "&logfile.";
		  logline = _infile_;
          firstword = compress(tranwrd(strip(lowcase(scan(_infile_,1,' '))),".ms_starttimer",""),""); /* remove starttimer macro */
		  secondword = compress(tranwrd(strip(lowcase(scan(_infile_,2,' '))),".ms_starttimer",""),"");
		  
		  if length(firstword) < 4 then delete;  /*These lines do not contain Errors, Warnings or Notes */
		  else if substr(firstword,1,4) not in ("note", "erro", "warn", "mpri") then delete; 

          /*macro available when mprint option on*/
          if substr(firstword,1,6)='mprint' then do;
            macro = substr(firstword, 8,length(firstword)-9);
          end;

		  if index(firstword,"warning") and index(secondword,"sentinel") then do;
  		    description = "Sentinel Warning";
			level = 4;
		  end;
		  else if index(firstword,"error") and index(secondword,"sentinel") then do;
		    description = "Sentinel Error";
			level = 2;
		  end;
		  else if index(firstword,"error") then do;
		    description = "SAS Error";
			level = 1;
		  end;
		  else if index(firstword,"warning") then do;
		    description = "SAS Warning";
			level = 3;
		  end;
		  else if index(firstword,"note") then do;
		    description = "SAS Note";
		  end;

		  if description = "SAS Note" then do;
		    %do n = 1 %to &num_notes.;
			  if index(lowcase(logline),"&&note&n..") > 0 and index(lowcase(logline),"data step stopped due to looping") = 0 
                %if "&&note&n.." = "invalid" %then %do;
                    and index(lowcase(logline),"'invalid'") = 0 and index(lowcase(logline),'"invalid"') = 0 and index(lowcase(logline),"(invalid)") = 0 
                %end;
                then level = 5;
			%end;
		  end;

		  if level in (1, 2, 3, 4, 5) then output;
       run;
	
	%end;
	
  /*-----------------------------------------------------------------------------------------------------------
    Save final dataset to msoc folder
    -----------------------------------------------------------------------------------------------------------*/
    libname Outlib "&logdir.";	
	data  Outlib.log_checker;
	  set _input_log:;
	run;
	
  /*-----------------------------------------------------------------------------------------------------------
    Sort log checker dataset by level, logname, logline_number
    -----------------------------------------------------------------------------------------------------------*/	
	proc sort data = Outlib.log_checker;
	  by level logname logline_number;
	run; 
	
	proc datasets noprint lib = work;
	  delete _input_log:;
	quit;
	
	%put NOTE: ********END OF MACRO: ms_logchecker v1.0********;

  %mend ms_logchecker;
