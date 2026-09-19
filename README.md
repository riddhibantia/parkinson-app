# Parkinson's Early Screening & Monitoring — Parkinson App

Flutter **desktop** (Windows/macOS/Linux) for personalized Parkinson's-related motor monitoring. Two layers: **Layer 1** population comparison (RF/TabPFN on harmonized Tappy + neuroQWERTY) and **Layer 2** personal drift (CUSUM/EWMA + Isolation Forest). Never a diagnosis — flags unusual/changing patterns and recommends clinician follow-up.

Live repo: https://github.com/riddhibantia/parkinson-app

## Quick start

```bash
flutter pub get
flutter run -d windows   # or macos / linux
# functions (offline pipeline + tests):
cd functions && pip install -r requirements.txt && pytest -q
```

## Project layout
- `lib/` — Flutter desktop app (Riverpod, GoRouter, Firebase Auth/Firestore, fl_chart)
- `functions/` — Firebase Cloud Functions 2nd gen (Python): `main.py` thin handlers, `services/pipeline.py` single analysis path, `services/*` per concern, `models/` train scripts + `experiments/` frozen artifacts
- `doc/implementation_plan_parkinson_personalized_v6 (3).md` — source-of-truth plan (stages 1-10)

## Firebase setup
1. `flutterfire configure` (already configured for `parkinson-app-rbt` — regenerate if needed).
2. Enable **Auth** (Email/Password + Google) and **Firestore**.
3. `firebase deploy --only firestore:rules,storage` — rules are owner-only per `users/{uid}`.
4. Storage `anomaly_models/{uid}/isolation_forest.joblib` — owner-only.

### Why no Storage click needed for Firestore
Firestore works as soon as the Firestore API/database is enabled. Storage is only for per-user Isolation Forest blobs.

## Cloud Functions
```bash
firebase deploy --only functions   # requires Blaze
```
- `submit_session` (callable) — validates + persists one session.
- `run_analysis` (trigger `users/{uid}/sessions/{id}`) — sole analysis path via `services/pipeline.py`.
- `fill_shap_explanation` (trigger `users/{uid}/results/{id}`) — async SHAP top-contributors when `shap_status == pending`; degrades to `unavailable` if shap/artifact missing.
- `get_dashboard` / `reset_baseline` — callables.

Heavy training deps (`torch`, `tabpfn`) are **not** in `functions/requirements.txt` (size + Colab-GPU workflow). SHAP is deferred — missing at runtime just marks `shap_status=unavailable`.

## Demo without waiting 21 days
```bash
python -m scripts.seed_demo   # prints synthetic sessions
# Use the provided helpers to write them to Firestore for a demo user,
# or let the local SharedPreferences buffer drive the dashboard.
```

## Tests
```bash
flutter analyze lib test   # 0 issues
flutter test               # 34 passed (dashboard mapping, streak, widget smoke, etc.)
pytest functions/tests -q  # 57 passed
```

## Sensitive paths (excluded from git)
Raw datasets (`keystrokes/`, `users/`, `nq/`), `*.joblib`, `colab_bundle.zip` — documented downloads / regenerable via `functions/models/run_*.py` (RF ~15s; TabPFN needs pinned env; finetune is Colab).
`lib/firebase_options.dart` **is tracked** — public client keys, app won't run without it.

## Deployment checklist
- [ ] Firebase console: create/enable Firestore (Native mode), Auth, Storage.
- [ ] Upgrade to **Blaze** only if you need to deploy/share Cloud Functions (emulator works without it).
- [ ] `firebase deploy --only firestore:rules,storage,functions` when ready.
- [ ] Remove any probe docs with `firebase firestore:delete` if they appear in dev.
- [ ] Google OAuth: add OAuth consent screen + SHA if using Google sign-in on mobile targets.
