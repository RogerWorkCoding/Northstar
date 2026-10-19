-- Northstar Navigator, step 1 ("find my files", look only). See docs/navigator-step1.md.
-- Only the northstar-navigator function (service role) uses these tables. Row level security is on
-- with no policies on purpose: nobody can read or write them directly, from the app or the Mac.

-- A Mac linked to a person. The Mac keeps its device key; here we keep only its SHA-256 fingerprint.
create table if not exists public.navigator_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default 'Mac' check (char_length(name) <= 60),
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_seen timestamptz,
  revoked_at timestamptz
);

-- Short pairing codes shown on the iPhone, good for 10 minutes, used once.
create table if not exists public.navigator_pairing (
  code text primary key check (char_length(code) between 6 and 12),
  user_id uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz
);

-- One request from the iPhone and what happened to it.
create table if not exists public.navigator_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  device_id uuid references public.navigator_devices (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  request text not null check (char_length(request) between 1 and 500),
  status text not null default 'queued'
    check (status in ('queued', 'running', 'done', 'failed', 'stopped')),
  plan jsonb,
  result jsonb,
  error text check (char_length(error) <= 300)
);

-- The record ("What Navigator did"): one entry per event, each carrying the fingerprint of the one
-- before it for the same person, so a changed or missing entry is visible. Written only by the function.
create table if not exists public.navigator_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid references public.navigator_tasks (id) on delete cascade,
  at timestamptz not null default now(),
  actor text not null check (actor in ('iphone', 'brain', 'mac')),
  kind text not null check (char_length(kind) <= 40),
  detail jsonb not null default '{}'::jsonb,
  prev_hash text,
  hash text not null
);

alter table public.navigator_devices enable row level security;
alter table public.navigator_pairing enable row level security;
alter table public.navigator_tasks enable row level security;
alter table public.navigator_events enable row level security;

create index if not exists navigator_tasks_user_created on public.navigator_tasks (user_id, created_at desc);
create index if not exists navigator_tasks_queued on public.navigator_tasks (user_id, status, created_at)
  where status = 'queued';
create index if not exists navigator_events_user on public.navigator_events (user_id, id desc);
create index if not exists navigator_events_task on public.navigator_events (task_id, id);
