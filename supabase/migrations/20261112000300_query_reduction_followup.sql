begin;

create or replace function public.search_lat_lng_batch(p_queries jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_queries) <> 'array'
     or jsonb_array_length(p_queries) > 100 then
    raise exception 'invalid_geocode_cache_batch' using errcode = '22023';
  end if;

  with inputs as (
    select item.value, item.ordinality
    from jsonb_array_elements(p_queries) with ordinality item(value, ordinality)
  )
  select coalesce(
    jsonb_agg(
      case
        when matched.lat is null or matched.lng is null then '{}'::jsonb
        else jsonb_build_object('lat', matched.lat, 'lng', matched.lng)
      end
      order by inputs.ordinality
    ),
    '[]'::jsonb
  )
  into v_result
  from inputs
  left join lateral (
    select location.lat, location.lng
    from public.location_lat_lng location
    where (
        nullif(inputs.value ->> 'city_like', '') is null
        or (inputs.value ->> 'city_like') ilike '%' || location.city || '%'
      )
      and (
        nullif(inputs.value ->> 'location_like', '') is null
        or (inputs.value ->> 'location_like') ilike '%' || location.location || '%'
      )
      and (
        nullif(inputs.value ->> 'country_like', '') is null
        or (inputs.value ->> 'country_like') ilike '%' || location.country || '%'
      )
    order by location.created_at desc
    limit 1
  ) matched on true;

  return v_result;
end;
$$;

