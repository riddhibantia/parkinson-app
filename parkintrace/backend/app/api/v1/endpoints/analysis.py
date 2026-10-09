"""Analysis endpoints — strict Layer separation (spec 20.2).

POST /api/v1/analysis/layer1  Layer 1 ONLY (population screening).
POST /api/v1/analysis/layer2  Layer 2 ONLY (personal monitoring).
POST /api/v1/analysis/session  convenience orchestration: calls both
  independent services and returns two separate result objects.
  No combined score is ever produced (spec 3.3).
"""

from fastapi import APIRouter, HTTPException
from pydantic import Field

from app.schemas.session import CamelModel, SessionIngest
from app.services import pipeline as pipe

router = APIRouter()


class AnalysisRequest(SessionIngest):
    """Flat session contract + optional longitudinal context.

    baseline/recent are plain JSON (baseline statistics + recent feature
    dicts); Supabase reads that supply them live in the route handler,
    never in the pipeline.
    """

    baseline: dict | None = None
    recent: list[dict] = Field(default_factory=list)


def _camel(name: str) -> str:
    parts = name.split("_")
    return parts[0] + "".join(p.title() for p in parts[1:])


def _out(result: dict) -> dict:
    """Envelope keys to camelCase (spec 15). Canonical feature NAMES
    (ht_mean, ...) stay snake_case inside features/drift payloads."""
    out = {}
    for key, value in result.items():
        if isinstance(value, dict) and key in ("layer1", "layer2"):
            value = {_camel(k): v for k, v in value.items()}
        out[_camel(key)] = value
    return out


def _session_dict(body: SessionIngest) -> dict:    return {
        "session_id": str(body.session_id),
        "session_type": body.session_type,
        "device_id": body.device_id,
        "duration_sec": body.duration_ms / 1000.0,
        "keystroke_count": body.keystroke_count,
        "quality_flags": body.quality_flags,
        "events": [e.model_dump(by_alias=True) for e in body.events],
        "taps": [t.model_dump(by_alias=True) for t in body.taps],
        "features": dict(body.features),
        "started_at": body.started_at,
    }


@router.post("/analysis/layer1")
def analyze_layer1(body: SessionIngest) -> dict:
    session = _session_dict(body)
    features = pipe.resolve_features(session)
    try:
        result = pipe.layer1_for_session(session, features)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    camel = {_camel(k): v for k, v in result.items()}
    return {"sessionId": str(body.session_id), "layer1": camel,
            "features": features}


@router.post("/analysis/layer2")
def analyze_layer2(body: AnalysisRequest) -> dict:
    session = _session_dict(body)
    recent = body.recent or []
    result = pipe.analyze_session(
        session, baseline=body.baseline,
        baseline_sessions=recent, recent_features=recent,
        anomaly_model=None, sessions_since_baseline=len(recent))
    layer2 = _out(result.get("layer2", result))
    return {"sessionId": str(body.session_id), "layer2": layer2,
            "features": result.get("features")}


@router.post("/analysis/session")
def analyze_session(body: AnalysisRequest) -> dict:
    session = _session_dict(body)
    recent = body.recent or []
    try:
        result = pipe.analyze_session(
            session, baseline=body.baseline,
            baseline_sessions=recent, recent_features=recent,
            anomaly_model=None, sessions_since_baseline=len(recent))
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    result = _out(result)
    result["sessionId"] = str(body.session_id)
    return result
