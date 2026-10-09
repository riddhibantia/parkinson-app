# ParkinTrace (migration target — Next.js + Supabase + FastAPI)

Authoritative spec: the MASTER MIGRATION & IMPLEMENTATION SPECIFICATION
(typing-pattern screening & longitudinal monitoring; research aid, not a
diagnostic device).

## Layout

- `backend/` — FastAPI + ported validated Python services + pytest
  regression suite. No familiarization, no Firebase, one canonical
  camelCase contract, Layer 1/2 strictly separated.
- `supabase/migrations/0001_core.sql` — profiles / sessions /
  session_metrics / baselines + owner-only RLS + private raw-sessions
  bucket (consented archives only).
- `research/` — read-only provenance copies + artifact pointer (SHA256).
- `frontend/src/` — Next.js App Router target (scaffolded next).

## Migration order (spec 35) — completed so far

1. Repo audit vs spec — done (report in chat 2026-09-29).
2. Python service inventory — done (pipeline, extraction, L1/L2, guards).
3. Artifact verification — RF artifact EXISTS + loads (SHA256 recorded);
   sklearn pin required (1.6.1 vs dev-box 1.7.2).
4. Supabase schema + RLS — done (migration 0001).
5. FastAPI foundation — done (routers, schemas, health fail-closed).
6. Feature extraction + quality port — done (ms-explicit units).
7. Layer 1 port — done (RF-only, no substitution).
8. Layer 2 port — done (gates/thresholds frozen).
9. Canonical contract — done (Pydantic camelCase aliases).

## Not started

10+. Next.js foundation, Supabase Auth wiring, browser capture
(performance.now), Layer UIs, real charts, dashboard, Playwright,
deploy. The legacy Flutter/Firebase app is untouched and remains the
only runnable client until the frontend is built.
