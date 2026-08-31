begin;

alter table public.business_plan
  add column if not exists status text not null default 'not_started';
alter table public.business_plan
  drop constraint if exists business_plan_status_check;
alter table public.business_plan
  add constraint business_plan_status_check
  check (status in ('not_started', 'in_progress', 'completed'));

alter table public.feedback
  add column if not exists status text not null default 'pending';
update public.feedback
set status = case when coalesce(is_ok, false) then 'completed' else 'pending' end;
alter table public.feedback
  drop constraint if exists feedback_status_check;
alter table public.feedback
  add constraint feedback_status_check
  check (status in ('pending', 'in_progress', 'completed'));

create index if not exists business_plan_owner_status_created_idx
  on public.business_plan (created_by, status, created_at desc);
create index if not exists feedback_status_created_idx
  on public.feedback (status, created_at desc);

commit;
