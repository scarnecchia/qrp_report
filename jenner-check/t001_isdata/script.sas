/* Exercises %isdata from utility_macros.sas: it reports the observation count   */
/* of a dataset so the driver can decide whether to produce a table. Here we     */
/* build a small masked cohort (the shape QRP partner output takes) and an empty */
/* dataset, then record what %isdata reports for each.                           */
data cohort;
  length dpid $8 group $12;
  input dpid $ group $ npts;
datalines;
DP01 exposed   42
DP01 reference 38
DP02 exposed   17
DP02 reference 21
;
run;

data emptyds;
  length dpid $8;
  stop;
run;

%isdata(dataset=cohort);
%let n_cohort = &nobs.;

%isdata(dataset=emptyds);
%let n_empty = &nobs.;

data _summary;
  length check $20 result 8;
  check = "cohort_nobs"; result = &n_cohort; output;
  check = "empty_nobs";  result = &n_empty;  output;
run;

proc print data=_summary noobs; run;
