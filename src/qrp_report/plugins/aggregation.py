"""Shared aggregation utilities for report plugins.

These functions handle the common patterns of:
1. Loading SAS datasets from multiple data partners
2. Adding masked DP identifiers
3. Combining data across DPs
4. Filtering by group/analysisgrp
"""

from pathlib import Path
from typing import Literal

import polars as pl

from qrp_report.plugins.types import DataPartnerInfo


def load_dp_dataset(
    dp: DataPartnerInfo,
    run_id: str,
    dataset_name: str,
) -> pl.DataFrame | None:
    """Load a single dataset from a data partner.

    Returns None if dataset doesn't exist.

    Args:
        dp: Data partner information
        run_id: Run identifier (e.g., "run01")
        dataset_name: Dataset name (e.g., "t1_cida")

    Returns:
        DataFrame with added 'dpidsiteid' and 'runid' columns, or None
    """
    # Standard SAS dataset naming: {runid}_{dataset}.sas7bdat
    file_path = dp.data_path / f"{run_id}_{dataset_name}.sas7bdat"

    if not file_path.exists():
        return None

    # Import pyreadstat lazily to avoid import errors if not installed
    import pyreadstat

    df_pandas, meta = pyreadstat.read_sas7bdat(str(file_path))
    df = pl.from_pandas(df_pandas)

    # Add DP identifier and run ID
    return df.with_columns([
        pl.lit(dp.masked_id).alias("dpidsiteid"),
        pl.lit(run_id).alias("runid"),
    ])


def aggregate_datasets(
    data_partners: tuple[DataPartnerInfo, ...],
    run_id: str,
    dataset_name: str,
    filter_var: Literal["group", "analysisgrp"],
    filter_values: tuple[str, ...],
) -> pl.DataFrame:
    """Aggregate a dataset across all data partners.

    This implements the %agg_report macro pattern from SAS.

    Args:
        data_partners: Tuple of data partner info
        run_id: Run identifier
        dataset_name: Dataset to aggregate
        filter_var: Column to filter on ('group' or 'analysisgrp')
        filter_values: Values to include (case-insensitive)

    Returns:
        Combined DataFrame with all DP data, filtered by group

    Raises:
        ValueError: If no data found from any DP
    """
    frames: list[pl.DataFrame] = []
    filter_values_lower = tuple(v.lower() for v in filter_values)

    for dp in data_partners:
        df = load_dp_dataset(dp, run_id, dataset_name)
        if df is None:
            continue

        # Filter by group/analysisgrp (case-insensitive)
        if filter_var in df.columns:
            df = df.filter(
                pl.col(filter_var).str.to_lowercase().is_in(filter_values_lower)
            )

        frames.append(df)

    if not frames:
        raise ValueError(f"No data found for dataset '{dataset_name}' from any data partner")

    return pl.concat(frames)


def summarize_by_strata(
    df: pl.DataFrame,
    group_cols: list[str],
    sum_cols: list[str],
    level_filter: list[int] | None = None,
) -> pl.DataFrame:
    """Summarize data by stratification columns.

    This implements the PROC SUMMARY pattern from SAS.

    Args:
        df: Input DataFrame
        group_cols: Columns to group by (e.g., ['level', 'group', 'sex'])
        sum_cols: Columns to sum (e.g., ['npts', 'episodes'])
        level_filter: Optional list of level values to include

    Returns:
        Summarized DataFrame with sums by strata
    """
    # Apply level filter if specified
    if level_filter is not None and "level" in df.columns:
        df = df.filter(pl.col("level").is_in(level_filter))

    # Filter to columns that exist
    existing_group = [c for c in group_cols if c in df.columns]
    existing_sum = [c for c in sum_cols if c in df.columns]

    if not existing_group:
        raise ValueError("No valid group columns found in DataFrame")

    if not existing_sum:
        raise ValueError("No valid sum columns found in DataFrame")

    # Aggregate
    return df.group_by(existing_group).agg([
        pl.col(c).sum().alias(c) for c in existing_sum
    ])
