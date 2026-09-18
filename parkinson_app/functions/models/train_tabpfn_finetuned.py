"""Experiment C — fine-tuned TabPFN v2 (Stage 4.4). GPU script.

Fine-tuning = genuine gradient updates on pretrained weights via
    from tabpfn.finetuning import FinetunedTabPFNClassifier
so a completed run here may be reported as "fine-tuned" (plan precision
note). Runs on the Colab GPU (tabpfn>=6 provides tabpfn.finetuning;
the local tabpfn==2.2.1 env used for experiment B does not).

Licensing: model_version is pinned to the "v2" family (Prior Labs
License 1.1 = Apache-derived + attribution). NEVER v3 weights
(research/non-commercial only).

Colab steps:
  1. Runtime -> Change runtime type -> T4 GPU.
  2. pip install "tabpfn==9.0.0" pandas scikit-learn joblib
  3. Upload harmonized_sessions.csv (or mount Drive and point --data).
  4. python train_tabpfn_finetuned.py --data harmonized_sessions.csv
       --out ./tabpfn_finetuned --device cuda
  5. Download the --out directory back into models/experiments/.

Local check (no GPU burn): --smoke builds data/folds/scalers and exits
before .fit().

Configuration guidance (Prior Labs docs): epochs 10-30 start, lr 1e-5
default (conservative, preserves priors), GPU strongly recommended.
"""

import argparse
import json
import os
import sys
import time
import traceback

sys.path.insert(0, os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--learning-rate", type=float, default=1e-5)
    parser.add_argument("--model-version", default="v2")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--smoke", action="store_true")
    return parser.parse_args()


def main() -> None:
    from models.exp_common import (  # noqa: E402
        TRAIN_FEATURES,
        cached_folds,
        package_versions,
    )
    from services.evaluation import (  # noqa: E402
        assert_no_subject_leakage,
        fit_per_dataset_scalers,
        summarize_metrics,
        transform_with_scalers,
    )

    args = parse_args()
    os.makedirs(args.out, exist_ok=True)

    df = pd.read_csv(args.data).dropna(subset=TRAIN_FEATURES)
    df = df.reset_index(drop=True)
    X = df[TRAIN_FEATURES].to_numpy(dtype=float)
    y = df["parkinsons_label"].to_numpy(dtype=int)
    groups = df["subject_id"].to_numpy()
    sources = df["dataset_source"].to_numpy()
    folds = cached_folds("pooled", y, groups)
    print(f"[finetune] rows={len(df)} subjects={df['subject_id'].nunique()} "
          f"features={len(TRAIN_FEATURES)} folds={len(folds)}", flush=True)

    # Smoke path: verify data/folds/scalers, then stop before any .fit().
    train_idx, test_idx = folds[0]
    assert_no_subject_leakage(train_idx, test_idx, groups)
    scalers = fit_per_dataset_scalers(X[train_idx], sources[train_idx],
                                      TRAIN_FEATURES)
    _ = transform_with_scalers(X[train_idx], sources[train_idx], scalers)
    _ = transform_with_scalers(X[test_idx], sources[test_idx], scalers)
    print("[finetune] smoke: data/folds/scalers OK", flush=True)
    if args.smoke:
        return

    from tabpfn.finetuning import FinetunedTabPFNClassifier  # noqa: E402
    import torch  # noqa: E402

    config = {
        "experiment": "tabpfn_finetuned",
        "model": "FinetunedTabPFNClassifier",
        "model_version": args.model_version,
        "device": args.device,
        "epochs": args.epochs,
        "learning_rate": args.learning_rate,
        "seed": args.seed,
        "features": TRAIN_FEATURES,
        "versions": package_versions(),
        "gpu": torch.cuda.get_device_name(0)
        if torch.cuda.is_available() else None,
    }
    print(json.dumps({k: v for k, v in config.items()
                      if k != "features"}, indent=2, default=str),
          flush=True)

    prob_rows, fold_metrics, errors = [], [], []
    for fold, (train_idx, test_idx) in enumerate(folds):
        assert_no_subject_leakage(train_idx, test_idx, groups)
        scalers = fit_per_dataset_scalers(X[train_idx],
                                          sources[train_idx], TRAIN_FEATURES)
        X_tr = transform_with_scalers(X[train_idx], sources[train_idx],
                                      scalers)
        X_te = transform_with_scalers(X[test_idx], sources[test_idx],
                                      scalers)
        t0 = time.time()
        try:
            model = FinetunedTabPFNClassifier(
                device=args.device,
                epochs=args.epochs,
                learning_rate=args.learning_rate,
                model_version=args.model_version,
                random_state=args.seed,
            )
            model.fit(X_tr, y[train_idx])
            scores = model.predict_proba(X_te)[:, 1]
            fold_metrics.append(summarize_metrics(y[test_idx], scores))
            status = "ok"
        except Exception:  # noqa: BLE001 — record, don't redesign
            status = "failed"
            errors.append({"fold": fold,
                           "trace": traceback.format_exc()[-2000:]})
        elapsed = round(time.time() - t0, 1)
        print(f"[finetune] fold {fold}: {status} ({elapsed}s)", flush=True)
        if status == "ok":
            for sid, true, score in zip(df["subject_id"].iloc[test_idx],
                                        y[test_idx], scores):
                prob_rows.append({"subject_id": sid, "fold": fold,
                                  "y_true": int(true),
                                  "y_score": float(score)})

    if prob_rows:
        pd.DataFrame(prob_rows).to_csv(
            os.path.join(args.out, "probabilities_pooled.csv"), index=False)
    config["folds"] = fold_metrics
    config["errors"] = errors
    config["mean"] = {
        k: {"mean": float(np.mean([m[k] for m in fold_metrics])),
            "std": float(np.std([m[k] for m in fold_metrics]))}
        for k in ("roc_auc", "avg_precision", "f1")
    } if fold_metrics else None
    with open(os.path.join(args.out, "finetuned_results.json"), "w") as fh:
        json.dump(config, fh, indent=2, default=str)
    print(json.dumps(config["mean"], default=str), flush=True)


if __name__ == "__main__":
    main()
