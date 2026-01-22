"""Tests for T4L1 (pregnancy-specific background rates) plugin."""

import pytest
import polars as pl
from pathlib import Path
from unittest.mock import patch

from qrp_report.plugins.types import (
    ReportContext,
    DataPartnerInfo,
)
from qrp_report.plugins.t4l1 import T4L1Plugin, T4_PREG_DATASETS
from qrp_report.plugins.registry import get_plugin


class TestT4L1Plugin:
    """Test T4L1 plugin functionality."""

    def test_plugin_report_type(self) -> None:
        """T4L1 plugin identifies as T4L1 report type."""
        plugin = T4L1Plugin()
        assert plugin.report_type == "T4L1"

    def test_plugin_is_registered(self) -> None:
        """T4L1 plugin should be registered."""
        plugin_cls = get_plugin("T4L1")
        assert plugin_cls is T4L1Plugin

    def test_required_datasets(self) -> None:
        """T4L1 requires pregnancy-specific datasets."""
        plugin = T4L1Plugin()
        required = plugin.required_datasets
        assert "t4preg" in required
        assert "t4nopreg" in required
        assert "t4preggestwk" in required
        assert "t4cida" in required

    def test_aggregation_dimensions(self) -> None:
        """T4L1 aggregates by group, moiname, and pregflg."""
        plugin = T4L1Plugin()
        dims = plugin.aggregation_dimensions
        assert "group" in dims
        assert "moiname" in dims
        assert "pregflg" in dims

    def test_trimester_denominator_calculation(self) -> None:
        """T4L1 calculates trimester-specific denominators."""
        plugin = T4L1Plugin()

        # Sample data with trimester flags
        df = pl.DataFrame({
            "group": ["1", "1", "1"],
            "moiname": ["MOI1", "MOI1", "MOI1"],
            "pregflg": ["Y", "Y", "Y"],
            "episodes": [100, 200, 150],
            "episodes_2trim": [80, 160, 120],
            "episodes_3trim": [60, 120, 90],
            "events": [5, 10, 8],
        })

        result = plugin.aggregate_with_trimesters(df)

        # Total episodes should sum
        assert result["episodes"].sum() == 450
        # Trimester denominators maintained separately
        assert "episodes_2trim" in result.columns
        assert "episodes_3trim" in result.columns

    def test_gestational_week_expansion(self) -> None:
        """T4L1 expands gestational week data for transposition."""
        plugin = T4L1Plugin()

        # Gestational week dataset pattern
        df = pl.DataFrame({
            "group": ["1"],
            "moiname": ["MOI1"],
            "gestwk": [20],
            "n_episodes": [50],
            "n_events": [2],
        })

        expanded = plugin.expand_gestational_weeks(df, max_week=44)

        # Should have row for each week up to max
        assert len(expanded) >= 1
        assert "gestwk" in expanded.columns


class TestT4L1Validation:
    """Tests for T4L1 plugin context validation."""

    @pytest.fixture
    def sample_context(self, tmp_path: Path) -> ReportContext:
        """Create sample report context for testing."""
        dp1_path = tmp_path / "dp1"
        dp1_path.mkdir()

        return ReportContext(
            report_type="T4L1",
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
        )

    def test_validates_report_type(self, sample_context: ReportContext) -> None:
        """Should reject non-T4L1 report types."""
        plugin = T4L1Plugin()

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
        assert "T4L1" in errors[0]

    def test_validates_groups_present(self, sample_context: ReportContext) -> None:
        """Should require at least one group."""
        plugin = T4L1Plugin()

        empty_groups_context = ReportContext(
            report_type="T4L1",
            run_id=sample_context.run_id,
            groups=(),
            data_partners=sample_context.data_partners,
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
        )

        errors = plugin.validate_context(empty_groups_context)
        assert len(errors) > 0
        assert "group" in errors[0].lower()

    def test_validates_data_partners_present(self, sample_context: ReportContext) -> None:
        """Should require at least one data partner."""
        plugin = T4L1Plugin()

        no_dp_context = ReportContext(
            report_type="T4L1",
            run_id=sample_context.run_id,
            groups=sample_context.groups,
            data_partners=(),
            stratification=sample_context.stratification,
            output_dir=sample_context.output_dir,
        )

        errors = plugin.validate_context(no_dp_context)
        assert len(errors) > 0
        assert "data partner" in errors[0].lower()

    def test_valid_context_passes(self, sample_context: ReportContext) -> None:
        """Valid context should pass validation."""
        plugin = T4L1Plugin()
        errors = plugin.validate_context(sample_context)
        assert len(errors) == 0


