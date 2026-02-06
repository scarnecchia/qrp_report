"""Tests for configuration validation."""

import pytest

from qrp_report.config.errors import ErrorSeverity
from qrp_report.config.models import (
    BaselineConfig,
    DPInfo,
    FigureConfig,
    GroupConfig,
    ReportConfig,
    ReportType,
)
from qrp_report.config.validation import validate_config


@pytest.fixture
def valid_config() -> ReportConfig:
    """Create valid minimal configuration."""
    return ReportConfig(
        reportid="test",
        reporttype=ReportType.T1,
        dpinfo=[DPInfo(dp="dp01", dpname="DP 1", path="/data/dp01", includedp=True)],
    )


class TestDPInfoValidation:
    """Tests for Data Partner validation rules."""

    def test_e002_dpinfo_missing(self) -> None:
        """Test E002: dpinfo required."""
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T1,
            dpinfo=[],
        )
        errors = validate_config(config)

        error_codes = [e.code for e in errors]
        assert "E002" in error_codes

    def test_e003_no_dp_included(self) -> None:
        """Test E003: at least one DP must be included."""
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T1,
            dpinfo=[
                DPInfo(dp="dp01", dpname="DP 1", path="/data", includedp=False),
                DPInfo(dp="dp02", dpname="DP 2", path="/data", includedp=False),
            ],
        )
        errors = validate_config(config)

        error_codes = [e.code for e in errors]
        assert "E003" in error_codes


class TestBaselineValidation:
    """Tests for baseline configuration validation."""

    def test_e040_order_across_runids(self, valid_config: ReportConfig) -> None:
        """Test E040: ORDER cannot repeat across different RUNIDs."""
        valid_config.baseline = [
            BaselineConfig(runid="run01", group="g1", order=1),
            BaselineConfig(runid="run02", group="g2", order=1),  # Same ORDER, different RUNID
        ]
        errors = validate_config(valid_config)

        error_codes = [e.code for e in errors]
        assert "E040" in error_codes

    def test_e041_order_repeats_without_groupnum(self, valid_config: ReportConfig) -> None:
        """Test E041: ORDER repeats require BASELINEGROUPNUM."""
        valid_config.baseline = [
            BaselineConfig(runid="run01", group="g1", order=1),
            BaselineConfig(runid="run01", group="g2", order=1),  # Repeat without groupnum
        ]
        errors = validate_config(valid_config)

        error_codes = [e.code for e in errors]
        assert "E041" in error_codes

    def test_e042_too_many_per_order(self, valid_config: ReportConfig) -> None:
        """Test E042: Maximum 2 rows per ORDER value."""
        valid_config.baseline = [
            BaselineConfig(runid="run01", group="g1", order=1, baselinegroupnum=1),
            BaselineConfig(runid="run01", group="g2", order=1, baselinegroupnum=2),
            BaselineConfig(runid="run01", group="g3", order=1, baselinegroupnum=1),  # Third row
        ]
        errors = validate_config(valid_config)

        error_codes = [e.code for e in errors]
        assert "E042" in error_codes

    def test_valid_baseline_with_groupnum(self, valid_config: ReportConfig) -> None:
        """Test valid baseline with BASELINEGROUPNUM."""
        valid_config.baseline = [
            BaselineConfig(runid="run01", group="g1", order=1, baselinegroupnum=1),
            BaselineConfig(runid="run01", group="g2", order=1, baselinegroupnum=2),
        ]
        errors = validate_config(valid_config)

        error_codes = [e.code for e in errors]
        assert "E040" not in error_codes
        assert "E041" not in error_codes
        assert "E042" not in error_codes


class TestFigureValidation:
    """Tests for figure configuration validation."""

    def test_e033_figures_require_groups(self) -> None:
        """Test E033: Figures require groups for L1 reports."""
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T2L1,
            dpinfo=[DPInfo(dp="dp01", dpname="DP 1", path="/data", includedp=True)],
            figures=[FigureConfig(figure="F1", dataset="t2cida")],
            groups=[],  # Empty groups
        )
        errors = validate_config(config)

        error_codes = [e.code for e in errors]
        assert "E033" in error_codes

    def test_e032_no_groups_includeinfigure(self) -> None:
        """Test E032: At least one group must have includeinfigure=True."""
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T2L1,
            dpinfo=[DPInfo(dp="dp01", dpname="DP 1", path="/data", includedp=True)],
            figures=[FigureConfig(figure="F1", dataset="t2cida")],
            groups=[
                GroupConfig(runid="run01", group="g1", order=1, includeinfigure=False),
            ],
        )
        errors = validate_config(config)

        error_codes = [e.code for e in errors]
        assert "E032" in error_codes


class TestReportTypeSpecificValidation:
    """Tests for report-type-specific validation."""

    def test_w001_collapse_vars_l2(self) -> None:
        """Test W001: collapse_vars ignored for L2 reports."""
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T2L2,
            dpinfo=[DPInfo(dp="dp01", dpname="DP 1", path="/data", includedp=True)],
            collapse_vars=["var1", "var2"],
        )
        errors = validate_config(config)

        warnings = [e for e in errors if e.severity == ErrorSeverity.WARNING]
        warning_codes = [w.code for w in warnings]
        assert "W001" in warning_codes

    def test_w003_covinps_l1(self) -> None:
        """Test W003: covinps not relevant for L1 reports."""
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T2L1,
            dpinfo=[DPInfo(dp="dp01", dpname="DP 1", path="/data", includedp=True)],
            baseline=[
                BaselineConfig(runid="run01", group="g1", order=1, covinps=["age", "sex"]),
            ],
        )
        errors = validate_config(config)

        warnings = [e for e in errors if e.severity == ErrorSeverity.WARNING]
        warning_codes = [w.code for w in warnings]
        assert "W003" in warning_codes


class TestValidConfigFunction:
    """Tests for validate_config convenience function."""

    def test_valid_config_no_errors(self, valid_config: ReportConfig) -> None:
        """Test that valid config produces no errors."""
        errors = validate_config(valid_config)

        critical_errors = [e for e in errors if e.severity == ErrorSeverity.ERROR]
        assert len(critical_errors) == 0
