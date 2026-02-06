"""Statistical result types for QRP Report.

All statistical computations return typed dataclasses for type safety
and clear documentation of what each function produces.
"""

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class ConfidenceInterval:
    """95% confidence interval bounds."""

    lower: float
    upper: float
    level: float = 0.95

    def __post_init__(self) -> None:
        if self.lower > self.upper:
            raise ValueError(
                f"lower bound ({self.lower}) cannot exceed upper bound ({self.upper})"
            )


@dataclass(frozen=True)
class RateResult:
    """Result of a rate calculation (incidence rate or risk).

    Attributes:
        value: Point estimate (e.g., rate per 1000 person-years)
        ci: 95% confidence interval
        events: Number of events
        denominator: Person-time (for IR) or count (for risk)
        per: Multiplier used (e.g., 1000 for "per 1000")
    """

    value: float
    ci: ConfidenceInterval
    events: int
    denominator: float
    per: int = 1000


@dataclass(frozen=True)
class SurvivalPoint:
    """Single point on a Kaplan-Meier survival curve.

    Attributes:
        time: Time point (in days)
        survival: Survival probability S(t)
        ci: 95% confidence interval for S(t)
        at_risk: Number at risk at this time point
        events: Number of events at this time point
        censored: Number censored at this time point
    """

    time: int
    survival: float
    ci: ConfidenceInterval
    at_risk: int
    events: int
    censored: int


@dataclass(frozen=True)
class EffectEstimate:
    """Result of an effect estimate calculation (HR, RR, RD).

    Attributes:
        value: Point estimate
        ci: 95% confidence interval
        p_value: P-value from statistical test (if available)
        method: Method used (e.g., "logistic", "robust", "stratified")
    """

    value: float
    ci: ConfidenceInterval
    p_value: Optional[float] = None
    method: str = ""


@dataclass(frozen=True)
class BalanceResult:
    """Result of covariate balance assessment.

    Attributes:
        absolute_diff: Absolute difference between group means
        standardized_diff: Standardized mean difference (Cohen's d approach)
        balanced: Whether balance threshold is met (|SMD| < 0.1)
    """

    absolute_diff: float
    standardized_diff: float
    balanced: bool

    @classmethod
    def compute(
        cls,
        mean_exp: float,
        mean_comp: float,
        std_exp: float,
        std_comp: float,
        threshold: float = 0.1,
    ) -> "BalanceResult":
        """Compute balance metrics from group statistics.

        Args:
            mean_exp: Mean in exposure group
            mean_comp: Mean in comparator group
            std_exp: Standard deviation in exposure group
            std_comp: Standard deviation in comparator group
            threshold: Balance threshold (default 0.1)

        Returns:
            BalanceResult with computed metrics
        """
        abs_diff = abs(mean_exp - mean_comp)

        pooled_var = (std_exp**2 + std_comp**2) / 2
        if pooled_var > 0:
            std_diff = abs_diff / (pooled_var**0.5)
        else:
            std_diff = 0.0

        return cls(
            absolute_diff=abs_diff,
            standardized_diff=std_diff,
            balanced=std_diff < threshold,
        )
