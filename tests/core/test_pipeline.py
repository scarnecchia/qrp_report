"""Tests for report pipeline."""

from pathlib import Path

import polars as pl
import pytest

from qrp_report.config.errors import ValidationMessage
from qrp_report.config.models import DPInfo, ReportConfig, ReportType
from qrp_report.core.interfaces import Figure, ReportData, ReportPlugin, Table
from qrp_report.core.pipeline import PipelineContext, PipelineStage, ReportPipeline
from qrp_report.core.registry import clear_registry, register_plugin


class MockPlugin(ReportPlugin):
    """Mock plugin for testing."""

    @property
    def report_type(self) -> str:
        return "T1"

    @property
    def description(self) -> str:
        return "Mock T1 plugin"

    @property
    def supported_tables(self) -> list[str]:
        return ["1a"]

    @property
    def supported_figures(self) -> list[str]:
        return ["F1"]

    def validate_config(self, config: ReportConfig) -> list[ValidationMessage]:
        return []

    def aggregate_data(
        self, dp_data: dict[str, pl.LazyFrame], config: ReportConfig
    ) -> dict[str, pl.DataFrame]:
        return {"t1_cida": pl.DataFrame({"count": [100, 200]})}

    def compute_statistics(
        self, data: dict[str, pl.DataFrame], config: ReportConfig
    ) -> ReportData:
        return ReportData(
            config=config,
            aggregated_data=data,
            computed_stats={"total": 300},
        )

    def get_tables(self, data: ReportData) -> list[Table]:
        return [Table(id="1a", title="Test Table")]

    def get_figures(self, data: ReportData) -> list[Figure]:
        return []


@pytest.fixture(autouse=True)
def setup_registry() -> None:
    """Set up registry with mock plugin."""
    clear_registry()

    @register_plugin
    class TestPlugin(MockPlugin):
        pass

    yield
    clear_registry()


@pytest.fixture
def valid_config() -> ReportConfig:
    """Create valid test configuration."""
    return ReportConfig(
        reportid="test_001",
        reporttype=ReportType.T1,
        dpinfo=[
            DPInfo(dp="dp01", dpname="DP 1", path="/data/dp01", includedp=True),
        ],
    )


class TestPipelineContext:
    """Tests for PipelineContext."""

    def test_initial_state(self, valid_config: ReportConfig) -> None:
        """Test initial context state."""
        ctx = PipelineContext(config=valid_config)

        assert ctx.stage == PipelineStage.INIT
        assert ctx.has_errors is False
        assert ctx.errors == []
        assert ctx.warnings == []

    def test_add_error(self, valid_config: ReportConfig) -> None:
        """Test adding errors."""
        ctx = PipelineContext(config=valid_config)

        from qrp_report.config.errors import ErrorSeverity

        error = ValidationMessage(
            severity=ErrorSeverity.ERROR,
            code="E001",
            message="test error",
        )
        ctx.add_error(error)

        assert ctx.has_errors is True
        assert len(ctx.errors) == 1

    def test_add_warning(self, valid_config: ReportConfig) -> None:
        """Test adding warnings."""
        ctx = PipelineContext(config=valid_config)

        from qrp_report.config.errors import ErrorSeverity

        warning = ValidationMessage(
            severity=ErrorSeverity.WARNING,
            code="W001",
            message="test warning",
        )
        ctx.add_error(warning)

        assert ctx.has_errors is False  # Warnings don't count as errors
        assert len(ctx.warnings) == 1


class TestReportPipeline:
    """Tests for ReportPipeline."""

    def test_pipeline_creation(
        self, valid_config: ReportConfig, tmp_path: Path
    ) -> None:
        """Test pipeline creation."""
        pipeline = ReportPipeline(
            config=valid_config,
            dataroot=tmp_path,
            output_dir=tmp_path / "output",
        )

        assert pipeline.config == valid_config
        assert pipeline.dataroot == tmp_path

    def test_pipeline_validation_failure(self, tmp_path: Path) -> None:
        """Test pipeline fails on validation error."""
        # Config with no DPs
        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T1,
            dpinfo=[],
        )

        pipeline = ReportPipeline(
            config=config,
            dataroot=tmp_path,
        )
        result = pipeline.run()

        assert result.has_errors
        assert result.stage == PipelineStage.FAILED

    def test_pipeline_unknown_report_type(self, tmp_path: Path) -> None:
        """Test pipeline fails for unknown report type."""
        # Clear registry to ensure no T2L1 plugin
        clear_registry()

        config = ReportConfig(
            reportid="test",
            reporttype=ReportType.T2L1,
            dpinfo=[DPInfo(dp="dp01", dpname="DP", path="/data", includedp=True)],
        )

        pipeline = ReportPipeline(config=config, dataroot=tmp_path)
        result = pipeline.run()

        assert result.has_errors
        # Error should mention no plugin registered

    def test_progress_callback(
        self, valid_config: ReportConfig, tmp_path: Path
    ) -> None:
        """Test progress callback is called."""
        pipeline = ReportPipeline(
            config=valid_config,
            dataroot=tmp_path,
        )

        progress_calls: list[tuple[str, float]] = []

        def callback(stage: str, progress: float) -> None:
            progress_calls.append((stage, progress))

        pipeline.run(progress_callback=callback)

        assert len(progress_calls) > 0
        assert progress_calls[-1][1] == 1.0  # Final call should be 100%
