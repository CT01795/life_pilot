begin;

create table if not exists public.subscription_pricing_versions (
  id uuid primary key default gen_random_uuid(),
  version_name text not null,
  effective_at timestamptz not null,
  quarterly_price_twd integer not null check (quarterly_price_twd > 0),
  calendar_quota integer not null check (calendar_quota >= 0),
  accounting_quota integer not null check (accounting_quota >= 0),
  point_quota integer not null check (point_quota >= 0),
  memory_quota integer not null check (memory_quota >= 0),
  game_question_quota integer not null check (game_question_quota >= 0),
  calendar_share_quota integer not null check (calendar_share_quota >= 0),
  image_megabytes integer not null check (image_megabytes >= 0),
  answer_history_days integer not null check (answer_history_days > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

alter table public.subscription_pricing_versions enable row level security;
drop policy if exists subscription_pricing_versions_select_authenticated
  on public.subscription_pricing_versions;
create policy subscription_pricing_versions_select_authenticated
  on public.subscription_pricing_versions for select to authenticated using (true);
revoke all on public.subscription_pricing_versions from public, anon, authenticated;
grant select on public.subscription_pricing_versions to authenticated;
grant all on public.subscription_pricing_versions to service_role;

insert into public.subscription_pricing_versions(
  version_name, effective_at, quarterly_price_twd,
  calendar_quota, accounting_quota, point_quota, memory_quota,
  game_question_quota, calendar_share_quota, image_megabytes,
  answer_history_days, created_by
)
select '2026-Q3', '2026-09-08 00:00:00+08'::timestamptz, 129,
       300, 300, 300, 300, 500, 5, 300, 365, auth.uid()
where not exists (select 1 from public.subscription_pricing_versions);

alter table public.user_subscriptions
  add column if not exists pricing_version_id uuid
    references public.subscription_pricing_versions(id),
  add column if not exists quota_multiplier integer not null default 1
    check (quota_multiplier >= 1),
  add column if not exists storage_plan text not null default 'cloud'
    check (storage_plan in ('cloud', 'local')),
  add column if not exists quarterly_price_paid_twd integer,
  add column if not exists entitlement_snapshot jsonb,
  add column if not exists last_data_activity_at timestamptz not null default now();

create table if not exists public.user_subscription_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pricing_version_id uuid not null references public.subscription_pricing_versions(id),
  storage_plan text not null check (storage_plan in ('cloud', 'local')),
  quota_multiplier integer not null check (quota_multiplier >= 1),
  quarterly_price_paid_twd integer not null check (quarterly_price_paid_twd > 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  entitlement_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);
create index if not exists user_subscription_entitlements_active_idx
  on public.user_subscription_entitlements(user_id, starts_at, ends_at);
alter table public.user_subscription_entitlements enable row level security;
drop policy if exists user_subscription_entitlements_select_own_or_admin
  on public.user_subscription_entitlements;
create policy user_subscription_entitlements_select_own_or_admin
  on public.user_subscription_entitlements for select to authenticated
  using (user_id = auth.uid() or public.life_pilot_is_admin());
revoke all on public.user_subscription_entitlements from public, anon, authenticated;
grant select on public.user_subscription_entitlements to authenticated;
grant all on public.user_subscription_entitlements to service_role;

create or replace function public.life_pilot_pricing_snapshot(
  p_pricing_version_id uuid, p_multiplier integer
)
returns jsonb language sql stable security definer set search_path = '' as $function$
  select jsonb_build_object(
    'calendar_events', p.calendar_quota::bigint * p_multiplier,
    'accounting_detail', p.accounting_quota::bigint * p_multiplier,
    'point_record_detail', p.point_quota::bigint * p_multiplier,
    'memory_trace', p.memory_quota::bigint * p_multiplier,
    'game_questions', p.game_question_quota::bigint * p_multiplier,
    'calendar_shares', p.calendar_share_quota::bigint * p_multiplier,
    'image_bytes', p.image_megabytes::bigint * 1024 * 1024 * p_multiplier,
    'answer_history_days', p.answer_history_days
  ) from public.subscription_pricing_versions p
  where p.id = p_pricing_version_id;
$function$;

create or replace function public.admin_create_subscription_pricing_version(
  p_version_name text,
  p_effective_at timestamptz,
  p_quarterly_price_twd integer,
  p_calendar_quota integer,
  p_accounting_quota integer,
  p_point_quota integer,
  p_memory_quota integer,
  p_game_question_quota integer,
  p_calendar_share_quota integer,
  p_image_megabytes integer,
  p_answer_history_days integer
)
returns uuid language plpgsql security definer set search_path = '' as $function$
declare new_id uuid;
begin
  if not public.life_pilot_is_admin() then raise exception 'admin_required'; end if;
  if nullif(trim(p_version_name), '') is null or p_effective_at is null
     or least(p_quarterly_price_twd, p_calendar_quota, p_accounting_quota,
       p_point_quota, p_memory_quota, p_game_question_quota,
       p_calendar_share_quota, p_image_megabytes, p_answer_history_days) < 0
     or p_quarterly_price_twd = 0 or p_answer_history_days = 0 then
    raise exception 'invalid_pricing_version';
  end if;
  insert into public.subscription_pricing_versions(
    version_name, effective_at, quarterly_price_twd,
    calendar_quota, accounting_quota, point_quota, memory_quota,
    game_question_quota, calendar_share_quota, image_megabytes,
    answer_history_days, created_by
  ) values (
    trim(p_version_name), p_effective_at, p_quarterly_price_twd,
    p_calendar_quota, p_accounting_quota, p_point_quota, p_memory_quota,
    p_game_question_quota, p_calendar_share_quota, p_image_megabytes,
    p_answer_history_days, auth.uid()
  ) returning id into new_id;
  return new_id;
end;
$function$;

create or replace function public.get_subscription_pricing_versions()
returns setof public.subscription_pricing_versions
language sql stable security definer set search_path = '' as $function$
  select p.* from public.subscription_pricing_versions p
  where p.is_active or public.life_pilot_is_admin()
  order by p.effective_at desc, p.created_at desc;
$function$;

create or replace function public.admin_set_user_subscription_v2(
  p_email text,
  p_plan text,
  p_storage_plan text,
  p_pricing_version_id uuid,
  p_quota_multiplier integer,
  p_expires_at timestamptz,
  p_admin_note text default null
)
returns void language plpgsql security definer set search_path = '' as $function$
declare
  target_user_id uuid;
  price public.subscription_pricing_versions%rowtype;
  snapshot jsonb;
begin
  if not public.life_pilot_is_admin() then raise exception 'admin_required'; end if;
  if p_plan not in ('free', 'plus') then raise exception 'invalid_plan'; end if;
  if p_storage_plan not in ('cloud', 'local') then raise exception 'invalid_storage_plan'; end if;
  if p_quota_multiplier is null or p_quota_multiplier < 1 then raise exception 'invalid_multiplier'; end if;
  select id into target_user_id from auth.users
   where lower(email) = lower(trim(p_email)) limit 1;
  if target_user_id is null then raise exception 'user_not_found'; end if;

  if p_plan = 'free' then
    p_expires_at := null;
    p_pricing_version_id := null;
    snapshot := null;
    delete from public.user_subscription_entitlements
      where user_id = target_user_id and ends_at > now();
  else
    if p_expires_at is null or p_expires_at <= now() then raise exception 'expiry_required'; end if;
    select * into price from public.subscription_pricing_versions
     where id = p_pricing_version_id and is_active;
    if price.id is null then raise exception 'pricing_version_not_found'; end if;
    snapshot := jsonb_build_object(
      'calendar_events', price.calendar_quota::bigint * p_quota_multiplier,
      'accounting_detail', price.accounting_quota::bigint * p_quota_multiplier,
      'point_record_detail', price.point_quota::bigint * p_quota_multiplier,
      'memory_trace', price.memory_quota::bigint * p_quota_multiplier,
      'game_questions', price.game_question_quota::bigint * p_quota_multiplier,
      'calendar_shares', price.calendar_share_quota::bigint * p_quota_multiplier,
      'image_bytes', price.image_megabytes::bigint * 1024 * 1024 * p_quota_multiplier,
      'answer_history_days', price.answer_history_days
    );
  end if;

  insert into public.user_subscriptions(
    user_id, plan, status, current_period_end, expires_at, updated_at,
    updated_by, admin_note, pricing_version_id, quota_multiplier,
    storage_plan, quarterly_price_paid_twd, entitlement_snapshot
  ) values (
    target_user_id, p_plan, case when p_plan = 'plus' then 'active' else 'inactive' end,
    p_expires_at, p_expires_at, now(), auth.uid(), nullif(trim(p_admin_note), ''),
    p_pricing_version_id, p_quota_multiplier, p_storage_plan,
    case when p_plan = 'plus' then price.quarterly_price_twd * p_quota_multiplier end,
    snapshot
  ) on conflict (user_id) do update set
    plan = excluded.plan, status = excluded.status,
    current_period_end = excluded.current_period_end, expires_at = excluded.expires_at,
    updated_at = now(), updated_by = auth.uid(), admin_note = excluded.admin_note,
    pricing_version_id = excluded.pricing_version_id,
    quota_multiplier = excluded.quota_multiplier,
    storage_plan = excluded.storage_plan,
    quarterly_price_paid_twd = excluded.quarterly_price_paid_twd,
    entitlement_snapshot = excluded.entitlement_snapshot;

  if p_plan = 'plus' then
    delete from public.user_subscription_entitlements
      where user_id = target_user_id and ends_at > now();
    insert into public.user_subscription_entitlements(
      user_id, pricing_version_id, storage_plan, quota_multiplier,
      quarterly_price_paid_twd, starts_at, ends_at,
      entitlement_snapshot, created_by
    ) values (
      target_user_id, price.id, p_storage_plan, p_quota_multiplier,
      price.quarterly_price_twd * p_quota_multiplier, now(), p_expires_at,
      snapshot, auth.uid()
    );
  end if;
end;
$function$;

create or replace function public.admin_add_user_subscription_entitlement(
  p_email text,
  p_storage_plan text,
  p_pricing_version_id uuid,
  p_quota_multiplier integer,
  p_ends_at timestamptz,
  p_admin_note text default null
)
returns uuid language plpgsql security definer set search_path = '' as $function$
declare
  target_user_id uuid;
  price public.subscription_pricing_versions%rowtype;
  entitlement_id uuid;
  snapshot jsonb;
begin
  if not public.life_pilot_is_admin() then raise exception 'admin_required'; end if;
  if p_storage_plan not in ('cloud', 'local') or p_quota_multiplier < 1
     or p_ends_at is null or p_ends_at <= now() then raise exception 'invalid_entitlement'; end if;
  select id into target_user_id from auth.users
   where lower(email) = lower(trim(p_email)) limit 1;
  if target_user_id is null then raise exception 'user_not_found'; end if;
  select * into price from public.subscription_pricing_versions
   where id = p_pricing_version_id and is_active;
  if price.id is null then raise exception 'pricing_version_not_found'; end if;
  snapshot := public.life_pilot_pricing_snapshot(price.id, p_quota_multiplier);
  insert into public.user_subscription_entitlements(
    user_id, pricing_version_id, storage_plan, quota_multiplier,
    quarterly_price_paid_twd, starts_at, ends_at,
    entitlement_snapshot, created_by
  ) values (
    target_user_id, price.id, p_storage_plan, p_quota_multiplier,
    price.quarterly_price_twd * p_quota_multiplier, now(), p_ends_at,
    snapshot, auth.uid()
  ) returning id into entitlement_id;
  insert into public.user_subscriptions(
    user_id, plan, status, current_period_end, expires_at, updated_at,
    updated_by, admin_note, storage_plan, pricing_version_id,
    quota_multiplier, quarterly_price_paid_twd, entitlement_snapshot
  ) values (
    target_user_id, 'plus', 'active', p_ends_at, p_ends_at, now(),
    auth.uid(), nullif(trim(p_admin_note), ''), p_storage_plan, price.id,
    p_quota_multiplier, price.quarterly_price_twd * p_quota_multiplier,
    snapshot
  ) on conflict (user_id) do update set
    plan = 'plus', status = 'active',
    current_period_end = greatest(coalesce(public.user_subscriptions.current_period_end, p_ends_at), p_ends_at),
    expires_at = greatest(coalesce(public.user_subscriptions.expires_at, p_ends_at), p_ends_at),
    updated_at = now(), updated_by = auth.uid(),
    admin_note = coalesce(nullif(trim(p_admin_note), ''), public.user_subscriptions.admin_note),
    storage_plan = p_storage_plan,
    pricing_version_id = price.id,
    quota_multiplier = p_quota_multiplier,
    quarterly_price_paid_twd = price.quarterly_price_twd * p_quota_multiplier,
    entitlement_snapshot = snapshot;
  return entitlement_id;
end;
$function$;

create or replace function public.life_pilot_answer_retention_days_for_user(p_user_id uuid)
returns integer language sql stable security definer set search_path = '' as $function$
  select coalesce(max((e.entitlement_snapshot ->> 'answer_history_days')::integer), 30)
  from public.user_subscription_entitlements e
  where e.user_id = p_user_id and e.starts_at <= now() and e.ends_at > now();
$function$;

create or replace function public.cleanup_expired_game_answer_history()
returns integer language plpgsql security definer set search_path = '' as $function$
declare table_name text; affected integer; deleted_count integer := 0;
begin
  perform pg_advisory_xact_lock(hashtext('life_pilot_game_answer_retention'));
  foreach table_name in array array[
    'game_grammar_user', 'game_sentence_user', 'game_translation_user',
    'game_social_user', 'game_speaking_user', 'game_word_search_user'
  ] loop
    execute format(
      'delete from public.%I r using auth.users u '
      'where r.owner_id = u.id and r.created_at < now() - make_interval(days => public.life_pilot_answer_retention_days_for_user(u.id))',
      table_name
    );
    get diagnostics affected = row_count;
    deleted_count := deleted_count + affected;
  end loop;
  return deleted_count;
end;
$function$;

create or replace function public.life_pilot_plan_limit(p_resource text)
returns bigint language plpgsql stable security definer set search_path = '' as $function$
declare subscription_row public.user_subscriptions%rowtype; frozen_limit bigint;
begin
  if public.life_pilot_is_admin() then return 9223372036854775807; end if;
  select * into subscription_row from public.user_subscriptions where user_id = auth.uid();
  if exists (
    select 1 from public.user_subscription_entitlements e
    where e.user_id = auth.uid() and e.storage_plan = 'local'
      and e.starts_at <= now() and e.ends_at > now()
  ) then
    return 9223372036854775807;
  end if;
  select sum((e.entitlement_snapshot ->> p_resource)::bigint)
    into frozen_limit
  from public.user_subscription_entitlements e
  where e.user_id = auth.uid() and e.storage_plan = 'cloud'
    and e.starts_at <= now() and e.ends_at > now();
  if frozen_limit is not null then
    return frozen_limit;
  end if;
  return case p_resource
    when 'calendar_events' then 30 when 'accounting_detail' then 30
    when 'point_record_detail' then 30 when 'memory_trace' then 30
    when 'game_questions' then 50 when 'calendar_shares' then 2
    when 'image_bytes' then 0 else 0 end;
end;
$function$;

create or replace function public.get_my_subscription_entitlements()
returns table(
  id uuid, version_name text, effective_at timestamptz,
  storage_plan text, quota_multiplier integer,
  quarterly_price_paid_twd integer, starts_at timestamptz,
  ends_at timestamptz, entitlement_snapshot jsonb
)
language sql stable security definer set search_path = '' as $function$
  select e.id, p.version_name, p.effective_at, e.storage_plan,
    e.quota_multiplier, e.quarterly_price_paid_twd,
    e.starts_at, e.ends_at, e.entitlement_snapshot
  from public.user_subscription_entitlements e
  join public.subscription_pricing_versions p on p.id = e.pricing_version_id
  where e.user_id = auth.uid() and e.ends_at > now()
  order by e.ends_at, e.created_at;
$function$;

-- PostgreSQL cannot change a RETURNS TABLE layout through CREATE OR REPLACE.
-- Drop the previous zero-argument version before installing the expanded result.
drop function if exists public.get_my_subscription_status();
create function public.get_my_subscription_status()
returns table(
  plan text, status text, current_period_end timestamptz,
  cancel_at_period_end boolean, storage_plan text,
  quota_multiplier integer, quarterly_price_paid_twd integer,
  pricing_version_name text, pricing_effective_at timestamptz,
  last_data_activity_at timestamptz
)
language sql stable security definer set search_path = '' as $function$
  select public.life_pilot_subscription_plan(), coalesce(s.status, 'inactive'),
    case when s.plan = 'free' then null else coalesce(s.current_period_end, s.expires_at) end,
    coalesce(s.cancel_at_period_end, false), coalesce(s.storage_plan, 'cloud'),
    coalesce(s.quota_multiplier, 1), s.quarterly_price_paid_twd,
    p.version_name, p.effective_at, s.last_data_activity_at
  from (select 1) seed
  left join public.user_subscriptions s on s.user_id = auth.uid()
  left join public.subscription_pricing_versions p on p.id = s.pricing_version_id;
$function$;

create or replace function public.life_pilot_touch_data_activity()
returns trigger language plpgsql security definer set search_path = '' as $function$
begin
  if auth.uid() is not null then
    insert into public.user_subscriptions(user_id, plan, status, expires_at, last_data_activity_at)
    values (auth.uid(), 'free', 'inactive', null, now())
    on conflict (user_id) do update set last_data_activity_at = now();
  end if;
  return null;
end;
$function$;

do $block$
declare table_name text;
begin
  foreach table_name in array array[
    'calendar_events', 'accounting_detail', 'point_record_detail', 'memory_trace',
    'game_grammar', 'game_sentence', 'game_translation', 'game_social_scenarios'
  ] loop
    execute format('drop trigger if exists life_pilot_touch_activity on public.%I', table_name);
    execute format(
      'create trigger life_pilot_touch_activity after insert or update on public.%I '
      'for each statement execute function public.life_pilot_touch_data_activity()', table_name
    );
  end loop;
end;
$block$;

create or replace function public.cleanup_inactive_free_accounts()
returns integer language plpgsql security definer set search_path = '' as $function$
declare deleted_count integer;
begin
  perform pg_advisory_xact_lock(hashtext('life_pilot_inactive_free_accounts'));
  with targets as (
    select u.id from auth.users u
    left join public.user_subscriptions s on s.user_id = u.id
    where coalesce(s.plan, 'free') = 'free'
      and coalesce(s.last_data_activity_at, u.created_at) < now() - interval '3 months'
      and coalesce((u.raw_app_meta_data ->> 'role') = 'admin', false) = false
  ), deleted as (
    delete from auth.users u using targets t where u.id = t.id returning u.id
  ) select count(*) into deleted_count from deleted;
  return deleted_count;
end;
$function$;

revoke all on function public.admin_create_subscription_pricing_version(text,timestamptz,integer,integer,integer,integer,integer,integer,integer,integer,integer) from public, anon, authenticated;
grant execute on function public.admin_create_subscription_pricing_version(text,timestamptz,integer,integer,integer,integer,integer,integer,integer,integer,integer) to authenticated;
revoke all on function public.get_subscription_pricing_versions() from public, anon;
grant execute on function public.get_subscription_pricing_versions() to authenticated;
revoke all on function public.admin_set_user_subscription_v2(text,text,text,uuid,integer,timestamptz,text) from public, anon, authenticated;
grant execute on function public.admin_set_user_subscription_v2(text,text,text,uuid,integer,timestamptz,text) to authenticated;
revoke all on function public.admin_add_user_subscription_entitlement(text,text,uuid,integer,timestamptz,text) from public, anon, authenticated;
grant execute on function public.admin_add_user_subscription_entitlement(text,text,uuid,integer,timestamptz,text) to authenticated;
revoke all on function public.get_my_subscription_entitlements() from public, anon;
grant execute on function public.get_my_subscription_entitlements() to authenticated;
revoke all on function public.get_my_subscription_status() from public, anon;
grant execute on function public.get_my_subscription_status() to authenticated;
revoke all on function public.life_pilot_answer_retention_days_for_user(uuid) from public, anon, authenticated;
grant execute on function public.life_pilot_answer_retention_days_for_user(uuid) to service_role;
revoke all on function public.cleanup_inactive_free_accounts() from public, anon, authenticated;
grant execute on function public.cleanup_inactive_free_accounts() to service_role;

commit;
