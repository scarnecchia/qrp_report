"""Plugin registry for report type plugins.

Provides decorator-based registration and lookup for report plugins.
"""

from typing import TypeVar, Callable

from qrp_report.plugins.types import ReportPlugin, ReportType


# Global plugin registry
_PLUGINS: dict[ReportType, type[ReportPlugin]] = {}


def register_plugin(report_type: ReportType) -> Callable[[type[ReportPlugin]], type[ReportPlugin]]:
    """Decorator to register a report plugin.

    Example:
        @register_plugin("T1")
        class T1Plugin:
            ...
    """
    def decorator(cls: type[ReportPlugin]) -> type[ReportPlugin]:
        if report_type in _PLUGINS:
            raise ValueError(f"Plugin already registered for {report_type}")
        _PLUGINS[report_type] = cls
        return cls
    return decorator


def get_plugin(report_type: ReportType) -> type[ReportPlugin]:
    """Get the plugin class for a report type.

    Raises:
        KeyError: If no plugin is registered for the report type.
    """
    if report_type not in _PLUGINS:
        raise KeyError(f"No plugin registered for report type: {report_type}")
    return _PLUGINS[report_type]


def list_plugins() -> tuple[ReportType, ...]:
    """List all registered report types."""
    return tuple(_PLUGINS.keys())


def clear_registry() -> None:
    """Clear all registered plugins. For testing only."""
    _PLUGINS.clear()
