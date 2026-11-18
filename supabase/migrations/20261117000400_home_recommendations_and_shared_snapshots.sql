begin;

create or replace function public.get_home_recommendations(
  p_event_city text,
  p_place_city text,
  p_limit integer default 5
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', event_row.id,
        'name', event_row.name,
        'start_date', event_row.start_date,
        'end_date', event_row.end_date,
        'start_time', event_row.start_time,
        'end_time', event_row.end_time,
        'country', event_row.country,
        'city', event_row.city,
        'location', event_row.location,
        'type', event_row.type,
        'is_free', event_row.is_free,
        'description', event_row.description,
        'master_url', event_row.master_url
      ) order by event_row.ordinality)
      from public.get_home_recommended_events(
        p_event_city,
        least(greatest(coalesce(p_limit, 5), 1), 50)
      ) with ordinality event_row
    ), '[]'::jsonb),
    'places', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', place_row.id,
        'name', place_row.name,
        'start_date', place_row.start_date,
        'end_date', place_row.end_date,
        'start_time', place_row.start_time,
        'end_time', place_row.end_time,
        'country', place_row.country,
        'city', place_row.city,
        'location', place_row.location,
        'type', place_row.type,
        'is_free', place_row.is_free,
        'description', place_row.description,
        'master_url', place_row.master_url
      ) order by place_row.ordinality)
      from public.get_home_recommended_places(
        p_place_city,
        least(greatest(coalesce(p_limit, 5), 1), 50)
      ) with ordinality place_row
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_home_recommendations(text,text,integer)
  from public, anon;
grant execute on function public.get_home_recommendations(text,text,integer)
  to authenticated, service_role;

create or replace function public.get_my_ledger_home_snapshots(
  p_month_start timestamptz,
  p_month_end timestamptz,
  p_day_start timestamptz,
  p_day_end timestamptz
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with eligible as materialized (
    select
      s.id as share_id,
      s.kind,
      s.account_id,
      coalesce(a.account, p.account)::text as account_name,
      a.main_currency
    from public.ledger_home_links h
    join public.ledger_read_shares s
      on s.id = h.share_id
     and s.recipient_id = h.recipient_id
     and s.kind = h.kind
    join auth.users recipient on recipient.id = s.recipient_id
    join auth.users owner_user on owner_user.id = s.owner_id
    left join public.accounting_account a
      on s.kind = 'accounting'
     and a.id::text = s.account_id
     and lower(trim(a.created_by)) = lower(trim(owner_user.email))
     and a.is_valid
    left join public.point_record_account p
      on s.kind = 'points'
     and p.id::text = s.account_id
     and lower(trim(p.created_by)) = lower(trim(owner_user.email))
     and p.is_valid
    where recipient.id = auth.uid()
      and (recipient.banned_until is null or recipient.banned_until <= now())
      and public.life_pilot_ledger_share_owner_eligible(s.owner_id)
      and (
        (a.id is not null and nullif(trim(a.main_currency), '') is not null)
        or p.id is not null
      )
  ), accounting_totals as (
    select
      link.share_id,
      jsonb_build_object(
        'total', coalesce(sum(detail.value), 0),
        'currency', link.main_currency,
        'month', coalesce(sum(detail.value) filter (
          where detail.date >= p_month_start and detail.date < p_month_end
        ), 0),
        'today', coalesce(sum(detail.value) filter (
          where detail.date >= p_day_start and detail.date < p_day_end
        ), 0)
      ) as totals
    from eligible link
    left join public.accounting_detail detail
      on link.kind = 'accounting'
     and detail.account_id::text = link.account_id
     and detail.currency = link.main_currency
     and detail.date is not null
    where link.kind = 'accounting'
    group by link.share_id, link.main_currency
  ), point_totals as (
    select
      link.share_id,
      jsonb_build_object(
        'total', coalesce(sum(detail.value), 0),
        'month', coalesce(sum(detail.value) filter (
          where detail.date >= p_month_start and detail.date < p_month_end
        ), 0),
        'today', coalesce(sum(detail.value) filter (
          where detail.date >= p_day_start and detail.date < p_day_end
        ), 0)
      ) as totals
    from eligible link
    left join public.point_record_detail detail
      on link.kind = 'points'
     and detail.account_id::text = link.account_id
     and detail.date is not null
    where link.kind = 'points'
    group by link.share_id
  ), totals as (
    select * from accounting_totals
    union all
    select * from point_totals
  ), entry_candidates as (
    select
      link.share_id,
      detail.date as occurred_at,
      detail.id::text as entry_id,
      jsonb_build_object(
        'description', detail.description,
        'value', detail.value,
        'currency', detail.currency,
        'secondary_category', detail."group"
      ) as entry
    from eligible link
    join public.accounting_detail detail
      on link.kind = 'accounting'
     and detail.account_id::text = link.account_id
    union all
    select
      link.share_id,
      detail.date,
      detail.id::text,
      jsonb_build_object(
        'description', detail.description,
        'value', detail.value,
        'currency', null,
        'secondary_category', detail."group"
      )
    from eligible link
    join public.point_record_detail detail
      on link.kind = 'points'
     and detail.account_id::text = link.account_id
  ), ranked_entries as (
    select entry_candidates.*,
      row_number() over (
        partition by share_id
        order by occurred_at desc nulls last, entry_id desc
      ) as position
    from entry_candidates
  ), previews as (
    select share_id,
      jsonb_agg(
        jsonb_build_object('entry', entry)
        order by occurred_at desc nulls last, entry_id desc
      ) as entries
    from ranked_entries
    where position <= 5
    group by share_id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'share_id', link.share_id,
      'kind', link.kind,
      'account_name', link.account_name,
      'snapshot', jsonb_build_object(
        'totals', total_row.totals,
        'entries', coalesce(preview.entries, '[]'::jsonb)
      )
    ) order by link.kind
  ), '[]'::jsonb)
  from eligible link
  join totals total_row on total_row.share_id = link.share_id
  left join previews preview on preview.share_id = link.share_id;
$$;

revoke all on function public.get_my_ledger_home_snapshots(
  timestamptz,timestamptz,timestamptz,timestamptz
) from public, anon;
grant execute on function public.get_my_ledger_home_snapshots(
  timestamptz,timestamptz,timestamptz,timestamptz
) to service_role;

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
    jsonb_agg(to_jsonb(rows) order by rows.start_date, rows.start_time nulls last, rows.id),
    '[]'::jsonb
  )
  into v_today_events
  from (
    select
      event.id, event.name, event.start_date, event.start_time,
      event.end_date, event.end_time, event.country, event.city,
      event.location, event.type, event.is_free, event.description,
      event.master_url, event.sub_events, event.is_completed, event.account,
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
