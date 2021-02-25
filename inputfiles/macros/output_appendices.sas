****************************************************************************************************
*                                           PROGRAM OVERVIEW
****************************************************************************************************
*
* PROGRAM: output_appendices.sas  
* Created (mm/dd/yyyy): 02/24/2021
*
*--------------------------------------------------------------------------------------------------
* PURPOSE: This macro produces all report appendices
*                                        
*  Program inputs:                                                                                   
*
* 
*  Program outputs:  
*   - Appendix A (List of DPs) is always produced 
*   - For ReportType = L2T2 and T4L2, an aggregated VARINFO appendix is produced if any analysis
*     uses HDPS
*   - For ReportType = L2T2, a weight distribution appendix is produced if any analysis uses
*     IPTW or PS stratum weighting
*   - For ReportType = L1T2 or L1T2 an appendix listing HHS or CB region is produced if either
*     stratification is requested in the report
*   - For ReportType = T6, an appendix listing the computed start marketing date foe each cohort
*     at each data parter is produced
*   - If an APPENDIXFILE is specified, code list appendices are generated
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

%macro output_appendices();

    %put =====> MACRO CALLED: output_appendices;

***************************************************************************************************;
* Appendix A: list of DPs                                            
***************************************************************************************************;










   
***************************************************************************************************;
*                                          
***************************************************************************************************;




    %put =====> END MACRO: output_appendices ;

%mend output_appendices;
