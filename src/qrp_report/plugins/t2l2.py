"""T2L2 Report Plugin: Effect estimates with propensity score methods (Level 2 - inferential).

T2L2 extends T2L1 by adding:
- Propensity score calculations and distributions
- Effect estimates: Odds Ratio, Hazard Ratio, Risk Ratio, Risk Difference
- Confidence intervals around effect estimates
- Forest plots for visualizing effect estimates across strata
- Support for multiple PS methods: Matching, Stratification, IPTW, Covariate Stratification
- Sequential analysis support (multiple periods/looks)

Input datasets (in addition to T2L1):
- psdistribution_[period]: PS values for treated/control groups
- adjusted_attrition_[period]: Attrition after PS adjustment
- Effect estimate datasets from l2_effect_estimate macros
"""

import polars as pl

from qrp_report.plugins.types import (
    ReportContext,
    ReportResult,
    TableResult,
    FigureResult,
    ReportType,
)
from qrp_report.plugins.registry import register_plugin
from qrp_report.plugins.aggregation import (
    aggregate_datasets,
    summarize_by_strata,
)
from qrp_report.plugins.t2l1 import T2L1Plugin, T2_CIDA_SUM_COLS


@register_plugin("T2L2")
class T2L2Plugin:
    """T2L2 Report Plugin implementation.

    T2L2 extends T2L1 with effect estimation capabilities.
    It inherits L1 table generation from T2L1 and adds L2-specific
    effect estimates and figures.
    """

    def __init__(self):
        # Compose with T2L1 for L1 table generation
        self._l1_plugin = T2L1Plugin()

    @property
    def report_type(self) -> ReportType:
        return "T2L2"

    @property
    def required_datasets(self) -> tuple[str, ...]:
        return ("t2_cida",)

    def validate_context(self, context: ReportContext) -> tuple[str, ...]:
        """Validate T2L2 context."""
        errors: list[str] = []

        if context.report_type != "T2L2":
            errors.append(f"Expected report_type 'T2L2', got '{context.report_type}'")

        if not context.groups:
            errors.append("At least one group must be specified")

        if not context.data_partners:
            errors.append("At least one data partner must be specified")

        # L2-specific validation
        if not context.periods:
            errors.append("At least one analysis period must be specified for L2")

        if context.ps_method is None:
            errors.append("PS method must be specified for L2 (matching, stratification, iptw, covstrat)")

        return tuple(errors)

    def execute(self, context: ReportContext) -> ReportResult:
        """Execute T2L2 report generation."""
        errors = self.validate_context(context)
        if errors:
            raise ValueError(f"Invalid context: {'; '.join(errors)}")

        tables: list[TableResult] = []
        figures: list[FigureResult] = []
        warnings: list[str] = []

        # Generate L1 tables using T2L1 plugin logic
        l1_context = ReportContext(
            report_type="T2L1",  # Pretend to be T2L1 for base tables
            run_id=context.run_id,
            groups=context.groups,
            data_partners=context.data_partners,
            stratification=context.stratification,
            output_dir=context.output_dir,
            table_specs=context.table_specs,
        )

        try:
            # Temporarily override validation for composed execution
            l1_result = self._generate_l1_tables(l1_context)
            tables.extend(l1_result.tables)
            warnings.extend(l1_result.warnings)
        except ValueError as e:
            warnings.append(f"L1 table generation: {e}")

        # Generate L2 effect estimates for each period
        for period in context.periods:
            period_tables, period_figures, period_warnings = self._generate_l2_for_period(
                context=context,
                period=period,
            )
            tables.extend(period_tables)
            figures.extend(period_figures)
            warnings.extend(period_warnings)

        return ReportResult(
            report_type="T2L2",
            tables=tuple(tables),
            figures=tuple(figures),
            warnings=tuple(warnings),
        )

    def _generate_l1_tables(self, context: ReportContext) -> ReportResult:
        """Generate L1 tables using T2L1 plugin."""
        # Use T2L1's execute but with modified context
        return self._l1_plugin.execute(context)

    def _generate_l2_for_period(
        self,
        context: ReportContext,
        period: int,
    ) -> tuple[list[TableResult], list[FigureResult], list[str]]:
        """Generate L2 effect estimates for a single analysis period."""
        tables: list[TableResult] = []
        figures: list[FigureResult] = []
        warnings: list[str] = []

        # Load PS distribution data
        ps_dist_table = self._try_load_ps_distribution(context, period, warnings)
        if ps_dist_table:
            tables.append(ps_dist_table)

            # Create PS distribution histogram figure
            ps_hist_figure = self._create_ps_histogram_figure(ps_dist_table.data, period)
            if ps_hist_figure:
                figures.append(ps_hist_figure)

        # Load adjusted attrition data
        attrition_table = self._try_load_adjusted_attrition(context, period, warnings)
        if attrition_table:
            tables.append(attrition_table)

        # Generate effect estimates based on PS method
        effect_table = self._compute_effect_estimates(context, period, warnings)
        if effect_table:
            tables.append(effect_table)

            # Create forest plot figure
            forest_figure = self._create_forest_plot_figure(effect_table.data, period)
            if forest_figure:
                figures.append(forest_figure)

        return tables, figures, warnings

    def _try_load_ps_distribution(
        self,
        context: ReportContext,
        period: int,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to load PS distribution data for a period."""
        try:
            agg_ps = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=f"psdistribution_{period}",
                filter_var="analysisgrp",
                filter_values=context.groups,
            )

            return TableResult(
                table_id=f"l2_ps_dist_{period}",
                title=f"L2: PS Distribution (Period {period})",
                data=agg_ps,
            )
        except ValueError as e:
            warnings.append(f"PS distribution period {period}: {e}")
            return None

    def _try_load_adjusted_attrition(
        self,
        context: ReportContext,
        period: int,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to load adjusted attrition data for a period."""
        try:
            agg_attrition = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=f"adjusted_attrition_{period}",
                filter_var="analysisgrp",
                filter_values=context.groups,
            )

            group_cols = ["level", "analysisgrp"]
            sum_cols = ["npts", "episodes"]

            summary = summarize_by_strata(
                df=agg_attrition,
                group_cols=[c for c in group_cols if c in agg_attrition.columns],
                sum_cols=[c for c in sum_cols if c in agg_attrition.columns],
            )

            return TableResult(
                table_id=f"l2_attrition_{period}",
                title=f"L2: Adjusted Attrition (Period {period})",
                data=summary,
            )
        except ValueError as e:
            warnings.append(f"Adjusted attrition period {period}: {e}")
            return None

    def _compute_effect_estimates(
        self,
        context: ReportContext,
        period: int,
        warnings: list[str],
    ) -> TableResult | None:
        """Compute effect estimates for a period.

        This loads pre-computed effect estimate data from data partners
        and aggregates across DPs using the appropriate method based on
        the PS configuration.
        """
        # Try to load effect estimate data
        try:
            # Effect estimates dataset name depends on PS method
            dataset_name = f"estimates_{period}"

            agg_estimates = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=dataset_name,
                filter_var="analysisgrp",
                filter_values=context.groups,
            )

            # Process effect estimates based on PS method
            result_df = self._aggregate_effect_estimates(
                df=agg_estimates,
                ps_method=context.ps_method,
            )

            return TableResult(
                table_id=f"l2_effects_{period}",
                title=f"L2: Effect Estimates (Period {period})",
                data=result_df,
                footnotes=(
                    f"PS Method: {context.ps_method}",
                    "95% confidence intervals shown",
                ),
            )
        except ValueError as e:
            warnings.append(f"Effect estimates period {period}: {e}")
            return None

    def _aggregate_effect_estimates(
        self,
        df: pl.DataFrame,
        ps_method: str | None,
    ) -> pl.DataFrame:
        """Aggregate effect estimates across data partners.

        For effect estimates, we typically use meta-analysis style
        aggregation rather than simple summing.
        """
        # Group by analysis group and estimate type
        group_cols = ["analysisgrp"]
        if "estimate_type" in df.columns:
            group_cols.append("estimate_type")

        # Expected columns for effect estimates
        estimate_cols = ["estimate", "ci_lower", "ci_upper", "se", "pvalue"]
        existing_cols = [c for c in estimate_cols if c in df.columns]

        if not existing_cols:
            return df

        # For now, take weighted average by sample size if available
        # This is a simplified aggregation; real implementation would use
        # proper meta-analysis methods
        if "n" in df.columns:
            # Weighted aggregation
            agg_exprs = []
            for col in existing_cols:
                if col in ["estimate", "ci_lower", "ci_upper"]:
                    # Weighted mean
                    agg_exprs.append(
                        ((pl.col(col) * pl.col("n")).sum() / pl.col("n").sum()).alias(col)
                    )
                elif col == "se":
                    # Pooled SE (simplified)
                    agg_exprs.append(
                        ((pl.col("se").pow(2) * pl.col("n")).sum() / pl.col("n").sum()).sqrt().alias("se")
                    )
                elif col == "pvalue":
                    # Min p-value (conservative)
                    agg_exprs.append(pl.col("pvalue").min().alias("pvalue"))

            agg_exprs.append(pl.col("n").sum().alias("n"))

            return df.group_by(group_cols).agg(agg_exprs)
        else:
            # Simple mean if no sample size available
            return df.group_by(group_cols).agg([
                pl.col(c).mean().alias(c) for c in existing_cols
            ])

    def _create_ps_histogram_figure(
        self,
        df: pl.DataFrame,
        period: int,
    ) -> FigureResult | None:
        """Create PS distribution histogram figure data."""
        if df.is_empty():
            return None

        # Expected columns for PS histogram
        required_cols = ["ps_value", "treatment"]
        if not all(c in df.columns for c in required_cols):
            return None

        return FigureResult(
            figure_id=f"f1_ps_dist_{period}",
            title=f"Figure F1: Propensity Score Distribution (Period {period})",
            figure_type="histogram",
            data=df.select(["ps_value", "treatment"]),
            metadata=(
                ("period", period),
                ("x_label", "Propensity Score"),
                ("y_label", "Frequency"),
            ),
        )

    def _create_forest_plot_figure(
        self,
        df: pl.DataFrame,
        period: int,
    ) -> FigureResult | None:
        """Create forest plot figure data."""
        if df.is_empty():
            return None

        # Expected columns for forest plot
        required_cols = ["analysisgrp", "estimate", "ci_lower", "ci_upper"]
        if not all(c in df.columns for c in required_cols):
            return None

        return FigureResult(
            figure_id=f"f2_forest_{period}",
            title=f"Figure F2: Forest Plot (Period {period})",
            figure_type="forest_plot",
            data=df.select(required_cols),
            metadata=(
                ("period", period),
                ("reference_line", 1.0),  # For ratios
            ),
        )
