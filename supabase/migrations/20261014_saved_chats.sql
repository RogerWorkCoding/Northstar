-- Saved chats (Oct 13, 2026): chats are kept so History can list them and a
-- search result can open the chat it came from. Only the owner can see them.
-- Never kept when memory is off (the app doesn't save them then).
-- Additive: two new tables, one new nullable column on notes, and the search
-- function now also returns which chat a note came from.

create table if not exists public.chats (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 80),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  chat_id     uuid not null references public.chats(id) on delete cascade,
  role        text not null check (role in ('user', 'assistant')),
  content     text not null check (char_length(content) between 1 and 8000),
  created_at  timestamptz not null default now()
);

alter table public.chats enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists "Own rows only" on public.chats;
create policy "Own rows only" on public.chats
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Own rows only" on public.chat_messages;
create policy "Own rows only" on public.chat_messages
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create index if not exists chats_recent on public.chats (user_id, updated_at desc);
create index if not exists chat_messages_in_order on public.chat_messages (chat_id, created_at);

-- Each note remembers the chat it came from (empty for older notes).
alter table public.notes add column if not exists chat_id uuid references public.chats(id) on delete set null;

-- Search now also returns chat_id, so a result can open its chat.
-- (The return type changes, so the old function is replaced.)
drop function if exists public.search_notes(text, extensions.vector, int, float);
create or replace function public.search_notes(
  query_text text,
  query_embedding extensions.vector(384),
  match_count int default 20,
  max_distance float default 0.2
)
returns table (id uuid, text text, context text, subject text, created_at timestamptz, score float, chat_id uuid)
language sql stable security invoker
set search_path = public, extensions
as $$
  with q as (
    select nullif(replace(plainto_tsquery('english', query_text)::text, '&', '|'), '')::tsquery as tsq
  ),
  by_meaning as (
    select n.id, row_number() over (order by n.embedding <=> query_embedding) as rank
    from public.notes n
    where query_embedding is not null
      and n.user_id = auth.uid()
      and n.embedding is not null
      and (n.embedding <=> query_embedding) < max_distance
    order by n.embedding <=> query_embedding
    limit 50
  ),
  by_words as (
    select n.id, row_number() over (order by ts_rank_cd(n.fts, q.tsq) desc) as rank
    from public.notes n, q
    where q.tsq is not null and n.user_id = auth.uid() and n.fts @@ q.tsq
    limit 50
  ),
  fused as (
    select coalesce(m.id, w.id) as id,
           coalesce(1.0 / (60 + m.rank), 0) + coalesce(1.0 / (60 + w.rank), 0) as score
    from by_meaning m
    full outer join by_words w on m.id = w.id
  )
  select n.id, n.text, n.context, n.subject, n.created_at, f.score::float, n.chat_id
  from fused f
  join public.notes n on n.id = f.id
  order by f.score desc, n.created_at desc
  limit least(match_count, 50);
$$;

revoke all on function public.search_notes(text, extensions.vector, int, float) from public, anon;
grant execute on function public.search_notes(text, extensions.vector, int, float) to authenticated;
