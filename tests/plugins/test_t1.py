"""Tests for T1 report plugin."""

import pytest
import polars as pl
from pathlib import Path
from unittest.mock import patch, MagicMock

from qrp_report.plugins.types import (
    ReportContext,
    DataPartnerInfo,
    StratificationConfig,
)
from qrp_report.plugins.t1 import T1Plugin, T1_CIDA_SUM_COLS
from qrp_report.plugins.registry import get_plugin, clear_registry


@pytest.fixture
def sample_t1_cida_data() -> pl.DataFrame:
    """Create sample T1 CIDA data for testing."""
    return pl.DataFrame({
        "group": ["treatment", "treatment", "control", "control"],
        "level": [1, 1, 1, 1],
        "npts": [100, 150, 120, 180],
        "episodes": [10, 15, 8, 12],
        "adjustedcodecount": [10, 15, 8, 12],
        "rawcodecount": [12, 18, 10, 15],
        "daysupp": [1000, 1500, 900, 1400],
        "amtsupp": [5000.0, 7500.0, 4500.0, 7000.0],
        "dennumpts": [100, 150, 120, 180],
        "dennummemdays": [36525, 54787, 43830, 65745],  # ~100, 150, 120, 180 person-years
        "timetocensor": [90, 100, 85, 95],
        "sex": ["M", "F", "M", "F"],
    })


@pytest.fixture
def sample_context(tmp_path: Path) -> ReportContext:
    """Create sample report context for testing."""
    dp1_path = tmp_path / "dp1"
    dp1_path.mkdir()

    return ReportContext(
        report_type="T1",
        run_id="run01",
        groups=("treatment", "control"),
        data_partners=(
            DataPartnerInfo(
                dp_id="site1",
                masked_id="DP01",
                data_path=dp1_path,
            ),
        ),
        stratification=None,
        output_dir=tmp_path / "output",
    )


class TestT1PluginRegistration:
    """Tests for T1 plugin registration."""

    def test_plugin_is_registered(self):
        """T1 plugin should be registered."""
        plugin_cls = get_plugin("T1")
        assert plugin_cls is T1Plugin

    def test_plugin_report_type(self):
        """Plugin should report correct type."""
        plugin = T1Plugin()
        assert plugin.report_type == "T1"

    def test_plugin_required_datasets(self):
        """Plugin should list required datasets."""
        plugin = T1Plugin()
        assert "t1_cida" in plugin.required_datasets


class TestT1PluginValidation:
    """Tests for T1 plugin context validation."""

    def test_validates_report_type(self, sample_context: ReportContext):
        """Should reject non-T1 report types."""
        plugin = T1Plugin()

        # Create context with wrong type
        wrong_context = ReportContext(
            report_type="T2L1",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
        )

        errors = plugin.validate_context(wrong_context)
        assert len(errors) > 0
        assert "T1" in errors[0]

    def test_validates_groups_present(self, sample_context: ReportContext):
        """Should require at least one group."""
        plugin = T1Plugin()

        empty_groups_context = ReportContext(
            report_type="T1",
            run_id=sample_context.run_id,
            groups=(),
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
        )

        errors = plugin.validate_context(empty_groups_context)
        assert len(errors) > 0
        assert "group" in errors[0].lower()

    def test_validates_data_partners_present(self, sample_context: ReportContext):
        """Should require at least one data partner."""
        plugin = T1Plugin()

        no_dp_context = ReportContext(
            report_type="T1",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=(),
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
        )

        errors = plugin.validate_context(no_dp_context)
        assert len(errors) > 0
        assert "data partner" in errors[0].lower()

    def test_valid_context_passes(self, sample_context: ReportContext):
        """Valid context should pass validation."""
        plugin = T1Plugin()
        errors = plugin.validate_context(sample_context)
        assert len(errors) == 0


class TestT1PluginRateComputation:
    """Tests for T1 rate and CI computation."""

    def test_computes_incidence_rate(self, sample_t1_cida_data: pl.DataFrame):
        """Should compute incidence rate per 1000 person-years."""
        plugin = T1Plugin()
        result = plugin._compute_t1_rates(sample_t1_cida_data)

        assert "rate_1000py" in result.columns
        assert "rate_ci_lower" in result.columns
        assert "rate_ci_upper" in result.columns

        # Check first row: 10 episodes / 100 person-years * 1000 = 100
        rates = result.select("rate_1000py").to_series().to_list()
        assert rates[0] == pytest.approx(100.0, rel=0.01)

    def test_computes_risk_per_1000(self, sample_t1_cida_data: pl.DataFrame):
        """Should compute risk per 1000 new users."""
        plugin = T1Plugin()
        result = plugin._compute_t1_rates(sample_t1_cida_data)

        assert "risk_1000nu" in result.columns
        assert "risk_ci_lower" in result.columns
        assert "risk_ci_upper" in result.columns

        # Check first row: 10 episodes / 100 npts * 1000 = 100
        risks = result.select("risk_1000nu").to_series().to_list()
        assert risks[0] == pytest.approx(100.0, rel=0.01)

    def test_handles_zero_denominator(self):
        """Should handle zero person-years gracefully."""
        plugin = T1Plugin()

        df = pl.DataFrame({
            "npts": [0],
            "episodes": [0],
            "dennummemdays": [0],
        })

        result = plugin._compute_t1_rates(df)

        # Should be null, not error
        assert result.select("rate_1000py").to_series().to_list()[0] is None
        assert result.select("risk_1000nu").to_series().to_list()[0] is None

    def test_ci_bounds_correct_order(self, sample_t1_cida_data: pl.DataFrame):
        """CI lower should be less than CI upper."""
        plugin = T1Plugin()
        result = plugin._compute_t1_rates(sample_t1_cida_data)

        for row in result.iter_rows(named=True):
            if row["rate_ci_lower"] is not None and row["rate_ci_upper"] is not None:
                assert row["rate_ci_lower"] < row["rate_ci_upper"]
            if row["risk_ci_lower"] is not None and row["risk_ci_upper"] is not None:
                assert row["risk_ci_lower"] < row["risk_ci_upper"]


class TestT1PluginExecution:
    """Integration tests for T1 plugin execution."""

    def test_execute_returns_result(
        self,
        sample_context: ReportContext,
        sample_t1_cida_data: pl.DataFrame,
    ):
        """Execute should return ReportResult."""
        plugin = T1Plugin()

        # Mock the aggregate_datasets function
        with patch("qrp_report.plugins.t1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t1_cida_data

            result = plugin.execute(sample_context)

        assert result.report_type == "T1"
        assert len(result.tables) >= 1
        assert result.tables[0].table_id == "t1_main"

    def test_execute_with_stratification(
        self,
        sample_context: ReportContext,
        sample_t1_cida_data: pl.DataFrame,
    ):
        """Execute should handle stratification."""
        context_with_strat = ReportContext(
            report_type="T1",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=sample_context.data_partners,
            stratification=StratificationConfig(variables=("sex",)),
            output_dir=sample_context.output_dir,
        )

        plugin = T1Plugin()

        with patch("qrp_report.plugins.t1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t1_cida_data

            result = plugin.execute(context_with_strat)

        assert result.tables[0].stratification == "sex"

    def test_execute_handles_missing_data(self, sample_context: ReportContext):
        """Execute should handle missing dataset gracefully."""
        plugin = T1Plugin()

        with patch("qrp_report.plugins.t1.aggregate_datasets") as mock_agg:
            mock_agg.side_effect = ValueError("No data found")

            result = plugin.execute(sample_context)

        assert len(result.tables) == 0
        assert len(result.warnings) > 0
