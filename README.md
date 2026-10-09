# ParkinTrace — Keystroke-Dynamics Based Parkinson's Screening & Longitudinal Monitoring System

> **Academic Research Project** — Submitted in partial fulfillment of degree requirements.
> This repository is maintained for academic evaluation and demonstration purposes. It is **not** an open-source product and is **not licensed for public distribution or commercial use**.
>
> **Research aid — not a medical device.** All outputs are research signals, never a diagnosis.

## Current stack: Next.js + Supabase + FastAPI

The Next.js app is the repo root; backend, database and research live beside it:

| Part | Path | Tech |
|---|---|---|
| Web client | `src/`, `public/` (this root) | Next.js 16 (App Router), React 19, Tailwind 4, Supabase SSR |
| Analysis API | `backend/` | FastAPI, Python 3.10.11, scikit-learn 1.6.1 (frozen RF) |
| Database | `supabase/` | Postgres + owner-only RLS (`0001_core.sql`), private `raw-sessions` bucket |
| Research provenance | `research/` | Read-only pointers, artifact SHA256 |
| Deploy | `render.yaml` | `uvicorn app.main:app` (rootDir `backend/`) |

### Quickstart

```bash
# Backend:
cd backend
pip install -r requirements.txt   # pins scikit-learn==1.6.1 (artifact compat)
pytest -q                         # 26 passed
uvicorn app.main:app --reload     # /api/v1/health reports RF artifact status (fail-closed)

# Frontend (repo root):
npm install
cp .env.example .env.local        # set NEXT_PUBLIC_SUPABASE_URL / ANON_KEY / API_URL
npm run dev                       # http://localhost:3000
npm test                          # vitest, 15 passed
npx playwright test               # 10 local passed, 4 cloud skip without PLAYWRIGHT_CLOUD
npm run build
```

### Rules enforced in code + tests

- Timing: `KeyboardEvent.timeStamp` only (monotonic ms). No `Date.now()`.
- Units: milliseconds end-to-end (matches FastAPI canonical contract).
- No practice session; first session is real measurement.
- Exact session ids (`crypto.randomUUID`, one per lifecycle); missing id →
  "Session not found", never another session.
- Charts render real rows only; insufficient data → honest message.
- No diagnostic language; internal model signals never rendered as diagnosis.
- Typed content is dropped after capture; only timing + hand persist.

Without Supabase/API keys the app runs honestly degraded: capture + on-device preview work; auth/analysis/persistence show "not configured" states. Signed-out visitors always get analysis-only + local snapshot (never a placeholder-user write).

The frozen Layer 1 model (`functions/models/experiments/rf/model_full.joblib`, git-ignored, ~15 s to regenerate via the archive branch) and scaler (`live_scaler.json`, tracked) resolve by default relative to the repo root; override with `PARKINTRACE_RF_ARTIFACT` / `PARKINTRACE_RF_SCALER`. Missing artifact → `/health` reports `degraded` and live inference stays disabled. Nothing is ever substituted or fabricated.

Migration history (order log, backend steps 1–9) is preserved in `doc/migration.md`.

## Legacy app (archived)

The original Flutter desktop + Firebase client is frozen on branch **`archive/flutter-firebase`** (includes the Geist design-system overhaul). It is no longer developed. Supabase (`profiles` / `sessions` / `session_metrics` / `baselines`) is the database of record — see `supabase/README.md` for the RLS self-test checklist.

## Licence & Use

© 2026 Riddhi Bantia. **All rights reserved.** Shared solely for **academic evaluation and demonstration**. No licence is granted for reproduction, distribution, or commercial use. Contact the author for evaluation queries.
