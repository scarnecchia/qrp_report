"""Tests for T2L1 report plugin."""

import pytest
import polars as pl
from pathlib import Path
from unittest.mock import patch

from qrp_report.plugins.types import (
    ReportContext,
    DataPartnerInfo,
    StratificationConfig,
)
from qrp_report.plugins.t2l1 import T2L1Plugin, T2_CIDA_SUM_COLS
from qrp_report.plugins.registry import get_plugin


@pytest.fixture
def sample_t2_cida_data() -> pl.DataFrame:
    """Create sample T2 CIDA data for testing."""
    return pl.DataFrame({
        "group": ["treatment", "treatment", "control", "control"],
        "level": [1, 1, 1, 1],
        "npts": [100, 150, 120, 180],
        "episodes": [80, 120, 90, 140],
        "adjustedcodecount": [80, 120, 90, 140],
        "rawcodecount": [85, 125, 95, 145],
        "daysupp": [8000, 12000, 9000, 14000],
        "amtsupp": [40000.0, 60000.0, 45000.0, 70000.0],
        "dennumpts": [100, 150, 120, 180],
        "dennummemdays": [36525, 54787, 43830, 65745],
        "timetocensor": [90, 100, 85, 95],
        # T2-specific columns
        "eps_wevents": [10, 15, 8, 12],
        "all_events": [12, 18, 10, 15],
        "followuptime": [36000, 54000, 42000, 64000],
        "sex": ["M", "F", "M", "F"],
    })


@pytest.fixture
def sample_concomitant_data() -> pl.DataFrame:
    """Create sample concomitant medication data."""
    return pl.DataFrame({
        "analysisgrp": ["treatment", "treatment", "control", "control"],
        "level": [1, 1, 1, 1],
        "npts": [50, 75, 60, 90],
        "episodes": [40, 60, 45, 70],
    })


