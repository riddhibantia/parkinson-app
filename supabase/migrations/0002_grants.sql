-- ParkinTrace grants for Data API roles (spec 17/18 companion to 0001).
-- RLS policies in 0001 remain the real protection (owner-only via
-- auth.uid()); these GRANTs only let the API roles REACH the tables —
-- every row is still filtered by RLS. Without these, supabase-js gets
-- permission errors even when RLS would allow the row.

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.sessions to authenticated;
grant select, insert, update, delete on public.session_metrics to authenticated;
grant select, insert, update, delete on public.baselines to authenticated;

-- No grants to anon: unauthenticated users must see nothing (spec Phase 2).
