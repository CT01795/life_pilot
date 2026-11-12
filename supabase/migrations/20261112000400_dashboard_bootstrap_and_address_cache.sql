begin;

create or replace function public.get_or_create_my_dashboard_core(
  p_expected_email text,
  p_day_start timestamptz,
  p_day_end timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_setting public.dashboard_setting%rowtype;
  v_accounting jsonb;
  v_points jsonb;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if lower(trim(coalesce(p_expected_email, ''))) <> v_email then
    raise exception 'account_mismatch' using errcode = '42501';
  end if;
  if p_day_start is null or p_day_end is null or p_day_end <= p_day_start then
    raise exception 'invalid_dashboard_day' using errcode = '22023';
  end if;

  insert into public.dashboard_setting(
    account, recommend_event_city, recommend_place_city, language
  ) values (v_email, '台北', '台北', 'zh')
  on conflict (account) do nothing;

  select * into v_setting
  from public.dashboard_setting setting
  where lower(trim(setting.account)) = v_email
  limit 1;

  if v_setting.accounting_account_id is not null then
    v_accounting := public.get_my_dashboard_ledger_summary(
      'accounting', v_setting.accounting_account_id,
      p_day_start, p_day_end
    );
  end if;
  if v_setting.point_account_id is not null then
    v_points := public.get_my_dashboard_ledger_summary(
      'points', v_setting.point_account_id,
      p_day_start, p_day_end
    );
  end if;

  return jsonb_build_object(
    'setting', jsonb_build_object(
      'recommend_event_city', v_setting.recommend_event_city,
      'recommend_place_city', v_setting.recommend_place_city,
      'language', v_setting.language,
      'accounting_account_id', v_setting.accounting_account_id,
      'accounting_account_name', v_setting.accounting_account_name,
      'point_account_id', v_setting.point_account_id,
      'point_account_name', v_setting.point_account_name
    ),
    'accounting', v_accounting,
    'points', v_points
  );
end;
$$;

create or replace function public.life_pilot_resolve_cached_address(
  p_city_like text,
  p_location_like text,
  p_country_like text,
  p_query text
)
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
  if nullif(trim(p_query), '') is null or length(p_query) > 200 then
    raise exception 'invalid_geocode_query' using errcode = '22023';
  end if;

  select jsonb_build_object('lat', location.lat, 'lng', location.lng)
  into v_result
  from public.location_lat_lng location
  where (nullif(p_city_like, '') is null
         or p_city_like ilike '%' || location.city || '%')
    and (nullif(p_location_like, '') is null
         or p_location_like ilike '%' || location.location || '%')
    and (nullif(p_country_like, '') is null
         or p_country_like ilike '%' || location.country || '%')
    and location.lat is not null
    and location.lng is not null
  order by location.created_at desc
  limit 1;

  return coalesce(v_result, public.life_pilot_geocode_cache_result(p_query));
end;
$$;

revoke all on function public.get_or_create_my_dashboard_core(
  text, timestamptz, timestamptz
) from public, anon;
grant execute on function public.get_or_create_my_dashboard_core(
  text, timestamptz, timestamptz
) to authenticated, service_role;

revoke all on function public.life_pilot_resolve_cached_address(
  text, text, text, text
) from public, anon;
grant execute on function public.life_pilot_resolve_cached_address(
  text, text, text, text
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
