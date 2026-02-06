"""Core interfaces and types for QRP Report plugins."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any

import polars as pl

from qrp_report.config.errors import ValidationMessage
from qrp_report.config.models import ReportConfig


@dataclass
class TableCell:
    """A cell in a report table.

    Attributes:
        value: Cell content (string, int, or float)
        colspan: Number of columns this cell spans
        rowspan: Number of rows this cell spans
        style: Cell style (data, header, subheader, total)
        superscript: Optional superscript text (e.g., footnote reference)
    """

    value: str | int | float
    colspan: int = 1
    rowspan: int = 1
    style: str = "data"
    superscript: str | None = None

    def __str__(self) -> str:
        """String representation of cell value."""
        text = str(self.value)
        if self.superscript:
            text = f"{text}{self.superscript}"
        return text


@dataclass
class Table:
    """A report table definition.

    Tables are abstract representations that renderers convert to
    Excel worksheets or PDF table elements.

    Attributes:
        id: Table identifier (e.g., "1a", "2b")
        title: Table title text
        headers: Multi-row header (list of rows, each row is list of cells)
        rows: Data rows (list of rows, each row is list of cells)
        footnotes: List of footnote texts
        landscape: Whether to render in landscape orientation
    """

    id: str
    title: str
    headers: list[list[TableCell]] = field(default_factory=list)
    rows: list[list[TableCell]] = field(default_factory=list)
    footnotes: list[str] = field(default_factory=list)
    landscape: bool = False


@dataclass
class Figure:
    """A report figure definition.

    Figures are abstract representations that renderers convert to
    charts, plots, or images.

    Attributes:
        id: Figure identifier (e.g., "F1", "F2")
        title: Figure title text
        figure_type: Type of figure (km_curve, cif_curve, bar_chart, etc.)
        data: Data for rendering the figure
        x_label: X-axis label
        y_label: Y-axis label
        x_range: Optional (min, max) for X-axis
        y_range: Optional (min, max) for Y-axis
        footnotes: List of footnote texts
        landscape: Whether to render in landscape orientation
    """

    id: str
    title: str
    figure_type: str
    data: pl.DataFrame
    x_label: str = ""
    y_label: str = ""
    x_range: tuple[float, float] | None = None
    y_range: tuple[float, float] | None = None
    footnotes: list[str] = field(default_factory=list)
    landscape: bool = False


@dataclass
class ReportData:
    """Container for computed report data.

    Holds the results of statistical computations that plugins
    transform into tables and figures.

    Attributes:
        config: Report configuration
        aggregated_data: Dict mapping dataset names to DataFrames
        computed_stats: Dict mapping stat names to computed results
        metadata: Additional metadata from computation
    """

    config: ReportConfig
    aggregated_data: dict[str, pl.DataFrame] = field(default_factory=dict)
    computed_stats: dict[str, Any] = field(default_factory=dict)
    metadata: dict[str, Any] = field(default_factory=dict)


class ReportPlugin(ABC):
    """Abstract base class for report type plugins.

    Each report type (T1, T2L1, T2L2, etc.) implements this interface.
    Plugins are self-contained modules that handle:
    - Configuration validation specific to the report type
    - Data aggregation across Data Partners
    - Statistical computations
    - Table and figure generation

    Attributes:
        report_type: Report type code (e.g., "T1", "T2L1")
        description: Human-readable description
        supported_tables: List of table IDs this plugin can produce
        supported_figures: List of figure IDs this plugin can produce
    """

    @property
    @abstractmethod
    def report_type(self) -> str:
        """Return the report type code (e.g., 'T1', 'T2L1')."""
        ...

    @property
    @abstractmethod
    def description(self) -> str:
        """Return human-readable description of this report type."""
        ...

    @property
    @abstractmethod
    def supported_tables(self) -> list[str]:
        """Return list of table IDs this plugin can produce."""
        ...

    @property
    @abstractmethod
    def supported_figures(self) -> list[str]:
        """Return list of figure IDs this plugin can produce."""
        ...

    @abstractmethod
    def validate_config(self, config: ReportConfig) -> list[ValidationMessage]:
        """Validate configuration for this report type.

        Performs report-type-specific validation beyond the general
        validation in ConfigValidator.

        Args:
            config: Report configuration to validate.

        Returns:
            List of validation errors and warnings.
        """
        ...

    @abstractmethod
    def aggregate_data(
        self,
        dp_data: dict[str, pl.LazyFrame],
        config: ReportConfig,
    ) -> dict[str, pl.DataFrame]:
        """Aggregate data from multiple Data Partners.

        Args:
            dp_data: Dict mapping dataset types to LazyFrames with DP data.
            config: Report configuration.

        Returns:
            Dict mapping dataset names to aggregated DataFrames.
        """
        ...

    @abstractmethod
    def compute_statistics(
        self,
        data: dict[str, pl.DataFrame],
        config: ReportConfig,
    ) -> ReportData:
        """Compute statistics from aggregated data.

        Args:
            data: Dict of aggregated DataFrames from aggregate_data().
            config: Report configuration.

        Returns:
            ReportData containing computed statistics.
        """
        ...

    @abstractmethod
    def get_tables(self, data: ReportData) -> list[Table]:
        """Generate table definitions from computed data.

        Args:
            data: ReportData from compute_statistics().

        Returns:
            List of Table definitions for rendering.
        """
        ...

    @abstractmethod
    def get_figures(self, data: ReportData) -> list[Figure]:
        """Generate figure definitions from computed data.

        Args:
            data: ReportData from compute_statistics().

        Returns:
            List of Figure definitions for rendering.
        """
        ...
