begin;

drop function if exists public.get_my_subscription_status();
create function public.get_my_subscription_status()
returns table(
  plan text, status text, current_period_end timestamptz,
  cancel_at_period_end boolean, storage_plan text,
  quota_multiplier integer, quarterly_price_paid_twd integer,
  pricing_version_name text, pricing_effective_at timestamptz,
  last_data_activity_at timestamptz, downgrade_grace_ends_at timestamptz
)
language sql stable security definer set search_path = '' as $function$
  select public.life_pilot_subscription_plan(), coalesce(s.status, 'inactive'),
    case when s.plan = 'free' then null else coalesce(s.current_period_end, s.expires_at) end,
    coalesce(s.cancel_at_period_end, false), coalesce(s.storage_plan, 'cloud'),
    coalesce(s.quota_multiplier, 1), s.quarterly_price_paid_twd,
    p.version_name, p.effective_at, s.last_data_activity_at,
    s.downgrade_grace_ends_at
  from (select 1) seed
  left join public.user_subscriptions s on s.user_id = auth.uid()
  left join public.subscription_pricing_versions p on p.id = s.pricing_version_id;
$function$;

revoke all on function public.get_my_subscription_status() from public, anon;
grant execute on function public.get_my_subscription_status() to authenticated;

commit;
