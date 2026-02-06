"""Tests for T4L2 (pregnancy effect estimates) plugin."""

import pytest
import polars as pl
from pathlib import Path
from unittest.mock import patch

from qrp_report.plugins.types import (
    ReportContext,
    DataPartnerInfo,
)
from qrp_report.plugins.t4l2 import T4L2Plugin, EFFECT_METHODS, T4L2_DATASETS
from qrp_report.plugins.registry import get_plugin


class TestT4L2Plugin:
    """Test T4L2 plugin functionality."""

    def test_plugin_report_type(self) -> None:
        """T4L2 plugin identifies as T4L2 report type."""
        plugin = T4L2Plugin()
        assert plugin.report_type == "T4L2"

    def test_plugin_is_registered(self) -> None:
        """T4L2 plugin should be registered."""
        plugin_cls = get_plugin("T4L2")
        assert plugin_cls is T4L2Plugin

    def test_dual_effect_methods(self) -> None:
        """T4L2 supports both binary and timetoevent methods."""
        plugin = T4L2Plugin()
        methods = plugin.effect_methods
        assert "binary" in methods
        assert "timetoevent" in methods

    def test_required_datasets_includes_l1(self) -> None:
        """T4L2 required datasets include T4L1 datasets."""
        plugin = T4L2Plugin()
        required = plugin.required_datasets

        # Should include T4L1 datasets
        assert "t4preg" in required
        assert "t4nopreg" in required
        assert "t4cida" in required

        # Should include T4L2-specific datasets
        for ds in T4L2_DATASETS:
            assert ds in required

    def test_includes_l1_plugin(self) -> None:
        """T4L2 includes L1 plugin via composition."""
        plugin = T4L2Plugin()
        assert hasattr(plugin, "l1_plugin")
        assert plugin.l1_plugin.report_type == "T4L1"

    def test_binary_method_produces_risk_ratio(self) -> None:
        """Binary method calculates Risk Ratio."""
        plugin = T4L2Plugin()

        # Sample effect estimate data
        df = pl.DataFrame({
            "group": ["1"],
            "moiname": ["MOI1"],
            "estimate": [1.25],
            "lcl": [0.95],
            "ucl": [1.65],
        })

        result = plugin.format_effect_estimates(df, method="binary")

        assert "RR" in result.columns
        assert "RR (95% CI)" in result.columns

    def test_timetoevent_method_produces_hazard_ratio(self) -> None:
        """Timetoevent method calculates Hazard Ratio."""
        plugin = T4L2Plugin()

        df = pl.DataFrame({
            "group": ["1"],
            "moiname": ["MOI1"],
            "estimate": [1.15],
            "lcl": [0.88],
            "ucl": [1.50],
        })

        result = plugin.format_effect_estimates(df, method="timetoevent")

        assert "HR" in result.columns
        assert "HR (95% CI)" in result.columns

    def test_separate_forest_plots_per_method(self) -> None:
        """T4L2 generates separate forest plots for each method."""
        plugin = T4L2Plugin()

        df = pl.DataFrame({
            "group": ["1", "1"],
            "moiname": ["MOI1", "MOI1"],
            "method": ["binary", "timetoevent"],
            "estimate": [1.25, 1.15],
            "lcl": [0.95, 0.88],
            "ucl": [1.65, 1.50],
        })

        figures = plugin.generate_forest_plots(df)

        # Should have one figure per method
        assert len(figures) == 2
        figure_ids = {f.figure_id for f in figures}
        assert "forest_binary" in figure_ids
        assert "forest_timetoevent" in figure_ids


