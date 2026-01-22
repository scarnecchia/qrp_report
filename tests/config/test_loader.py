"""Tests for configuration loader."""

from pathlib import Path
from textwrap import dedent

import pytest

from qrp_report.config.loader import ConfigLoader, load_config
from qrp_report.config.models import ReportType


@pytest.fixture
def sample_yaml_config(tmp_path: Path) -> Path:
    """Create sample YAML config file."""
    config_content = dedent("""
        reportid: test_report_001
        reporttype: T2L1
        stratifybydp: true
        report_destination: EXCEL
        dpinfo:
          - dp: dp01
            dpname: Data Partner 1
            path: /data/dp01
            includedp: true
          - dp: dp02
            dpname: Data Partner 2
            path: /data/dp02
            includedp: false
        groups:
          - runid: run01
            group: exposure_yes
            order: 1
            includeinfigure: true
    """)
    config_file = tmp_path / "config.yaml"
    config_file.write_text(config_content)
    return config_file


@pytest.fixture
def minimal_yaml_config(tmp_path: Path) -> Path:
    """Create minimal YAML config file."""
    config_content = dedent("""
        reportid: minimal_test
        reporttype: T1
        dpinfo:
          - dp: dp01
            dpname: DP 1
            path: /data/dp01
    """)
    config_file = tmp_path / "config.yaml"
    config_file.write_text(config_content)
    return config_file


class TestConfigLoader:
    """Tests for ConfigLoader class."""

    def test_load_yaml_success(self, sample_yaml_config: Path) -> None:
        """Test loading valid YAML config."""
        loader = ConfigLoader(sample_yaml_config)
        config = loader.load()

        assert config is not None
        assert config.reportid == "test_report_001"
        assert config.reporttype == ReportType.T2L1
        assert config.stratifybydp is True
        assert len(config.dpinfo) == 2
        assert config.dpinfo[0].dp == "dp01"
        assert config.dpinfo[1].includedp is False

    def test_load_yaml_minimal(self, minimal_yaml_config: Path) -> None:
        """Test loading minimal YAML config with defaults."""
        loader = ConfigLoader(minimal_yaml_config)
        config = loader.load()

        assert config is not None
        assert config.reportid == "minimal_test"
        assert config.reporttype == ReportType.T1
        assert config.stratifybydp is False  # default
        assert len(loader.errors) == 0

    def test_load_nonexistent_file(self, tmp_path: Path) -> None:
        """Test loading nonexistent file produces error."""
        loader = ConfigLoader(tmp_path / "nonexistent.yaml")
        config = loader.load()

        assert config is None
        assert len(loader.errors) == 1
        assert loader.errors[0].code == "E001"

    def test_load_invalid_yaml(self, tmp_path: Path) -> None:
        """Test loading invalid YAML produces error."""
        bad_yaml = tmp_path / "bad.yaml"
        bad_yaml.write_text("reportid: [invalid yaml")

        loader = ConfigLoader(bad_yaml)
        config = loader.load()

        assert config is None
        assert len(loader.errors) == 1
        assert "YAML" in loader.errors[0].message

    def test_load_unsupported_format(self, tmp_path: Path) -> None:
        """Test loading unsupported format produces error."""
        txt_file = tmp_path / "config.txt"
        txt_file.write_text("some text")

        loader = ConfigLoader(txt_file)
        config = loader.load()

        assert config is None
        assert len(loader.errors) == 1
        assert "unsupported" in loader.errors[0].message


class TestLoadConfigFunction:
    """Tests for load_config convenience function."""

    def test_returns_tuple(self, sample_yaml_config: Path) -> None:
        """Test that load_config returns (config, errors) tuple."""
        config, errors = load_config(sample_yaml_config)

        assert config is not None
        assert isinstance(errors, list)
        assert config.reportid == "test_report_001"

    def test_accepts_string_path(self, sample_yaml_config: Path) -> None:
        """Test that load_config accepts string path."""
        config, errors = load_config(str(sample_yaml_config))

        assert config is not None
