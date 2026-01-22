"""Cross-field validation rules for QRP Report configuration.

Mirrors the 23 validation abort points from SAS process_inputfiles.sas.
"""

from qrp_report.config.errors import ErrorSeverity, ValidationMessage
from qrp_report.config.models import ReportConfig, ReportType


class ConfigValidator:
    """Validates ReportConfig with cross-field rules."""

    def __init__(self, config: ReportConfig) -> None:
        """Initialize validator with config to validate."""
        self.config = config
        self.errors: list[ValidationMessage] = []

    def validate(self) -> list[ValidationMessage]:
        """Run all validation rules.

        Returns:
            List of validation errors and warnings.
        """
        self.errors = []

        # File existence validations
        self._validate_dpinfo_required()
        self._validate_dpinfo_included()

        # Cross-reference validations
        self._validate_baseline_order_uniqueness()
        self._validate_figures_require_groups()
        self._validate_figures_includeinfigure()

        # Report-type-specific validations
        self._validate_l2_specific()
        self._validate_l1_specific()
        self._validate_t6_specific()

        return self.errors

    def _validate_dpinfo_required(self) -> None:
        """E002: DPINFOFILE required unless appendix-only report."""
        # For now, assume all reports need dpinfo
        # TODO: Add appendix-only detection when appendixfile support is added
        if not self.config.dpinfo:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E002",
                    message="DPINFOFILE is missing",
                    location="dpinfo",
                    suggestion="add at least one Data Partner to the dpinfo configuration",
                )
            )

    def _validate_dpinfo_included(self) -> None:
        """E003: At least one DP must have includedp=True."""
        if not self.config.dpinfo:
            return  # Already caught by E002

        included_count = sum(1 for dp in self.config.dpinfo if dp.includedp)
        if included_count == 0:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E003",
                    message="no Data Partners included (all have includedp=false)",
                    location="dpinfo",
                    suggestion="set includedp=true for at least one Data Partner",
                )
            )

    def _validate_baseline_order_uniqueness(self) -> None:
        """E040, E041, E042: Validate ORDER/BASELINEGROUPNUM combinations."""
        if not self.config.baseline:
            return

        # Group by order value
        order_groups: dict[int, list[tuple[str, int | None]]] = {}
        for b in self.config.baseline:
            if b.order not in order_groups:
                order_groups[b.order] = []
            order_groups[b.order].append((b.runid, b.baselinegroupnum))

        for order, entries in order_groups.items():
            runids = [e[0] for e in entries]
            groupnums = [e[1] for e in entries]

            # E040: ORDER cannot repeat across different RUNIDs
            unique_runids = set(runids)
            if len(unique_runids) > 1:
                self.errors.append(
                    ValidationMessage(
                        severity=ErrorSeverity.ERROR,
                        code="E040",
                        message=(
                            f"ORDER value {order} repeats across different "
                            f"RUNIDs: {unique_runids}"
                        ),
                        location=f"baseline[order={order}]",
                        suggestion="ensure each ORDER value is unique within a single RUNID",
                    )
                )

            # E041: ORDER repeats within RUNID require BASELINEGROUPNUM
            if len(entries) > 1 and any(g is None for g in groupnums):
                self.errors.append(
                    ValidationMessage(
                        severity=ErrorSeverity.ERROR,
                        code="E041",
                        message=f"ORDER value {order} repeats but BASELINEGROUPNUM not specified",
                        location=f"baseline[order={order}]",
                        suggestion="specify baselinegroupnum (1 or 2) when ORDER values repeat",
                    )
                )

            # E042: Maximum 2 rows per ORDER value
            if len(entries) > 2:
                self.errors.append(
                    ValidationMessage(
                        severity=ErrorSeverity.ERROR,
                        code="E042",
                        message=f"ORDER value {order} has {len(entries)} rows (maximum is 2)",
                        location=f"baseline[order={order}]",
                        suggestion=(
                            "use at most 2 rows per ORDER value with "
                            "baselinegroupnum=1 and baselinegroupnum=2"
                        ),
                    )
                )

    def _validate_figures_require_groups(self) -> None:
        """E033: FIGUREFILE requires GROUPSFILE for L1 reports."""
        if not self.config.figures:
            return

        if self.config.is_l1_report and not self.config.groups:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E033",
                    message="figures requested but groups configuration is missing",
                    location="figures",
                    suggestion="add groups configuration when requesting figures for L1 reports",
                )
            )

    def _validate_figures_includeinfigure(self) -> None:
        """E032: At least one group must have includeinfigure=True for L1 reports."""
        if not self.config.figures or not self.config.is_l1_report:
            return

        if not self.config.groups:
            return  # Already caught by E033

        included_count = sum(1 for g in self.config.groups if g.includeinfigure)
        if included_count == 0:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E032",
                    message="figures requested but no groups have includeinfigure=true",
                    location="groups",
                    suggestion="set includeinfigure=true for at least one group",
                )
            )

    def _validate_l2_specific(self) -> None:
        """Validations specific to L2 report types."""
        if not self.config.is_l2_report:
            return

        # W001: COLLAPSE_VARS ignored for L2
        if self.config.collapse_vars:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.WARNING,
                    code="W001",
                    message="collapse_vars is ignored for L2 reports",
                    location="collapse_vars",
                    suggestion="remove collapse_vars or change to L1 report type",
                )
            )

    def _validate_l1_specific(self) -> None:
        """Validations specific to L1 report types."""
        if not self.config.is_l1_report:
            return

        # W003: COVINPS not relevant for L1
        for i, b in enumerate(self.config.baseline):
            if b.covinps:
                self.errors.append(
                    ValidationMessage(
                        severity=ErrorSeverity.WARNING,
                        code="W003",
                        message="covinps is not relevant for L1 reports",
                        location=f"baseline[{i}].covinps",
                        suggestion="remove covinps or change to L2 report type",
                    )
                )

    def _validate_t6_specific(self) -> None:
        """E031: T6 switch plots require switch analyses."""
        if self.config.reporttype != ReportType.T6:
            return

        if not self.config.figures:
            return

        # Check for switch plot datasets
        switch_datasets = {"t6plota", "t6plotb"}
        has_switch_figures = any(
            f.dataset.lower() in switch_datasets for f in self.config.figures
        )

        if not has_switch_figures:
            return

        # Would need to check groupsfile for switch analyses
        # For now, just warn if groups is empty
        if not self.config.groups:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E031",
                    message="switch plots requested but no groups configured for switch analysis",
                    location="figures",
                    suggestion="add groups with switch analysis configuration",
                )
            )


def validate_config(config: ReportConfig) -> list[ValidationMessage]:
    """Validate configuration with all cross-field rules.

    Args:
        config: ReportConfig to validate.

    Returns:
        List of validation errors and warnings.
    """
    validator = ConfigValidator(config)
    return validator.validate()