@pytest.fixture
def sample_context(tmp_path: Path) -> ReportContext:
    """Create sample report context for testing."""
    dp1_path = tmp_path / "dp1"
    dp1_path.mkdir()

    return ReportContext(
        report_type="T2L1",
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


class TestT2L1PluginRegistration:
    """Tests for T2L1 plugin registration."""

    def test_plugin_is_registered(self):
        """T2L1 plugin should be registered."""
        plugin_cls = get_plugin("T2L1")
        assert plugin_cls is T2L1Plugin

    def test_plugin_report_type(self):
        """Plugin should report correct type."""
        plugin = T2L1Plugin()
        assert plugin.report_type == "T2L1"

    def test_plugin_required_datasets(self):
        """Plugin should list required datasets."""
        plugin = T2L1Plugin()
        assert "t2_cida" in plugin.required_datasets


class TestT2L1PluginValidation:
    """Tests for T2L1 plugin context validation."""

    def test_validates_report_type(self, sample_context: ReportContext):
        """Should reject non-T2L1 report types."""
        plugin = T2L1Plugin()

        wrong_context = ReportContext(
            report_type="T1",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
        )

        errors = plugin.validate_context(wrong_context)
        assert len(errors) > 0
        assert "T2L1" in errors[0]

    def test_valid_context_passes(self, sample_context: ReportContext):
        """Valid context should pass validation."""
        plugin = T2L1Plugin()
        errors = plugin.validate_context(sample_context)
        assert len(errors) == 0


class TestT2L1RateComputation:
    """Tests for T2L1 rate computation."""

    def test_computes_event_rate(self, sample_t2_cida_data: pl.DataFrame):
        """Should compute event rate per 1000 person-years."""
        plugin = T2L1Plugin()
        result = plugin._compute_t2_rates(sample_t2_cida_data)

        assert "event_rate_1000py" in result.columns
        assert "event_rate_ci_lower" in result.columns
        assert "event_rate_ci_upper" in result.columns

    def test_computes_pct_episodes_with_events(self, sample_t2_cida_data: pl.DataFrame):
        """Should compute percentage of episodes with events."""
        plugin = T2L1Plugin()
        result = plugin._compute_t2_rates(sample_t2_cida_data)

        assert "pct_eps_wevents" in result.columns

        # Check first row: 10 / 80 * 100 = 12.5%
        pct = result.select("pct_eps_wevents").to_series().to_list()[0]
        assert pct == pytest.approx(12.5, rel=0.01)

    def test_inherits_t1_rates(self, sample_t2_cida_data: pl.DataFrame):
        """Should also compute T1-style rates."""
        plugin = T2L1Plugin()
        result = plugin._compute_t2_rates(sample_t2_cida_data)

        # T1 columns should exist
        assert "rate_1000py" in result.columns
        assert "risk_1000nu" in result.columns


class TestT2L1Execution:
    """Integration tests for T2L1 plugin execution."""

    def test_execute_returns_main_table(
        self,
        sample_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
    ):
        """Execute should return at least main T2 table."""
        plugin = T2L1Plugin()

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t2_cida_data

            result = plugin.execute(sample_context)

        assert result.report_type == "T2L1"
        assert len(result.tables) >= 1
        assert result.tables[0].table_id == "t2_main"

    def test_execute_creates_optional_tables(
        self,
        sample_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
        sample_concomitant_data: pl.DataFrame,
    ):
        """Execute should create optional tables when data available."""
        plugin = T2L1Plugin()

        def mock_aggregate(data_partners, run_id, dataset_name, filter_var, filter_values):
            if dataset_name == "t2_cida":
                return sample_t2_cida_data
            elif dataset_name == "t2_concomitance":
                return sample_concomitant_data
            else:
                raise ValueError(f"No data for {dataset_name}")

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_agg:
            mock_agg.side_effect = mock_aggregate

            result = plugin.execute(sample_context)

        table_ids = [t.table_id for t in result.tables]
        assert "t2_main" in table_ids
        assert "t2_concomitant" in table_ids

    def test_execute_handles_missing_optional_data(
        self,
        sample_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
    ):
        """Execute should handle missing optional datasets gracefully."""
        plugin = T2L1Plugin()

        def mock_aggregate(data_partners, run_id, dataset_name, filter_var, filter_values):
            if dataset_name == "t2_cida":
                return sample_t2_cida_data
            else:
                raise ValueError(f"No data for {dataset_name}")

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_agg:
            mock_agg.side_effect = mock_aggregate

            result = plugin.execute(sample_context)

        # Should still succeed with just main table
        assert result.report_type == "T2L1"
        assert len(result.tables) == 1
        assert result.tables[0].table_id == "t2_main"

    def test_execute_with_stratification(
        self,
        sample_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
    ):
        """Execute should handle stratification."""
        context_with_strat = ReportContext(
            report_type="T2L1",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=sample_context.data_partners,
            stratification=StratificationConfig(variables=("sex",)),
            output_dir=sample_context.output_dir,
        )

        plugin = T2L1Plugin()

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t2_cida_data

            result = plugin.execute(context_with_strat)

        assert result.tables[0].stratification == "sex"


class TestT2L1FilterVariables:
    """Tests for correct filter variable usage."""

    def test_t2_cida_uses_group_filter(
        self,
        sample_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
    ):
        """t2_cida should filter by 'group' variable."""
        plugin = T2L1Plugin()

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t2_cida_data

            plugin.execute(sample_context)

        # Check that first call (t2_cida) used group filter
        first_call = mock_agg.call_args_list[0]
        assert first_call.kwargs["filter_var"] == "group"

    def test_concomitant_uses_analysisgrp_filter(
        self,
        sample_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
        sample_concomitant_data: pl.DataFrame,
    ):
        """t2_concomitance should filter by 'analysisgrp' variable."""
        plugin = T2L1Plugin()

        call_args_list = []

        def mock_aggregate(**kwargs):
            call_args_list.append(kwargs)
            if kwargs["dataset_name"] == "t2_cida":
                return sample_t2_cida_data
            elif kwargs["dataset_name"] == "t2_concomitance":
                return sample_concomitant_data
            else:
                raise ValueError(f"No data")

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_agg:
            mock_agg.side_effect = mock_aggregate

            plugin.execute(sample_context)

        # Find the concomitance call
        conc_calls = [c for c in call_args_list if c["dataset_name"] == "t2_concomitance"]
        assert len(conc_calls) == 1
        assert conc_calls[0]["filter_var"] == "analysisgrp"
