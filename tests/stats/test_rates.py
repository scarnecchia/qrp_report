"""Tests for rate calculation functions."""

import math
import pytest

from qrp_report.stats.rates import (
    poisson_ci,
    binomial_ci,
    incidence_rate,
    risk_per_1000,
)
from qrp_report.stats.types import ConfidenceInterval, RateResult


class TestPoissonCI:
    """Tests for Poisson confidence interval calculation."""

    def test_zero_events_returns_zero_ci(self) -> None:
        """Zero events should return CI of (0, 0)."""
        ci = poisson_ci(events=0, rate=0.0)
        assert ci.lower == 0.0
        assert ci.upper == 0.0

    def test_positive_events_returns_valid_ci(self) -> None:
        """Positive events should return a valid CI around the rate."""
        # 50 events with rate of 10 per 1000 PY
        ci = poisson_ci(events=50, rate=10.0)
        assert ci.lower < 10.0
        assert ci.upper > 10.0
        assert ci.lower > 0.0

    def test_ci_width_decreases_with_more_events(self) -> None:
        """More events should produce narrower CI."""
        ci_10 = poisson_ci(events=10, rate=10.0)
        ci_100 = poisson_ci(events=100, rate=10.0)

        width_10 = ci_10.upper - ci_10.lower
        width_100 = ci_100.upper - ci_100.lower

        assert width_100 < width_10


class TestBinomialCI:
    """Tests for Binomial confidence interval calculation."""

    def test_zero_denominator_returns_zero_ci(self) -> None:
        """Zero denominator should return CI of (0, 0)."""
        ci = binomial_ci(events=0, n=0, proportion=0.0)
        assert ci.lower == 0.0
        assert ci.upper == 0.0

    def test_valid_proportion_returns_bounded_ci(self) -> None:
        """CI should be bounded within [0, 1]."""
        # 30 events out of 100
        ci = binomial_ci(events=30, n=100, proportion=0.3)
        assert ci.lower >= 0.0
        assert ci.upper <= 1.0
        assert ci.lower < 0.3
        assert ci.upper > 0.3

    def test_extreme_proportion_stays_bounded(self) -> None:
        """Even extreme proportions should stay in [0, 1]."""
        # 95 out of 100
        ci = binomial_ci(events=95, n=100, proportion=0.95)
        assert ci.lower >= 0.0
        assert ci.upper <= 1.0


class TestIncidenceRate:
    """Tests for incidence rate calculation."""

    def test_zero_person_time_returns_nan(self) -> None:
        """Zero person-time should return NaN rate."""
        result = incidence_rate(events=10, person_days=0.0)
        assert math.isnan(result.value)

    def test_calculates_rate_per_1000_person_years(self) -> None:
        """Should calculate rate per 1000 person-years correctly."""
        # 50 events over 36525 person-days = 100 person-years
        # Rate = 50/100 * 1000 = 500 per 1000 PY
        result = incidence_rate(events=50, person_days=36525.0)
        assert result.per == 1000
        assert result.value == pytest.approx(500.0, rel=0.01)

    def test_converts_days_to_years(self) -> None:
        """Person-days should be converted to person-years using 365.25."""
        result = incidence_rate(events=10, person_days=365.25)
        # 1 person-year, 10 events = 10000 per 1000 PY
        assert result.denominator == pytest.approx(1.0, rel=0.001)

    def test_returns_rate_result_with_ci(self) -> None:
        """Should return RateResult with valid CI."""
        result = incidence_rate(events=100, person_days=365250.0)
        assert isinstance(result, RateResult)
        assert isinstance(result.ci, ConfidenceInterval)
        assert result.ci.lower < result.value
        assert result.ci.upper > result.value


class TestRiskPer1000:
    """Tests for risk per 1000 new users calculation."""

    def test_zero_users_returns_nan(self) -> None:
        """Zero users should return NaN risk."""
        result = risk_per_1000(events=10, n=0)
        assert math.isnan(result.value)

    def test_calculates_risk_per_1000(self) -> None:
        """Should calculate risk per 1000 users correctly."""
        # 50 events out of 1000 users = 50 per 1000
        result = risk_per_1000(events=50, n=1000)
        assert result.value == pytest.approx(50.0, rel=0.01)

    def test_returns_rate_result_with_scaled_ci(self) -> None:
        """CI should be scaled by the same multiplier."""
        result = risk_per_1000(events=100, n=1000, per=1000)
        # 10% proportion, CI should be around 100 per 1000
        assert result.ci.lower > 0.0
        assert result.ci.upper < 1000.0
