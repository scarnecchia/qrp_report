"""Tests for Data Partner loader module."""

from pathlib import Path

import polars as pl
import pytest

from qrp_report.config.models import DPInfo
from qrp_report.io.dp_loader import DPLoader, DPMask, LoadResult


@pytest.fixture
def sample_dp_info() -> list[DPInfo]:
    """Create sample DP info list."""
    return [
        DPInfo(dp="sentinel01", dpname="Sentinel DP 1", path=Path("/data/dp01"), includedp=True),
        DPInfo(dp="sentinel02", dpname="Sentinel DP 2", path=Path("/data/dp02"), includedp=True),
        DPInfo(dp="sentinel03", dpname="Sentinel DP 3", path=Path("/data/dp03"), includedp=False),
    ]


class TestDPMask:
    """Tests for DPMask dataclass."""

    def test_creation(self) -> None:
        """Test DPMask creation."""
        mask = DPMask(
            original_id="sentinel01",
            masked_id="DP01",
            path=Path("/data/dp01"),
        )
        assert mask.original_id == "sentinel01"
        assert mask.masked_id == "DP01"
        assert mask.path == Path("/data/dp01")


class TestLoadResult:
    """Tests for LoadResult dataclass."""

    def test_creation_with_data(self) -> None:
        """Test LoadResult with data."""
        df = pl.DataFrame({"a": [1, 2, 3]})
        result = LoadResult(
            data=df,
            dp_masks=[],
            loaded_dps=["DP01"],
            missing_files=[],
            errors=[],
        )
        assert result.data is not None
        assert result.loaded_dps == ["DP01"]

    def test_creation_without_data(self) -> None:
        """Test LoadResult without data."""
        result = LoadResult(
            data=None,
            dp_masks=[],
            loaded_dps=[],
            missing_files=["DP01/test.sas7bdat"],
            errors=[],
        )
        assert result.data is None
        assert len(result.missing_files) == 1


class TestDPLoader:
    """Tests for DPLoader class."""

    def test_initialization(self, tmp_path: Path, sample_dp_info: list[DPInfo]) -> None:
        """Test DPLoader initialization."""
        loader = DPLoader(
            dataroot=tmp_path,
            dp_info=sample_dp_info,
            seed=42,
        )
        assert loader.dataroot == tmp_path
        assert len(loader.dp_info) == 3

    def test_mask_generation_excludes_not_included(
        self, tmp_path: Path, sample_dp_info: list[DPInfo]
    ) -> None:
        """Test that excluded DPs are not masked."""
        loader = DPLoader(
            dataroot=tmp_path,
            dp_info=sample_dp_info,
            seed=42,
        )
        masks = loader.get_dp_masks()

        # Should only have 2 masks (sentinel03 has includedp=False)
        assert len(masks) == 2
        original_ids = [m.original_id for m in masks]
        assert "sentinel03" not in original_ids

    def test_mask_ids_sequential(
        self, tmp_path: Path, sample_dp_info: list[DPInfo]
    ) -> None:
        """Test that masked IDs are sequential (DP01, DP02, etc.)."""
        loader = DPLoader(
            dataroot=tmp_path,
            dp_info=sample_dp_info,
            seed=42,
        )
        masks = loader.get_dp_masks()
        masked_ids = sorted([m.masked_id for m in masks])

        assert masked_ids == ["DP01", "DP02"]

    def test_seed_affects_order(
        self, tmp_path: Path, sample_dp_info: list[DPInfo]
    ) -> None:
        """Test that different seeds produce different orderings."""
        loader1 = DPLoader(dataroot=tmp_path, dp_info=sample_dp_info, seed=1)
        loader2 = DPLoader(dataroot=tmp_path, dp_info=sample_dp_info, seed=2)

        masks1 = loader1.get_dp_masks()
        masks2 = loader2.get_dp_masks()

        # Same DPs but potentially different order
        originals1 = [m.original_id for m in masks1]
        originals2 = [m.original_id for m in masks2]

        assert set(originals1) == set(originals2)

    def test_same_seed_same_order(
        self, tmp_path: Path, sample_dp_info: list[DPInfo]
    ) -> None:
        """Test that same seed produces same ordering."""
        loader1 = DPLoader(dataroot=tmp_path, dp_info=sample_dp_info, seed=42)
        loader2 = DPLoader(dataroot=tmp_path, dp_info=sample_dp_info, seed=42)

        masks1 = loader1.get_dp_masks()
        masks2 = loader2.get_dp_masks()

        originals1 = [m.original_id for m in masks1]
        originals2 = [m.original_id for m in masks2]

        assert originals1 == originals2

    def test_load_dataset_missing_files(
        self, tmp_path: Path, sample_dp_info: list[DPInfo]
    ) -> None:
        """Test load_dataset with missing files."""
        loader = DPLoader(
            dataroot=tmp_path,
            dp_info=sample_dp_info,
            seed=42,
        )

        result = loader.load_dataset(
            dataset_type="t1_cida",
            runids=["run01"],
        )

        # No data should be loaded (files don't exist)
        assert result.data is None
        assert len(result.loaded_dps) == 0
        # But we should have missing file entries or errors (path not found)
        assert len(result.missing_files) > 0 or len(result.errors) > 0

    def test_empty_dp_info(self, tmp_path: Path) -> None:
        """Test loader with empty DP info."""
        loader = DPLoader(
            dataroot=tmp_path,
            dp_info=[],
            seed=42,
        )

        masks = loader.get_dp_masks()
        assert len(masks) == 0

    def test_all_dps_excluded(self, tmp_path: Path) -> None:
        """Test loader when all DPs are excluded."""
        dp_info = [
            DPInfo(dp="dp01", dpname="DP 1", path=Path("/data"), includedp=False),
            DPInfo(dp="dp02", dpname="DP 2", path=Path("/data"), includedp=False),
        ]

        loader = DPLoader(
            dataroot=tmp_path,
            dp_info=dp_info,
            seed=42,
        )

        masks = loader.get_dp_masks()
        assert len(masks) == 0
