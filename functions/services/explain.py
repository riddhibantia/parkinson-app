"""SHAP explanations for Layer 1 results (Stage 4.5, async by design).

The classification result returns immediately; this runs as a follow-up
trigger and attaches the top contributing features afterwards. Uses
TreeExplainer on the frozen Random Forest (exact, fast) — never on the
live scoring path. Language stays non-diagnostic (Stage 9.4): features
are described as timing observations, never as evidence of disease.
"""

import os

import joblib
import numpy as np
import pandas as pd

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTIFACT = os.path.join(BASE, "models", "experiments", "rf",
                        "model_full.joblib")
HARMONIZED_CSV = os.path.join(BASE, "data", "harmonized",
                              "harmonized_sessions.csv")
N_BACKGROUND = 100
TOP_K = 3

# Plain-language, non-diagnostic descriptions per feature direction.
DESCRIPTIONS = {
    "ht_mean": ("key presses held longer than typical",
                "key presses held shorter than typical"),
    "ht_std": ("hold times more variable than typical",
               "hold times steadier than typical"),
    "ft_mean": ("slower finger transitions than typical",
                "quicker finger transitions than typical"),
    "ft_std": ("transition timing more variable than typical",
               "transition timing steadier than typical"),
    "ikl_mean": ("slower overall typing rhythm than typical",
                "faster overall typing rhythm than typical"),
    "ikl_std": ("typing rhythm more variable than typical",
               "typing rhythm steadier than typical"),
    "left_ht_mean": ("left-hand holds longer than typical",
                     "left-hand holds shorter than typical"),
    "right_ht_mean": ("right-hand holds longer than typical",
                      "right-hand holds shorter than typical"),
    "hand_asymmetry": ("more left/right timing difference than typical",
                       "more even left/right timing than typical"),
    "pause_frequency": ("more pauses than typical",
                        "fewer pauses than typical"),
    "typing_speed": ("slower typing speed than typical",
                     "faster typing speed than typical"),
    "session_consistency": ("less regular rhythm than typical",
                            "more regular rhythm than typical"),
}

_bundle = None


def _load():
    global _bundle
    if _bundle is None:
        artifact = joblib.load(ARTIFACT)
        features = artifact["features"]
        # Background for TreeExplainer: prefer harmonized CSV when
        # present (offline/dev), else fall back to synthetic median
        # background so the deployed function does not need the CSV
        # bundled (size + data governance).
        try:
            frame = pd.read_csv(HARMONIZED_CSV)
            background = frame[features].dropna().sample(
                n=min(N_BACKGROUND, len(frame)), random_state=42)
        except Exception:
            # Minimal fallback: single-row median-like background
            background = pd.DataFrame(
                [ [0.0]*len(features) ], columns=features)
        try:
            import shap  # deferred import — see requirements.txt note
        except Exception as exc:  # shap absent -> caller degrades
            raise ImportError(f"shap not available: {exc}") from exc
        explainer = shap.TreeExplainer(artifact["model"],
                                       data=background)
        _bundle = {"model": artifact["model"],
                   "features": features,
                   "background": background,
                   "explainer": explainer}
    return _bundle


def explain_session(session_features: dict, top_k: int = TOP_K) -> list:
    """Top contributing features for one scored session.

    Returns [{feature, contribution, direction, text}] sorted by
    absolute contribution. Raises KeyError/ValueError on incomplete
    input — callers treat that as 'explanation unavailable', never a
    health result.
    """
    bundle = _load()
    row = pd.DataFrame(
        [[float(session_features[name]) for name in bundle["features"]]],
        columns=bundle["features"])
    values = np.asarray(bundle["explainer"].shap_values(row))
    if values.ndim == 3:  # (rows, features, classes) -> positive class
        values = values[0, :, 1]
    elif values.ndim == 2 and values.shape[1] == 2:
        values = values[:, 1]
    else:
        values = values.reshape(-1)
    contributions = dict(zip(bundle["features"], values))
    ranked = sorted(contributions.items(), key=lambda kv: abs(kv[1]),
                    reverse=True)[:top_k]
    background = bundle["background"]
    out = []
    for name, contribution in ranked:
        typical = float(background[name].median())
        actual = float(row[name].iloc[0])
        high_side = actual >= typical
        pair = DESCRIPTIONS.get(name, ("stood out most", "stood out most"))
        out.append({
            "feature": name,
            "contribution": float(contribution),
            "direction": "above_typical" if high_side else "below_typical",
            "text": f"Your {pair[0] if high_side else pair[1]} "
                    f"this session.",
        })
    return out
