begin;

-- The dashboard only renders schedule timing, location and the external link.
-- Descriptions and sub-events are fetched for one row only when the user asks
-- to copy that event into the memory corridor.
create or replace function public.get_or_create_my_dashboard_core_v2(
  p_expected_email text,
  p_month_start timestamptz,
  p_month_end timestamptz,
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
  v_core jsonb;
  v_shared jsonb;
  v_today_events jsonb;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_month_start is null or p_month_end is null
     or p_day_start is null or p_day_end is null
     or p_month_end <= p_month_start
     or p_month_end > p_month_start + interval '32 days'
     or p_day_end <= p_day_start
     or p_day_end > p_day_start + interval '26 hours'
     or p_day_start < p_month_start
     or p_day_end > p_month_end then
    raise exception 'Invalid dashboard date boundary' using errcode = '22023';
  end if;

  v_core := public.get_or_create_my_dashboard_core(
    p_expected_email, p_day_start, p_day_end
  );
  v_shared := public.get_my_ledger_home_snapshots(
    p_month_start, p_month_end, p_day_start, p_day_end
  );

  select coalesce(
    jsonb_agg(
      to_jsonb(rows)
      order by rows.start_date, rows.start_time nulls last, rows.id
    ),
    '[]'::jsonb
  )
  into v_today_events
  from (
    select
      event.id, event.name, event.start_date, event.start_time,
      event.end_date, event.end_time, event.country, event.city,
      event.location, event.type, event.is_free, event.master_url,
      event.is_completed, event.account,
      lower(trim(event.account)) <> v_email as is_shared
    from public.calendar_events event
    where coalesce(event.is_completed, false) is false
      and event.start_date < p_day_start + interval '3 days'
      and (
        event.end_date >= p_day_start
        or (event.end_date is null and event.start_date >= p_day_start)
      )
      and (
        lower(trim(event.account)) = v_email
        or exists (
          select 1
          from public.calendar_share_invitations invitation
          join public.calendar_share_events selected
            on selected.invitation_id = invitation.id
          where invitation.status = 'accepted'
            and selected.event_id = event.id
            and lower(trim(invitation.shared_by)) = lower(trim(event.account))
            and lower(trim(invitation.invited_email)) = v_email
        )
      )
  ) rows;

  return v_core || jsonb_build_object(
    'shared_ledgers', v_shared,
    'today_events', v_today_events
  );
end;
$$;

revoke all on function public.get_or_create_my_dashboard_core_v2(
  text,timestamptz,timestamptz,timestamptz,timestamptz
) from public, anon;
grant execute on function public.get_or_create_my_dashboard_core_v2(
  text,timestamptz,timestamptz,timestamptz,timestamptz
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
