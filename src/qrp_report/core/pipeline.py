"""Report generation pipeline orchestration."""

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Callable

import polars as pl
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

from qrp_report.config.errors import ErrorSeverity, ValidationMessage
from qrp_report.config.models import ReportConfig
from qrp_report.config.validation import validate_config
from qrp_report.core.interfaces import Figure, ReportData, ReportPlugin, Table
from qrp_report.core.registry import get_plugin
from qrp_report.io.dp_loader import DPLoader
from qrp_report.io.parquet import write_aggregated_data


class PipelineStage(Enum):
    """Pipeline execution stages."""

    INIT = "init"
    VALIDATE = "validate"
    LOAD = "load"
    AGGREGATE = "aggregate"
    COMPUTE = "compute"
    RENDER = "render"
    COMPLETE = "complete"
    FAILED = "failed"


@dataclass
class PipelineContext:
    """Context object carrying state through pipeline stages.

    Attributes:
        config: Report configuration
        plugin: Report plugin instance
        stage: Current pipeline stage
        errors: Accumulated validation errors
        warnings: Accumulated warnings
        dp_data: Loaded Data Partner data (LazyFrames)
        aggregated_data: Aggregated data (DataFrames)
        report_data: Computed report data
        tables: Generated table definitions
        figures: Generated figure definitions
        output_paths: Paths to generated output files
    """

    config: ReportConfig
    plugin: ReportPlugin | None = None
    stage: PipelineStage = PipelineStage.INIT
    errors: list[ValidationMessage] = field(default_factory=list)
    warnings: list[ValidationMessage] = field(default_factory=list)
    dp_data: dict[str, pl.LazyFrame] = field(default_factory=dict)
    aggregated_data: dict[str, pl.DataFrame] = field(default_factory=dict)
    report_data: ReportData | None = None
    tables: list[Table] = field(default_factory=list)
    figures: list[Figure] = field(default_factory=list)
    output_paths: dict[str, Path] = field(default_factory=dict)

    @property
    def has_errors(self) -> bool:
        """Check if any errors occurred."""
        return len(self.errors) > 0

    def add_error(self, error: ValidationMessage) -> None:
        """Add a validation error."""
        if error.severity == ErrorSeverity.ERROR:
            self.errors.append(error)
        else:
            self.warnings.append(error)

    def add_errors(self, errors: list[ValidationMessage]) -> None:
        """Add multiple validation messages."""
        for error in errors:
            self.add_error(error)


# Type for progress callback
ProgressCallback = Callable[[str, float], None]


