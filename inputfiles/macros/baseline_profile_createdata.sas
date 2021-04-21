****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: baseline_profile_createdata.sas  
* Created (mm/dd/yyyy): 04/16/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE:
*   Compute aggregate covariate profile table(s)                                 
*   
*  Program inputs:        
*	-                                                                           
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
*--------------------------------------------------------------------------------------------------
*  CHANGE LOG: 
*
*   Version   Date       Initials      Comment (reference external documentation when available)
*   -------   --------   --------   ----------------------------------------------------------------
*
***************************************************************************************************;

%macro baseline_profile_createdata;

    proc sql noprint undo_policy=none;
        create table agg_profile as 
        select a.*, b.profilecovarstoinclude
        from agg_profile a
        inner join 
        baselinefile(where=(not missing(profilecovarstoinclude))) b
        on a.group = b.group and a.runid = b.runid;

        select distinct profiletablename
        into :profiletablenames separated by ' '
        from agg_profile;
    quit;

    data output.agg_profile;
        set agg_profile;
    run;


    %do b = 1 %to %sysfunc(countw(&profiletablenames));
        %let profiletable = %scan(&profiletablenames,&b);
            data agg_&profiletable;
                set agg_profile(where=(profiletablename="&profiletable"));
            run;

            proc sql noprint;
                select distinct group 
                into :profilegroups separated by ' '
                from agg_&profiletable;
            quit;

            %do c = 1 %to %sysfunc(countw(&profilegroups));
                %let profilegroup = %scan(&profilegroups,&c);

                data agg_profilegroup&c;
                    set agg_&profiletable(where=(group="&profilegroup"));
                    call symputx('profilecovarsnocomma', compress(profilecovarstoinclude,','));
                run;

                proc means data=agg_profilegroup&c nway missing noprint;
                    var npts n_episodes;
                    class profiletablename group &profilecovarsnocomma;
                    output out=sum_agg_profile&c(drop=_:)   
                    sum(npts n_episodes)=sum_npts sum_nepisodes;
                run;

            %end;

            data agg_group_profile&b;
                set sum_agg_profile:;
            run;
    %end;


%mend baseline_profile_createdata;