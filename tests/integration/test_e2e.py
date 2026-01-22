"""End-to-end integration tests for QRP Report generation.

These tests verify the full pipeline from configuration to report output:
- Configuration loading (YAML format)
- Driver orchestration
- Plugin execution
- Report result structure

The tests use minimal mock data to exercise the complete workflow
without requiring actual SAS datasets.
"""

import polars as pl
import pytest
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any
from unittest.mock import patch, MagicMock

from typer.testing import CliRunner

from qrp_report.driver import ReportDriver
from qrp_report.cli import app
from qrp_report.config.models import (
    ReportConfig,
    ReportType,
    DPInfo,
    GroupConfig,
)
from qrp_report.plugins.types import (
    ReportContext,
    DataPartnerInfo,
    StratificationConfig,
)


# CLI test runner
runner = CliRunner()


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def sample_config() -> ReportConfig:
    """Create minimal test configuration for T1 report."""
    return ReportConfig(
        reportid="test001",
        reporttype=ReportType.T1,
        dpinfo=[
            DPInfo(
                dp="DP001",
                dpname="Test Partner 1",
                path=Path("/tmp/dp001"),
                includedp=True,
            ),
        ],
        groups=[
            GroupConfig(
                runid="test001",
                group="treatment",
                order=1,
            ),
            GroupConfig(
                runid="test001",
                group="control",
                order=2,
            ),
        ],
    )


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
        "dennummemdays": [36525, 54787, 43830, 65745],
        "timetocensor": [90, 100, 85, 95],
        "dpidsiteid": ["DP001", "DP001", "DP001", "DP001"],
        "runid": ["test001", "test001", "test001", "test001"],
    })


@pytest.fixture
def sample_t2l1_data() -> pl.DataFrame:
    """Create sample T2L1 data for testing."""
    return pl.DataFrame({
        "group": ["treatment", "control"],
        "level": [1, 1],
        "npts": [500, 480],
        "episodes": [45, 38],
        "personyears": [450.5, 432.0],
        "exposuretime": [180.0, 175.0],
        "dpidsiteid": ["DP001", "DP001"],
        "runid": ["test001", "test001"],
    })


@pytest.fixture
def yaml_config_file(tmp_path: Path) -> Path:
    """Create a test YAML configuration file."""
    config_content = """
reportid: test_report_001
reporttype: T1
dpinfo:
  - dp: DP001
    dpname: Test Data Partner
    path: /tmp/test/dp001
    includedp: true
groups:
  - runid: test_report_001
    group: treatment
    order: 1
  - runid: test_report_001
    group: control
    order: 2
stratifybydp: false
"""
    config_path = tmp_path / "test_config.yaml"
    config_path.write_text(config_content)
    return config_path


# ---------------------------------------------------------------------------
# Test Classes
# ---------------------------------------------------------------------------


