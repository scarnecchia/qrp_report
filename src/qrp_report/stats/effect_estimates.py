"""Effect estimate calculations (HR, RR, RD).

Implements:
- Risk difference with CI
- Risk ratio with CI
- Hazard ratio via logistic regression (stub for statsmodels)
- Hazard ratio with robust sandwich variance

Based on SAS patterns from:
- l2_effect_estimate_runrd_rs.sas
- l2_effect_estimate_runlogithr.sas
- l2_effect_estimate_runrobustest.sas
"""

import math
from typing import Optional

from qrp_report.stats.types import ConfidenceInterval, EffectEstimate


def risk_difference(
    events_exp: int,
    n_exp: int,
    events_unexp: int,
    n_unexp: int,
    per: int = 1000,
) -> EffectEstimate:
    """Calculate risk difference with confidence interval.

    Formula: RD = (events_exp/n_exp - events_unexp/n_unexp) * per

    Args:
        events_exp: Events in exposed group
        n_exp: Total in exposed group
        events_unexp: Events in unexposed group
        n_unexp: Total in unexposed group
        per: Multiplier (default 1000 for "per 1000")

    Returns:
        EffectEstimate with RD and CI
    """
    if n_exp <= 0 or n_unexp <= 0:
        return EffectEstimate(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            method="risk_difference",
        )

    risk_exp = events_exp / n_exp
    risk_unexp = events_unexp / n_unexp
    rd = (risk_exp - risk_unexp) * per

    # Simple CI using pooled variance
    # SE = sqrt(p1*(1-p1)/n1 + p2*(1-p2)/n2) * per
    var_exp = (risk_exp * (1 - risk_exp)) / n_exp if risk_exp > 0 else 0
    var_unexp = (risk_unexp * (1 - risk_unexp)) / n_unexp if risk_unexp > 0 else 0
    se = math.sqrt(var_exp + var_unexp) * per

    z = 1.96
    ci = ConfidenceInterval(
        lower=rd - z * se,
        upper=rd + z * se,
    )

    return EffectEstimate(value=rd, ci=ci, method="risk_difference")


def risk_ratio(
    events_exp: int,
    n_exp: int,
    events_unexp: int,
    n_unexp: int,
) -> EffectEstimate:
    """Calculate risk ratio with confidence interval.

    Formula: RR = (events_exp/n_exp) / (events_unexp/n_unexp)

    Uses log transformation for CI:
        SE(log RR) = sqrt(1/a - 1/n1 + 1/c - 1/n2)
        CI = exp(log(RR) +/- z * SE)

    Args:
        events_exp: Events in exposed group
        n_exp: Total in exposed group
        events_unexp: Events in unexposed group
        n_unexp: Total in unexposed group

    Returns:
        EffectEstimate with RR and CI
    """
    if n_exp <= 0 or n_unexp <= 0:
        return EffectEstimate(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            method="risk_ratio",
        )

    risk_exp = events_exp / n_exp
    risk_unexp = events_unexp / n_unexp

    if risk_unexp <= 0:
        return EffectEstimate(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            method="risk_ratio",
        )

    rr = risk_exp / risk_unexp

    # Log-scale CI
    if events_exp <= 0 or events_unexp <= 0:
        return EffectEstimate(
            value=rr,
            ci=ConfidenceInterval(lower=rr, upper=rr),
            method="risk_ratio",
        )

    # SE on log scale: sqrt(1/a - 1/n1 + 1/c - 1/n0)
    se_log = math.sqrt(
        (1 / events_exp) - (1 / n_exp) + (1 / events_unexp) - (1 / n_unexp)
    )

    z = 1.96
    log_rr = math.log(rr)
    ci = ConfidenceInterval(
        lower=math.exp(log_rr - z * se_log),
        upper=math.exp(log_rr + z * se_log),
    )

    return EffectEstimate(value=rr, ci=ci, method="risk_ratio")


def incidence_rate_difference(
    events_exp: int,
    person_time_exp: float,
    events_unexp: int,
    person_time_unexp: float,
    per: int = 1000,
) -> EffectEstimate:
    """Calculate incidence rate difference with CI.

    Formula: IRD = (events_exp/pt_exp - events_unexp/pt_unexp) * per

    Args:
        events_exp: Events in exposed group
        person_time_exp: Person-time in exposed group (years)
        events_unexp: Events in unexposed group
        person_time_unexp: Person-time in unexposed group (years)
        per: Multiplier (default 1000 for "per 1000 PY")

    Returns:
        EffectEstimate with IRD and CI
    """
    if person_time_exp <= 0 or person_time_unexp <= 0:
        return EffectEstimate(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            method="incidence_rate_difference",
        )

    rate_exp = events_exp / person_time_exp
    rate_unexp = events_unexp / person_time_unexp
    ird = (rate_exp - rate_unexp) * per

    # Variance of rate difference (Poisson)
    # Var(rate) = events / pt^2
    var_exp = events_exp / (person_time_exp**2) if events_exp > 0 else 0
    var_unexp = events_unexp / (person_time_unexp**2) if events_unexp > 0 else 0
    se = math.sqrt(var_exp + var_unexp) * per

    z = 1.96
    ci = ConfidenceInterval(
        lower=ird - z * se,
        upper=ird + z * se,
    )

    return EffectEstimate(value=ird, ci=ci, method="incidence_rate_difference")