class ReportPipeline:
    """Orchestrates report generation through pipeline stages.

    Stages:
    1. Validate: Check configuration and load plugin
    2. Load: Load data from Data Partners
    3. Aggregate: Combine data across DPs
    4. Compute: Run statistical computations
    5. Render: Generate output files

    Usage:
        pipeline = ReportPipeline(config, dataroot)
        result = pipeline.run()
        if result.has_errors:
            for error in result.errors:
                print(error)
        else:
            print(f"Generated: {result.output_paths}")
    """

    def __init__(
        self,
        config: ReportConfig,
        dataroot: Path,
        output_dir: Path | None = None,
        console: Console | None = None,
    ) -> None:
        """Initialize pipeline.

        Args:
            config: Report configuration.
            dataroot: Root directory for Data Partner data.
            output_dir: Output directory for generated files.
            console: Rich console for output (creates one if not provided).
        """
        self.config = config
        self.dataroot = Path(dataroot)
        self.output_dir = Path(output_dir) if output_dir else Path("output")
        self.console = console or Console()
        self.context: PipelineContext | None = None

    def run(self, progress_callback: ProgressCallback | None = None) -> PipelineContext:
        """Run the complete pipeline.

        Args:
            progress_callback: Optional callback for progress updates.
                Called with (stage_name, progress_fraction).

        Returns:
            PipelineContext with results or errors.
        """
        self.context = PipelineContext(config=self.config)

        stages = [
            ("Validating configuration", self._validate),
            ("Loading data", self._load),
            ("Aggregating data", self._aggregate),
            ("Computing statistics", self._compute),
            ("Rendering output", self._render),
        ]

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console,
            transient=True,
        ) as progress:
            task = progress.add_task("Starting...", total=len(stages))

            for i, (description, stage_fn) in enumerate(stages):
                progress.update(task, description=description)
                if progress_callback:
                    progress_callback(description, i / len(stages))

                try:
                    stage_fn()
                except Exception as e:
                    self.context.stage = PipelineStage.FAILED
                    self.context.add_error(
                        ValidationMessage(
                            severity=ErrorSeverity.ERROR,
                            code="E999",
                            message=f"pipeline error: {e}",
                            location=self.context.stage.value,
                        )
                    )
                    break

                if self.context.has_errors:
                    self.context.stage = PipelineStage.FAILED
                    break

                progress.advance(task)

        if not self.context.has_errors:
            self.context.stage = PipelineStage.COMPLETE

        if progress_callback:
            progress_callback("Complete", 1.0)

        return self.context

    def _validate(self) -> None:
        """Validate configuration and load plugin."""
        assert self.context is not None
        self.context.stage = PipelineStage.VALIDATE

        # Run general validation
        errors = validate_config(self.config)
        self.context.add_errors(errors)

        if self.context.has_errors:
            return

        # Load plugin for report type
        try:
            self.context.plugin = get_plugin(self.config.reporttype.value)
        except KeyError as e:
            self.context.add_error(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E100",
                    message=str(e),
                    location="reporttype",
                )
            )
            return

        # Run plugin-specific validation
        plugin_errors = self.context.plugin.validate_config(self.config)
        self.context.add_errors(plugin_errors)

    def _load(self) -> None:
        """Load data from Data Partners."""
        assert self.context is not None
        assert self.context.plugin is not None
        self.context.stage = PipelineStage.LOAD

        # Create DP loader
        loader = DPLoader(
            dataroot=self.dataroot,
            dp_info=self.config.dpinfo,
            seed=self.config.seed,
        )

        # Store DP masks in metadata (will be used later)
        if self.context.report_data is None:
            self.context.report_data = ReportData(config=self.config)
        self.context.report_data.metadata["dp_masks"] = loader.get_dp_masks()

        # For now, we'll let the plugin's aggregate_data handle loading
        # This stage just sets up the loader info in context
        self.context.dp_data = {}  # Placeholder - actual loading in aggregate

    def _aggregate(self) -> None:
        """Aggregate data across Data Partners."""
        assert self.context is not None
        assert self.context.plugin is not None
        self.context.stage = PipelineStage.AGGREGATE

        # Let plugin handle aggregation
        self.context.aggregated_data = self.context.plugin.aggregate_data(
            self.context.dp_data,
            self.config,
        )

        # Save intermediate data as Parquet
        if self.context.aggregated_data:
            msoc_dir = self.output_dir / "msocdata"
            write_aggregated_data(
                self.context.aggregated_data,
                msoc_dir,
                prefix=f"{self.config.reportid}_",
            )

    def _compute(self) -> None:
        """Compute statistics from aggregated data."""
        assert self.context is not None
        assert self.context.plugin is not None
        self.context.stage = PipelineStage.COMPUTE

        self.context.report_data = self.context.plugin.compute_statistics(
            self.context.aggregated_data,
            self.config,
        )

    def _render(self) -> None:
        """Generate output files from computed data."""
        assert self.context is not None
        assert self.context.plugin is not None
        assert self.context.report_data is not None
        self.context.stage = PipelineStage.RENDER

        # Get tables and figures from plugin
        self.context.tables = self.context.plugin.get_tables(self.context.report_data)
        self.context.figures = self.context.plugin.get_figures(self.context.report_data)

        # Note: Actual rendering to Excel/PDF will be handled by renderers
        # in Phase 6. For now, we just collect the table/figure definitions.
        self.context.output_paths["reportdata"] = self.output_dir / "reportdata"
