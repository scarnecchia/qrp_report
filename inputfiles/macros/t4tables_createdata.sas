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
*   - 1 dataset per table in the format [TableID]_[Tablesubstrat]
* 
*  PARAMETERS: 
*   - dataset: aggregate dataset from %aggregate_report_tables
*   - whereclause: where clause to restrict input dataset
*   - catvar: variable that will be categorized
*   - countvar: metric counting counts
*   - cattableid: category table ID from TABLEFILE
*   - createfootnote: Y/N indicator to create group-specific footnote table (for dose tables)
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
     Set preg and nopreg data together when requested for desired levels            
     ************************************************************************************************/
	 data agg_t4moi;
	   set %if %index(&datasetlist.,t4preg) > 0 %then %do;
	         agg_t4preg (in = t4preg where = (level in (&t4preglevel1., &t4preglevel2.)))
		   %end;
		   %if %index(&datasetlist.,t4nopreg) > 0 %then %do;
		     agg_t4nopreg (in = t4nopreg where = (level in (&t4nopreglevel1., &t4nopreglevel2.)))
		   %end;;
	   if t4preg then pregflg = "Y";
	   else pregflg = "N";
	 run;
	
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
			,scan(compress(scan(column,1,'*'),'()'),2,'/') as denominator
	   into: var1 -:var&numcolumns.
		    ,:formula1 - :formula&numcolumns.
			,:label1 - :label&numcolumns.
			,:format1 - :format&numcolumns.
			,:num1 - :num&numcolumns.
			,:denominator1 - :denominator&numcolumns.
	  from tablecolumns;
	  
	  select column into: sumcolumns separated by " "
	  from tablecolumns where index(column,"/") = 0;
    quit;
	
   /************************************************************************************************
     Summarize Data     
    ************************************************************************************************/	
	proc summary data = agg_t4moi nway missing;
	  class group level moiname pregflg;
	  var &sumcolumns. npts episodes episodes_3trim;
	  output out = agg_t4moi_summ (drop = _:) sum=;
	run;
	 
	%macro prep_t4tables (dsin =, dsout =, dpvar = );	
	/************************************************************************************************
      Determine denominators for percent calculations           
    ************************************************************************************************/
	   proc sql noprint undo_policy=none;
	      create table &dsin. as 
              select b.*
	          ,a.episodes as den_episodes
	          ,a.episodes_3trim as den_episodes_3trim
              from &dsin (where=(level in (&t4preglevel1 &t4nopreglevel1.))) as a,
                   &dsin (where=(level in (&t4preglevel2 &t4nopreglevel2.)))as b
              where a.group=b.group 
			        and a.pregflg=b.pregflg 
	        %if %str("&dpvar.") ne %str("") %then %do;
	       and a.dpidsiteid = b.dpidsiteid
	     %end;;
       quit;
	
   /************************************************************************************************
     Identify columns requested and apply labels and formats          
    ************************************************************************************************/ 
	   data &dsin.;
	     set &dsin.;
		 %do vv = 1 %to &numcolumns;
		    format &&var&vv.. &&format&vv..;
		    label &&var&vv.. = "&&label&vv..";
			label &&var&vv.._char = "&&label&vv..";
			
			%if %index(&&formula&vv.,/) > 0 %then %do;
			   if &&num&vv. = 0 or &&denominator&vv. = 0 then do;
			     &&var&vv. = 0;
				 &&var&vv.._char = strip(put(0, percent10.1));
			   end;
			   else if &&num&vv. = . or &&denominator&vv. = . then do;
			     &&var&vv. = 0;
				 &&var&vv.._char = "NaN";
			   end;
			   else do;
			     &&var&vv. = &&formula&vv.;
				 &&var&vv.._char = strip(put(&&var&vv., percent10.1));
			   end;
			%end;
			%else %do;
			   if &&num&vv. = . then do;
			     &&var&vv.._char = "NaN";
			   end;
			   else do;
			     &&var&vv. = &&formula&vv.;
			     &&var&vv.._char = strip(put(&&var&vv., comma12.0));
			   end;
			%end;
	     %end;
	   run;
	   
	   /* Apply labels */
	   %isdata(dataset=labelfile);
	
       proc sql noprint;
         create table &dsout. as
         select a.*, b.order
		 %if %eval(&nobs.>0) %then %do;
		    /*,d.label as header */
			,case when c.label = "" then a.group
			 when lowcase(c.labelvar) = "npts" then left(c.label||" (N = "||put(a.npts,comma12.0)||" )") 
			 when lowcase(c.labelvar) = "episodes" then left(c.label||" (N = "||put(a.episodes,comma12.0)||" )") 
			 when lowcase(c.labelvar) = "episodes_3trim" then left(c.label||" (N = "||put(a.episodes_3trim,comma12.0)||" )") 
             else c.label end as grouplabel 
            ,case when e.label = "" then a.moiname
             else e.label end as moilabel 
			,case when f.label = "" then a.moiname
             else f.label end as moiheader 
		 %end;
         %else %do;
            ,"" as header 
			,a.group as grouplabel
            ,a.moiname as moilabel
            ,"" as moiheader 
          %end;				   
         from &dsin. a 
		  left join groupsfile b
		  on strip(lowcase(a.group)) = strip(lowcase(b.group))
		  %if %eval(&nobs.>0) %then %do;
		    left join labelfile (where = (labeltype = "grouplabel")) c
		    on strip(a.group) = strip(c.group)
		    left join labelfile (where = (labeltype = "header")) d
		    on strip(a.group) = strip(d.group)
			left join labelfile (where = (labeltype = "moilabel")) e
			on strip(a.group) = strip(e.group)
			   and (a.moiname) = strip(e.labelvar)
			left join labelfile (where = (labeltype = "moiheader")) f
			on strip(a.group) = strip(f.group)
			   and (a.moiname) = strip(e.labelvar)
		  %end;;
       quit;
		
		proc sort data = &dsout.;
		  by &dpvar. order moiname;
		run;
    %mend;
	/*Overall*/
    %prep_t4tables (dsin=agg_t4moi_summ, dsout=final_t4moi);
	
	%if &stratifybydp. = Y %then %do;
	  %prep_t4tables(dsin=agg_t4moi, dsout=final_dps_t4moi, dpvar=dpidsiteid);
	%end;

    %put =====> END MACRO: t4tables_createdata ;

%mend t4tables_createdata;
