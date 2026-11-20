begin;

-- Historical engagement totals grow with every interaction. Maintain them by
-- delta so opening the vendor dashboard no longer sums every submission row.
-- Date-sensitive active counts remain live queries because time alone can
-- change them without a row mutation.
create table if not exists public.vendor_dashboard_aggregates (
  account text primary key,
  published bigint not null default 0,
  pending bigint not null default 0,
  page_views bigint not null default 0,
  card_clicks bigint not null default 0,
  registration_clicks bigint not null default 0,
  saves bigint not null default 0,
  like_counts bigint not null default 0,
  dislike_counts bigint not null default 0,
  updated_at timestamp with time zone not null default now()
);

alter table public.vendor_dashboard_aggregates enable row level security;
revoke all on table public.vendor_dashboard_aggregates
  from public, anon, authenticated;
grant all on table public.vendor_dashboard_aggregates to service_role;

create or replace function public.life_pilot_apply_vendor_aggregate_delta(
  p_account text,
  p_published bigint,
  p_pending bigint,
  p_page_views bigint,
  p_card_clicks bigint,
  p_registration_clicks bigint,
  p_saves bigint,
  p_like_counts bigint,
  p_dislike_counts bigint
)
returns void
language sql
security definer
set search_path = ''
as $function$
  insert into public.vendor_dashboard_aggregates(
    account, published, pending, page_views, card_clicks,
    registration_clicks, saves, like_counts, dislike_counts, updated_at
  )
  select lower(trim(p_account)), p_published, p_pending, p_page_views,
    p_card_clicks, p_registration_clicks, p_saves, p_like_counts,
    p_dislike_counts, now()
  where nullif(lower(trim(p_account)), '') is not null
  on conflict (account) do update set
    published = greatest(0,
      public.vendor_dashboard_aggregates.published + excluded.published),
    pending = greatest(0,
      public.vendor_dashboard_aggregates.pending + excluded.pending),
    page_views = greatest(0,
      public.vendor_dashboard_aggregates.page_views + excluded.page_views),
    card_clicks = greatest(0,
      public.vendor_dashboard_aggregates.card_clicks + excluded.card_clicks),
    registration_clicks = greatest(0,
      public.vendor_dashboard_aggregates.registration_clicks
        + excluded.registration_clicks),
    saves = greatest(0,
      public.vendor_dashboard_aggregates.saves + excluded.saves),
    like_counts = greatest(0,
      public.vendor_dashboard_aggregates.like_counts + excluded.like_counts),
    dislike_counts = greatest(0,
      public.vendor_dashboard_aggregates.dislike_counts
        + excluded.dislike_counts),
    updated_at = now();
$function$;

create or replace function public.life_pilot_update_vendor_aggregate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if tg_op <> 'INSERT' then
    perform public.life_pilot_apply_vendor_aggregate_delta(
      old.account,
      case when coalesce(old.is_approved, false) then -1 else 0 end,
      case when coalesce(old.is_approved, false) then 0 else -1 end,
      -coalesce(old.page_views, 0),
      -coalesce(old.card_clicks, 0),
      -coalesce(old.registration_clicks, 0),
      -coalesce(old.saves, 0),
      -coalesce(old.like_counts, 0),
      -coalesce(old.dislike_counts, 0)
    );
  end if;
  if tg_op <> 'DELETE' then
    perform public.life_pilot_apply_vendor_aggregate_delta(
      new.account,
      case when coalesce(new.is_approved, false) then 1 else 0 end,
      case when coalesce(new.is_approved, false) then 0 else 1 end,
      coalesce(new.page_views, 0),
      coalesce(new.card_clicks, 0),
      coalesce(new.registration_clicks, 0),
      coalesce(new.saves, 0),
      coalesce(new.like_counts, 0),
      coalesce(new.dislike_counts, 0)
    );
  end if;
  return null;
end;
$function$;

-- A deleted account must not leave historical metrics that a future account
-- reusing the same email could inherit.
create or replace function public.life_pilot_remove_deleted_vendor_aggregate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  delete from public.vendor_dashboard_aggregates aggregate
  where aggregate.account = lower(trim(old.email));
  return old;
end;
$function$;

drop trigger if exists life_pilot_remove_deleted_vendor_aggregate
  on auth.users;
