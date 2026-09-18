"""Cloud Functions entry point (Stage 6.1 / 6.3). Thin handlers only.

Pipeline rule: `submit_session` only validates and persists data.
`run_analysis` (Firestore trigger) is the single live analysis path via
services/pipeline.py, so a session can never be analysed twice and the
async SHAP flow stays explicit. SHAP explanation itself (Stage 4.5)
remains pending by design — results carry shap_status for it.

Deploy (Stage 11.1): firebase deploy --only functions
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


@https_fn.on_call()
def get_dashboard(req: https_fn.CallableRequest):
    """Aggregate latest results, readiness, and baseline progress."""
    if not req.auth:
        raise https_fn.HttpsError(
            code="unauthenticated", message="Sign-in required")
    return dashboard_data(firestore.client(), req.auth.uid)
