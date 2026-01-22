"""T2L1 Report Plugin: Exposure and follow-up analysis (Level 1 - descriptive).

T2L1 reports extend T1 with exposure-focused analyses including:
- Follow-up time distributions
- Concomitant medication patterns
- Multiple event analysis
- Episode gaps and overlaps

Input datasets:
- t2_cida: Main Type 2 data (npts, episodes, events, follow-up)
- censor_cida: Censoring information (optional)
- followuptime_cida: Follow-up period statistics
- t2_concomitance: Concomitant medication episodes
- t2_multevent: Multiple event episodes
- t2_epigap: Episode gaps
- t2_overlap: Episode overlaps
"""

from dataclasses import dataclass
from typing import Literal

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


# Columns to sum for T2 cida (extends T1 with additional vars)
T2_CIDA_SUM_COLS = (
    "npts",
    "episodes",
    "adjustedcodecount",
    "rawcodecount",
    "daysupp",
    "amtsupp",
    "dennumpts",
    "dennummemdays",
    "timetocensor",
    # T2-specific
    "eps_wevents",
    "all_events",
    "followuptime",
)

# Datasets that use 'group' filter
GROUP_FILTER_DATASETS = ("t2_cida", "censor_cida", "followuptime_cida")

# Datasets that use 'analysisgrp' filter
ANALYSISGRP_FILTER_DATASETS = ("t2_concomitance", "t2_multevent", "t2_epigap", "t2_overlap")


