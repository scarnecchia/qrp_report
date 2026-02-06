"""QRP Report statistics module.

Provides statistical computation functions for epidemiological analyses:
- Baseline statistics (means, SDs, standardized differences)
- Incidence rates with confidence intervals
- Kaplan-Meier survival analysis
- Effect estimates (HR, RR, RD)
"""

from qrp_report.stats.types import (
    ConfidenceInterval,
    RateResult,
    SurvivalPoint,
    EffectEstimate,
    BalanceResult,
)
from qrp_report.stats.rates import (
    incidence_rate,
    risk_per_1000,
    poisson_ci,
    binomial_ci,
)
from qrp_report.stats.survival import (
    kaplan_meier,
    greenwood_ci,
)
from qrp_report.stats.effect_estimates import (
    risk_difference,
    risk_ratio,
    incidence_rate_difference,
    incidence_rate_ratio,
    hazard_ratio_logistic,
    hazard_ratio_robust,
)
from qrp_report.stats.balance import (
    standardized_difference,
    aggregate_balance,
)

__all__ = [
    # Types
    "ConfidenceInterval",
    "RateResult",
    "SurvivalPoint",
    "EffectEstimate",
    "BalanceResult",
    # Rates
    "incidence_rate",
    "risk_per_1000",
    "poisson_ci",
    "binomial_ci",
    # Survival
    "kaplan_meier",
    "greenwood_ci",
    # Effect estimates
    "risk_difference",
    "risk_ratio",
    "incidence_rate_difference",
    "incidence_rate_ratio",
    "hazard_ratio_logistic",
    "hazard_ratio_robust",
    # Balance
    "standardized_difference",
    "aggregate_balance",
]
