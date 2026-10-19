-- Deep Think: how many "think it through" answers (the bigger brain) each person used today.
-- Only the brain (service role) reads or writes it. Adds one column; nothing existing changes.

alter table public.usage_daily add column if not exists deep integer not null default 0;

-- Deep Think answers this person used today (0 if none).
create or replace function public.deep_today(p_user uuid)
returns integer
language sql security definer set search_path = public as $$
  select coalesce((select deep from usage_daily where user_id = p_user and day = (now() at time zone 'utc')::date), 0);
$$;

-- Count one Deep Think answer.
create or replace function public.add_deep(p_user uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'utc')::date;
begin
  insert into usage_daily (user_id, day, deep) values (p_user, d, 1)
    on conflict (user_id, day) do update set deep = usage_daily.deep + 1;
end $$;

revoke all on function public.deep_today(uuid) from public, anon, authenticated;
revoke all on function public.add_deep(uuid) from public, anon, authenticated;
grant execute on function public.deep_today(uuid) to service_role;
grant execute on function public.add_deep(uuid) to service_role;
