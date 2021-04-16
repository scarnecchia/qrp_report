****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: codedistribution_output.sas  
* Created (mm/dd/yyyy): 04/16/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates both the Full Code Distribution and Total Code Counts output
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

%macro codedistribution_output;
	 
	/* This macros produces output for a specific distribution type (EXP or HOI) */
	%macro codedistribution_type(distindextype=);
		/* Compute group label to display in title */
		%let grouplabel=;
		%isdata(dataset=labelfile);
    	%if %eval(&nobs>0) %then %do;
			proc sql noprint;
			select label into :grouplabel trimmed from labelfile
			where lower(group)="&group." and runid = "&runid" and
			%if &distindextype. eq exp %then %do;
				lower(labeltype)="grouplabel";
			%end;
			%else %do;
				lower(labeltype)="outcomelabel";
			%end;
			quit;
		%end;

		%if %str("&grouplabel.") eq %str("") %then %let grouplabel = %trim(&group.);

		/*  Full Code Distribution */
		%tableletter();

		proc sql;
		create table repdata.table&tablenum.&tableletter as 
		select  group
				,distindexlist
				,code Label="Code"
				,description Label="Code Description"
				,codecat Label="Code Category"
				,codetype Label="Code Type"
				,caresetting Label="Encounter Care Setting"
				,totalN as totalN Label="Overall Counts"
		from codedistdata (where=(lower(group) = "&group." and runid = "&runid" and lower(distindextype) = "&distindextype."))
		order distindexlist, code;
		quit;

		data repdata.table&tablenum.&tableletter;
		length caresetting codetype codecat$20 description $700 code $100;
		set repdata.table&tablenum.&tableletter (rename = 
						                (code = _code 
						                 caresetting = _caresetting 
						                 TotalN = _TotalN
						                 description = _description
						                 codetype = _codetype
						                 codecat = _codecat));
		by distindexlist;
		if first.distindexlist then do;
			caresetting = '';
			TotalN = 0;
			code = '';
			description = '';
			codecat = '';
			codetype = '';
		end;

		TotalN + _TotalN;
		caresetting = cat(strip(_caresetting), '^n', caresetting);
		code = cat(strip(_code), '^n', code);
		description = cat(strip(_description), '^n', description);
		codecat = cat(strip(_codecat), '^n', codecat);
		codetype = cat(strip(_codetype), '^n', codetype);
		retain caresetting code description codecat codetype;

		if last.distindexlist then do;
			caresetting = substr(caresetting,1,length(strip(caresetting)) - 2);
			description = substr(description,1,length(strip(description)) - 2);
			codetype = substr(codetype,1,length(strip(codetype)) - 2);
			codecat = substr(codecat,1,length(strip(codecat)) - 2);
			code = substr(code,1,length(strip(code)) - 2);
			row_separator + 1;
			output; 
		end;
		run;

		proc sort data=repdata.table&tablenum.&tableletter(drop = _:);
		by descending totalN;
		run; 


		%let title = %quote(Table &tablenum.&tableletter.. Full Code Distribution of &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.);

		ods escapechar="^";
        %if &destination = excel %then %do;
        ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="teal");
        %end;
        ods proclabel = "Table &tablenum.&tableletter.";

		proc report data=repdata.table&tablenum.&tableletter nofs nowd spanrows missing
                style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
                style(report)=[rules=none frame=box cellpadding=1.5pt];

		column distindexlist code description codecat codetype totalN caresetting;
        define distindexlist / noprint;
        define code / display 'Code'  
        	style(column)=[width=.7in just=L tagattr="type:String" width=20%] 
          	style(header)=[just=L background=white borderbottomcolor=black];
        define description / display 'Code Description'  
          	style(column)=[width=1.7in just=c tagattr="type:String" width=30%] 
          	style(header)=[just=C background=white borderbottomcolor=black];
        define codecat / display 'Code Category'  
          	style(column)=[width=.7in just=c tagattr="type:String"] 
          	style(header)=[just=C background=white borderbottomcolor=black];
        define codetype / display 'Code Type' 
          	style(column)=[width=.7in just=c tagattr="type:String"] 
          	style(header)=[just=C background=white borderbottomcolor=black];
        define totalN / display 'Overall Counts' format=comma10.0
          	style(column)=[width=.7in just=c] 
          	style(header)=[just=C background=white borderbottomcolor=black];
        define caresetting / display 'Encounter Care Setting'  
          	style(column)=[width=.7in just=c] 
          	style(header)=[just=C background=white borderbottomcolor=black];

		/* Add title */
        compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                       tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
        line "&title.";
        endcomp;

      	run;
	    

		/* Total Code Counts */
		%tableletter();

		proc sort data=codedistdata (where=(lower(group) = "&group." and runid = "&runid" and lower(distindextype) = "&distindextype."))
			 out=codedistcounts (keep = runid distindexlist code description codetype codecat codetype totalN);
		by distindexlist descending totalN code;
		run;

		data codedistcounts; 
		set codedistcounts;
		by distindexlist descending totalN code;
		if first.distindexlist then do;
			codeCount = TotalN;
		end;
		retain codeCount;
		else do;
			codeCount = codeCount;
		end;
		run;

		proc sql noprint undo_policy = none;
		create table repdata.table&tablenum.&tableletter as 
		select  distinct code 
				,description 
				,codecat 
				,codetype Label="Code Type"
				,sum(codeCount) as N
		from codedistcounts
		group by code, description, codecat, codetype
		order by N desc;
		quit;
		

		%let title = %quote(Table &tablenum.&tableletter.. Total Code Counts of &grouplabel. in the &database. from &startdateformatted. to &enddateformatted.);

		ods escapechar="^";
        %if &destination = excel %then %do;
        ods excel options(sheet_name="Table &tablenum.&tableletter." tab_color="teal");
        %end;
        ods proclabel = "Table &tablenum.&tableletter.";

		proc report data=repdata.table&tablenum.&tableletter nofs nowd spanrows missing
                style(header)=[rules=none vjust=b bordertopcolor=black borderbottomcolor=black] split='*'
                style(report)=[rules=none frame=box cellpadding=1.5pt];

		column code description codecat codetype N  ;
	    define code / display 'Code' group  order order= data 
	      	style(column)=[width=.7in just=L tagattr="type:String" width=20%] 
	      	style(header)=[just=L background=white borderbottomcolor=black];
	    define description / display 'Code Description'  group  order order= data 
	      	style(column)=[width=1.7in just=c tagattr="type:String" width=30%] 
	      	style(header)=[just=C background=white borderbottomcolor=black];
	    define codecat / display 'Code Category'  group  order order= data 
	      	style(column)=[width=.7in just=c tagattr="type:String"] 
	      	style(header)=[just=C background=white borderbottomcolor=black];
	    define codetype / display 'Code Type' group  order order= data 
	      	style(column)=[width=.7in just=c tagattr="type:String"] 
	      	style(header)=[just=C background=white borderbottomcolor=black];
	    define N / display 'Overall Counts' group order order= data format=comma10.0
	      	style(column)=[width=.7in just=c] 
	      	style(header)=[just=C background=white borderbottomcolor=black];

		/* Add title */
        compute before _page_ / style=[background=white font_weight=bold just=L foreground=black vjust=b bordertopcolor=black borderbottomcolor=black
                                       tagattr="wrap:yes" nobreakspace=off cellheight=.3in];
        line "&title.";
        endcomp;

      	run;

	%mend codedistribution_type;
 

    %let tablecount=1;
    
	proc sql noprint;
	select count(*) into :numgroupscodedist trimmed 
	from GroupsDist;
	quit;
	
    %do loopcount = 1 %to &numgroupscodedist.; 

		%let codedistexp = N;
		%let codedisthoi = N;

        data _null_;
            set GroupsDist;
			if &loopcount. = _N_;
            call symputx('runid', runid);
            call symputx('group', group);			
            if index(upcase(codedist), "EXP") > 0 then call symputx('codedistexp', 'Y');
			if index(upcase(codedist), "HOI") > 0 then call symputx('codedisthoi', 'Y');
        run;
				
		%if &codedistexp. eq Y %then %codedistribution_type(distindextype=exp);
		%if &codedisthoi. eq Y %then %codedistribution_type(distindextype=hoi);
		
	%end; *numgroupscodedist;
		
%mend codedistribution_output;
