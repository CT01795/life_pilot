begin;

create or replace function public.admin_get_user_subscription(p_email text)
returns table(
  user_id uuid,
  email text,
  plan text,
  storage_plan text,
  status text,
  pricing_version_id uuid,
  pricing_version_name text,
  quota_multiplier integer,
  quarterly_price_paid_twd integer,
  starts_at timestamptz,
  expires_at timestamptz,
  current_period_end timestamptz,
  admin_note text
)
language sql
security definer
set search_path = ''
as $function$
  select u.id, lower(u.email), s.plan, s.storage_plan, s.status,
         s.pricing_version_id, p.version_name, s.quota_multiplier,
         s.quarterly_price_paid_twd, s.starts_at, s.expires_at,
         s.current_period_end, s.admin_note
  from auth.users u
  left join public.user_subscriptions s on s.user_id = u.id
  left join public.subscription_pricing_versions p on p.id = s.pricing_version_id
  where public.life_pilot_is_admin()
    and lower(u.email) = lower(trim(p_email));
$function$;

revoke all on function public.admin_get_user_subscription(text) from public, anon;
grant execute on function public.admin_get_user_subscription(text) to authenticated;

commit;
