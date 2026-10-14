-- Subject cards (memory step 4): one card per subject that grows over time.
-- Approved by Roger (Oct 13, 2026): updates to a kept subject happen on their own, with Undo.
-- Purely additive: one new table, one new nullable column on notes.

create table if not exists public.subjects (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 80),      -- "Sunrise Loaf bakery"
  goal        text check (char_length(goal) <= 200),                          -- "Open in May"
  next_step   text check (char_length(next_step) <= 200),                     -- "Pick the name font"
  decisions   jsonb not null default '[]'::jsonb,                             -- [{ "text": "Logo: Warm Morning", "at": "2026-10-13" }]
  status      text not null default 'active' check (status in ('active', 'done')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.subjects enable row level security;
drop policy if exists "Own rows only" on public.subjects;
create policy "Own rows only" on public.subjects
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index if not exists subjects_active on public.subjects (user_id, status, updated_at desc);
-- No duplicates: one active subject per title, per person.
create unique index if not exists subjects_one_active_title on public.subjects (user_id, lower(title)) where status = 'active';

-- Each note can point to its subject (empty for loose notes).
alter table public.notes add column if not exists subject_id uuid references public.subjects(id) on delete set null;
create index if not exists notes_by_subject on public.notes (subject_id);
