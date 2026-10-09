-- ParkinTrace RLS self-test, part 1 of 2 (run in the Supabase SQL editor).
-- Verifies owner-only isolation per spec Phase 2 WITHOUT weakening
-- production security:
--   * ALL functions/tables are created as postgres BEFORE any role switch.
--     Nothing is created as `authenticated` (which has no CREATE on
--     public, by design — that 42501 denial is correct behavior).
--   * Fixture logins are genuine auth.users rows (never dangling FKs),
--     deleted at the end, leaving no trace.
--   * RLS policies, foreign keys, and grants are NOT touched by this file.
--
-- How to run: CLOSE all other query tabs, open ONE new query, paste the
-- whole file, execute. The first result must read 'SELFTEST v6'.
-- Checks 1–5 must each read 'PASS'. Then run part 2
-- (rls_selftest_anon.sql) for check 6.
select 'SELFTEST v6' as version;

-- ============ 0. cleanup any previous run (as postgres) ============
delete from auth.users where id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

-- ============ 0a. ensure API roles can reach the tables (as postgres) ============
-- Same grants as migration 0002. RLS policies remain the real protection;
-- without these, reads fail with 42501 before RLS is ever evaluated.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.sessions to authenticated;
grant select, insert, update, delete on public.session_metrics to authenticated;
grant select, insert, update, delete on public.baselines to authenticated;

-- ============ 0b. ensure the auth instance row exists (as postgres) ============
-- Fresh projects can have an empty auth.instances table until the first
-- real signup; fixture logins need a parent row, so create one if absent.
insert into auth.instances (id, uuid, raw_base_config, created_at, updated_at)
select gen_random_uuid(), gen_random_uuid(), '{}', now(), now()
where not exists (select 1 from auth.instances);

-- ============ 1. fixture logins: REAL auth.users rows (as postgres) ============
-- Genuine rows satisfying profiles_id_fkey / sessions_user_id_fkey —
-- never dangling references. Deleted in the cleanup section below.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
select i.id, '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated',
       'rls-test-a@example.com', '', now(), now(), now(), '{}', '{}'
from auth.instances i limit 1;
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
select i.id, '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated',
       'rls-test-b@example.com', '', now(), now(), now(), '{}', '{}'
from auth.instances i limit 1;

-- ============ 2. fixture app rows (as postgres) ============
insert into public.profiles (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222');

insert into public.sessions (id, user_id, started_at, ended_at, session_type, device_id)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', now() - interval '2 hours', now() - interval '1 hour', 'structured', 'kbd-a'),
       ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', now() - interval '2 hours', now() - interval '1 hour', 'structured', 'kbd-b');

delete from public.sessions where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

-- ============ 3. helper functions (as postgres, BEFORE any SET ROLE) ============
-- Creating these here is the whole point: `authenticated` has no CREATE
-- privilege on public, so any DDL after SET ROLE correctly fails.
create or replace function parkintrace_test_act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid::text)::text, true);
$$;
create or replace function parkintrace_test_clear() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
$$;
-- A blocked write raises 42501, which would abort plain SQL — the function
-- converts outcomes instead: blocked = PASS, written = FAIL.
create or replace function parkintrace_test_cannot_write_b() returns text language plpgsql as $$
begin
  insert into public.sessions (id, user_id, started_at, ended_at, session_type, device_id)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', now(), now(), 'structured', 'kbd-x');
  return 'FAIL';
exception when insufficient_privilege then
  return 'PASS';
end $$;

-- ============ 4. checks 1–5 as User A (DML only, no DDL past this point) ============
set role authenticated;
select parkintrace_test_act_as('11111111-1111-1111-1111-111111111111');

-- Check 1: User A reads only A's rows.
select case when (select count(*) from public.sessions) = 1
             and (select count(*) from public.sessions where user_id = '11111111-1111-1111-1111-111111111111') = 1
            then 'PASS' else 'FAIL' end as expect_a_reads_only_a;
select case when (select count(*) from public.profiles) = 1 then 'PASS' else 'FAIL' end as expect_a_profile_only_a;

-- Check 2: User A cannot read User B's exact session.
select case when (select count(*) from public.sessions where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') = 0
            then 'PASS' else 'FAIL' end as expect_a_cannot_read_b_session;

-- Check 3: User A cannot insert as User B.
select parkintrace_test_cannot_write_b() as expect_a_cannot_write_b;

-- Check 4: User A CAN write own rows.
insert into public.sessions (id, user_id, started_at, ended_at, session_type, device_id)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', now(), now(), 'free', 'kbd-a')
on conflict do nothing;
select case when (select count(*) from public.sessions where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') = 1
            then 'PASS' else 'FAIL' end as expect_a_can_write_a;

-- Check 5: session_metrics remain owner-isolated.
insert into public.session_metrics (session_id, user_id, features)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', '{"ht_mean": 100}'::jsonb)
on conflict do nothing;
select case when (select count(*) from public.session_metrics) >= 1
             and (select count(*) from public.session_metrics where user_id = '22222222-2222-2222-2222-222222222222') = 0
            then 'PASS' else 'FAIL' end as expect_a_metrics_only_a;

-- ============ 5. cleanup: leave no trace (back as postgres) ============
reset role;
select parkintrace_test_clear();
drop function if exists parkintrace_test_act_as(uuid);
drop function if exists parkintrace_test_clear();
drop function if exists parkintrace_test_cannot_write_b();
delete from auth.users where id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

-- Check 6 (anon) lives in rls_selftest_anon.sql — run it separately.
select 'PART 1 COMPLETE — now run rls_selftest_anon.sql for check 6' as next_step;
