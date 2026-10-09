-- ParkinTrace core schema (spec section 18).
-- Canonical session id: sessions.id (uuid, client-generated, single lifecycle).
-- No raw typed content columns anywhere by design (spec section 8/19).
-- Apply with: supabase db push (or supabase migration up).

-- ---------- profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  age int null check (age is null or (age >= 0 and age <= 130)),
  gender text null,
  typing_experience text null check (typing_experience is null or typing_experience in ('regular', 'occasional', 'not_familiar')),
  parkinson_context jsonb not null default '{}'::jsonb,
  onboarding_completed boolean not null default false
);

-- ---------- sessions ----------
create table if not exists public.sessions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  started_at timestamptz not null,
  ended_at timestamptz not null,
  session_type text not null check (session_type in ('structured', 'free', 'motor_task')),
  device_id text not null,
  device_metadata jsonb not null default '{}'::jsonb,
  valid boolean not null default true,
  quality_flags text[] not null default '{}',
  quality_reason text null,
  check (ended_at >= started_at)
);
create index if not exists sessions_user_started_idx on public.sessions (user_id, started_at desc);

-- ---------- session_metrics ----------
create table if not exists public.session_metrics (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references public.sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  features jsonb not null default '{}'::jsonb,
  quality_metrics jsonb not null default '{}'::jsonb,
  layer1_result jsonb null,
  layer2_result jsonb null,
  within_session_series jsonb null,
  created_at timestamptz not null default now()
);
create index if not exists session_metrics_user_idx on public.session_metrics (user_id, created_at desc);

-- ---------- baselines ----------
create table if not exists public.baselines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'building' check (status in ('building', 'established')),
  sample_count int not null default 0,
  distinct_days int not null default 0,
  baseline_start timestamptz null,
  baseline_end timestamptz null,
  anchor_device_id text null,
  baseline_statistics jsonb not null default '{}'::jsonb,
  isolation_forest_artifact_reference text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists baselines_user_idx on public.baselines (user_id, created_at desc);

-- ---------- updated_at trigger ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_baselines_updated on public.baselines;
create trigger trg_baselines_updated before update on public.baselines
  for each row execute function public.set_updated_at();

-- ---------- RLS ----------
alter table public.profiles enable row level security;
alter table public.sessions enable row level security;
alter table public.session_metrics enable row level security;
alter table public.baselines enable row level security;

-- Owner-only policies (authenticated users, own rows only).
drop policy if exists profiles_owner on public.profiles;
create policy profiles_owner on public.profiles
  for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists sessions_owner on public.sessions;
create policy sessions_owner on public.sessions
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists session_metrics_owner on public.session_metrics;
create policy session_metrics_owner on public.session_metrics
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists baselines_owner on public.baselines;
create policy baselines_owner on public.baselines
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- optional raw-archive bucket ----------
-- Private bucket for consented research raw-timing archives only (spec 19).
-- Normal app paths must NOT write here; no public access.
-- Guarded: applies only where the storage schema exists (real Supabase
-- projects); skipped silently on bare Postgres so syntax/apply checks
-- elsewhere in this file are not blocked by a missing extension schema.
do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('raw-sessions', 'raw-sessions', false)
    on conflict (id) do nothing;
  end if;
end $$;

do $$
begin
  if to_regclass('storage.objects') is not null then
    if not exists (select 1 from pg_policies
                   where schemaname = 'storage' and tablename = 'objects'
                   and policyname = 'raw_sessions_owner') then
      create policy raw_sessions_owner on storage.objects
        for all to authenticated
        using (bucket_id = 'raw-sessions' and auth.uid()::text = (storage.foldername(name))[1])
        with check (bucket_id = 'raw-sessions' and auth.uid()::text = (storage.foldername(name))[1]);
    end if;
  end if;
end $$;
