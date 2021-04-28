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
                    if lowcase(strip(profilecovarstoinclude)) = 'all' then profilecovarstoinclude = 'covar:';
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

    /* Stack all aggregated datasets together */
    data final_agg_profile;
        set agg_group_profile:;
    run;

    /* Rejoin order and covarsort back onto final dataset */
    proc sql noprint undo_policy=none;
        create table final_agg_profile as 
        select a.*, b.order, b.covarsort 
        from final_agg_profile a 
        left join baselinefile b 
        on a.group = b.group and scan(a.profiletablename,1,'_') = b.runid 
        order by b.order;
    quit;

%mend baseline_profile_createdata;