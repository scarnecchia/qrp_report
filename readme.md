![alt text](https://dev.sentinelsystem.org/projects/AP/repos/sentinel-analytic-packages/raw/resources/logo.png?at=refs%2Fheads%2Fmaster)
# Sentinel Query Request Package (QRP) Reporting Tool

## Overview

The Sentinel QRP Reporting Tool generates formatted reports from the output of the [Sentinel routine querying tools](https://dev.sentinelsystem.org/projects/AD/repos/qrp/browse). It aggregates results across multiple Data Partner sites in the Sentinel Distributed Database (SDD), computes epidemiological statistics, and produces Excel and PDF reports.

**Version 5.0** is a complete rewrite in Python, replacing the previous SAS implementation.

## Requirements

- Python 3.12 or higher
- Output tables from the Sentinel routine querying tools (SAS7BDAT format)

## Installation

```bash
# Clone the repository
git clone https://github.com/scarnecchia/qrp_report.git
cd qrp_report

# Activate the virtual environment
source .venv/bin/activate

# Install with pip
pip install -e .

# Or with uv (recommended)
uv pip install -e .
```

## Quick Start

### 1. Verify Installation

```bash
# Check CLI is available
qrp-report --help

# List available report types
qrp-report list-plugins
```

Available report types:
- **T1**: Background rates and population statistics
- **T2L1**: Exposure and follow-up analysis (Level 1 - descriptive)
- **T2L2**: Effect estimates with propensity score methods (Level 2 - inferential)
- **T4L1**: Pregnancy-specific background rates
- **T4L2**: Pregnancy-specific effect estimates

### 2. Create a Configuration File

See `examples/` for complete configuration examples:
- `t1_config_example.yaml` - Full T1 config with all options documented
- `t1_config_minimal.yaml` - Minimal T1 config with required fields only

Minimal example (`config.yaml`):

```yaml
reportid: "MY_ANALYSIS_001"
reporttype: T1

dpinfo:
  - dp: "DP001"
    dpname: "Data Partner 1"
    path: "/path/to/dp001/msocdata"

groups:
  - runid: "myquery"
    group: "exposure"
    order: 1

baseline:
  - runid: "myquery"
    group: "exposure"
    order: 1
    baseline: true

tables:
  - table: "T1A"
    tablesub: "overall"
    dataset: "t1_cida"

report_destination: EXCEL
```

### 3. Validate Configuration

```bash
qrp-report validate config.yaml
```

### 4. Generate Report

```bash
qrp-report generate config.yaml
```

## Configuration Reference

| Field | Required | Description |
|-------|----------|-------------|
| `reporttype` | Yes | Report type: T1, T2L1, T2L2, T4L1, T4L2 |
| `runid` | Yes | Unique identifier for this analysis run |
| `groups` | Yes | List of analysis groups to include |
| `datapartners` | Yes | List of data partner configurations |
| `outputdir` | Yes | Directory for output files |
| `stratification` | No | Variables to stratify by (e.g., sex, agegroup) |
| `periods` | No | Analysis periods (required for L2 reports) |
| `psmethod` | No | PS method for L2: matching, stratification, iptw, covstrat |

## Input Data

The tool expects output from Sentinel routine querying tools:

- **Type 1**: Background rates ([documentation](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type1.md))
- **Type 2**: Exposures and follow-up ([documentation](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type2.md))
- **Type 4**: Pregnancy utilization ([documentation](https://dev.sentinelsystem.org/projects/SENTINEL/repos/sentinel-routine-querying-tool-documentation/browse/files/atoc-type4.md))

## Output

Reports are saved to the configured output directory:
- Excel reports (`.xlsx`) with formatted tables
- PDF reports (`.pdf`) with publication-ready formatting
- Aggregated data files (`.parquet`) for further analysis

## Development

```bash
# Install development dependencies
uv pip install -e ".[dev]"

# Run tests
pytest tests/ -v

# Run type checking
mypy src/qrp_report/

# Run linter
ruff check src/qrp_report/
```

## Compatibility

| QRP Version | QRP Report Version |
|-------------|-------------------|
| 14.3.0+ | 5.0.0 (Python) |
| 14.3.0+ | 4.3.0 (SAS) |
| 14.2.1 | 4.2.1 |
| 14.2.0 | 4.2.0 |
| 14.1.0 | 4.1.1 |
| 14.0.0 | 4.0.0 |

## Additional Information

The Sentinel Operations Center welcomes feedback, comments, and suggestions. Email us [here](mailto:info@sentinelsystem.org?subject=Git).
