"""Experiment A — Random Forest baseline (Stage 4.4).

Same folds + fold-internal per-dataset preprocessing as the later TabPFN
runs. Views: pooled CV, per-dataset CV, leave-one-dataset-out both ways.
No thresholding here — probabilities are saved for later threshold work.

Run: python models/run_rf.py
"""

import json
import os
import sys
import time

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

sys.path.insert(0, os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))

from models.exp_common import (  # noqa: E402
    EXPERIMENTS_DIR,
    REPORTS_DIR,
    TRAIN_FEATURES,
    cached_folds,
    load_training_frame,
    package_versions,
    view_mask,
)
from services.evaluation import (  # noqa: E402
    assert_no_subject_leakage,
    fit_per_dataset_scalers,
    leave_one_dataset_out_splits,
    summarize_metrics,
    transform_with_scalers,
    transform_with_train_scaler,
)

RF_PARAMS = {
    "n_estimators": 200,
    "max_depth": 8,
    "class_weight": "balanced",
    "random_state": 42,
}
OUT_DIR = os.path.join(EXPERIMENTS_DIR, "rf")


def run_cv_view(df: pd.DataFrame, view: str) -> dict:
    sub = view_mask(df, view)
    X = sub[TRAIN_FEATURES].to_numpy(dtype=float)
    y = sub["parkinsons_label"].to_numpy(dtype=int)
    groups = sub["subject_id"].to_numpy()
    sources = sub["dataset_source"].to_numpy()

    folds = cached_folds(view, y, groups)
    prob_rows, fold_metrics = [], []
    for fold, (train_idx, test_idx) in enumerate(folds):
        assert_no_subject_leakage(train_idx, test_idx, groups)
        scalers = fit_per_dataset_scalers(X[train_idx],
                                          sources[train_idx], TRAIN_FEATURES)
        X_tr = transform_with_scalers(X[train_idx], sources[train_idx],
                                      scalers)
        X_te = transform_with_scalers(X[test_idx], sources[test_idx], scalers)
        model = RandomForestClassifier(**RF_PARAMS)
        model.fit(X_tr, y[train_idx])
        scores = model.predict_proba(X_te)[:, 1]
        fold_metrics.append(summarize_metrics(y[test_idx], scores))
        for sid, true, score in zip(sub["subject_id"].iloc[test_idx],
                                    y[test_idx], scores):
            prob_rows.append({"subject_id": sid, "fold": fold,
                              "y_true": int(true), "y_score": float(score)})
    probs = pd.DataFrame(prob_rows)
    probs.to_csv(os.path.join(OUT_DIR, f"probabilities_{view}.csv"),
                 index=False)
    return {"view": view, "n_subjects": int(sub["subject_id"].nunique()),
            "n_rows": len(sub), "folds": fold_metrics,
            "mean": _mean_metrics(fold_metrics)}


def run_lodo(df: pd.DataFrame, train_source: str) -> dict:
    X = df[TRAIN_FEATURES].to_numpy(dtype=float)
    y = df["parkinsons_label"].to_numpy(dtype=int)
    groups = df["subject_id"].to_numpy()
    sources = df["dataset_source"].to_numpy()
    test_source = [s for s in ("tappy", "neuroqwerty")
                   if s != train_source][0]

    train_idx = np.where(sources == train_source)[0]
    test_idx = np.where(sources == test_source)[0]
    assert_no_subject_leakage(train_idx, test_idx, groups)
    scalers = fit_per_dataset_scalers(X[train_idx], sources[train_idx],
                                      TRAIN_FEATURES)
    X_tr = transform_with_scalers(X[train_idx], sources[train_idx], scalers)
    X_te = transform_with_train_scaler(X[test_idx], scalers)
    model = RandomForestClassifier(**RF_PARAMS)
    model.fit(X_tr, y[train_idx])
    scores = model.predict_proba(X_te)[:, 1]
    probs = pd.DataFrame({
        "subject_id": groups[test_idx], "y_true": y[test_idx],
        "y_score": scores})
    name = f"train_{train_source}_test_{test_source}"
    probs.to_csv(os.path.join(OUT_DIR, f"probabilities_{name}.csv"),
                 index=False)
    return {"view": name, "metrics": summarize_metrics(y[test_idx], scores),
            "n_train_subjects": int(len(set(groups[train_idx]))),
            "n_test_subjects": int(len(set(groups[test_idx])))}


def _mean_metrics(fold_metrics: list) -> dict:
    out = {}
    for key in ("roc_auc", "avg_precision", "f1"):
        vals = [m[key] for m in fold_metrics]
        out[key] = {"mean": float(np.mean(vals)),
                    "std": float(np.std(vals))}
    return out


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(REPORTS_DIR, exist_ok=True)
    started = time.time()
    df = load_training_frame()
    assert (df[TRAIN_FEATURES].isna().sum() == 0).all()

    results = {
        "experiment": "rf_baseline",
        "model": "RandomForestClassifier",
        "params": RF_PARAMS,
        "features": TRAIN_FEATURES,
        "versions": package_versions(),
        "views": {},
    }
    for view in ("pooled", "tappy", "neuroqwerty"):
        print(f"[rf] CV view: {view}", flush=True)
        results["views"][view] = run_cv_view(df, view)
    for train_source in ("tappy", "neuroqwerty"):
        print(f"[rf] LODO: train {train_source}", flush=True)
        name = f"train_{train_source}_test_" + (
            "neuroqwerty" if train_source == "tappy" else "tappy")
        results["views"][name] = run_lodo(df, train_source)

    # Full-data artifact for reproducibility (NOT wired into inference).
    full = RandomForestClassifier(**RF_PARAMS)
    scalers = fit_per_dataset_scalers(
        df[TRAIN_FEATURES].to_numpy(dtype=float),
        df["dataset_source"].to_numpy(), TRAIN_FEATURES)
    joblib.dump({"model": full.fit(
        transform_with_scalers(df[TRAIN_FEATURES].to_numpy(dtype=float),
                               df["dataset_source"].to_numpy(), scalers),
        df["parkinsons_label"].to_numpy(dtype=int)),
        "scalers": scalers, "features": TRAIN_FEATURES},
        os.path.join(OUT_DIR, "model_full.joblib"))

    results["runtime_sec"] = round(time.time() - started, 1)
    with open(os.path.join(REPORTS_DIR, "stage4_rf_results.json"), "w") as fh:
        json.dump(results, fh, indent=2, default=str)
    for view, payload in results["views"].items():
        m = payload.get("mean", payload.get("metrics", {}))
        print(f"[rf] {view}: {json.dumps(m, default=str)}", flush=True)
    print(f"[rf] done in {results['runtime_sec']}s")


if __name__ == "__main__":
    main()
