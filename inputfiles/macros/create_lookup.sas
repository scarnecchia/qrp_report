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
*   -lookup_footnotes (one record created per footnote)
*        
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
	   attrib order        length = 3    format = 3.
	          description  length = $575 format = $575.;
	   order = 1;  description = "All metrics are based on total number of episodes per group, except for sex, race, and Hispanic origin which are based on total number of unique patients."; output;
	   order = 2;  description = "Covariates in blue show a standardized difference greater than &threshold.."; output;
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
  %mend create_lookup;
  %create_lookup();


