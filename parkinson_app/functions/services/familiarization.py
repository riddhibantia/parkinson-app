"""Familiarization readiness gate (Stage 1.6 / 2.2 / 6.3).

Practice sessions are evaluated here only. All users need >= 1 good
practice session; users reporting 'not familiar' need 2 plus a stability
check. This is a readiness/stability heuristic, not a health threshold.
"""

import numpy as np

from utils.constants import (
    FAMILIARIZATION_CORE_FEATURES,
    FAMILIARIZATION_MAX_MEDIAN_APC,
)


def median_apc(previous: dict, current: dict) -> float:
    """Median absolute percentage change across core timing features."""
    changes = []
    for name in FAMILIARIZATION_CORE_FEATURES:
        a = float(previous[name])
        b = float(current[name])
        denominator = max(abs(a), abs(b), 1e-6)
        changes.append(abs(a - b) / denominator)
    return float(np.median(changes))


def familiarization_ready(previous: dict, current: dict) -> bool:
    return median_apc(previous, current) <= FAMILIARIZATION_MAX_MEDIAN_APC


def required_practice_sessions(experience_level: str) -> int:
    return 2 if experience_level == "not_familiar" else 1