create trigger life_pilot_remove_deleted_vendor_aggregate
after delete on auth.users
for each row execute function
  public.life_pilot_remove_deleted_vendor_aggregate();

drop trigger if exists recommended_events_vendor_aggregate
  on public.recommended_events;
create trigger recommended_events_vendor_aggregate
after insert or delete or update of account, is_approved, page_views,
  card_clicks, registration_clicks, saves, like_counts, dislike_counts
on public.recommended_events
for each row execute function public.life_pilot_update_vendor_aggregate();

drop trigger if exists recommended_attractions_vendor_aggregate
  on public.recommended_attractions;
create trigger recommended_attractions_vendor_aggregate
after insert or delete or update of account, is_approved, page_views,
  card_clicks, registration_clicks, saves, like_counts, dislike_counts
on public.recommended_attractions
for each row execute function public.life_pilot_update_vendor_aggregate();

-- Seed existing data once. Subsequent writes are maintained by the triggers.
insert into public.vendor_dashboard_aggregates(
  account, published, pending, page_views, card_clicks,
  registration_clicks, saves, like_counts, dislike_counts, updated_at
)
select lower(trim(source.account)),
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
  select account, is_approved, page_views, card_clicks,
    registration_clicks, saves, like_counts, dislike_counts
  from public.recommended_events
  union all
  select account, is_approved, page_views, card_clicks,
    registration_clicks, saves, like_counts, dislike_counts
  from public.recommended_attractions
) source
where nullif(lower(trim(source.account)), '') is not null
group by lower(trim(source.account))
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

create or replace function public.get_my_vendor_dashboard_metrics(
  p_day_start timestamp with time zone
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_email text := public.life_pilot_user_email();
  v_aggregate public.vendor_dashboard_aggregates%rowtype;
  v_active_events bigint;
  v_active_attractions bigint;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_day_start is null or not isfinite(p_day_start) then
    raise exception 'invalid_day_boundary' using errcode = '22023';
  end if;

  select aggregate.* into v_aggregate
  from public.vendor_dashboard_aggregates aggregate
  where aggregate.account = v_email;

  select count(*) into v_active_events
  from public.recommended_events event
  where lower(trim(event.account)) = v_email
    and (coalesce(event.end_date, event.start_date) is null
      or coalesce(event.end_date, event.start_date) >= p_day_start);
  select count(*) into v_active_attractions
  from public.recommended_attractions attraction
  where lower(trim(attraction.account)) = v_email
    and (coalesce(attraction.end_date, attraction.start_date) is null
      or coalesce(attraction.end_date, attraction.start_date) >= p_day_start);

  return jsonb_build_object(
    'published', coalesce(v_aggregate.published, 0),
    'pending', coalesce(v_aggregate.pending, 0),
    'active_events', v_active_events,
    'active_attractions', v_active_attractions,
    'totals', jsonb_build_object(
      'page_views', coalesce(v_aggregate.page_views, 0),
      'card_clicks', coalesce(v_aggregate.card_clicks, 0),
      'registration_clicks', coalesce(v_aggregate.registration_clicks, 0),
      'saves', coalesce(v_aggregate.saves, 0),
      'like_counts', coalesce(v_aggregate.like_counts, 0),
      'dislike_counts', coalesce(v_aggregate.dislike_counts, 0)
    ),
    'recent_submissions', public.get_my_vendor_recent_submissions(p_day_start)
  );
end;
$function$;

-- A refresh usually needs only status and metrics. Plans are returned on the
-- first read and shared with the plan manager through the App display cache.
drop function if exists public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone, boolean
);
create or replace function public.get_my_vendor_dashboard_bootstrap(
  p_day_start timestamp with time zone,
  p_force_refresh boolean default false,
  p_include_plans boolean default true
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
    'plans', case when coalesce(p_include_plans, true) then coalesce(
      public.get_pricing_catalog(true) -> 'versions',
      '[]'::jsonb
    ) else null end
  );
end;
$function$;

revoke all on function public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone, boolean, boolean
) from public, anon;
grant execute on function public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone, boolean, boolean
) to authenticated, service_role;
revoke all on function public.life_pilot_apply_vendor_aggregate_delta(
  text, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint
) from public, anon, authenticated;
revoke all on function public.life_pilot_update_vendor_aggregate()
  from public, anon, authenticated;
revoke all on function public.life_pilot_remove_deleted_vendor_aggregate()
  from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
