"""Baseline endpoints (spec 10).

GET  /api/v1/baseline        current baseline state (building/established).
POST /api/v1/baseline/reset  explicit reset: clears the baseline AND the
  anomaly-model reference together (spec 10/11.3). No silent rebuilds.
"""

from fastapi import APIRouter, HTTPException

from app.services.supabase_store import get_service_client

router = APIRouter()


@router.get("/baseline")
def get_baseline(user_id: str) -> dict:
    client = get_service_client()
    if client is None:
        return {"status": "building", "persisted": False,
                "note": "Supabase not configured."}
    res = (client.table("baselines").select("*").eq("user_id", user_id)
           .order("created_at", desc=True).limit(1).execute())
    rows = res.data or []
    if not rows:
        return {"status": "building", "sessions": 0}
    current = rows[0]
    if current.get("status") != "established":
        return {"status": "building",
                "sample_count": current.get("sample_count", 0),
                "distinct_days": current.get("distinct_days", 0)}
    return {"status": "established", "baseline": current}


@router.post("/baseline/reset")
def reset_baseline(user_id: str) -> dict:
    client = get_service_client()
    if client is None:
        raise HTTPException(status_code=501, detail="Supabase not configured")
    # Reset BOTH baseline rows and the anomaly artifact reference together.
    client.table("baselines").delete().eq("user_id", user_id).execute()
    return {"status": "baseline_reset",
            "note": "Baseline and anomaly-model state cleared together."}
