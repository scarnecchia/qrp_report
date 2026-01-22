"""QRP Report plugins module.

Provides report type plugins that implement the pipeline:
- T1: Background rates and population statistics
- T2L1: Exposure and follow-up analysis (Level 1 - descriptive)
- T2L2: Effect estimates with propensity score methods (Level 2 - inferential)
- T4L1: Type 4 Level 1 analysis
- T4L2: Type 4 Level 2 analysis with effect estimates
"""

from qrp_report.plugins.types import (
    ReportPlugin,
    ReportContext,
    ReportResult,
    TableResult,
    FigureResult,
    DataPartnerInfo,
    StratificationConfig,
    ReportType,
)
from qrp_report.plugins.registry import (
    register_plugin,
    get_plugin,
    list_plugins,
    clear_registry,
)
from qrp_report.plugins.aggregation import (
    load_dp_dataset,
    aggregate_datasets,
    summarize_by_strata,
)

# Import plugins to trigger registration
from qrp_report.plugins import t1  # noqa: F401
from qrp_report.plugins import t2l1  # noqa: F401
from qrp_report.plugins import t2l2  # noqa: F401

__all__ = [
    # Types
    "ReportPlugin",
    "ReportContext",
    "ReportResult",
    "TableResult",
    "FigureResult",
    "DataPartnerInfo",
    "StratificationConfig",
    "ReportType",
    # Registry
    "register_plugin",
    "get_plugin",
    "list_plugins",
    "clear_registry",
    # Aggregation utilities
    "load_dp_dataset",
    "aggregate_datasets",
    "summarize_by_strata",
]
