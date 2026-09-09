begin;

drop function if exists public.get_filtered_calendar_events(json);

create function public.get_filtered_calendar_events(payload json)
returns table(
  id text, master_graph_url text, master_url text,
  start_date timestamptz, end_date timestamptz,
  start_time text, end_time text,
  country text, city text, location text, name text, type text,
  description text, fee text, unit text, sub_events jsonb, account text,
  repeat_options text, reminder_options text[], is_completed boolean,
  is_holiday boolean, is_taiwan_holiday boolean, is_approved boolean,
  age_min numeric, age_max numeric, is_free boolean,
  price_min numeric, price_max numeric, is_outdoor boolean,
  is_like boolean, is_dislike boolean, source text,
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
  current_email text := public.life_pilot_user_email();
begin
  if auth.uid() is null or current_email = '' then
    raise exception 'Authentication required';
  end if;

  return query
  select
    e.id, e.master_graph_url, e.master_url, e.start_date, e.end_date,
    e.start_time, e.end_time, e.country, e.city, e.location, e.name,
    e.type, e.description, e.fee, e.unit, e.sub_events, e.account,
    e.repeat_options, e.reminder_options, e.is_completed, e.is_holiday,
    e.is_taiwan_holiday, e.is_approved, e.age_min, e.age_max,
    e.is_free, e.price_min, e.price_max, e.is_outdoor,
    null::boolean, null::boolean, e.source, e.lat, e.lng,
    e.map_lat, e.map_lng
  from public.calendar_events e
  where (
      lower(trim(e.account)) = current_email
      or exists (
        select 1
        from public.calendar_share_invitations invitation
        join public.calendar_share_events selected
          on selected.invitation_id = invitation.id
        where invitation.status = 'accepted'
          and selected.event_id = e.id
          and lower(trim(invitation.shared_by)) = lower(trim(e.account))
          and lower(trim(invitation.invited_email)) = current_email
      )
    )
    and (
      (e.end_date is null and e.start_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
      or
      (e.end_date is not null and e.end_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
    )
    and (inputid is null or e.id = inputid)
  order by e.start_date, e.start_time, e.account, e.name;
end;
$$;

revoke all on function public.get_filtered_calendar_events(json)
from public, anon;
grant execute on function public.get_filtered_calendar_events(json)
to authenticated;

commit;
