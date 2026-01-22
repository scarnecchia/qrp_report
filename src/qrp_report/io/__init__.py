"""Data I/O module for QRP Report."""

from qrp_report.io.sas_reader import read_sas, read_sas_lazy

__all__ = ["read_sas", "read_sas_lazy"]
