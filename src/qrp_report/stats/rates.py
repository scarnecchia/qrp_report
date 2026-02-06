"""Rate calculations with confidence intervals.

Implements:
- Incidence rate per 1000 person-years with Poisson CI
- Risk per 1000 new users with Binomial CI

Based on SAS patterns from t1t2t4conc_createdata.sas lines 213-262.
"""

import math
from typing import Optional

from qrp_report.stats.types import ConfidenceInterval, RateResult


def poisson_ci(events: int, rate: float, alpha: float = 0.05) -> ConfidenceInterval:
    """Calculate Poisson confidence interval for a rate.

    Uses log-scale approximation:
        SE = sqrt(1 / events)
        CI = rate * exp(±z * SE)

    Args:
        events: Number of events
        rate: Point estimate (rate per unit time)
        alpha: Significance level (default 0.05 for 95% CI)

    Returns:
        ConfidenceInterval with lower and upper bounds

    Note:
        If events = 0, returns CI of (0, 0)
    """
    if events <= 0:
        return ConfidenceInterval(lower=0.0, upper=0.0)

    z = 1.96  # For 95% CI
    se = math.sqrt(1.0 / events)

    # CI on log scale, then transform back
    log_rate = math.log(rate) if rate > 0 else float("-inf")
    lower = math.exp(log_rate - z * se) if rate > 0 else 0.0
    upper = math.exp(log_rate + z * se) if rate > 0 else 0.0

    return ConfidenceInterval(lower=lower, upper=upper, level=1 - alpha)


def binomial_ci(
    events: int, n: int, proportion: float, alpha: float = 0.05
) -> ConfidenceInterval:
    """Calculate Binomial confidence interval for a proportion.

    Uses normal approximation:
        SE = sqrt(p * (1-p) / n)
        CI = p ± z * SE

    Args:
        events: Number of events
        n: Total count (denominator)
        proportion: Point estimate (events / n)
        alpha: Significance level (default 0.05 for 95% CI)

    Returns:
        ConfidenceInterval with lower and upper bounds

    Note:
        Bounds are clamped to [0, 1] for proportions
    """
    if n <= 0:
        return ConfidenceInterval(lower=0.0, upper=0.0)

    z = 1.96  # For 95% CI
    p = proportion
    q = 1 - p
    se = math.sqrt((p * q) / n) if p > 0 and q > 0 else 0.0

    lower = max(0.0, p - z * se)
    upper = min(1.0, p + z * se)

    return ConfidenceInterval(lower=lower, upper=upper, level=1 - alpha)


def incidence_rate(
    events: int,
    person_days: float,
    per: int = 1000,
) -> RateResult:
    """Calculate incidence rate per 1000 person-years.

    Formula: IR = (events / person_years) * per

    Args:
        events: Number of events
        person_days: Total follow-up time in days
        per: Multiplier (default 1000 for "per 1000 PY")

    Returns:
        RateResult with rate, CI, and metadata

    Note:
        Converts days to years using 365.25 days/year
    """
    person_years = person_days / 365.25

    if person_years <= 0:
        return RateResult(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            events=events,
            denominator=person_years,
            per=per,
        )

    rate = (events / person_years) * per
    ci = poisson_ci(events, rate)

    # Scale CI by the same multiplier
    scaled_ci = ConfidenceInterval(lower=ci.lower, upper=ci.upper, level=ci.level)

    return RateResult(
        value=rate,
        ci=scaled_ci,
        events=events,
        denominator=person_years,
        per=per,
    )


def risk_per_1000(
    events: int,
    n: int,
    per: int = 1000,
) -> RateResult:
    """Calculate risk per 1000 new users.

    Formula: Risk = (events / n) * per

    Args:
        events: Number of events
        n: Number of new users (or episodes)
        per: Multiplier (default 1000 for "per 1000 users")

    Returns:
        RateResult with risk, CI, and metadata
    """
    if n <= 0:
        return RateResult(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            events=events,
            denominator=float(n),
            per=per,
        )

    proportion = events / n
    risk = proportion * per

    # Binomial CI on proportion, then scale
    ci = binomial_ci(events, n, proportion)
    scaled_ci = ConfidenceInterval(
        lower=ci.lower * per,
        upper=ci.upper * per,
        level=ci.level,
    )

    return RateResult(
        value=risk,
        ci=scaled_ci,
        events=events,
        denominator=float(n),
        per=per,
    )