class TestT4L2Validation:
    """Tests for T4L2 plugin context validation."""

    @pytest.fixture
    def sample_context(self, tmp_path: Path) -> ReportContext:
        """Create sample L2 report context."""
        dp1_path = tmp_path / "dp1"
        dp1_path.mkdir()

        return ReportContext(
            report_type="T4L2",
            run_id="run01",
            groups=("1", "2"),
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
        )

    def test_validates_report_type(self, sample_context: ReportContext) -> None:
        """Should reject non-T4L2 report types."""
        plugin = T4L2Plugin()

        wrong_context = ReportContext(
            report_type="T4L1",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
            periods=sample_context.periods,
        )

        errors = plugin.validate_context(wrong_context)
        assert len(errors) > 0
        assert "T4L2" in errors[0]

    def test_validates_groups_present(self, sample_context: ReportContext) -> None:
        """Should require at least one group."""
        plugin = T4L2Plugin()

        empty_groups_context = ReportContext(
            report_type="T4L2",
            run_id=sample_context.run_id,
            groups=(),
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
            periods=sample_context.periods,
        )

        errors = plugin.validate_context(empty_groups_context)
        assert len(errors) > 0
        assert "group" in errors[0].lower()

    def test_validates_data_partners_present(self, sample_context: ReportContext) -> None:
        """Should require at least one data partner."""
        plugin = T4L2Plugin()

        no_dp_context = ReportContext(
            report_type="T4L2",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=(),
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
            periods=sample_context.periods,
        )

        errors = plugin.validate_context(no_dp_context)
        assert len(errors) > 0
        assert "data partner" in errors[0].lower()

    def test_validates_periods_required(self, sample_context: ReportContext) -> None:
        """Should require at least one period for L2."""
        plugin = T4L2Plugin()

        no_periods_context = ReportContext(
            report_type="T4L2",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
            periods=(),
        )

        errors = plugin.validate_context(no_periods_context)
        assert len(errors) > 0
        assert "period" in errors[0].lower()

    def test_valid_context_passes(self, sample_context: ReportContext) -> None:
        """Valid L2 context should pass validation."""
        plugin = T4L2Plugin()
        errors = plugin.validate_context(sample_context)
        assert len(errors) == 0


