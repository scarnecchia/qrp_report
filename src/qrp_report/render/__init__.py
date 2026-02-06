"""QRP Report rendering module.

Provides output rendering for Excel and PDF reports:
- Excel workbooks with multiple sheets and styling
- PDF reports with tables, figures, and TOC
- Consistent formatting across output types
"""

from qrp_report.render.types import (
    Alignment,
    Orientation,
    CellStyle,
    ColumnSpec,
    TableSpec,
    ReportSection,
    RenderContext,
    STYLE_HEADER,
    STYLE_DATA,
    STYLE_DATA_LEFT,
    STYLE_TITLE,
    STYLE_FOOTER,
    STYLE_HIGHLIGHT,
)
from qrp_report.render.formatters import (
    format_count,
    format_percent,
    format_rate,
    format_ci,
    format_rate_with_ci,
    format_effect_estimate,
    format_pvalue,
    format_days,
    format_person_years,
    apply_format,
)
from qrp_report.render.excel import ExcelRenderer
from qrp_report.render.pdf import PDFRenderer

__all__ = [
    # Types
    "Alignment",
    "Orientation",
    "CellStyle",
    "ColumnSpec",
    "TableSpec",
    "ReportSection",
    "RenderContext",
    # Pre-defined styles
    "STYLE_HEADER",
    "STYLE_DATA",
    "STYLE_DATA_LEFT",
    "STYLE_TITLE",
    "STYLE_FOOTER",
    "STYLE_HIGHLIGHT",
    # Formatters
    "format_count",
    "format_percent",
    "format_rate",
    "format_ci",
    "format_rate_with_ci",
    "format_effect_estimate",
    "format_pvalue",
    "format_days",
    "format_person_years",
    "apply_format",
    # Renderers
    "ExcelRenderer",
    "PDFRenderer",
]
