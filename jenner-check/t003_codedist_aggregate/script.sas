/* The aggregation core of inputfiles/macros/codedistribution_createdata.sas:    */
/* episode counts arrive split across data partners (dpidsiteid) and are summed  */
/* up by group / runid / distindextype with PROC MEANS NWAY, then sorted for the */
/* report. The mock agg_distindex below has the column shape the macro reads;     */
/* the PROC MEANS / OUTPUT step is the upstream logic unchanged.                  */
data agg_distindex;
  length group $10 runid $8 distindextype $4 dpidsiteid $6;
  input group $ runid $ distindextype $ dpidsiteid $ episodes;
datalines;
exposed RUN1 exp DP01 120
exposed RUN1 exp DP02 95
exposed RUN1 hoi DP01 40
exposed RUN1 hoi DP02 33
reference RUN1 exp DP01 88
reference RUN1 exp DP02 71
reference RUN1 hoi DP01 25
reference RUN1 hoi DP02 19
;
run;

proc means data=agg_distindex nway missing noprint;
  var episodes;
  class group runid distindextype;
  output out=_agg_distindex sum=;
run;

/* Keep only the analysis columns for the report. */
data _agg_distindex;
  set _agg_distindex;
  drop _type_ _freq_;
run;

proc sort data=_agg_distindex; by group distindextype; run;

proc print data=_agg_distindex noobs; run;
