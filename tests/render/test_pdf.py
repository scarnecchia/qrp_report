"""Tests for PDF renderer."""

from pathlib import Path

import polars as pl
import pytest

from qrp_report.render.pdf import PDFRenderer
from qrp_report.render.types import (
    Alignment,
    ColumnSpec,
    Orientation,
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


class TestPDFRenderer:
    """Tests for PDFRenderer."""

    def test_creates_pdf_file(self, render_context: RenderContext) -> None:
        """Should create a PDF file."""
        renderer = PDFRenderer(render_context)
        output_path = renderer.render()

        assert output_path.exists()
        assert output_path.suffix == ".pdf"

    def test_file_named_correctly(self, render_context: RenderContext) -> None:
        """File should be named qrp_report{reportid}.pdf."""
        renderer = PDFRenderer(render_context)
        output_path = renderer.render()

        assert output_path.name == "qrp_reporttest001.pdf"

    def test_creates_output_directory(self, tmp_path: Path) -> None:
        """Should create output directory if it doesn't exist."""
        nested_dir = tmp_path / "nested" / "output"
        context = RenderContext(
            report_id="test002",
            output_dir=nested_dir,
            sections=[],
        )
        renderer = PDFRenderer(context)
        output_path = renderer.render()

        assert output_path.parent.exists()

    def test_renders_without_toc(self, render_context: RenderContext) -> None:
        """Should render without TOC when disabled."""
        render_context.table_of_contents = False
        renderer = PDFRenderer(render_context)
        output_path = renderer.render()

        assert output_path.exists()

    def test_handles_empty_sections(self, tmp_path: Path) -> None:
        """Should handle report with no sections."""
        context = RenderContext(
            report_id="empty",
            output_dir=tmp_path,
            sections=[],
        )
        renderer = PDFRenderer(context)
        output_path = renderer.render()

        assert output_path.exists()

    def test_landscape_orientation(
        self, sample_data: pl.DataFrame, tmp_path: Path
    ) -> None:
        """Should support landscape orientation."""
        spec = TableSpec(
            table_id="t1",
            title="Landscape Table",
            columns=[
                ColumnSpec(name="group", label="Group", order=1),
                ColumnSpec(name="count", label="Count", order=2),
            ],
            orientation=Orientation.LANDSCAPE,
        )
        section = ReportSection(
            section_type="table",
            spec=spec,
            data=sample_data,
        )
        context = RenderContext(
            report_id="landscape",
            output_dir=tmp_path,
            sections=[section],
        )
        renderer = PDFRenderer(context)
        output_path = renderer.render()

        assert output_path.exists()

    def test_multiple_footnotes(
        self, sample_data: pl.DataFrame, tmp_path: Path
    ) -> None:
        """Should handle multiple footnotes."""
        spec = TableSpec(
            table_id="t1",
            title="Multi-footnote Table",
            columns=[
                ColumnSpec(name="group", label="Group", order=1),
            ],
            footnotes=[
                "First footnote.",
                "Second footnote.",
                "Third footnote.",
            ],
        )
        section = ReportSection(
            section_type="table",
            spec=spec,
            data=sample_data,
        )
        context = RenderContext(
            report_id="footnotes",
            output_dir=tmp_path,
            sections=[section],
        )
        renderer = PDFRenderer(context)
        output_path = renderer.render()

        assert output_path.exists()