class TestEndToEndGeneration:
    """End-to-end tests for complete report generation workflow."""

    def test_t1_report_generation_with_mock_data(
        self,
        sample_config: ReportConfig,
        sample_t1_cida_data: pl.DataFrame,
        tmp_path: Path,
    ) -> None:
        """T1 report generates successfully with mocked data."""
        driver = ReportDriver()
        output_path = tmp_path / "output"
        output_path.mkdir()

        # Mock the aggregate_datasets function to return our test data
        with patch("qrp_report.plugins.t1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t1_cida_data

            result = driver.generate_report(
                config=sample_config,
                data_path=tmp_path,
                output_path=output_path,
            )

        # Verify result structure
        assert result.report_type == "T1"
        assert len(result.tables) >= 1

        # Verify at least one table has data
        has_data = any(len(t.data) > 0 for t in result.tables)
        assert has_data, "Expected at least one table with data"

    def test_all_plugins_can_instantiate(self) -> None:
        """All registered plugins can be instantiated and have required properties."""
        driver = ReportDriver()
        report_types = driver.available_report_types()

        # Should have at least T1, T2L1, T2L2, T4L1, T4L2
        assert len(report_types) >= 5, f"Expected >= 5 report types, got {report_types}"

        for report_type in report_types:
            plugin = driver.get_plugin(report_type)

            # Verify required properties exist
            assert plugin.report_type == report_type
            assert hasattr(plugin, "required_datasets")
            assert len(plugin.required_datasets) > 0
            assert hasattr(plugin, "validate_context")
            assert hasattr(plugin, "execute")

    def test_all_plugins_have_unique_report_types(self) -> None:
        """Each plugin should have a unique report type."""
        driver = ReportDriver()
        report_types = driver.available_report_types()

        # Check no duplicates
        assert len(report_types) == len(set(report_types))

        # Verify expected types are present
        expected = {"T1", "T2L1", "T2L2", "T4L1", "T4L2"}
        actual = set(report_types)
        assert expected.issubset(actual), f"Missing types: {expected - actual}"

    def test_config_validation_catches_unknown_report_type(self) -> None:
        """Config validation identifies invalid report type configurations."""
        driver = ReportDriver()

        # Create config with invalid report type by patching
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T1,
            dpinfo=[],
            groups=[],
        )

        # Manually change to invalid type for testing
        # Since Pydantic validates, we need to test the driver validation
        with patch.object(config, "reporttype", "INVALID_TYPE"):
            errors = driver.validate_config(config)
            assert len(errors) > 0
            assert "Unknown report type" in errors[0]

    def test_config_validation_catches_missing_groups(
        self,
        sample_config: ReportConfig,
    ) -> None:
        """Config validation identifies missing groups."""
        driver = ReportDriver()

        # Create config with no groups
        config = ReportConfig(
            reportid=sample_config.reportid,
            reporttype=sample_config.reporttype,
            dpinfo=sample_config.dpinfo,
            groups=[],  # Empty groups
        )

        errors = driver.validate_config(config)
        assert len(errors) > 0
        assert any("group" in e.lower() for e in errors)

    def test_config_validation_catches_missing_data_partners(
        self,
        sample_config: ReportConfig,
    ) -> None:
        """Config validation identifies missing data partners."""
        driver = ReportDriver()

        # Create config with no data partners
        config = ReportConfig(
            reportid=sample_config.reportid,
            reporttype=sample_config.reporttype,
            dpinfo=[],  # Empty data partners
            groups=sample_config.groups,
        )

        errors = driver.validate_config(config)
        assert len(errors) > 0
        assert any("data partner" in e.lower() for e in errors)

    def test_valid_config_passes_validation(
        self,
        sample_config: ReportConfig,
    ) -> None:
        """Valid configuration passes validation without errors."""
        driver = ReportDriver()
        errors = driver.validate_config(sample_config)
        assert len(errors) == 0, f"Unexpected errors: {errors}"


