"""Tests for effect estimate calculations."""

import math
import pytest

from qrp_report.stats.effect_estimates import (
    risk_difference,
    risk_ratio,
    incidence_rate_difference,
    incidence_rate_ratio,
    hazard_ratio_logistic,
    hazard_ratio_robust,
    number_needed_to_treat,
    attributable_risk,
    population_attributable_risk,
)
from qrp_report.stats.types import EffectEstimate


class TestRiskDifference:
    """Tests for risk difference calculation."""

    def test_zero_denominator_returns_nan(self) -> None:
        """Zero in either group should return NaN."""
        result = risk_difference(events_exp=10, n_exp=0, events_unexp=5, n_unexp=100)
        assert math.isnan(result.value)

    def test_calculates_rd_per_1000(self) -> None:
        """Should calculate RD correctly."""
        # Exposed: 100/1000 = 0.1, Unexposed: 50/1000 = 0.05
        # RD = (0.1 - 0.05) * 1000 = 50 per 1000
        result = risk_difference(
            events_exp=100, n_exp=1000, events_unexp=50, n_unexp=1000
        )
        assert result.value == pytest.approx(50.0, rel=0.01)

    def test_negative_rd_when_unexposed_higher(self) -> None:
        """RD should be negative when unexposed has higher risk."""
        result = risk_difference(
            events_exp=50, n_exp=1000, events_unexp=100, n_unexp=1000
        )
        assert result.value < 0

    def test_returns_effect_estimate_with_ci(self) -> None:
        """Should return EffectEstimate with valid CI."""
        result = risk_difference(
            events_exp=100, n_exp=1000, events_unexp=50, n_unexp=1000
        )
        assert isinstance(result, EffectEstimate)
        assert result.method == "risk_difference"
        assert result.ci.lower < result.value
        assert result.ci.upper > result.value


class TestRiskRatio:
    """Tests for risk ratio calculation."""

    def test_zero_unexposed_risk_returns_nan(self) -> None:
        """Zero risk in unexposed group should return NaN."""
        result = risk_ratio(events_exp=10, n_exp=100, events_unexp=0, n_unexp=100)
        assert math.isnan(result.value)

    def test_calculates_rr_correctly(self) -> None:
        """Should calculate RR correctly."""
        # Exposed: 100/1000 = 0.1, Unexposed: 50/1000 = 0.05
        # RR = 0.1 / 0.05 = 2.0
        result = risk_ratio(
            events_exp=100, n_exp=1000, events_unexp=50, n_unexp=1000
        )
        assert result.value == pytest.approx(2.0, rel=0.01)

    def test_rr_less_than_one_when_exposed_lower(self) -> None:
        """RR < 1 when exposed has lower risk."""
        result = risk_ratio(
            events_exp=50, n_exp=1000, events_unexp=100, n_unexp=1000
        )
        assert result.value < 1.0

    def test_ci_uses_log_transformation(self) -> None:
        """CI should be asymmetric around point estimate (log scale)."""
        result = risk_ratio(
            events_exp=100, n_exp=1000, events_unexp=50, n_unexp=1000
        )
        # Distances from RR should not be equal
        lower_dist = result.value - result.ci.lower
        upper_dist = result.ci.upper - result.value
        # Log-scale CI is asymmetric
        assert lower_dist != pytest.approx(upper_dist, rel=0.1)


class TestIncidenceRateDifference:
    """Tests for incidence rate difference."""

    def test_zero_person_time_returns_nan(self) -> None:
        """Zero person-time should return NaN."""
        result = incidence_rate_difference(
            events_exp=10, person_time_exp=0, events_unexp=5, person_time_unexp=100
        )
        assert math.isnan(result.value)

    def test_calculates_ird_per_1000py(self) -> None:
        """Should calculate IRD per 1000 person-years."""
        # Rate exp: 100/1000 = 0.1 per PY = 100 per 1000 PY
        # Rate unexp: 50/1000 = 0.05 per PY = 50 per 1000 PY
        # IRD = 50 per 1000 PY
        result = incidence_rate_difference(
            events_exp=100,
            person_time_exp=1000,
            events_unexp=50,
            person_time_unexp=1000,
        )
        assert result.value == pytest.approx(50.0, rel=0.01)


class TestIncidenceRateRatio:
    """Tests for incidence rate ratio."""

    def test_calculates_irr_correctly(self) -> None:
        """Should calculate IRR correctly."""
        # Rate exp: 100/1000 = 0.1, Rate unexp: 50/1000 = 0.05
        # IRR = 0.1 / 0.05 = 2.0
        result = incidence_rate_ratio(
            events_exp=100,
            person_time_exp=1000,
            events_unexp=50,
            person_time_unexp=1000,
        )
        assert result.value == pytest.approx(2.0, rel=0.01)


class TestHazardRatioLogistic:
    """Tests for hazard ratio from logistic regression."""

    def test_exponentiates_coefficient(self) -> None:
        """HR should be exp(coefficient)."""
        # log(HR) = 0.693 -> HR = 2.0
        result = hazard_ratio_logistic(coefficient=0.693, std_error=0.1)
        assert result.value == pytest.approx(2.0, rel=0.01)

    def test_calculates_wald_ci(self) -> None:
        """CI should use Wald method on log scale."""
        result = hazard_ratio_logistic(coefficient=0.693, std_error=0.2)
        assert result.ci.lower < result.value
        assert result.ci.upper > result.value
        assert result.method == "logistic"

    def test_includes_pvalue_if_provided(self) -> None:
        """Should include p-value when provided."""
        result = hazard_ratio_logistic(
            coefficient=0.693, std_error=0.1, p_value=0.001
        )
        assert result.p_value == 0.001


class TestHazardRatioRobust:
    """Tests for hazard ratio with robust variance."""

    def test_uses_robust_se_for_ci(self) -> None:
        """CI should use robust SE on log scale."""
        result = hazard_ratio_robust(hr=2.0, robust_se=0.2)
        assert result.value == 2.0
        assert result.ci.lower < 2.0
        assert result.ci.upper > 2.0
        assert result.method == "robust_sandwich"


class TestDerivedMeasures:
    """Tests for NNT, AR, PAR."""

    def test_nnt_positive_rd(self) -> None:
        """NNT should be 1/RD when RD > 0."""
        # RD = 0.1 - 0.05 = 0.05, NNT = 20
        nnt = number_needed_to_treat(risk_exp=0.1, risk_unexp=0.05)
        assert nnt == pytest.approx(20.0, rel=0.01)

    def test_nnt_negative_rd_returns_none(self) -> None:
        """NNT should be None when RD <= 0."""
        nnt = number_needed_to_treat(risk_exp=0.05, risk_unexp=0.1)
        assert nnt is None

    def test_ar_calculates_correctly(self) -> None:
        """AR = (risk_exp - risk_unexp) / risk_exp."""
        ar = attributable_risk(risk_exp=0.1, risk_unexp=0.05)
        # AR = (0.1 - 0.05) / 0.1 = 0.5
        assert ar == pytest.approx(0.5, rel=0.01)

    def test_ar_zero_risk_returns_none(self) -> None:
        """AR should be None when risk_exp = 0."""
        ar = attributable_risk(risk_exp=0.0, risk_unexp=0.05)
        assert ar is None

    def test_par_calculates_correctly(self) -> None:
        """PAR = (pop_risk - risk_unexp) / pop_risk."""
        par = population_attributable_risk(population_risk=0.08, risk_unexp=0.05)
        # PAR = (0.08 - 0.05) / 0.08 = 0.375
        assert par == pytest.approx(0.375, rel=0.01)
