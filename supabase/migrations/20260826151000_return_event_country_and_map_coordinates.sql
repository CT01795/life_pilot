begin;

drop function if exists public.get_filtered_calendar_events(json);
drop function if exists public.get_filtered_memory_trace(json);
drop function if exists public.get_filtered_recommended_attractions(json);
drop function if exists public.get_filtered_recommended_events(json);

create function public.get_filtered_calendar_events(payload json)
returns table(
  id text, master_graph_url text, master_url text,
  start_date timestamptz, end_date timestamptz,
  start_time text, end_time text,
  country text, city text, location text, name text, type text,
  description text, fee text, unit text, sub_events jsonb, account text,
  repeat_options text, reminder_options text[], is_holiday boolean,
  is_taiwan_holiday boolean, is_approved boolean, age_min numeric,
  age_max numeric, is_free boolean, price_min numeric, price_max numeric,
  is_outdoor boolean, is_like boolean, is_dislike boolean, source text,
  lat double precision, lng double precision,
  map_lat double precision, map_lng double precision
)
language plpgsql
stable
set search_path = ''
as $$
declare
  inputid text := nullif(payload->>'inputid', '');
  inputdates date := nullif(payload->>'inputdates', '')::date;
  inputdatee date := nullif(payload->>'inputdatee', '')::date;
  inputuser text := payload->>'inputuser';
