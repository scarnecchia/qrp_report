****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: t4tables_createdata.sas  
* Created (mm/dd/yyyy): 08/06/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro produces tables for a Type 4 report
*                                        
*  Program inputs:                                                                                   
*   - agg_t4preg.sas7bdat   
*   - agg_t4nopreg.sas7bdat 
*   - agg_t4preggestwk.sas7bdat   
*   - agg_t4nopreggestwk.sas7bdat 
*
*  Program outputs:                                                                                                                           
*   - final_t4moi - levelid and moiname stratification across data partners
*   - final_dps_t4moi - levelid and moiname stratification by data partner
*   - final_t4gestwk - moiname and gestwk stratification across data partners
*   - final_dps_t4gestwk - moiname and gestwk stratification by data partner
* 
*  PARAMETERS: 
* 
*  Programming Notes:                                                                                 

*
*--------------------------------------------------------------------------------------------------
* CONTACT INFO: 
*  Sentinel Coordinating Center
*  info@sentinelsystem.org
*
***************************************************************************************************;

%macro t4tables_createdata(dataset = , output_suffix = , episode_var = );

    %put =====> MACRO CALLED: t4tables_createdata ;

   /*********************************************************************************************************
      Determine total count of variables on table and put tablecolumns information into macro variables
        - For tables T1-T4, there is a 1:1 relationship between rows in TABLECOLUMNS and columns in the table 
        - For tables T5-T6, TABLECOLUMNS only contains 3 possible columns, this table will be expanded for 
          each gestational week after table information is assigned to macro variables
    ********************************************************************************************************/
	proc sql noprint;
	  select distinct(compress(table)) into: tables separated by '" "'
      from tablefile where dataset in ("t4&dataset." "t4no&dataset.");
	  
	  select count(column) into: numcolumns trimmed
	  from tablecolumns where table in ("&tables.");
	  
	  select columnname 
	        ,column 
			,columnlabel
			,columnformat
			,scan(compress(column,'()'),1,'/') as numerator
			,cats("den_",scan(compress(scan(column,1,'*'),'()'),2,'/')) as denominator
			,case when index(columnformat,'$') > 0 then columnformat
			   else compress('$'||put(input(scan(compress(columnformat,'','a'),1,'.'),3.) +  input(scan(compress(columnformat,'','a'),2,'.'),3.),8.)||".") end as columnformatchar
	   into: var1 -:var&numcolumns.
		    ,:formula1 - :formula&numcolumns.
			,:label1 - :label&numcolumns.
			,:format1 - :format&numcolumns.
			,:num1 - :num&numcolumns.
			,:denominator1 - :denominator&numcolumns.
			,:formatchar1 - :formatchar&numcolumns.
	  from tablecolumns where table in ("&tables.");
	  
	  select distinct(a.numerator)
	         into: sumcolumns separated by " "
	        from (select case when index(column,'/') > 0 then scan(compress(column,'()'),1,'/')
                   else column end as numerator from tablecolumns where table in ("&tables.")) a;
    quit;

    /*Expand table to 1 row per gestional week*/
    %if &dataset. = preggestwk %then %do;



    %end;

	
   /************************************************************************************************
     Identify substrat tables requested     
    ************************************************************************************************/
	 proc sql noprint;
	    select count(distinct tablesubstrat) into: numdset trimmed
		from tablefile where dataset in ("t4&dataset." "t4no&dataset.");
		
		select distinct tablesubstrat 
		   into: substrat1 - :substrat&numdset.
	    from tablefile where dataset in ("t4&dataset." "t4no&dataset.");
	 quit;
	 
	
	/************************************************************************************************
      Code specific for t4pregnancy and t4nopregnancy
	  - Identify levels 1 and 2 for preg and nopreg
	  - Calculate denominator episodes and denominator episodes in trimester 3
	  - Summarize data by group moiname and pregnancy flag for the identified level ids
     ************************************************************************************************/	
	 %if &dataset. = preg %then %do;
	
      /************************************************************************************************
        Determine levels
       ************************************************************************************************/	 
	    %let t4preglevel1 =;
	    %let t4preglevel2 =;
	    %let t4nopreglevel1 =;
	    %let t4nopreglevel2 =;
	    
	    %do ds = 1 %to &numdset.;
	      proc sql noprint;
             select distinct quote(levelid1), quote(levelid2) 
             into :&&&substrat&ds..level1,
                  :&&&substrat&ds..level2
             from tablefile where dataset = "&&substrat&ds.";
	      quit;
	    %end;
	  
     /************************************************************************************************
       Determine denominators for percent calculations          
      ************************************************************************************************/
        %macro t4_preg_nopreg (dsin = );	
	       proc sql noprint undo_policy=none;
	          create table _&dsin as 
                  select b.*
	              ,a.&episode_var. as den_&episode_var.
	              ,a.&episode_var._3trim as den_&episode_var._3trim
                  from agg_t4&dsin (keep = &episode_var. &episode_var._3trim level group dpidsiteid 
	    		                    where=(level in (&&t4&dsin.level1))) as a,
                       agg_t4&dsin (where=(level in (&&t4&dsin.level2))) as b
                  where a.group=b.group 
	              and a.dpidsiteid = b.dpidsiteid;
           quit;
        %mend t4_preg_nopreg;
	    %if %index(&datasetlist.,t4preg) > 0 %then %do;
	      %t4_preg_nopreg(dsin = preg);
	    %end;
	    %if %index(&datasetlist.,t4nopreg) > 0 %then %do;
	       %t4_preg_nopreg(dsin = nopreg);
	    %end;
	  
     /************************************************************************************************
       Set preg and nopreg data together when requested for desired levels            
      ************************************************************************************************/
	     data _agg_t4moi;
	       length moiname $5;
	       set %if %index(&datasetlist.,t4preg) > 0 %then %do;
	             _preg (in = t4preg keep= dpidsiteid group moiname &sumcolumns &episode_var. &episode_var._3trim den_:)
	    	   %end;
	    	   %if %index(&datasetlist.,t4nopreg) > 0 %then %do;
	    	     _nopreg (in = t4nopreg keep= dpidsiteid group moiname &sumcolumns &episode_var. &episode_var._3trim den_:)
	    	   %end;;
	       if t4preg then pregflg = "Y";
	       else pregflg = "N";
	     run;
	  
     /************************************************************************************************
       List of groups with a defined pre-pregnancy period          
      ************************************************************************************************/
	    %let prepreggrouplist = ;
        %if %index(&sumcolumns., pre)>0 %then %do;
            proc sql noprint;
                select distinct "'"||group||"'" into: prepreggrouplist separated by ','
                from master_typefile
                where prepregdays >0;
            quit;
            %if %str("&prepreggrouplist") = %str("") %then %let prepreggrouplist = '';
        %end;
	  
     /************************************************************************************************
       Summarize Data     
      ************************************************************************************************/	
	    proc summary data = _agg_t4moi nway missing;
	      class group moiname pregflg;
	      var &sumcolumns. &episode_var. &episode_var._3trim den_&episode_var. den_&episode_var._3trim;
	      output out = _agg_t4moi_summ (drop = _:) sum=;
	    run;
	  %end; /* T4preg and T4nopreg specific code */
	  
	/************************************************************************************************
      Summarize preg and nopreg data by group moiname pregflg and gestational week
	   - Gestational week data is in a different format than pregnancy data and requires separate processing
     ************************************************************************************************/	
	  %else %do;
	    %let prepreggrouplist = ;/* Pre pregnancy periods not evaluated for gestwk */
		
		/* Identify min and max gestwk requested */
		proc sql noprint;
		  select min(gestwk_min),
		         max(gestwk_max)
  		    into: min_min
			    ,:max_max
             from master_typefile;
	    quit;
		
	    data _agg_t4moi (keep = group moiname pregflg gestwk_char dpidsiteid den_&episode_var. &sumcolumns. pregflg gestwk_char);
	      length pregflg $1 gestwk_char $15;
	      set %if %sysfunc(findw(&datasetlist.,t4preggestwk)) %then %do;
	  	      agg_t4preggestwk (in = preg)
	  		%end;
	  		%if %sysfunc(findw(&datasetlist.,t4nopreggestwk)) %then %do;
	  	      agg_t4nopreggestwk (in = nopreg)
	  		%end;;
	  	if gestwk < 0 then gestwk_char = left(cats("gestwkneg",put(abs(gestwk),3.)));
          else gestwk_char = left(cats("gestwk",put(gestwk,3.)));
	  	if preg then pregflg = "Y";
	      else pregflg = "N";
	  	den_&episode_var. = &episode_var.;
		if not (&min_min. <= gestwk <= &max_max.) then delete; /* remove gestational weeks not requested in the type4 file */
	    run;	
	  	
	    proc summary data = _agg_t4moi nway missing;
          class group moiname pregflg gestwk_char;
          var &sumcolumns. den_&episode_var.;
          output out = _agg_t4moi_summ (drop = _:) sum=;
        run;
	  %end;
	
   /************************************************************************************************
     Identify columns requested and apply labels and formats          
    ************************************************************************************************/ 
    %macro prep_t4tables (dsin =, dsout =, dpvar = );	
	   data &dsin. (keep = &dpvar. group moiname column: pregflg den_&episode_var. %if &dataset. = preggestwk %then %do; gestwk_char  %end;);
	     set &dsin.;
		 %do vv = 1 %to &numcolumns;
		    label &&var&vv.. = "&&label&vv..";
			label &&var&vv.._char = "&&label&vv..";
			format &&var&vv.._char &&formatchar&vv..;
			
			%if %index(&&formula&vv.,/) > 0 %then %do;
               if &&num&vv. = . then &&num&vv. = 0;
			   if &&denominator&vv. <=0 then do;
			     &&var&vv. = .;
			   end;
			   else do;
			     &&var&vv. = &&num&vv./&&denominator&vv.;
			   end;
               &&var&vv.._char = strip(put(&&var&vv., &&format&vv..));
			%end;
			%else %do;
              if &&formula&vv. = . then &&formula&vv. = 0;
		      &&var&vv. = &&formula&vv.;
		      &&var&vv.._char = strip(put(&&var&vv., &&format&vv..));
			%end;
            
            /*standard missing value indicators*/
            /*if 0 patients in cohort, set to '.'*/
            if den_&episode_var. <=0 then do;
                &&var&vv. = .;
                &&var&vv.._char = '.';
            end;
            else do;
                /*if pre-pregnancy period not evaluated, set to 'N/A'*/
                %if %index(&&formula&vv.,pre)>0 and %str("&prepreggrouplist") ne %str("") %then %do;
                    if group not in (&prepreggrouplist) then do;
                        &&var&vv.._char = 'N/A';
                        &&var&vv. = .;
                    end;
                %end;
                /*if 0 episodes in 3rd trimester, % cannot be computed*/
                %if &&denominator&vv. = den_&episode_var._3trim %then %do;
                     if den_&episode_var._3trim <=0 then &&var&vv.._char = 'NaN';
                %end;
            end;
	     %end;
	   run;
	   
     /* Transpose Data for gestwk */
       %if &dataset. = preggestwk %then %do;
	   
	      proc sort data = &dsin.;
		    by &dpvar. group moiname pregflg;
		  run;
		  
		 %do va = 1 %to &numcolumns; 

            proc transpose data = &dsin suffix = &&var&va.. out = &dsin._tran_&va.  (drop =_name_ _label_);
               by &dpvar. group moiname pregflg;
               id gestwk_char;
               var &&var&va.. &&var&va.._char;
            run;
		 %end;
		 
		 data &dsin.;
		   merge &dsin._tran_:;
		   by &dpvar. group moiname pregflg;
		 run;

		 /*missing values for the gestwk out of range defined for the group*/
		 proc sql noprint undo_policy=none;
           select distinct group into: group_l
             separated by ' '
             from &dsin.;

          create table &dsin as 
            select a.*, b.gestwk_min, b.gestwk_max
            from &dsin. as a left join master_typefile as b
            on a.group = b.group;
        quit;

        %do group_1 = 1 %to %sysfunc(countw(&group_l));
          proc sql noprint;  
            select gestwk_min into: min&group_l
	          from &dsin.;
	        select gestwk_max into: max&group_l
	          from &dsin.;
       %end;

       data &dsin.;
         set &dsin.;
         %do group_1 = 1 %to %sysfunc(countw(&group_l));
           %if  "&&min&group_l" < "&min_min" %then %do;
             %do min_loop = %sysfunc(abs(&min_min)) %to %sysfunc(abs(&&min&group_l));
			   %do vv = 1 %to &numcolumns;
	             gestwkneg&min_loop.&&var&vv. = 'N/A';
		       %end;
             %end;
           %end; 
           %if "&&max&group_l" < "&max_max" %then %do;
             %do max_loop = &&max&group_l %to &max_max;
			   %do vv = 1 %to &numcolumns;
	             gestwk&max_loop.&&var&vv. = 'N/A';
		       %end;;
             %end;
           %end; 
         %end;
       run;

     %end;
	   
	   /* Apply labels */
       proc sql noprint;
         create table &dsout. as
		 select all.*
         from(select a.*, b.order
		 %if &labelfileexists. = Y %then %do;
		 	,case %if &includeheaderrow = Y %then %do; when c.label = "" and d.label = "" then strip(a.group) %end;
			%if &dataset. = preg %then %do;
		 	        when c.label = "" then catx(' ',strip(a.group),"(N = ",strip(put(a.den_&episode_var.,comma12.0))||")")
		 	   else catx(' ',strip(c.label),"(N = ",strip(put(a.den_&episode_var.,comma12.0))||")") end as grouplabel 
		 	  ,case when d.label = "" then catx(' ',coalescec(c.label, a.group),"(N = ",strip(put(a.den_&episode_var.,comma12.0))||")")
			%end;
			%else %do;
			       when c.label = "" then strip(a.group)
		 	   else strip(c.label) end as grouplabel 
		 	  ,case when d.label = "" then coalescec(c.label, a.group)
			%end;
             else d.label end as header
            ,case when e.label = "" then a.moiname
             else e.label end as moilabel 
		       	,case when f.label = "" then a.moiname
             else f.label end as moiheader 
		 %end;
         %else %do;
		    %if &dataset. = preg %then %do;
		      ,catx(' ',strip(a.group),"(N = ",strip(put(a.den_&episode_var.,comma12.0))||")") as grouplabel 
			%end;
			%else %do;
			  ,strip(a.group) as grouplabel
			%end;
            ,a.moiname as moilabel
            ,"" as moiheader 
         %end;				   
             from &dsin. a 
		      left join groupsfile b
		      on strip(lowcase(a.group)) = strip(lowcase(b.group))
		      %if &labelfileexists. = Y %then %do;
		        left join labelfile (where = (labeltype = "grouplabel")) c
		        on strip(a.group) = strip(c.group)
		        left join labelfile (where = (labeltype = "header")) d
		        on strip(a.group) = strip(d.group)
		     	left join labelfile (where = (labeltype = "moilabel")) e
		     	on strip(a.group) = strip(e.group)
		     	 and lowcase(a.moiname) = strip(e.labelvar)
		     	left join labelfile (where = (labeltype = "moiheader")) f
		     	on strip(a.group) = strip(f.group)
		     	 and lowcase(a.moiname) = strip(f.labelvar)
		      %end;) all;
        quit;
		
		proc sort data = &dsout. sortseq=linguistic(numeric_collation=on);
		  by descending pregflg order moiname;
		run;
    %mend;

	/*Overall*/
    %prep_t4tables (dsin=_agg_t4moi_summ, dsout=final&output_suffix.);

	/*By Data Partner*/
    %if &stratifybydp. = Y %then %do;
	  %prep_t4tables(dsin=_agg_t4moi, dsout=final_dps&output_suffix., dpvar=dpidsiteid);
	%end;
	
	/*Clean up*/
    proc datasets nowarn noprint lib=work;
      delete _:;
    quit;

    %put =====> END MACRO: t4tables_createdata ;

%mend t4tables_createdata;
