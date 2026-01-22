"""Tests for SAS reader module."""

from pathlib import Path

import polars as pl
import pytest

from qrp_report.io.sas_reader import (
    get_sas_metadata,
    read_sas,
    read_sas_lazy,
    sas_file_exists,
)


class TestReadSas:
    """Tests for read_sas function."""

    def test_file_not_found(self, tmp_path: Path) -> None:
        """Test that FileNotFoundError is raised for missing file."""
        with pytest.raises(FileNotFoundError, match="SAS file not found"):
            read_sas(tmp_path / "nonexistent.sas7bdat")

    def test_returns_dataframe(self, template_files_dir: Path) -> None:
        """Test that function returns polars DataFrame."""
        # Skip if no template files available
        sas_files = list(template_files_dir.glob("*.sas7bdat"))
        if not sas_files:
            pytest.skip("No SAS template files available for testing")

        df = read_sas(sas_files[0])
        assert isinstance(df, pl.DataFrame)

    def test_columns_lowercase(self, template_files_dir: Path) -> None:
        """Test that column names are lowercased."""
        sas_files = list(template_files_dir.glob("*.sas7bdat"))
        if not sas_files:
            pytest.skip("No SAS template files available for testing")

        df = read_sas(sas_files[0])
        for col in df.columns:
            assert col == col.lower(), f"Column {col} not lowercase"


class TestReadSasLazy:
    """Tests for read_sas_lazy function."""

    def test_returns_lazyframe(self, template_files_dir: Path) -> None:
        """Test that function returns polars LazyFrame."""
        sas_files = list(template_files_dir.glob("*.sas7bdat"))
        if not sas_files:
            pytest.skip("No SAS template files available for testing")

        lf = read_sas_lazy(sas_files[0])
        assert isinstance(lf, pl.LazyFrame)

    def test_can_collect(self, template_files_dir: Path) -> None:
        """Test that LazyFrame can be collected to DataFrame."""
        sas_files = list(template_files_dir.glob("*.sas7bdat"))
        if not sas_files:
            pytest.skip("No SAS template files available for testing")

        lf = read_sas_lazy(sas_files[0])
        df = lf.collect()
        assert isinstance(df, pl.DataFrame)


class TestGetSasMetadata:
    """Tests for get_sas_metadata function."""

    def test_returns_metadata(self, template_files_dir: Path) -> None:
        """Test that function returns metadata dictionary."""
        sas_files = list(template_files_dir.glob("*.sas7bdat"))
        if not sas_files:
            pytest.skip("No SAS template files available for testing")

        meta = get_sas_metadata(sas_files[0])
        assert "column_names" in meta
        assert "number_rows" in meta
        assert "number_columns" in meta
        assert isinstance(meta["column_names"], list)

    def test_column_names_lowercase(self, template_files_dir: Path) -> None:
        """Test that column names in metadata are lowercased."""
        sas_files = list(template_files_dir.glob("*.sas7bdat"))
        if not sas_files:
            pytest.skip("No SAS template files available for testing")

        meta = get_sas_metadata(sas_files[0])
        for col in meta["column_names"]:
            assert col == col.lower()


class TestSasFileExists:
    """Tests for sas_file_exists function."""

    def test_returns_false_for_missing(self, tmp_path: Path) -> None:
        """Test that function returns False for missing file."""
        assert sas_file_exists(tmp_path / "missing.sas7bdat") is False

    def test_returns_true_for_existing(self, template_files_dir: Path) -> None:
        """Test that function returns True for existing file."""
        sas_files = list(template_files_dir.glob("*.sas7bdat"))
        if not sas_files:
            pytest.skip("No SAS template files available for testing")

        assert sas_file_exists(sas_files[0]) is True
