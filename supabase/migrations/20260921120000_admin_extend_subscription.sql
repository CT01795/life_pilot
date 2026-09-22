begin;

create or replace function public.admin_extend_user_subscription(
  p_email text,
  p_days integer default 90
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_id uuid;
  target_end timestamptz;
begin
  if not public.life_pilot_is_admin() then raise exception 'admin_required'; end if;
  if p_days <= 0 or p_days > 3650 then raise exception 'invalid_extension_days'; end if;
  select u.id into target_id from auth.users u
  where lower(u.email) = lower(trim(p_email));
  if target_id is null then raise exception 'user_not_found'; end if;
  select greatest(coalesce(s.current_period_end, s.expires_at, now()), now())
    into target_end
  from public.user_subscriptions s where s.user_id = target_id;
  if target_end is null then target_end := now(); end if;
  update public.user_subscriptions
  set status = 'active',
      current_period_end = target_end + make_interval(days => p_days),
      expires_at = target_end + make_interval(days => p_days),
      updated_at = now()
  where user_id = target_id;
  if not found then raise exception 'subscription_not_found'; end if;
end;
$function$;

revoke all on function public.admin_extend_user_subscription(text, integer)
from public, anon;
grant execute on function public.admin_extend_user_subscription(text, integer)
to authenticated;

commit;
