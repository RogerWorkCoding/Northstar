-- Northstar Navigator: "Always allow" switches (Roger, Oct 19). Off unless the person turns one on.
-- { "read": true, "email": false, "event": true, "reminder": false }. Only the function reads or writes it.
create table if not exists public.navigator_permissions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  always jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.navigator_permissions enable row level security;
