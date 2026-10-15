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
  check (parent_id is null or parent_id <> id),
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

-- No two folders with the same name in the same place.
create unique index if not exists video_folders_unique_name
  on public.video_folders (user_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));
-- Each video is saved once per person (saving it again just moves it).
create unique index if not exists saved_videos_unique_youtube on public.saved_videos (user_id, youtube_id) where youtube_id is not null;
create unique index if not exists saved_videos_unique_made on public.saved_videos (user_id, storage_path) where storage_path is not null;

-- A folder can't be moved inside itself (or inside something inside it).
create or replace function public.video_folders_no_cycle() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.parent_id is not null and exists (
    with recursive up as (
      select id, parent_id, 1 as depth from public.video_folders where id = new.parent_id
      union all
      select f.id, f.parent_id, up.depth + 1 from public.video_folders f join up on f.id = up.parent_id where up.depth < 100
    )
    select 1 from up where id = new.id
  ) then
    raise exception 'A folder can''t go inside itself';
  end if;
  return new;
end $$;

drop trigger if exists video_folders_no_cycle on public.video_folders;
create trigger video_folders_no_cycle before insert or update of parent_id on public.video_folders
  for each row execute function public.video_folders_no_cycle();

alter table public.video_folders enable row level security;
alter table public.saved_videos  enable row level security;

drop policy if exists "Own rows only" on public.video_folders;
create policy "Own rows only" on public.video_folders
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Own rows only" on public.saved_videos;
create policy "Own rows only" on public.saved_videos
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
