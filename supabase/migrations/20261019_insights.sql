-- Insights (Oct 16, 2026): anonymous counts so Northstar Labs can see what people use
-- and what they ask for that Northstar can't do yet.
-- Never anyone's words: a general topic, which features were used, and a short generic
-- name for a missing ability. "who" is a one-way code, not a user id.
-- Only the brain (service role) can write or read this table. Nothing existing is changed.

create table if not exists public.insight_events (
  id        bigint generated always as identity primary key,
  at        timestamptz not null default now(),
  who       text,                                   -- one-way code (or null)
  features  text[] not null default '{}',           -- e.g. {chat}, {concierge,places}
  topic     text not null default 'other' check (char_length(topic) <= 20),
  unmet     text check (char_length(unmet) <= 40), -- e.g. 'book a table' (or null)
  failed    boolean not null default false,
  ms        integer not null default 0
);

alter table public.insight_events enable row level security;
-- No policies: the app and the public key can't see or change anything here.

create index if not exists insight_events_at on public.insight_events (at desc);

-- Keep it small: anything older than 180 days can be removed by the report function.
