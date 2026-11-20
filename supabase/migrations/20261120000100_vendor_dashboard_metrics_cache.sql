begin;

-- Cache the historical dashboard projection for five minutes. Source rows
-- remain authoritative and a manual refresh bypasses the cached value.
create table if not exists public.vendor_dashboard_metrics_cache (
  user_id uuid primary key references auth.users(id) on delete cascade,
  account text not null,
  day_start timestamp with time zone not null,
  metrics jsonb not null,
  refreshed_at timestamp with time zone not null default now()
);

alter table public.vendor_dashboard_metrics_cache enable row level security;
revoke all on table public.vendor_dashboard_metrics_cache
  from public, anon, authenticated;
grant all on table public.vendor_dashboard_metrics_cache to service_role;

create or replace function public.life_pilot_cached_vendor_dashboard_metrics(
  p_day_start timestamp with time zone,
  p_force_refresh boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_email text := public.life_pilot_user_email();
  v_metrics jsonb;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_day_start is null or not isfinite(p_day_start) then
    raise exception 'invalid_day_boundary' using errcode = '22023';
  end if;

  if not coalesce(p_force_refresh, false) then
    select cache.metrics
      into v_metrics
    from public.vendor_dashboard_metrics_cache cache
    where cache.user_id = auth.uid()
      and cache.day_start = p_day_start
      and cache.refreshed_at > now() - interval '5 minutes';
    if found then return v_metrics; end if;
  end if;

  v_metrics := public.get_my_vendor_dashboard_metrics(p_day_start);
  insert into public.vendor_dashboard_metrics_cache(
    user_id, account, day_start, metrics, refreshed_at
  ) values (
    auth.uid(), v_email, p_day_start, v_metrics, now()
  )
  on conflict (user_id) do update set
    account = excluded.account,
    day_start = excluded.day_start,
    metrics = excluded.metrics,
    refreshed_at = excluded.refreshed_at;
  return v_metrics;
end;
$function$;

-- Content changes invalidate the aggregate. Interaction counter updates do
-- not delete it; those appear after the TTL or a forced manual refresh.
create or replace function public.life_pilot_invalidate_vendor_metrics_cache()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_old_account text;
  v_new_account text;
begin
  if tg_op <> 'INSERT' then
    v_old_account := lower(trim(old.account));
  end if;
  if tg_op <> 'DELETE' then
    v_new_account := lower(trim(new.account));
  end if;
  delete from public.vendor_dashboard_metrics_cache cache
  where cache.account = v_old_account or cache.account = v_new_account;
  return null;
end;
$function$;

drop trigger if exists recommended_events_vendor_metrics_rows
  on public.recommended_events;
create trigger recommended_events_vendor_metrics_rows
after insert or delete on public.recommended_events
for each row execute function public.life_pilot_invalidate_vendor_metrics_cache();

drop trigger if exists recommended_events_vendor_metrics_content
  on public.recommended_events;
create trigger recommended_events_vendor_metrics_content
after update of account, name, city, start_date, end_date, is_approved
on public.recommended_events
for each row execute function public.life_pilot_invalidate_vendor_metrics_cache();

drop trigger if exists recommended_attractions_vendor_metrics_rows
  on public.recommended_attractions;
create trigger recommended_attractions_vendor_metrics_rows
after insert or delete on public.recommended_attractions
for each row execute function public.life_pilot_invalidate_vendor_metrics_cache();

drop trigger if exists recommended_attractions_vendor_metrics_content
  on public.recommended_attractions;
create trigger recommended_attractions_vendor_metrics_content
after update of account, name, city, start_date, end_date, is_approved
on public.recommended_attractions
for each row execute function public.life_pilot_invalidate_vendor_metrics_cache();

-- Mutations only need these five small cards, not subscription, plan and all
-- historical performance data again.
create or replace function public.get_my_vendor_recent_submissions(
  p_day_start timestamp with time zone
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  with source as (
    select e.id, e.name, e.city, e.start_date, e.end_date,
      coalesce(e.is_approved, false) as is_approved,
      true as is_activity
    from public.recommended_events e
    where auth.uid() is not null
      and lower(trim(e.account)) = public.life_pilot_user_email()
    union all
    select a.id, a.name, a.city, a.start_date, a.end_date,
      coalesce(a.is_approved, false) as is_approved,
      false as is_activity
    from public.recommended_attractions a
    where auth.uid() is not null
      and lower(trim(a.account)) = public.life_pilot_user_email()
  ), ranked as (
    select source.*,
      row_number() over (
        order by is_approved,
          (coalesce(start_date, end_date) is null),
          case when coalesce(start_date, end_date) >= p_day_start
            then 0 else 1 end,
          case when coalesce(start_date, end_date) >= p_day_start
            then coalesce(start_date, end_date) end asc nulls last,
          case when coalesce(start_date, end_date) < p_day_start
            then coalesce(start_date, end_date) end desc nulls last,
          is_activity desc,
          id
      ) as ordinal
    from source
  )
  select coalesce(
    jsonb_agg(to_jsonb(ranked) - 'ordinal' order by ordinal),
    '[]'::jsonb
  )
  from ranked
  where ordinal <= 5;
$function$;

-- Changing the signature creates an overload, so retire the original wrapper
-- before exposing the force-refresh argument used by the current App.
drop function if exists public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone
);
create or replace function public.get_my_vendor_dashboard_bootstrap(
  p_day_start timestamp with time zone,
  p_force_refresh boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform public.ensure_my_vendor_account();
  return jsonb_build_object(
    'status', public.get_my_vendor_subscription_status(),
    'metrics', public.life_pilot_cached_vendor_dashboard_metrics(
      p_day_start,
      p_force_refresh
    ),
    'plans', coalesce(
      public.get_pricing_catalog(true) -> 'versions',
      '[]'::jsonb
    )
  );
end;
$function$;

revoke all on function public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone, boolean
) from public, anon;
grant execute on function public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone, boolean
) to authenticated, service_role;
revoke all on function public.life_pilot_cached_vendor_dashboard_metrics(
  timestamp with time zone, boolean
) from public, anon;
grant execute on function public.life_pilot_cached_vendor_dashboard_metrics(
  timestamp with time zone, boolean
) to authenticated, service_role;
revoke all on function public.get_my_vendor_recent_submissions(
  timestamp with time zone
) from public, anon;
grant execute on function public.get_my_vendor_recent_submissions(
  timestamp with time zone
) to authenticated, service_role;
revoke all on function public.life_pilot_invalidate_vendor_metrics_cache()
  from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
