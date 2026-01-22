"""Tests for Parquet module."""

from pathlib import Path

import polars as pl
import pytest

from qrp_report.io.parquet import (
    read_parquet,
    read_parquet_lazy,
    write_aggregated_data,
    write_parquet,
)


@pytest.fixture
def sample_df() -> pl.DataFrame:
    """Create sample DataFrame for testing."""
    return pl.DataFrame(
        {
            "dpidsiteid": ["DP01", "DP01", "DP02", "DP02"],
            "runid": ["run01", "run01", "run01", "run01"],
            "group": ["exp", "unexp", "exp", "unexp"],
            "count": [100, 200, 150, 250],
            "rate": [0.1, 0.2, 0.15, 0.25],
        }
    )


class TestWriteParquet:
    """Tests for write_parquet function."""

    def test_creates_file(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that function creates Parquet file."""
        output_path = tmp_path / "test.parquet"
        result = write_parquet(sample_df, output_path)

        assert result == output_path
        assert output_path.exists()

    def test_creates_parent_dirs(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that function creates parent directories."""
        output_path = tmp_path / "subdir" / "nested" / "test.parquet"
        write_parquet(sample_df, output_path)

        assert output_path.exists()

    def test_accepts_lazyframe(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that function accepts LazyFrame."""
        output_path = tmp_path / "lazy.parquet"
        write_parquet(sample_df.lazy(), output_path)

        assert output_path.exists()

    def test_compression_option(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test different compression options."""
        for compression in ["snappy", "gzip", "lz4", "zstd"]:
            output_path = tmp_path / f"test_{compression}.parquet"
            write_parquet(sample_df, output_path, compression=compression)
            assert output_path.exists()


class TestReadParquet:
    """Tests for read_parquet function."""

    def test_reads_file(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that function reads Parquet file."""
        output_path = tmp_path / "test.parquet"
        write_parquet(sample_df, output_path)

        df = read_parquet(output_path)
        assert isinstance(df, pl.DataFrame)
        assert df.shape == sample_df.shape

    def test_data_integrity(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that data is preserved through write/read cycle."""
        output_path = tmp_path / "test.parquet"
        write_parquet(sample_df, output_path)

        df = read_parquet(output_path)
        assert df.equals(sample_df)

    def test_file_not_found(self, tmp_path: Path) -> None:
        """Test that FileNotFoundError is raised for missing file."""
        with pytest.raises(FileNotFoundError, match="Parquet file not found"):
            read_parquet(tmp_path / "missing.parquet")


class TestReadParquetLazy:
    """Tests for read_parquet_lazy function."""

    def test_returns_lazyframe(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that function returns LazyFrame."""
        output_path = tmp_path / "test.parquet"
        write_parquet(sample_df, output_path)

        lf = read_parquet_lazy(output_path)
        assert isinstance(lf, pl.LazyFrame)

    def test_can_collect(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that LazyFrame can be collected."""
        output_path = tmp_path / "test.parquet"
        write_parquet(sample_df, output_path)

        lf = read_parquet_lazy(output_path)
        df = lf.collect()
        assert df.equals(sample_df)


class TestWriteAggregatedData:
    """Tests for write_aggregated_data function."""

    def test_writes_multiple_files(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that function writes multiple Parquet files."""
        data = {
            "t1cida": sample_df,
            "t1censor": sample_df.select(["dpidsiteid", "runid", "count"]),
        }

        result = write_aggregated_data(data, tmp_path)

        assert len(result) == 2
        assert (tmp_path / "agg_t1cida.parquet").exists()
        assert (tmp_path / "agg_t1censor.parquet").exists()

    def test_custom_prefix(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test custom filename prefix."""
        data = {"test": sample_df}

        write_aggregated_data(data, tmp_path, prefix="custom_")

        assert (tmp_path / "custom_test.parquet").exists()

    def test_creates_output_dir(self, tmp_path: Path, sample_df: pl.DataFrame) -> None:
        """Test that function creates output directory."""
        output_dir = tmp_path / "new_dir" / "nested"
        data = {"test": sample_df}

        write_aggregated_data(data, output_dir)

        assert output_dir.exists()
        assert (output_dir / "agg_test.parquet").exists()
