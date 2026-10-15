-- Videos: Northstar makes short clips with Google Veo from shot cards.
-- Each clip is a job (working → done or failed). The finished video is kept in private
-- storage under the person's own folder. Only the brain writes; people read only their own.
-- Nothing existing is changed.

create table if not exists public.video_jobs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  prompt       text not null check (char_length(prompt) between 1 and 1200),
  seconds      integer not null check (seconds in (4, 6, 8)),
  status       text not null default 'working' check (status in ('working', 'done', 'failed')),
  operation    text,
  storage_path text,
  error        text,
  cost_micros  bigint not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists video_jobs_user_day on public.video_jobs (user_id, created_at desc);

alter table public.video_jobs enable row level security;

drop policy if exists "Read own videos" on public.video_jobs;
create policy "Read own videos" on public.video_jobs
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "Delete own videos" on public.video_jobs;
create policy "Delete own videos" on public.video_jobs
  for delete to authenticated using (user_id = auth.uid());

-- Clips made today are counted here too, so deleting videos doesn't reset the daily limit.
alter table public.usage_daily add column if not exists videos integer not null default 0;

-- Check the limits and reserve the clip in one step (one at a time per person), before Google
-- is called. Returns the new job id, or raises 'limit:videos' / 'limit:budget'.
create or replace function public.reserve_video(
  p_user uuid, p_prompt text, p_seconds integer, p_cost_micros bigint,
  p_max_videos integer, p_user_cap_micros bigint, p_global_cap_micros bigint)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  d date := (now() at time zone 'utc')::date;
  used_videos integer;
  used_user bigint;
  used_global bigint;
  job uuid;
begin
  perform pg_advisory_xact_lock(hashtext('video:' || p_user::text));
  select coalesce(videos, 0), coalesce(cost_micros, 0) into used_videos, used_user
    from usage_daily where user_id = p_user and day = d;
  select coalesce(cost_micros, 0) into used_global from usage_global where day = d;
  if coalesce(used_videos, 0) >= p_max_videos then raise exception 'limit:videos'; end if;
  if coalesce(used_user, 0) + p_cost_micros > p_user_cap_micros
     or coalesce(used_global, 0) + p_cost_micros > p_global_cap_micros then
    raise exception 'limit:budget';
  end if;
  insert into video_jobs (user_id, prompt, seconds, cost_micros)
    values (p_user, p_prompt, p_seconds, p_cost_micros) returning id into job;
  perform add_usage(p_user, p_cost_micros);
  update usage_daily set videos = videos + 1 where user_id = p_user and day = d;
  return job;
end $$;

-- Google refused to start: give the clip and its cost back.
create or replace function public.release_video(p_job uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare j video_jobs; d date;
begin
  select * into j from video_jobs where id = p_job and status = 'working' and operation is null;
  if not found then return; end if;
  d := (j.created_at at time zone 'utc')::date;
  update usage_daily set videos = greatest(videos - 1, 0), cost_micros = greatest(cost_micros - j.cost_micros, 0),
    requests = greatest(requests - 1, 0) where user_id = j.user_id and day = d;
  update usage_global set cost_micros = greatest(cost_micros - j.cost_micros, 0),
    requests = greatest(requests - 1, 0) where day = d;
  update video_jobs set status = 'failed', error = 'Google couldn''t start this video.', updated_at = now() where id = p_job;
end $$;

revoke all on function public.reserve_video(uuid, text, integer, bigint, integer, bigint, bigint) from public, anon, authenticated;
revoke all on function public.release_video(uuid) from public, anon, authenticated;
grant execute on function public.reserve_video(uuid, text, integer, bigint, integer, bigint, bigint) to service_role;
grant execute on function public.release_video(uuid) to service_role;

-- Private bucket for finished clips (50 MB max each, mp4 only).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('videos', 'videos', false, 52428800, array['video/mp4'])
on conflict (id) do nothing;

-- People can read and delete only files in their own folder: videos/<their id>/...
drop policy if exists "Own video files: read" on storage.objects;
create policy "Own video files: read" on storage.objects
  for select to authenticated
  using (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Own video files: delete" on storage.objects;
create policy "Own video files: delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);
