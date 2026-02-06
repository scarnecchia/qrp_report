"""Tests for report driver."""

import pytest

from qrp_report.driver import ReportDriver


class TestReportDriver:
    """Test report driver functionality."""

    def test_driver_selects_correct_plugin(self) -> None:
        """Driver selects plugin based on report type."""
        driver = ReportDriver()

        plugin = driver.get_plugin("T1")
        assert plugin.report_type == "T1"

        plugin = driver.get_plugin("T4L2")
        assert plugin.report_type == "T4L2"

    def test_driver_raises_for_unknown_type(self) -> None:
        """Driver raises error for unknown report type."""
        driver = ReportDriver()

        with pytest.raises(ValueError, match="Unknown report type"):
            driver.get_plugin("T99")

    def test_driver_lists_available_types(self) -> None:
        """Driver can list all available report types."""
        driver = ReportDriver()

        types = driver.available_report_types()

        assert "T1" in types
        assert "T2L1" in types
        assert "T2L2" in types
        assert "T4L1" in types
        assert "T4L2" in types

    def test_driver_get_plugin_returns_plugin_instance(self) -> None:
        """Driver returns plugin instance, not class."""
        driver = ReportDriver()

        plugin = driver.get_plugin("T1")
        # Check that it's an instance with required properties
        assert hasattr(plugin, "report_type")
        assert hasattr(plugin, "required_datasets")
        assert hasattr(plugin, "validate_context")
        assert hasattr(plugin, "execute")

    def test_driver_available_report_types_returns_list(self) -> None:
        """available_report_types returns a list."""
        driver = ReportDriver()

        types = driver.available_report_types()

        assert isinstance(types, list)
        assert len(types) >= 5  # At least T1, T2L1, T2L2, T4L1, T4L2
