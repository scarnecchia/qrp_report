/* Adapted from inputfiles/macros/create_lookup.sas. The macro authors the      */
/* report's footnote lookup table: one row per (type, order) with the verbatim  */
/* footnote text in an attrib-typed DATA step. The upstream version writes to    */
/* the read-only `lookup` library; here it writes to WORK so the bundle is       */
/* self-contained. The footnote rows are taken verbatim from the source file.    */
%macro create_lookup();
   data lookup_footnotes;
     attrib type         length = $10  format = $10.
            order        length = 3    format = 3.
            description  length = $575 format = $575.;

     type = "type4";     order = -2; description = "Pregnancy is defined as a pregnancy that resulted in a live or non-live birth identified using the method specified in the overview section of this report."; output;
     type = "baseline";  order = -4; description = "Covariate included in the propensity score logistic regression model."; output;
     type = "baseline";  order = 1;  description = "All metrics are based on total number of episodes per group, except for sex, race, and Hispanic origin which are based on total number of unique patients."; output;
     type = "baseline";  order = 15; description = "Race data may not be completely populated at all Data Partners; therefore, data about race may be incomplete."; output;
     type = "censor";    order = 1;  description = "An episode may be censored due to more than one reason if they occur on the same date. Therefore, the sum of the reasons for censoring may be greater than the total number of episodes."; output;
     type = "censor";    order = 10; description = "Represents episodes censored due to user-specified study end date."; output;
     type = "kmcdf";     order = 1;  description = "A single episode may contribute to multiple categories if a patient was censored due to multiple criteria on the same day."; output;
     type = "effectest"; order = 1;  description = "All values in this section are weighted."; output;
   run;
%mend create_lookup;
%create_lookup();

/* Show the lookup table and a count of footnotes per report section. */
proc print data=lookup_footnotes noobs; var type order description; run;

proc freq data=lookup_footnotes;
  tables type / nocum;
run;
