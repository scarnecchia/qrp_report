****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_expand_parameters.sas  
* Created (mm/dd/yyyy): 11/19/2020
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This utility macro takes a macro variable that contains a space delineated list and/or 
*          covariates with a dash notation in the format COVAR#-COVAR# and expands the covariate list
*          to use in a data step in ("var" "var") notation
*
*  Program inputs:    
*   - Macro variable containing space delineated list 
* 
*  Program outputs:                                                                                                                                       
*   - Macro variable containing each variable in the list in double quotes and separated by a space
* 
*  PARAMETERS:        
*   - var: macro variable to expand. This should be entered as the variable name without an ampersand
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

%macro baseline_expand_parameters(var =);

    %put =====> MACRO CALLED: baseline_expand_parameters;

    %put Expanding macro variable &var = &&&var.;

    /*initialize temporary variable*/
    %let tempvar = ;

    %if %length(&&&var.) > 0 %then %do;
        %let countvars = %sysfunc(countw(%quote(&&&var), %str( )));
            /*loop through each word. If '-' is used, then expand to each covar*/
            %do count = 1 %to &countvars.;
                %let word = %scan(%quote(&&&var),&count, %str( ));
                    %if %index(&word.,%str(-)) = 0 %then %do;
                        %if &count = 1 %then %do;
                            %let tempvar = "&word.";
                        %end;
                        %else %let tempvar = &tempvar. "&word.";
                    %end;
                    %else %do;
                        %let start = %sysfunc(substr(%scan(%quote(&word.),1,%str(-)), 6));
                        %let end = %sysfunc(substr(%scan(%quote(&word.),2,%str(-)), 6));
                        %do covar = &start. %to &end.;
                            %if &count = 1 and &covar = &start. %then %do;
                                %let tempvar = "COVAR&covar.";
                            %end;
                            %else %let tempvar = &tempvar.  "COVAR&covar.";
                        %end;
                    %end;
            %end;

        /*Reassign to original macro variable*/
        %let &var = &tempvar.;     
    %end;
    %else %let &var ='';

    %put Expanded macro variable &var. = &&&var.;
    
    %put =====> END MACRO: baseline_expand_parameters;

%mend baseline_expand_parameters;