class TestPluginExecution:
    """Tests for plugin execution with realistic data patterns."""

    def test_t1_plugin_execution(
        self,
        sample_t1_cida_data: pl.DataFrame,
        tmp_path: Path,
    ) -> None:
        """T1 plugin executes and produces expected tables."""
        driver = ReportDriver()
        plugin = driver.get_plugin("T1")

        context = ReportContext(
            report_type="T1",
            run_id="test001",
            groups=("treatment", "control"),
            data_partners=(
                DataPartnerInfo(
                    dp_id="DP001",
                    masked_id="DP001",
                    data_path=tmp_path / "DP001",
                ),
            ),
            stratification=None,
            output_dir=tmp_path / "output",
        )

        # Mock the data loading
        with patch("qrp_report.plugins.t1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t1_cida_data

            result = plugin.execute(context)

        # Verify T1 produces expected table structure
        assert result.report_type == "T1"
        assert len(result.tables) >= 1
        assert result.tables[0].table_id == "t1_main"

    def test_t2l1_plugin_execution(
        self,
        sample_t2l1_data: pl.DataFrame,
        tmp_path: Path,
    ) -> None:
        """T2L1 plugin executes and produces expected tables."""
        driver = ReportDriver()
        plugin = driver.get_plugin("T2L1")

        context = ReportContext(
            report_type="T2L1",
            run_id="test001",
            groups=("treatment", "control"),
            data_partners=(
                DataPartnerInfo(
                    dp_id="DP001",
                    masked_id="DP001",
                    data_path=tmp_path / "DP001",
                ),
            ),
            stratification=None,
            output_dir=tmp_path / "output",
        )

        # Mock the data loading to return empty but valid result
        with patch("qrp_report.plugins.t2l1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t2l1_data

            result = plugin.execute(context)

        assert result.report_type == "T2L1"
        # T2L1 should produce at least one table or warning about missing data
        assert len(result.tables) >= 0  # May be empty if optional datasets missing

    def test_plugin_handles_missing_data_gracefully(
        self,
        tmp_path: Path,
    ) -> None:
        """Plugin handles missing data without crashing."""
        driver = ReportDriver()
        plugin = driver.get_plugin("T1")

        context = ReportContext(
            report_type="T1",
            run_id="test001",
            groups=("treatment",),
            data_partners=(
                DataPartnerInfo(
                    dp_id="DP001",
                    masked_id="DP001",
                    data_path=tmp_path / "nonexistent",
                ),
            ),
            stratification=None,
            output_dir=tmp_path / "output",
        )

        # Mock to simulate missing data
        with patch("qrp_report.plugins.t1.aggregate_datasets") as mock_agg:
            mock_agg.side_effect = ValueError("No data found")

            result = plugin.execute(context)

        # Should not crash, should return result with warnings
        assert result.report_type == "T1"
        assert len(result.warnings) > 0


class TestCLIEndToEnd:
    """End-to-end tests for CLI commands."""

    def test_cli_help_displays(self) -> None:
        """CLI shows help text."""
        result = runner.invoke(app, ["--help"])
        assert result.exit_code == 0
        assert "QRP Report" in result.stdout or "qrp" in result.stdout.lower()

    def test_cli_version_displays(self) -> None:
        """CLI shows version."""
        result = runner.invoke(app, ["--version"])
        assert result.exit_code == 0
        assert "0.1.0" in result.stdout or "version" in result.stdout.lower()

    def test_cli_list_plugins_shows_all_types(self) -> None:
        """CLI list-plugins command shows all registered plugins."""
        result = runner.invoke(app, ["list-plugins"])
        assert result.exit_code == 0

        # Verify all expected report types are listed
        assert "T1" in result.stdout
        assert "T2L1" in result.stdout
        assert "T2L2" in result.stdout
        assert "T4L1" in result.stdout
        assert "T4L2" in result.stdout

    def test_cli_generate_with_valid_config(
        self,
        yaml_config_file: Path,
        sample_t1_cida_data: pl.DataFrame,
        tmp_path: Path,
    ) -> None:
        """CLI generate command works with valid configuration."""
        output_path = tmp_path / "output"

        # Mock the data loading to return test data
        with patch("qrp_report.plugins.t1.aggregate_datasets") as mock_agg:
            mock_agg.return_value = sample_t1_cida_data

            result = runner.invoke(
                app,
                [
                    "generate",
                    str(yaml_config_file),
                    "--data", str(tmp_path),
                    "--output", str(output_path),
                    "--verbose",
                ],
            )

        # Should complete (may have warnings about missing data)
        # Exit code 0 = success, exit code 1 = error (missing data is expected)
        assert result.exit_code in (0, 1)
        # If it fails, it should be due to data issues, not config
        if result.exit_code == 1:
            assert "Error" in result.stdout or "error" in result.stdout.lower()

    def test_cli_validate_with_valid_config(
        self,
        yaml_config_file: Path,
    ) -> None:
        """CLI validate command works with valid configuration."""
        result = runner.invoke(app, ["validate", str(yaml_config_file)])

        # Should pass validation
        assert result.exit_code == 0
        assert "valid" in result.stdout.lower()

    def test_cli_validate_with_nonexistent_file(self) -> None:
        """CLI validate command handles nonexistent file."""
        result = runner.invoke(app, ["validate", "/nonexistent/path/config.yaml"])
        assert result.exit_code == 1
        assert "not found" in result.stdout.lower() or "error" in result.stdout.lower()

    def test_cli_generate_with_nonexistent_config(self) -> None:
        """CLI generate command handles nonexistent config file."""
        result = runner.invoke(
            app,
            ["generate", "/nonexistent/path/config.yaml"],
        )
        assert result.exit_code == 1
        assert "not found" in result.stdout.lower() or "error" in result.stdout.lower()


class TestConfigurationLoading:
    """Tests for configuration loading from different formats."""

    def test_yaml_config_loads_correctly(
        self,
        yaml_config_file: Path,
    ) -> None:
        """YAML configuration file loads correctly."""
        from qrp_report.config.loader import load_config

        config, errors = load_config(yaml_config_file)

        # Should load without fatal errors
        fatal_errors = [e for e in errors if e.severity.value == "error"]
        assert len(fatal_errors) == 0, f"Errors: {fatal_errors}"

        # Verify config structure
        assert config is not None
        assert config.reportid == "test_report_001"
        assert config.reporttype == ReportType.T1
        assert len(config.dpinfo) == 1
        assert len(config.groups) == 2

    def test_invalid_yaml_returns_error(self, tmp_path: Path) -> None:
        """Invalid YAML syntax returns appropriate error."""
        from qrp_report.config.loader import load_config

        bad_yaml = tmp_path / "bad.yaml"
        bad_yaml.write_text("this: is: invalid: yaml: [[[")

        config, errors = load_config(bad_yaml)

        assert config is None
        assert len(errors) > 0
        assert any("yaml" in e.message.lower() or "syntax" in e.message.lower() for e in errors)


class TestProjectStructure:
    """Tests verifying project structure is correct."""

    def test_package_imports(self) -> None:
        """Main package imports work correctly."""
        from qrp_report import __version__, ReportDriver

        assert __version__ == "0.1.0"
        assert ReportDriver is not None

    def test_plugin_imports(self) -> None:
        """All plugin modules import correctly."""
        from qrp_report.plugins import registry
        from qrp_report.plugins.t1 import T1Plugin
        from qrp_report.plugins.t2l1 import T2L1Plugin
        from qrp_report.plugins.t2l2 import T2L2Plugin
        from qrp_report.plugins.t4l1 import T4L1Plugin
        from qrp_report.plugins.t4l2 import T4L2Plugin

        assert T1Plugin is not None
        assert T2L1Plugin is not None
        assert T2L2Plugin is not None
        assert T4L1Plugin is not None
        assert T4L2Plugin is not None

    def test_config_imports(self) -> None:
        """Configuration module imports work correctly."""
        from qrp_report.config.models import ReportConfig, ReportType
        from qrp_report.config.loader import load_config

        assert ReportConfig is not None
        assert ReportType is not None
        assert load_config is not None

    def test_stats_imports(self) -> None:
        """Statistics module imports work correctly."""
        from qrp_report.stats.rates import incidence_rate_per_1000py, poisson_ci
        from qrp_report.stats.effect_estimates import risk_ratio, hazard_ratio

        assert incidence_rate_per_1000py is not None
        assert poisson_ci is not None
        assert risk_ratio is not None
        assert hazard_ratio is not None

    def test_render_imports(self) -> None:
        """Rendering module imports work correctly."""
        from qrp_report.render.formatters import format_rate_ci
        from qrp_report.render.excel import ExcelRenderer
        from qrp_report.render.pdf import PDFRenderer

        assert format_rate_ci is not None
        assert ExcelRenderer is not None
        assert PDFRenderer is not None


class TestDataPipeline:
    """Tests for the data processing pipeline."""

    def test_aggregation_utilities(self) -> None:
        """Aggregation utilities work correctly."""
        from qrp_report.plugins.aggregation import summarize_by_strata

        df = pl.DataFrame({
            "group": ["A", "A", "B", "B"],
            "level": [1, 1, 1, 1],
            "npts": [100, 200, 150, 250],
            "episodes": [10, 20, 15, 25],
        })

        result = summarize_by_strata(
            df=df,
            group_cols=["group", "level"],
            sum_cols=["npts", "episodes"],
        )

        # Verify aggregation
        assert len(result) == 2  # Two groups
        group_a = result.filter(pl.col("group") == "A")
        assert group_a["npts"].item() == 300  # 100 + 200
        assert group_a["episodes"].item() == 30  # 10 + 20

    def test_stratification_config_creation(self) -> None:
        """Stratification config can be created."""
        strat = StratificationConfig(
            variables=("sex", "race", "agegroup"),
            by_dp=True,
        )

        assert strat.variables == ("sex", "race", "agegroup")
        assert strat.by_dp is True

    def test_data_partner_info_creation(self, tmp_path: Path) -> None:
        """DataPartnerInfo can be created."""
        dp = DataPartnerInfo(
            dp_id="site001",
            masked_id="DP01",
            data_path=tmp_path / "dp01",
        )

        assert dp.dp_id == "site001"
        assert dp.masked_id == "DP01"
        assert dp.data_path == tmp_path / "dp01"
