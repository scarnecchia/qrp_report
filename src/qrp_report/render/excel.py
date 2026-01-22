"""Excel rendering for QRP Report.

Generates Excel workbooks with multiple sheets, styling, and
formatting matching the SAS ODS Excel output.

Uses xlsxwriter for workbook generation.
"""

from pathlib import Path
from typing import Any

import polars as pl
import xlsxwriter
from xlsxwriter.format import Format
from xlsxwriter.workbook import Workbook
from xlsxwriter.worksheet import Worksheet

from qrp_report.render.types import (
    Alignment,
    CellStyle,
    ColumnSpec,
    RenderContext,
    ReportSection,
    TableSpec,
    STYLE_DATA,
    STYLE_FOOTER,
    STYLE_HEADER,
    STYLE_TITLE,
)
from qrp_report.render.formatters import apply_format


class ExcelRenderer:
    """Renders QRP reports to Excel format.

    Creates multi-sheet workbooks with:
    - Table of Contents (first sheet, orange tab)
    - Data tables (subsequent sheets, green tabs)
    - Consistent styling matching SAS output
    """

    def __init__(self, context: RenderContext) -> None:
        """Initialize renderer with context.

        Args:
            context: RenderContext with report configuration
        """
        self.context = context
        self._workbook: Workbook | None = None
        self._formats: dict[str, Format] = {}

    def render(self) -> Path:
        """Render the complete report to Excel.

        Returns:
            Path to the generated Excel file
        """
        output_path = self.context.excel_path
        output_path.parent.mkdir(parents=True, exist_ok=True)

        self._workbook = xlsxwriter.Workbook(str(output_path))
        try:
            self._create_formats()

            if self.context.table_of_contents:
                self._render_toc()

            for section in self.context.sections:
                if section.section_type == "table":
                    self._render_table(section)

        finally:
            self._workbook.close()
            self._workbook = None

        return output_path

    def _create_formats(self) -> None:
        """Create xlsxwriter Format objects for styling."""
        if not self._workbook:
            return

        # Header format
        self._formats["header"] = self._workbook.add_format(
            {
                "bold": True,
                "align": "center",
                "valign": "vcenter",
                "font_name": "Calibri",
                "font_size": 11,
                "top": 1,
                "bottom": 1,
                "bg_color": "#FFFFFF",
            }
        )

        # Data format (center)
        self._formats["data"] = self._workbook.add_format(
            {
                "align": "center",
                "valign": "vcenter",
                "font_name": "Calibri",
                "font_size": 11,
            }
        )

        # Data format (left)
        self._formats["data_left"] = self._workbook.add_format(
            {
                "align": "left",
                "valign": "vcenter",
                "font_name": "Calibri",
                "font_size": 11,
            }
        )

        # Title format
        self._formats["title"] = self._workbook.add_format(
            {
                "bold": True,
                "align": "left",
                "valign": "vcenter",
                "font_name": "Calibri",
                "font_size": 11,
                "bottom": 1,
            }
        )

        # Footer/footnote format
        self._formats["footer"] = self._workbook.add_format(
            {
                "align": "left",
                "valign": "top",
                "font_name": "Calibri",
                "font_size": 10,
                "top": 1,
                "text_wrap": True,
            }
        )

        # Highlight format (small cells)
        self._formats["highlight"] = self._workbook.add_format(
            {
                "align": "center",
                "valign": "vcenter",
                "font_name": "Calibri",
                "font_size": 11,
                "bg_color": "#FFFF00",
            }
        )

        # Number formats
        self._formats["count"] = self._workbook.add_format(
            {
                "align": "center",
                "num_format": "#,##0",
            }
        )
        self._formats["rate"] = self._workbook.add_format(
            {
                "align": "center",
                "num_format": "#,##0.00",
            }
        )
        self._formats["percent"] = self._workbook.add_format(
            {
                "align": "center",
                "num_format": "0.0%",
            }
        )

    def _render_toc(self) -> None:
        """Render Table of Contents sheet."""
        if not self._workbook:
            return

        sheet = self._workbook.add_worksheet("Table of Contents")
        sheet.set_tab_color("#FFA500")  # Orange

        # Write header
        sheet.write(0, 0, "Table Number", self._formats["header"])
        sheet.write(0, 1, "Caption", self._formats["header"])

        # Set column widths
        sheet.set_column(0, 0, 15)  # Table number
        sheet.set_column(1, 1, 80)  # Caption

        # Write table entries
        row = 1
        for i, section in enumerate(self.context.sections, start=1):
            if section.section_type == "table":
                sheet.write(row, 0, f"Table {i}", self._formats["data"])
                sheet.write(row, 1, section.spec.title, self._formats["data_left"])
                row += 1

    def _render_table(self, section: ReportSection) -> None:
        """Render a data table to a worksheet.

        Args:
            section: ReportSection containing table spec and data
        """
        if not self._workbook:
            return

        spec = section.spec
        data: pl.DataFrame = section.data

        sheet = self._workbook.add_worksheet(spec.sheet_name[:31])  # Max 31 chars
        sheet.set_tab_color(spec.tab_color)
        sheet.hide_gridlines(2)  # Hide all gridlines

        # Get columns to include
        columns = [c for c in spec.columns if c.include_in_report]
        columns.sort(key=lambda c: c.order)

        # Write title
        title_text = f"{spec.sheet_name}. {spec.title}"
        sheet.merge_range(0, 0, 0, len(columns) - 1, title_text, self._formats["title"])

        # Write headers
        header_row = 2
        for col_idx, col in enumerate(columns):
            sheet.write(header_row, col_idx, col.label, self._formats["header"])
            # Set column width (convert inches to Excel units ~8.43 per inch)
            sheet.set_column(col_idx, col_idx, col.width * 8.43)

        # Write data rows
        data_start_row = header_row + 1
        for row_idx, row in enumerate(data.iter_rows(named=True)):
            excel_row = data_start_row + row_idx
            for col_idx, col in enumerate(columns):
                value = row.get(col.name)
                formatted = apply_format(value, col.format) if col.format else str(value or "")

                # Select format based on alignment
                fmt = (
                    self._formats["data_left"]
                    if col.alignment == Alignment.LEFT
                    else self._formats["data"]
                )

                sheet.write(excel_row, col_idx, formatted, fmt)

        # Write footnotes
        if spec.footnotes:
            footnote_row = data_start_row + len(data)
            footnote_text = "\n".join(
                f"{i+1}. {fn}" for i, fn in enumerate(spec.footnotes)
            )
            sheet.merge_range(
                footnote_row,
                0,
                footnote_row + len(spec.footnotes),
                len(columns) - 1,
                footnote_text,
                self._formats["footer"],
            )
