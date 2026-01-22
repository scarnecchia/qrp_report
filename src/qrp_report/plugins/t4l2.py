"""T4L2 Report Plugin: Pregnancy-specific effect estimates analysis.

T4L2 extends T4L1 with:
- Dual effect estimate methods (binary Risk Ratio + timetoevent Hazard Ratio)
- Separate forest plots per method
- PS-adjusted effect estimates
- Composition pattern: includes all T4L1 tables

Input datasets (in addition to T4L1):
- t4_effect_binary: Risk Ratio effect estimates from binary method
- t4_effect_timetoevent: Hazard Ratio effect estimates from time-to-event method
- t4_psdistribution: Propensity score distribution data
- t4_adjusted_attrition: Attrition after PS adjustment
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
from qrp_report.plugins.t4l1 import T4L1Plugin


# Effect estimate methods for T4L2
EFFECT_METHODS: tuple[str, ...] = ("binary", "timetoevent")

# Additional T4L2-specific datasets
T4L2_DATASETS: tuple[str, ...] = (
    "t4_effect_binary",
    "t4_effect_timetoevent",
    "t4_psdistribution",
    "t4_adjusted_attrition",
)


@register_plugin("T4L2")
class T4L2Plugin:
    """Plugin for T4L2 pregnancy-specific effect estimates reports.

    T4L2 extends T4L1 with effect estimation capabilities for pregnancy studies.
    It inherits L1 table generation from T4L1 and adds L2-specific effect
    estimates with dual methods (binary RR and timetoevent HR).
    """

    def __init__(self) -> None:
        """Initialize T4L2 plugin with T4L1 composition."""
        self._l1_plugin = T4L1Plugin()

    @property
    def report_type(self) -> ReportType:
        return "T4L2"

    @property
    def required_datasets(self) -> tuple[str, ...]:
        """T4L2 requires T4L1 datasets plus effect estimate datasets."""
        return self._l1_plugin.required_datasets + T4L2_DATASETS

    @property
    def effect_methods(self) -> tuple[str, ...]:
        """Available effect estimate methods."""
        return EFFECT_METHODS

    @property
    def l1_plugin(self) -> T4L1Plugin:
        """Access to composed L1 plugin for testing."""
        return self._l1_plugin

    def validate_context(self, context: ReportContext) -> tuple[str, ...]:
        """Validate T4L2 context.

        Args:
            context: Report context to validate.

        Returns:
            Tuple of error messages (empty if valid).
        """
        errors: list[str] = []

        if context.report_type != "T4L2":
            errors.append(f"Expected report_type 'T4L2', got '{context.report_type}'")

        if not context.groups:
            errors.append("At least one group must be specified")

        if not context.data_partners:
            errors.append("At least one data partner must be specified")

        # L2-specific validation: require periods for effect estimates
        if not context.periods:
            errors.append("At least one analysis period must be specified for L2")

        return tuple(errors)

    def format_effect_estimates(
        self,
        df: pl.DataFrame,
        *,
        method: str,
    ) -> pl.DataFrame:
        """Format effect estimates for display.

        Args:
            df: Effect estimate dataframe with estimate, lcl, ucl columns.
            method: Effect method ('binary' or 'timetoevent').

        Returns:
            Formatted dataframe with appropriate column names and CI string.
        """
        # Determine measure name based on method
        if method == "binary":
            measure_name = "RR"
        else:
            measure_name = "HR"

        # Rename estimate column to method-specific name
        result = df.with_columns([
            pl.col("estimate").alias(measure_name),
        ])

        # Format confidence interval string
        if "lcl" in df.columns and "ucl" in df.columns:
            result = result.with_columns([
                pl.format(
                    "{} ({}, {})",
                    pl.col(measure_name).round(2),
                    pl.col("lcl").round(2),
                    pl.col("ucl").round(2),
                ).alias(f"{measure_name} (95% CI)"),
            ])

        return result

    def generate_forest_plots(
        self,
        df: pl.DataFrame,
    ) -> list[FigureResult]:
        """Generate separate forest plots for each effect method.

        Args:
            df: Effect estimate data with method column.

        Returns:
            List of FigureResult, one per method.
        """
        figures: list[FigureResult] = []

        for method in self.effect_methods:
            method_data = df.filter(pl.col("method") == method)

            if method_data.is_empty():
                continue

            # Determine measure name
            measure = "RR" if method == "binary" else "HR"

            # Create forest plot data structure
            # Actual rendering handled by rendering module
            figure = FigureResult(
                figure_id=f"forest_{method}",
                title=self._get_forest_title(method),
                figure_type="forest_plot",
                data=method_data,
                metadata=(
                    ("method", method),
                    ("measure", measure),
                    ("reference_line", 1.0),
                ),
            )
            figures.append(figure)

        return figures

    def execute(self, context: ReportContext) -> ReportResult:
        """Execute T4L2 pregnancy effect estimates report.

        Args:
            context: Report generation context.

        Returns:
            Report result with L1 tables and L2 effect estimates.
        """
        errors = self.validate_context(context)
        if errors:
            raise ValueError(f"Invalid context: {'; '.join(errors)}")

        tables: list[TableResult] = []
        figures: list[FigureResult] = []
        warnings: list[str] = []

        # Generate L1 tables using T4L1 plugin logic
        l1_context = ReportContext(
            report_type="T4L1",  # Pretend to be T4L1 for base tables
            run_id=context.run_id,
            groups=context.groups,
            data_partners=context.data_partners,
            stratification=context.stratification,
            output_dir=context.output_dir,
            table_specs=context.table_specs,
        )

        try:
            l1_result = self._l1_plugin.execute(l1_context)
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
            report_type="T4L2",
            tables=tuple(tables),
            figures=tuple(figures),
            warnings=tuple(warnings),
        )

    def _generate_l2_for_period(
        self,
        context: ReportContext,
        period: int,
    ) -> tuple[list[TableResult], list[FigureResult], list[str]]:
        """Generate L2 effect estimates for a single analysis period.

        Args:
            context: Report context.
            period: Analysis period number.

        Returns:
            Tuple of (tables, figures, warnings) for this period.
        """
        tables: list[TableResult] = []
        figures: list[FigureResult] = []
        warnings: list[str] = []

        # Load effect estimates for each method
        all_effects: list[pl.DataFrame] = []

        for method in self.effect_methods:
            effect_table, effect_df = self._try_load_effect_estimates(
                context, method, period, warnings
            )
            if effect_table:
                tables.append(effect_table)
            if effect_df is not None:
                all_effects.append(effect_df.with_columns(pl.lit(method).alias("method")))

        # Generate forest plots from combined effect data
        if all_effects:
            combined_effects = pl.concat(all_effects)
            figures.extend(self.generate_forest_plots(combined_effects))

        # Load PS distribution if available
        ps_dist_table = self._try_load_ps_distribution(context, period, warnings)
        if ps_dist_table:
            tables.append(ps_dist_table)

        # Load adjusted attrition if available
        attrition_table = self._try_load_adjusted_attrition(context, period, warnings)
        if attrition_table:
            tables.append(attrition_table)

        return tables, figures, warnings

    def _try_load_effect_estimates(
        self,
        context: ReportContext,
        method: str,
        period: int,
        warnings: list[str],
    ) -> tuple[TableResult | None, pl.DataFrame | None]:
        """Try to load effect estimates for specific method.

        Args:
            context: Report context.
            method: Effect method ('binary' or 'timetoevent').
            period: Analysis period.
            warnings: Warning list to append to.

        Returns:
            Tuple of (TableResult, raw DataFrame) or (None, None) if not available.
        """
        try:
            dataset_name = f"t4_effect_{method}_{period}"

            agg_estimates = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=dataset_name,
                filter_var="group",
                filter_values=context.groups,
            )

            # Aggregate effect estimates across DPs
            processed = self._aggregate_effect_estimates(agg_estimates)

            # Format for display
            formatted = self.format_effect_estimates(processed, method=method)

            return TableResult(
                table_id=f"l2_effects_{method}_{period}",
                title=self._get_effect_title(method, period),
                data=formatted,
                footnotes=(
                    f"Method: {method}",
                    "95% confidence intervals shown",
                ),
            ), processed
        except ValueError as e:
            warnings.append(f"Effect estimates ({method}) period {period}: {e}")
            return None, None

    def _try_load_ps_distribution(
        self,
        context: ReportContext,
        period: int,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to load PS distribution data for a period.

        Args:
            context: Report context.
            period: Analysis period.
            warnings: Warning list to append to.

        Returns:
            TableResult or None if not available.
        """
        try:
            agg_ps = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=f"t4_psdistribution_{period}",
                filter_var="group",
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
        """Try to load adjusted attrition data for a period.

        Args:
            context: Report context.
            period: Analysis period.
            warnings: Warning list to append to.

        Returns:
            TableResult or None if not available.
        """
        try:
            agg_attrition = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=f"t4_adjusted_attrition_{period}",
                filter_var="group",
                filter_values=context.groups,
            )

            group_cols = ["level", "group"]
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

    def _aggregate_effect_estimates(
        self,
        df: pl.DataFrame,
    ) -> pl.DataFrame:
        """Aggregate effect estimates across data partners.

        For effect estimates, uses weighted aggregation by sample size
        when available.

        Args:
            df: Effect estimate data from multiple DPs.

        Returns:
            Aggregated effect estimates.
        """
        # Group by analysis group
        group_cols = ["group"]
        if "moiname" in df.columns:
            group_cols.append("moiname")

        # Expected columns for effect estimates
        estimate_cols = ["estimate", "lcl", "ucl", "se", "pvalue"]
        existing_cols = [c for c in estimate_cols if c in df.columns]

        if not existing_cols:
            return df

        # Weighted aggregation by sample size if available
        if "n" in df.columns:
            agg_exprs = []
            for col in existing_cols:
                if col in ["estimate", "lcl", "ucl"]:
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

            existing_group = [c for c in group_cols if c in df.columns]
            if existing_group:
                return df.group_by(existing_group).agg(agg_exprs)
            return df.select(agg_exprs)
        else:
            # Simple mean if no sample size available
            existing_group = [c for c in group_cols if c in df.columns]
            if existing_group:
                return df.group_by(existing_group).agg([
                    pl.col(c).mean().alias(c) for c in existing_cols
                ])
            return df.select([pl.col(c).mean().alias(c) for c in existing_cols])

    def _get_effect_title(self, method: str, period: int) -> str:
        """Get title for effect estimate table.

        Args:
            method: Effect method.
            period: Analysis period.

        Returns:
            Human-readable title.
        """
        titles = {
            "binary": f"Risk Ratio Effect Estimates (Period {period})",
            "timetoevent": f"Hazard Ratio Effect Estimates (Period {period})",
        }
        return titles.get(method, f"Effect Estimates ({method}, Period {period})")

    def _get_forest_title(self, method: str) -> str:
        """Get title for forest plot.

        Args:
            method: Effect method.

        Returns:
            Human-readable title.
        """
        titles = {
            "binary": "Forest Plot: Risk Ratios (Binary Method)",
            "timetoevent": "Forest Plot: Hazard Ratios (Time-to-Event)",
        }
        return titles.get(method, f"Forest Plot ({method})")
