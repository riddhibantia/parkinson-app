"""Analysis orchestration (Stage 6.3). Cloud-agnostic: every function
takes a `db` handle with the Firestore collection/document/stream shape,
so the full user journey is testable against an in-memory fake.

The per-user Isolation Forest artifact travels through an injected
`store` (save/load/delete) — Cloud Storage in production, a dict in
tests. Baselines and the Layer 1 artifact are never refit here.
"""

from services.baseline_builder import (
    LAYER2_TYPING_FEATURES,
    build_baseline,
)
from services.device_guard import check_device_consistency
from services.familiarization import (
    familiarization_ready,
    required_practice_sessions,
)
from services.feature_extraction import (
    extract_features,
    extract_motor_task_features,
)
from services.layer1_screening import screen_against_reference
from services.layer2_anomaly import (
    feature_matrix,
    fit_personal_anomaly_model,
)
from services.layer2_drift import (
    dual_result,
    score_monitoring_session,
)
from services.quality_filter import validate_session
from utils.constants import (
    LAYER2_CONFIDENCE_WINDOW,
    MINIMUM_SESSIONS_FOR_BASELINE,
    MOTOR_TASK_FEATURE_LIST,
    TYPING_FEATURE_LIST,
)

# Motor-task sessions need their own model (different vector space); it is
# fit only once enough complete motor sessions exist. Until then motor
# monitoring is CUSUM-only with a pending anomaly note.
MIN_MOTOR_SESSIONS_FOR_MODEL = 10


def layer2_feature_list(session_data: dict) -> list:
    """Typing sessions score on typing features, motor-task sessions on
    motor features (Stage 5.1b). Never mixed, never demographic."""
    if session_data.get("mode") == "motor_task":
        return MOTOR_TASK_FEATURE_LIST
    return LAYER2_TYPING_FEATURES


def resolve_features(session_data: dict) -> dict:
    """One code path for both document shapes: raw wire events/taps
    (direct-write path) or already-extracted feature fields
    (submit_session path) — both flow through the same extractors."""
    if session_data.get("mode") == "motor_task":
        if "taps" in session_data:
            return extract_motor_task_features(
                session_data.get("taps", []))
        return {k: session_data.get(k) for k in MOTOR_TASK_FEATURE_LIST}
    if "events" in session_data:
        duration = float(session_data.get("duration_sec", 0))
        return extract_features(session_data.get("events", []), duration)
    return {k: session_data.get(k) for k in TYPING_FEATURE_LIST}


def layer1_for_session(session_data: dict, features: dict) -> dict:
    """Population comparison. Motor-task sessions have no reference
    training matrix (Stage 2.3) and are never scored by Layer 1."""
    if session_data.get("mode") == "motor_task":
        return {
            "status": "not_applicable",
            "message": ("The tapping task is tracked in your personal "
                        "trend only; it has no population comparison."),
            "pd_probability": None,
            "top_contributors": None,
        }
    return screen_against_reference(features)


def update_familiarization_readiness(db, user_id: str) -> dict:
    """Evaluate practice sessions only; set screening_ready accordingly."""
    profile_ref = db.collection("users").document(user_id)
    profile = profile_ref.get().to_dict() or {}
    level = profile.get("typing_experience_level", "regular")

    sessions = [
        doc.to_dict()
        for doc in profile_ref.collection("sessions").stream()
        if doc.to_dict().get("session_phase") == "familiarization"
    ]
    sessions.sort(key=lambda s: s.get("timestamp"))
    if not sessions:
        return {"screening_ready": False, "reason": "no_practice"}

    required = required_practice_sessions(level)
    if len(sessions) < required:
        return {"screening_ready": False, "reason": "practice_required"}

    if required == 1:
        ready = not sessions[-1].get("quality_flags")
    else:
        ready = familiarization_ready(
            resolve_features(sessions[-2]), resolve_features(sessions[-1]))

    profile_ref.set(
        {"screening_ready": bool(ready),
         "familiarization_sessions": len(sessions)},
        merge=True,
    )
    return {"screening_ready": bool(ready),
            "reason": "ready" if ready else "unstable"}


def recent_screening_sessions(db, user_id: str, n: int) -> list:
    docs = db.collection("users").document(user_id).collection(
        "sessions").order_by("timestamp").stream()
    sessions = [d.to_dict() for d in docs
                if d.to_dict().get("session_phase") == "screening"]
    return sessions[-n:]


def count_sessions_after(db, user_id: str, built_date) -> int:
    docs = db.collection("users").document(user_id).collection(
        "sessions").stream()
    return sum(1 for d in docs
               if d.to_dict().get("session_phase") == "screening"
               and d.to_dict().get("timestamp") is not None
               and built_date is not None
               and d.to_dict().get("timestamp") > built_date)


def store_result(db, user_id: str, session_id: str, result: dict,
                 shap: str, timestamp=None) -> None:
    db.collection("users").document(user_id).collection(
        "results").document().set({
            **result,
            "session_id": session_id,
            "timestamp": timestamp,
            "shap_status": shap,
        })


