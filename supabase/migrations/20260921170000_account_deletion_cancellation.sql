begin;

alter table public.account_deletion_requests
  add column if not exists cancellation_requested_at timestamptz;

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_requests_status_check;
alter table public.account_deletion_requests
  add constraint account_deletion_requests_status_check
  check (status in ('pending', 'cancel_pending', 'approved', 'rejected'));

create or replace function public.request_account_deletion()
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if exists (
    select 1 from public.account_deletion_requests
    where user_id = auth.uid()
      and status in ('pending', 'cancel_pending')
  ) then
    raise exception 'deletion_request_already_pending';
  end if;

  insert into public.account_deletion_requests(user_id, email)
  values (auth.uid(), public.life_pilot_user_email())
  returning id into request_id;
  return request_id;
end;
$function$;

create or replace function public.get_my_account_deletion_request()
returns table(
  id uuid,
  status text,
  requested_at timestamptz,
  cancellation_requested_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select r.id, r.status, r.requested_at, r.cancellation_requested_at
  from public.account_deletion_requests r
  where r.user_id = auth.uid()
    and r.status in ('pending', 'cancel_pending')
  order by r.requested_at desc
  limit 1;
$function$;

create or replace function public.cancel_account_deletion_request()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  update public.account_deletion_requests
  set status = 'cancel_pending',
      cancellation_requested_at = now()
  where user_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'pending_deletion_request_not_found';
  end if;
end;
$function$;

create or replace function public.admin_list_account_deletion_requests()
returns setof public.account_deletion_requests
language sql
security definer
set search_path = ''
as $function$
  select *
  from public.account_deletion_requests
  where public.life_pilot_is_admin()
    and status in ('pending', 'cancel_pending')
  order by
    case status when 'cancel_pending' then 0 else 1 end,
    coalesce(cancellation_requested_at, requested_at) desc;
$function$;

create or replace function public.admin_confirm_account_deletion_cancellation(
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not public.life_pilot_is_admin() then
    raise exception 'admin_required';
  end if;

  delete from public.account_deletion_requests
  where id = p_request_id
    and status = 'cancel_pending';

  if not found then
    raise exception 'cancellation_request_not_found';
  end if;
end;
$function$;

revoke all on function public.request_account_deletion() from public, anon;
revoke all on function public.get_my_account_deletion_request()
from public, anon;
revoke all on function public.cancel_account_deletion_request()
from public, anon;
revoke all on function public.admin_list_account_deletion_requests()
from public, anon;
revoke all on function public.admin_confirm_account_deletion_cancellation(uuid)
from public, anon;

grant execute on function public.request_account_deletion() to authenticated;
grant execute on function public.get_my_account_deletion_request()
to authenticated;
grant execute on function public.cancel_account_deletion_request()
to authenticated;
grant execute on function public.admin_list_account_deletion_requests()
to authenticated;
grant execute on function public.admin_confirm_account_deletion_cancellation(uuid)
to authenticated;

commit;
