"""Validation error types for configuration."""

from dataclasses import dataclass
from enum import Enum


class ErrorSeverity(Enum):
    """Severity level for validation messages."""

    ERROR = "error"
    WARNING = "warning"


@dataclass(frozen=True)
class ValidationMessage:
    """A validation error or warning with context.

    Attributes:
        severity: ERROR or WARNING
        code: Error code (e.g., "E001", "W001")
        message: Human-readable error message
        location: File path or field location where error occurred
        suggestion: How to fix the error
    """

    severity: ErrorSeverity
    code: str
    message: str
    location: str | None = None
    suggestion: str | None = None

    def __str__(self) -> str:
        """Format as human-readable string."""
        parts = [f"[{self.code}] {self.message}"]
        if self.location:
            parts.append(f"  Location: {self.location}")
        if self.suggestion:
            parts.append(f"  Suggestion: {self.suggestion}")
        return "\n".join(parts)


# Error code registry - mirrors SAS %abort points
ERROR_CODES = {
    # File existence errors (E0xx)
    "E001": "REPORT_PARAMETERS file is missing",
    "E002": "DPINFOFILE is missing",
    "E003": "No Data Partners included (all have includedp=N)",
    "E004": "Invalid runid not found in qrp_parameters",
    # USERSTRATA errors (E01x)
    "E010": "Duplicate USERSTRATA tableid-levelid combinations",
    "E011": "Duplicate USERSTRATA tableid-levelvars combinations",
    "E012": "TABLEFILE specified but no USERSTRATA file",
    "E013": "FIGUREFILE specified but no USERSTRATA file",
    # Table errors (E02x)
    "E020": "Table levelid not found in USERSTRATA",
    "E021": "Overall table required for stratified table",
    "E022": "TableColumnsFile specified but does not exist",
    "E023": "Different labels for N and % columns in T1 table",
    "E024": "All TableColumnsFile rows set to N",
    "E025": "Lookup table dataset requires TableColumnsFile",
    # Figure errors (E03x)
    "E030": "Figure levelid not found in USERSTRATA",
    "E031": "Switch plots require switch analyses in GROUPSFILE",
    "E032": "No groups with INCLUDEINFIGURE=Y",
    "E033": "FIGUREFILE requires GROUPSFILE",
    # Baseline errors (E04x)
    "E040": "ORDER values cannot repeat across different RUNIDs",
    "E041": "ORDER repeats require BASELINEGROUPNUM parameter",
    "E042": "Maximum 2 rows per ORDER value for BASELINEGROUPNUM",
    # Other errors (E05x)
    "E050": "Covariate codes stratification mismatch",
}

WARNING_CODES = {
    "W001": "COLLAPSE_VARS ignored for L2 reports",
    "W002": "Code distribution disabled (DISTINDEX not Y)",
    "W003": "COVINPS not relevant for L1 reports",
    "W004": "Figure axis parameters ignored for T5",
    "W005": "Multiple censordisplay values for F8/F9 figures",
}