class TestT4L1Integration:
    """Integration tests for T4L1 plugin with realistic data."""

    @pytest.fixture
    def sample_t4preg_data(self) -> pl.DataFrame:
        """Create sample pregnancy cohort data."""
        return pl.DataFrame({
            "group": ["1", "1", "2", "2"],
            "moiname": ["Outcome1", "Outcome1", "Outcome1", "Outcome1"],
            "pregflg": ["Y", "Y", "Y", "Y"],
            "episodes": [1000, 800, 1200, 900],
            "episodes_2trim": [800, 640, 960, 720],
            "episodes_3trim": [600, 480, 720, 540],
            "events": [50, 40, 60, 45],
            "personyears": [500.0, 400.0, 600.0, 450.0],
            "personyears_2trim": [400.0, 320.0, 480.0, 360.0],
            "personyears_3trim": [300.0, 240.0, 360.0, 270.0],
        })

    @pytest.fixture
    def sample_gestwk_data(self) -> pl.DataFrame:
        """Create sample gestational week data."""
        return pl.DataFrame({
            "group": ["1", "1", "1"],
            "moiname": ["Outcome1", "Outcome1", "Outcome1"],
            "gestwk": [10, 20, 30],
            "n_episodes": [100, 150, 80],
            "n_events": [5, 8, 4],
        })

    def test_trimester_aggregation_preserves_structure(
        self,
        sample_t4preg_data: pl.DataFrame,
    ) -> None:
        """Aggregation maintains separate trimester denominators."""
        plugin = T4L1Plugin()

        result = plugin.aggregate_with_trimesters(
            sample_t4preg_data,
            group_cols=["group", "moiname", "pregflg"],
        )

        # Should have 2 groups after aggregation
        assert len(result) == 2

        # Check group 1 totals
        g1 = result.filter(pl.col("group") == "1")
        assert g1["episodes"].item() == 1800  # 1000 + 800
        assert g1["episodes_2trim"].item() == 1440  # 800 + 640
        assert g1["episodes_3trim"].item() == 1080  # 600 + 480

    def test_gestational_week_expansion_fills_gaps(
        self,
        sample_gestwk_data: pl.DataFrame,
    ) -> None:
        """Expansion creates rows for all weeks with zero-fill."""
        plugin = T4L1Plugin()

        result = plugin.expand_gestational_weeks(
            sample_gestwk_data,
            max_week=44,
        )

        # Should have 44 rows (weeks 1-44)
        assert len(result) == 44

        # Original weeks should have their values
        wk20 = result.filter(pl.col("gestwk") == 20)
        assert wk20["n_episodes"].item() == 150

        # Missing weeks should be zero
        wk15 = result.filter(pl.col("gestwk") == 15)
        assert wk15["n_episodes"].item() == 0

    def test_rate_calculation_by_trimester(
        self,
        sample_t4preg_data: pl.DataFrame,
    ) -> None:
        """Rates can be calculated per trimester."""
        plugin = T4L1Plugin()

        agg = plugin.aggregate_with_trimesters(
            sample_t4preg_data,
            group_cols=["group", "moiname", "pregflg"],
        )

        # Calculate rate for full pregnancy
        full_rate = (agg["events"].sum() / agg["personyears"].sum()) * 1000

        # Calculate rate for 2nd trimester
        trim2_rate = (agg["events"].sum() / agg["personyears_2trim"].sum()) * 1000

        # 2nd trimester rate should be higher (smaller denominator)
        assert trim2_rate > full_rate


