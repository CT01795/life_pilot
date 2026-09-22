begin;

create or replace function public.admin_get_user_subscription_entitlements(
  p_email text
)
returns table(
  id uuid,
  version_name text,
  storage_plan text,
  quota_multiplier integer,
  quarterly_price_paid_twd integer,
  starts_at timestamptz,
  ends_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select e.id, p.version_name, e.storage_plan, e.quota_multiplier,
         e.quarterly_price_paid_twd, e.starts_at, e.ends_at
  from auth.users u
  join public.user_subscription_entitlements e on e.user_id = u.id
  join public.subscription_pricing_versions p on p.id = e.pricing_version_id
  where public.life_pilot_is_admin()
    and lower(u.email) = lower(trim(p_email))
    and e.ends_at > now()
  order by e.created_at desc, e.id desc;
$function$;

create or replace function public.admin_delete_user_subscription_entitlement(
  p_entitlement_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_user_id uuid;
  replacement public.user_subscription_entitlements%rowtype;
  replacement_period_end timestamptz;
begin
  if not public.life_pilot_is_admin() then
    raise exception 'admin_required';
  end if;

  delete from public.user_subscription_entitlements
  where id = p_entitlement_id
  returning user_id into target_user_id;

  if target_user_id is null then
    raise exception 'entitlement_not_found';
  end if;

  select e.* into replacement
  from public.user_subscription_entitlements e
  where e.user_id = target_user_id
    and e.starts_at <= now()
    and e.ends_at > now()
  order by e.created_at desc, e.id desc
  limit 1;

  select max(e.ends_at) into replacement_period_end
  from public.user_subscription_entitlements e
  where e.user_id = target_user_id
    and e.starts_at <= now()
    and e.ends_at > now();

  if replacement.id is null then
    update public.user_subscriptions
    set plan = 'free', status = 'inactive', current_period_end = null,
        expires_at = null, pricing_version_id = null, quota_multiplier = 1,
        quarterly_price_paid_twd = null, entitlement_snapshot = null,
        updated_at = now(), updated_by = auth.uid()
    where user_id = target_user_id;
  else
    update public.user_subscriptions
    set plan = 'plus', status = 'active',
        current_period_end = replacement_period_end,
        expires_at = replacement_period_end,
        pricing_version_id = replacement.pricing_version_id,
        quota_multiplier = replacement.quota_multiplier,
        storage_plan = replacement.storage_plan,
        quarterly_price_paid_twd = replacement.quarterly_price_paid_twd,
        entitlement_snapshot = replacement.entitlement_snapshot,
        updated_at = now(), updated_by = auth.uid()
    where user_id = target_user_id;
  end if;
end;
$function$;

revoke all on function public.admin_get_user_subscription_entitlements(text)
from public, anon;
grant execute on function public.admin_get_user_subscription_entitlements(text)
to authenticated;

revoke all on function public.admin_delete_user_subscription_entitlement(uuid)
from public, anon;
grant execute on function public.admin_delete_user_subscription_entitlement(uuid)
to authenticated;

commit;
