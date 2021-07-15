*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: create_lookup.sas  
* Created (mm/dd/yyyy): 03/23/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: The macro creates all files that reside in the lookuptables folder. These are lookuptables
*          used for processing, but cannot be modified by the user.
* 
*  Program inputs:                                                                                   
* 
*  Program outputs: The following lookuptables files are created:
*   -lookup_footnotes_baseline  = Footnotes for baseline table
*   -lookup_footnotes_effectest = Footnotes for L2 effect estimates table
*   -lookup_footnotes_attrition = Footnotes for attrition table
*   -lookup_attrition           = Mapping QRP attrition descriptions to report descriptions
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
     data lookup.lookup_footnotes_baseline;
	   attrib order        length = 3    format = 3.
	          description  length = $575 format = $575.;
	   order = 1;  description = "All metrics are based on total number of episodes per group, except for sex, race, and Hispanic origin which are based on total number of unique patients."; output;
	   order = 2;  description = "Covariates in blue show a standardized difference greater than &sdthreshold.."; output;
	   order = 3;  description = "Covariates in italics were not included in the propensity score logistic regression model."; output;
	   order = 4;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after propensity score (PS) stratum weighting and should not be interpreted as a description of the unweighted population. Treated/control patients are weighted by the proportion of the total patient population included in their PS stratum divided by the proportion of the total treated/control patient population included in their PS stratum."; output;
	   order = 5;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after propensity score (PS) stratum weighting and should not be interpreted as a description of the unweighted population. Treated patients are assigned a weight of 1, and control patients are weighted by the proportion of the total treated patient population included in their PS stratum divided by the proportion of the total control patient population included in their PS stratum."; output;
	   order = 6;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after propensity score (PS) stratification and should not be interpreted as a description of the unweighted population. Treated/control patients are weighted by the proportion of the total patient population included in their PS stratum divided by the proportion of the total treated/control patient population included in their PS stratum."; output;
	   order = 7;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after inverse probability weighting and should not be interpreted as a description of the unweighted population. Treated patients are weighted by the inverse of their propensity score (PS), while reference patients are weighted by the inverse of 1 minus their PS."; output;
	   order = 8;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after inverse probability weighting and should not be interpreted as a description of the unweighted population. Treated patients are weighted by the proportion of treated patients in the trimmed population divided by the inverse of their propensity score (PS). Reference patients are weighted by 1 minus the proportion of treated patients in the trimmed population divided by 1 minus their PS."; output;
	   order = 9;  description = "Weighted patient characteristics tables facilitate the assessment of covariate balance after inverse probability weighting and should not be interpreted as a description of the unweighted population. Treated patients are assigned a weight of 1. Reference patients are weighted by their propensity score (PS) divided by 1 minus their PS."; output;
	   order = 10; description = "With variable ratio matching, each exposed subject is matched to a variable number of comparator subjects. The weight for each treated subject equals 1 (wi = 1 for i = 1, ..., nt). The weight for each control subject equals the inverse of the matching ratio for that specific matched set."; output;
	   order = 11; description = "Baseline period in reference to user defined index date (pregnancy start, exposure date, or delivery date)."; output;
	   order = 12; description = "Represents proportion of episodes with first switch."; output;
	   order = 13; description = "Represents proportion of first switch episodes with second switch."; output;
	   order = 14; description = "Value represents standard deviation where no % follows the value."; output;
       order = 15; description = "Race data may not be completely populated at all Data Partners; therefore, data about race may be incomplete."; output;
	   order = 16; description = "Gestational age estimated using a claims-based algorithm, previously validated in the Medication Exposure in Pregnancy Risk Evaluation Program (MEPREP), to identify pregnancies ending in a live birth. ICD-10-CM diagnosis codes indicative of weeks of gestation, and ICD-9-CM and ICD-10-CM diagnosis codes for preterm and post-term deliveries, were used to calculate the length of the pregnancy episode. Codes had to occur within 7 days of a delivery date in the inpatient setting. In absence of pre-/post-term codes, pregnancy duration was set to 273 days."; output;
	   order = 17; description = "The Charlson/Elixhauser Combined Comorbidity Score is calculated based on comorbidities observed during a requester-defined window around the exposure episode start date. (Gagne JJ, Glynn RJ, Avorn J, Levin R, Schneeweiss S. A combined comorbidity score predicted mortality in elderly patients better than existing scores. J Clin Epidemiol. 2011;64(7):749-759)"; output;
	 run; 

     data lookup.lookup_footnotes_effectest;
	   attrib order        length = 3    format = 3.
	          description  length = $575 format = $575.;
	   order = 1;  description = "Race data may not be completely populated at all Data Partners; therefore, data about race may be incomplete."; output;
	   order = 2;  description = "Delivery status based on algorithm-derived pregnancy duration."; output;
	   order = 3;  description = "Conditional analysis accounts for informative events and person-time."; output;
	   order = 4;  description = "&weightscheme. = &weightschemelong.."; output;
	 run;  

     data lookup.lookup_footnotes_attrition;
	   attrib order        length = 3    format = 3.
	          description  length = $575 format = $575.;
	   order = 1; description = '&claim_level_descr. can meet multiple inclusion and/or exclusion criteria; therefore, the total number of %sysfunc(lowcase(&claim_level_descr.)) excluded overall may not equal the sum of all %sysfunc(lowcase(&claim_level_descr.)) in each criterion.'; output;
	 run;  
	 
     data lookup.lookup_attrition;
	   attrib claim_level   length = $10	format = $10.
              descr  		length = $500	format = $500.
			  report_descr	length = $500	format = $500.;
		claim_level = "Member"; descr = "Initial Member Count - Members with a non-missing birth date/sex at any enrollment episode overlapping the query period"; report_descr = "Enrolled at any point during the query period"; output;
		claim_level = "Member"; descr = "Exclusion - Members must be excluded if they only have enrollment episodes with DrugCov=N and MedCov=Y or A during the query period"; report_descr = "Had required coverage type (medical and/or drug coverage)"; output;
		claim_level = "Member"; descr = "Exclusion - Members must be excluded if they only have enrollment episodes with DrugCov=Y and MedCov=N during the query period"; report_descr = "Had required coverage type (medical and/or drug coverage)"; output;
		claim_level = "Member"; descr = "Exclusion - Members must be excluded if they only have enrollment episodes with DrugCov=Y and MedCov=N and DrugCov=N and MedCov=Y or A during the query period"; report_descr = "Had required coverage type (medical and/or drug coverage)"; output;
		claim_level = "Member"; descr = "Exclusion - Members must satisfy the age range condition within the query period"; report_descr = "Enrolled during specified age range"; output;
		claim_level = "Member"; descr = "Exclusion - Members must meet chart availability criterion within the query period"; report_descr = "Had requestable medical charts"; output;
		claim_level = "Member"; descr = "Exclusion - Members must satisfy the demographic (sex, race and hispanic) condition"; report_descr = "Met demographic requirements (sex, race, and Hispanic origin)"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one claim with cohort-identifying codes within the query period"; report_descr = "Had any cohort-defining claim during the query period"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one live birth delivery during the query period"; report_descr = "Had a live birth delivery claim during the query period"; output;
		claim_level = "Episode"; descr = "Initial Episode Count (among eligible members from previous step) - All claims with cohort-identifying codes"; report_descr = "Total number of claims with cohort-identifying codes during the query period"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode index date within the age range condition"; report_descr = "Claim recorded during specified age range"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episode must have an index date within the age range condition"; report_descr = "Claim recorded during specified age range"; output;
		claim_level = "Episode"; descr = "Exclusion - Live birth deliveries must have an index date within the age range condition"; report_descr = "Live birth delivery recorded during specified age range"; output;
		claim_level = "Member"; descr = "Exclusion - Members cannot have all their valid index dates in a prior look period"; report_descr = "Claim recorded during current look period"; output;
		claim_level = "Episode"; descr = "Exclusion - Valid index dates cannot be in a prior look period"; report_descr = "Claim recorded during current look period"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one episode defining index claim during the query period"; report_descr = "Episode defining index claim recorded during the query period"; output;
		claim_level = "Episode"; descr = "Exclusion - Episode-defining index claims must be during the query period"; report_descr = "Episode defining index claim recorded during the query period"; output;
		claim_level = "Episode"; descr = "Exclusion - Live birth deliveries must be during the query period"; report_descr = "Pregnancy episode recorded during the query period"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode incident with respect to other criteria"; report_descr = "Met exposure incidence criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must be incident with respect to other criteria"; report_descr = "Met exposure incidence criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Live birth deliveries must be incident with respect to other criteria"; report_descr = "Met pregnancy episode incidence criteria"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have only one exposure RX on index date"; report_descr = "Had single National Drug Code on index date"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must have only one exposure RX on index date"; report_descr = "Had single National Drug Code on index date"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode satisfying the pre-index enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the pre-index enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Live birth deliveries must satisfy the pre-delivery enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode satisfying the HOI-defined enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the HOI-defined enrollment criterion"; report_descr = "Had sufficient pre-index continuous enrollment"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode satisfying all exclusion and inclusion criteria"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy all exclusion and inclusion criteria"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Pregnancy episodes must satisfy the inclusion and exclusion criteria"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Member"; descr = "Information: Members excluded for lacking"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Information: Episodes excluded for lacking"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Member"; descr = "Information: Members excluded for"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Episode"; descr = "Information: Episodes excluded for"; report_descr = "Met inclusion and exclusion criteria"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode satisfying the cumulative dose criteria"; report_descr = "Met cumulative dose criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the cumulative dose criteria"; report_descr = "Met cumulative dose criteria"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode that meets HOI incidence criterion"; report_descr = "Met event incidence criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must meet HOI incidence criterion"; report_descr = "Met event incidence criteria"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode satisfying the post-index enrollment criterion"; report_descr = "Had sufficient post-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the post-index enrollment criterion"; report_descr = "Had sufficient post-index continuous enrollment"; output;
		claim_level = "Episode"; descr = "Exclusion - Pregnancy episodes must satisfy the post-delivery enrollment criterion"; report_descr = "Had sufficient post-index continuous enrollment"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode with at least minimum days supplied"; report_descr = "Had minimum days' supply on index date"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must have at least minimum days supplied"; report_descr = "Met minimum days' supply criteria"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode with at least minimum days duration"; report_descr = "Had index episode of at least required length"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must have at least minimum days duration"; report_descr = "Met minimum episode duration criteria"; output;
      claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode satisfying the minimum and maximum average filled daily dose criteria"; report_descr = "Met average filled daily dose criteria"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must satisfy the minimum and maximum average filled daily dose criteria"; report_descr = "Met average filled daily dose criteria"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode with longer than blackout days duration"; report_descr = "Had index episode longer than blackout period"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must be longer than blackout days duration"; report_descr = "Episode duration was longer than blackout period"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one cohort episode that meets HOI blackout criterion"; report_descr = "Did not have an event during blackout period"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must meet HOI blackout criterion"; report_descr = "Did not have an event during blackout period"; output;
		claim_level = "Member"; descr = "Exclusion - Members must have at least one HOI in a HOI assessment window"; report_descr = "Had an event during the risk or control window"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort episodes must have at least one HOI in a HOI assessment window"; report_descr = "Had an event during the risk or control window"; output;
		claim_level = "Episode"; descr = "Exclusion - Cohort includes all valid exposure episodes during the query period until an outcome of interest occurs"; report_descr = "Episode occurred after first event"; output;
		claim_level = "Member"; descr = "Information - Unique number of members in final cohort"; report_descr = "Number of members"; output;
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
	 run; 

  %mend create_lookup;
  %create_lookup();


