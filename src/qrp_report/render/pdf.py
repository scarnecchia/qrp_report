"""PDF rendering for QRP Report.

Generates PDF reports with tables, figures, and table of contents
matching the SAS ODS PDF output.

Uses reportlab for PDF generation.
"""

from pathlib import Path
from typing import Any

import polars as pl
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate,
    Table,
    TableStyle,
    Paragraph,
    Spacer,
    PageBreak,
)

from qrp_report.render.types import (
    Alignment,
    ColumnSpec,
    Orientation,
    RenderContext,
    ReportSection,
    TableSpec,
)
from qrp_report.render.formatters import apply_format


class PDFRenderer:
    """Renders QRP reports to PDF format.

    Creates PDF documents with:
    - Table of Contents
    - Data tables with headers and footnotes
    - Portrait/landscape orientation support
    - Consistent styling matching SAS output
    """

    def __init__(self, context: RenderContext) -> None:
        """Initialize renderer with context.

        Args:
            context: RenderContext with report configuration
        """
        self.context = context
        self._styles = getSampleStyleSheet()
        self._setup_custom_styles()

    def _setup_custom_styles(self) -> None:
        """Set up custom paragraph styles."""
        self._styles.add(
            ParagraphStyle(
                name="TableTitle",
                parent=self._styles["Heading2"],
                fontSize=11,
                fontName="Helvetica-Bold",
                spaceAfter=6,
            )
        )
        self._styles.add(
            ParagraphStyle(
                name="Footnote",
                parent=self._styles["Normal"],
                fontSize=9,
                fontName="Helvetica",
                spaceBefore=6,
            )
        )
        self._styles.add(
            ParagraphStyle(
                name="TOCEntry",
                parent=self._styles["Normal"],
                fontSize=11,
                leftIndent=20,
            )
        )

    def render(self) -> Path:
        """Render the complete report to PDF.

        Returns:
            Path to the generated PDF file
        """
        output_path = self.context.pdf_path
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Determine page size from first table orientation
        pagesize = letter
        if self.context.sections:
            first_section = self.context.sections[0]
            if (
                first_section.section_type == "table"
                and first_section.spec.orientation == Orientation.LANDSCAPE
            ):
                pagesize = landscape(letter)

        doc = SimpleDocTemplate(
            str(output_path),
            pagesize=pagesize,
            leftMargin=0.5 * inch,
            rightMargin=0.5 * inch,
            topMargin=0.5 * inch,
            bottomMargin=0.5 * inch,
        )

        story: list[Any] = []

        # Add title
        story.append(
            Paragraph(self.context.title, self._styles["Title"])
        )
        story.append(Spacer(1, 0.25 * inch))

        # Add table of contents
        if self.context.table_of_contents:
            story.extend(self._build_toc())
            story.append(PageBreak())

        # Add sections
        for section in self.context.sections:
            if section.section_type == "table":
                story.extend(self._build_table(section))
                story.append(PageBreak())

        doc.build(story)
        return output_path

    def _build_toc(self) -> list[Any]:
        """Build table of contents elements.

        Returns:
            List of flowable elements
        """
        elements: list[Any] = []
        elements.append(
            Paragraph("Table of Contents", self._styles["Heading1"])
        )
        elements.append(Spacer(1, 0.1 * inch))

        for i, section in enumerate(self.context.sections, start=1):
            if section.section_type == "table":
                entry = f"Table {i}. {section.spec.title}"
                elements.append(
                    Paragraph(entry, self._styles["TOCEntry"])
                )

        return elements

    def _build_table(self, section: ReportSection) -> list[Any]:
        """Build table elements for a section.

        Args:
            section: ReportSection with table spec and data

        Returns:
            List of flowable elements
        """
        elements: list[Any] = []
        spec = section.spec
        data: pl.DataFrame = section.data

        # Table title
        elements.append(
            Paragraph(
                f"{spec.sheet_name}. {spec.title}",
                self._styles["TableTitle"],
            )
        )

        # Get columns to include
        columns = [c for c in spec.columns if c.include_in_report]
        columns.sort(key=lambda c: c.order)

        # Build table data
        table_data: list[list[str]] = []

        # Header row
        header_row = [col.label for col in columns]
        table_data.append(header_row)

        # Data rows
        for row in data.iter_rows(named=True):
            data_row: list[str] = []
            for col in columns:
                value = row.get(col.name)
                formatted = (
                    apply_format(value, col.format)
                    if col.format
                    else str(value or "")
                )
                data_row.append(formatted)
            table_data.append(data_row)

        # Calculate column widths
        available_width = 7.5 * inch  # Letter width minus margins
        total_spec_width = sum(col.width for col in columns)
        col_widths = [
            (col.width / total_spec_width) * available_width for col in columns
        ]

        # Create table
        table = Table(table_data, colWidths=col_widths)

        # Apply style
        style = TableStyle(
            [
                # Header styling
                ("BACKGROUND", (0, 0), (-1, 0), colors.white),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.black),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, 0), 10),
                ("ALIGN", (0, 0), (-1, 0), "CENTER"),
                ("LINEABOVE", (0, 0), (-1, 0), 1, colors.black),
                ("LINEBELOW", (0, 0), (-1, 0), 1, colors.black),
                # Data styling
                ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 1), (-1, -1), 10),
                ("ALIGN", (0, 1), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                # Cell padding
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )

        # Apply left alignment to specific columns
        for col_idx, col in enumerate(columns):
            if col.alignment == Alignment.LEFT:
                style.add("ALIGN", (col_idx, 1), (col_idx, -1), "LEFT")

        table.setStyle(style)
        elements.append(table)

        # Footnotes
        if spec.footnotes:
            elements.append(Spacer(1, 0.1 * inch))
            for i, footnote in enumerate(spec.footnotes, start=1):
                elements.append(
                    Paragraph(
                        f"<sup>{i}</sup> {footnote}",
                        self._styles["Footnote"],
                    )
                )

        return elements
