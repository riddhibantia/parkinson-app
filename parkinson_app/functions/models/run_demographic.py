"""Demographic secondary experiment (Stage 4.4 sensitivity analysis).

Typing-only vs typing + age + sex/gender, on the SAME complete-case
subset (Tappy rows with valid age and sex; neuroQWERTY rows carry neither
and are excluded entirely), under the SAME cached subject-grouped folds.
Single-source subset -> pooled-subset CV only (no LODO possible).

NOT part of the primary model. Missingness is disclosed, not imputed:
40 Tappy subjects (33 PD) lack birth year, so complete-case analysis can
be biased — this experiment measures sensitivity, it cannot replace the
primary typing-only result.

Both model families (RF + pretrained TabPFN v2) run both arms so the
demographic delta is measured within each family.

Run: python models/run_demographic.py
"""

import json
import os
import sys
import time

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
)
from services.evaluation import (  # noqa: E402
    assert_no_subject_leakage,
    fit_per_dataset_scalers,
    summarize_metrics,
    transform_with_scalers,
)

RF_PARAMS = {
    "n_estimators": 200,
    "max_depth": 8,
    "class_weight": "balanced",
    "random_state": 42,
}
TABPFN_PARAMS = {"device": "cpu"}
VIEW = "demographic_subset"
OUT_DIR = os.path.join(EXPERIMENTS_DIR, "demographic_secondary")


def build_subset(df: pd.DataFrame) -> tuple:
    """Complete-case Tappy rows + encoded demographics."""
    sub = df[(df["dataset_source"] == "tappy")
             & df["age_at_session"].notna()
             & df["sex_gender"].notna()].copy()
    sub = sub.reset_index(drop=True)
    valid_sex = set(sub["sex_gender"].unique().tolist())
    assert valid_sex <= {"Male", "Female"}, f"Unexpected terms: {valid_sex}"
    sub["age_years"] = sub["age_at_session"].astype(float)
    sub["sex_male"] = (sub["sex_gender"] == "Male").astype(float)
    return sub, {
        "n_rows": len(sub),
        "n_subjects": int(sub["subject_id"].nunique()),
        "label_rate": float(sub["parkinsons_label"].mean()),
        "sex_terms": sorted(valid_sex),
        "age_range": [float(sub["age_years"].min()),
                      float(sub["age_years"].max())],
    }


def run_arm(sub: pd.DataFrame, features: list, model_name: str) -> dict:
    X = sub[features].to_numpy(dtype=float)
    y = sub["parkinsons_label"].to_numpy(dtype=int)
    groups = sub["subject_id"].to_numpy()
    sources = sub["dataset_source"].to_numpy()

    folds = cached_folds(VIEW, y, groups)
    prob_rows, fold_metrics = [], []
    for fold, (train_idx, test_idx) in enumerate(folds):
        assert_no_subject_leakage(train_idx, test_idx, groups)
        scalers = fit_per_dataset_scalers(X[train_idx],
                                          sources[train_idx], features)
        X_tr = transform_with_scalers(X[train_idx], sources[train_idx],
                                      scalers)
        X_te = transform_with_scalers(X[test_idx], sources[test_idx],
                                      scalers)
        if model_name == "rf":
            model = RandomForestClassifier(**RF_PARAMS)
        else:
            from tabpfn import TabPFNClassifier
            model = TabPFNClassifier(**TABPFN_PARAMS)
        t0 = time.time()
        model.fit(X_tr, y[train_idx])
        scores = model.predict_proba(X_te)[:, 1]
        print(f"[demo] {model_name} {'+'.join(features[-2:]) if len(features) > len(TRAIN_FEATURES) else 'typing-only'} "
              f"fold {fold}: {round(time.time() - t0, 1)}s", flush=True)
        fold_metrics.append(summarize_metrics(y[test_idx], scores))
        for sid, true, score in zip(sub["subject_id"].iloc[test_idx],
                                    y[test_idx], scores):
            prob_rows.append({"subject_id": sid, "fold": fold,
                              "y_true": int(true), "y_score": float(score)})
    tag = f"{model_name}_{'with_demo' if len(features) > len(TRAIN_FEATURES) else 'typing_only'}"
    pd.DataFrame(prob_rows).to_csv(
        os.path.join(OUT_DIR, f"probabilities_{tag}.csv"), index=False)
    vals = {}
    for key in ("roc_auc", "avg_precision", "f1"):
        v = [m[key] for m in fold_metrics]
        vals[key] = {"mean": float(np.mean(v)), "std": float(np.std(v))}
    return {"arm": tag, "features": features, "mean": vals,
            "folds": fold_metrics}


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(REPORTS_DIR, exist_ok=True)
    started = time.time()
    df = load_training_frame()
    sub, subset_info = build_subset(df)
    print(f"[demo] subset: {subset_info}", flush=True)

    results = {
        "experiment": "demographic_secondary",
        "scope": ("Sensitivity analysis ONLY. Complete-case Tappy rows; "
                  "40 Tappy subjects (33 PD) missing birth year are "
                  "excluded, so missingness is not random. Must not "
                  "replace the primary typing-only model."),
        "subset": subset_info,
        "rf_params": RF_PARAMS,
        "tabpfn_params": TABPFN_PARAMS,
        "versions": package_versions(),
        "arms": {},
    }
    for model_name in ("rf", "tabpfn"):
        results["arms"][f"{model_name}_typing_only"] = run_arm(
            sub, TRAIN_FEATURES, model_name)
        results["arms"][f"{model_name}_with_demo"] = run_arm(
            sub, TRAIN_FEATURES + ["age_years", "sex_male"], model_name)

    results["runtime_sec"] = round(time.time() - started, 1)
    with open(os.path.join(
            REPORTS_DIR, "stage4_demographic_results.json"), "w") as fh:
        json.dump(results, fh, indent=2, default=str)
    for tag, payload in results["arms"].items():
        print(f"[demo] {tag}: {json.dumps(payload['mean'])}", flush=True)
    print(f"[demo] done in {results['runtime_sec']}s")


if __name__ == "__main__":
    main()
