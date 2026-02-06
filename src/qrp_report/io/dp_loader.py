"""Data Partner loader for aggregating data across multiple DPs."""

import random
import re
from dataclasses import dataclass, field
from pathlib import Path

import polars as pl

from qrp_report.config.models import DPInfo
from qrp_report.io.sas_reader import read_sas, sas_file_exists


@dataclass
class DPMask:
    """Mapping from original DP ID to masked ID."""

    original_id: str
    masked_id: str
    path: Path


@dataclass
class LoadResult:
    """Result of loading data from DPs."""

    data: pl.DataFrame | None
    dp_masks: list[DPMask]
    loaded_dps: list[str]
    missing_files: list[str]
    errors: list[str]


@dataclass
class DPLoader:
    """Loads and aggregates data from multiple Data Partners.

    Handles:
    - DP path resolution (explicit paths or version auto-discovery)
    - DP masking (randomized ID assignment)
    - File existence checking
    - Aggregation across DPs with dpidsiteid column
    """

    dataroot: Path
    dp_info: list[DPInfo]
    seed: int | None = None
    dp_masks: list[DPMask] = field(default_factory=list, init=False)

    def __post_init__(self) -> None:
        """Initialize DP masks after construction."""
        self._initialize_masks()

    def _initialize_masks(self) -> None:
        """Create randomized DP ID masking."""
        # Filter to included DPs only
        included_dps = [dp for dp in self.dp_info if dp.includedp]

        if not included_dps:
            self.dp_masks = []
            return

        # Create random order
        rng = random.Random(self.seed)
        shuffled = included_dps.copy()
        rng.shuffle(shuffled)

        # Assign masked IDs
        self.dp_masks = []
        for i, dp in enumerate(shuffled, start=1):
            masked_id = f"DP{i:02d}"
            dp_path = self._resolve_dp_path(dp)
            self.dp_masks.append(
                DPMask(
                    original_id=dp.dp,
                    masked_id=masked_id,
                    path=dp_path,
                )
            )

    def _resolve_dp_path(self, dp: DPInfo) -> Path:
        """Resolve the data path for a Data Partner.

        If dp.path is specified, use it directly.
        Otherwise, use version auto-discovery from dataroot.
        """
        if dp.path and Path(dp.path).exists():
            return Path(dp.path)

        # Auto-discover version directories
        return self._auto_discover_path(dp.dp)

    def _auto_discover_path(self, dp_id: str) -> Path:
        """Auto-discover DP data path from dataroot using version directories.

        Scans for directories starting with V, B, or T (version indicators).
        Returns most recent version path that contains the DP's msoc folder.
        """
        if not self.dataroot.exists():
            return Path()

        # Find version directories (V*, B*, T*)
        version_pattern = re.compile(r"^[VBT]", re.IGNORECASE)
        version_dirs = []

        for entry in self.dataroot.iterdir():
            if entry.is_dir() and version_pattern.match(entry.name):
                # Check if this version has our DP
                dp_msoc = entry / dp_id.lower() / "msoc"
                if dp_msoc.exists():
                    # Get modification time for sorting
                    mtime = entry.stat().st_mtime
                    version_dirs.append((mtime, dp_msoc))

        if not version_dirs:
            # Fallback: try direct path without version
            direct_path = self.dataroot / dp_id.lower() / "msoc"
            if direct_path.exists():
                return direct_path
            return Path()

        # Sort by modification time (descending) and return most recent
        version_dirs.sort(key=lambda x: x[0], reverse=True)
        return version_dirs[0][1]

    def get_dp_masks(self) -> list[DPMask]:
        """Get the DP masking information."""
        return self.dp_masks

    def load_dataset(
        self,
        dataset_type: str,
        runids: list[str],
        group_column: str = "group",
        group_filter: str | None = None,
    ) -> LoadResult:
        """Load and aggregate a dataset type across all DPs.

        Args:
            dataset_type: Dataset suffix (e.g., "t1_cida", "t2_cida")
            runids: List of run IDs to load
            group_column: Name of the grouping column to lowercase
            group_filter: Optional filter value for group column

        Returns:
            LoadResult with aggregated data and metadata
        """
        all_frames: list[pl.DataFrame] = []
        loaded_dps: list[str] = []
        missing_files: list[str] = []
        errors: list[str] = []

        for dp_mask in self.dp_masks:
            if not dp_mask.path or not dp_mask.path.exists():
                errors.append(f"DP {dp_mask.original_id}: path not found")
                continue

            for runid in runids:
                filename = f"{runid}_{dataset_type}.sas7bdat"
                file_path = dp_mask.path / filename

                if not sas_file_exists(file_path):
                    missing_files.append(f"{dp_mask.masked_id}/{filename}")
                    continue

                try:
                    df = read_sas(file_path)

                    # Add DP identification columns
                    df = df.with_columns(
                        pl.lit(dp_mask.masked_id).alias("dpidsiteid"),
                        pl.lit(runid).alias("runid"),
                    )

                    # Lowercase the group column if present
                    if group_column in df.columns:
                        df = df.with_columns(
                            pl.col(group_column).str.to_lowercase()
                        )

                    # Apply group filter if specified
                    if group_filter and group_column in df.columns:
                        df = df.filter(pl.col(group_column) == group_filter.lower())

                    all_frames.append(df)
                    if dp_mask.masked_id not in loaded_dps:
                        loaded_dps.append(dp_mask.masked_id)

                except Exception as e:
                    errors.append(f"{dp_mask.masked_id}/{filename}: {e}")

        # Combine all frames
        if all_frames:
            combined = pl.concat(all_frames, how="diagonal")
        else:
            combined = None

        return LoadResult(
            data=combined,
            dp_masks=self.dp_masks,
            loaded_dps=loaded_dps,
            missing_files=missing_files,
            errors=errors,
        )

    def load_dataset_lazy(
        self,
        dataset_type: str,
        runids: list[str],
        group_column: str = "group",
        group_filter: str | None = None,
    ) -> pl.LazyFrame | None:
        """Load dataset as LazyFrame for deferred computation.

        Same as load_dataset but returns LazyFrame.
        """
        result = self.load_dataset(dataset_type, runids, group_column, group_filter)
        if result.data is not None:
            return result.data.lazy()
        return None