@register_plugin("T2L1")
class T2L1Plugin:
    """T2L1 Report Plugin implementation."""

    @property
    def report_type(self) -> ReportType:
        return "T2L1"

    @property
    def required_datasets(self) -> tuple[str, ...]:
        return ("t2_cida",)

    def validate_context(self, context: ReportContext) -> tuple[str, ...]:
        """Validate T2L1 context."""
        errors: list[str] = []

        if context.report_type != "T2L1":
            errors.append(f"Expected report_type 'T2L1', got '{context.report_type}'")

        if not context.groups:
            errors.append("At least one group must be specified")

        if not context.data_partners:
            errors.append("At least one data partner must be specified")

        return tuple(errors)

    def execute(self, context: ReportContext) -> ReportResult:
        """Execute T2L1 report generation."""
        errors = self.validate_context(context)
        if errors:
            raise ValueError(f"Invalid context: {'; '.join(errors)}")

        tables: list[TableResult] = []
        warnings: list[str] = []

        # Load and aggregate t2_cida (main exposure data)
        try:
            agg_t2cida = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="t2_cida",
                filter_var="group",
                filter_values=context.groups,
            )
        except ValueError as e:
            warnings.append(f"t2_cida: {e}")
            return ReportResult(
                report_type="T2L1",
                tables=(),
                warnings=tuple(warnings),
            )

        # Build main T2 table
        main_table = self._create_main_table(agg_t2cida, context)
        tables.append(main_table)

        # Optional tables based on available datasets

        # Censor table
        censor_table = self._try_create_censor_table(context, warnings)
        if censor_table:
            tables.append(censor_table)

        # Follow-up time table
        followup_table = self._try_create_followup_table(context, warnings)
        if followup_table:
            tables.append(followup_table)

        # Concomitant table (uses analysisgrp filter)
        conc_table = self._try_create_concomitant_table(context, warnings)
        if conc_table:
            tables.append(conc_table)

        # Multi-event table
        multevent_table = self._try_create_multevent_table(context, warnings)
        if multevent_table:
            tables.append(multevent_table)

        # Episode gap table
        epigap_table = self._try_create_epigap_table(context, warnings)
        if epigap_table:
            tables.append(epigap_table)

        # Episode overlap table
        overlap_table = self._try_create_overlap_table(context, warnings)
        if overlap_table:
            tables.append(overlap_table)

        # DP-stratified table if requested
        if context.stratification and context.stratification.by_dp:
            dp_table = self._create_dp_stratified_table(agg_t2cida, context)
            tables.append(dp_table)

        return ReportResult(
            report_type="T2L1",
            tables=tuple(tables),
            warnings=tuple(warnings),
        )

    def _create_main_table(
        self,
        df: pl.DataFrame,
        context: ReportContext,
    ) -> TableResult:
        """Create main T2L1 exposure table."""
        group_cols = ["level", "group"]
        if context.stratification:
            group_cols.extend(context.stratification.variables)

        summary = summarize_by_strata(
            df=df,
            group_cols=group_cols,
            sum_cols=list(T2_CIDA_SUM_COLS),
        )

        result_df = self._compute_t2_rates(summary)

        return TableResult(
            table_id="t2_main",
            title="T2L1: Exposure Analysis",
            data=result_df,
            stratification=",".join(context.stratification.variables) if context.stratification else None,
        )

    def _compute_t2_rates(self, df: pl.DataFrame) -> pl.DataFrame:
        """Compute T2 rates including event rates.

        Extends T1 rates with:
        - Event rate per 1000 person-years
        - Episodes with events rate
        """
        # Compute person-years
        df = df.with_columns([
            (pl.col("dennummemdays") / 365.25).alias("person_years"),
        ])

        z = 1.96

        # Incidence rate (same as T1)
        df = df.with_columns([
            pl.when(pl.col("person_years") > 0)
            .then(pl.col("episodes") / pl.col("person_years") * 1000)
            .otherwise(None)
            .alias("rate_1000py"),
        ])

        # Poisson CI for rate
        df = df.with_columns([
            pl.when((pl.col("episodes") > 0) & (pl.col("rate_1000py").is_not_null()))
            .then(pl.col("rate_1000py") * ((-z * (1.0 / pl.col("episodes").sqrt())).exp()))
            .otherwise(None)
            .alias("rate_ci_lower"),

            pl.when((pl.col("episodes") > 0) & (pl.col("rate_1000py").is_not_null()))
            .then(pl.col("rate_1000py") * ((z * (1.0 / pl.col("episodes").sqrt())).exp()))
            .otherwise(None)
            .alias("rate_ci_upper"),
        ])

        # Event rate per 1000 person-years (T2-specific)
        if "all_events" in df.columns:
            df = df.with_columns([
                pl.when(pl.col("person_years") > 0)
                .then(pl.col("all_events") / pl.col("person_years") * 1000)
                .otherwise(None)
                .alias("event_rate_1000py"),
            ])

            df = df.with_columns([
                pl.when((pl.col("all_events") > 0) & (pl.col("event_rate_1000py").is_not_null()))
                .then(pl.col("event_rate_1000py") * ((-z * (1.0 / pl.col("all_events").sqrt())).exp()))
                .otherwise(None)
                .alias("event_rate_ci_lower"),

                pl.when((pl.col("all_events") > 0) & (pl.col("event_rate_1000py").is_not_null()))
                .then(pl.col("event_rate_1000py") * ((z * (1.0 / pl.col("all_events").sqrt())).exp()))
                .otherwise(None)
                .alias("event_rate_ci_upper"),
            ])

        # Episodes with events percentage (T2-specific)
        if "eps_wevents" in df.columns:
            df = df.with_columns([
                pl.when(pl.col("episodes") > 0)
                .then(pl.col("eps_wevents") / pl.col("episodes") * 100)
                .otherwise(None)
                .alias("pct_eps_wevents"),
            ])

        # Risk per 1000 new users
        df = df.with_columns([
            pl.when(pl.col("npts") > 0)
            .then(pl.col("episodes") / pl.col("npts") * 1000)
            .otherwise(None)
            .alias("risk_1000nu"),
        ])

        df = df.with_columns([
            (pl.col("episodes") / pl.col("npts")).alias("_p"),
        ])

        df = df.with_columns([
            pl.when(pl.col("npts") > 0)
            .then((pl.col("_p") - z * (pl.col("_p") * (1 - pl.col("_p")) / pl.col("npts")).sqrt()) * 1000)
            .otherwise(None)
            .alias("risk_ci_lower"),

            pl.when(pl.col("npts") > 0)
            .then((pl.col("_p") + z * (pl.col("_p") * (1 - pl.col("_p")) / pl.col("npts")).sqrt()) * 1000)
            .otherwise(None)
            .alias("risk_ci_upper"),
        ])

        return df.drop("_p")

    def _try_create_censor_table(
        self,
        context: ReportContext,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create censor table, return None if data not available."""
        try:
            agg_censor = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="censor_cida",
                filter_var="group",
                filter_values=context.groups,
            )

            group_cols = ["level", "group"]
            censor_cols = [c for c in agg_censor.columns if c.startswith("cens_")]

            if censor_cols:
                summary = agg_censor.group_by(group_cols).agg([
                    pl.col(c).sum().alias(c) for c in censor_cols
                ])
            else:
                summary = agg_censor.select(group_cols).unique()

            return TableResult(
                table_id="t2_censor",
                title="T2L1: Censoring Information",
                data=summary,
            )
        except ValueError:
            return None

    def _try_create_followup_table(
        self,
        context: ReportContext,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create follow-up time table."""
        try:
            agg_followup = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="followuptime_cida",
                filter_var="group",
                filter_values=context.groups,
            )

            group_cols = ["level", "group"]
            sum_cols = ["followuptime", "npts"]

            summary = summarize_by_strata(
                df=agg_followup,
                group_cols=group_cols,
                sum_cols=[c for c in sum_cols if c in agg_followup.columns],
            )

            # Compute average follow-up
            if "followuptime" in summary.columns and "npts" in summary.columns:
                summary = summary.with_columns([
                    (pl.col("followuptime") / pl.col("npts")).alias("avg_followup_days"),
                    (pl.col("followuptime") / pl.col("npts") / 365.25).alias("avg_followup_years"),
                ])

            return TableResult(
                table_id="t2_followup",
                title="T2L1: Follow-up Time",
                data=summary,
            )
        except ValueError:
            return None

    def _try_create_concomitant_table(
        self,
        context: ReportContext,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create concomitant medication table."""
        try:
            agg_conc = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="t2_concomitance",
                filter_var="analysisgrp",  # Uses analysisgrp, not group
                filter_values=context.groups,
            )

            group_cols = ["level", "analysisgrp"]
            if context.stratification:
                group_cols.extend(context.stratification.variables)

            sum_cols = ["npts", "episodes"]

            summary = summarize_by_strata(
                df=agg_conc,
                group_cols=[c for c in group_cols if c in agg_conc.columns],
                sum_cols=[c for c in sum_cols if c in agg_conc.columns],
            )

            return TableResult(
                table_id="t2_concomitant",
                title="T2L1: Concomitant Medications",
                data=summary,
                stratification=",".join(context.stratification.variables) if context.stratification else None,
            )
        except ValueError:
            return None

    def _try_create_multevent_table(
        self,
        context: ReportContext,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create multiple event table."""
        try:
            agg_multevent = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="t2_multevent",
                filter_var="analysisgrp",
                filter_values=context.groups,
            )

            group_cols = ["level", "analysisgrp"]
            sum_cols = ["episodes", "all_events"]

            summary = summarize_by_strata(
                df=agg_multevent,
                group_cols=[c for c in group_cols if c in agg_multevent.columns],
                sum_cols=[c for c in sum_cols if c in agg_multevent.columns],
            )

            return TableResult(
                table_id="t2_multevent",
                title="T2L1: Multiple Events",
                data=summary,
            )
        except ValueError:
            return None

    def _try_create_epigap_table(
        self,
        context: ReportContext,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create episode gap table."""
        try:
            agg_epigap = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="t2_epigap",
                filter_var="analysisgrp",
                filter_values=context.groups,
            )

            group_cols = ["level", "analysisgrp"]
            sum_cols = ["episodes", "gapdays"]

            summary = summarize_by_strata(
                df=agg_epigap,
                group_cols=[c for c in group_cols if c in agg_epigap.columns],
                sum_cols=[c for c in sum_cols if c in agg_epigap.columns],
            )

            return TableResult(
                table_id="t2_epigap",
                title="T2L1: Episode Gaps",
                data=summary,
            )
        except ValueError:
            return None

    def _try_create_overlap_table(
        self,
        context: ReportContext,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create episode overlap table."""
        try:
            agg_overlap = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="t2_overlap",
                filter_var="analysisgrp",
                filter_values=context.groups,
            )

            group_cols = ["level", "analysisgrp"]
            sum_cols = ["episodes", "overlapdays"]

            summary = summarize_by_strata(
                df=agg_overlap,
                group_cols=[c for c in group_cols if c in agg_overlap.columns],
                sum_cols=[c for c in sum_cols if c in agg_overlap.columns],
            )

            return TableResult(
                table_id="t2_overlap",
                title="T2L1: Episode Overlaps",
                data=summary,
            )
        except ValueError:
            return None

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
            sum_cols=list(T2_CIDA_SUM_COLS),
        )

        result_df = self._compute_t2_rates(summary)

        return TableResult(
            table_id="t2_by_dp",
            title="T2L1: By Data Partner",
            data=result_df,
        )
