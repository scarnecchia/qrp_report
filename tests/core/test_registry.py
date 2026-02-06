"""Tests for plugin registry."""

import pytest

from qrp_report.config.errors import ValidationMessage
from qrp_report.config.models import ReportConfig, ReportType
from qrp_report.core.interfaces import Figure, ReportData, ReportPlugin, Table
from qrp_report.core.registry import (
    clear_registry,
    get_plugin,
    get_registered_types,
    is_registered,
    register_plugin,
)
import polars as pl


class MockPlugin(ReportPlugin):
    """Mock plugin for testing."""

    @property
    def report_type(self) -> str:
        return "MOCK"

    @property
    def description(self) -> str:
        return "Mock plugin for testing"

    @property
    def supported_tables(self) -> list[str]:
        return ["1a"]

    @property
    def supported_figures(self) -> list[str]:
        return ["F1"]

    def validate_config(self, config: ReportConfig) -> list[ValidationMessage]:
        return []

    def aggregate_data(
        self, dp_data: dict[str, pl.LazyFrame], config: ReportConfig
    ) -> dict[str, pl.DataFrame]:
        return {}

    def compute_statistics(
        self, data: dict[str, pl.DataFrame], config: ReportConfig
    ) -> ReportData:
        return ReportData(config=config)

    def get_tables(self, data: ReportData) -> list[Table]:
        return []

    def get_figures(self, data: ReportData) -> list[Figure]:
        return []


@pytest.fixture(autouse=True)
def clean_registry() -> None:
    """Clear registry before and after each test."""
    clear_registry()
    yield
    clear_registry()


class TestRegisterPlugin:
    """Tests for register_plugin decorator."""

    def test_registers_plugin(self) -> None:
        """Test that decorator registers plugin."""

        @register_plugin
        class TestPlugin(MockPlugin):
            @property
            def report_type(self) -> str:
                return "TEST"

        assert is_registered("TEST")

    def test_duplicate_registration_raises(self) -> None:
        """Test that duplicate registration raises ValueError."""

        @register_plugin
        class Plugin1(MockPlugin):
            @property
            def report_type(self) -> str:
                return "DUP"

        with pytest.raises(ValueError, match="already registered"):

            @register_plugin
            class Plugin2(MockPlugin):
                @property
                def report_type(self) -> str:
                    return "DUP"


class TestGetPlugin:
    """Tests for get_plugin function."""

    def test_returns_plugin_instance(self) -> None:
        """Test that get_plugin returns instance."""

        @register_plugin
        class TestPlugin(MockPlugin):
            @property
            def report_type(self) -> str:
                return "GET"

        plugin = get_plugin("GET")
        assert isinstance(plugin, TestPlugin)

    def test_case_insensitive(self) -> None:
        """Test that lookup is case-insensitive."""

        @register_plugin
        class TestPlugin(MockPlugin):
            @property
            def report_type(self) -> str:
                return "CASE"

        plugin1 = get_plugin("case")
        plugin2 = get_plugin("CASE")
        assert type(plugin1) == type(plugin2)

    def test_unknown_type_raises(self) -> None:
        """Test that unknown type raises KeyError."""
        with pytest.raises(KeyError, match="no plugin registered"):
            get_plugin("UNKNOWN")


class TestGetRegisteredTypes:
    """Tests for get_registered_types function."""

    def test_empty_registry(self) -> None:
        """Test empty registry returns empty list."""
        assert get_registered_types() == []

    def test_returns_sorted_types(self) -> None:
        """Test returns sorted list of types."""

        @register_plugin
        class PluginB(MockPlugin):
            @property
            def report_type(self) -> str:
                return "B"

        @register_plugin
        class PluginA(MockPlugin):
            @property
            def report_type(self) -> str:
                return "A"

        types = get_registered_types()
        assert types == ["A", "B"]


class TestIsRegistered:
    """Tests for is_registered function."""

    def test_returns_false_for_unknown(self) -> None:
        """Test returns False for unknown type."""
        assert is_registered("UNKNOWN") is False

    def test_returns_true_for_registered(self) -> None:
        """Test returns True for registered type."""

        @register_plugin
        class TestPlugin(MockPlugin):
            @property
            def report_type(self) -> str:
                return "REG"

        assert is_registered("REG") is True
        assert is_registered("reg") is True  # Case insensitive
