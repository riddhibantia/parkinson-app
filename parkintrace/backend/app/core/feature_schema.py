"""Canonical feature schema (spec 6.4). Single source of truth for
feature name, unit, description, required/optional, Layer 1 / Layer 2 usage.

Units: all timing in MILLISECONDS end-to-end (capture -> API -> storage).
No ms/sec conversions anywhere in the new path (spec 7.2).
"""

from app.core.constants import MOTOR_TASK_FEATURE_LIST, TYPING_FEATURE_LIST

FEATURE_SCHEMA: dict[str, dict] = {
    "ht_mean": {"unit": "ms", "description": "Mean key hold time (keydown->keyup).",
                "required": True, "layer1": True, "layer2": True},
    "ht_std": {"unit": "ms", "description": "SD of hold time.",
               "required": True, "layer1": True, "layer2": True},
    "ft_mean": {"unit": "ms", "description": "Mean flight time (keyup->next keydown).",
                "required": True, "layer1": True, "layer2": True},
    "ft_std": {"unit": "ms", "description": "SD of flight time.",
               "required": True, "layer1": True, "layer2": True},
    "ikl_mean": {"unit": "ms", "description": "Mean inter-key latency (keydown->next keydown).",
                 "required": True, "layer1": True, "layer2": True},
    "ikl_std": {"unit": "ms", "description": "SD of inter-key latency.",
                "required": True, "layer1": True, "layer2": True},
    "left_ht_mean": {"unit": "ms", "description": "Mean hold time, left-hand keys.",
                     "required": True, "layer1": True, "layer2": True},
    "right_ht_mean": {"unit": "ms", "description": "Mean hold time, right-hand keys.",
                      "required": True, "layer1": True, "layer2": True},
    "hand_asymmetry": {"unit": "ratio", "description": "abs(L-R)/max(L,R) hold asymmetry.",
                       "required": False, "layer1": True, "layer2": True},
    "pause_frequency": {"unit": "count/min", "description": "Pauses (>500ms FT) per minute.",
                        "required": True, "layer1": True, "layer2": True},
    "typing_speed": {"unit": "keys/s", "description": "Character keys per second.",
                     "required": True, "layer1": True, "layer2": True},
    "session_consistency": {"unit": "ratio", "description": "Coefficient of variation of IKL (std/mean).",
                            "required": False, "layer1": True, "layer2": True},
    "backspace_rate": {"unit": "count/min",
                       "description": "Backspace corrections per minute. Context/correction signal only; NOT a Layer 1 training feature (research datasets lack it).",
                       "required": False, "layer1": False, "layer2": True},
    "valid_taps": {"unit": "count", "description": "Motor task: valid alternating taps.",
                   "required": True, "layer1": False, "layer2": True},
    "mean_iti_ms": {"unit": "ms", "description": "Motor task: mean inter-tap interval.",
                    "required": True, "layer1": False, "layer2": True},
    "std_iti_ms": {"unit": "ms", "description": "Motor task: SD of inter-tap interval.",
                   "required": True, "layer1": False, "layer2": True},
    "miss_rate": {"unit": "ratio", "description": "Motor task: fraction of taps breaking alternation.",
                  "required": True, "layer1": False, "layer2": True},
    "extra_tap_count": {"unit": "count", "description": "Motor task: taps breaking alternation.",
                        "required": True, "layer1": False, "layer2": True},
    "slowing_slope_ms": {"unit": "ms/tap", "description": "Motor task: ITI slope over tap index.",
                         "required": False, "layer1": False, "layer2": True},
}

CANONICAL_TYPING_FEATURES = list(TYPING_FEATURE_LIST)
CANONICAL_MOTOR_FEATURES = list(MOTOR_TASK_FEATURE_LIST)


def validate_feature_vector(features: dict, *, motor: bool = False) -> list[str]:
    """Return names of usable (finite numeric) features. Never raises for
    bad values — callers skip unusable features (spec 11.4)."""
    import math

    names = CANONICAL_MOTOR_FEATURES if motor else CANONICAL_TYPING_FEATURES
    usable = []
    for name in names:
        value = features.get(name)
        if isinstance(value, bool):
            continue
        if isinstance(value, (int, float)) and math.isfinite(float(value)):
            usable.append(name)
    return usable
