"""Data I/O module for QRP Report."""

from qrp_report.io.dp_loader import DPLoader, DPMask, LoadResult
from qrp_report.io.parquet import (
    read_parquet,
    read_parquet_lazy,
    write_aggregated_data,
    write_parquet,
)
from qrp_report.io.sas_reader import (
    get_sas_metadata,
    read_sas,
    read_sas_lazy,
    sas_file_exists,
)

__all__ = [
    # SAS reader
    "read_sas",
    "read_sas_lazy",
    "get_sas_metadata",
    "sas_file_exists",
    # DP loader
    "DPLoader",
    "DPMask",
    "LoadResult",
    # Parquet
    "write_parquet",
    "read_parquet",
    "read_parquet_lazy",
    "write_aggregated_data",
]
