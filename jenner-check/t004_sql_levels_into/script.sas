/* The stratification-discovery step from                                       */
/* inputfiles/macros/t1t2t4conc_createdata.sas: PROC SQL reads the table-columns */
/* file and collects the distinct level IDs and sub-stratifications for a table  */
/* into macro variables with SELECT ... INTO : ... SEPARATED BY. The mock        */
/* `tablefile` matches the columns the macro queries; the SQL is the upstream    */
/* logic.                                                                         */
data tablefile;
  length dataset $10 levelid1 $8 tablesub $12;
  input dataset $ levelid1 $ tablesub $;
datalines;
t1_cida L1 overall
t1_cida L1 age
t1_cida L2 sex
t2_cida L1 overall
t2_cida L1 region
;
run;

proc sql noprint;
  select distinct strip(levelid1)
    into :t1_levelid separated by ' '
  from tablefile where dataset = "t1_cida";

  select distinct tablesub into :t1_strat separated by ' '
    from tablefile
    where tablesub ne 'overall' and dataset = "t1_cida";

  select count(distinct levelid1) into :n_levels trimmed
  from tablefile where dataset = "t1_cida";
quit;

data _r;
  length item $20 value $80;
  item = "t1_levelid"; value = "&t1_levelid"; output;
  item = "t1_strat";   value = "&t1_strat";   output;
  item = "n_levels";   value = "&n_levels";   output;
run;

proc print data=_r noobs; run;
