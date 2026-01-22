"""Tests for value formatters."""

import math
import pytest

from qrp_report.render.formatters import (
    format_count,
    format_percent,
    format_rate,
    format_ci,
    format_effect_estimate,
    format_pvalue,
    apply_format,
)
from qrp_report.stats.types import ConfidenceInterval, EffectEstimate


class TestFormatCount:
    """Tests for count formatting."""

    def test_formats_with_commas(self) -> None:
        """Should add comma separators."""
        assert format_count(1234) == "1,234"
        assert format_count(1234567) == "1,234,567"

    def test_handles_small_numbers(self) -> None:
        """Small numbers should not have commas."""
        assert format_count(123) == "123"
        assert format_count(0) == "0"

    def test_truncates_floats(self) -> None:
        """Floats should be truncated to integers."""
        assert format_count(1234.56) == "1,234"

    def test_missing_returns_empty(self) -> None:
        """Missing values should return empty string."""
        assert format_count(float("nan")) == ""
        assert format_count(float("nan"), missing="N/A") == "N/A"


class TestFormatPercent:
    """Tests for percentage formatting."""

    def test_formats_with_one_decimal(self) -> None:
        """Default should be 1 decimal place."""
        assert format_percent(45.2) == "45.2%"
        assert format_percent(100.0) == "100.0%"

    def test_custom_decimals(self) -> None:
        """Should support custom decimal places."""
        assert format_percent(45.23, decimals=2) == "45.23%"
        assert format_percent(45.0, decimals=0) == "45%"

    def test_without_symbol(self) -> None:
        """Should optionally omit % symbol."""
        assert format_percent(45.2, include_symbol=False) == "45.2"

    def test_missing_returns_empty(self) -> None:
        """Missing values should return empty string."""
        assert format_percent(float("nan")) == ""


class TestFormatRate:
    """Tests for rate formatting."""

    def test_formats_with_two_decimals(self) -> None:
        """Default should be 2 decimal places."""
        assert format_rate(12.34) == "12.34"
        assert format_rate(1234.56) == "1,234.56"

    def test_custom_decimals(self) -> None:
        """Should support custom decimal places."""
        assert format_rate(12.345, decimals=3) == "12.345"

    def test_missing_returns_nan(self) -> None:
        """Missing values should return 'NaN'."""
        assert format_rate(float("nan")) == "NaN"


class TestFormatCI:
    """Tests for confidence interval formatting."""

    def test_formats_as_lower_upper(self) -> None:
        """Should format as 'lower, upper'."""
        ci = ConfidenceInterval(lower=0.95, upper=1.57)
        assert format_ci(ci) == "0.95, 1.57"

    def test_custom_decimals(self) -> None:
        """Should support custom decimal places."""
        ci = ConfidenceInterval(lower=0.9523, upper=1.5678)
        assert format_ci(ci, decimals=3) == "0.952, 1.568"

    def test_missing_returns_nan(self) -> None:
        """NaN bounds should return 'NaN'."""
        ci = ConfidenceInterval(lower=float("nan"), upper=float("nan"))
        assert format_ci(ci) == "NaN"


class TestFormatEffectEstimate:
    """Tests for effect estimate formatting."""

    def test_formats_with_ci(self) -> None:
        """Should format value with CI."""
        ci = ConfidenceInterval(lower=0.95, upper=1.57)
        est = EffectEstimate(value=1.23, ci=ci)
        assert format_effect_estimate(est) == "1.23 (0.95, 1.57)"

    def test_with_label(self) -> None:
        """Should include label prefix."""
        ci = ConfidenceInterval(lower=0.95, upper=1.57)
        est = EffectEstimate(value=1.23, ci=ci)
        assert format_effect_estimate(est, label="HR") == "HR 1.23 (0.95, 1.57)"

    def test_missing_returns_na(self) -> None:
        """NaN value should return 'N/A'."""
        ci = ConfidenceInterval(lower=0.0, upper=0.0)
        est = EffectEstimate(value=float("nan"), ci=ci)
        assert format_effect_estimate(est) == "N/A"


class TestFormatPvalue:
    """Tests for p-value formatting."""

    def test_formats_with_three_decimals(self) -> None:
        """Should use 3 decimal places."""
        assert format_pvalue(0.023) == "0.023"
        assert format_pvalue(0.5) == "0.500"

    def test_small_values_show_threshold(self) -> None:
        """Very small values should show '<threshold'."""
        assert format_pvalue(0.0001) == "<0.001"
        assert format_pvalue(0.0005, threshold=0.001) == "<0.001"

    def test_missing_returns_empty(self) -> None:
        """Missing values should return empty string."""
        assert format_pvalue(None) == ""
        assert format_pvalue(float("nan")) == ""


class TestApplyFormat:
    """Tests for SAS format application."""

    def test_comma_format_no_decimals(self) -> None:
        """comma14.0 should format as integer with commas."""
        assert apply_format(1234, "comma14.0") == "1,234"

    def test_comma_format_with_decimals(self) -> None:
        """comma13.2 should format with 2 decimals."""
        assert apply_format(1234.56, "comma13.2") == "1,234.56"

    def test_percent_format(self) -> None:
        """percent8.1 should format as percentage."""
        assert apply_format(45.2, "percent8.1") == "45.2%"

    def test_missing_returns_empty(self) -> None:
        """Missing values should return empty string."""
        assert apply_format(None, "comma14.0") == ""
        assert apply_format(float("nan"), "percent8.1") == ""