class TestT4L2Integration:
    """Integration tests for T4L2 plugin."""

    @pytest.fixture
    def sample_binary_effects(self) -> pl.DataFrame:
        """Sample binary method effect estimates."""
        return pl.DataFrame({
            "group": ["1", "1", "2", "2"],
            "moiname": ["MOI1", "MOI2", "MOI1", "MOI2"],
            "estimate": [1.25, 0.85, 1.42, 0.92],
            "lcl": [0.95, 0.62, 1.10, 0.71],
            "ucl": [1.65, 1.16, 1.83, 1.19],
            "pvalue": [0.12, 0.31, 0.008, 0.52],
        })

    @pytest.fixture
    def sample_timetoevent_effects(self) -> pl.DataFrame:
        """Sample timetoevent method effect estimates."""
        return pl.DataFrame({
            "group": ["1", "1", "2", "2"],
            "moiname": ["MOI1", "MOI2", "MOI1", "MOI2"],
            "estimate": [1.18, 0.79, 1.35, 0.88],
            "lcl": [0.92, 0.58, 1.05, 0.68],
            "ucl": [1.51, 1.08, 1.74, 1.14],
            "pvalue": [0.18, 0.14, 0.02, 0.34],
        })

    @pytest.fixture
    def sample_t4preg_data(self) -> pl.DataFrame:
        """Create sample T4 pregnancy data for testing."""
        return pl.DataFrame({
            "group": ["1", "1", "2", "2"],
            "moiname": ["MOI1", "MOI1", "MOI1", "MOI1"],
            "pregflg": ["Y", "Y", "Y", "Y"],
            "episodes": [100, 150, 120, 180],
            "episodes_2trim": [80, 120, 96, 144],
            "episodes_3trim": [60, 90, 72, 108],
            "events": [10, 15, 12, 18],
            "personyears": [50.0, 75.0, 60.0, 90.0],
            "personyears_2trim": [40.0, 60.0, 48.0, 72.0],
            "personyears_3trim": [30.0, 45.0, 36.0, 54.0],
        })

    def test_binary_format_includes_ci_string(
        self,
        sample_binary_effects: pl.DataFrame,
    ) -> None:
        """Binary formatting produces RR (95% CI) string."""
        plugin = T4L2Plugin()

        result = plugin.format_effect_estimates(
            sample_binary_effects,
            method="binary",
        )

        assert "RR" in result.columns
        assert "RR (95% CI)" in result.columns

        # Check formatting
        first_ci = result["RR (95% CI)"][0]
        assert "1.25" in first_ci
        assert "0.95" in first_ci
        assert "1.65" in first_ci

    def test_timetoevent_format_includes_ci_string(
        self,
        sample_timetoevent_effects: pl.DataFrame,
    ) -> None:
        """Timetoevent formatting produces HR (95% CI) string."""
        plugin = T4L2Plugin()

        result = plugin.format_effect_estimates(
            sample_timetoevent_effects,
            method="timetoevent",
        )

        assert "HR" in result.columns
        assert "HR (95% CI)" in result.columns

    def test_forest_plots_contain_required_metadata(
        self,
        sample_binary_effects: pl.DataFrame,
        sample_timetoevent_effects: pl.DataFrame,
    ) -> None:
        """Forest plots include metadata for rendering."""
        plugin = T4L2Plugin()

        # Combine with method column
        binary = sample_binary_effects.with_columns(pl.lit("binary").alias("method"))
        tte = sample_timetoevent_effects.with_columns(pl.lit("timetoevent").alias("method"))
        combined = pl.concat([binary, tte])

        figures = plugin.generate_forest_plots(combined)

        for fig in figures:
            assert fig.figure_type == "forest_plot"
            # Check metadata is tuple of tuples
            metadata_dict = dict(fig.metadata)
            assert "method" in metadata_dict
            assert "measure" in metadata_dict
            assert "reference_line" in metadata_dict
            assert metadata_dict["reference_line"] == 1.0

    def test_l1_tables_included_in_l2_output(self) -> None:
        """T4L2 output includes all T4L1 tables."""
        plugin = T4L2Plugin()

        # T4L1 required datasets should be subset of T4L2
        l1_datasets = set(plugin.l1_plugin.required_datasets)
        l2_datasets = set(plugin.required_datasets)

        assert l1_datasets.issubset(l2_datasets)


