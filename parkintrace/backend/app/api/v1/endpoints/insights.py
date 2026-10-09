"""Read-only insight views over persisted rows (spec 24/25).

GET /api/v1/insights/layer1                  latest Layer 1 insight.
GET /api/v1/insights/layer2                  longitudinal Layer 2 view.
GET /api/v1/sessions/{id}/insight            exact-session insight (404,
  never another session).

All chart series come from real persisted rows. Insufficient data is
reported honestly (spec 26) — no synthetic points, no fake history.
"""

from fastapi import APIRouter, HTTPException

from app.services.supabase_store import (
    fetch_metrics_exact,
    fetch_session_exact,
    get_service_client,
    history_for_user,
)

router = APIRouter()


@router.get("/insights/layer1")
def insight_layer1(user_id: str) -> dict:
    client = get_service_client()
    if client is None:
        raise HTTPException(status_code=501, detail="Supabase not configured")
    res = (client.table("session_metrics").select("*").eq("user_id", user_id)
           .order("created_at", desc=True).limit(1).execute())
    rows = res.data or []
    if not rows or not rows[0].get("layer1_result"):
        return {"status": "insufficient_data",
                "message": "Complete a typing session to see your comparison."}
    return {"status": "ok", "insight": rows[0]}


@router.get("/insights/layer2")
def insight_layer2(user_id: str) -> dict:
    client = get_service_client()
    if client is None:
        raise HTTPException(status_code=501, detail="Supabase not configured")
    sessions = history_for_user(client, user_id)
    metrics = (client.table("session_metrics").select("*")
               .eq("user_id", user_id).order("created_at").execute()).data or []
    if len(metrics) < 1:
        return {"status": "insufficient_data",
                "message": "Save a typing session to begin monitoring."}
    trend = [{"session_id": m["session_id"],
              "features": m.get("features", {}),
              "layer2": m.get("layer2_result"),
              "created_at": m.get("created_at")} for m in metrics]
    if len(metrics) < 2:
        return {"status": "ok", "trend": trend,
                "note": "Not enough sessions for a longitudinal trend."}
    return {"status": "ok", "trend": trend,
            "sessions": len(sessions)}


@router.get("/sessions/{session_id}/insight")
def session_insight(session_id: str, user_id: str) -> dict:
    client = get_service_client()
    if client is None:
        raise HTTPException(status_code=501, detail="Supabase not configured")
    row = fetch_session_exact(client, session_id, user_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Session not found")
    metrics = fetch_metrics_exact(client, session_id, user_id)
    return {"session": row, "metrics": metrics}
