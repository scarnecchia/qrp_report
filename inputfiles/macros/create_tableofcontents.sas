****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_tableofcontents.sas  
* Created (mm/dd/yyyy): 02/09/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro createas a dataset with 1 row per table and figure that is used as the 
*          report table of contents
*                                        
*  Program inputs:                                                                                   
*
*  Program outputs:          
*   -tableofcontents: dataset containing table of contents 
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

%macro create_tableofcontents();

    %put =====> MACRO CALLED: create_tableofcontents;

    /*********************************************************************************************/
    /* Utility macro to add row to tableofcontents file                                          */
    /*********************************************************************************************/
    %macro addtotoc(tabnum=, caption=);
    data tableofcontents;
        set tableofcontents end=eof;
        output;
        if eof then do;
            tabnum = "&tabnum";
            caption = "&caption";
            output;
        end;
    run;
    %mend;

    /*********************************************************************************************/
    /* Initialize empty table                                                                    */
    /*********************************************************************************************/
    data tableofcontents;
        length tabnum $25 caption $500;
        call missing(tabnum, caption);
    run;

    /*********************************************************************************************/
    /* Build table of contents                                                                   */
    /*********************************************************************************************/

    /*****************/
    /* Glossary rows */
    /*****************/
    
        *tbd;


    /******************/
    /* Baseline Table */
    /******************/
    








    /*********************/
    /* Remove empty rows */
    /*********************/
    data tableofcontents;
       set tableofcontents;
       if missing(tabnum)=0;
    run;

    %put =====> END MACRO: create_tableofcontents ;

%mend create_tableofcontents;
