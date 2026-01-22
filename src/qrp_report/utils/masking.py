"""DP masking utilities."""

import random


def create_dp_mask_mapping(
    dp_ids: list[str],
    seed: int | None = None,
) -> dict[str, str]:
    """Create randomized DP ID masking.

    Args:
        dp_ids: List of original DP identifiers.
        seed: Random seed for reproducibility.

    Returns:
        Dict mapping original IDs to masked IDs (DP01, DP02, etc.).
    """
    if not dp_ids:
        return {}

    rng = random.Random(seed)
    shuffled = dp_ids.copy()
    rng.shuffle(shuffled)

    return {
        original: f"DP{i:02d}"
        for i, original in enumerate(shuffled, start=1)
    }


def mask_dp_id(dp_id: str, mapping: dict[str, str]) -> str:
    """Get masked ID for a DP.

    Args:
        dp_id: Original DP identifier.
        mapping: Mapping from original to masked IDs.

    Returns:
        Masked ID, or original if not in mapping.
    """
    return mapping.get(dp_id, dp_id)
