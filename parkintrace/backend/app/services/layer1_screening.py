"""Layer 1 reference screening (ported, validated — inference only).

Source: functions/services/layer1_screening.py.
Frozen Random Forest primary; no training/refit/threshold tuning here.
Bands 0.4/0.7 are experimental placeholders, not medical cutoffs.
Raw probability is stored as an internal research signal — the UI must
never present it as a diagnosis or clinical probability (spec 1.2/9.3).

Artifact resolution (spec 9.2, fail-closed):
  PARKINTRACE_RF_ARTIFACT -> explicit path, else legacy repo path
  functions/models/experiments/rf/model_full.joblib for local dev.
Missing artifact: raise FileNotFoundError with a clear message.
NEVER retrain silently, substitute TabPFN, hard-code, or fabricate.
"""

import json
import os

import joblib
import numpy as np

from app.core.constants import (
    LAYER1_ATTENTION_THRESHOLD as ATTENTION_THRESHOLD,
    LAYER1_WATCH_THRESHOLD as WATCH_THRESHOLD,
    RF_LAYER1_FEATURES,
)

_SERVICES_DIR = os.path.dirname(os.path.abspath(__file__))
# services -> app -> backend -> parkintrace -> repo root
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(_SERVICES_DIR))))
LEGACY_ARTIFACT = os.path.join(
    _REPO_ROOT, "functions", "models", "experiments", "rf", "model_full.joblib")
LEGACY_SCALER = os.path.join(
    _REPO_ROOT, "functions", "models", "experiments", "rf", "live_scaler.json")

ARTIFACT = os.environ.get("PARKINTRACE_RF_ARTIFACT", LEGACY_ARTIFACT)
LIVE_SCALER = os.environ.get("PARKINTRACE_RF_SCALER", LEGACY_SCALER)

_bundle = None


def artifact_status() -> dict:
    """Fail-closed verification hook for /health (spec 9.2)."""
    info = {"artifact": ARTIFACT, "scaler": LIVE_SCALER,
            "exists": os.path.exists(ARTIFACT) and os.path.exists(LIVE_SCALER),
            "features": list(RF_LAYER1_FEATURES)}
    if info["exists"]:
        try:
            bundle = _load()
            info["loaded"] = True
            info["model"] = type(bundle["model"]).__name__
            info["artifact_features"] = list(bundle["features"])
            info["match"] = list(bundle["features"]) == list(RF_LAYER1_FEATURES)
        except Exception as exc:  # noqa: BLE001
            info["loaded"] = False
            info["error"] = str(exc)
    else:
        info["loaded"] = False
        info["error"] = ("Random Forest artifact not found. Set "
                         "PARKINTRACE_RF_ARTIFACT to the authoritative "
                         "model_full.joblib; live inference stays disabled.")
    return info


def _load():
    global _bundle
    if _bundle is None:
        if not os.path.exists(ARTIFACT):
            raise FileNotFoundError(
                f"Layer 1 RF artifact missing: {ARTIFACT}. Refusing to "
                "substitute another model or fabricate output (spec 9.2).")
        if not os.path.exists(LIVE_SCALER):
            raise FileNotFoundError(f"Layer 1 scaler missing: {LIVE_SCALER}.")
        artifact = joblib.load(ARTIFACT)
        with open(LIVE_SCALER) as fh:
            scaler = json.load(fh)
        _bundle = {
            "model": artifact["model"],
            "features": artifact["features"],
            "mean": np.array(scaler["mean_"], dtype=float),
            "scale": np.array(scaler["scale_"], dtype=float),
        }
    return _bundle


def screen_against_reference(session_features: dict) -> dict:
    """Score one session's typing features (motor-task never reaches here)."""
    bundle = _load()
    try:
        row = np.array([[float(session_features[name])
                         for name in bundle["features"]]], dtype=float)
    except (KeyError, TypeError, ValueError):
        return {
            "status": "insufficient_data",
            "message": ("This session did not produce a complete typing "
                        "pattern. Keep typing regularly."),
            "pd_probability": None,
            "top_contributors": None,
        }
    if not np.all(np.isfinite(row)):
        return {
            "status": "insufficient_data",
            "message": ("This session did not produce a complete typing "
                        "pattern. Keep typing regularly."),
            "pd_probability": None,
            "top_contributors": None,
        }
    z = (row - bundle["mean"]) / bundle["scale"]
    probability = float(bundle["model"].predict_proba(z)[0][1])

    if probability >= ATTENTION_THRESHOLD:
        status = "attention"
        message = ("Your typing shows patterns that can be associated with "
                   "motor changes. This is not a diagnosis. We recommend "
                   "consulting a doctor for a check-up.")
    elif probability >= WATCH_THRESHOLD:
        status = "watch"
        message = ("Some of your typing patterns are slightly outside the "
                   "typical range. Keep typing regularly so we can build "
                   "a better picture over time.")
    else:
        status = "normal"
        message = ("Your typing patterns are within the typical range. "
                   "Keep typing regularly for ongoing monitoring.")
    return {"status": status, "message": message,
            "pd_probability": probability, "top_contributors": None}
