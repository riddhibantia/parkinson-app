"""Tappy adapter (Stage 4.1).

Raw layout (verified against the download):
- `users/Archived users/User_<CODE>.txt`: `Key: value` lines with BirthYear,
  Gender, Parkinsons (True/False), Tremors, DiagnosisYear, Sided, ...
- `keystrokes/Tappy Data/<CODE>_YYMM.txt`: TAB-separated, HEADERLESS rows
  [UserKey, Date(YYMMDD), Timestamp, Hand, Hold, Direction, Latency(PP),
  Flight, (empty)] in milliseconds.

Quirks handled here (all observed in the spike):
- Rare corrupt rows where a newline is missing and two records
  concatenate -> dropped via numeric/hand validation.
- The first row of each monthly file references unobserved prior context
  in its Latency/Flight -> dropped.
"""

import os

import pandas as pd

TAPPY_COLS = ["user", "date", "time", "hand", "ht", "direction",
              "pp", "ft", "trailing"]

LABEL_MAP = {"True": 1, "False": 0}


def keystroke_dir(tappy_root: str) -> str:
    base = os.path.join(tappy_root, "keystrokes")
    sub = os.listdir(base)[0]
    full = os.path.join(base, sub)
    return full if os.path.isdir(full) else base


def load_users(tappy_root: str) -> pd.DataFrame:
    """Subject table with labels joined from the per-subject files."""
    udir = os.path.join(tappy_root, "users", "Archived users")
    rows = []
    for fn in sorted(os.listdir(udir)):
        record = {}
        with open(os.path.join(udir, fn)) as fh:
            for line in fh:
                if ":" in line:
                    key, value = line.split(":", 1)
                    record[key.strip()] = value.strip()
        record["subject_id"] = fn[5:15]
        rows.append(record)
    users = pd.DataFrame(rows)
    users["parkinsons_label"] = users["Parkinsons"].map(LABEL_MAP)
    return users


def monthly_files(tappy_root: str, code: str) -> list:
    kdir = keystroke_dir(tappy_root)
    return sorted(f for f in os.listdir(kdir) if f.startswith(code + "_"))


def read_monthly_file(tappy_root: str, fname: str) -> pd.DataFrame:
    """One monthly file -> cleaned keystroke frame (ms floats)."""
    df = pd.read_csv(os.path.join(keystroke_dir(tappy_root), fname),
                     sep="\t", header=None, names=TAPPY_COLS, dtype=str)
    for col in ("ht", "pp", "ft"):
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df = df.dropna(subset=["ht", "pp", "ft"])
    df = df[df["hand"].isin(["L", "R"])]
    df = df.reset_index(drop=True)
    # First row's Latency/Flight reference context outside this file.
    return df.iloc[1:].reset_index(drop=True)


def age_at_session(birth_year, yymm: str) -> int | None:
    """Whole-year age from birth year + file YYMM stamp (all Tappy
    collection falls in the 2000s)."""
    try:
        return 2000 + int(str(yymm)[:2]) - int(birth_year)
    except (ValueError, TypeError):
        return None


def month_to_features(df: pd.DataFrame) -> dict:
    """Monthly keystroke frame -> shared-feature summary row."""
    import numpy as np

    ht = df["ht"].to_numpy(dtype=float)
    ft = df["ft"].to_numpy(dtype=float)
    pp = df["pp"].to_numpy(dtype=float)
    rr = pp[1:] + ht[1:] - ht[:-1]
    left = ht[df["hand"].to_numpy() == "L"]
    right = ht[df["hand"].to_numpy() != "L"]
    left_mean = float(np.mean(left)) if len(left) else None
    right_mean = float(np.mean(right)) if len(right) else None
    denom = None
    if left_mean is not None and right_mean is not None:
        denom = max(left_mean, right_mean)
    # Active time base: press-press gaps up to the Stage 3.3 FT cutoff;
    # longer gaps are idle time, not typing.
    active = pp[pp <= 3000.0]
    active_min = float(np.sum(active)) / 60000.0 if len(active) else 0.0
    pauses = int(np.sum(ft > 500.0))
    ikl_mean = float(np.mean(pp))
    return {
        "ht_mean": float(np.mean(ht)),
        "ht_std": float(np.std(ht)),
        "ft_mean": float(np.mean(ft)),
        "ft_std": float(np.std(ft)),
        "ikl_mean": ikl_mean,
        "ikl_std": float(np.std(pp)),
        "left_ht_mean": left_mean,
        "right_ht_mean": right_mean,
        "hand_asymmetry": (abs(left_mean - right_mean) / denom
                           if denom else None),
        "pause_frequency": (pauses / active_min if active_min > 0 else None),
        "typing_speed": (len(df) / (active_min * 60.0)
                         if active_min > 0 else None),
        "session_consistency": (float(np.std(pp) / ikl_mean)
                                if ikl_mean else None),
        # Tappy records no backspace events -> unavailable, never imputed.
        "backspace_rate": None,
        "rr_mean": float(np.mean(rr)) if len(rr) else None,
        "n_keystrokes": len(df),
    }
