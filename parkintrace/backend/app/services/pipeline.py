"""Canonical analysis pipeline (NEW — replaces functions/services/pipeline.py).

Differences from the legacy pipeline (all per spec, all intentional):
- NO familiarization/practice path (spec 4.2/27.1). Every valid session
  is a real measurement from session 1.
- NO screening_ready / blocked / familiarization_required states.
- NO second heuristic Layer 1 path (spec 27.2). One authoritative RF path.
- Canonical session contract: one session_id in, same session_id out
  (spec 14). This module never generates IDs.
- Layer 1 and Layer 2 stay independent; dual_result carries both
  without blending (spec 3.3).
- Supabase I/O lives in the API endpoints, NOT here: this module takes
  plain session/baseline dicts so the full journey is unit-testable.

Session dict shape in: canonical snake_case with started_at/device_id/
quality_flags, or legacy timestamp/deviceId fallbacks (boundary-tolerant).
"""

from app.core.constants import (
    LAYER2_CONFIDENCE_WINDOW,
    MINIMUM_SESSIONS_FOR_BASELINE,
    MOTOR_TASK_FEATURE_LIST,
    TYPING_FEATURE_LIST,
)
from app.services.baseline_builder import (
    LAYER2_TYPING_FEATURES,
    build_baseline,
)
from app.services.device_guard import check_device_consistency
from app.services.feature_extraction import (
    extract_features,
    extract_motor_task_features,
    within_session_series,
)
from app.services.layer1_screening import screen_against_reference
from app.services.layer2_anomaly import (
    feature_matrix,
    fit_personal_anomaly_model,
)
from app.services.layer2_drift import (
    dual_result,
    score_monitoring_session,
)
from app.services.quality_filter import validate_session

MIN_MOTOR_SESSIONS_FOR_MODEL = 10


def is_motor(session: dict) -> bool:
    kind = session.get("session_type", session.get("mode", "structured"))
    return kind == "motor_task"


def layer2_feature_list(session: dict) -> list:
    """Typing vs motor feature groups — never mixed, never demographic."""
    if is_motor(session):
        return MOTOR_TASK_FEATURE_LIST
    return LAYER2_TYPING_FEATURES


def _duration_sec(session: dict) -> float:
    if "duration_sec" in session:
        return float(session["duration_sec"])
    if "durationMs" in session:
        return float(session["durationMs"]) / 1000.0
    if "duration_ms" in session:
        return float(session["duration_ms"]) / 1000.0
    return 0.0


def _keystroke_count(session: dict) -> int:
    return int(session.get("keystroke_count",
                           session.get("keystrokeCount", 0)) or 0)


def _events(session: dict) -> list:
    events = session.get("events", []) or []
    # Dicts may be Pydantic-dumped (snake_case) or wire (camelCase);
    # the extractor accepts both.
    return events


def resolve_features(session: dict) -> dict:
    """Single code path: raw events/taps -> extractor, or pre-extracted
    feature fields. capture -> quality -> extract -> persist (spec 27.5)."""
    if is_motor(session):
        taps = session.get("taps", [])
        if taps:
            return extract_motor_task_features(taps)
        return {k: session.get(k) for k in MOTOR_TASK_FEATURE_LIST}
    events = _events(session)
    if events:
        return extract_features(events, _duration_sec(session))
    source = session.get("features", session)
    return {k: source.get(k) for k in TYPING_FEATURE_LIST}


def layer1_for_session(session: dict, features: dict) -> dict:
    """Population comparison. Motor-task has no reference matrix and is
    never scored by Layer 1 (validated rule preserved)."""
    if is_motor(session):
        return {
            "status": "not_applicable",
            "message": ("The tapping task is tracked in your personal "
                        "trend only; it has no population comparison."),
            "pd_probability": None,
            "top_contributors": None,
        }
    return screen_against_reference(features)


def analyze_session(
    session: dict,
    *,
    baseline: dict | None,
    baseline_sessions: list | None = None,
    recent_features: list | None = None,
    anomaly_model=None,
    sessions_since_baseline: int = 0,
) -> dict:
    """Analyze one persisted session. Returns stored-result shape
    (minus transport timestamp). Never invents a session id.

    collecting  -> baseline building (session 1 useful immediately,
                   layer1 real + progress counters).
    monitoring  -> baseline exists: device guard, then independent
                   Layer 1 + Layer 2 via dual_result.
    """
    features = resolve_features(session)
    current_series = (within_session_series(_events(session))
                      if _events(session) else None)

    if baseline is not None:
        device_check = check_device_consistency(session, baseline)
        if not device_check["proceed"]:
            return {
                "status": "device_mismatch",
                "layer1": layer1_for_session(session, features),
                "layer2": {"status": "device_mismatch",
                           "message": device_check["message"],
                           "baseline_status": "established",
                           "drift": {}, "anomaly": {},
                           "anomaly_run": False},
                "features": features,
                "within_session_series": current_series,
            }
        feature_list = layer2_feature_list(session)
        recent = list(recent_features or []) + [features]
        layer2_result = score_monitoring_session(
            baseline, anomaly_model, features, recent, feature_list)
        layer1_result = layer1_for_session(session, features)
        result = dual_result(layer1_result, layer2_result,
                             sessions_since_baseline,
                             LAYER2_CONFIDENCE_WINDOW)
        result["features"] = features
        result["within_session_series"] = current_series
        return result

    # No baseline yet: real Layer 1 + building progress (never "no result").
    layer1_result = layer1_for_session(session, features)
    collected = len(baseline_sessions or []) + 1
    return {
        "status": "collecting",
        "layer1": layer1_result,
        "layer2": {"status": "collecting",
                   "message": ("Session saved. Your personal baseline "
                               "builds as you add sessions across days."),
                   "baseline_status": "building",
                   "drift": {}, "anomaly": {},
                   "anomaly_run": False},
        "baseline_progress": {
            "sessions": collected,
            "required": MINIMUM_SESSIONS_FOR_BASELINE,
        },
        "features": features,
        "within_session_series": current_series,
    }


def maybe_build_baseline(all_sessions: list):
    """Attempt baseline construction; fit the personal IF model ONCE on
    the exact qualifying sessions when it succeeds. Returns
    (baseline, baseline_sessions, anomaly_model) or (None, [], None)."""
    baseline, used = build_baseline(all_sessions)
    if baseline is None:
        return None, [], None
    feature_list = LAYER2_TYPING_FEATURES
    model = fit_personal_anomaly_model(used, feature_list)
    extra = None
    if len(feature_matrix(used, MOTOR_TASK_FEATURE_LIST)) >= MIN_MOTOR_SESSIONS_FOR_MODEL:
        extra = fit_personal_anomaly_model(used, MOTOR_TASK_FEATURE_LIST)
    return baseline, used, (model, extra)
