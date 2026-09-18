"""Layer 1 reference screening at inference time (Stage 4.6 wiring).

Loads the FROZEN Random Forest artifact (the locked primary baseline)
once at cold start and scores each new typing session's feature row.
No training, no refitting, no threshold tuning here: the 0.4/0.7 bands
are experimental placeholders (plan Stage 4.6), and the raw probability
is stored for later threshold work — never shown as a percentage in UI
(Stage 9.4 enforced client-side).
"""

import json
import os

import joblib
import numpy as np

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTIFACT = os.path.join(BASE, "models", "experiments", "rf",
                        "model_full.joblib")
LIVE_SCALER = os.path.join(BASE, "models", "experiments", "rf",
                           "live_scaler.json")

# Experimental placeholders, not medical cutoffs (Stage 4.6).
WATCH_THRESHOLD = 0.4
ATTENTION_THRESHOLD = 0.7

_bundle = None


def _load():
    global _bundle
    if _bundle is None:
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
    """Score one session's typing features. Returns status + message +
    stored probability. `top_contributors` is filled later by the async
    SHAP step (Stage 4.5); it stays None here by design."""
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