class TestT4L2Execution:
    """Integration tests for T4L2 plugin execution."""

    @pytest.fixture
    def sample_context(self, tmp_path: Path) -> ReportContext:
        """Create sample L2 report context."""
        dp1_path = tmp_path / "dp1"
        dp1_path.mkdir()

        return ReportContext(
            report_type="T4L2",
            run_id="run01",
            groups=("1", "2"),
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
        )

    @pytest.fixture
    def sample_t4preg_data(self) -> pl.DataFrame:
        """Create sample T4 pregnancy data for testing."""
        return pl.DataFrame({
            "group": ["1", "1", "2", "2"],
            "moiname": ["MOI1", "MOI1", "MOI1", "MOI1"],
            "pregflg": ["Y", "Y", "Y", "Y"],
            "episodes": [100, 150, 120, 180],
            "episodes_2trim": [80, 120, 96, 144],
            "episodes_3trim": [60, 90, 72, 108],
            "events": [10, 15, 12, 18],
            "personyears": [50.0, 75.0, 60.0, 90.0],
            "personyears_2trim": [40.0, 60.0, 48.0, 72.0],
            "personyears_3trim": [30.0, 45.0, 36.0, 54.0],
        })

    @pytest.fixture
    def sample_effect_data(self) -> pl.DataFrame:
        """Create sample effect estimate data for testing."""
        return pl.DataFrame({
            "group": ["1", "2"],
            "moiname": ["MOI1", "MOI1"],
            "estimate": [1.25, 1.42],
            "lcl": [0.95, 1.10],
            "ucl": [1.65, 1.83],
            "pvalue": [0.12, 0.008],
            "n": [200, 250],
        })

    def test_execute_returns_result(
        self,
        sample_context: ReportContext,
        sample_t4preg_data: pl.DataFrame,
        sample_effect_data: pl.DataFrame,
    ) -> None:
        """Execute should return ReportResult."""
        plugin = T4L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset in ["t4preg", "t4nopreg", "t4cida", "t4preggestwk", "t4nopreggestwk"]:
                return sample_t4preg_data
            elif dataset.startswith("t4_effect_"):
                return sample_effect_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t4l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t4l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(sample_context)

        assert result.report_type == "T4L2"
        assert len(result.tables) >= 1

    def test_execute_generates_l1_and_l2_tables(
        self,
        sample_context: ReportContext,
        sample_t4preg_data: pl.DataFrame,
        sample_effect_data: pl.DataFrame,
    ) -> None:
        """Execute should generate both L1 and L2 tables."""
        plugin = T4L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset in ["t4preg", "t4nopreg", "t4cida", "t4preggestwk", "t4nopreggestwk"]:
                return sample_t4preg_data
            elif dataset.startswith("t4_effect_"):
                return sample_effect_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t4l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t4l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(sample_context)

        # Should have L1 tables (from T4L1)
        table_ids = [t.table_id for t in result.tables]
        l1_tables = [tid for tid in table_ids if tid.startswith("t4_")]
        assert len(l1_tables) >= 1

        # Should have L2 effect estimate tables
        l2_tables = [tid for tid in table_ids if tid.startswith("l2_")]
        assert len(l2_tables) >= 1

    def test_execute_creates_forest_plots(
        self,
        sample_context: ReportContext,
        sample_t4preg_data: pl.DataFrame,
        sample_effect_data: pl.DataFrame,
    ) -> None:
        """Execute should create forest plot figures."""
        plugin = T4L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset in ["t4preg", "t4nopreg", "t4cida", "t4preggestwk", "t4nopreggestwk"]:
                return sample_t4preg_data
            elif dataset.startswith("t4_effect_"):
                return sample_effect_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t4l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t4l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(sample_context)

        # Should have forest plot figures
        forest_plots = [f for f in result.figures if "forest" in f.figure_id]
        assert len(forest_plots) >= 1

    def test_execute_handles_missing_l2_data(
        self,
        sample_context: ReportContext,
        sample_t4preg_data: pl.DataFrame,
    ) -> None:
        """Execute should handle missing L2 datasets gracefully."""
        plugin = T4L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset in ["t4preg", "t4nopreg", "t4cida", "t4preggestwk", "t4nopreggestwk"]:
                return sample_t4preg_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t4l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t4l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(sample_context)

        # Should still have L1 tables
        table_ids = [t.table_id for t in result.tables]
        l1_tables = [tid for tid in table_ids if tid.startswith("t4_")]
        assert len(l1_tables) >= 1

        # Should have warnings about missing L2 data
        assert len(result.warnings) > 0

    def test_execute_multiple_periods(
        self,
        sample_context: ReportContext,
        sample_t4preg_data: pl.DataFrame,
        sample_effect_data: pl.DataFrame,
    ) -> None:
        """Execute should handle multiple analysis periods."""
        multi_period_context = ReportContext(
            report_type="T4L2",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
            periods=(1, 2, 3),
        )

        plugin = T4L2Plugin()

        def mock_aggregate(**kwargs):
            dataset = kwargs["dataset_name"]
            if dataset in ["t4preg", "t4nopreg", "t4cida", "t4preggestwk", "t4nopreggestwk"]:
                return sample_t4preg_data
            elif dataset.startswith("t4_effect_"):
                return sample_effect_data
            else:
                raise ValueError(f"No data for {dataset}")

        with patch("qrp_report.plugins.t4l1.aggregate_datasets") as mock_l1, \
             patch("qrp_report.plugins.t4l2.aggregate_datasets") as mock_l2:
            mock_l1.side_effect = mock_aggregate
            mock_l2.side_effect = mock_aggregate

            result = plugin.execute(multi_period_context)

        # Should have L2 tables for each period and method
        l2_effect_tables = [t for t in result.tables if t.table_id.startswith("l2_effects_")]
        # 3 periods x 2 methods = 6 effect tables
        assert len(l2_effect_tables) == 6


