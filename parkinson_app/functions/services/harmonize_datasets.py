"""Dual-dataset harmonization (Stage 4.1).

Both datasets are pooled into ONE common feature schema: the intersection
of what they support (HT/FT/PP-IKL/variability/pauses/speed/asymmetry),
one row per analysis unit (Tappy: subject-month; neuroQWERTY: session
file), every row carrying `subject_id`, `dataset_source`, and the joined
`parkinsons_label`.

Labels are NOT on the keystroke rows in either dataset — they are joined
from the separate per-subject files by subject ID (Pre-Build #2).
"""

import json
import os

import pandas as pd

from services.neuroqwerty_adapter import (
    file_to_features,
    load_ground_truth,
)
from services.tappy_adapter import (
    age_at_session,
    load_users,
    month_to_features,
    monthly_files,
    read_monthly_file,
)
from utils.constants import TYPING_FEATURE_LIST

SCHEMA_COLUMNS = (
    ["subject_id", "dataset_source", "parkinsons_label",
     "age_at_session", "sex_gender", "demographics_available"]
    + TYPING_FEATURE_LIST
    + ["n_keystrokes", "source_file"]
)


def load_and_label(keystroke_df: pd.DataFrame, ground_truth: pd.DataFrame,
                   subject_col: str = "subject_id",
                   label_col: str = "parkinsons_label") -> pd.DataFrame:
    """Inner-join feature rows to the SEPARATE per-subject ground truth.

    Subjects with keystroke data but no label are dropped and counted —
    never silently mislabeled.
    """
    labeled = keystroke_df.merge(
        ground_truth[[subject_col, label_col]],
        on=subject_col, how="inner",
    )
    dropped = (len(keystroke_df[subject_col].unique())
               - len(labeled[subject_col].unique()))
    if dropped:
        print(f"WARNING: {dropped} subjects had keystroke data but no "
              f"ground-truth label — dropped")
    return labeled, dropped


def build_tappy_rows(tappy_root: str) -> tuple:
    """One row per (subject, month-file), labels joined explicitly."""
    users = load_users(tappy_root)
    ground_truth = users[["subject_id", "parkinsons_label"]].copy()
    rows, files_seen, files_empty = [], 0, 0
    meta = {u["subject_id"]: u for _, u in users.iterrows()}
    for code, user in meta.items():
        try:
            birth_year = int(str(user.get("BirthYear", "")).strip())
        except ValueError:
            birth_year = None
        for fname in monthly_files(tappy_root, code):
            files_seen += 1
            df = read_monthly_file(tappy_root, fname)
            if len(df) < 2:
                files_empty += 1
                continue
            yymm = fname.rsplit("_", 1)[-1].split(".")[0]
            rows.append({
                "subject_id": code,
                "dataset_source": "tappy",
                "age_at_session": (age_at_session(birth_year, yymm)
                                   if birth_year else None),
                "sex_gender": user.get("Gender"),
                "demographics_available": True,
                **month_to_features(df),
                "source_file": fname,
            })
    unlabeled = pd.DataFrame(rows)
    table, dropped = load_and_label(unlabeled, ground_truth)
    stats = {
        "subjects_total": len(users),
        "subjects_labeled": int(ground_truth["parkinsons_label"].notna()
                                .sum()),
        "label_counts": ground_truth["parkinsons_label"].value_counts(
            ).to_dict(),
        "subjects_with_files": table["subject_id"].nunique()
        if len(table) else 0,
        "subjects_dropped_no_label": dropped,
        "month_files_seen": files_seen,
        "month_files_skipped_too_small": files_empty,
        "rows": len(table),
    }
    return table, stats


def build_neuroqwerty_rows(nq_root: str) -> tuple:
    """One row per session file, labels joined explicitly."""
    rows = []
    gt_frames = []
    stats = {"subjects": 0, "label_counts": {}, "files": 0,
             "subjects_dropped_no_label": 0, "rows": 0}
    for dataset in ("MIT-CS1PD", "MIT-CS2PD"):
        gt = load_ground_truth(nq_root, dataset)
        gt["subject_id"] = gt["pID"].apply(lambda p: f"nq-{dataset}-{p}")
        gt_frames.append(gt[["subject_id", "parkinsons_label"]])
        ddir = os.path.join(nq_root, dataset, f"data_{dataset}")
        for _, row in gt.iterrows():
            stats["subjects"] += 1
            label = int(row["parkinsons_label"])
            stats["label_counts"][label] = \
                stats["label_counts"].get(label, 0) + 1
            for file_col in ("file_1", "file_2"):
                fname = row.get(file_col)
                if not isinstance(fname, str) or not fname:
                    continue
                path = os.path.join(ddir, fname)
                if not os.path.exists(path):
                    continue
                stats["files"] += 1
                rows.append({
                    "subject_id": f"nq-{dataset}-{row['pID']}",
                    "dataset_source": "neuroqwerty",
                    "age_at_session": None,
                    "sex_gender": None,
                    "demographics_available": False,
                    **file_to_features(path),
                    "source_file": f"{dataset}/{fname}",
                })
    unlabeled = pd.DataFrame(rows)
    ground_truth = pd.concat(gt_frames, ignore_index=True)
    table, dropped = load_and_label(unlabeled, ground_truth)
    stats["subjects_dropped_no_label"] = dropped
    stats["rows"] = len(table)
    return table, stats


def build_pooled(tappy_root: str, nq_root: str) -> tuple:
    """Pooled table + report. Column order frozen for training/inference."""
    tappy_table, tappy_stats = build_tappy_rows(tappy_root)
    nq_table, nq_stats = build_neuroqwerty_rows(nq_root)
    pooled = pd.concat([tappy_table, nq_table], ignore_index=True)
    pooled = pooled[[c for c in SCHEMA_COLUMNS if c in pooled.columns]]
    report = {
        "tappy": tappy_stats,
        "neuroqwerty": nq_stats,
        "pooled_rows": len(pooled),
        "pooled_subjects": int(pooled["subject_id"].nunique()),
        "column_missingness": {
            c: int(pooled[c].isna().sum()) for c in pooled.columns
        },
        "schema_columns": list(pooled.columns),
    }
    return pooled, report


def save_artifacts(pooled: pd.DataFrame, report: dict, out_dir: str) -> None:
    """Persist the dataset + the preprocessing artifacts that pin the
    exact feature definitions for later training and live inference."""
    os.makedirs(out_dir, exist_ok=True)
    pooled.to_csv(os.path.join(out_dir, "harmonized_sessions.csv"),
                  index=False)
    schema = {
        "columns": list(pooled.columns),
        "typing_features": TYPING_FEATURE_LIST,
        "dtypes": {c: str(pooled[c].dtype) for c in pooled.columns},
        "sources": {
            "tappy": "PhysioNet tappy/1.0.0 (ODC-By-1.0)",
            "neuroqwerty": "PhysioNet nqmitcsxpd/1.0.0 (ODC-By-1.0)",
        },
    }
    with open(os.path.join(out_dir, "feature_schema.json"), "w") as fh:
        json.dump(schema, fh, indent=2, default=str)
    with open(os.path.join(out_dir, "harmonization_report.json"), "w") as fh:
        json.dump(report, fh, indent=2, default=str)
