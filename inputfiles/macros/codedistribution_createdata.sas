****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: codedistribution_createdata.sas  
* Created (mm/dd/yyyy): 04/16/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates aggregated code distribution dataset and process code descriptions
*                                        
*  Program inputs:                                                                                   
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
***************************************************************************************************;

%macro codedistribution_createdata;

	proc sql noprint;
	select count(*) into :numgroupscodedist trimmed 
	from GroupsDist;
	quit;
	
    %do loopcount = 1 %to &numgroupscodedist.;             

        /* set parameters for this loop */
		%let codedistexp = N;
		%let codedisthoi = N;

        data _null_;
            set GroupsDist;
			if &loopcount. = _N_;
            call symputx('runid', runid);
            call symputx('group', group);
			call symputx('order', order);
            if index(upcase(codedist), "EXP") > 0 then call symputx('codedistexp', 'Y');
			if index(upcase(codedist), "HOI") > 0 then call symputx('codedisthoi', 'Y');
        run;

		/* Aggregate results and keep only relevant distindextype */
		proc means data=agg_distindex (where=(lowcase(group)="&group." and runid="&runid.")) noprint nway missing;
            var episodes;
            class group runid distindextype distindexlist dpidsiteid;
            output out=_agg_distindex(drop=_:) sum=;
        run;

		data _agg_distindex;
		set _agg_distindex;
		order=&order.;
		%if &codedistexp. ne Y %then %do; 
			if lowcase(distindextype)="exp" then delete;
		%end;
		%if &codedisthoi. ne Y %then %do; 
			if lowcase(distindextype)="hoi" then delete;
		%end;
		run;

		proc append data=_agg_distindex base=_distindex force; run;
			
	%end;  /*loop through code distribution groups*/


	data _distindex (drop = nwords count);
	set _distindex;      
	length ixid $10.;
	nwords = countw(distindexlist, '_', 'oq');
	do count = 1 to nwords;
		ixid = scan(distindexlist, count, '_', 'oq');
		if count > 1 then episodes = 0;
		output;
	end;      
	run;

    /* Create one table for the unique mapping values. If RX, use stockgroup as code */
    data _mappingfile (drop = stockgroup _code); 
	length code $30;
	set agg_distindexmap (rename = (code = _code));
	if not missing(stockgroup) then do;
		codecat = 'RX';
		enctype = 'NA';
		codetype = 'NA';
		code = put(stockgroup,30.);
	end;
	else code = _code;
    run;

	/* Join index data to mapping file */
	proc sql noprint;
	create table _map_distindex as 
	select  t.*
			,m.codecat
			,m.codetype
			,case when m.codecat = "RX" then "NA"
	      		  else compress(m.enctype||m.pdx) end as caresetting
			,m.code 
	from _distindex t   
	left join _mappingfile m 
		on t.runid = m.runid 
		and t.group = m.group
		and t.dpidsiteid = m.dpidsiteid
		and lower(t.distindextype) = lower(m.distindextype)
		and t.ixid = m.distindexid;
	quit;

	proc sql noprint; 
	create table _agg_distindex as 
	select  runid
			,group
			,order
			,distindextype  
			,distindexlist 
			,ixid 
			,code
			,codecat
			,codetype
			,caresetting
			,sum(episodes) as totalN
	from _map_distindex 
	group by runid
			,group
			,order
			,distindextype  
			,distindexlist 
			,ixid 
			,code
			,codecat
			,codetype
			,caresetting;
	quit;

 	/* Process CodeDescriptionsFile */
    %if %str("&CodeDescriptionsFile.") ne %str("") %then %do; 
		proc sql noprint; 
		create table _codedescription as
		select code
		      , compress(code,'.') as codef
		      , codecat
		      , codetype
		      , description
		from input.&CodeDescriptionsFile.;

		create table distIndexData as 
		select dist.*
		      , propcase(coalesce(cd.description, dist.code)) as description   
		from _agg_distindex dist
		left join _codedescription cd
			on dist.code=cd.codef and 
			dist.codetype=cd.codetype and 
			dist.codecat= cd.codecat;      
    	quit;
	%end;
	%else %do;
		proc sql noprint;
		create table distIndexData as
		select dist.*
			   , propcase(dist.code) as description
		from _agg_distindex dist;
		quit;

		/* Add decimals to code description */
		data distIndexData;
		set distIndexData;

		*if icd dx, then 3rd place;
		if codecat='DX' then do;
			if length(description) > 3 then var = cat( substr(description, 1, 3), '.', substr(description, 4) );
			else var = description;
		end;

		*if icd 9 px, then 2nd place;
		else if codecat='PX' and codetype = '09' then do;
			if length(description) > 2 then var = cat( substr(description, 1, 2), '.', substr(description, 3) );
			else var = description;
		end;     
		
		else var = propcase(description);

		drop description ;
		rename var=description;
		run;
	%end;

	/* Add decimals to code */
	data codedistdata;
    length var $50;
    set distindexdata;

    *if icd dx, then 3rd place;
    if codecat='DX' then do;
        if length(code) > 3 then var = cat( substr(code, 1, 3), '.', substr(code, 4) );
        else var = code;
    end;

    *if icd 9 px, then 2nd place;
    else if codecat='PX' and codetype = '09' then do;
       if length(code) > 2 then var = cat( substr(code, 1, 2), '.', substr(code, 3) );
       else var = code;
    end;     
    
    else var = propcase(code);

    drop code ;
    rename var=code;    
  	run;

	proc datasets nowarn noprint lib=work;
	delete _agg_distindex _distindex _map: _codedescription distindexdata;
	quit;

%mend codedistribution_createdata;
