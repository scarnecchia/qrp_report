/* The DP-pivot pattern from inputfiles/macros/baseline_aggregate.sas: baseline  */
/* metrics arrive one row per (metric, data partner); PROC TRANSPOSE reshapes     */
/* them so each data partner becomes its own column, the layout the baseline      */
/* report tables use. The mock `baseline_long` matches the metric/dp/value shape;  */
/* the SORT + TRANSPOSE is the upstream reshaping logic.                          */
data baseline_long;
  length metric $20 dp $6;
  input metric $ dp $ value;
datalines;
mean_age DP01 54.2
mean_age DP02 51.8
mean_age DP03 56.1
pct_female DP01 61.0
pct_female DP02 58.5
pct_female DP03 63.2
;
run;

proc sort data=baseline_long; by metric dp; run;

proc transpose data=baseline_long out=baseline_wide(drop=_name_) prefix=dp_;
  by metric;
  id dp;
  var value;
run;

proc print data=baseline_wide noobs; run;
