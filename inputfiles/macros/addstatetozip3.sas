****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: addstatetozip3.sas  
* Created (mm/dd/yyyy): 08/09/2017
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro adds state based on 3 Digit Zip Code.                                      
*  Program inputs:                                                                                   
*   - 3 Digit Zip
* 
*  Program outputs:                                                                                                                                       
*   - 3 Digit Zip/State
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

%macro addstatetozip3(data=);
    
  %put =====> MACRO CALLED: addstatetozip3;
 
      proc sql noprint;
        create table _tempzip as
        select distinct 
          statecode,
          substr(zip,1,3) as zip3
        from infolder.&&&id1._zipfile.; /* only need to pull from run 1 zip file since the same zipfile is used across runs */
      quit;

      /* recode the following 3 digit zips:
      1) 063 = CT
      2) 205 = DC
      3) 739 = OK
      4) 834 = ID
      5) 969 = GU
      
      These 3 digit zip codes correspond to multiple states as of 1/1/2017. If new discordant states
      arise, a warning will be written to the log. The decision was made to assign to 1 state */

      data _tempzip;
        set _tempzip;
        if zip3 = '063' then statecode = 'CT';
        if zip3 = '205' then statecode = 'DC';
        if zip3 = '739' then statecode = 'OK';
        if zip3 = '834' then statecode = 'ID';
        if zip3 = '969' then statecode = 'GU';
      run;  

      proc sql noprint;
        create table ziplookup as
        select distinct zip3, statecode
        from _tempzip;
      quit;

      %put WARNING: Due to 3 zip codes mapping to multiple states, the following 3 digit zip codes have been recoded:
              1) 063 = CT, 2) 205 = DC, 3) 739 = OK, 4) 834 = ID, 5) 969 = GU;

      /*Check to ensure no additional states need to be reclassified*/
      proc sql noprint;
        create table _recodedstates as
        select zip3, count(zip3) as zip_count
        from _tempzip
        group by zip3
        having zip_count > 1 and zip3 not in ('063', '205', '739', '834', '969');
      quit;

      %ISDATA(dataset=_recodedstates); 
      %if %eval(&nobs. > 1) %then %do;
        %put WARNING: Additional 3 digit zip codes map to multiple states. Further investigation recommended.
              See output dataset for these zip and state codes;
        data output.discrepant_states;
          set _recodedstates;
        run;
      %end;

      proc sql noprint undo_policy=none;
        create table &data. as 
        select x.* , y.statecode 
        from &data. as x
        left join ziplookup as y
        on x.zip3 = y.zip3;
      quit;

      data &data. (drop = statecode);
         set &data.;
         if zip3 not in ("Missing", "Invalid") and missing(zip3) = 0 then 
         zip3 = strip(zip3)||"/"||strip(statecode);;
      run;
    %put =====> END MACRO: addstatetozip3;

%mend addstatetozip3;

  
  
