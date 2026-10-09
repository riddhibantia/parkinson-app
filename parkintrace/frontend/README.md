# ParkinTrace frontend (Next.js 16 App Router)

Browser-first typing screening & monitoring. Research aid — not a device.

## Run

```bash
npm install
npm run dev        # http://localhost:3000
npm run build
```

Configure backend access via `.env.local` (see `.env.example`):
`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_API_URL`.
Without them the app runs honestly degraded: auth/analysis/persistence
show "not configured" states; capture + on-device preview still work.

## Rules enforced in code + tests

- Timing: `KeyboardEvent.timeStamp` only (monotonic ms). No `Date.now()`.
- Units: milliseconds end-to-end (matches FastAPI canonical contract).
- No practice session; first session is real measurement.
- Exact session ids (`crypto.randomUUID`, one per lifecycle); missing id →
  "Session not found", never another session.
- Charts render real rows only; insufficient data → honest message.
- No diagnostic language; internal model signals never rendered as diagnosis.
- Typed content is dropped after capture; only timing + hand persist.

## Tests

- `npm test` — Vitest (feature math + static legacy-pattern guards)
- `npm run test:e2e` — Playwright, real Chrome (port 3111, no creds needed
  for the 7 local tests; 4 cloud tests skip without Supabase + FastAPI)
- `npm run typecheck`, `npm run build`

## Tested versions (2026-09-29)

Node v24.14.0, npm 11.18.0, next 16.3.7, react 19.2.8, zustand 5.0.15,
zod 4.6.5, recharts 3.10.1, vitest 3.2.7, @playwright/test 1.63.0,
@supabase/supabase-js 2.117.2, react-hook-form 7.89.0.
Locked via `package-lock.json`.
