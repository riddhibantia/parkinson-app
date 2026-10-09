"""GET /api/v1/health — artifact verification + dependency status.

Fail-closed: reports RF artifact presence/loadability without ever
fabricating a prediction (spec 9.2).
"""

from fastapi import APIRouter

from app.services.layer1_screening import artifact_status

router = APIRouter()


@router.get("/health")
def health() -> dict:
    layer1 = artifact_status()
    ok = bool(layer1.get("loaded"))
    return {
        "status": "ok" if ok else "degraded",
        "layer1": layer1,
        "layer2": {"methods": ["baseline", "cusum", "ewma", "isolation_forest"],
                   "ready": True},
        "note": ("degraded means live Layer 1 inference is disabled until "
                 "the authoritative RF artifact is provided; nothing is "
                 "substituted or fabricated."),
    }
