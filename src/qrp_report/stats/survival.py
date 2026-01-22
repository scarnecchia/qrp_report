"""Kaplan-Meier survival analysis.

Implements survival curve estimation with Greenwood variance
based on SAS patterns from l2_effect_estimate_km_createdata.sas.
"""

import math
from dataclasses import dataclass
from typing import Sequence

import polars as pl

from qrp_report.stats.types import ConfidenceInterval, SurvivalPoint


@dataclass(frozen=True)
class SurvivalData:
    """Input data for survival analysis at a single time point.

    Attributes:
        time: Time point (in days)
        events: Number of events at this time
        at_risk: Number at risk immediately before this time
        censored: Number censored at this time (optional)
    """

    time: int
    events: int
    at_risk: int
    censored: int = 0


def greenwood_variance_component(events: int, at_risk: int) -> float:
    """Calculate single variance component for Greenwood's formula.

    Formula: d / [n * (n - d)]

    Args:
        events: Number of events (d)
        at_risk: Number at risk (n)

    Returns:
        Variance component, or 0 if invalid
    """
    if at_risk <= 0 or at_risk <= events:
        return 0.0
    return events / (at_risk * (at_risk - events))


def greenwood_ci(
    survival: float,
    cumulative_variance: float,
    alpha: float = 0.05,
) -> ConfidenceInterval:
    """Calculate confidence interval using Greenwood's formula.

    Uses log-log transformation for CI:
        CI_lower = S(t) ^ exp(-z * sqrt(V) / log(S(t)))
        CI_upper = S(t) ^ exp(z * sqrt(V) / log(S(t)))

    Args:
        survival: Survival probability S(t)
        cumulative_variance: Sum of variance components up to time t
        alpha: Significance level (default 0.05)

    Returns:
        ConfidenceInterval for survival probability
    """
    z = 1.96  # For 95% CI

    # Handle edge cases
    if survival <= 0.0 or survival >= 1.0:
        return ConfidenceInterval(lower=survival, upper=survival)

    if cumulative_variance <= 0.0:
        return ConfidenceInterval(lower=survival, upper=survival)

    # Greenwood CI on log-log scale
    log_s = math.log(survival)
    sqrt_var = math.sqrt(cumulative_variance)
    qt3 = sqrt_var * survival

    # Transform: S^exp(±z*qt3/log(S))
    lower = survival ** math.exp((-z * qt3) / log_s)
    upper = survival ** math.exp((z * qt3) / log_s)

    # Ensure bounds are valid probabilities
    lower = max(0.0, min(1.0, lower))
    upper = max(0.0, min(1.0, upper))

    return ConfidenceInterval(lower=lower, upper=upper, level=1 - alpha)


def kaplan_meier(data: Sequence[SurvivalData]) -> list[SurvivalPoint]:
    """Calculate Kaplan-Meier survival curve.

    Implements standard KM estimator:
        S(t) = S(t-1) * (1 - d_t / n_t)

    With Greenwood's variance:
        Var[log S(t)] = sum{ d_i / [n_i * (n_i - d_i)] }

    Args:
        data: Sequence of SurvivalData points, sorted by time

    Returns:
        List of SurvivalPoint with survival estimates and CIs
    """
    if not data:
        return []

    # Sort by time to ensure correct order
    sorted_data = sorted(data, key=lambda x: x.time)

    results: list[SurvivalPoint] = []
    survival = 1.0
    cumulative_variance = 0.0

    for point in sorted_data:
        # At time 0, survival is 1.0
        if point.time == 0:
            results.append(
                SurvivalPoint(
                    time=0,
                    survival=1.0,
                    ci=ConfidenceInterval(lower=1.0, upper=1.0),
                    at_risk=point.at_risk,
                    events=0,
                    censored=point.censored,
                )
            )
            continue

        # Update survival if there are events
        if point.events > 0 and point.at_risk > 0:
            survival *= 1 - (point.events / point.at_risk)

            # Accumulate variance component
            var_component = greenwood_variance_component(point.events, point.at_risk)
            cumulative_variance += var_component

        # Calculate CI
        ci = greenwood_ci(survival, cumulative_variance)

        results.append(
            SurvivalPoint(
                time=point.time,
                survival=survival,
                ci=ci,
                at_risk=point.at_risk,
                events=point.events,
                censored=point.censored,
            )
        )

    return results


def kaplan_meier_from_dataframe(
    df: pl.DataFrame,
    time_col: str = "followupday",
    events_col: str = "events",
    at_risk_col: str = "at_risk",
    censored_col: str | None = "censored",
) -> list[SurvivalPoint]:
    """Calculate Kaplan-Meier from a polars DataFrame.

    Args:
        df: DataFrame with survival data
        time_col: Column name for time points
        events_col: Column name for event counts
        at_risk_col: Column name for at-risk counts
        censored_col: Column name for censored counts (optional)

    Returns:
        List of SurvivalPoint with survival estimates
    """
    data: list[SurvivalData] = []

    for row in df.iter_rows(named=True):
        censored = row.get(censored_col, 0) if censored_col else 0
        data.append(
            SurvivalData(
                time=int(row[time_col]),
                events=int(row[events_col]),
                at_risk=int(row[at_risk_col]),
                censored=int(censored) if censored is not None else 0,
            )
        )

    return kaplan_meier(data)
