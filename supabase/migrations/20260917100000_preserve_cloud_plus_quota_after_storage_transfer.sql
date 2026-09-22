begin;

-- Returning from local storage to cloud storage must not make an active
-- cloud Plus subscription look like the free plan.  Versioned entitlements
-- remain the primary source, while older/current subscription rows provide a
-- compatibility fallback for accounts created before entitlement snapshots
-- were introduced or repaired.
create or replace function public.life_pilot_plan_limit(p_resource text)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  frozen_limit bigint;
  override_limit bigint;
  snapshot_limit bigint;
  pricing_limit bigint;
  subscription_row public.user_subscriptions%rowtype;
  subscription_active boolean := false;
begin
  if public.life_pilot_is_admin() then
    return 9223372036854775807;
  end if;

  select *
    into subscription_row
    from public.user_subscriptions s
   where s.user_id = auth.uid();

  subscription_active := found
    and subscription_row.plan = 'plus'
    and subscription_row.status in ('trialing', 'active')
    and coalesce(
      subscription_row.current_period_end,
      subscription_row.expires_at
    ) > now();

  -- A custom unlimited grant applies to the storage plan for which it was
  -- issued.  A local-only grant must not unlock unlimited cloud storage.
  if subscription_active
     and subscription_row.storage_plan = 'cloud'
     and coalesce(subscription_row.unlimited_quota, false) then
    return 9223372036854775807;
  end if;

  -- Frozen paid entitlements are additive and take precedence over the
  -- mutable current pricing version.
  select sum((e.entitlement_snapshot ->> p_resource)::bigint)
    into frozen_limit
    from public.user_subscription_entitlements e
   where e.user_id = auth.uid()
     and e.storage_plan = 'cloud'
     and e.starts_at <= now()
     and e.ends_at > now()
     and e.entitlement_snapshot ? p_resource;

  if frozen_limit is not null then
    return frozen_limit;
  end if;

  -- A local Plus subscription alone does not provide cloud Plus quota.
  if not subscription_active or subscription_row.storage_plan <> 'cloud' then
    return case p_resource
      when 'calendar_events' then 30
      when 'accounting_detail' then 30
      when 'point_record_detail' then 30
      when 'memory_trace' then 30
      when 'game_questions' then 50
      when 'calendar_shares' then 2
      when 'image_bytes' then 0
      else 0
    end;
  end if;

  -- Preserve administrator-defined per-user overrides from the pre-versioned
  -- subscription model.
  override_limit := case p_resource
    when 'calendar_events' then subscription_row.calendar_quota_override
    when 'accounting_detail' then subscription_row.accounting_quota_override
    when 'point_record_detail' then subscription_row.point_quota_override
    when 'memory_trace' then subscription_row.memory_quota_override
    when 'game_questions' then subscription_row.game_question_quota_override
    when 'calendar_shares' then subscription_row.calendar_share_quota_override
    when 'image_bytes' then subscription_row.image_bytes_quota_override
  end;
  if override_limit is not null then
    return override_limit;
  end if;

  -- Current subscriptions normally retain the exact quota snapshot that was
  -- purchased.  This fallback is essential when an entitlement row is
  -- missing but the paid subscription itself is still valid.
  if subscription_row.entitlement_snapshot ? p_resource then
    snapshot_limit := (
      subscription_row.entitlement_snapshot ->> p_resource
    )::bigint;
  end if;
  if snapshot_limit is not null then
    return snapshot_limit;
  end if;

  -- Repair-compatible fallback for a valid pricing version whose snapshot
  -- was not populated by an older migration.
  select case p_resource
      when 'calendar_events' then p.calendar_quota::bigint
      when 'accounting_detail' then p.accounting_quota::bigint
      when 'point_record_detail' then p.point_quota::bigint
      when 'memory_trace' then p.memory_quota::bigint
      when 'game_questions' then p.game_question_quota::bigint
      when 'calendar_shares' then p.calendar_share_quota::bigint
      when 'image_bytes' then p.image_megabytes::bigint * 1024 * 1024
    end * subscription_row.quota_multiplier
    into pricing_limit
    from public.subscription_pricing_versions p
   where p.id = subscription_row.pricing_version_id;

  if pricing_limit is not null then
    return pricing_limit;
  end if;

  -- Legacy Plus accounts without a version or snapshot retain the original
  -- Plus allowance instead of silently falling back to the free allowance.
  return case p_resource
    when 'calendar_events' then 300
    when 'accounting_detail' then 300
    when 'point_record_detail' then 300
    when 'memory_trace' then 300
    when 'game_questions' then 500
    when 'calendar_shares' then 5
    when 'image_bytes' then 314572800
    else 0
  end;
end;
$function$;

revoke all on function public.life_pilot_plan_limit(text)
  from public, anon, authenticated;
grant execute on function public.life_pilot_plan_limit(text)
  to authenticated, service_role;

commit;
