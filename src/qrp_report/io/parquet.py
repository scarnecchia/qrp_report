"""Parquet file writer for intermediate data storage."""

from pathlib import Path

import polars as pl


def write_parquet(
    df: pl.DataFrame | pl.LazyFrame,
    path: Path | str,
    compression: str = "snappy",
) -> Path:
    """Write DataFrame to Parquet file.

    Args:
        df: polars DataFrame or LazyFrame to write.
        path: Output file path.
        compression: Compression codec (snappy, gzip, lz4, zstd, none).

    Returns:
        Path to written file.
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    # Collect if LazyFrame
    if isinstance(df, pl.LazyFrame):
        df = df.collect()

    df.write_parquet(path, compression=compression)
    return path


def read_parquet(path: Path | str) -> pl.DataFrame:
    """Read Parquet file into DataFrame.

    Args:
        path: Path to Parquet file.

    Returns:
        polars DataFrame.

    Raises:
        FileNotFoundError: If file does not exist.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Parquet file not found: {path}")

    return pl.read_parquet(path)


def read_parquet_lazy(path: Path | str) -> pl.LazyFrame:
    """Read Parquet file as LazyFrame.

    Args:
        path: Path to Parquet file.

    Returns:
        polars LazyFrame with deferred loading.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Parquet file not found: {path}")

    return pl.scan_parquet(path)


def write_aggregated_data(
    data: dict[str, pl.DataFrame],
    output_dir: Path | str,
    prefix: str = "agg_",
) -> dict[str, Path]:
    """Write multiple aggregated datasets to Parquet files.

    Args:
        data: Dictionary mapping dataset names to DataFrames.
        output_dir: Directory to write files.
        prefix: Prefix for output filenames.

    Returns:
        Dictionary mapping dataset names to output paths.
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    written_files: dict[str, Path] = {}

    for name, df in data.items():
        filename = f"{prefix}{name}.parquet"
        output_path = output_dir / filename
        write_parquet(df, output_path)
        written_files[name] = output_path

    return written_files
