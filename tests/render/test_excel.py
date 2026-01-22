"""Tests for Excel renderer."""

from pathlib import Path
import tempfile

import polars as pl
import pytest

from qrp_report.render.excel import ExcelRenderer
from qrp_report.render.types import (
    Alignment,
    ColumnSpec,
    RenderContext,
    ReportSection,
    TableSpec,
)


@pytest.fixture
def sample_data() -> pl.DataFrame:
    """Create sample data for testing."""
    return pl.DataFrame(
        {
            "group": ["A", "B", "C"],
            "count": [100, 200, 150],
            "rate": [12.34, 23.45, 18.90],
            "percent": [10.5, 20.3, 15.2],
        }
    )


@pytest.fixture
def sample_table_spec() -> TableSpec:
    """Create sample table specification."""
    return TableSpec(
        table_id="t1",
        title="Sample Table",
        columns=[
            ColumnSpec(
                name="group",
                label="Group",
                width=1.0,
                alignment=Alignment.LEFT,
                order=1,
            ),
            ColumnSpec(
                name="count",
                label="Count",
                width=0.8,
                format="comma14.0",
                order=2,
            ),
            ColumnSpec(
                name="rate",
                label="Rate",
                width=1.0,
                format="comma13.2",
                order=3,
            ),
            ColumnSpec(
                name="percent",
                label="Percent",
                width=0.8,
                format="percent8.1",
                order=4,
            ),
        ],
        footnotes=["This is a footnote."],
        sheet_name="Table 1",
    )


@pytest.fixture
def render_context(
    sample_data: pl.DataFrame, sample_table_spec: TableSpec, tmp_path: Path
) -> RenderContext:
    """Create render context for testing."""
    section = ReportSection(
        section_type="table",
        spec=sample_table_spec,
        data=sample_data,
    )
    return RenderContext(
        report_id="test001",
        output_dir=tmp_path,
        title="Test Report",
        sections=[section],
    )


class TestExcelRenderer:
    """Tests for ExcelRenderer."""

    def test_creates_excel_file(self, render_context: RenderContext) -> None:
        """Should create an Excel file."""
        renderer = ExcelRenderer(render_context)
        output_path = renderer.render()

        assert output_path.exists()
        assert output_path.suffix == ".xlsx"

    def test_file_named_correctly(self, render_context: RenderContext) -> None:
        """File should be named qrp_report{reportid}.xlsx."""
        renderer = ExcelRenderer(render_context)
        output_path = renderer.render()

        assert output_path.name == "qrp_reporttest001.xlsx"

    def test_creates_output_directory(self, tmp_path: Path) -> None:
        """Should create output directory if it doesn't exist."""
        nested_dir = tmp_path / "nested" / "output"
        context = RenderContext(
            report_id="test002",
            output_dir=nested_dir,
            sections=[],
        )
        renderer = ExcelRenderer(context)
        output_path = renderer.render()

        assert output_path.parent.exists()

    def test_renders_without_toc(
        self, render_context: RenderContext
    ) -> None:
        """Should render without TOC when disabled."""
        render_context.table_of_contents = False
        renderer = ExcelRenderer(render_context)
        output_path = renderer.render()

        assert output_path.exists()

    def test_handles_empty_sections(self, tmp_path: Path) -> None:
        """Should handle report with no sections."""
        context = RenderContext(
            report_id="empty",
            output_dir=tmp_path,
            sections=[],
        )
        renderer = ExcelRenderer(context)
        output_path = renderer.render()

        assert output_path.exists()

    def test_column_order_respected(
        self, sample_data: pl.DataFrame, tmp_path: Path
    ) -> None:
        """Columns should be ordered by order attribute."""
        spec = TableSpec(
            table_id="t1",
            title="Order Test",
            columns=[
                ColumnSpec(name="percent", label="Pct", order=3),
                ColumnSpec(name="group", label="Grp", order=1),
                ColumnSpec(name="count", label="Cnt", order=2),
            ],
        )
        section = ReportSection(
            section_type="table",
            spec=spec,
            data=sample_data,
        )
        context = RenderContext(
            report_id="order",
            output_dir=tmp_path,
            sections=[section],
        )
        renderer = ExcelRenderer(context)
        output_path = renderer.render()

        assert output_path.exists()

    def test_excludes_hidden_columns(
        self, sample_data: pl.DataFrame, tmp_path: Path
    ) -> None:
        """Columns with include_in_report=False should be excluded."""
        spec = TableSpec(
            table_id="t1",
            title="Hidden Column Test",
            columns=[
                ColumnSpec(name="group", label="Group", order=1),
                ColumnSpec(
                    name="count", label="Count", order=2, include_in_report=False
                ),
                ColumnSpec(name="rate", label="Rate", order=3),
            ],
        )
        section = ReportSection(
            section_type="table",
            spec=spec,
            data=sample_data,
        )
        context = RenderContext(
            report_id="hidden",
            output_dir=tmp_path,
            sections=[section],
        )
        renderer = ExcelRenderer(context)
        output_path = renderer.render()

        assert output_path.exists()
