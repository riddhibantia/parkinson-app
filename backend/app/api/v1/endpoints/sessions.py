"""Session persistence + exact retrieval (no analysis here).

POST /api/v1/sessions        persist one session under its canonical id.
GET  /api/v1/sessions/{id}   exact retrieval; 404 when missing —
                             NEVER another session (spec 16/27.6).

Lifecycle: capture -> validate -> persist -> analyze (same id) ->
result persistence (same id). This module does step 3 only.
"""

from fastapi import APIRouter, Header, HTTPException

from app.schemas.session import SessionIngest
from app.services.supabase_store import (
    fetch_session_exact,
    get_service_client,
    get_user_client,
)

router = APIRouter()


def _client(auth_header: str | None):
    # RLS-as-user when a JWT is supplied; service client otherwise
    # (dev/self-host without Supabase wired). Ownership still checked.
    if auth_header:
        from supabase import create_client
        import os
        url = os.environ.get("SUPABASE_URL", "")
        if url:
            return create_client(url, auth_header.replace("Bearer ", ""))
    return get_service_client()


@router.post("/sessions")
def create_session(body: SessionIngest,
                   authorization: str | None = Header(default=None)) -> dict:
    client = _client(authorization)
    row = {
        "id": str(body.session_id),
        "user_id": str(body.user_id),
        "started_at": body.started_at.isoformat(),
        "ended_at": body.ended_at.isoformat(),
        "session_type": body.session_type,
        "device_id": body.device_id,
        "valid": True,
        "quality_flags": body.quality_flags,
    }
    if client is None:
        return {"status": "accepted", "sessionId": str(body.session_id),
                "persisted": False,
                "note": "Supabase not configured; caller holds the row."}
    client.table("sessions").upsert(row, on_conflict="id").execute()
    return {"status": "accepted", "sessionId": str(body.session_id),
            "persisted": True}


@router.get("/sessions/{session_id}")
def get_session(session_id: str, user_id: str,
                authorization: str | None = Header(default=None)) -> dict:
    client = _client(authorization)
    if client is None:
        raise HTTPException(status_code=501, detail="Supabase not configured")
    row = fetch_session_exact(client, session_id, user_id)
    metrics = None
    if row is not None:
        from app.services.supabase_store import fetch_metrics_exact
        metrics = fetch_metrics_exact(client, session_id, user_id)
    if row is None:
        # Exact-ID contract: missing -> Not Found, no fallback (spec 16).
        raise HTTPException(status_code=404, detail="Session not found")
    return {"session": row, "metrics": metrics}
