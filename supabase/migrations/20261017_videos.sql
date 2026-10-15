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
