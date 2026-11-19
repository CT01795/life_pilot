begin;

create or replace function public.life_pilot_cached_weather_batch(
  p_locations jsonb
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
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_locations) is distinct from 'array'
     or jsonb_array_length(p_locations) not between 1 and 8
     or exists (
       select 1
       from jsonb_array_elements(p_locations) item
       where jsonb_typeof(item) is distinct from 'object'
          or jsonb_typeof(item -> 'lat') is distinct from 'number'
          or jsonb_typeof(item -> 'lng') is distinct from 'number'
          or (item ->> 'lat')::double precision not between -90 and 90
          or (item ->> 'lng')::double precision not between -180 and 180
     ) then
    raise exception 'Invalid weather batch' using errcode = '22023';
  end if;

  select jsonb_agg(
    case when cache.cache_key is null then null
         else jsonb_build_object(
           'items', cache.forecast,
           'expires_at', cache.expires_at
         )
    end
    order by requested.ordinality
  )
  into v_result
  from jsonb_array_elements(p_locations) with ordinality requested(item, ordinality)
  left join public.weather_forecast_cache cache
    on cache.cache_key = encode(
      sha256(convert_to(
        public.life_pilot_weather_coordinate_bucket(
          (requested.item ->> 'lat')::double precision
        )::text || ':' ||
        public.life_pilot_weather_coordinate_bucket(
          (requested.item ->> 'lng')::double precision
        )::text,
        'UTF8'
      )),
      'hex'
    )
   and cache.expires_at > now()
   and jsonb_typeof(cache.forecast) = 'array';

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

create or replace function public.life_pilot_cached_holidays_batch(
  p_years integer[],
  p_language text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_country text;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  v_country := case p_language
    when 'zh' then 'TW'
    when 'en' then 'US'
    when 'ja' then 'JP'
    when 'ko' then 'KR'
  end;
  if v_country is null
     or coalesce(cardinality(p_years), 0) not between 1 and 4
     or exists (
       select 1 from unnest(p_years) as years(value)
       where years.value not between 1 and 9998
     )
     or cardinality(p_years) <> (
       select count(distinct years.value)
       from unnest(p_years) as years(value)
     ) then
    raise exception 'Invalid holiday batch' using errcode = '22023';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'year', requested.year,
      'cached', runs.cached or jsonb_array_length(items.value) > 0,
      'fresh', runs.fresh,
      'items', items.value
    )
    order by requested.ordinality
  )
  into v_result
  from unnest(p_years) with ordinality requested(year, ordinality)
  cross join lateral (
    select coalesce(
      jsonb_agg(
        jsonb_build_object('date', holiday_date, 'summary', summary)
        order by holiday_date, source_event_id
      ),
      '[]'::jsonb
    ) as value
    from public.public_holidays
    where country_code = v_country
      and holiday_date >= make_date(requested.year, 1, 1)
      and holiday_date < make_date(requested.year + 1, 1, 1)
  ) items
  cross join lateral (
    select
      exists (
        select 1 from public.holiday_sync_runs
        where country_code = v_country
          and calendar_year = requested.year
          and status = 'success'
      ) as cached,
      exists (
        select 1 from public.holiday_sync_runs
        where country_code = v_country
          and calendar_year = requested.year
          and status = 'success'
          and sync_date = (now() at time zone 'UTC')::date
      ) as fresh
  ) runs;

  return coalesce(v_result, '[]'::jsonb);
end;
$$;

revoke all on function public.life_pilot_cached_weather_batch(jsonb)
  from public, anon;
revoke all on function public.life_pilot_cached_holidays_batch(integer[], text)
  from public, anon;
grant execute on function public.life_pilot_cached_weather_batch(jsonb)
  to authenticated, service_role;
grant execute on function public.life_pilot_cached_holidays_batch(integer[], text)
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
