begin;

-- Incremental triggers keep the ordinary dashboard read cheap. A forced
-- refresh also rebuilds this one vendor's aggregate from source rows, so a
-- previously missed trigger or an administrator mutation cannot leave a
-- permanently stale published/pending count.
create or replace function public.life_pilot_rebuild_vendor_dashboard_aggregate(
  p_account text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_account text := lower(trim(p_account));
begin
  if nullif(v_account, '') is null then
    raise exception 'invalid_vendor_account' using errcode = '22023';
  end if;

  insert into public.vendor_dashboard_aggregates(
    account, published, pending, page_views, card_clicks,
    registration_clicks, saves, like_counts, dislike_counts, updated_at
  )
  select v_account,
    count(*) filter (where coalesce(source.is_approved, false)),
    count(*) filter (where not coalesce(source.is_approved, false)),
    coalesce(sum(source.page_views), 0),
    coalesce(sum(source.card_clicks), 0),
    coalesce(sum(source.registration_clicks), 0),
    coalesce(sum(source.saves), 0),
    coalesce(sum(source.like_counts), 0),
    coalesce(sum(source.dislike_counts), 0),
    now()
  from (
    select event.is_approved, event.page_views, event.card_clicks,
      event.registration_clicks, event.saves, event.like_counts,
      event.dislike_counts
    from public.recommended_events event
    where lower(trim(event.account)) = v_account
    union all
    select attraction.is_approved, attraction.page_views,
      attraction.card_clicks, attraction.registration_clicks,
      attraction.saves, attraction.like_counts, attraction.dislike_counts
    from public.recommended_attractions attraction
    where lower(trim(attraction.account)) = v_account
  ) source
  on conflict (account) do update set
    published = excluded.published,
    pending = excluded.pending,
    page_views = excluded.page_views,
    card_clicks = excluded.card_clicks,
    registration_clicks = excluded.registration_clicks,
    saves = excluded.saves,
    like_counts = excluded.like_counts,
    dislike_counts = excluded.dislike_counts,
    updated_at = excluded.updated_at;
end;
$function$;

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
  else
    perform public.life_pilot_rebuild_vendor_dashboard_aggregate(v_email);
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

revoke all on function public.life_pilot_rebuild_vendor_dashboard_aggregate(text)
  from public, anon, authenticated;
revoke all on function public.life_pilot_cached_vendor_dashboard_metrics(
  timestamp with time zone, boolean
) from public, anon;
grant execute on function public.life_pilot_cached_vendor_dashboard_metrics(
  timestamp with time zone, boolean
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
