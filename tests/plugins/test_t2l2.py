"""Tests for T2L2 report plugin."""

import pytest
import polars as pl
from pathlib import Path
from unittest.mock import patch, MagicMock

from qrp_report.plugins.types import (
    ReportContext,
    DataPartnerInfo,
    StratificationConfig,
)
from qrp_report.plugins.t2l2 import T2L2Plugin
from qrp_report.plugins.registry import get_plugin


@pytest.fixture
def sample_t2_cida_data() -> pl.DataFrame:
    """Create sample T2 CIDA data for testing."""
    return pl.DataFrame({
        "group": ["treatment", "control"],
        "level": [1, 1],
        "npts": [200, 200],
        "episodes": [160, 150],
        "dennummemdays": [73050, 73050],
        "eps_wevents": [20, 15],
        "all_events": [25, 18],
        "followuptime": [72000, 71000],
    })


@pytest.fixture
def sample_ps_distribution_data() -> pl.DataFrame:
    """Create sample PS distribution data."""
    return pl.DataFrame({
        "analysisgrp": ["treatment"] * 5 + ["control"] * 5,
        "ps_value": [0.2, 0.4, 0.5, 0.6, 0.8, 0.3, 0.4, 0.5, 0.55, 0.7],
        "treatment": [1] * 5 + [0] * 5,
    })


@pytest.fixture
def sample_effect_estimates_data() -> pl.DataFrame:
    """Create sample effect estimates data."""
    return pl.DataFrame({
        "analysisgrp": ["treatment_vs_control", "treatment_vs_control"],
        "estimate_type": ["HR", "RR"],
        "estimate": [1.25, 1.18],
        "ci_lower": [0.95, 0.90],
        "ci_upper": [1.65, 1.55],
        "se": [0.14, 0.13],
        "pvalue": [0.12, 0.18],
        "n": [400, 400],
    })


@pytest.fixture
def sample_l2_context(tmp_path: Path) -> ReportContext:
    """Create sample L2 report context."""
    dp1_path = tmp_path / "dp1"
    dp1_path.mkdir()

    return ReportContext(
        report_type="T2L2",
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
        periods=(1,),
        ps_method="matching",
    )


class TestT2L2PluginRegistration:
    """Tests for T2L2 plugin registration."""

    def test_plugin_is_registered(self):
        """T2L2 plugin should be registered."""
        plugin_cls = get_plugin("T2L2")
        assert plugin_cls is T2L2Plugin

    def test_plugin_report_type(self):
        """Plugin should report correct type."""
        plugin = T2L2Plugin()
        assert plugin.report_type == "T2L2"

    def test_plugin_required_datasets(self):
        """Plugin should list required datasets."""
        plugin = T2L2Plugin()
        assert "t2_cida" in plugin.required_datasets


class TestT2L2PluginValidation:
    """Tests for T2L2 plugin context validation."""

    def test_validates_report_type(self, sample_l2_context: ReportContext):
        """Should reject non-T2L2 report types."""
        plugin = T2L2Plugin()

        wrong_context = ReportContext(
            report_type="T2L1",
            run_id=sample_l2_context.run_id,
            groups=sample_l2_context.groups,
            data_partners=sample_l2_context.data_partners,
            stratification=sample_l2_context.stratification,
            output_dir=sample_l2_context.output_dir,
            periods=sample_l2_context.periods,
            ps_method=sample_l2_context.ps_method,
        )

        errors = plugin.validate_context(wrong_context)
        assert len(errors) > 0
        assert "T2L2" in errors[0]

    def test_validates_periods_required(self, sample_l2_context: ReportContext):
        """Should require at least one period for L2."""
        plugin = T2L2Plugin()

        no_periods_context = ReportContext(
            report_type="T2L2",
            run_id=sample_l2_context.run_id,
            groups=sample_l2_context.groups,
            data_partners=sample_l2_context.data_partners,
            stratification=sample_l2_context.stratification,
            output_dir=sample_l2_context.output_dir,
            periods=(),
            ps_method=sample_l2_context.ps_method,
        )

        errors = plugin.validate_context(no_periods_context)
        assert len(errors) > 0
        assert "period" in errors[0].lower()

    def test_validates_ps_method_required(self, sample_l2_context: ReportContext):
        """Should require PS method for L2."""
        plugin = T2L2Plugin()

        no_ps_context = ReportContext(
            report_type="T2L2",
            run_id=sample_l2_context.run_id,
            groups=sample_l2_context.groups,
            data_partners=sample_l2_context.data_partners,
            stratification=sample_l2_context.stratification,
            output_dir=sample_l2_context.output_dir,
            periods=sample_l2_context.periods,
            ps_method=None,
        )

        errors = plugin.validate_context(no_ps_context)
        assert len(errors) > 0
        assert "ps" in errors[0].lower() or "method" in errors[0].lower()

    def test_valid_context_passes(self, sample_l2_context: ReportContext):
        """Valid L2 context should pass validation."""
        plugin = T2L2Plugin()
        errors = plugin.validate_context(sample_l2_context)
        assert len(errors) == 0


