![alt text](https://dev.sentinelsystem.org/projects/AP/repos/sentinel-analytic-packages/raw/resources/logo.png?at=refs%2Fheads%2Fmaster)
# Sentinel Query Request Package (QRP) Reporting Tool

## How to execute an analytic request package using the query request package (QRP) reporting tool

### Overview
The Sentinel QRP Reporting Tool is a SAS® program that is designed to run against the output of the <u>[Sentinel routine querying tools](https://dev.sentinelsystem.org/projects/AD/repos/qrp/browse)</u>. The QRP Reporting Tool is made up of SAS macros that allow users to aggregate results across multiple Data Partner sites in the Sentinel Distributed Database (SDD) and create formatted reports. For inferential analyses, users are able to adjust for confounders and generate effect estimates, utilizing various methods based upon the study design and balancing technique requested in the Sentinel routine querying tools. Note that data must be in the form of SAS datasets in order to use this analytic program.

### Analytic Request Package Folder Structure
* <b>inputfiles:</b> contains SAS datasets specific to the given report
* <b>output:</b> is where reports and output datasets are saved
* <b>resources:</b> contains resource file(s)
* <b>sasprograms:</b> contains the file(s) to be executed
* <b>templatefiles:</b> contains the template lookup files

### Requirements
* To execute your own customized analysis with the QRP Reporting Tool, you must
properly parameterize the appropriate input files (see documentation <u><b>[here](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-report-documentation/browse/files/atoc-inputfiles.md)</b></u>
for details)
* Output tables from the msoc folder of the Sentinel routine querying tools. The
output tables can be found in their relevant tables of contents below:
    * Type 1: <u><b>[Extract information to calculate background
        rates](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type1.md)</b></u>
    * Type 2: <u><b>[Extract information on exposures and follow-up
        time](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type2.md)</b></u>
    * Type 3: <u><b>[Extract information for a self-controlled risk interval
        design](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type3.md)</b></u>
    * Type 4: <u><b>[Extract information for medical product use during
        pregnancy](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type4.md)</b></u>
    * Type 5: <u><b>[Extract information for medical product
        utilization](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type5.md)</b></u>
    * Type 6: <u><b>[Extract information on manufacturer-level product utilization
        and switching
        patterns](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type6.md)
    </b></u>
* SAS version 9.4 or higher

### Getting Started
* Create each input file as SAS datasets (file types are sas.7bdat).
	* For more information on the input file structure in the most recent version of the QRP Reporting Tool, please refer to the <u><b>[documentation](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-report-documentation/browse)</b></u>.
* Open sasprograms\qrp_report.sas
	* Follow the instructions in section 1 in the SAS program and provide:
		* The file path for the location of your QRP request inputfiles folder
		* The file path for the location of your data folder containing QRP request output files. Should be left blank if path is specified in Data Partner Info file.
		* The file path for the location of this QRP report package
		* The name of your create report file
* Close and run qrp_report.sas by right-clicking on the file and selecting "run in batch."

### Output
* Reports are saved to the “output” folder of the QRP Reporting Tool file structure.
* The QRP output for each Data Partner is masked and stacked into datasets and are saved in a folder called "msocdata" within the "output" folder.
* The underlying aggregated report datasets are saved in a folder called "reportdata" within the "output" folder.

### Compatability
Version 1.3.0 of the QRP reporting tool is designed to be compatible with QRP 11.3.0 and later. To determine which version of the tool is compatible with older versions of QRP, use the table below:

 <table style="width:100%">
  <tr>
    <th>QRP Version<br></th>
    <th> QRP Report Version</th>
  </tr>
  <tr>
    <td>11.3.0-current</td>
    <td>1.3.0</td>
  </tr>
  <tr>
    <td>11.0.0-11.2.4</td>
    <td>1.2.4</td>
  </tr>

</table>

### Additional Information

The Sentinel Operations Center has limited capacity to support use of our tools. However, we welcome feedback, comments, and suggestions pertaining to our documentation or tools. Email us <u><b>[here](mailto:info@sentinelsystem.org?subject=Git)</u></b>.
