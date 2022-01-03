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
*
*  Program outputs:                                                                                                                           
*   - final_t4moi - levelid and moiname stratification across data partners
*   - final_dps_t4moi - levelid and moiname stratification by data partner
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

%macro t4tables_createdata();

    %put =====> MACRO CALLED: t4tables_createdata ;
	
    /************************************************************************************************
      Determine levels   	  
     ************************************************************************************************/	
	  %let t4preglevel1 =;
	  %let t4preglevel2 =;
	  %let t4nopreglevel1 =;
	  %let t4nopreglevel2 =;
	  %do ds = 1 %to  %sysfunc(countw(&datasetlist,' '));
	    %let t4dset = %sysfunc(scan(&datasetlist,&ds.,' '));
	    proc sql noprint;
           select distinct quote(levelid1), quote(levelid2) 
           into :&t4dset.level1,
                :&t4dset.level2
           from tablefile where dataset = "&t4dset.";
	    quit;
	  %end;
	  
	/************************************************************************************************
      Determine total count of variables on table and put tablecolumns information into macro variables             
    ************************************************************************************************/
	proc sql noprint;
	  select count(column) into: numcolumns trimmed
	  from tablecolumns;
		
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
	  from tablecolumns;
	  
	  select distinct(a.numerator)
	         into: sumcolumns separated by " "
	        from (select case when index(column,'/') > 0 then scan(compress(column,'()'),1,'/')
                   else column end as numerator from tablecolumns) a;
    quit;
	
    /************************************************************************************************
     Determine denominators for percent calculations          
    ************************************************************************************************/
    %macro t4_preg_nopreg (dsin = );	
	   proc sql noprint undo_policy=none;
	      create table _&dsin as 
              select b.*
	          ,a.episodes as den_episodes
	          ,a.episodes_3trim as den_episodes_3trim
              from agg_t4&dsin (keep = episodes episodes_3trim level group dpidsiteid; 
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
	         _preg (in = t4preg keep= dpidsiteid group moiname &sumcolumns episodes episodes_3trim den_:)
		   %end;
		   %if %index(&datasetlist.,t4nopreg) > 0 %then %do;
		     _nopreg (in = t4nopreg keep= dpidsiteid group moiname &sumcolumns episodes episodes_3trim den_:)
		   %end;;
	   if t4preg then pregflg = "Y";
	   else pregflg = "N";
	 run;
	
   /************************************************************************************************
     Summarize Data     
    ************************************************************************************************/	
	proc summary data = _agg_t4moi nway missing;
	  class group moiname pregflg;
	  var &sumcolumns. episodes episodes_3trim den_episodes den_episodes_3trim;
	  output out = _agg_t4moi_summ (drop = _:) sum=;
	run;
	
    %macro prep_t4tables (dsin =, dsout =, dpvar = );	
   /************************************************************************************************
     Identify columns requested and apply labels and formats          
    ************************************************************************************************/ 
	   data &dsin. (keep = &dpvar. group moiname pregflg den_episodes column:);
	     set &dsin.;
		 %do vv = 1 %to &numcolumns;
		    label &&var&vv.. = "&&label&vv..";
			label &&var&vv.._char = "&&label&vv..";
			format &&var&vv.._char &&formatchar&vv..;
			
			%if %index(&&formula&vv.,/) > 0 %then %do;
			   if &&num&vv. = 0 or &&denominator&vv. = 0 then do;
			     &&var&vv. = 0;
				 &&var&vv.._char = strip(put(0, &&format&vv..));
			   end;
			   else if &&num&vv. = . or &&denominator&vv. = . then do;
			     &&var&vv. = 0;
				 &&var&vv.._char = "NaN";
			   end;
			   else do;
			     &&var&vv. = &&num&vv./&&denominator&vv.;
				 &&var&vv.._char = strip(put(&&var&vv., &&format&vv..));
			   end;
			%end;
			%else %do;
			   if &&num&vv. = . then do;
			     &&var&vv.._char = "NaN";
			   end;
			   else do;
			     &&var&vv. = &&formula&vv.;
			     &&var&vv.._char = strip(put(&&var&vv., &&format&vv..));
			   end;
			%end;
	     %end;
	   run;
	   
	   /* Apply labels */
       proc sql noprint;
         create table &dsout. as
		 select all.*
         from(select a.*, b.order
		 %if &labelfileexists. = Y %then %do;
		 	,case %if &includeheaderrow = Y %then %do; when c.label = "" and d.label = "" then strip(a.group) %end;
		 	      when c.label = "" then catx(' ',strip(a.group),"(N = ",strip(put(a.den_episodes,comma12.0))||")")
		 	 else catx(' ',strip(c.label),"(N = ",strip(put(a.den_episodes,comma12.0))||")") end as grouplabel 
		 	,case when d.label = "" then catx(' ',coalescec(c.label, a.group),"(N = ",strip(put(a.den_episodes,comma12.0))||")")
             else d.label end as header
            ,case when e.label = "" then a.moiname
             else e.label end as moilabel 
		       	,case when f.label = "" then a.moiname
             else f.label end as moiheader 
		 %end;
         %else %do;
		    ,catx(' ',strip(a.group),"(N = ",strip(put(a.den_episodes,comma12.0))||")") as grouplabel 
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
    %prep_t4tables (dsin=_agg_t4moi_summ, dsout=final_t4moi);
	
	%if &stratifybydp. = Y %then %do;
	  %prep_t4tables(dsin=_agg_t4moi, dsout=final_dps_t4moi, dpvar=dpidsiteid);
	%end;
	
	  /*Clean up*/
    proc datasets nowarn noprint lib=work;
      delete _:;
    quit;

    %put =====> END MACRO: t4tables_createdata ;

%mend t4tables_createdata;
