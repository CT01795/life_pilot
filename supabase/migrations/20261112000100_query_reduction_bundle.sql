begin;

create or replace function public.get_my_business_plan_window(
  p_before timestamptz,
  p_seek_older boolean default false,
  p_window_days integer default 360
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_to timestamptz := p_before;
  v_from timestamptz;
  v_latest timestamptz;
  v_rows jsonb;
  v_has_more boolean;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_before is null or p_window_days < 1 or p_window_days > 3660 then
    raise exception 'invalid_business_plan_window' using errcode = '22023';
  end if;

  if p_seek_older then
    select max(plan.created_at) into v_latest
    from public.business_plan plan
    where lower(trim(plan.created_by)) = v_email
      and plan.created_at < p_before;
    if v_latest is null then
      return jsonb_build_object(
        'rows', '[]'::jsonb,
        'next_before', p_before,
        'has_more', false
      );
    end if;
    v_to := v_latest + interval '1 microsecond';
  end if;

  v_from := v_to - make_interval(days => p_window_days);
  select coalesce(jsonb_agg(to_jsonb(page) order by page.created_at desc), '[]'::jsonb)
    into v_rows
  from (
    select plan.id, plan.title, plan.created_at, plan.status
    from public.business_plan plan
    where lower(trim(plan.created_by)) = v_email
      and plan.created_at >= v_from
      and plan.created_at < v_to
    order by plan.created_at desc, plan.id desc
  ) page;

  select exists (
    select 1 from public.business_plan plan
    where lower(trim(plan.created_by)) = v_email
      and plan.created_at < v_from
  ) into v_has_more;

  return jsonb_build_object(
    'rows', v_rows,
    'next_before', v_from,
    'has_more', v_has_more
  );
end;
$$;

create or replace function public.calendar_has_recommended_place(
  p_name text,
  p_country text,
  p_city text,
  p_location text,
  p_day_start timestamptz,
  p_day_end timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and p_day_start is not null
    and p_day_end > p_day_start
    and exists (
      select 1
      from public.calendar_events event
      where lower(trim(event.account)) = public.life_pilot_user_email()
        and event.start_date >= p_day_start
        and event.start_date < p_day_end
        and lower(trim(coalesce(event.name, ''))) = lower(trim(coalesce(p_name, '')))
        and lower(trim(coalesce(event.country, ''))) = lower(trim(coalesce(p_country, '')))
        and lower(trim(coalesce(event.city, ''))) = lower(trim(coalesce(p_city, '')))
        and lower(trim(coalesce(event.location, ''))) = lower(trim(coalesce(p_location, '')))
    );
$$;

create or replace function public.get_home_recommendation_city_counts()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'events', coalesce((
      select jsonb_agg(to_jsonb(row_value) order by row_value.count desc, row_value.city)
      from public.get_event_city_counts() row_value
    ), '[]'::jsonb),
    'places', coalesce((
      select jsonb_agg(to_jsonb(row_value) order by row_value.count desc, row_value.city)
      from public.get_place_city_counts() row_value
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_my_business_plan_window(timestamptz, boolean, integer)
  from public, anon;
revoke all on function public.calendar_has_recommended_place(text, text, text, text, timestamptz, timestamptz)
  from public, anon;
revoke all on function public.get_home_recommendation_city_counts()
  from public, anon;
grant execute on function public.get_my_business_plan_window(timestamptz, boolean, integer)
  to authenticated, service_role;
grant execute on function public.calendar_has_recommended_place(text, text, text, text, timestamptz, timestamptz)
  to authenticated, service_role;
grant execute on function public.get_home_recommendation_city_counts()
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
