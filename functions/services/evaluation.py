"""Evaluation scaffolding (Stage 4.3 / 10.5). No model fitting here.

Contracts enforced for the later training code:
- Splits are ALWAYS by subject (StratifiedGroupKFold on subject_id).
  Session-level splitting learns individuals, not PD — the pipeline's
  highest-risk failure mode, asserted by unit test.
- Normalization stats are fit INSIDE each fold on training subjects only,
  per dataset_source; test folds are transformed, never fit.
- Leave-one-dataset-out normalizes the held-out dataset with the
  TRAINING dataset's statistics.
"""

import numpy as np
from sklearn.metrics import (average_precision_score, confusion_matrix,
                             f1_score, roc_auc_score)
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.preprocessing import StandardScaler


def assert_no_subject_leakage(train_idx, test_idx, groups) -> None:
    """Raise if any subject spans train and test. Called by every
    training loop before fitting (plan Stage 10.5)."""
    groups = np.asarray(groups)
    leaked = set(groups[np.asarray(train_idx)]) & set(groups[np.asarray(
        test_idx)])
    if leaked:
        raise AssertionError(
            f"Subject leakage across split: {sorted(leaked)[:5]} "
            f"({len(leaked)} subjects). Split by subject, never by session.")


def subject_grouped_folds(y, groups, n_splits=5,
                          seed=42) -> list:
    """StratifiedGroupKFold split indices. One subject never spans sides."""
    cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True,
                              random_state=seed)
    y = np.asarray(y)
    groups = np.asarray(groups)
    folds = []
    for train_idx, test_idx in cv.split(np.zeros(len(y)), y, groups):
        assert_no_subject_leakage(train_idx, test_idx, groups)
        folds.append((np.asarray(train_idx), np.asarray(test_idx)))
    return folds


def leave_one_dataset_out_splits(sources) -> list:
    """One (train, test) split per held-out dataset_source value."""
    sources = np.asarray(sources)
    splits = []
    for held_out in sorted(set(sources.tolist())):
        test_idx = np.where(sources == held_out)[0]
        train_idx = np.where(sources != held_out)[0]
        splits.append((held_out, train_idx, test_idx))
    return splits


def fit_per_dataset_scalers(X_train, train_sources,
                            feature_names) -> dict:
    """Fit one StandardScaler per dataset_source on TRAINING rows only."""
    X_train = np.asarray(X_train, dtype=float)
    train_sources = np.asarray(train_sources)
    scalers = {}
    for source in sorted(set(train_sources.tolist())):
        mask = train_sources == source
        scalers[source] = StandardScaler().fit(X_train[mask])
    scalers["_features"] = list(feature_names)
    return scalers


def transform_with_scalers(X, sources, scalers) -> np.ndarray:
    """Transform rows with their source's TRAINING-fit scaler."""
    X = np.asarray(X, dtype=float)
    sources = np.asarray(sources)
    out = np.empty_like(X)
    for source in sorted(set(sources.tolist())):
        if source not in scalers:
            raise KeyError(f"No training-fit scaler for source {source!r}")
        mask = sources == source
        out[mask] = scalers[source].transform(X[mask])
    return out


def transform_with_train_scaler(X_test, scalers) -> np.ndarray:
    """Leave-one-dataset-out transform: the held-out dataset is normalized
    with the TRAINING dataset's statistics — never its own (Stage 4.1)."""
    train_keys = [k for k in scalers if not k.startswith("_")]
    if len(train_keys) != 1:
        raise ValueError("Expected exactly one training-source scaler, "
                         f"got {train_keys}")
    return scalers[train_keys[0]].transform(np.asarray(X_test, dtype=float))


def summarize_metrics(y_true, y_score, threshold=0.5) -> dict:
    """Screening metrics. Accuracy is reported last on purpose: for a
    screening tool, false-negative/false-positive costs differ."""
    y_true = np.asarray(y_true, dtype=int)
    y_score = np.asarray(y_score, dtype=float)
    y_pred = (y_score >= threshold).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    return {
        "roc_auc": float(roc_auc_score(y_true, y_score)),
        "avg_precision": float(average_precision_score(y_true, y_score)),
        "f1": float(f1_score(y_true, y_pred, zero_division=0)),
        "confusion": {"tn": int(tn), "fp": int(fp),
                      "fn": int(fn), "tp": int(tp)},
        "n_pos": int(y_true.sum()),
        "n_neg": int(len(y_true) - y_true.sum()),
    }
