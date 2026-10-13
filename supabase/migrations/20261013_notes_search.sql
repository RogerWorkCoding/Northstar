-- Notes + Search (Oct 13, 2026)
-- Notes are one-liners Northstar keeps from chats so you can find them later.
-- Never feelings or health, never when memory is off. Only the owner can see them.
-- Search finds a note by its words OR by its meaning ("cake shop" finds "bakery").
-- Purely additive: no existing table is changed.

-- Meaning search needs vectors (pgvector).
create extension if not exists vector with schema extensions;

create table if not exists public.notes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  text        text not null check (char_length(text) between 1 and 300),  -- the one-liner, in their words
  context     text check (char_length(context) <= 400),                   -- what Northstar answered (short)
  subject     text check (char_length(subject) <= 120),                   -- the goal it belongs to, if any
  embedding   extensions.vector(384),                                      -- meaning (gte-small)
  fts         tsvector generated always as (
                to_tsvector('english', text || ' ' || coalesce(subject, ''))
              ) stored,                                                   -- words
  created_at  timestamptz not null default now()
);

-- Only the owner, always.
alter table public.notes enable row level security;
drop policy if exists "Own rows only" on public.notes;
create policy "Own rows only" on public.notes
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- No duplicates: the same line is kept once per person.
create unique index if not exists notes_no_duplicates on public.notes (user_id, md5(lower(text)));
create index if not exists notes_recent on public.notes (user_id, created_at desc);
create index if not exists notes_words on public.notes using gin (fts);
create index if not exists notes_meaning on public.notes using hnsw (embedding extensions.vector_cosine_ops);

-- Search by words and meaning together, best matches first.
-- Runs as the person calling it, so row-level security still applies.
create or replace function public.search_notes(
  query_text text,
  query_embedding extensions.vector(384),
  match_count int default 20,
  max_distance float default 0.2
)
returns table (id uuid, text text, context text, subject text, created_at timestamptz, score float)
language sql stable security invoker
set search_path = public, extensions
as $$
  with q as (
    -- any of the words, not all of them
    select nullif(replace(plainto_tsquery('english', query_text)::text, '&', '|'), '')::tsquery as tsq
  ),
  by_meaning as (
    select n.id, row_number() over (order by n.embedding <=> query_embedding) as rank
    from public.notes n
    where query_embedding is not null
      and n.embedding is not null
      and (n.embedding <=> query_embedding) < max_distance
    order by n.embedding <=> query_embedding
    limit 50
  ),
  by_words as (
    select n.id, row_number() over (order by ts_rank_cd(n.fts, q.tsq) desc) as rank
    from public.notes n, q
    where q.tsq is not null and n.fts @@ q.tsq
    limit 50
  ),
  fused as (
    -- Reciprocal rank fusion: good in both lists = best.
    select coalesce(m.id, w.id) as id,
           coalesce(1.0 / (60 + m.rank), 0) + coalesce(1.0 / (60 + w.rank), 0) as score
    from by_meaning m
    full outer join by_words w on m.id = w.id
  )
  select n.id, n.text, n.context, n.subject, n.created_at, f.score::float
  from fused f
  join public.notes n on n.id = f.id
  order by f.score desc, n.created_at desc
  limit least(match_count, 50);
$$;

revoke all on function public.search_notes(text, extensions.vector, int, float) from public, anon;
grant execute on function public.search_notes(text, extensions.vector, int, float) to authenticated;
