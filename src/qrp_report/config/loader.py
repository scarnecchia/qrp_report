"""Configuration loading from YAML and legacy SAS datasets."""

from pathlib import Path
from typing import Any

import pyreadstat
import yaml

from qrp_report.config.errors import ErrorSeverity, ValidationMessage
from qrp_report.config.models import (
    ReportConfig,
)


class ConfigLoader:
    """Loads configuration from YAML or SAS datasets."""

    def __init__(self, config_path: Path) -> None:
        """Initialize loader with config file path.

        Args:
            config_path: Path to YAML config file or directory containing
                        SAS datasets (report_parameters.sas7bdat, etc.)
        """
        self.config_path = Path(config_path)
        self.errors: list[ValidationMessage] = []

    def load(self) -> ReportConfig | None:
        """Load configuration from file or directory.

        Returns:
            ReportConfig if successful, None if loading failed.
            Check self.errors for any validation messages.
        """
        if self.config_path.suffix in (".yaml", ".yml"):
            return self._load_yaml()
        elif self.config_path.suffix == ".sas7bdat":
            return self._load_sas_file()
        elif self.config_path.is_dir():
            return self._load_sas_directory()
        else:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E001",
                    message=f"unsupported config format: {self.config_path.suffix}",
                    location=str(self.config_path),
                    suggestion="use .yaml, .yml, .sas7bdat, or a directory with SAS datasets",
                )
            )
            return None

    def _load_yaml(self) -> ReportConfig | None:
        """Load configuration from YAML file."""
        try:
            with open(self.config_path) as f:
                data = yaml.safe_load(f)
        except FileNotFoundError:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E001",
                    message="configuration file not found",
                    location=str(self.config_path),
                )
            )
            return None
        except yaml.YAMLError as e:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E001",
                    message=f"invalid YAML syntax: {e}",
                    location=str(self.config_path),
                )
            )
            return None

        try:
            return ReportConfig.model_validate(data)
        except Exception as e:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E001",
                    message=f"configuration validation failed: {e}",
                    location=str(self.config_path),
                )
            )
            return None

    def _load_sas_directory(self) -> ReportConfig | None:
        """Load configuration from directory of SAS datasets."""
        report_params_path = self.config_path / "report_parameters.sas7bdat"
        if not report_params_path.exists():
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E001",
                    message="REPORT_PARAMETERS file is missing",
                    location=str(self.config_path),
                    suggestion="ensure report_parameters.sas7bdat is in the config directory",
                )
            )
            return None

        return self._load_sas_file(report_params_path)

    def _load_sas_file(self, path: Path | None = None) -> ReportConfig | None:
        """Load configuration from SAS report_parameters dataset."""
        sas_path = path or self.config_path
        config_dir = sas_path.parent

        try:
            params = self._read_sas_to_dict(sas_path)
        except Exception as e:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E001",
                    message=f"failed to read SAS file: {e}",
                    location=str(sas_path),
                )
            )
            return None

        # Build config from SAS parameters
        try:
            config_data = self._sas_params_to_config(params, config_dir)
            return ReportConfig.model_validate(config_data)
        except Exception as e:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.ERROR,
                    code="E001",
                    message=f"failed to convert SAS parameters: {e}",
                    location=str(sas_path),
                )
            )
            return None

    def _read_sas_to_dict(self, path: Path) -> dict[str, Any]:
        """Read SAS dataset and convert to dictionary.

        SAS report_parameters is typically structured with 'parameter' column
        as keys and 'report1' (or similar) column as values.
        """
        df, _ = pyreadstat.read_sas7bdat(str(path))

        # Handle different SAS structures
        if "parameter" in df.columns:
            # Key-value structure: parameter column has names, other columns have values
            result = {}
            for _, row in df.iterrows():
                param_name = str(row["parameter"]).lower().strip()
                # Use first non-parameter column as value
                for col in df.columns:
                    if col != "parameter":
                        value = row[col]
                        if not (isinstance(value, float) and str(value) == "nan"):
                            result[param_name] = value
                        break
            return result
        else:
            # Single row structure: column names are parameters
            if len(df) > 0:
                return {col.lower(): df[col].iloc[0] for col in df.columns}
            return {}

    def _sas_params_to_config(
        self, params: dict[str, Any], config_dir: Path
    ) -> dict[str, Any]:
        """Convert SAS parameters dictionary to ReportConfig format."""
        config: dict[str, Any] = {}

        # Required fields
        config["reportid"] = params.get("reportid", "")
        config["reporttype"] = self._normalize_report_type(params.get("reporttype", ""))

        # Optional scalar fields
        if "stratifybydp" in params:
            config["stratifybydp"] = self._parse_yn(params["stratifybydp"])
        if "small_cellcounts" in params:
            config["small_cellcounts"] = int(params["small_cellcounts"])
        if "report_destination" in params:
            config["report_destination"] = params["report_destination"].upper()
        if "collapse_vars" in params:
            config["collapse_vars"] = params["collapse_vars"]
        if "seed" in params:
            config["seed"] = int(params["seed"])
        if "database" in params:
            config["database"] = params["database"]

        # Load auxiliary files
        config["dpinfo"] = self._load_auxiliary_sas(
            config_dir, params.get("dpinfofile"), self._parse_dpinfo
        )
        config["groups"] = self._load_auxiliary_sas(
            config_dir, params.get("groupsfile"), self._parse_groups
        )
        config["baseline"] = self._load_auxiliary_sas(
            config_dir, params.get("baselinefile"), self._parse_baseline
        )
        config["tables"] = self._load_auxiliary_sas(
            config_dir, params.get("tablefile"), self._parse_tables
        )
        config["figures"] = self._load_auxiliary_sas(
            config_dir, params.get("figurefile"), self._parse_figures
        )
        config["labels"] = self._load_auxiliary_sas(
            config_dir, params.get("labelfile"), self._parse_labels
        )
        config["l2comparisons"] = self._load_auxiliary_sas(
            config_dir, params.get("l2comparisonfile"), self._parse_l2comparisons
        )

        return config

    def _load_auxiliary_sas(
        self,
        config_dir: Path,
        filename: Any,
        parser: Any,
    ) -> list[Any]:
        """Load auxiliary SAS file if specified."""
        if not filename or (isinstance(filename, float) and str(filename) == "nan"):
            return []

        # Handle filename with or without extension
        filename_str = str(filename).strip()
        if not filename_str.endswith(".sas7bdat"):
            filename_str += ".sas7bdat"

        file_path = config_dir / filename_str
        if not file_path.exists():
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.WARNING,
                    code="W001",
                    message=f"auxiliary file not found: {filename_str}",
                    location=str(file_path),
                )
            )
            return []

        try:
            df, _ = pyreadstat.read_sas7bdat(str(file_path))
            return parser(df)
        except Exception as e:
            self.errors.append(
                ValidationMessage(
                    severity=ErrorSeverity.WARNING,
                    code="W001",
                    message=f"failed to read auxiliary file: {e}",
                    location=str(file_path),
                )
            )
            return []

    def _normalize_report_type(self, value: Any) -> str:
        """Normalize report type string."""
        if not value:
            return "T1"
        return str(value).upper().strip()

    def _parse_yn(self, value: Any) -> bool:
        """Parse Y/N string to boolean."""
        if isinstance(value, bool):
            return value
        return str(value).upper().strip() in ("Y", "YES", "TRUE", "1")

    def _parse_dpinfo(self, df: Any) -> list[dict[str, Any]]:
        """Parse dpinfofile dataframe."""
        result = []
        for _, row in df.iterrows():
            result.append(
                {
                    "dp": str(row.get("dp", "")).strip(),
                    "dpname": str(row.get("dpname", "")).strip(),
                    "path": str(row.get("path", "")).strip(),
                    "database": str(row.get("database", "")).strip(),
                    "includedp": self._parse_yn(row.get("includedp", "Y")),
                }
            )
        return result

    def _parse_groups(self, df: Any) -> list[dict[str, Any]]:
        """Parse groupsfile dataframe."""
        result = []
        for _, row in df.iterrows():
            result.append(
                {
                    "runid": str(row.get("runid", "")).strip(),
                    "group": str(row.get("group", "")).strip(),
                    "order": int(row.get("order", 0)),
                    "includeinfigure": self._parse_yn(row.get("includeinfigure", "N")),
                    "codedist": row.get("codedist"),
                    "topncodedist": int(row.get("topncodedist", 10)),
                }
            )
        return result

    def _parse_baseline(self, df: Any) -> list[dict[str, Any]]:
        """Parse baselinefile dataframe."""
        result = []
        for _, row in df.iterrows():
            result.append(
                {
                    "runid": str(row.get("runid", "")).strip(),
                    "group": str(row.get("group", "")).strip(),
                    "order": int(row.get("order", 0)),
                    "baseline": self._parse_yn(row.get("baseline", "N")),
                    "baselinegroupnum": row.get("baselinegroupnum"),
                    "labcharacteristics": str(row.get("labcharacteristics", "")),
                    "covinps": str(row.get("covinps", "")),
                }
            )
        return result

    def _parse_tables(self, df: Any) -> list[dict[str, Any]]:
        """Parse tablefile dataframe."""
        result = []
        for _, row in df.iterrows():
            result.append(
                {
                    "table": str(row.get("table", "")).strip(),
                    "tablesub": str(row.get("tablesub", "overall")).strip(),
                    "dataset": str(row.get("dataset", "")).strip(),
                    "levelid1": str(row.get("levelid1", "")),
                    "levelid2": str(row.get("levelid2", "")),
                    "levelid3": str(row.get("levelid3", "")),
                    "categories": str(row.get("categories", "N%")),
                    "includeinreport": self._parse_yn(row.get("includeinreport", "Y")),
                }
            )
        return result

    def _parse_figures(self, df: Any) -> list[dict[str, Any]]:
        """Parse figurefile dataframe."""
        result = []
        for _, row in df.iterrows():
            result.append(
                {
                    "figure": str(row.get("figure", "")).strip(),
                    "figuresub": str(row.get("figuresub", "overall")).strip(),
                    "dataset": str(row.get("dataset", "")).strip(),
                    "levelid1": str(row.get("levelid1", "")),
                    "levelid2": str(row.get("levelid2", "")),
                    "levelid3": str(row.get("levelid3", "")),
                    "includeatrisktable": self._parse_yn(row.get("includeatrisktable", "Y")),
                }
            )
        return result

    def _parse_labels(self, df: Any) -> list[dict[str, Any]]:
        """Parse labelfile dataframe."""
        result = []
        for _, row in df.iterrows():
            result.append(
                {
                    "labeltype": str(row.get("labeltype", "")).strip(),
                    "labelvar": str(row.get("labelvar", "")).strip(),
                    "label": str(row.get("label", "")).strip(),
                }
            )
        return result

    def _parse_l2comparisons(self, df: Any) -> list[dict[str, Any]]:
        """Parse l2comparisonfile dataframe."""
        result = []
        for _, row in df.iterrows():
            psmethod_str = str(row.get("psmethod", "matching")).lower().strip()
            result.append(
                {
                    "runid": str(row.get("runid", "")).strip(),
                    "analysisgrp": str(row.get("analysisgrp", "")).strip(),
                    "order": int(row.get("order", 0)),
                    "psmethod": psmethod_str,
                    "outputconditional": self._parse_yn(row.get("outputconditional", "Y")),
                }
            )
        return result


def load_config(path: Path | str) -> tuple[ReportConfig | None, list[ValidationMessage]]:
    """Load configuration from file or directory.

    Args:
        path: Path to YAML config file or directory with SAS datasets.

    Returns:
        Tuple of (config, errors). Config is None if loading failed.
    """
    loader = ConfigLoader(Path(path))
    config = loader.load()
    return config, loader.errors
