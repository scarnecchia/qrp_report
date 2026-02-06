"""Rendering types for QRP Report output.

Defines specifications for tables, columns, and styling
that drive Excel and PDF output generation.
"""

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Optional


class Alignment(Enum):
    """Text alignment options."""

    LEFT = "left"
    CENTER = "center"
    RIGHT = "right"


class Orientation(Enum):
    """Page orientation for PDF output."""

    PORTRAIT = "portrait"
    LANDSCAPE = "landscape"


@dataclass(frozen=True)
class CellStyle:
    """Style specification for a table cell.

    Attributes:
        font_name: Font family (default "Calibri")
        font_size: Font size in points
        bold: Bold text
        italic: Italic text
        alignment: Text alignment
        background_color: Hex color string (e.g., "#FFFFFF")
        text_color: Hex color string
        border_top: Border on top edge
        border_bottom: Border on bottom edge
        number_format: Excel/PDF number format string
    """

    font_name: str = "Calibri"
    font_size: int = 11
    bold: bool = False
    italic: bool = False
    alignment: Alignment = Alignment.CENTER
    background_color: str = "#FFFFFF"
    text_color: str = "#000000"
    border_top: bool = False
    border_bottom: bool = False
    number_format: Optional[str] = None


# Pre-defined styles matching SAS qrp_report_excel/qrp_report_pdf
STYLE_HEADER = CellStyle(
    bold=True,
    alignment=Alignment.CENTER,
    border_top=True,
    border_bottom=True,
)

STYLE_DATA = CellStyle(
    alignment=Alignment.CENTER,
)

STYLE_DATA_LEFT = CellStyle(
    alignment=Alignment.LEFT,
)

STYLE_TITLE = CellStyle(
    bold=True,
    alignment=Alignment.LEFT,
    border_bottom=True,
)

STYLE_FOOTER = CellStyle(
    font_size=10,
    alignment=Alignment.LEFT,
    border_top=True,
)

STYLE_HIGHLIGHT = CellStyle(
    background_color="#FFFF00",  # Yellow for small cells
    alignment=Alignment.CENTER,
)


@dataclass
class ColumnSpec:
    """Specification for a table column.

    Attributes:
        name: Internal column name (from data)
        label: Display label for header
        width: Column width in inches
        format: Format string (e.g., "comma14.0", "percent8.1")
        alignment: Column alignment
        ci_type: CI calculation type ("N"=none, "P"=proportion, "R"=rate)
        include_in_report: Whether to display this column
        order: Sort order for column positioning
        footnote: Footnote number to display (if any)
        small_cell_highlight: Whether to highlight small cells
    """

    name: str
    label: str
    width: float = 1.0
    format: str = ""
    alignment: Alignment = Alignment.CENTER
    ci_type: str = "N"
    include_in_report: bool = True
    order: int = 0
    footnote: Optional[int] = None
    small_cell_highlight: bool = False


@dataclass
class TableSpec:
    """Specification for a report table.

    Attributes:
        table_id: Unique table identifier (e.g., "t1cida", "t2l1")
        title: Table title
        columns: List of column specifications
        footnotes: List of footnote texts
        orientation: Page orientation (portrait/landscape)
        sheet_name: Excel sheet name
        tab_color: Excel tab color (hex)
    """

    table_id: str
    title: str
    columns: list[ColumnSpec] = field(default_factory=list)
    footnotes: list[str] = field(default_factory=list)
    orientation: Orientation = Orientation.PORTRAIT
    sheet_name: str = ""
    tab_color: str = "#00FF00"  # Green default

    def __post_init__(self) -> None:
        if not self.sheet_name:
            self.sheet_name = f"Table {self.table_id}"


@dataclass
class ReportSection:
    """A section of a report (table or figure).

    Attributes:
        section_type: "table" or "figure"
        spec: TableSpec or FigureSpec
        data: polars DataFrame or figure data
    """

    section_type: str
    spec: TableSpec
    data: Any  # polars.DataFrame or matplotlib Figure


@dataclass
class RenderContext:
    """Context for rendering a complete report.

    Attributes:
        report_id: Unique report identifier
        output_dir: Output directory path
        title: Report title
        sections: List of report sections
        table_of_contents: Whether to generate TOC
        stratify_by_dp: Whether to stratify by data partner
    """

    report_id: str
    output_dir: Path
    title: str = "QRP Report"
    sections: list[ReportSection] = field(default_factory=list)
    table_of_contents: bool = True
    stratify_by_dp: bool = False

    @property
    def excel_path(self) -> Path:
        """Path to Excel output file."""
        return self.output_dir / f"qrp_report{self.report_id}.xlsx"

    @property
    def pdf_path(self) -> Path:
        """Path to PDF output file."""
        return self.output_dir / f"qrp_report{self.report_id}.pdf"
