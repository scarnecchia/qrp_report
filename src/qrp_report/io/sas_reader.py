"""SAS file reader with polars output."""

from pathlib import Path
from typing import Any

import polars as pl
import pyreadstat


def read_sas(path: Path | str, columns: list[str] | None = None) -> pl.DataFrame:
    """Read SAS dataset into polars DataFrame.

    Args:
        path: Path to .sas7bdat file.
        columns: Optional list of columns to read. If None, reads all.

    Returns:
        polars DataFrame with data from SAS file.

    Raises:
        FileNotFoundError: If file does not exist.
        ValueError: If file cannot be read.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"SAS file not found: {path}")

    try:
        # pyreadstat returns (dataframe, metadata)
        df_pandas, meta = pyreadstat.read_sas7bdat(
            str(path),
            usecols=columns,
        )

        # Convert to polars
        df = pl.from_pandas(df_pandas)

        # Normalize column names to lowercase
        df = df.rename({col: col.lower() for col in df.columns})

        return df

    except Exception as e:
        raise ValueError(f"failed to read SAS file {path}: {e}") from e


def read_sas_lazy(path: Path | str, columns: list[str] | None = None) -> pl.LazyFrame:
    """Read SAS dataset into polars LazyFrame.

    Note: SAS files don't support true lazy reading, so this reads the file
    eagerly and then converts to LazyFrame for consistent API.

    Args:
        path: Path to .sas7bdat file.
        columns: Optional list of columns to read. If None, reads all.

    Returns:
        polars LazyFrame with data from SAS file.
    """
    df = read_sas(path, columns)
    return df.lazy()


def get_sas_metadata(path: Path | str) -> dict[str, Any]:
    """Get metadata from SAS file without reading full data.

    Args:
        path: Path to .sas7bdat file.

    Returns:
        Dictionary with metadata including:
        - column_names: List of column names
        - column_labels: Dict mapping column names to labels
        - number_rows: Number of rows
        - number_columns: Number of columns
        - file_label: Dataset label if present
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"SAS file not found: {path}")

    try:
        # Read just metadata (no data)
        _, meta = pyreadstat.read_sas7bdat(str(path), metadataonly=True)

        return {
            "column_names": [c.lower() for c in meta.column_names],
            "column_labels": {
                c.lower(): meta.column_names_to_labels.get(c, "")
                for c in meta.column_names
            },
            "number_rows": meta.number_rows,
            "number_columns": meta.number_columns,
            "file_label": meta.file_label or "",
        }

    except Exception as e:
        raise ValueError(f"failed to read SAS metadata from {path}: {e}") from e


def sas_file_exists(path: Path | str) -> bool:
    """Check if SAS file exists.

    Args:
        path: Path to .sas7bdat file.

    Returns:
        True if file exists, False otherwise.
    """
    return Path(path).exists()
