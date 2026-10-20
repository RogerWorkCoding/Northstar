-- Northstar Navigator, Levels 2 and 3 (read one file with an OK; drafts the person approves).
-- See docs/navigator-levels-2-3.md. Adds two waiting states and the person's choice.
--   needs_ok  waiting for the person: which file to read / attach, or "add this event?"
--   approved  the person said OK; the Mac picks it up again to finish
alter table public.navigator_tasks drop constraint if exists navigator_tasks_status_check;
alter table public.navigator_tasks add constraint navigator_tasks_status_check
  check (status in ('queued', 'running', 'needs_ok', 'approved', 'done', 'failed', 'stopped'));

-- What the person picked: { index, name } of the file to read or attach (name null = no attachment).
alter table public.navigator_tasks add column if not exists choice jsonb;

create index if not exists navigator_tasks_ready on public.navigator_tasks (user_id, status, created_at)
  where status in ('queued', 'approved');
