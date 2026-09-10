begin;

alter table public.subscription_pricing_versions
  add column if not exists storage_plan text not null default 'cloud'
    check (storage_plan in ('cloud', 'local'));

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
    select 1
    from public.subscription_pricing_versions local_version
    where local_version.storage_plan = 'local'
  )
order by source.effective_at desc, source.created_at desc
limit 1;

commit;
