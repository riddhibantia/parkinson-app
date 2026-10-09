"""Personal Isolation Forest anomaly scoring (ported, validated).

Source: functions/services/layer2_anomaly.py.
One model per user, trained ONCE on frozen baseline sessions, persisted
via isolation_forest_artifact_reference, reused read-only afterwards.
Config: 100 trees, contamination 0.1, seed 42 (spec 11.3 — frozen).
"""

import numpy as np
from sklearn.ensemble import IsolationForest

from app.core.constants import (
    IF_CONTAMINATION,
    IF_N_ESTIMATORS,
    IF_RANDOM_STATE,
)

N_ESTIMATORS = IF_N_ESTIMATORS
CONTAMINATION = IF_CONTAMINATION
RANDOM_STATE = IF_RANDOM_STATE


def feature_matrix(sessions: list, feature_list: list) -> np.ndarray:
    """Dense matrix; rows with any missing feature are dropped (never imputed)."""
    rows = []
    for session in sessions:
        values = [session.get(name) for name in feature_list]
        if any(v is None for v in values):
            continue
        rows.append([float(v) for v in values])
    return np.array(rows, dtype=float)


def fit_personal_anomaly_model(baseline_sessions: list, feature_list: list):
    """Train on baseline sessions ONLY. Called at baseline-build time."""
    X = feature_matrix(baseline_sessions, feature_list)
    if len(X) == 0:
        raise ValueError("No complete baseline rows to train on")
    model = IsolationForest(
        n_estimators=N_ESTIMATORS,
        contamination=CONTAMINATION,
        random_state=RANDOM_STATE,
    )
    model.fit(X)
    return model


def score_session_anomaly(model, session: dict, feature_list: list) -> dict:
    """Score one new session against the FROZEN personal model (read-only)."""
    values = [session.get(name) for name in feature_list]
    if any(v is None for v in values):
        return {"anomaly_score": None, "is_anomaly": False,
                "reason": "incomplete_features"}
    x = np.array([[float(v) for v in values]])
    return {"anomaly_score": float(model.decision_function(x)[0]),
            "is_anomaly": bool(model.predict(x)[0] == -1)}
