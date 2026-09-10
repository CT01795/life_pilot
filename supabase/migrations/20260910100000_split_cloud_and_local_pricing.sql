begin;

alter table public.subscription_pricing_versions
  add column if not exists storage_plan text not null default 'cloud'
    check (storage_plan in ('cloud', 'local'));

-- Existing pricing rows predate storage-specific plans and therefore become
-- cloud versions. Seed a separate Local Plus version so both next-payment
-- offers are visible immediately; administrators can replace it later by
-- creating a newer effective local version.
insert into public.subscription_pricing_versions(
  version_name, storage_plan, effective_at, quarterly_price_twd,
  calendar_quota, accounting_quota, point_quota, memory_quota,
  game_question_quota, calendar_share_quota, image_megabytes,
  answer_history_days, created_by
)
select
  source.version_name || ' Local Plus', 'local', source.effective_at,
  source.quarterly_price_twd,
  0, 0, 0, 0, 0, 0, 0, 1, source.created_by
from public.subscription_pricing_versions source
where source.storage_plan = 'cloud'
  and source.is_active
  and not exists (
    select 1 from public.subscription_pricing_versions local_version
    where local_version.storage_plan = 'local'
  )
order by source.effective_at desc, source.created_at desc
limit 1;

create index if not exists subscription_pricing_versions_plan_effective_idx
  on public.subscription_pricing_versions(storage_plan, effective_at desc)
  where is_active;

drop function if exists public.admin_create_subscription_pricing_version(
  text, timestamptz, integer, integer, integer, integer, integer,
  integer, integer, integer, integer
);

create or replace function public.admin_create_subscription_pricing_version(
  p_version_name text,
  p_storage_plan text,
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
  if p_storage_plan not in ('cloud', 'local') then
    raise exception 'invalid_storage_plan';
  end if;
  if nullif(trim(p_version_name), '') is null or p_effective_at is null
     or p_quarterly_price_twd <= 0 then
    raise exception 'invalid_pricing_version';
  end if;
  if p_storage_plan = 'cloud' and
     (least(p_calendar_quota, p_accounting_quota, p_point_quota,
       p_memory_quota, p_game_question_quota, p_calendar_share_quota,
       p_image_megabytes, p_answer_history_days) < 0
      or p_answer_history_days = 0) then
    raise exception 'invalid_pricing_version';
  end if;

  insert into public.subscription_pricing_versions(
    version_name, storage_plan, effective_at, quarterly_price_twd,
    calendar_quota, accounting_quota, point_quota, memory_quota,
    game_question_quota, calendar_share_quota, image_megabytes,
    answer_history_days, created_by
  ) values (
    trim(p_version_name), p_storage_plan, p_effective_at, p_quarterly_price_twd,
    case when p_storage_plan = 'local' then 0 else p_calendar_quota end,
    case when p_storage_plan = 'local' then 0 else p_accounting_quota end,
    case when p_storage_plan = 'local' then 0 else p_point_quota end,
    case when p_storage_plan = 'local' then 0 else p_memory_quota end,
    case when p_storage_plan = 'local' then 0 else p_game_question_quota end,
    case when p_storage_plan = 'local' then 0 else p_calendar_share_quota end,
    case when p_storage_plan = 'local' then 0 else p_image_megabytes end,
    case when p_storage_plan = 'local' then 1 else p_answer_history_days end,
    auth.uid()
  ) returning id into new_id;
  return new_id;
end;
$function$;

create or replace function public.life_pilot_plan_limit(p_resource text)
returns bigint language plpgsql stable security definer set search_path = '' as $function$
declare frozen_limit bigint;
begin
  if public.life_pilot_is_admin() then return 9223372036854775807; end if;
  select sum((e.entitlement_snapshot ->> p_resource)::bigint)
    into frozen_limit
  from public.user_subscription_entitlements e
  where e.user_id = auth.uid() and e.storage_plan = 'cloud'
    and e.starts_at <= now() and e.ends_at > now();
  if frozen_limit is not null then return frozen_limit; end if;
  return case p_resource
    when 'calendar_events' then 30 when 'accounting_detail' then 30
    when 'point_record_detail' then 30 when 'memory_trace' then 30
    when 'game_questions' then 50 when 'calendar_shares' then 2
    when 'image_bytes' then 0 else 0 end;
end;
$function$;

revoke all on function public.admin_create_subscription_pricing_version(
  text, text, timestamptz, integer, integer, integer, integer, integer,
  integer, integer, integer, integer
) from public, anon;
grant execute on function public.admin_create_subscription_pricing_version(
  text, text, timestamptz, integer, integer, integer, integer, integer,
  integer, integer, integer, integer
) to authenticated, service_role;

commit;
