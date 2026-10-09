-- ParkinTrace RLS self-test, part 2 of 2: check 6 (anon).
-- Run AFTER part 1, in its own fresh query tab.
--
-- WHY A SEPARATE STEP: `anon` deliberately holds no USAGE/SELECT grants on
-- the private tables, so any read attempt raises error 42501 instead of
-- returning rows. That denial IS the proof — but a mid-script error would
-- abort part 1's reporting, so this check stands alone.
--
-- How to run: paste the WHOLE file into a fresh query and execute.
--
--   PASS if either happens:
--     a) ERROR 42501 "permission denied ..." — the stranger is blocked
--        before reading anything, or
--     b) a row count of 0 — the stranger reached the table but RLS
--        filtered every row (default-deny: no policy grants anon access).
--   FAIL only if the count is greater than 0. If you see rows,
--   stop and report it — do NOT weaken anything yourself.

set role anon;
select count(*) from public.sessions;
