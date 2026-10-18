-- Tester feedback (Settings › Feedback). Anonymous: no user id, no name, no email is stored.
-- Only the northstar-feedback function writes here (service role), and only admins read it
-- through northstar-insights. Nobody can read or write this table directly.

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  rating int check (rating between 1 and 5),
  kind text not null default 'general' check (kind in ('general', 'idea', 'problem')),
  message text not null check (char_length(message) between 1 and 2000),
  app_version text check (char_length(app_version) <= 20)
);

alter table public.feedback enable row level security;
-- No policies on purpose: only the service role (the functions) can use this table.

create index if not exists feedback_created_at on public.feedback (created_at desc);