class TestT4L1RateComputation:
    """Tests for T4L1 rate and CI computation."""

    @pytest.fixture
    def sample_preg_data(self) -> pl.DataFrame:
        """Sample pregnancy data with events and person-years."""
        return pl.DataFrame({
            "group": ["1", "2"],
            "events": [50, 60],
            "episodes": [500, 600],
            "personyears": [250.0, 300.0],
            "personyears_2trim": [200.0, 240.0],
            "personyears_3trim": [150.0, 180.0],
        })

    def test_computes_rate_per_1000py(self, sample_preg_data: pl.DataFrame) -> None:
        """Should compute incidence rate per 1000 person-years."""
        plugin = T4L1Plugin()
        result = plugin._compute_t4_rates(sample_preg_data)

        assert "rate_1000py" in result.columns
        assert "rate_ci_lower" in result.columns
        assert "rate_ci_upper" in result.columns

        # Check first row: 50 events / 250 person-years * 1000 = 200
        rates = result.select("rate_1000py").to_series().to_list()
        assert rates[0] == pytest.approx(200.0, rel=0.01)

    def test_computes_trimester_rates(self, sample_preg_data: pl.DataFrame) -> None:
        """Should compute trimester-specific rates."""
        plugin = T4L1Plugin()
        result = plugin._compute_t4_rates(sample_preg_data)

        assert "rate_1000py_2trim" in result.columns
        assert "rate_1000py_3trim" in result.columns

        # 2nd trim rate: 50 / 200 * 1000 = 250
        rates_2trim = result.select("rate_1000py_2trim").to_series().to_list()
        assert rates_2trim[0] == pytest.approx(250.0, rel=0.01)

        # 3rd trim rate: 50 / 150 * 1000 = 333.33
        rates_3trim = result.select("rate_1000py_3trim").to_series().to_list()
        assert rates_3trim[0] == pytest.approx(333.33, rel=0.01)

    def test_computes_risk_per_episodes(self, sample_preg_data: pl.DataFrame) -> None:
        """Should compute risk per 1000 episodes."""
        plugin = T4L1Plugin()
        result = plugin._compute_t4_rates(sample_preg_data)

        assert "risk_1000eps" in result.columns

        # Check first row: 50 events / 500 episodes * 1000 = 100
        risks = result.select("risk_1000eps").to_series().to_list()
        assert risks[0] == pytest.approx(100.0, rel=0.01)

    def test_handles_zero_denominator(self) -> None:
        """Should handle zero person-years gracefully."""
        plugin = T4L1Plugin()

        df = pl.DataFrame({
            "events": [0],
            "episodes": [0],
            "personyears": [0.0],
            "personyears_2trim": [0.0],
            "personyears_3trim": [0.0],
        })

        result = plugin._compute_t4_rates(df)

        # Should be null, not error
        assert result.select("rate_1000py").to_series().to_list()[0] is None
        assert result.select("rate_1000py_2trim").to_series().to_list()[0] is None
        assert result.select("rate_1000py_3trim").to_series().to_list()[0] is None

    def test_ci_bounds_correct_order(self, sample_preg_data: pl.DataFrame) -> None:
        """CI lower should be less than CI upper."""
        plugin = T4L1Plugin()
        result = plugin._compute_t4_rates(sample_preg_data)

        for row in result.iter_rows(named=True):
            if row["rate_ci_lower"] is not None and row["rate_ci_upper"] is not None:
                assert row["rate_ci_lower"] < row["rate_ci_upper"]


class TestT4L1Execution:
    """Integration tests for T4L1 plugin execution."""

    @pytest.fixture
    def sample_context(self, tmp_path: Path) -> ReportContext:
        """Create sample report context for testing."""
        dp1_path = tmp_path / "dp1"
        dp1_path.mkdir()

        return ReportContext(
            report_type="T4L1",
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

    def test_execute_returns_result(
        self,
        sample_context: ReportContext,
        sample_t4preg_data: pl.DataFrame,
    ) -> None:
        """Execute should return ReportResult."""
        plugin = T4L1Plugin()

        # Mock the aggregate_datasets function
        with patch("qrp_report.plugins.t4l1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t4preg_data

            result = plugin.execute(sample_context)

        assert result.report_type == "T4L1"
        # Should have at least one table (t4preg)
        assert len(result.tables) >= 1

    def test_execute_handles_missing_data(self, sample_context: ReportContext) -> None:
        """Execute should handle missing datasets gracefully."""
        plugin = T4L1Plugin()

        with patch("qrp_report.plugins.t4l1.aggregate_datasets") as mock_agg:
            mock_agg.side_effect = ValueError("No data found")

            result = plugin.execute(sample_context)

        # Should return empty result with warnings
        assert len(result.tables) == 0
        assert len(result.warnings) > 0

    def test_execute_creates_all_expected_tables(
        self,
        sample_context: ReportContext,
        sample_t4preg_data: pl.DataFrame,
    ) -> None:
        """Execute should attempt to create all T4L1 tables."""
        plugin = T4L1Plugin()

        # Track which datasets were requested
        requested_datasets: list[str] = []

        def mock_aggregate(data_partners, run_id, dataset_name, filter_var, filter_values):
            requested_datasets.append(dataset_name)
            return sample_t4preg_data

        with patch("qrp_report.plugins.t4l1.aggregate_datasets", side_effect=mock_aggregate):
            result = plugin.execute(sample_context)

        # Should have requested all expected datasets
        assert "t4preg" in requested_datasets
        assert "t4nopreg" in requested_datasets
        assert "t4preggestwk" in requested_datasets
        assert "t4nopreggestwk" in requested_datasets
        assert "t4cida" in requested_datasets
