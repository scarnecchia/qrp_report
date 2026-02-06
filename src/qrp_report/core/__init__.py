"""Core pipeline and plugin interfaces for QRP Report."""

from qrp_report.core.interfaces import (
    Figure,
    ReportData,
    ReportPlugin,
    Table,
    TableCell,
)
from qrp_report.core.pipeline import (
    PipelineContext,
    PipelineStage,
    ProgressCallback,
    ReportPipeline,
)
from qrp_report.core.registry import (
    clear_registry,
    get_plugin,
    get_registered_types,
    is_registered,
    register_plugin,
)

__all__ = [
    # Interfaces
    "Figure",
    "ReportData",
    "ReportPlugin",
    "Table",
    "TableCell",
    # Pipeline
    "PipelineContext",
    "PipelineStage",
    "ProgressCallback",
    "ReportPipeline",
    # Registry
    "clear_registry",
    "get_plugin",
    "get_registered_types",
    "is_registered",
    "register_plugin",
]
