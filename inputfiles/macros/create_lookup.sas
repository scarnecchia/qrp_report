*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_lookup.sas  
* Created (mm/dd/yyyy): 03/23/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This is a standalone program executed prior to qrp_report when there are updates to the lookuptables.
*          The macro creates all files that reside in the lookuptables folder. These are lookuptables used for
*          processing, but cannot be modified by the user.
* 
*  Program inputs:                                                                                   
* 
*  Program outputs: The following lookuptables files are created:
*   -lookup_footnotes = Footnotes for baseline, effect estimates, KM/CDF, concomitant use, and censor tables
*   -lookup_attrition = Mapping QRP attrition descriptions to report descriptions
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

 /* Define libname for location of templatefiles folder */
  libname lookup "";
  options noquotelenmax;
  
  %macro create_lookup();
     data lookup.lookup_footnotes;
	   attrib type         length = $10  format = $10. 
	          order        length = 3    format = 3.
	          description  length = $575 format = $575.;

	   /* Footnotes for in Type 4 tables - applied to multiple tables*/
      type = "type4"; order = -2;  description = "Pregnancy is defined as a pregnancy that resulted in a live birth delivery identified using the method specified in the overview section of this report."; output;
      type = "type4"; order = -1;  description = "The non-pregnancy cohort includes patients without delivery codes during the pregnancy episode of the matched pregnant patient, who met all inclusion/exclusion criteria and were the same integer age on the last date of the matched pregnant patient's pregnancy episode."; output;

	   /* Footnotes for baseline table */
      type = "baseline";  order = 1;  description = "All metrics are based on total number of episodes per group, except for sex, race, and Hispanic origin which are based on total number of unique patients."; output;
	   type = "baseline";  order = 2;  description = "&covar_characteristic. in blue show a standardized difference greater than &sdthreshold.."; output;
	   type = "baseline";  order = 4;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after propensity score (PS) stratum weighting and should not be interpreted as a description of the unweighted population. Treated/control patients are weighted by the proportion of the total patient population included in their PS stratum divided by the proportion of the total treated/control patient population included in their PS stratum."; output;
	   type = "baseline";  order = 5;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after propensity score (PS) stratum weighting and should not be interpreted as a description of the unweighted population. Treated patients are assigned a weight of 1, and control patients are weighted by the proportion of the total treated patient population included in their PS stratum divided by the proportion of the total control patient population included in their PS stratum."; output;
	   type = "baseline";  order = 6;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after propensity score (PS) stratification and should not be interpreted as a description of the unweighted population. Treated/control patients are weighted by the proportion of the total patient population included in their PS stratum divided by the proportion of the total treated/control patient population included in their PS stratum."; output;
	   type = "baseline";  order = 7;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after inverse probability weighting and should not be interpreted as a description of the unweighted population. Treated patients are weighted by the inverse of their propensity score (PS), while reference patients are weighted by the inverse of 1 minus their PS."; output;
	   type = "baseline";  order = 8;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after inverse probability weighting and should not be interpreted as a description of the unweighted population. Treated patients are weighted by the proportion of treated patients in the trimmed population divided by the inverse of their propensity score (PS). Reference patients are weighted by 1 minus the proportion of treated patients in the trimmed population divided by 1 minus their PS."; output;
	   type = "baseline";  order = 9;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after inverse probability weighting and should not be interpreted as a description of the unweighted population. Treated patients are assigned a weight of 1. Reference patients are weighted by their propensity score (PS) divided by 1 minus their PS."; output;
	   type = "baseline";  order = 10; description = "With variable ratio matching, each exposed subject is matched to a variable number of comparator subjects. The weight for each treated subject equals 1. The weight for each control subject equals the inverse of the matching ratio for that specific matched set."; output;
	   type = "baseline";  order = 11; description = "Baseline period in reference to user-defined index date (start of first valid exposed pregnancy resulting in live birth delivery, exposure date, or delivery date)."; output;
	   type = "baseline";  order = 12; description = "Value represents the proportion of episodes with first switch."; output;
	   type = "baseline";  order = 13; description = "Value represents the proportion of first switch episodes with second switch."; output;
	   type = "baseline";  order = 14; description = "Value represents standard deviation where no % follows the value."; output;
      type = "baseline";  order = 15; description = "Race data may not be completely populated at all Data Partners; therefore, data about race may be incomplete."; output;
      type = "baseline";  order = 16; description = 'Includes members classified as having an unknown race by the Data Partner and patients in race categories where the total member count is between one and ten.'; output;
	   type = "baseline";  order = 17; description = "Gestational age estimated using a claims-based algorithm, previously validated in the Medication Exposure in Pregnancy Risk Evaluation Program (MEPREP), to identify pregnancies ending in a live birth. ICD-10-CM diagnosis codes indicative of weeks of gestation, and ICD-9-CM and ICD-10-CM diagnosis codes for pre-term and post-term deliveries, were used to calculate the length of the pregnancy episode. Codes had to occur within 7 days of a delivery date in the inpatient setting. In absence of pre-/post-term codes, pregnancy duration was set to 273 days."; output;
	   type = "baseline";  order = 18; description = "The Combined Comorbidity Score is calculated based on comorbidities observed during a requester-defined window around the exposure episode start date. (Gagne JJ, Glynn RJ, Avorn J, Levin R, Schneeweiss S. A Combined Comorbidity Score Predicted Mortality in Elderly Patients Better Than Existing Scores. J Clin Epidemiol. 2011;64(7):749-759; Sun JW, Rogers JR, Her Q, Welch EC, Panozzo CA, Toh S, Gagne JJ. Adaptation and Validation of the Combined Comorbidity Score for ICD-10-CM. Med Care. 2017;55(12):1046-1051)"; output;
	   type = "baseline";  order = 19; description = "Covariate not included in the propensity score logistic regression model."; output;
	   type = "baseline"; order = 20;  description = "Only the laboratory result closest to the index date in the user-defined evaluation window is described. The number of &patientepi with a given categorical result value, or the mean numerical result value among those reported in given unit, is shown indented and italicized below the Romanized number of unique &patientepi with or without a test record."; output;

	   /* Footnotes for L2 effect estimates table */	  
	   type = "effectest"; order = 1;  description = "All values in this section are weighted."; output;
	   type = "effectest"; order = 2;  description = "Race data may not be completely populated at all Data Partners; therefore, data about race may be incomplete."; output;
	   type = "effectest"; order = 3;  description = "Delivery status based on algorithm-derived pregnancy duration."; output;
	   type = "effectest"; order = 4;  description = "&weightscheme. = &weightschemelong.."; output;

       /* Footnotes for attrition table */
	   type = "attrition"; order = -3;  description = 'Cohorts are formed by first evaluating enrollment and demographic requirements as well as index events among members, then evaluating index dates, pre-index history, and post-index follow-up among %sysfunc(lowcase(&claim_level_descr.)). Because of this, the number remaining often increases from the member- to episode-level steps.'; output;
	   type = "attrition"; order = 1;  description = '&claim_level_descr. can meet multiple inclusion and/or exclusion criteria; therefore, the total number of %sysfunc(lowcase(&claim_level_descr.)) excluded overall may not equal the sum of all %sysfunc(lowcase(&claim_level_descr.)) in each criterion.'; output;
	   
	   /* Footnotes for KM/CDF figures */
	   type = "kmcdf";     order = 1;  description = 'A single episode may contribute to multiple categories if a patient was censored due to multiple criteria on the same day.'; output;
	 
	   /* Footnotes for type 1, type 2 and concomitant use tables */
	   type = "t1t2conc";  order = 1;  description = "Race data may not be completely populated at all Data Partners; therefore, data about race may be incomplete."; output;
	   type = "t1t2conc";  order = 2;  description = 'Eligible Members are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period.'; output;
	   type = "t1t2conc";  order = 3;  description = 'Eligible Member-Days are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period.'; output;
	   type = "t1t2conc";  order = 4;  description = 'Eligible Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period.'; output;
	   type = "t1t2conc";  order = 5;  description = 'Eligible Member-Days and Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period.'; output;
	   type = "t1t2conc";  order = 6;  description = 'Eligible Members and Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period.'; output;
	   type = "t1t2conc";  order = 7;  description = 'Eligible Members and Member-Days are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period.'; output;
	   type = "t1t2conc";  order = 8;  description = 'Eligible Members, Member-Days, and Member-Years are reflective of the number of patients that met all cohort entry criteria on at least one day during the query period.'; output;
	   type = "t1t2conc";  order = 9;  description = 'Includes members classified as having an unknown race by the Data Partner and patients in race categories where the total member count is between one and ten.'; output;

	   /* Footnotes for type 5 tables and figures (note - dose table footnotes query specific and are generated in t5tables_createdata */
       /* order = 1 reserved for dose footnotes*/
       type = "t5tablefig";  order = 2;  description = 'Includes members classified as having an unknown race by the Data Partner and patients in race categories where the total member count is between one and ten.'; output;

	   /* Footnotes for types 1, 2, 5, and 6 censor tables */
	   type = "censor";    order = 1;  description = "An episode may be censored due to more than one reason if they occur on the same date. Therefore, the sum of the reasons for censoring may be greater than the total number of episodes."; output;
	   type = "censor";    order = 2;  description = "A patient's episode may be censored due to more than one reason if they occur on the same date. Therefore, the sum of the reasons for censoring may be greater than the total number of patients."; output;
	   type = "censor";    order = 3;  description = "Time to end of observable data is for characterization purposes only. It does not necessarily represent at-risk time, and does not consider episode end, outcome occurrence, blackout period, or delay risk period start."; output;
	   type = "censor";    order = 4;  description = "Represents episodes censored due to end of the exposure episode. In as-treated analyses, exposure episodes are defined using days supplied as recorded in outpatient pharmacy dispensing records, and episodes end after days supplied are exhausted or a pre-determined maximum episode duration is met. In point exposure analyses, exposure episodes end when a pre-determined maximum episode duration is met."; output;
	   type = "censor";    order = 5;  description = "Represents episodes censored due to occurrence of request-defined event."; output;
	   type = "censor";    order = 6;  description = "Represents episodes censored due to occurrence of additional user-defined criteria using drug, procedure, diagnosis, and/or laboratory codes."; output;
	   type = "censor";    order = 7;  description = "Represents episodes censored due to evidence of death. Death data source and completeness varies by Data Partner."; output;
	   type = "censor";    order = 8;  description = 'Represents episodes censored due to disenrollment from health plan. Data Partners often artificially assign a ""disenrollment"" date equal to data end date for members still enrolled on that date. Therefore, a patient may have dual reasons for censoring as ""disenrollment"" and ""end of data"" on the same day - this can be interpreted as right-censoring in most cases.'; output;
	   type = "censor";    order = 9;  description = "Represents episodes censored due to Data Partner data end date. This end date represents the last day of the most recent year-month in which all of a Data Partner's data tables in the Sentinel Common Data Model have at least 80% of the record count relative to the prior month."; output;
	   type = "censor";    order = 10; description = "Represents episodes censored due to user-specified study end date."; output;
	   type = "censor";    order = 11; description = "Represents episodes censored due to occurrence of first switch."; output;
	   type = "censor";    order = 12; description = "Represents episodes censored due to occurrence of second switch."; output;

       /* Footnotes for type 4 MOI tables */
      type = "t4l1moi"; order = 1;  description = "Displayed percentages represent the number of pregnancy (or matched non-pregnant) episodes with evidence of the exposure of interest as a proportion of all pregnancy (or matched non-pregnant) episodes."; output;
	   type = "t4l1moi"; order = 2;  description = "Displayed percentages represent the number of pregnancy episodes with evidence of the exposure of interest as a proportion of all pregnancy episodes."; output;
	   type = "t4l1moi"; order = 3;  description = "Displayed percentages represent the number of pregnancy (or matched non-pregnant) episodes with evidence of the exposure of interest as a proportion of all pregnancy (or matched non-pregnant) episodes in the given gestational week"; output;
	   type = "t4l1moi"; order = 4;  description = "Displayed percentages represent the number of pregnancy episodes with evidence of the exposure of interest as a proportion of all pregnancy episodes in the given gestational week"; output;
	   type = "t4l1moi"; order = 5;  description = "Results are not output since enrollment was not required during this time period of given pregnancy episode examined."; output;

     run; 

     data lookup.lookup_attrition;
	   attrib claim_level   length = $10	format = $10.
              descr  		length = $500	format = $500.
			  report_descr	length = $500	format = $500.;
		claim_level = "Member";  descr = "Initial Member Count - Members with a non-missing birth date/sex at any enrollment episode overlapping the query period"; report_descr = "Enrolled at any point during the query period"; output;
		claim_level = "Member";  descr = "Exclusion - Members must be excluded if they only have enrollment episodes with DrugCov=N and MedCov=Y or A during the query period"; report_descr = "Had required coverage type (medical and/or drug coverage)"; output;
		claim_level = "Member";  descr = "Exclusion - Members must be excluded if they only have enrollment episodes with DrugCov=Y and MedCov=N during the query period"; report_descr = "Had required coverage type (medical and/or drug coverage)"; output;
		claim_level = "Member";  descr = "Exclusion - Members must be excluded if they only have enrollment episodes with DrugCov=Y and MedCov=N and DrugCov=N and MedCov=Y or A during the query period"; report_descr = "Had required coverage type (medical and/or drug coverage)"; output;
		claim_level = "Member";  descr = "Exclusion - Members must satisfy the age range condition within the query period"; report_descr = "Enrolled during specified age range"; output;
		claim_level = "Member";  descr = "Exclusion - Members must meet chart availability criterion within the query period"; report_descr = "Had requestable medical charts"; output;
		claim_level = "Member";  descr = "Exclusion - Members must satisfy the demographic (sex, race and hispanic) condition"; report_descr = "Met demographic requirements (sex, race, and Hispanic origin)"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one claim with cohort-identifying codes within the query period"; report_descr = "Had any cohort-defining claim during the query period"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one live birth delivery during the query period"; report_descr = "Had a live birth delivery claim during the query period"; output;
		claim_level = "Episode"; descr = "Initial Episode Count (among eligible members from previous step) - All claims with cohort-identifying codes"; report_descr = "Total number of claims with cohort-identifying codes during the query period"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode index date within the age range condition"; report_descr = "Claim recorded during specified age range"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episode must have an index date within the age range condition"; report_descr = "Claim recorded during specified age range"; output;
		claim_level = "Episode"; descr = "Exclusion - Live birth deliveries must have an index date within the age range condition"; report_descr = "Live birth delivery recorded during specified age range"; output;
		claim_level = "Member";  descr = "Exclusion - Members cannot have all their valid index dates in a prior look period"; report_descr = "Claim recorded during current look period"; output;
		claim_level = "Episode"; descr = "Exclusion - Valid index dates cannot be in a prior look period"; report_descr = "Claim recorded during current look period"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one episode defining index claim during the query period"; report_descr = "Episode defining index claim recorded during the query period"; output;
		claim_level = "Episode"; descr = "Exclusion - Episode-defining index claims must be during the query period"; report_descr = "Episode defining index claim recorded during the query period"; output;
		claim_level = "Episode"; descr = "Exclusion - Live birth deliveries must be during the query period"; report_descr = "Pregnancy episode recorded during the query period"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode satisfying the pre-index enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the pre-index enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Live birth deliveries must satisfy the enrollment criterion"; report_descr = "Had sufficient pre-delivery continuous enrollment"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode satisfying the HOI-defined enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the HOI-defined enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode satisfying all exclusion and inclusion criteria"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy all exclusion and inclusion criteria"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Pregnancy episodes must satisfy the inclusion and exclusion criteria"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Member";  descr = "Information: Members excluded for lacking"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Information: Episodes excluded for lacking"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Member";  descr = "Information: Members excluded for"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Information: Episodes excluded for"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode satisfying the cumulative dose criteria"; report_descr = "Met cumulative dose criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the cumulative dose criteria"; report_descr = "Met cumulative dose criteria"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode satisfying the minimum current filled daily dose criteria"; report_descr = "Met minimum current filled daily dose criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the minimum current filled daily dose criteria"; report_descr = "Met minimum current filled daily dose criteria"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode satisfying the maximum current filled daily dose criteria"; report_descr = "Met maximum current filled daily dose criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the maximum current filled daily dose criteria"; report_descr = "Met maximum current filled daily dose criteria"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode that meets HOI incidence criterion"; report_descr = "Met event incidence criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must meet HOI incidence criterion"; report_descr = "Met event incidence criteria"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode satisfying the post-index enrollment and available data criteria"; report_descr = "Had sufficient post-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the post-index enrollment and available data criteria"; report_descr = "Had sufficient post-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Pregnancy episodes must satisfy the post-delivery enrollment and available data criteria"; report_descr = "Had sufficient post-index continuous enrollment"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode with at least minimum days supplied"; report_descr = "Had minimum days' supply on index date"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must have at least minimum days supplied"; report_descr = "Met minimum days' supply criteria"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode with at least minimum days duration"; report_descr = "Had index episode of at least required length"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must have at least minimum days duration"; report_descr = "Met minimum episode duration criteria"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode with longer than blackout days duration"; report_descr = "Had index episode longer than blackout period"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must be longer than blackout days duration"; report_descr = "Episode duration was longer than blackout period"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one cohort episode that meets HOI blackout criterion"; report_descr = "Did not have an event during blackout period"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must meet HOI blackout criterion"; report_descr = "Did not have an event during blackout period"; output;
		claim_level = "Member";  descr = "Exclusion - Members must have at least one HOI in a HOI assessment window"; report_descr = "Had an event during the risk or control window"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must have at least one HOI in a HOI assessment window"; report_descr = "Had an event during the risk or control window"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort includes all valid exposure episodes during the query period until an outcome of interest occurs"; report_descr = "Episode occurred after first event"; output;
		claim_level = "Member";  descr = "Information - Unique number of members in final cohort"; report_descr = "Number of members"; output;
		claim_level = "Episode"; descr = "Information - Number of non-pregnant matched comparator episodes"; report_descr = "Number of non-pregnant matched comparator episodes"; output;
		
		claim_level = "MIL"; descr = "Initial Episode Count - Pregnancy episodes meeting initial cohort eligibility requirements"; report_descr = "Pregnancy episodes met initial cohort eligibility requirements"; output;
		claim_level = "MIL"; descr = "Exclusion - Pregnancy episodes must have evidence of the MOI"; report_descr = "Medical product of interest recorded during pregnancy episode"; output;
		claim_level = "MIL"; descr = "Exclusion - Linked infant must satisfy the sex requirement"; report_descr = "Linked infant met sex requirement"; output;
		claim_level = "MIL"; descr = "Exclusion - Pregnancy episodes must be excluded if the member has evidence of earlier initiation of EOI or REF"; report_descr = "Linked mother excluded due to prior initiation of other exposure group"; output;
		claim_level = "MIL"; descr = "Exclusion - Live birth delivery must be during the look period"; report_descr = "Live birth delivery recorded during current look period"; output;
		claim_level = "MIL"; descr = "Exclusion - Pregnancy episodes must satisfy the age range condition within the query period"; report_descr = "Linked live birth delivery recorded during specified age range"; output;
		claim_level = "MIL"; descr = "Exclusion - Pregnancy episodes must satisfy the enrollment requirements"; report_descr = "Linked mother had sufficient pre-index continuous enrollment"; output;
		claim_level = "MIL"; descr = "Exclusion - Pregnancy episodes must satisfy the inclusion and exclusion criteria"; report_descr = "Linked mother met inclusion and exclusion criteria"; output;
		claim_level = "MIL"; descr = "Exclusion - Restrict to first valid pregnancy episode"; report_descr = "Restricted to first valid pregnancy episode"; output;
		claim_level = "MIL"; descr = "Information: Episodes excluded for lacking"; report_descr = "Linked mother met inclusion and exclusion criteria"; output;
		claim_level = "MIL"; descr = "Information: Episodes excluded for"; report_descr = "Linked mother met inclusion and exclusion criteria"; output;
							 
		claim_level = "L2";  descr = "Patients excluded due to same day EOI and REF initiation"; report_descr = "Excluded due to same-day initition of both exposure groups"; output;
		claim_level = "L2";  descr = "Patients excluded due to earlier initiation of EOI or REF"; report_descr = "Excluded due to prior initiation of other exposure group"; output;
		claim_level = "L2";  descr = "Patients excluded due to earlier initiation of EOI or REF in a prior look"; report_descr = "Excluded due to prior initiation of other exposure group in a prior look"; output;
		claim_level = "L2";  descr = "Patients excluded due to non-overlap eligibility criteria"; report_descr = "Excluded due to propensity score trimming"; output;
		claim_level = "L2";  descr = "Patients excluded due to lack of treatment heterogeneity in stratum"; report_descr = "Excluded due to lack of treatment heterogeneity in stratum"; output; 
		claim_level = "L2";  descr = "Patients in adjusted cohort"; report_descr = "Included in comparative analysis"; output;
		claim_level = "L2";  descr = "Events for patients in adjusted cohort"; report_descr = "Number of events in comparative analysis"; output;
		claim_level = "L2";  descr = "Information: Number of patients whose IPTW was truncated"; report_descr = "Number of patients with a truncated inverse probability of treatment weight"; output;
	 run; 

  %mend create_lookup;
  %create_lookup();
