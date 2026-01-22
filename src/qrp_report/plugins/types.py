"""Report plugin types for QRP Report.

Defines the protocol that all report plugins must implement,
along with shared context and result types.
"""

from dataclasses import dataclass, field
from typing import Protocol, Literal, Any
from pathlib import Path

import polars as pl


ReportType = Literal["T1", "T2L1", "T2L2", "T4L1", "T4L2"]


@dataclass(frozen=True)
class TableResult:
    """Result from generating a single report table."""

    table_id: str
    title: str
    data: pl.DataFrame
    footnotes: tuple[str, ...] = ()
    stratification: str | None = None


@dataclass(frozen=True)
class FigureResult:
    """Result from generating a single report figure."""

    figure_id: str
    title: str
    figure_type: Literal["histogram", "forest_plot", "km_curve"]
    data: pl.DataFrame
    metadata: tuple[tuple[str, Any], ...] = ()


@dataclass(frozen=True)
class ReportResult:
    """Complete result from a report plugin."""

    report_type: ReportType
    tables: tuple[TableResult, ...]
    figures: tuple[FigureResult, ...] = ()
    warnings: tuple[str, ...] = ()

    @property
    def table_ids(self) -> tuple[str, ...]:
        """Return all table IDs in this result."""
        return tuple(t.table_id for t in self.tables)

    @property
    def figure_ids(self) -> tuple[str, ...]:
        """Return all figure IDs in this result."""
        return tuple(f.figure_id for f in self.figures)


@dataclass(frozen=True)
class DataPartnerInfo:
    """Information about a single data partner."""

    dp_id: str
    masked_id: str  # e.g., "DP01", "DP02"
    data_path: Path


@dataclass(frozen=True)
class StratificationConfig:
    """Configuration for stratification variables."""

    variables: tuple[str, ...]  # e.g., ("sex", "race", "agegroup")
    by_dp: bool = False  # Whether to stratify by data partner


@dataclass(frozen=True)
class ReportContext:
    """Context passed to report plugins for execution.

    Contains all configuration and data paths needed to generate
    a report. Plugins should not modify this context.
    """

    report_type: ReportType
    run_id: str
    groups: tuple[str, ...]
    data_partners: tuple[DataPartnerInfo, ...]
    stratification: StratificationConfig | None
    output_dir: Path

    # Table configuration
    table_specs: dict[str, Any] = field(default_factory=dict)

    # L2-specific (optional)
    periods: tuple[int, ...] = ()
    ps_method: Literal["matching", "stratification", "iptw", "covstrat"] | None = None
    l2_comparison_file: Path | None = None


class ReportPlugin(Protocol):
    """Protocol that all report plugins must implement.

    Plugins are responsible for:
    1. Loading data from data partners
    2. Aggregating across data partners
    3. Computing statistics
    4. Producing table and figure results
    """

    @property
    def report_type(self) -> ReportType:
        """The report type this plugin handles."""
        ...

    @property
    def required_datasets(self) -> tuple[str, ...]:
        """Dataset names this plugin requires (e.g., 't1_cida', 'censor_cida')."""
        ...

    def validate_context(self, context: ReportContext) -> tuple[str, ...]:
        """Validate context and return any error messages.

        Returns empty tuple if valid, otherwise tuple of error strings.
        """
        ...

    def execute(self, context: ReportContext) -> ReportResult:
        """Execute the report plugin and return results.

        This is the main entry point. It should:
        1. Load and aggregate data
        2. Compute statistics
        3. Return structured results

        Raises:
            ValueError: If context is invalid
            FileNotFoundError: If required datasets are missing
        """
        ...
