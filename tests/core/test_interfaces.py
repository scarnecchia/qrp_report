"""Tests for core interface types."""

import polars as pl
import pytest

from qrp_report.config.models import ReportConfig, ReportType
from qrp_report.core.interfaces import (
    Figure,
    ReportData,
    Table,
    TableCell,
)


class TestTableCell:
    """Tests for TableCell dataclass."""

    def test_default_values(self) -> None:
        """Test default values."""
        cell = TableCell(value="test")
        assert cell.colspan == 1
        assert cell.rowspan == 1
        assert cell.style == "data"
        assert cell.superscript is None

    def test_str_representation(self) -> None:
        """Test string representation."""
        cell = TableCell(value="100")
        assert str(cell) == "100"

    def test_str_with_superscript(self) -> None:
        """Test string with superscript."""
        cell = TableCell(value="100", superscript="a")
        assert str(cell) == "100a"

    def test_numeric_values(self) -> None:
        """Test numeric cell values."""
        int_cell = TableCell(value=42)
        float_cell = TableCell(value=3.14)
        assert str(int_cell) == "42"
        assert str(float_cell) == "3.14"


class TestTable:
    """Tests for Table dataclass."""

    def test_empty_table(self) -> None:
        """Test creating empty table."""
        table = Table(id="1a", title="Test Table")
        assert table.id == "1a"
        assert table.title == "Test Table"
        assert table.headers == []
        assert table.rows == []
        assert table.footnotes == []
        assert table.landscape is False

    def test_table_with_data(self) -> None:
        """Test creating table with data."""
        headers = [[TableCell(value="Column 1"), TableCell(value="Column 2")]]
        rows = [
            [TableCell(value="A"), TableCell(value=1)],
            [TableCell(value="B"), TableCell(value=2)],
        ]
        footnotes = ["Note 1", "Note 2"]

        table = Table(
            id="2a",
            title="Data Table",
            headers=headers,
            rows=rows,
            footnotes=footnotes,
            landscape=True,
        )

        assert len(table.headers) == 1
        assert len(table.rows) == 2
        assert len(table.footnotes) == 2
        assert table.landscape is True


class TestFigure:
    """Tests for Figure dataclass."""

    def test_minimal_figure(self) -> None:
        """Test creating minimal figure."""
        data = pl.DataFrame({"x": [1, 2, 3], "y": [4, 5, 6]})
        figure = Figure(
            id="F1",
            title="Test Figure",
            figure_type="line",
            data=data,
        )
        assert figure.id == "F1"
        assert figure.figure_type == "line"
        assert figure.x_label == ""
        assert figure.y_label == ""

    def test_figure_with_labels(self) -> None:
        """Test figure with axis labels."""
        data = pl.DataFrame({"x": [1, 2], "y": [3, 4]})
        figure = Figure(
            id="F2",
            title="Labeled Figure",
            figure_type="km_curve",
            data=data,
            x_label="Time (days)",
            y_label="Survival Probability",
            x_range=(0, 365),
            y_range=(0, 1),
        )
        assert figure.x_label == "Time (days)"
        assert figure.y_label == "Survival Probability"
        assert figure.x_range == (0, 365)
        assert figure.y_range == (0, 1)


class TestReportData:
    """Tests for ReportData dataclass."""

    def test_empty_report_data(self) -> None:
        """Test creating empty report data."""
        config = ReportConfig(reportid="test", reporttype=ReportType.T1)
        data = ReportData(config=config)

        assert data.config == config
        assert data.aggregated_data == {}
        assert data.computed_stats == {}
        assert data.metadata == {}

    def test_report_data_with_content(self) -> None:
        """Test report data with content."""
        config = ReportConfig(reportid="test", reporttype=ReportType.T2L1)
        df = pl.DataFrame({"a": [1, 2, 3]})

        data = ReportData(
            config=config,
            aggregated_data={"t1_cida": df},
            computed_stats={"mean_a": 2.0},
            metadata={"run_time": "10s"},
        )

        assert "t1_cida" in data.aggregated_data
        assert data.computed_stats["mean_a"] == 2.0
        assert data.metadata["run_time"] == "10s"
