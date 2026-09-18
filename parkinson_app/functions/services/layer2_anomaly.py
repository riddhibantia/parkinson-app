"""Personal Isolation Forest anomaly scoring (Stage 5.3).

One model per user, trained ONCE on that user's own frozen baseline
sessions — a multivariate "does this look like me" check complementing
the per-feature CUSUM/EWMA trends. Scoring never retrains: `fit` appears
only in `fit_personal_anomaly_model`, called from the baseline-build path
(and explicit rebuilds), never from monitoring.
"""

import numpy as np
from sklearn.ensemble import IsolationForest

N_ESTIMATORS = 100
CONTAMINATION = 0.1
RANDOM_STATE = 42


def feature_matrix(sessions: list, feature_list: list) -> np.ndarray:
    """Dense matrix; rows with any missing feature are dropped (never
    imputed — demographics/symptoms never reach this vector by
    construction, see Stage 5.7)."""
    rows = []
    for session in sessions:
        values = [session.get(name) for name in feature_list]
        if any(v is None for v in values):
            continue
        rows.append([float(v) for v in values])
    return np.array(rows, dtype=float)


def fit_personal_anomaly_model(baseline_sessions: list,
                               feature_list: list):
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


def score_session_anomaly(model, session: dict,
                          feature_list: list) -> dict:
    """Score one new session against the FROZEN personal model. Read-only:
    never calls .fit() and never mutates the model."""
    values = [session.get(name) for name in feature_list]
    if any(v is None for v in values):
        return {"anomaly_score": None, "is_anomaly": False,
                "reason": "incomplete_features"}
    x = np.array([[float(v) for v in values]])
    return {"anomaly_score": float(model.decision_function(x)[0]),
            "is_anomaly": bool(model.predict(x)[0] == -1)}