class TestT2L2Execution:
    """Integration tests for T2L2 plugin execution."""

    def test_execute_generates_l1_and_l2_tables(
        self,
        sample_l2_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
        sample_effect_estimates_data: pl.DataFrame,
    ):
        """Execute should generate both L1 and L2 tables."""
        plugin = T2L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset == "t2_cida":
                return sample_t2_cida_data
            elif dataset == "estimates_1":
                return sample_effect_estimates_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t2l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(sample_l2_context)

        assert result.report_type == "T2L2"

        # Should have L1 tables
        table_ids = [t.table_id for t in result.tables]
        assert "t2_main" in table_ids

        # Should have L2 effect estimate table
        l2_tables = [t for t in result.tables if t.table_id.startswith("l2_")]
        assert len(l2_tables) >= 1

    def test_execute_creates_figures(
        self,
        sample_l2_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
        sample_ps_distribution_data: pl.DataFrame,
        sample_effect_estimates_data: pl.DataFrame,
    ):
        """Execute should create PS histogram and forest plot figures."""
        plugin = T2L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset == "t2_cida":
                return sample_t2_cida_data
            elif dataset == "psdistribution_1":
                return sample_ps_distribution_data
            elif dataset == "estimates_1":
                return sample_effect_estimates_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t2l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(sample_l2_context)

        # Should have figures
        figure_ids = [f.figure_id for f in result.figures]
        assert "f1_ps_dist_1" in figure_ids
        assert "f2_forest_1" in figure_ids

    def test_execute_multiple_periods(
        self,
        sample_l2_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
        sample_effect_estimates_data: pl.DataFrame,
    ):
        """Execute should handle multiple analysis periods."""
        multi_period_context = ReportContext(
            report_type="T2L2",
            run_id=sample_l2_context.run_id,
            groups=sample_l2_context.groups,
            data_partners=sample_l2_context.data_partners,
            stratification=sample_l2_context.stratification,
            output_dir=sample_l2_context.output_dir,
            periods=(1, 2, 3),
            ps_method=sample_l2_context.ps_method,
        )

        plugin = T2L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset == "t2_cida":
                return sample_t2_cida_data
            elif dataset.startswith("estimates_"):
                return sample_effect_estimates_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t2l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(multi_period_context)

        # Should have L2 tables for each period
        l2_effect_tables = [t for t in result.tables if t.table_id.startswith("l2_effects_")]
        assert len(l2_effect_tables) == 3

    def test_execute_handles_missing_l2_data(
        self,
        sample_l2_context: ReportContext,
        sample_t2_cida_data: pl.DataFrame,
    ):
        """Execute should handle missing L2 datasets gracefully."""
        plugin = T2L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset == "t2_cida":
                return sample_t2_cida_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t2l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(sample_l2_context)

        # Should still have L1 tables
        table_ids = [t.table_id for t in result.tables]
        assert "t2_main" in table_ids

        # Should have warnings about missing L2 data
        assert len(result.warnings) > 0


class TestT2L2EffectEstimateAggregation:
    """Tests for effect estimate aggregation."""

    def test_aggregates_by_analysis_group(self, sample_effect_estimates_data: pl.DataFrame):
        """Should aggregate effect estimates by analysis group."""
        plugin = T2L2Plugin()

        result = plugin._aggregate_effect_estimates(
            df=sample_effect_estimates_data,
            ps_method="matching",
        )

        assert "analysisgrp" in result.columns
        assert "estimate" in result.columns

    def test_uses_weighted_aggregation_when_n_available(
        self,
        sample_effect_estimates_data: pl.DataFrame,
    ):
        """Should use weighted aggregation when sample sizes available."""
        plugin = T2L2Plugin()

        # Add DP-level data to simulate multiple DPs
        multi_dp_data = pl.concat([
            sample_effect_estimates_data.with_columns(pl.lit("DP01").alias("dpidsiteid")),
            sample_effect_estimates_data.with_columns([
                pl.lit("DP02").alias("dpidsiteid"),
                (pl.col("n") * 2).alias("n"),  # Different weight
            ]),
        ])

        result = plugin._aggregate_effect_estimates(
            df=multi_dp_data,
            ps_method="matching",
        )

        # Aggregated n should be sum
        total_n = result.filter(pl.col("estimate_type") == "HR").select("n").to_series()[0]
        assert total_n == 400 + 800  # 400 from DP01, 800 from DP02


class TestT2L2FigureCreation:
    """Tests for figure data creation."""

    def test_creates_ps_histogram_data(self, sample_ps_distribution_data: pl.DataFrame):
        """Should create PS histogram figure data."""
        plugin = T2L2Plugin()

        result = plugin._create_ps_histogram_figure(sample_ps_distribution_data, period=1)

        assert result is not None
        assert result.figure_id == "f1_ps_dist_1"
        assert result.figure_type == "histogram"
        assert "ps_value" in result.data.columns

    def test_creates_forest_plot_data(self, sample_effect_estimates_data: pl.DataFrame):
        """Should create forest plot figure data."""
        plugin = T2L2Plugin()

        result = plugin._create_forest_plot_figure(sample_effect_estimates_data, period=1)

        assert result is not None
        assert result.figure_id == "f2_forest_1"
        assert result.figure_type == "forest_plot"
        assert "estimate" in result.data.columns
        assert "ci_lower" in result.data.columns
        assert "ci_upper" in result.data.columns

    def test_returns_none_for_missing_columns(self):
        """Should return None if required columns missing."""
        plugin = T2L2Plugin()

        incomplete_data = pl.DataFrame({
            "analysisgrp": ["treatment"],
            "some_other_column": [1],
        })

        result = plugin._create_forest_plot_figure(incomplete_data, period=1)

        assert result is None