def handle_new_session(db, user_id: str, session_id: str,
                       session_data: dict, store) -> dict:
    """Single live analysis path for one persisted session (Stage 6.3).

    Practice updates readiness only. Screening sessions pass a quality
    gate (direct-write hardening; submit_session pre-validates), then
    route to collecting / baseline-build / Layer 1+2 monitoring.
    Returns the stored result (minus transport timestamp).
    """
    if session_data.get("session_phase") == "familiarization":
        readiness = update_familiarization_readiness(db, user_id)
        result = {"status": "practice_recorded", **readiness}
        store_result(db, user_id, session_id, result, "not_applicable",
                     session_data.get("timestamp"))
        return result

    accepted, reason = validate_session(
        int(session_data.get("keystroke_count", 0)),
        float(session_data.get("duration_sec", 0)),
    )
    if not accepted and session_data.get("mode") != "motor_task":
        result = {"status": "rejected", "reason": reason}
        store_result(db, user_id, session_id, result, "not_applicable",
                     session_data.get("timestamp"))
        return result

    baseline_doc = (
        db.collection("users").document(user_id)
        .collection("baselines").document("current").get()
    )
    if baseline_doc.exists:
        baseline = baseline_doc.to_dict()
        device_check = check_device_consistency(session_data, baseline)
        if not device_check["proceed"]:
            result = {"layer2": {
                "status": "device_mismatch",
                "message": device_check["message"]}}
            store_result(db, user_id, session_id, result, "not_applicable",
                         session_data.get("timestamp"))
            return result
        feature_list = layer2_feature_list(session_data)
        # The just-persisted session is the latest entry (trigger
        # semantics) — recent INCLUDES the current session, never appended.
        recent = recent_screening_sessions(db, user_id, n=10)
        recent_features = [resolve_features(s) for s in recent]
        current = recent_features[-1]
        kind = ("motor" if session_data.get("mode") == "motor_task"
                else "typing")
        anomaly_model = store.load(user_id, kind)
        layer2_result = score_monitoring_session(
            baseline, anomaly_model, current, recent_features,
            feature_list)
        sessions_since = count_sessions_after(
            db, user_id, baseline.get("built_date"))
        layer1_result = layer1_for_session(session_data, current)
        result = dual_result(layer1_result, layer2_result, sessions_since,
                             LAYER2_CONFIDENCE_WINDOW)
        store_result(db, user_id, session_id, result,
                     "pending" if layer1_result.get("pd_probability")
                     is not None else "not_applicable",
                     session_data.get("timestamp"))
        return result

    all_sessions = [
        doc.to_dict()
        for doc in db.collection("users").document(user_id)
        .collection("sessions").stream()
        if doc.to_dict().get("session_phase") == "screening"
    ]
    if len(all_sessions) >= MINIMUM_SESSIONS_FOR_BASELINE:
        baseline, baseline_sessions = build_baseline(all_sessions)
        if baseline is None:
            result = {
                "status": "collecting",
                "message": ("Keep typing on the same keyboard across "
                            "multiple days while we build your baseline."),
            }
            store_result(db, user_id, session_id, result, "not_applicable",
                         session_data.get("timestamp"))
            return result
        # Fit ONCE on the exact baseline sessions, then freeze. This
        # branch is reachable again only after an explicit reset.
        anomaly_model = fit_personal_anomaly_model(
            baseline_sessions, LAYER2_TYPING_FEATURES)
        db.collection("users").document(user_id).collection(
            "baselines").document("current").set(baseline)
        store.save(user_id, anomaly_model, "typing")
        if len(feature_matrix(baseline_sessions,
                              MOTOR_TASK_FEATURE_LIST)) >= \
                MIN_MOTOR_SESSIONS_FOR_MODEL:
            store.save(user_id, fit_personal_anomaly_model(
                baseline_sessions, MOTOR_TASK_FEATURE_LIST), "motor")
        result = {
            "status": "baseline_built",
            "message": ("Your personal baseline is ready. Layer 2 "
                        "monitoring is now active and gaining confidence."),
        }
        store_result(db, user_id, session_id, result, "not_applicable",
                     session_data.get("timestamp"))
        return result

    current = resolve_features(session_data)
    layer1_result = layer1_for_session(session_data, current)
    result = {
        "status": "collecting",
        "layer1": layer1_result,
        "baseline_progress": (
            f"{len(all_sessions)}/{MINIMUM_SESSIONS_FOR_BASELINE}+ sessions"
        ),
    }
    store_result(db, user_id, session_id, result,
                 "pending" if layer1_result.get("pd_probability")
                 is not None else "not_applicable",
                 session_data.get("timestamp"))
    return result


def reset_user_baseline(db, user_id: str, store) -> dict:
    """Archive the frozen baseline and delete its artifact so a fresh
    collection period can start (Stage 5.4). Explicit action only."""
    current = db.collection("users").document(user_id).collection(
        "baselines").document("current").get()
    if current.exists:
        db.collection("users").document(user_id).collection(
            "baselines").document("archived").set(current.to_dict())
        db.collection("users").document(user_id).collection(
            "baselines").document("current").delete()
    store.delete(user_id)
    return {"status": "baseline_reset"}


def dashboard_data(db, user_id: str) -> dict:
    """Latest result, readiness, and baseline progress for get_dashboard."""
    results = (
        db.collection("users").document(user_id).collection("results")
        .order_by("timestamp", descending=True).limit(1).stream()
    )
    latest = [doc.to_dict() for doc in results]
    profile = db.collection("users").document(user_id).get().to_dict() or {}
    baseline = db.collection("users").document(user_id).collection(
        "baselines").document("current").get()
    screenings = [
        doc.to_dict()
        for doc in db.collection("users").document(user_id)
        .collection("sessions").stream()
        if doc.to_dict().get("session_phase") == "screening"
    ]
    return {
        "latest_result": latest[0] if latest else None,
        "screening_ready": profile.get("screening_ready", False),
        "baseline_ready": baseline.exists,
        "baseline_progress": (
            f"{len(screenings)}/{MINIMUM_SESSIONS_FOR_BASELINE}+ sessions"
        ),
    }
