"""Tests for Kaplan-Meier survival analysis."""

import math
import pytest

from qrp_report.stats.survival import (
    SurvivalData,
    greenwood_variance_component,
    greenwood_ci,
    kaplan_meier,
)
from qrp_report.stats.types import ConfidenceInterval, SurvivalPoint


class TestGreenwoodVariance:
    """Tests for Greenwood variance component calculation."""

    def test_zero_at_risk_returns_zero(self) -> None:
        """Zero at risk should return 0 variance."""
        assert greenwood_variance_component(events=1, at_risk=0) == 0.0

    def test_events_equal_at_risk_returns_zero(self) -> None:
        """When all at risk have events, variance component is undefined (0)."""
        assert greenwood_variance_component(events=10, at_risk=10) == 0.0

    def test_calculates_correct_variance(self) -> None:
        """Should calculate d / [n * (n - d)]."""
        # 5 events, 100 at risk: 5 / (100 * 95) = 0.000526...
        var = greenwood_variance_component(events=5, at_risk=100)
        expected = 5 / (100 * 95)
        assert var == pytest.approx(expected, rel=0.001)


class TestGreenwoodCI:
    """Tests for Greenwood confidence interval."""

    def test_survival_one_returns_point_estimate(self) -> None:
        """S(t) = 1.0 should return CI of (1.0, 1.0)."""
        ci = greenwood_ci(survival=1.0, cumulative_variance=0.01)
        assert ci.lower == 1.0
        assert ci.upper == 1.0

    def test_survival_zero_returns_point_estimate(self) -> None:
        """S(t) = 0.0 should return CI of (0.0, 0.0)."""
        ci = greenwood_ci(survival=0.0, cumulative_variance=0.01)
        assert ci.lower == 0.0
        assert ci.upper == 0.0

    def test_zero_variance_returns_point_estimate(self) -> None:
        """Zero variance should return point estimate only."""
        ci = greenwood_ci(survival=0.8, cumulative_variance=0.0)
        assert ci.lower == 0.8
        assert ci.upper == 0.8

    def test_valid_survival_returns_bounded_ci(self) -> None:
        """CI should be bounded within (0, 1)."""
        ci = greenwood_ci(survival=0.8, cumulative_variance=0.01)
        assert 0.0 < ci.lower < 0.8
        assert 0.8 < ci.upper < 1.0


class TestKaplanMeier:
    """Tests for Kaplan-Meier survival curve estimation."""

    def test_empty_data_returns_empty(self) -> None:
        """Empty input should return empty output."""
        result = kaplan_meier([])
        assert result == []

    def test_time_zero_has_survival_one(self) -> None:
        """Time 0 should always have S(0) = 1.0."""
        data = [
            SurvivalData(time=0, events=0, at_risk=100),
            SurvivalData(time=1, events=5, at_risk=100),
        ]
        result = kaplan_meier(data)
        assert result[0].time == 0
        assert result[0].survival == 1.0

    def test_survival_decreases_with_events(self) -> None:
        """Survival should decrease when events occur."""
        data = [
            SurvivalData(time=0, events=0, at_risk=100),
            SurvivalData(time=1, events=10, at_risk=100),
            SurvivalData(time=2, events=10, at_risk=90),
        ]
        result = kaplan_meier(data)

        # S(0) = 1.0
        # S(1) = 1.0 * (1 - 10/100) = 0.9
        # S(2) = 0.9 * (1 - 10/90) = 0.9 * 0.889 = 0.8
        assert result[0].survival == 1.0
        assert result[1].survival == pytest.approx(0.9, rel=0.001)
        assert result[2].survival == pytest.approx(0.8, rel=0.001)

    def test_no_events_keeps_survival_constant(self) -> None:
        """No events should not change survival."""
        data = [
            SurvivalData(time=0, events=0, at_risk=100),
            SurvivalData(time=1, events=10, at_risk=100),
            SurvivalData(time=2, events=0, at_risk=85),  # Only censoring
            SurvivalData(time=3, events=5, at_risk=80),
        ]
        result = kaplan_meier(data)

        # S(1) = 0.9
        # S(2) = 0.9 (no events)
        # S(3) = 0.9 * (1 - 5/80) = 0.84375
        assert result[1].survival == pytest.approx(0.9, rel=0.001)
        assert result[2].survival == pytest.approx(0.9, rel=0.001)
        assert result[3].survival == pytest.approx(0.84375, rel=0.001)

    def test_returns_survival_points_with_ci(self) -> None:
        """Each point should have valid CI."""
        data = [
            SurvivalData(time=0, events=0, at_risk=100),
            SurvivalData(time=1, events=10, at_risk=100),
        ]
        result = kaplan_meier(data)

        # Time 1 should have CI around 0.9
        point = result[1]
        assert isinstance(point, SurvivalPoint)
        assert isinstance(point.ci, ConfidenceInterval)
        assert point.ci.lower < point.survival
        assert point.ci.upper > point.survival

    def test_preserves_at_risk_and_events(self) -> None:
        """Should preserve at_risk and events in output."""
        data = [
            SurvivalData(time=0, events=0, at_risk=100),
            SurvivalData(time=5, events=15, at_risk=90, censored=10),
        ]
        result = kaplan_meier(data)

        assert result[0].at_risk == 100
        assert result[1].at_risk == 90
        assert result[1].events == 15
        assert result[1].censored == 10

    def test_sorts_by_time(self) -> None:
        """Should handle unsorted input."""
        data = [
            SurvivalData(time=2, events=5, at_risk=90),
            SurvivalData(time=0, events=0, at_risk=100),
            SurvivalData(time=1, events=10, at_risk=100),
        ]
        result = kaplan_meier(data)

        assert result[0].time == 0
        assert result[1].time == 1
        assert result[2].time == 2