class TestT4L2EffectEstimateAggregation:
    """Tests for effect estimate aggregation."""

    def test_aggregates_by_group(self) -> None:
        """Should aggregate effect estimates by group."""
        plugin = T4L2Plugin()

        df = pl.DataFrame({
            "group": ["1", "1"],
            "moiname": ["MOI1", "MOI1"],
            "estimate": [1.25, 1.30],
            "lcl": [0.95, 1.00],
            "ucl": [1.65, 1.68],
            "n": [100, 150],
        })

        result = plugin._aggregate_effect_estimates(df)

        assert "group" in result.columns
        assert "estimate" in result.columns
        # Should have one row per group
        assert len(result) == 1

    def test_uses_weighted_aggregation_when_n_available(self) -> None:
        """Should use weighted aggregation when sample sizes available."""
        plugin = T4L2Plugin()

        # Add DP-level data to simulate multiple DPs
        df = pl.DataFrame({
            "group": ["1", "1"],
            "moiname": ["MOI1", "MOI1"],
            "estimate": [1.20, 1.30],
            "lcl": [0.90, 1.00],
            "ucl": [1.60, 1.70],
            "n": [100, 200],  # Different weights
        })

        result = plugin._aggregate_effect_estimates(df)

        # Aggregated n should be sum
        total_n = result.select("n").to_series()[0]
        assert total_n == 300

        # Weighted estimate: (1.20*100 + 1.30*200) / 300 = 1.2667
        weighted_est = result.select("estimate").to_series()[0]
        assert weighted_est == pytest.approx(1.2667, rel=0.01)


class TestT4L2FigureCreation:
    """Tests for figure data creation."""

    def test_creates_forest_plot_data(self) -> None:
        """Should create forest plot figure data."""
        plugin = T4L2Plugin()

        df = pl.DataFrame({
            "group": ["1", "2"],
            "moiname": ["MOI1", "MOI1"],
            "method": ["binary", "binary"],
            "estimate": [1.25, 1.42],
            "lcl": [0.95, 1.10],
            "ucl": [1.65, 1.83],
        })

        figures = plugin.generate_forest_plots(df)

        assert len(figures) == 1
        assert figures[0].figure_id == "forest_binary"
        assert figures[0].figure_type == "forest_plot"
        assert "estimate" in figures[0].data.columns

    def test_returns_empty_for_no_data(self) -> None:
        """Should return empty list if no method data available."""
        plugin = T4L2Plugin()

        empty_df = pl.DataFrame({
            "group": pl.Series([], dtype=pl.Utf8),
            "method": pl.Series([], dtype=pl.Utf8),
            "estimate": pl.Series([], dtype=pl.Float64),
        })

        figures = plugin.generate_forest_plots(empty_df)

        assert len(figures) == 0

    def test_creates_separate_plots_per_method(self) -> None:
        """Should create separate forest plots for binary and timetoevent."""
        plugin = T4L2Plugin()

        df = pl.DataFrame({
            "group": ["1", "1"],
            "moiname": ["MOI1", "MOI1"],
            "method": ["binary", "timetoevent"],
            "estimate": [1.25, 1.18],
            "lcl": [0.95, 0.92],
            "ucl": [1.65, 1.51],
        })

        figures = plugin.generate_forest_plots(df)

        assert len(figures) == 2

        binary_fig = next(f for f in figures if f.figure_id == "forest_binary")
        tte_fig = next(f for f in figures if f.figure_id == "forest_timetoevent")

        # Check measure in metadata
        binary_meta = dict(binary_fig.metadata)
        tte_meta = dict(tte_fig.metadata)

        assert binary_meta["measure"] == "RR"
        assert tte_meta["measure"] == "HR"
