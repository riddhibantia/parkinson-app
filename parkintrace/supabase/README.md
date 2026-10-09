# Supabase live integration (Phase 11)

## Apply (once, per project)

```bash
# Link once (needs a Supabase access token — never commit it):
supabase link --project-ref <PROJECT_REF>
supabase db push   # applies supabase/migrations/0001_core.sql
```

## Verify

1. Tables exist: `profiles`, `sessions`, `session_metrics`, `baselines`.
2. RLS enabled on all four (see migration) with owner-only policies.
3. Bucket `raw-sessions` exists, **not public**.
4. Run `supabase/tests/rls_selftest.sql` in the SQL editor — every
   `expect_*` row must read `PASS` (User A ↔ User B isolation, anon
   sees nothing). Any FAIL = stop, do not ship.
5. Manual two-user check: two browsers (or normal + incognito), one
   account each — each sees only its own sessions/history/baseline.

## Status

BLOCKED until project credentials exist on this machine: no
`SUPABASE_URL` / keys found in the workspace (only `.env.example`
placeholders). No policy was weakened; the migration is fail-strict
by construction (owner `auth.uid()` checks on every table).
