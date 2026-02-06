"""Value formatters for QRP Report output.

Implements consistent number formatting matching SAS patterns:
- Counts: comma-separated, no decimals
- Percentages: 1 decimal place with % symbol
- Rates: 2 decimal places
- Confidence intervals: "lower, upper" format

Based on SAS patterns from create_templatefiles.sas.
"""

import math
from typing import Any, Optional

from qrp_report.stats.types import ConfidenceInterval, EffectEstimate, RateResult


def format_count(value: int | float, missing: str = "") -> str:
    """Format a count value with comma separators.

    SAS equivalent: comma14.0

    Args:
        value: Count value
        missing: String to show for missing/invalid values

    Returns:
        Formatted string (e.g., "1,234")
    """
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return missing
    return f"{int(value):,}"


def format_percent(
    value: float,
    decimals: int = 1,
    missing: str = "",
    include_symbol: bool = True,
) -> str:
    """Format a percentage value.

    SAS equivalent: percent8.1

    Args:
        value: Percentage value (0-100 scale)
        decimals: Number of decimal places
        missing: String to show for missing values
        include_symbol: Whether to append % symbol

    Returns:
        Formatted string (e.g., "45.2%")
    """
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return missing

    formatted = f"{value:.{decimals}f}"
    if include_symbol:
        formatted += "%"
    return formatted


def format_rate(
    value: float,
    decimals: int = 2,
    missing: str = "NaN",
) -> str:
    """Format a rate value with comma separators.

    SAS equivalent: comma13.2

    Args:
        value: Rate value
        decimals: Number of decimal places
        missing: String to show for missing values

    Returns:
        Formatted string (e.g., "1,234.56")
    """
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return missing

    # Format with decimals, then add commas to integer part
    formatted = f"{value:,.{decimals}f}"
    return formatted


def format_ci(
    ci: ConfidenceInterval,
    decimals: int = 2,
    missing: str = "NaN",
) -> str:
    """Format a confidence interval as "lower, upper".

    Args:
        ci: ConfidenceInterval object
        decimals: Number of decimal places
        missing: String to show for missing values

    Returns:
        Formatted string (e.g., "0.95, 1.57")
    """
    if math.isnan(ci.lower) or math.isnan(ci.upper):
        return missing

    lower = f"{ci.lower:.{decimals}f}"
    upper = f"{ci.upper:.{decimals}f}"
    return f"{lower}, {upper}"


def format_rate_with_ci(
    result: RateResult,
    decimals: int = 2,
    missing: str = "NaN",
) -> str:
    """Format a rate with its confidence interval.

    Args:
        result: RateResult object
        decimals: Number of decimal places
        missing: String for missing values

    Returns:
        Formatted string (e.g., "12.34 (10.23, 14.56)")
    """
    if math.isnan(result.value):
        return missing

    rate = format_rate(result.value, decimals, missing)
    ci = format_ci(result.ci, decimals, missing)
    return f"{rate} ({ci})"


def format_effect_estimate(
    estimate: EffectEstimate,
    decimals: int = 2,
    label: str = "",
    missing: str = "N/A",
) -> str:
    """Format an effect estimate with CI.

    Args:
        estimate: EffectEstimate object
        decimals: Number of decimal places
        label: Optional label prefix (e.g., "HR", "RR")
        missing: String for missing values

    Returns:
        Formatted string (e.g., "HR 1.23 (0.95, 1.57)")
    """
    if math.isnan(estimate.value):
        return missing

    value = f"{estimate.value:.{decimals}f}"
    ci = format_ci(estimate.ci, decimals, missing)

    if label:
        return f"{label} {value} ({ci})"
    return f"{value} ({ci})"


def format_pvalue(
    value: Optional[float],
    threshold: float = 0.001,
    missing: str = "",
) -> str:
    """Format a p-value with appropriate precision.

    Args:
        value: P-value
        threshold: Threshold below which to show "<threshold"
        missing: String for missing values

    Returns:
        Formatted string (e.g., "0.023" or "<0.001")
    """
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return missing

    if value < threshold:
        return f"<{threshold}"

    # Use 3 decimal places for p-values
    return f"{value:.3f}"


def format_days(value: float, decimals: int = 1, missing: str = "") -> str:
    """Format days with appropriate precision.

    Args:
        value: Number of days
        decimals: Decimal places
        missing: String for missing values

    Returns:
        Formatted string
    """
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return missing
    return f"{value:,.{decimals}f}"


def format_person_years(value: float, decimals: int = 1, missing: str = "") -> str:
    """Format person-years with commas.

    SAS equivalent: comma15.1

    Args:
        value: Person-years
        decimals: Decimal places
        missing: String for missing values

    Returns:
        Formatted string (e.g., "1,234.5")
    """
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return missing
    return f"{value:,.{decimals}f}"


def apply_format(value: Any, format_spec: str, missing: str = "") -> str:
    """Apply a SAS-style format specification to a value.

    Translates SAS format strings to Python formatting.

    Args:
        value: Value to format
        format_spec: SAS format string (e.g., "comma14.0", "percent8.1")
        missing: String for missing values

    Returns:
        Formatted string
    """
    if value is None:
        return missing
    if isinstance(value, float) and math.isnan(value):
        return missing

    # Parse format spec
    format_lower = format_spec.lower()

    if format_lower.startswith("comma"):
        # Extract decimals from format (e.g., "comma14.0" -> 0)
        parts = format_spec.split(".")
        decimals = int(parts[1]) if len(parts) > 1 else 0
        if decimals == 0:
            return format_count(value, missing)
        return format_rate(value, decimals, missing)

    elif format_lower.startswith("percent"):
        # Extract decimals (e.g., "percent8.1" -> 1)
        parts = format_spec.split(".")
        decimals = int(parts[1]) if len(parts) > 1 else 1
        # Assume value is already 0-100 scale
        return format_percent(value, decimals, missing)

    else:
        # Default: return string representation
        return str(value)
