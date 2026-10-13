-- Northstar: lock each table so people only see their own rows.
-- Run once in Supabase → SQL Editor.

-- 1. Back up the current test rows (kept outside the app's reach).
create schema if not exists backup_20261012;
create table if not exists backup_20261012.identities as table public.identities;
create table if not exists backup_20261012.projects   as table public.projects;
create table if not exists backup_20261012.decisions  as table public.decisions;
create table if not exists backup_20261012.memories   as table public.memories;

-- 2. Add an owner to every table. New rows get the signed-in person automatically.
alter table public.identities add column if not exists user_id uuid default auth.uid() references auth.users(id) on delete cascade;
alter table public.projects   add column if not exists user_id uuid default auth.uid() references auth.users(id) on delete cascade;
alter table public.decisions  add column if not exists user_id uuid default auth.uid() references auth.users(id) on delete cascade;
alter table public.memories   add column if not exists user_id uuid default auth.uid() references auth.users(id) on delete cascade;

-- 3. Remove the old "anyone can do anything" development rules.
drop policy if exists "Development memory delete" on public.memories;
drop policy if exists "Development memory insert" on public.memories;
drop policy if exists "Development memory select" on public.memories;

-- 4. Turn the locks on.
alter table public.identities enable row level security;
alter table public.projects   enable row level security;
alter table public.decisions  enable row level security;
alter table public.memories   enable row level security;

-- 5. One rule per table: you can only see and change your own rows.
create policy "Own rows only" on public.identities for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Own rows only" on public.projects for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Own rows only" on public.decisions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Own rows only" on public.memories for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
