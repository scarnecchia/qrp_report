"""T4L1 Report Plugin: Pregnancy-specific background rates analysis.

T4L1 extends the T1 pattern with:
- Multi-dimensional grouping (group x moiname x pregflg)
- Trimester-specific denominators
- Gestational week expansion and transposition

Input datasets:
- t4preg: Pregnancy cohort data
- t4nopreg: Non-pregnancy cohort data
- t4preggestwk: Gestational week data for pregnancy cohort
- t4nopreggestwk: Gestational week data for non-pregnancy cohort
- t4cida: CIDA summary statistics
"""

import polars as pl

from qrp_report.plugins.types import (
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


# T4-specific columns for aggregation
T4_SUM_COLS: tuple[str, ...] = (
    "episodes",
    "episodes_2trim",
    "episodes_3trim",
    "events",
    "personyears",
    "personyears_2trim",
    "personyears_3trim",
    "npts",
    "dennummemdays",
)

# T4 pregnancy-specific datasets
T4_PREG_DATASETS: tuple[str, ...] = (
    "t4preg",
    "t4nopreg",
    "t4preggestwk",
    "t4nopreggestwk",
    "t4cida",
)


@register_plugin("T4L1")
class T4L1Plugin:
    """Plugin for T4L1 pregnancy-specific background rates reports."""

    @property
    def report_type(self) -> ReportType:
        return "T4L1"

    @property
    def required_datasets(self) -> tuple[str, ...]:
        return T4_PREG_DATASETS

    @property
    def aggregation_dimensions(self) -> tuple[str, ...]:
        """T4 uses multi-dimensional grouping."""
        return ("group", "moiname", "pregflg")

    def validate_context(self, context: ReportContext) -> tuple[str, ...]:
        """Validate T4L1 context."""
        errors: list[str] = []

        if context.report_type != "T4L1":
            errors.append(f"Expected report_type 'T4L1', got '{context.report_type}'")

        if not context.groups:
            errors.append("At least one group must be specified")

        if not context.data_partners:
            errors.append("At least one data partner must be specified")

        return tuple(errors)

    def aggregate_with_trimesters(
        self,
        df: pl.DataFrame,
        *,
        group_cols: list[str] | None = None,
    ) -> pl.DataFrame:
        """Aggregate preserving trimester-specific denominators.

        Args:
            df: Input dataframe with trimester columns.
            group_cols: Columns to group by. Defaults to aggregation_dimensions.

        Returns:
            Aggregated dataframe with trimester denominators.
        """
        if group_cols is None:
            group_cols = list(self.aggregation_dimensions)

        # Identify which sum columns exist in this dataframe
        sum_cols = [c for c in T4_SUM_COLS if c in df.columns]

        if not sum_cols:
            return df

        # Filter to existing group columns
        existing_group_cols = [c for c in group_cols if c in df.columns]
        if not existing_group_cols:
            return df

        return df.group_by(existing_group_cols).agg([
            pl.col(c).sum().alias(c) for c in sum_cols
        ])

    def expand_gestational_weeks(
        self,
        df: pl.DataFrame,
        max_week: int = 44,
    ) -> pl.DataFrame:
        """Expand gestational week data for full week range.

        Creates rows for all weeks from 1 to max_week, filling missing
        weeks with zeros. Used for gestational week transposition tables.

        Args:
            df: Dataframe with gestwk column.
            max_week: Maximum gestational week to include.

        Returns:
            Expanded dataframe with all weeks represented.
        """
        if "gestwk" not in df.columns:
            return df

        # Get unique combinations of grouping columns
        group_cols = [c for c in self.aggregation_dimensions if c in df.columns]

        if not group_cols:
            # No grouping, just ensure all weeks present
            all_weeks = pl.DataFrame({"gestwk": range(1, max_week + 1)})
            return all_weeks.join(df, on="gestwk", how="left").fill_null(0)

        # Create scaffold with all group x week combinations
        unique_groups = df.select(group_cols).unique()
        all_weeks = pl.DataFrame({"gestwk": range(1, max_week + 1)})

        scaffold = unique_groups.join(all_weeks, how="cross")

        # Join actual data and fill missing with zeros
        numeric_cols = [c for c in df.columns if c not in group_cols + ["gestwk"]]

        result = scaffold.join(
            df,
            on=group_cols + ["gestwk"],
            how="left",
        )

        # Fill nulls with 0 for numeric columns
        for col in numeric_cols:
            if col in result.columns:
                result = result.with_columns(pl.col(col).fill_null(0))

        return result.sort(group_cols + ["gestwk"])

    def execute(self, context: ReportContext) -> ReportResult:
        """Execute T4L1 pregnancy-specific background rates report.

        Args:
            context: Report generation context with config and data paths.

        Returns:
            Report result with pregnancy-specific tables.
        """
        errors = self.validate_context(context)
        if errors:
            raise ValueError(f"Invalid context: {'; '.join(errors)}")

        tables: list[TableResult] = []
        warnings: list[str] = []

        # Load and aggregate pregnancy datasets
        preg_table = self._try_create_preg_table(context, "t4preg", warnings)
        if preg_table:
            tables.append(preg_table)

        nopreg_table = self._try_create_preg_table(context, "t4nopreg", warnings)
        if nopreg_table:
            tables.append(nopreg_table)

        # Load gestational week data with expansion
        preggestwk_table = self._try_create_gestwk_table(context, "t4preggestwk", warnings)
        if preggestwk_table:
            tables.append(preggestwk_table)

        nopreggestwk_table = self._try_create_gestwk_table(context, "t4nopreggestwk", warnings)
        if nopreggestwk_table:
            tables.append(nopreggestwk_table)

        # Load CIDA summary if available
        cida_table = self._try_create_cida_table(context, warnings)
        if cida_table:
            tables.append(cida_table)

        return ReportResult(
            report_type="T4L1",
            tables=tuple(tables),
            warnings=tuple(warnings),
        )

    def _try_create_preg_table(
        self,
        context: ReportContext,
        dataset_name: str,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create pregnancy/non-pregnancy cohort table.

        Args:
            context: Report context.
            dataset_name: Dataset to load (t4preg or t4nopreg).
            warnings: Warning list to append to.

        Returns:
            TableResult or None if data not available.
        """
        try:
            agg_data = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=dataset_name,
                filter_var="group",
                filter_values=context.groups,
            )

            # Aggregate with trimester preservation
            summary = self.aggregate_with_trimesters(agg_data)

            # Compute rates
            result_df = self._compute_t4_rates(summary)

            return TableResult(
                table_id=f"t4_{dataset_name}_summary",
                title=self._get_table_title(dataset_name),
                data=result_df,
            )
        except ValueError as e:
            warnings.append(f"{dataset_name}: {e}")
            return None

    def _try_create_gestwk_table(
        self,
        context: ReportContext,
        dataset_name: str,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create gestational week table.

        Args:
            context: Report context.
            dataset_name: Gestational week dataset name.
            warnings: Warning list to append to.

        Returns:
            TableResult or None if data not available.
        """
        try:
            agg_data = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name=dataset_name,
                filter_var="group",
                filter_values=context.groups,
            )

            # Aggregate by gestational week
            group_cols = ["group", "moiname", "gestwk"]
            existing_group_cols = [c for c in group_cols if c in agg_data.columns]
            sum_cols = [c for c in ["n_episodes", "n_events", "npts"] if c in agg_data.columns]

            if existing_group_cols and sum_cols:
                summary = summarize_by_strata(
                    df=agg_data,
                    group_cols=existing_group_cols,
                    sum_cols=sum_cols,
                )
            else:
                summary = agg_data

            # Expand to include all gestational weeks
            expanded = self.expand_gestational_weeks(summary)

            return TableResult(
                table_id=f"t4_{dataset_name}_expanded",
                title=self._get_table_title(dataset_name),
                data=expanded,
            )
        except ValueError as e:
            warnings.append(f"{dataset_name}: {e}")
            return None

    def _try_create_cida_table(
        self,
        context: ReportContext,
        warnings: list[str],
    ) -> TableResult | None:
        """Try to create CIDA summary table.

        Args:
            context: Report context.
            warnings: Warning list to append to.

        Returns:
            TableResult or None if data not available.
        """
        try:
            agg_data = aggregate_datasets(
                data_partners=context.data_partners,
                run_id=context.run_id,
                dataset_name="t4cida",
                filter_var="group",
                filter_values=context.groups,
            )

            # Aggregate with standard T4 columns
            summary = self.aggregate_with_trimesters(agg_data)

            return TableResult(
                table_id="t4_cida_summary",
                title="T4 CIDA Summary Statistics",
                data=summary,
            )
        except ValueError as e:
            warnings.append(f"t4cida: {e}")
            return None

    def _compute_t4_rates(self, df: pl.DataFrame) -> pl.DataFrame:
        """Compute T4 rates including trimester-specific rates.

        Note: Uses vectorized Polars operations for efficiency.
        Computes rates for full pregnancy and by trimester.

        Args:
            df: Aggregated dataframe with episode and person-year columns.

        Returns:
            DataFrame with computed rate columns.
        """
        z = 1.96

        # Full pregnancy rate: events / personyears * 1000
        if "events" in df.columns and "personyears" in df.columns:
            df = df.with_columns([
                pl.when(pl.col("personyears") > 0)
                .then(pl.col("events") / pl.col("personyears") * 1000)
                .otherwise(None)
                .alias("rate_1000py"),
            ])

            # Poisson CI for rate
            df = df.with_columns([
                pl.when((pl.col("events") > 0) & (pl.col("rate_1000py").is_not_null()))
                .then(
                    pl.col("rate_1000py") *
                    ((-z * (1.0 / pl.col("events").sqrt())).exp())
                )
                .otherwise(None)
                .alias("rate_ci_lower"),

                pl.when((pl.col("events") > 0) & (pl.col("rate_1000py").is_not_null()))
                .then(
                    pl.col("rate_1000py") *
                    ((z * (1.0 / pl.col("events").sqrt())).exp())
                )
                .otherwise(None)
                .alias("rate_ci_upper"),
            ])

        # 2nd trimester rate
        if "events" in df.columns and "personyears_2trim" in df.columns:
            df = df.with_columns([
                pl.when(pl.col("personyears_2trim") > 0)
                .then(pl.col("events") / pl.col("personyears_2trim") * 1000)
                .otherwise(None)
                .alias("rate_1000py_2trim"),
            ])

        # 3rd trimester rate
        if "events" in df.columns and "personyears_3trim" in df.columns:
            df = df.with_columns([
                pl.when(pl.col("personyears_3trim") > 0)
                .then(pl.col("events") / pl.col("personyears_3trim") * 1000)
                .otherwise(None)
                .alias("rate_1000py_3trim"),
            ])

        # Risk per 1000 episodes
        if "events" in df.columns and "episodes" in df.columns:
            df = df.with_columns([
                pl.when(pl.col("episodes") > 0)
                .then(pl.col("events") / pl.col("episodes") * 1000)
                .otherwise(None)
                .alias("risk_1000eps"),
            ])

        return df

    def _get_table_title(self, dataset_name: str) -> str:
        """Get human-readable title for dataset.

        Args:
            dataset_name: Internal dataset name.

        Returns:
            Display title for table.
        """
        titles = {
            "t4preg": "Pregnancy Cohort Background Rates",
            "t4nopreg": "Non-Pregnancy Cohort Background Rates",
            "t4preggestwk": "Pregnancy Gestational Week Analysis",
            "t4nopreggestwk": "Non-Pregnancy Gestational Week Analysis",
            "t4cida": "T4 CIDA Summary Statistics",
        }
        return titles.get(dataset_name, dataset_name)
