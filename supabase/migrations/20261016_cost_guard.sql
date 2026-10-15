-- Cost guard: count what each person (and everyone together) costs per day,
-- so one heavy user or a bug can't run up a surprise bill.
-- Only the brain (service role) can read or write these numbers. Nothing existing is changed.

create table if not exists public.usage_daily (
  user_id     uuid not null references auth.users(id) on delete cascade,
  day         date not null,
  requests    integer not null default 0,
  cost_micros bigint  not null default 0,   -- millionths of a dollar
  primary key (user_id, day)
);

create table if not exists public.usage_global (
  day         date primary key,
  requests    integer not null default 0,
  cost_micros bigint  not null default 0
);

alter table public.usage_daily  enable row level security;
alter table public.usage_global enable row level security;

-- People can see their own usage (read only). No one can write directly.
drop policy if exists "Read own usage" on public.usage_daily;
create policy "Read own usage" on public.usage_daily
  for select to authenticated using (user_id = auth.uid());

-- Today's numbers for one person and for everyone (user may be null).
create or replace function public.usage_today(p_user uuid)
returns table (user_requests integer, user_cost_micros bigint, global_cost_micros bigint)
language sql security definer set search_path = public as $$
  select
    coalesce((select requests    from usage_daily  where user_id = p_user and day = (now() at time zone 'utc')::date), 0),
    coalesce((select cost_micros from usage_daily  where user_id = p_user and day = (now() at time zone 'utc')::date), 0),
    coalesce((select cost_micros from usage_global where day = (now() at time zone 'utc')::date), 0);
$$;

-- Add one reply's cost (user may be null for calls without a signed-in person).
create or replace function public.add_usage(p_user uuid, p_cost_micros bigint)
returns void
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'utc')::date;
begin
  if p_cost_micros < 0 or p_cost_micros > 10000000 then
    raise exception 'cost out of range';
  end if;
  insert into usage_global (day, requests, cost_micros) values (d, 1, p_cost_micros)
    on conflict (day) do update
      set requests = usage_global.requests + 1,
          cost_micros = usage_global.cost_micros + excluded.cost_micros;
  if p_user is not null then
    insert into usage_daily (user_id, day, requests, cost_micros) values (p_user, d, 1, p_cost_micros)
      on conflict (user_id, day) do update
        set requests = usage_daily.requests + 1,
            cost_micros = usage_daily.cost_micros + excluded.cost_micros;
  end if;
end $$;

-- Only the brain may call these (not the app, not the public key).
revoke all on function public.usage_today(uuid) from public, anon, authenticated;
revoke all on function public.add_usage(uuid, bigint) from public, anon, authenticated;
grant execute on function public.usage_today(uuid) to service_role;
grant execute on function public.add_usage(uuid, bigint) to service_role;