create or replace function public.get_my_ledger_history_window_v2(
  p_kind text,
  p_account_id uuid,
  p_type text,
  p_from timestamptz,
  p_until timestamptz,
  p_include_reserved boolean,
  p_include_latest boolean
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_table text;
  v_account_table text;
  v_total_column text;
  v_columns text := 'd.id,d.account_id,d.created_at,d.date,d.primary_category,d."group",d.description,d.type,d.value';
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_from is null or p_until is null or p_until <= p_from
     or p_until > p_from + interval '36525 days' then
    raise exception 'invalid_ledger_history_window' using errcode = '22023';
  end if;
  if p_kind = 'accounting' then
    v_table := 'accounting_detail';
    v_account_table := 'accounting_account';
    v_total_column := 'balance';
    v_columns := v_columns || ',d.currency';
  elsif p_kind = 'points' then
    v_table := 'point_record_detail';
    v_account_table := 'point_record_account';
    v_total_column := 'points';
  else
    raise exception 'invalid_ledger_kind' using errcode = '22023';
  end if;

  execute format($query$
    with page as (
      select %1$s
      from public.%2$I d
      where d.account_id = $1 and d.type ilike $2
        and ((d.date >= $3 and d.date < $4)
          or ($5 and d.primary_category = 'reserved'))
      order by d.date desc
    ), fallback as (
      select %1$s
      from public.%2$I d
      where $6
        and not exists(
          select 1 from page where primary_category is distinct from 'reserved'
        )
        and d.account_id = $1 and d.type ilike $2
        and d.primary_category <> 'reserved'
      order by d.date desc
      limit 1
    ), boundary as (
      select least($3, (select date from fallback)) before
    ), display_rows as (
      select * from page
      union all
      select * from fallback
    )
    select jsonb_build_object(
      'rows', coalesce(
        (select jsonb_agg(to_jsonb(row_value) order by row_value.date desc)
         from display_rows row_value),
        '[]'::jsonb
      ),
      'next_before', boundary.before,
      'next_date', (
        select d.date from public.%2$I d
        where d.account_id = $1 and d.type ilike $2
          and d.date < boundary.before and d.primary_category <> 'reserved'
        order by d.date desc limit 1
      ),
      'total', (
        select account_row.%3$I from public.%4$I account_row
        where account_row.id = $1 and account_row.is_valid is true
      )
    ) from boundary
  $query$, v_columns, v_table, v_total_column, v_account_table)
  into v_result
  using p_account_id, p_type, p_from, p_until,
        p_include_reserved, p_include_latest;
  return v_result;
end;
$$;

create or replace function public.get_my_ledger_entry_defaults(
  p_expected_email text,
  p_accounting_account_id uuid default null,
  p_point_account_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_accounting jsonb;
  v_points jsonb;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if v_email <> lower(trim(coalesce(p_expected_email, ''))) then
    raise exception 'account_changed' using errcode = '42501';
  end if;

  if p_accounting_account_id is not null then
    select jsonb_build_object(
      'value', detail.value,
      'primary_category', detail.primary_category
    )
    into v_accounting
    from public.accounting_detail detail
    join public.accounting_account account_row
      on account_row.id = detail.account_id
    where detail.account_id = p_accounting_account_id
      and detail.type ilike 'balance'
      and account_row.is_valid is true
      and lower(trim(account_row.created_by)) = v_email
    order by detail.date desc, detail.id desc
    limit 1;
  end if;

  if p_point_account_id is not null then
    select jsonb_build_object(
      'value', detail.value,
      'primary_category', detail.primary_category
    )
    into v_points
    from public.point_record_detail detail
    join public.point_record_account account_row
      on account_row.id = detail.account_id
    where detail.account_id = p_point_account_id
      and detail.type ilike 'points'
      and account_row.is_valid is true
      and lower(trim(account_row.created_by)) = v_email
    order by detail.date desc, detail.id desc
    limit 1;
  end if;

  return jsonb_build_object('accounting', v_accounting, 'points', v_points);
end;
$$;

do $$
declare
  v_has_legacy_screenshots boolean;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'feedback'
      and column_name = 'screenshot'
  ) then
    execute $query$
      select exists (
        select 1 from public.feedback
        where coalesce(array_length(screenshot, 1), 0) > 0
      )
    $query$
    into v_has_legacy_screenshots;
    if v_has_legacy_screenshots then
      raise exception 'feedback_screenshot_migration_incomplete';
    end if;
  end if;
end;
$$;

alter table public.feedback drop column if exists screenshot;

do $$
declare
  v_legacy_keys text[] := array[
    'calendar_quota', 'recommended_event_quota',
    'recommended_attraction_quota', 'accounting_quota', 'point_quota',
    'memory_quota', 'game_question_quota', 'calendar_share_quota',
    'image_megabytes'
  ];
begin
  if exists (
    select 1 from public.user_subscription_entitlements
    where entitlement_snapshot ?| v_legacy_keys
  ) or exists (
    select 1 from public.user_subscriptions
    where entitlement_snapshot ?| v_legacy_keys
  ) then
    raise exception 'subscription_snapshot_migration_incomplete';
  end if;
end;
$$;

create or replace function public.life_pilot_resolve_cloud_quota_value(
  p_snapshot jsonb,
  p_version jsonb,
  p_resource text,
  p_multiplier integer
)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  quota_column text;
  quota_value numeric;
  unit_factor numeric := 1;
begin
  quota_column := case p_resource
    when 'calendar_events' then 'calendar_quota'
    when 'accounting_detail' then 'accounting_quota'
    when 'point_record_detail' then 'point_quota'
    when 'memory_trace' then 'memory_quota'
    when 'game_questions' then 'game_question_quota'
    when 'calendar_shares' then 'calendar_share_quota'
    when 'recommended_events' then 'recommended_event_quota'
    when 'recommended_attractions' then 'recommended_attraction_quota'
    when 'image_bytes' then 'image_megabytes'
    when 'answer_history_days' then 'answer_history_days'
    else null
  end;
  if quota_column is null then
    raise exception 'LIFE_PILOT_QUOTA_RESOURCE_INVALID:%', p_resource;
  end if;

  quota_value := nullif(p_snapshot ->> p_resource, '')::numeric;
  if quota_value is null then
    quota_value := nullif(p_version ->> quota_column, '')::numeric;
    if p_resource = 'image_bytes' then unit_factor := 1024 * 1024; end if;
    if p_resource <> 'answer_history_days' then
      if p_multiplier is null or p_multiplier < 1 then
        raise exception 'LIFE_PILOT_QUOTA_CONFIGURATION_INVALID:multiplier';
      end if;
      quota_value := quota_value * p_multiplier;
    end if;
    quota_value := quota_value * unit_factor;
  end if;
  if quota_value < 0 or quota_value <> trunc(quota_value) then
    raise exception 'LIFE_PILOT_QUOTA_CONFIGURATION_INVALID:%', p_resource;
  end if;
  return quota_value;
end;
$$;

create or replace function public.get_my_cumulative_subscription_quotas(
  p_storage_plan text default 'cloud'
)
returns table(resource text, quota bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with active_entitlements as (
    select entitlement_snapshot
    from public.user_subscription_entitlements
    where user_id = auth.uid()
      and storage_plan = p_storage_plan
      and starts_at <= now()
      and ends_at > now()
  ), entitlement_quotas as (
    select quota_values.resource, quota_values.quota
    from active_entitlements active
    cross join lateral (
      values
        ('calendar_events'::text,
          nullif(active.entitlement_snapshot ->> 'calendar_events', '')::bigint),
        ('recommended_events',
          nullif(active.entitlement_snapshot ->> 'recommended_events', '')::bigint),
        ('recommended_attractions',
          nullif(active.entitlement_snapshot ->> 'recommended_attractions', '')::bigint),
        ('accounting_detail',
          nullif(active.entitlement_snapshot ->> 'accounting_detail', '')::bigint),
        ('point_record_detail',
          nullif(active.entitlement_snapshot ->> 'point_record_detail', '')::bigint),
        ('memory_trace',
          nullif(active.entitlement_snapshot ->> 'memory_trace', '')::bigint),
        ('game_questions',
          nullif(active.entitlement_snapshot ->> 'game_questions', '')::bigint),
        ('calendar_shares',
          nullif(active.entitlement_snapshot ->> 'calendar_shares', '')::bigint),
        ('image_bytes',
          nullif(active.entitlement_snapshot ->> 'image_bytes', '')::bigint),
        ('answer_history_days',
          nullif(active.entitlement_snapshot ->> 'answer_history_days', '')::bigint)
    ) quota_values(resource, quota)
    where quota_values.quota is not null
  )
  select entitlement_quotas.resource, sum(entitlement_quotas.quota)::bigint
  from entitlement_quotas
  group by entitlement_quotas.resource;
$$;

revoke all on function public.search_lat_lng_batch(jsonb) from public, anon;
revoke all on function public.get_my_ledger_entry_defaults(text, uuid, uuid)
  from public, anon;
grant execute on function public.search_lat_lng_batch(jsonb)
  to authenticated, service_role;
grant execute on function public.get_my_ledger_entry_defaults(text, uuid, uuid)
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