begin
  return query
  select
    e.id, e.master_graph_url, e.master_url, e.start_date, e.end_date,
    e.start_time, e.end_time, e.country, e.city, e.location, e.name,
    e.type, e.description, e.fee, e.unit, e.sub_events, e.account,
    e.repeat_options, e.reminder_options, e.is_holiday,
    e.is_taiwan_holiday, e.is_approved, e.age_min, e.age_max,
    e.is_free, e.price_min, e.price_max, e.is_outdoor,
    f.is_like, f.is_dislike, e.source, e.lat, e.lng, e.map_lat, e.map_lng
  from public.calendar_events e
  left join public.recommended_events_favor f
    on e.id = f.id and inputuser = f.account
  where inputuser = e.account
    and (
      (e.end_date is null and e.start_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
      or
      (e.end_date is not null and e.end_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
    )
    and (inputid is null or e.id = inputid)
  order by e.start_date desc, e.start_time desc, e.city, e.name;
end;
$$;

create function public.get_filtered_memory_trace(payload json)
returns table(
  id text, master_graph_url text, master_url text,
  start_date timestamptz, end_date timestamptz,
  start_time text, end_time text,
  country text, city text, location text, name text, type text,
  description text, fee text, unit text, sub_events jsonb, account text,
  repeat_options text, reminder_options text[], is_holiday boolean,
  is_taiwan_holiday boolean, is_approved boolean, age_min numeric,
  age_max numeric, is_free boolean, price_min numeric, price_max numeric,
  is_outdoor boolean, is_like boolean, is_dislike boolean, source text,
  lat double precision, lng double precision,
  map_lat double precision, map_lng double precision
)
language plpgsql
stable
set search_path = ''
as $$
declare
  inputid text := nullif(payload->>'inputid', '');
  inputdates date := nullif(payload->>'inputdates', '')::date;
  inputdatee date := nullif(payload->>'inputdatee', '')::date;
  inputuser text := payload->>'inputuser';
begin
  return query
  select
    e.id, e.master_graph_url, e.master_url, e.start_date, e.end_date,
    e.start_time, e.end_time, e.country, e.city, e.location, e.name,
    e.type, e.description, e.fee, e.unit, e.sub_events, e.account,
    e.repeat_options, e.reminder_options, e.is_holiday,
    e.is_taiwan_holiday, e.is_approved, e.age_min, e.age_max,
    e.is_free, e.price_min, e.price_max, e.is_outdoor,
    f.is_like, f.is_dislike, e.source, e.lat, e.lng, e.map_lat, e.map_lng
  from public.memory_trace e
  left join public.recommended_events_favor f
    on e.id = f.id and inputuser = f.account
  where inputuser = e.account
    and (
      (e.end_date is null and e.start_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
      or
      (e.end_date is not null and e.end_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
    )
    and (inputid is null or e.id = inputid)
  order by e.start_date desc, e.start_time desc, e.city, e.name;
end;
$$;

create function public.get_filtered_recommended_attractions(payload json)
returns table(
  id text, master_graph_url text, master_url text,
  start_date timestamptz, end_date timestamptz,
  start_time text, end_time text,
  country text, city text, location text, name text, type text,
  description text, fee text, unit text, sub_events jsonb, account text,
  repeat_options text, reminder_options text[], is_holiday boolean,
  is_taiwan_holiday boolean, is_approved boolean, age_min numeric,
  age_max numeric, is_free boolean, price_min numeric, price_max numeric,
  is_outdoor boolean, is_like boolean, is_dislike boolean, source text,
  lat double precision, lng double precision,
  map_lat double precision, map_lng double precision
)
language plpgsql
stable
set search_path = ''
as $$
declare
  inputid text := nullif(payload->>'inputid', '');
  current_email text := public.life_pilot_user_email();
  current_is_admin boolean := public.life_pilot_is_admin();
begin
  return query
  select
    e.id, e.master_graph_url, e.master_url, e.start_date, e.end_date,
    e.start_time, e.end_time, e.country, e.city, e.location, e.name,
    e.type, e.description, e.fee, e.unit, e.sub_events, e.account,
    e.repeat_options, e.reminder_options, e.is_holiday,
    e.is_taiwan_holiday, e.is_approved, e.age_min, e.age_max,
    e.is_free, e.price_min, e.price_max, e.is_outdoor,
    f.is_like, f.is_dislike, e.source, e.lat, e.lng, e.map_lat, e.map_lng
  from public.recommended_attractions e
  left join public.recommended_events_favor f
    on e.id = f.id and lower(f.account) = current_email
  where (
      e.is_approved is true
      or lower(e.account) = current_email
      or current_is_admin
    )
    and (inputid is null or e.id = inputid)
  order by
    case
      when f.is_like is true then 0
      when f.is_dislike is true then 2
      else 1
    end,
    e.city, e.name;
end;
$$;

create function public.get_filtered_recommended_events(payload json)
returns table(
  id text, master_graph_url text, master_url text,
  start_date timestamptz, end_date timestamptz,
  start_time text, end_time text,
  country text, city text, location text, name text, type text,
  description text, fee text, unit text, sub_events jsonb, account text,
  repeat_options text, reminder_options text[], is_holiday boolean,
  is_taiwan_holiday boolean, is_approved boolean, age_min numeric,
  age_max numeric, is_free boolean, price_min numeric, price_max numeric,
  is_outdoor boolean, is_like boolean, is_dislike boolean, source text,
  lat double precision, lng double precision,
  map_lat double precision, map_lng double precision
)
language plpgsql
stable
set search_path = ''
as $$
declare
  inputid text := nullif(payload->>'inputid', '');
  inputdates date := nullif(payload->>'inputdates', '')::date;
  inputdatee date := nullif(payload->>'inputdatee', '')::date;
  inputuser text := public.life_pilot_user_email();
  current_is_admin boolean := public.life_pilot_is_admin();
begin
  if auth.uid() is null or inputuser = '' then
    raise exception 'Authentication required';
  end if;

  return query
  select
    e.id, e.master_graph_url, e.master_url, e.start_date, e.end_date,
    e.start_time, e.end_time, e.country, e.city, e.location, e.name,
    e.type, e.description, e.fee, e.unit, e.sub_events, e.account,
    e.repeat_options, e.reminder_options, e.is_holiday,
    e.is_taiwan_holiday, e.is_approved, e.age_min, e.age_max,
    e.is_free, e.price_min, e.price_max, e.is_outdoor,
    f.is_like, f.is_dislike, e.source, e.lat, e.lng, e.map_lat, e.map_lng
  from public.recommended_events e
  left join public.recommended_events_favor f
    on e.id = f.id and lower(f.account) = inputuser
  where (
      current_is_admin
      or lower(e.account) = inputuser
      or lower(e.account) = 'minavi@alumni.nccu.edu.tw'
      or coalesce(e.is_approved, false) is true
    )
    and (
      (e.end_date is null and e.start_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
      or
      (e.end_date is not null and e.end_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
    )
    and (inputid is null or e.id = inputid)
  order by
    case
      when f.is_like is true then 0
      when f.is_dislike is true then 2
      else 1
    end,
    case
      when e.start_date < current_date then coalesce(e.end_date, current_date)
      else e.start_date
    end,
    coalesce(e.start_time::time, time '23:59:59'),
    coalesce(e.end_date, coalesce(e.start_date, current_date)),
    coalesce(e.end_time::time, time '23:59:59'),
    e.city, e.name;
end;
$$;

revoke all on function public.get_filtered_calendar_events(json) from public, anon;
revoke all on function public.get_filtered_memory_trace(json) from public, anon;
revoke all on function public.get_filtered_recommended_attractions(json) from public, anon;
revoke all on function public.get_filtered_recommended_events(json) from public, anon;

grant execute on function public.get_filtered_calendar_events(json) to authenticated;
grant execute on function public.get_filtered_memory_trace(json) to authenticated;
grant execute on function public.get_filtered_recommended_attractions(json) to authenticated;
grant execute on function public.get_filtered_recommended_events(json) to authenticated;

commit;
