"""Plugin registry for report type plugins."""

from typing import TypeVar

from qrp_report.core.interfaces import ReportPlugin

T = TypeVar("T", bound=ReportPlugin)

# Global registry of plugins by report type
_registry: dict[str, type[ReportPlugin]] = {}


def register_plugin(plugin_class: type[T]) -> type[T]:
    """Decorator to register a report plugin.

    Usage:
        @register_plugin
        class T1Plugin(ReportPlugin):
            ...

    Args:
        plugin_class: The plugin class to register.

    Returns:
        The plugin class (unchanged).

    Raises:
        ValueError: If a plugin for this report type is already registered.
    """
    # Create instance to get report_type
    # Note: This requires plugins to have no required __init__ args
    instance = plugin_class()
    report_type = instance.report_type.upper()

    if report_type in _registry:
        raise ValueError(
            f"plugin for report type '{report_type}' already registered: "
            f"{_registry[report_type].__name__}"
        )

    _registry[report_type] = plugin_class
    return plugin_class


def get_plugin(report_type: str) -> ReportPlugin:
    """Get a plugin instance for a report type.

    Args:
        report_type: Report type code (e.g., "T1", "T2L1").

    Returns:
        Plugin instance for the report type.

    Raises:
        KeyError: If no plugin is registered for this report type.
    """
    report_type = report_type.upper()
    if report_type not in _registry:
        available = ", ".join(sorted(_registry.keys())) or "none"
        raise KeyError(
            f"no plugin registered for report type '{report_type}'. "
            f"Available: {available}"
        )

    return _registry[report_type]()


def get_registered_types() -> list[str]:
    """Get list of registered report types.

    Returns:
        Sorted list of report type codes.
    """
    return sorted(_registry.keys())


def is_registered(report_type: str) -> bool:
    """Check if a report type is registered.

    Args:
        report_type: Report type code.

    Returns:
        True if registered, False otherwise.
    """
    return report_type.upper() in _registry


def clear_registry() -> None:
    """Clear all registered plugins.

    Primarily for testing purposes.
    """
    _registry.clear()
