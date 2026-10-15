-- Videos library: the person's own folders (folders inside folders) and the videos they saved:
-- YouTube videos (saved as a link) and videos they made with Northstar (the file in private storage).
-- Own rows only. A folder and a saved video can only point at the same person's folders.
-- Deleting a folder deletes what's inside it. Nothing existing is changed.

create table if not exists public.video_folders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  parent_id   uuid,
  name        text not null check (char_length(name) between 1 and 60),
  created_at  timestamptz not null default now(),
  unique (id, user_id),
  foreign key (parent_id, user_id) references public.video_folders(id, user_id) on delete cascade
);

create table if not exists public.saved_videos (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  folder_id     uuid,
  title         text not null check (char_length(title) between 1 and 200),
  source        text not null check (source in ('youtube', 'made')),
  youtube_id    text check (youtube_id is null or youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  storage_path  text,
  created_at    timestamptz not null default now(),
  -- A made video's file must be in the person's own storage folder.
  check (storage_path is null or storage_path like (user_id::text || '/%')),
  check ((source = 'youtube' and youtube_id is not null) or (source = 'made' and storage_path is not null)),
  foreign key (folder_id, user_id) references public.video_folders(id, user_id) on delete cascade
);

create index if not exists video_folders_user on public.video_folders (user_id, parent_id);
create index if not exists saved_videos_user on public.saved_videos (user_id, folder_id, created_at desc);

alter table public.video_folders enable row level security;
alter table public.saved_videos  enable row level security;

drop policy if exists "Own rows only" on public.video_folders;
create policy "Own rows only" on public.video_folders
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Own rows only" on public.saved_videos;
create policy "Own rows only" on public.saved_videos
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
