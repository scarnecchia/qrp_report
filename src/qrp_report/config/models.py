"""Pydantic models for QRP Report configuration."""

from enum import Enum
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class ReportType(str, Enum):
    """Supported report types."""

    T1 = "T1"
    T2L1 = "T2L1"
    T2L2 = "T2L2"
    T3 = "T3"
    T4L1 = "T4L1"
    T4L2 = "T4L2"
    T5 = "T5"
    T6 = "T6"


class ReportDestination(str, Enum):
    """Output format options."""

    EXCEL = "EXCEL"
    PDF = "PDF"
    BOTH = "BOTH"


class PSMethod(str, Enum):
    """Propensity score methods."""

    MATCHING = "matching"
    STRATIFICATION = "stratification"
    IPTW = "iptw"


class DPInfo(BaseModel):
    """Data Partner information."""

    dp: str = Field(description="Data Partner ID")
    dpname: str = Field(description="Data Partner display name")
    path: Path = Field(description="Path to DP data files")
    database: str = Field(default="", description="Database label")
    includedp: bool = Field(default=True, description="Include in report")

    @field_validator("dp", "dpname", mode="before")
    @classmethod
    def normalize_string(cls, v: str) -> str:
        """Strip whitespace from string fields."""
        return v.strip() if isinstance(v, str) else v


class GroupConfig(BaseModel):
    """Analysis group configuration."""

    runid: str = Field(description="Query run identifier")
    group: str = Field(description="Group name")
    order: int = Field(description="Display order")
    includeinfigure: bool = Field(default=False, description="Include in figures")
    codedist: str | None = Field(default=None, description="Code distribution module")
    topncodedist: int = Field(default=10, description="Top N codes to show")

    @field_validator("runid", "group", mode="before")
    @classmethod
    def normalize_to_lowercase(cls, v: str) -> str:
        """Convert identifiers to lowercase."""
        return v.lower().strip() if isinstance(v, str) else v


class BaselineConfig(BaseModel):
    """Baseline/Table 1 configuration."""

    runid: str = Field(description="Query run identifier")
    group: str = Field(description="Cohort/analysis group")
    order: int = Field(description="Table order/number")
    baseline: bool = Field(default=False, description="Is baseline group")
    baselinegroupnum: int | None = Field(default=None, description="Sub-group number (1-2)")
    labcharacteristics: list[str] = Field(default_factory=list, description="Lab covariates")
    covinps: list[str] = Field(default_factory=list, description="Covariates in PS (L2 only)")

    @field_validator("runid", "group", mode="before")
    @classmethod
    def normalize_to_lowercase(cls, v: str) -> str:
        """Convert identifiers to lowercase."""
        return v.lower().strip() if isinstance(v, str) else v

    @field_validator("labcharacteristics", "covinps", mode="before")
    @classmethod
    def parse_space_separated(cls, v: str | list[str]) -> list[str]:
        """Parse space-separated string into list."""
        if isinstance(v, str):
            return v.split() if v.strip() else []
        return v


class TableConfig(BaseModel):
    """Table specification."""

    table: str = Field(description="Table identifier (e.g., T1A)")
    tablesub: str = Field(default="overall", description="Table sub-stratification")
    tablesubstrat: str | None = Field(default=None, description="Substrata specification")
    dataset: str = Field(description="Source dataset")
    levelid1: str = Field(default="", description="Stratification level 1")
    levelid2: str = Field(default="", description="Stratification level 2")
    levelid3: str = Field(default="", description="Stratification level 3")
    categories: str = Field(default="N%", description="Column categories")
    includeinreport: bool = Field(default=True, description="Include in report")
    censorreason: list[str] = Field(default_factory=list, description="Censoring reasons")

    @field_validator("levelid1", "levelid2", "levelid3", mode="before")
    @classmethod
    def normalize_levelid(cls, v: str) -> str:
        """Normalize levelid (convert 'overall' to empty)."""
        if isinstance(v, str):
            v = v.strip().lower()
            return "" if v == "overall" else v
        return v or ""


