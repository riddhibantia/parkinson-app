"""neuroQWERTY adapter (Stage 4.1).

Raw layout (verified against the download + nqDataLoader.py):
- `MIT-CS1PD/GT_DataPD_MIT-CS1PD.csv`, `MIT-CS2PD/GT_DataPD_MIT-CS2PD.csv`:
  per-subject labels (`pID`, boolean `gt`) plus `file_1`/`file_2` session
  file names. No age/sex columns exist — never imputed.
- `data_MIT-CSXPD/<epoch>_<pID>_<rep>_<exp>.csv`: HEADERLESS rows
  [key, f1, f2, f3] where f3 = press time, f2 = release time (seconds;
  see the loader's "CHANGED 2<->3" note), f1 mirrors hold for valid rows.
  Row 0 carries the absolute session start (negative f3) and is dropped
  by the loader's sanityCheck (start <= 0); same here.

Hand/row derivation mirrors the Flutter capture service exactly (fixed
QWERTY zones; space falls to right/row-1 there too), so the identical
Stage 3 code path scores these rows.
"""

import os
import re

import pandas as pd

from services.feature_extraction import extract_features

LEFT_KEYS = set("qwertasdfgzxcvb")
ROW_0 = set("qwertyuiop")
ROW_1 = set("asdfghjkl")
ROW_2 = set("zxcvbnm")

MOUSE_RE = re.compile(r"mouse.+", re.IGNORECASE)
LONG_META_RE = re.compile(r"(shift.+)|(alt.+)|(control.+)", re.IGNORECASE)


def hand_for(key: str) -> str:
    return "left" if key.lower() in LEFT_KEYS else "right"


def row_for(key: str) -> int:
    label = key.lower()
    if len(label) == 1:
        if label in ROW_0:
            return 0
        if label in ROW_1:
            return 1
        if label in ROW_2:
            return 2
    return 1


def key_type_for(key: str) -> str:
    if key == "BackSpace":
        return "backspace"
    if len(key) == 1 or key == "space":
        return "character"
    if MOUSE_RE.match(key) or LONG_META_RE.match(key):
        return "control"
    # Short meta (Return, arrows, Caps_Lock, ...) — excluded like the
    # loader's short-meta filter and the live control category.
    return "control"


def load_ground_truth(nq_root: str, dataset: str) -> pd.DataFrame:
    """Per-subject labels; e.g. dataset='MIT-CS1PD'."""
    path = os.path.join(nq_root, dataset, f"GT_DataPD_{dataset}.csv")
    gt = pd.read_csv(path)
    gt["parkinsons_label"] = gt["gt"].astype(bool).astype(int)
    return gt


def file_to_events(path: str) -> tuple:
    """Typing file -> (wire-format events, raw_row_count)."""
    df = pd.read_csv(path, header=None,
                     names=["key", "f1", "f2", "f3"], dtype=str)
    raw_rows = len(df)
    df["press_s"] = pd.to_numeric(df["f3"], errors="coerce")
    df["release_s"] = pd.to_numeric(df["f2"], errors="coerce")
    df = df.dropna(subset=["press_s", "release_s"])
    # Loader sanity bounds: positive starts, 0 <= HT < 5 s.
    df["ht_s"] = df["release_s"] - df["press_s"]
    df = df[(df["press_s"] > 0) & (df["ht_s"] >= 0) & (df["ht_s"] < 5)]
    df = df.reset_index(drop=True)

    events = []
    for _, row in df.iterrows():
        key = str(row["key"])
        events.append({
            "pressTimestamp": int(float(row["press_s"]) * 1_000_000),
            "releaseTimestamp": int(float(row["release_s"]) * 1_000_000),
            "hand": hand_for(key),
            "row": row_for(key),
            "keyType": key_type_for(key),
        })
    return events, raw_rows


def file_to_features(path: str) -> dict:
    """Typing file -> shared-feature row via the identical Stage 3 path."""
    events, raw_rows = file_to_events(path)
    duration = 0.0
    presses = [e["pressTimestamp"] for e in events
               if e["keyType"] == "character"]
    releases = [e["releaseTimestamp"] for e in events
                if e["keyType"] == "character"]
    if presses and releases:
        duration = (max(releases) - min(presses)) / 1_000_000.0
    features = extract_features(events, duration)
    features.pop("outlier_removal", None)
    features["n_keystrokes"] = len(
        [e for e in events if e["keyType"] == "character"])
    features["raw_rows"] = raw_rows
    return features
