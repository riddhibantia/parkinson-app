# Research provenance (read-only copies — do not edit)

Source of truth for datasets, features, and evaluation:
- `feature_schema.json` — canonical 12+1 typing features (copied from
  `functions/data/harmonized/feature_schema.json`).
- `harmonization_report.json` — verified counts: Tappy 227 subjects
  (169 PD / 58 HC, 212 with files, 552 month-rows); neuroQWERTY 85
  (42 PD / 43 HC); pooled 668 rows / 297 subjects.
- `stage4_summary.md` / `stage4_rf_results.json` — locked evaluation:
  RF pooled ROC-AUC 0.600 ± 0.019 (primary); TabPFN experimental.

## Authoritative Layer 1 artifact (NOT committed — referenced)

- Path (dev): `functions/models/experiments/rf/model_full.joblib`
- Scaler (dev): `functions/models/experiments/rf/live_scaler.json`
- SHA256 (model_full.joblib): `2D2FF7A7198DABB3C6B6CF6179E8DFBB05BAEB9AE14876A9B33AD980B6C9490A`
- Size: 1827839 bytes
- Trained under: scikit-learn 1.6.1 / Python 3.10.11
- Features (12, ordered): ht_mean, ht_std, ft_mean, ft_std, ikl_mean,
  ikl_std, left_ht_mean, right_ht_mean, hand_asymmetry, pause_frequency,
  typing_speed, session_consistency (backspace_rate EXCLUDED by design)
- Env override: `PARKINTRACE_RF_ARTIFACT` / `PARKINTRACE_RF_SCALER`

Spec 9.2 note: the master spec claimed this artifact was missing from
the inspected ZIP. It EXISTS in the live repo at the path above and
loads (verified 2026-09-29). No retraining or substitution was performed.
Production must pin scikit-learn==1.6.1 (current dev box has 1.7.2,
which loads only with an InconsistentVersionWarning).
