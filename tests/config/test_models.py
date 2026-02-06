"""Tests for Pydantic configuration models."""

import pytest
from pydantic import ValidationError

from qrp_report.config.models import (
    BaselineConfig,
    DPInfo,
    FigureConfig,
    GroupConfig,
    L2ComparisonConfig,
    LabelConfig,
    PSMethod,
    ReportConfig,
    ReportDestination,
    ReportType,
    TableConfig,
)


class TestDPInfo:
    """Tests for DPInfo model."""

    def test_valid_dpinfo(self) -> None:
        """Test creating valid DPInfo."""
        dp = DPInfo(
            dp="sentinel_dp01",
            dpname="Sentinel DP #1",
            path="/path/to/data",
        )
        assert dp.dp == "sentinel_dp01"
        assert dp.includedp is True  # default

    def test_whitespace_stripped(self) -> None:
        """Test that whitespace is stripped from string fields."""
        dp = DPInfo(
            dp="  dp01  ",
            dpname="  Name  ",
            path="/path",
        )
        assert dp.dp == "dp01"
        assert dp.dpname == "Name"


class TestGroupConfig:
    """Tests for GroupConfig model."""

    def test_lowercase_normalization(self) -> None:
        """Test that runid and group are lowercased."""
        group = GroupConfig(
            runid="RUN01",
            group="EXPOSURE_YES",
            order=1,
        )
        assert group.runid == "run01"
        assert group.group == "exposure_yes"

    def test_defaults(self) -> None:
        """Test default values."""
        group = GroupConfig(runid="run01", group="group1", order=1)
        assert group.includeinfigure is False
        assert group.topncodedist == 10


class TestBaselineConfig:
    """Tests for BaselineConfig model."""

    def test_space_separated_parsing(self) -> None:
        """Test that space-separated strings are parsed to lists."""
        baseline = BaselineConfig(
            runid="run01",
            group="group1",
            order=1,
            labcharacteristics="ALT AST BMI",
            covinps="age sex race",
        )
        assert baseline.labcharacteristics == ["ALT", "AST", "BMI"]
        assert baseline.covinps == ["age", "sex", "race"]

    def test_empty_string_to_empty_list(self) -> None:
        """Test that empty strings become empty lists."""
        baseline = BaselineConfig(
            runid="run01",
            group="group1",
            order=1,
            labcharacteristics="",
        )
        assert baseline.labcharacteristics == []


class TestTableConfig:
    """Tests for TableConfig model."""

    def test_levelid_overall_normalized(self) -> None:
        """Test that 'overall' levelid is converted to empty string."""
        table = TableConfig(
            table="T1A",
            dataset="t1cida",
            levelid1="overall",
            levelid2="OVERALL",
        )
        assert table.levelid1 == ""
        assert table.levelid2 == ""

    def test_defaults(self) -> None:
        """Test default values."""
        table = TableConfig(table="T1A", dataset="t1cida")
        assert table.tablesub == "overall"
        assert table.categories == "N%"
        assert table.includeinreport is True


class TestFigureConfig:
    """Tests for FigureConfig model."""

    def test_axis_params_optional(self) -> None:
        """Test that axis parameters are optional."""
        figure = FigureConfig(figure="F1", dataset="t1cida")
        assert figure.xmin is None
        assert figure.xmax is None
        assert figure.includeatrisktable is True


class TestLabelConfig:
    """Tests for LabelConfig model."""

    def test_valid_label_types(self) -> None:
        """Test valid label types."""
        censor_label = LabelConfig(
            labeltype="censorlabel",
            labelvar="cens_spec",
            label="User-Defined Censoring",
        )
        assert censor_label.labeltype == "censorlabel"

        group_label = LabelConfig(
            labeltype="grouplabel",
            labelvar="group1",
            label="Treatment Group",
        )
        assert group_label.labeltype == "grouplabel"

    def test_invalid_label_type_rejected(self) -> None:
        """Test that invalid label types are rejected."""
        with pytest.raises(ValidationError):
            LabelConfig(
                labeltype="invalid",  # type: ignore[arg-type]
                labelvar="var",
                label="Label",
            )


class TestL2ComparisonConfig:
    """Tests for L2ComparisonConfig model."""

    def test_psmethod_enum(self) -> None:
        """Test PSMethod enum values."""
        config = L2ComparisonConfig(
            runid="run01",
            analysisgrp="matching_grp",
            order=1,
            psmethod=PSMethod.MATCHING,
        )
        assert config.psmethod == PSMethod.MATCHING

    def test_outputconditional_default(self) -> None:
        """Test outputconditional defaults to True."""
        config = L2ComparisonConfig(
            runid="run01",
            analysisgrp="grp",
            order=1,
            psmethod=PSMethod.IPTW,
        )
        assert config.outputconditional is True


class TestReportConfig:
    """Tests for ReportConfig model."""

    def test_minimal_config(self) -> None:
        """Test creating minimal valid config."""
        config = ReportConfig(
            reportid="test_report",
            reporttype=ReportType.T1,
        )
        assert config.reportid == "test_report"
        assert config.reporttype == ReportType.T1
        assert config.stratifybydp is False
        assert config.report_destination == ReportDestination.BOTH

    def test_is_l2_report(self) -> None:
        """Test is_l2_report property."""
        l2_config = ReportConfig(reportid="test", reporttype=ReportType.T2L2)
        assert l2_config.is_l2_report is True
        assert l2_config.is_l1_report is False

        l1_config = ReportConfig(reportid="test", reporttype=ReportType.T2L1)
        assert l1_config.is_l2_report is False
        assert l1_config.is_l1_report is True

    def test_collapse_vars_parsing(self) -> None:
        """Test collapse_vars space-separated parsing."""
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T1,
            collapse_vars="var1 var2 var3",  # type: ignore[arg-type]
        )
        assert config.collapse_vars == ["var1", "var2", "var3"]

    def test_full_config_with_nested(self) -> None:
        """Test config with nested configuration objects."""
        config = ReportConfig(
            reportid="full_test",
            reporttype=ReportType.T2L1,
            dpinfo=[
                DPInfo(dp="dp01", dpname="DP 1", path="/path/dp01"),
                DPInfo(dp="dp02", dpname="DP 2", path="/path/dp02", includedp=False),
            ],
            groups=[
                GroupConfig(runid="run01", group="exp", order=1, includeinfigure=True),
            ],
            stratifybydp=True,
            report_destination=ReportDestination.EXCEL,
        )
        assert len(config.dpinfo) == 2
        assert config.dpinfo[0].includedp is True
        assert config.dpinfo[1].includedp is False
        assert len(config.groups) == 1
