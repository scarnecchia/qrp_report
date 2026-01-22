"""T1 Report Plugin: Background rates and population statistics.

T1 reports provide descriptive statistics for study populations including:
- Patient counts and demographics
- Episode counts and distributions
- Incidence rates with confidence intervals
- Stratification by sex, race, age group, region, etc.

Input datasets:
- t1_cida: Main Type 1 data (npts, episodes, etc.)
- censor_cida: Censoring information (optional)
"""

from dataclasses import dataclass

import polars as pl

from qrp_report.plugins.types import (
    ReportPlugin,
    ReportContext,
    ReportResult,
    TableResult,
    ReportType,
)
from qrp_report.plugins.registry import register_plugin
from qrp_report.plugins.aggregation import (
    aggregate_datasets,
    summarize_by_strata,
)
from qrp_report.stats import (
    incidence_rate,
    risk_per_1000,
)


# Columns to sum for T1 cida
T1_CIDA_SUM_COLS = (
    "npts",
    "episodes",
    "adjustedcodecount",
    "rawcodecount",
    "daysupp",
    "amtsupp",
    "dennumpts",
    "dennummemdays",
    "timetocensor",
)


@register_plugin("T1")
class T1Plugin:
    """T1 Report Plugin implementation."""

    @property
    def report_type(self) -> ReportType:
        return "T1"

    @property
    def required_datasets(self) -> tuple[str, ...]:
        return ("t1_cida",)

    def validate_context(self, context: ReportContext) -> tuple[str, ...]:
        """Validate T1 context."""
        errors: list[str] = []

        if context.report_type != "T1":
            errors.append(f"Expected report_type 'T1', got '{context.report_type}'")

        if not context.groups:
            errors.append("At least one group must be specified")

        if not context.data_partners:
            errors.append("At least one data partner must be specified")

        return tuple(errors)

    def execute(self, context: ReportContext) -> ReportResult:
        """Execute T1 report generation."""
        # Validate first
        errors = self.validate_context(context)
        if errors:
            raise ValueError(f"Invalid context: {'; '.join(errors)}")

        tables: list[TableResult] = []
        warnings: list[str] = []

        # Load and aggregate t1_cida
        try:
            agg_t1cida = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="t1_cida",
                filter_var="group",
                filter_values=context.groups,
            )
        except ValueError as e:
            warnings.append(f"t1_cida: {e}")
            return ReportResult(
                report_type="T1",
                tables=(),
                warnings=tuple(warnings),
            )

        # Build group columns for summarization
        group_cols = ["level", "group"]
        if context.stratification:
            group_cols.extend(context.stratification.variables)

        # Summarize by strata
        summary = summarize_by_strata(
            df=agg_t1cida,
            group_cols=group_cols,
            sum_cols=list(T1_CIDA_SUM_COLS),
        )

        # Compute rates and CIs
        result_df = self._compute_t1_rates(summary)

        # Create main T1 table
        tables.append(TableResult(
            table_id="t1_main",
            title="T1: Background Rates",
            data=result_df,
            stratification=",".join(context.stratification.variables) if context.stratification else None,
        ))

        # Optionally load censor data
        try:
            agg_censor = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="censor_cida",
                filter_var="group",
                filter_values=context.groups,
            )
            censor_table = self._create_censor_table(agg_censor, context)
            tables.append(censor_table)
        except ValueError:
            # Censor data is optional
            pass

        # Add DP-stratified table if requested
        if context.stratification and context.stratification.by_dp:
            dp_table = self._create_dp_stratified_table(agg_t1cida, context)
            tables.append(dp_table)

        return ReportResult(
            report_type="T1",
            tables=tuple(tables),
            warnings=tuple(warnings),
        )

    def _compute_t1_rates(self, df: pl.DataFrame) -> pl.DataFrame:
        """Compute T1 rates and confidence intervals.

        Adds computed columns:
        - rate_1000py: Incidence rate per 1000 person-years
        - rate_ci_lower, rate_ci_upper: 95% CI for rate
        - risk_1000nu: Risk per 1000 new users
        - risk_ci_lower, risk_ci_upper: 95% CI for risk
        """
        # Compute person-years from dennummemdays (days -> years)
        df = df.with_columns([
            (pl.col("dennummemdays") / 365.25).alias("person_years"),
        ])

        # Compute rates using vectorized operations
        # Incidence rate: episodes / person-years * 1000
        df = df.with_columns([
            pl.when(pl.col("person_years") > 0)
            .then(pl.col("episodes") / pl.col("person_years") * 1000)
            .otherwise(None)
            .alias("rate_1000py"),
        ])

        # Poisson CI for rate: exp(log(rate) +/- 1.96 * sqrt(1/events))
        z = 1.96

        df = df.with_columns([
            pl.when((pl.col("episodes") > 0) & (pl.col("rate_1000py").is_not_null()))
            .then(
                pl.col("rate_1000py") *
                ((-z * (1.0 / pl.col("episodes").sqrt())).exp())
            )
            .otherwise(None)
            .alias("rate_ci_lower"),

            pl.when((pl.col("episodes") > 0) & (pl.col("rate_1000py").is_not_null()))
            .then(
                pl.col("rate_1000py") *
                ((z * (1.0 / pl.col("episodes").sqrt())).exp())
            )
            .otherwise(None)
            .alias("rate_ci_upper"),
        ])

        # Risk per 1000 new users: episodes / npts * 1000
        df = df.with_columns([
            pl.when(pl.col("npts") > 0)
            .then(pl.col("episodes") / pl.col("npts") * 1000)
            .otherwise(None)
            .alias("risk_1000nu"),
        ])

        # Binomial CI for risk: p +/- 1.96 * sqrt(p*(1-p)/n)
        df = df.with_columns([
            (pl.col("episodes") / pl.col("npts")).alias("_p"),
        ])

        df = df.with_columns([
            pl.when(pl.col("npts") > 0)
            .then(
                (pl.col("_p") - z * (pl.col("_p") * (1 - pl.col("_p")) / pl.col("npts")).sqrt()) * 1000
            )
            .otherwise(None)
            .alias("risk_ci_lower"),

            pl.when(pl.col("npts") > 0)
            .then(
                (pl.col("_p") + z * (pl.col("_p") * (1 - pl.col("_p")) / pl.col("npts")).sqrt()) * 1000
            )
            .otherwise(None)
            .alias("risk_ci_upper"),
        ])

        # Drop temporary column
        return df.drop("_p")

    def _create_censor_table(
        self,
        df: pl.DataFrame,
        context: ReportContext,
    ) -> TableResult:
        """Create censoring information table."""
        group_cols = ["level", "group"]

        # Find censor reason columns (cens_*)
        censor_cols = [c for c in df.columns if c.startswith("cens_")]

        if censor_cols:
            summary = df.group_by(group_cols).agg([
                pl.col(c).sum().alias(c) for c in censor_cols
            ])
        else:
            summary = df.select(group_cols).unique()

        return TableResult(
            table_id="t1_censor",
            title="T1: Censoring Information",
            data=summary,
        )

    def _create_dp_stratified_table(
        self,
        df: pl.DataFrame,
        context: ReportContext,
    ) -> TableResult:
        """Create DP-stratified summary table."""
        group_cols = ["level", "group", "dpidsiteid"]

        summary = summarize_by_strata(
            df=df,
            group_cols=group_cols,
            sum_cols=list(T1_CIDA_SUM_COLS),
        )

        result_df = self._compute_t1_rates(summary)

        return TableResult(
            table_id="t1_by_dp",
            title="T1: By Data Partner",
            data=result_df,
        )
