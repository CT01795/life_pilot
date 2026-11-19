-- Read-only retirement audit. Run only after the batch migration and the new
-- App/Edge deployment are live. This file never drops or changes an object.
with candidate as (
  select to_regprocedure(
    'public.life_pilot_cached_holidays(integer,text)'
  ) as oid
), registered_dependents as (
  select
    d.refobjid as candidate_oid,
    jsonb_agg(distinct jsonb_build_object(
      'class', d.classid::regclass::text,
      'object', pg_describe_object(d.classid, d.objid, d.objsubid)
    )) as items
  from pg_depend d
  join candidate c on c.oid = d.refobjid
  where d.deptype not in ('i', 'e')
  group by d.refobjid
), function_callers as (
  select
    c.oid as candidate_oid,
    jsonb_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text) as items
  from candidate c
  join pg_proc p on p.oid <> c.oid
  join pg_namespace n on n.oid = p.pronamespace
  where c.oid is not null
    and p.prokind in ('f', 'p')
    and n.nspname not in ('pg_catalog', 'information_schema')
    and pg_get_functiondef(p.oid) ilike '%life_pilot_cached_holidays(%'
  group by c.oid
), view_callers as (
  select
    c.oid as candidate_oid,
    jsonb_agg(format('%I.%I', v.schemaname, v.viewname)
              order by v.schemaname, v.viewname) as items
  from candidate c
  join pg_views v on true
  where c.oid is not null
    and v.definition ilike '%life_pilot_cached_holidays(%'
  group by c.oid
), policy_callers as (
  select
    c.oid as candidate_oid,
    jsonb_agg(format('%I.%I:%s', p.schemaname, p.tablename, p.policyname)
              order by p.schemaname, p.tablename, p.policyname) as items
  from candidate c
  join pg_policies p on true
  where c.oid is not null
    and (coalesce(p.qual, '') || ' ' || coalesce(p.with_check, ''))
        ilike '%life_pilot_cached_holidays(%'
  group by c.oid
), setting_callers as (
  select
    c.oid as candidate_oid,
    jsonb_agg(distinct setting order by setting) as items
  from candidate c
  join pg_db_role_setting s on true
  cross join lateral unnest(s.setconfig) setting
  where c.oid is not null
    and setting ilike '%life_pilot_cached_holidays(%'
  group by c.oid
)
select
  c.oid::regprocedure::text as function_name,
  to_regprocedure(
    'public.life_pilot_cached_holidays_batch(integer[],text)'
  ) is not null as replacement_exists,
  coalesce(d.items, '[]'::jsonb) as registered_dependents,
  coalesce(f.items, '[]'::jsonb) as possible_function_callers,
  coalesce(v.items, '[]'::jsonb) as possible_view_callers,
  coalesce(p.items, '[]'::jsonb) as possible_policy_callers,
  coalesce(s.items, '[]'::jsonb) as possible_setting_callers,
  d.items is null and f.items is null and v.items is null
    and p.items is null and s.items is null as database_retirement_ready
from candidate c
left join registered_dependents d on d.candidate_oid = c.oid
left join function_callers f on f.candidate_oid = c.oid
left join view_callers v on v.candidate_oid = c.oid
left join policy_callers p on p.candidate_oid = c.oid
left join setting_callers s on s.candidate_oid = c.oid;

-- Canonical snapshot verification. The 20261112000300 migration already
-- removed runtime legacy-field parsing; this confirms no later write has
-- reintroduced an old key.
with legacy_keys(keys) as (values (array[
  'calendar_quota', 'recommended_event_quota',
  'recommended_attraction_quota', 'accounting_quota', 'point_quota',
  'memory_quota', 'game_question_quota', 'calendar_share_quota',
  'image_megabytes'
]::text[]))
select
  (select count(*) from public.user_subscription_entitlements e, legacy_keys
   where e.entitlement_snapshot ?| legacy_keys.keys) as entitlement_legacy_rows,
  (select count(*) from public.user_subscriptions s, legacy_keys
   where s.entitlement_snapshot ?| legacy_keys.keys) as subscription_legacy_rows;
