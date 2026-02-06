# SAS Configuration Files

This directory is for SAS-based configuration files (`.sas7bdat` format).

If you prefer YAML configuration, see `examples/` instead.

## Directory Structure

Place your SAS configuration files here:

```
inputfiles/
├── report_parameters.sas7bdat    # Main config file (REQUIRED)
├── dpinfo.sas7bdat               # Data Partner information
├── groups.sas7bdat               # Analysis groups
├── baseline.sas7bdat             # Baseline/Table 1 configuration
├── tables.sas7bdat               # Table specifications
├── figures.sas7bdat              # Figure specifications (optional)
├── labels.sas7bdat               # Custom labels (optional)
└── l2comparisons.sas7bdat        # L2 comparisons (T2L2/T4L2 only)
```

## Main Configuration File: report_parameters.sas7bdat

The `report_parameters.sas7bdat` file contains key-value pairs that reference the other config files. Required parameters:

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| `reportid` | Unique report identifier | `ACE_2024_001` |
| `reporttype` | Report type | `T1`, `T2L1`, `T2L2`, `T4L1`, `T4L2` |
| `dpinfofile` | Data Partner info file | `dpinfo` |
| `groupsfile` | Analysis groups file | `groups` |
| `baselinefile` | Baseline config file | `baseline` |
| `tablefile` | Table specifications file | `tables` |

Optional parameters:

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| `figurefile` | Figure specifications | `figures` |
| `labelfile` | Custom labels | `labels` |
| `l2comparisonfile` | L2 comparisons | `l2comparisons` |
| `stratifybydp` | Include DP-stratified tables | `Y` or `N` |
| `small_cellcounts` | Cell suppression threshold | `5` |
| `report_destination` | Output format | `EXCEL`, `PDF`, `BOTH` |
| `seed` | Random seed for DP masking | `12345` |

## Auxiliary Files

### dpinfo.sas7bdat

| Column | Description |
|--------|-------------|
| `dp` | Data Partner ID |
| `dpname` | Display name |
| `path` | Path to msocdata folder |
| `database` | Database description |
| `includedp` | Include in report (`Y`/`N`) |

### groups.sas7bdat

| Column | Description |
|--------|-------------|
| `runid` | Query run identifier |
| `group` | Group name (matches data) |
| `order` | Display order |
| `includeinfigure` | Include in figures (`Y`/`N`) |
| `codedist` | Code distribution module |
| `topncodedist` | Top N codes to show |

### baseline.sas7bdat

| Column | Description |
|--------|-------------|
| `runid` | Query run identifier |
| `group` | Group name |
| `order` | Table order |
| `baseline` | Is baseline group (`Y`/`N`) |
| `baselinegroupnum` | Sub-group number |
| `labcharacteristics` | Lab covariates (space-separated) |
| `covinps` | Covariates in PS (L2 only) |

### tables.sas7bdat

| Column | Description |
|--------|-------------|
| `table` | Table identifier (e.g., `T1A`) |
| `tablesub` | Sub-stratification name |
| `dataset` | Source dataset |
| `levelid1` | Stratification level 1 |
| `levelid2` | Stratification level 2 |
| `levelid3` | Stratification level 3 |
| `categories` | Column format |
| `includeinreport` | Include in report (`Y`/`N`) |

## Usage

Run the CLI pointing to this directory:

```bash
# Validate configuration
qrp-report validate ./inputfiles/

# Generate report
qrp-report generate ./inputfiles/
```

Or point directly to the main config file:

```bash
qrp-report generate ./inputfiles/report_parameters.sas7bdat
```