class FigureConfig(BaseModel):
    """Figure specification."""

    figure: str = Field(description="Figure identifier (e.g., F1)")
    figuresub: str = Field(default="overall", description="Sub-stratification")
    dataset: str = Field(description="Source dataset")
    levelid1: str = Field(default="", description="Stratification level 1")
    levelid2: str = Field(default="", description="Stratification level 2")
    levelid3: str = Field(default="", description="Stratification level 3")
    xmin: float | None = Field(default=None, description="X-axis minimum")
    xmax: float | None = Field(default=None, description="X-axis maximum")
    xtick: float | None = Field(default=None, description="X-axis tick interval")
    ymin: float | None = Field(default=None, description="Y-axis minimum")
    ymax: float | None = Field(default=None, description="Y-axis maximum")
    ytick: float | None = Field(default=None, description="Y-axis tick interval")
    censordisplay: str | None = Field(default=None, description="Censor reason to show")
    includeatrisktable: bool = Field(default=True, description="Show at-risk table")


class LabelConfig(BaseModel):
    """Custom label configuration."""

    labeltype: Literal["censorlabel", "grouplabel"] = Field(description="Type of label")
    labelvar: str = Field(description="Variable being labeled")
    label: str = Field(description="Label text")


class L2ComparisonConfig(BaseModel):
    """L2 analysis comparison configuration."""

    runid: str = Field(description="Query run identifier")
    analysisgrp: str = Field(description="Analysis group for comparison")
    order: int = Field(description="Display order")
    psmethod: PSMethod = Field(description="Propensity score method")
    outputconditional: bool = Field(default=True, description="Output conditional")

    @field_validator("runid", "analysisgrp", mode="before")
    @classmethod
    def normalize_to_lowercase(cls, v: str) -> str:
        """Convert identifiers to lowercase."""
        return v.lower().strip() if isinstance(v, str) else v


class ReportConfig(BaseModel):
    """Master report configuration.

    This is the top-level configuration that references all other config files.
    Mirrors the SAS report_parameters dataset structure.
    """

    # Required identifiers
    reportid: str = Field(description="Unique report identifier")
    reporttype: ReportType = Field(description="Report type")

    # File references (paths to config files or inline data)
    dpinfo: list[DPInfo] = Field(default_factory=list, description="Data Partner info")
    groups: list[GroupConfig] = Field(default_factory=list, description="Analysis groups")
    baseline: list[BaselineConfig] = Field(default_factory=list, description="Baseline config")
    tables: list[TableConfig] = Field(default_factory=list, description="Table specifications")
    figures: list[FigureConfig] = Field(default_factory=list, description="Figure specifications")
    labels: list[LabelConfig] = Field(default_factory=list, description="Custom labels")
    l2comparisons: list[L2ComparisonConfig] = Field(
        default_factory=list, description="L2 comparisons"
    )

    # Report options
    stratifybydp: bool = Field(default=False, description="Include DP-stratified tables")
    small_cellcounts: int | None = Field(default=None, description="Cell suppression threshold")
    report_destination: ReportDestination = Field(
        default=ReportDestination.BOTH, description="Output format"
    )
    collapse_vars: list[str] = Field(default_factory=list, description="Variables to collapse")
    include_unweighted_trim: bool = Field(default=False, description="Include unweighted trim")
    look_start: int = Field(default=1, description="Sequential analysis start")
    look_end: int = Field(default=1, description="Sequential analysis end")
    datedistributed: str | None = Field(default=None, description="Report distribution date")
    seed: int | None = Field(default=None, description="Random seed for DP masking")
    database: str | None = Field(default=None, description="Database name/label")
    logofile: Path | None = Field(default=None, description="Report logo file")

    @field_validator("reportid", mode="before")
    @classmethod
    def normalize_reportid(cls, v: str) -> str:
        """Strip whitespace from reportid."""
        return v.strip() if isinstance(v, str) else v

    @field_validator("collapse_vars", mode="before")
    @classmethod
    def parse_collapse_vars(cls, v: str | list[str]) -> list[str]:
        """Parse space-separated string into list."""
        if isinstance(v, str):
            return v.split() if v.strip() else []
        return v

    @property
    def is_l2_report(self) -> bool:
        """Check if this is an L2 (Level 2) report type."""
        return self.reporttype in (ReportType.T2L2, ReportType.T4L2)

    @property
    def is_l1_report(self) -> bool:
        """Check if this is an L1 (Level 1) report type."""
        return self.reporttype in (
            ReportType.T1,
            ReportType.T2L1,
            ReportType.T4L1,
            ReportType.T5,
            ReportType.T6,
        )
