"""Covariate balance assessment.

Implements standardized difference calculation for assessing
balance between exposure and comparator groups.

Based on SAS patterns from baseline_compute.sas lines ~500.
"""

from qrp_report.stats.types import BalanceResult


def standardized_difference(
    mean_exp: float,
    mean_comp: float,
    std_exp: float,
    std_comp: float,
    threshold: float = 0.1,
) -> BalanceResult:
    """Calculate standardized mean difference for covariate balance.

    Formula (Cohen's d approach):
        SMD = |mean_exp - mean_comp| / sqrt((var_exp + var_comp) / 2)

    Interpretation:
        SMD < 0.1: Good balance
        SMD >= 0.1: Possible imbalance

    Args:
        mean_exp: Mean in exposure group
        mean_comp: Mean in comparator group
        std_exp: Standard deviation in exposure group
        std_comp: Standard deviation in comparator group
        threshold: Balance threshold (default 0.1)

    Returns:
        BalanceResult with absolute and standardized difference
    """
    return BalanceResult.compute(
        mean_exp=mean_exp,
        mean_comp=mean_comp,
        std_exp=std_exp,
        std_comp=std_comp,
        threshold=threshold,
    )


def aggregate_balance(
    results: list[BalanceResult],
) -> tuple[int, int, float]:
    """Summarize balance across multiple covariates.

    Args:
        results: List of BalanceResult for each covariate

    Returns:
        Tuple of (balanced_count, total_count, max_smd)
    """
    if not results:
        return (0, 0, 0.0)

    balanced = sum(1 for r in results if r.balanced)
    total = len(results)
    max_smd = max(r.standardized_diff for r in results)

    return (balanced, total, max_smd)
