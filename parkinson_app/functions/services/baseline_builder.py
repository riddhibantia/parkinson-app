"""Personal baseline construction (Stage 5.1).

Builds the frozen baseline from the first qualifying post-familiarization
screening sessions: 10+ sessions, spanning 5+ days, inside a 21-day window,
anchored to one keyboard. Sessions are plain dicts (Firestore-shaped) with
`timestamp` (datetime), `device_id`, and typing-feature keys.

Stage 5 plugs `fit_personal_anomaly_model(baseline_sessions)` onto the
returned session list at the marked site — the Isolation Forest fit is
ML training and is NOT done here.
"""

from collections import Counter
from datetime import datetime, timedelta

import numpy as np

from utils.constants import (
    BASELINE_WINDOW_DAYS,
    MINIMUM_BASELINE_SPAN_DAYS,
    MINIMUM_SESSIONS_FOR_BASELINE,
    MOTOR_TASK_FEATURE_LIST,
    TYPING_FEATURE_LIST,
)

# Layer 2 feature groups (Stage 5.1b). Typing sessions score on the typing
# group, motor-task sessions on the motor group — never mixed. Neither
# group ever contains demographics, symptoms, or medication state.
LAYER2_TYPING_FEATURES = [f for f in TYPING_FEATURE_LIST]

# Quality flags that disqualify a session from baseline training.
# 'unusual_hour' is a weight hint only — it never excludes.
BLOCKING_QUALITY_FLAGS = {"too_short", "too_few_keystrokes"}


def eligible_sessions(sessions: list) -> list:
    """Hard gate: familiarization and poor-quality sessions can never
    enter baseline training, no matter what the caller passes in."""
    eligible = []
    for session in sessions:
        if session.get("session_phase", "screening") == "familiarization":
            continue
        flags = set(session.get("quality_flags", []) or [])
        if flags & BLOCKING_QUALITY_FLAGS:
            continue
        eligible.append(session)
    return eligible


def baseline_quality_ok(sessions: list) -> tuple:
    """Count is a floor, not a target: sessions must span enough distinct
    days to count as representative of normal typing."""
    distinct_days = len({s["timestamp"].date() for s in sessions})
    if distinct_days < MINIMUM_BASELINE_SPAN_DAYS:
        return False, (
            f"Sessions span only {distinct_days} days — "
            f"need {MINIMUM_BASELINE_SPAN_DAYS}+"
        )
    return True, "ok"


def build_baseline(sessions: list) -> tuple:
    """Return (baseline_dict | None, baseline_sessions).

    Only qualifying sessions survive: screening phase, no blocking
    quality flags, inside the 21-day window, on the anchor keyboard.
    The baseline dict holds frozen per-feature reference statistics plus
    the anchor device id and window bounds. Callers persist it and fit
    the personal Isolation Forest on baseline_sessions (Stage 5.4).
    """
    sessions = eligible_sessions(sessions)
    if len(sessions) < MINIMUM_SESSIONS_FOR_BASELINE:
        return None, []

    sessions = sorted(sessions, key=lambda s: s["timestamp"])
    window_start = sessions[0]["timestamp"]
    window_end = window_start + timedelta(days=BASELINE_WINDOW_DAYS)
    sessions = [s for s in sessions if s["timestamp"] <= window_end]

    if len(sessions) < MINIMUM_SESSIONS_FOR_BASELINE:
        return None, []

    ok, _ = baseline_quality_ok(sessions)
    if not ok:
        return None, []

    # Anchor to one keyboard so hardware differences never read as drift.
    device_counts = Counter(s["device_id"] for s in sessions)
    anchor_device, count = device_counts.most_common(1)[0]
    if count < MINIMUM_SESSIONS_FOR_BASELINE:
        return None, []
    baseline_sessions = [s for s in sessions if s["device_id"] == anchor_device]
    if len(baseline_sessions) < MINIMUM_SESSIONS_FOR_BASELINE:
        return None, []

    features = {}
    for name in TYPING_FEATURE_LIST + MOTOR_TASK_FEATURE_LIST:
        values = np.array(
            [s[name] for s in baseline_sessions if s.get(name) is not None],
            dtype=float,
        )
        if len(values) == 0:
            continue
        median = float(np.median(values))
        mad = float(np.median(np.abs(values - median)))
        features[name] = {
            "median": median,
            "mad": mad,
            "mean": float(np.mean(values)),
            "std": float(np.std(values)),
            "p25": float(np.percentile(values, 25)),
            "p75": float(np.percentile(values, 75)),
        }

    baseline = {
        "features": features,
        "session_count": len(baseline_sessions),
        "anchor_device_id": anchor_device,
        "built_date": datetime.utcnow(),
        "window_start": baseline_sessions[0]["timestamp"],
        "window_end": baseline_sessions[-1]["timestamp"],
    }
    return baseline, baseline_sessions
