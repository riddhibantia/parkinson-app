"""Personal baseline construction (ported, validated).

Source: functions/services/baseline_builder.py.
Gate: 10+ valid sessions AND 5+ distinct days AND 21-day window AND one
anchor keyboard (spec 10.1). Blocking flags exclude; unusual_hour never
excludes. Baseline freezes once established (spec 10.3).

Session dicts accept canonical keys (started_at/device_id/quality_flags)
with legacy fallbacks (timestamp/deviceId/session_phase) handled at the
boundary so old exports can be re-validated without silent renaming.
"""

from collections import Counter
from datetime import datetime, timedelta

import numpy as np

from app.core.constants import (
    BASELINE_WINDOW_DAYS,
    MINIMUM_BASELINE_SPAN_DAYS,
    MINIMUM_SESSIONS_FOR_BASELINE,
    MOTOR_TASK_FEATURE_LIST,
    TYPING_FEATURE_LIST,
)

LAYER2_TYPING_FEATURES = [f for f in TYPING_FEATURE_LIST]

BLOCKING_QUALITY_FLAGS = {"too_short", "too_few_keystrokes"}


def _ts(session: dict):
    return session.get("started_at", session.get("timestamp"))


def _device(session: dict):
    return session.get("device_id", session.get("deviceId"))


def _flags(session: dict) -> set:
    return set(session.get("quality_flags", session.get("qualityFlags", [])) or [])


def _phase(session: dict) -> str:
    return session.get("session_type", session.get("session_phase", "screening"))


def eligible_sessions(sessions: list) -> list:
    """Hard gate: legacy familiarization rows and poor-quality sessions
    can never enter baseline training."""
    eligible = []
    for session in sessions:
        if _phase(session) == "familiarization":
            continue
        if _flags(session) & BLOCKING_QUALITY_FLAGS:
            continue
        if _ts(session) is None or _device(session) is None:
            continue
        eligible.append(session)
    return eligible


def baseline_quality_ok(sessions: list) -> tuple:
    """Distinct-day span floor."""
    distinct_days = len({_ts(s).date() for s in sessions})
    if distinct_days < MINIMUM_BASELINE_SPAN_DAYS:
        return False, (
            f"Sessions span only {distinct_days} days — "
            f"need {MINIMUM_BASELINE_SPAN_DAYS}+"
        )
    return True, "ok"


def build_baseline(sessions: list) -> tuple:
    """Return (baseline_dict | None, baseline_sessions). Frozen on success."""
    sessions = eligible_sessions(sessions)
    if len(sessions) < MINIMUM_SESSIONS_FOR_BASELINE:
        return None, []

    sessions = sorted(sessions, key=lambda s: _ts(s))
    window_start = _ts(sessions[0])
    window_end = window_start + timedelta(days=BASELINE_WINDOW_DAYS)
    sessions = [s for s in sessions if _ts(s) <= window_end]

    if len(sessions) < MINIMUM_SESSIONS_FOR_BASELINE:
        return None, []

    ok, _ = baseline_quality_ok(sessions)
    if not ok:
        return None, []

    device_counts = Counter(_device(s) for s in sessions)
    anchor_device, count = device_counts.most_common(1)[0]
    if count < MINIMUM_SESSIONS_FOR_BASELINE:
        return None, []
    baseline_sessions = [s for s in sessions if _device(s) == anchor_device]
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
        "window_start": _ts(baseline_sessions[0]),
        "window_end": _ts(baseline_sessions[-1]),
    }
    return baseline, baseline_sessions
