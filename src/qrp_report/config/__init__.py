"""Configuration loading and validation for QRP Report."""

from qrp_report.config.errors import ErrorSeverity, ValidationMessage
from qrp_report.config.loader import ConfigLoader, load_config
from qrp_report.config.models import (
    BaselineConfig,
    DPInfo,
    FigureConfig,
    GroupConfig,
    L2ComparisonConfig,
    LabelConfig,
    PSMethod,
    ReportConfig,
    ReportDestination,
    ReportType,
    TableConfig,
)
from qrp_report.config.validation import ConfigValidator, validate_config

__all__ = [
    # Error types
    "ErrorSeverity",
    "ValidationMessage",
    # Loader
    "ConfigLoader",
    "load_config",
    # Validator
    "ConfigValidator",
    "validate_config",
    # Models
    "BaselineConfig",
    "DPInfo",
    "FigureConfig",
    "GroupConfig",
    "L2ComparisonConfig",
    "LabelConfig",
    "PSMethod",
    "ReportConfig",
    "ReportDestination",
    "ReportType",
    "TableConfig",
]
