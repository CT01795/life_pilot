begin;

create or replace function public.admin_delete_user_subscription(p_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_user_id uuid;
begin
  if not public.life_pilot_is_admin() then
    raise exception 'admin_required';
  end if;

  select u.id into target_user_id
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  limit 1;

  if target_user_id is null then
    raise exception 'user_not_found';
  end if;

  delete from public.user_subscription_entitlements
  where user_id = target_user_id;

  delete from public.user_subscriptions
  where user_id = target_user_id;

  if not found then
    raise exception 'subscription_not_found';
  end if;
end;
$function$;

revoke all on function public.admin_delete_user_subscription(text)
from public, anon;
grant execute on function public.admin_delete_user_subscription(text)
to authenticated;

commit;
