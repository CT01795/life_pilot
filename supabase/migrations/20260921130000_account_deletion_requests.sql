begin;

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references auth.users(id),
  admin_note text
);

create index if not exists account_deletion_requests_status_idx
  on public.account_deletion_requests(status, requested_at desc);

alter table public.account_deletion_requests enable row level security;

drop policy if exists account_deletion_requests_insert_own on public.account_deletion_requests;
create policy account_deletion_requests_insert_own on public.account_deletion_requests
  for insert to authenticated
  with check (user_id = auth.uid() and lower(trim(email)) = public.life_pilot_user_email());

drop policy if exists account_deletion_requests_select_participant on public.account_deletion_requests;
create policy account_deletion_requests_select_participant on public.account_deletion_requests
  for select to authenticated
  using (user_id = auth.uid() or public.life_pilot_is_admin());

create or replace function public.request_account_deletion()
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  request_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if exists (
    select 1 from public.account_deletion_requests
    where user_id = auth.uid() and status = 'pending'
  ) then raise exception 'deletion_request_already_pending'; end if;
  insert into public.account_deletion_requests(user_id, email)
  values (auth.uid(), public.life_pilot_user_email())
  returning id into request_id;
  return request_id;
end;
$function$;

create or replace function public.admin_list_account_deletion_requests()
returns setof public.account_deletion_requests
language sql
security definer
set search_path = ''
as $function$
  select * from public.account_deletion_requests
  where public.life_pilot_is_admin()
  order by requested_at desc;
$function$;

create or replace function public.admin_delete_account_and_data(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target public.account_deletion_requests;
begin
  if not public.life_pilot_is_admin() then raise exception 'admin_required'; end if;
  select * into target from public.account_deletion_requests
  where id = p_request_id and status = 'pending' for update;
  if not found then raise exception 'deletion_request_not_found'; end if;

  perform public.cleanup_subscription_data(target.email, 'all');
  delete from public.feedback where lower(trim(created_by)) = lower(trim(target.email));
  delete from public.dashboard_setting where lower(trim(account)) = lower(trim(target.email));
  delete from public.user_module where lower(trim(account)) = lower(trim(target.email));
  delete from public.recommended_events_favor where lower(trim(account)) = lower(trim(target.email));
  delete from public.recommended_events_stat where lower(trim(account)) = lower(trim(target.email));
  delete from public.legal_consents where user_id = target.user_id;
  delete from public.user_subscriptions where user_id = target.user_id;
  delete from auth.users where id = target.user_id;

  update public.account_deletion_requests
  set status = 'approved', processed_at = now(), processed_by = auth.uid()
  where id = p_request_id;
end;
$function$;

revoke all on function public.request_account_deletion() from public, anon;
grant execute on function public.request_account_deletion() to authenticated;
revoke all on function public.admin_list_account_deletion_requests() from public, anon;
grant execute on function public.admin_list_account_deletion_requests() to authenticated;
revoke all on function public.admin_delete_account_and_data(uuid) from public, anon;
grant execute on function public.admin_delete_account_and_data(uuid) to authenticated;

commit;