def incidence_rate_ratio(
    events_exp: int,
    person_time_exp: float,
    events_unexp: int,
    person_time_unexp: float,
) -> EffectEstimate:
    """Calculate incidence rate ratio with CI.

    Formula: IRR = (events_exp/pt_exp) / (events_unexp/pt_unexp)

    Uses log transformation for CI.

    Args:
        events_exp: Events in exposed group
        person_time_exp: Person-time in exposed group
        events_unexp: Events in unexposed group
        person_time_unexp: Person-time in unexposed group

    Returns:
        EffectEstimate with IRR and CI
    """
    if person_time_exp <= 0 or person_time_unexp <= 0:
        return EffectEstimate(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            method="incidence_rate_ratio",
        )

    rate_exp = events_exp / person_time_exp
    rate_unexp = events_unexp / person_time_unexp

    if rate_unexp <= 0:
        return EffectEstimate(
            value=float("nan"),
            ci=ConfidenceInterval(lower=float("nan"), upper=float("nan")),
            method="incidence_rate_ratio",
        )

    irr = rate_exp / rate_unexp

    # Log-scale CI for rate ratio
    if events_exp <= 0 or events_unexp <= 0:
        return EffectEstimate(
            value=irr,
            ci=ConfidenceInterval(lower=irr, upper=irr),
            method="incidence_rate_ratio",
        )

    # SE on log scale: sqrt(1/events_exp + 1/events_unexp)
    se_log = math.sqrt((1 / events_exp) + (1 / events_unexp))

    z = 1.96
    log_irr = math.log(irr)
    ci = ConfidenceInterval(
        lower=math.exp(log_irr - z * se_log),
        upper=math.exp(log_irr + z * se_log),
    )

    return EffectEstimate(value=irr, ci=ci, method="incidence_rate_ratio")


def hazard_ratio_logistic(
    coefficient: float,
    std_error: float,
    p_value: Optional[float] = None,
) -> EffectEstimate:
    """Create hazard ratio estimate from logistic regression output.

    This function takes output from statsmodels GLM and packages it
    as an EffectEstimate. The actual model fitting is done externally.

    Args:
        coefficient: Log hazard ratio (beta) from logistic regression
        std_error: Standard error of coefficient
        p_value: P-value from Wald test (optional)

    Returns:
        EffectEstimate with HR and Wald CI
    """
    hr = math.exp(coefficient)

    z = 1.96
    ci = ConfidenceInterval(
        lower=math.exp(coefficient - z * std_error),
        upper=math.exp(coefficient + z * std_error),
    )

    return EffectEstimate(value=hr, ci=ci, p_value=p_value, method="logistic")


def hazard_ratio_robust(
    hr: float,
    robust_se: float,
) -> EffectEstimate:
    """Create hazard ratio estimate with robust sandwich variance.

    This function packages a pre-computed HR with its robust SE.
    The sandwich variance computation is done externally (complex
    matrix algebra better suited for numpy/scipy).

    Args:
        hr: Point estimate of hazard ratio
        robust_se: Robust standard error on log scale

    Returns:
        EffectEstimate with HR and robust CI
    """
    z = 1.96
    log_hr = math.log(hr) if hr > 0 else float("-inf")

    ci = ConfidenceInterval(
        lower=math.exp(log_hr - z * robust_se),
        upper=math.exp(log_hr + z * robust_se),
    )

    return EffectEstimate(value=hr, ci=ci, method="robust_sandwich")


def number_needed_to_treat(risk_exp: float, risk_unexp: float) -> Optional[float]:
    """Calculate number needed to treat.

    Formula: NNT = 1 / (risk_exp - risk_unexp)

    Args:
        risk_exp: Risk in exposed group (proportion)
        risk_unexp: Risk in unexposed group (proportion)

    Returns:
        NNT if positive risk difference, None otherwise
    """
    diff = risk_exp - risk_unexp
    if diff > 0:
        return 1 / diff
    return None


def attributable_risk(risk_exp: float, risk_unexp: float) -> Optional[float]:
    """Calculate attributable risk.

    Formula: AR = (risk_exp - risk_unexp) / risk_exp

    Args:
        risk_exp: Risk in exposed group
        risk_unexp: Risk in unexposed group

    Returns:
        AR if risk_exp > 0, None otherwise
    """
    if risk_exp > 0:
        return (risk_exp - risk_unexp) / risk_exp
    return None


def population_attributable_risk(
    population_risk: float, risk_unexp: float
) -> Optional[float]:
    """Calculate population attributable risk.

    Formula: PAR = (population_risk - risk_unexp) / population_risk

    Args:
        population_risk: Overall population risk
        risk_unexp: Risk in unexposed group

    Returns:
        PAR if population_risk > 0, None otherwise
    """
    if population_risk > 0:
        return (population_risk - risk_unexp) / population_risk
    return None
