"""Report generation driver.

Coordinates plugin selection and report generation workflow.
"""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from qrp_report.plugins.registry import get_plugin, list_plugins
from qrp_report.plugins.types import (
    ReportContext,
    ReportResult,
    DataPartnerInfo,
    StratificationConfig,
    ReportType,
)

if TYPE_CHECKING:
    from qrp_report.config.models import ReportConfig
    from qrp_report.plugins.types import ReportPlugin


class ReportDriver:
    """Driver for report generation workflow.

    Handles plugin selection, context creation, and report generation
    orchestration.
    """

    def get_plugin(self, report_type: str) -> ReportPlugin:
        """Get plugin instance for specified report type.

        Args:
            report_type: Report type identifier (T1, T2L1, etc.).

        Returns:
            Plugin instance for the report type.

        Raises:
            ValueError: If report type is unknown.
        """
        try:
            plugin_cls = get_plugin(report_type)  # type: ignore[arg-type]
            return plugin_cls()
        except KeyError:
            available = ", ".join(self.available_report_types())
            raise ValueError(
                f"Unknown report type: {report_type}. "
                f"Available types: {available}"
            ) from None

    def available_report_types(self) -> list[str]:
        """List all available report types.

        Returns:
            List of registered report type identifiers.
        """
        return list(list_plugins())

    def generate_report(
        self,
        config: ReportConfig,
        data_path: Path,
        output_path: Path,
    ) -> ReportResult:
        """Generate report using appropriate plugin.

        Args:
            config: Report configuration.
            data_path: Path to input data directory.
            output_path: Path for output files.

        Returns:
            Generated report result.
        """
        # Get plugin for configured report type
        report_type_str = (
            config.reporttype.value
            if hasattr(config.reporttype, "value")
            else str(config.reporttype)
        )
        plugin = self.get_plugin(report_type_str)

        # Build data partner info from config
        data_partners = tuple(
            DataPartnerInfo(
                dp_id=dp.dp,
                masked_id=dp.dp,
                data_path=data_path / dp.dp,
            )
            for dp in config.dpinfo
            if dp.includedp
        )

        # Build stratification config if applicable
        stratification: StratificationConfig | None = None
        if config.stratifybydp:
            stratification = StratificationConfig(
                variables=(),
                by_dp=True,
            )

        # Extract groups from config
        groups = tuple(g.group for g in config.groups)

        # Create context for generation
        context = ReportContext(
            report_type=report_type_str,  # type: ignore[arg-type]
            run_id=config.reportid,
            groups=groups,
            data_partners=data_partners,
            stratification=stratification,
            output_dir=output_path,
        )

        # Generate report
        return plugin.execute(context)

    def validate_config(self, config: ReportConfig) -> list[str]:
        """Validate configuration for report generation.

        Args:
            config: Configuration to validate.

        Returns:
            List of validation error messages (empty if valid).
        """
        errors: list[str] = []

        # Extract report type string
        report_type_str = (
            config.reporttype.value
            if hasattr(config.reporttype, "value")
            else str(config.reporttype)
        )

        # Check report type is known
        if report_type_str not in self.available_report_types():
            errors.append(f"Unknown report type: {report_type_str}")
            return errors  # Can't validate further

        # Get plugin for additional validation
        try:
            plugin = self.get_plugin(report_type_str)
            # Check required datasets are documented
            _ = plugin.required_datasets
        except ValueError as e:
            errors.append(str(e))

        # Check data partners are configured
        if not config.dpinfo:
            errors.append("No data partners configured")

        # Check groups are configured
        if not config.groups:
            errors.append("No analysis groups configured")

        return errors
