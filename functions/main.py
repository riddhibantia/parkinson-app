"""Cloud Functions entry point (Stage 6.1 / 6.3). Thin handlers only.

Pipeline rule: `submit_session` only validates and persists data.
`run_analysis` (Firestore trigger) is the single live analysis path via
services/pipeline.py, so a session can never be analysed twice and the
async SHAP flow stays explicit. SHAP explanation itself (Stage 4.5)
runs as a follow-up trigger on newly created pending results — it
attaches top contributors when available and marks unavailable
otherwise, never as a health claim.

Deploy (Stage 11.1): firebase deploy --only functions
Requires Blaze to deploy functions, enablement handled outside code.
"""

from firebase_admin import firestore, initialize_app
from firebase_functions import firestore_fn, https_fn

from services.anomaly_store import (
    delete_user_anomaly_model,
    load_user_anomaly_model,
    save_user_anomaly_model,
)
from services.pipeline import (
    dashboard_data,
    handle_new_session,
    reset_user_baseline,
)
from services.pipeline import resolve_features as _resolve_features
from services.quality_filter import validate_session

initialize_app()


class _CloudModelStore:
    """Production artifact store: Cloud Storage via anomaly_store."""

    @staticmethod
    def save(user_id, model, kind="typing"):
        save_user_anomaly_model(user_id, model, kind)

    @staticmethod
    def load(user_id, kind="typing"):
        return load_user_anomaly_model(user_id, kind)

    @staticmethod
    def delete(user_id):
        delete_user_anomaly_model(user_id)


@https_fn.on_call()
def submit_session(req: https_fn.CallableRequest):
    """Validate and persist one session; analysis runs via trigger."""
    if not req.auth:
        raise https_fn.HttpsError(
            code="unauthenticated", message="Sign-in required")

    user_id = req.auth.uid
    session_data = req.data

    accepted, reason = validate_session(
        int(session_data.get("keystroke_count", 0)),
        float(session_data.get("duration_sec", 0)),
    )
    if not accepted and session_data.get("mode") != "motor_task":
        return {"status": "rejected", "reason": reason}

    session_phase = session_data.get("session_phase", "screening")
    if session_phase not in {"familiarization", "screening"}:
        raise https_fn.HttpsError(
            code="invalid-argument", message="Invalid session phase")

    db = firestore.client()
    profile = db.collection("users").document(user_id).get().to_dict() or {}
    if session_phase == "screening" and not profile.get(
            "screening_ready", False):
        return {
            "status": "blocked",
            "reason": "familiarization_required",
            "message": "Complete the required familiarization session(s) first.",
        }

    session_ref = (
        db.collection("users").document(user_id)
        .collection("sessions").document()
    )
    session_ref.set({
        **_resolve_features(session_data),
        "device_id": session_data["device_id"],
        "mode": session_data["mode"],
        "session_phase": session_phase,
        "quality_flags": session_data.get("quality_flags", []),
        "keystroke_count": session_data.get("keystroke_count", 0),
        "timestamp": firestore.SERVER_TIMESTAMP,
    })
    return {"status": "accepted", "session_id": session_ref.id}


@firestore_fn.on_document_created(
    document="users/{userId}/sessions/{sessionId}")
def run_analysis(event: firestore_fn.CloudEvent) -> None:
    """Route a persisted session through the shared pipeline."""
    handle_new_session(
        firestore.client(),
        event.params["userId"],
        event.params["sessionId"],
        event.data.to_dict(),
        _CloudModelStore(),
    )


@https_fn.on_call()
def reset_baseline(req: https_fn.CallableRequest):
    """Archive the frozen baseline and delete its anomaly artifact so a
    fresh collection period can start (Stage 5.4). Explicit action only."""
    if not req.auth:
        raise https_fn.HttpsError(
            code="unauthenticated", message="Sign-in required")
    return reset_user_baseline(
        firestore.client(), req.auth.uid, _CloudModelStore())


@firestore_fn.on_document_created(
    document="users/{userId}/results/{resultId}")
def fill_shap_explanation(event: firestore_fn.CloudEvent) -> None:
    """Async SHAP follow-up (Stage 4.5): if a new result is pending,
    explain the associated session's typing features and attach the
    top contributors. Failures degrade to shap_status=unavailable —
    never a health result, never a retry storm."""
    data = event.data.to_dict() or {}
    if data.get("shap_status") != "pending":
        return
    layer1 = data.get("layer1") or {}
    if layer1.get("pd_probability") is None:
        return
    user_id = event.params["userId"]
    result_id = event.params["resultId"]
    session_id = data.get("session_id")
    if not session_id:
        return
    db = firestore.client()
    try:
        session_doc = (
            db.collection("users").document(user_id)
            .collection("sessions").document(session_id).get()
        )
        session_data = session_doc.to_dict() or {}
        # Build feature dict from stored session fields (flattened by
        # pipeline._resolve_features) or from raw events fallback.
        from services.explain import explain_session
        # Prefer stored typed features; if session only has raw events,
        # explain will raise KeyError -> treated as unavailable.
        feature_dict = {
            k: session_data.get(k) for k in
            ["ht_mean","ht_std","ft_mean","ft_std","ikl_mean","ikl_std",
             "left_ht_mean","right_ht_mean","hand_asymmetry",
             "pause_frequency","typing_speed","session_consistency",
             "backspace_rate"]
            if session_data.get(k) is not None
        }
        contributors = explain_session(feature_dict)
        db.collection("users").document(user_id).collection("results").document(
            result_id).set(
                {"layer1": {**layer1, "top_contributors": contributors},
                 "shap_status": "completed"},
                merge=True,
            )
    except Exception:
        # Missing artifact, missing shap dep, incomplete features, etc.
        # Mark unavailable so the UI can show "explanation unavailable"
        # without implying anything about health.
        try:
            db.collection("users").document(user_id).collection("results").document(
                result_id).set({"shap_status": "unavailable"}, merge=True)
        except Exception:
            pass


@https_fn.on_call()
def get_dashboard(req: https_fn.CallableRequest):
    """Aggregate latest results, readiness, and baseline progress."""
    if not req.auth:
        raise https_fn.HttpsError(
            code="unauthenticated", message="Sign-in required")
    return dashboard_data(firestore.client(), req.auth.uid)
