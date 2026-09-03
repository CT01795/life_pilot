begin;

alter table public.user_subscriptions
  add column if not exists downgrade_grace_ends_at timestamptz,
  add column if not exists downgrade_notified_at timestamptz,
  add column if not exists downgrade_cleanup_completed_at timestamptz,
  add column if not exists local_move_started_at timestamptz;

create table if not exists public.subscription_cleanup_audit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  executed_at timestamptz not null default now(),
  reason text not null,
  deleted_counts jsonb not null default '{}'::jsonb
);
alter table public.subscription_cleanup_audit enable row level security;
revoke all on table public.subscription_cleanup_audit
  from public, anon, authenticated;
grant all on table public.subscription_cleanup_audit to service_role;

create or replace function public.life_pilot_begin_subscription_downgrade(
  p_user_id uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  grace_end timestamptz;
  owner_email text;
  has_overage boolean;
begin
  select lower(email) into owner_email from auth.users where id = p_user_id;
  select
    (select count(*) from public.calendar_events where lower(trim(account)) = owner_email) > 30
    or (select count(*) from public.memory_trace where lower(trim(account)) = owner_email) > 30
    or (select count(*) from public.accounting_detail d join public.accounting_account a on a.id = d.account_id where lower(trim(a.created_by)) = owner_email) > 30
    or (select count(*) from public.point_record_detail d join public.point_record_account a on a.id = d.account_id where lower(trim(a.created_by)) = owner_email) > 30
    or ((select count(*) from public.game_grammar where owner_id = p_user_id)
      + (select count(*) from public.game_sentence where owner_id = p_user_id)
      + (select count(*) from public.game_translation where owner_id = p_user_id)
      + (select count(*) from public.game_social_scenarios where owner_id = p_user_id)) > 50
    or (select count(distinct lower(trim(invited_email))) from public.calendar_share_invitations where lower(trim(shared_by)) = owner_email and status in ('pending', 'accepted')) > 2
    or exists (select 1 from public.calendar_events where lower(trim(account)) = owner_email and nullif(trim(master_graph_url), '') is not null)
    or exists (select 1 from public.memory_trace where lower(trim(account)) = owner_email and nullif(trim(master_graph_url), '') is not null)
    or exists (select 1 from public.recommended_events where lower(trim(account)) = owner_email and nullif(trim(master_graph_url), '') is not null)
    or exists (select 1 from public.recommended_attractions where lower(trim(account)) = owner_email and nullif(trim(master_graph_url), '') is not null)
  into has_overage;

  if not coalesce(has_overage, false) then
    update public.user_subscriptions
    set downgrade_grace_ends_at = null,
        downgrade_cleanup_completed_at = null,
        updated_at = now()
    where user_id = p_user_id;
    return null;
  end if;

  update public.user_subscriptions
  set downgrade_grace_ends_at = coalesce(
        downgrade_grace_ends_at,
        coalesce(current_period_end, expires_at, now()) + interval '30 days'
      ),
      downgrade_cleanup_completed_at = null,
      updated_at = now()
  where user_id = p_user_id
    and plan = 'plus'
    and status not in ('active', 'trialing')
  returning downgrade_grace_ends_at into grace_end;
  return grace_end;
end;
$$;

create or replace function public.life_pilot_cancel_subscription_downgrade(
  p_user_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.user_subscriptions
  set downgrade_grace_ends_at = null,
      downgrade_notified_at = null,
      downgrade_cleanup_completed_at = null,
      local_move_started_at = null,
      updated_at = now()
  where user_id = p_user_id;
$$;

create or replace function public.cleanup_expired_subscription_overages()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  subscription_row public.user_subscriptions%rowtype;
  owner_email text;
  deleted_calendar integer := 0;
  deleted_memory integer := 0;
  deleted_accounting integer := 0;
  deleted_points integer := 0;
  deleted_questions integer := 0;
  removed_images integer := 0;
  revoked_shares integer := 0;
  processed integer := 0;
  keep_regular integer;
  reserved_count integer;
  candidate record;
begin
  perform pg_advisory_xact_lock(hashtext('life_pilot_subscription_cleanup'));

  for subscription_row in
    select * from public.user_subscriptions s
    where s.plan = 'plus'
      and s.status not in ('active', 'trialing')
      and s.downgrade_grace_ends_at <= now()
      and s.downgrade_cleanup_completed_at is null
      and s.local_move_started_at is null
    for update skip locked
  loop
    -- A verified late renewal always wins over cleanup.
    if exists (
      select 1 from public.user_subscriptions renewed
      where renewed.user_id = subscription_row.user_id
        and renewed.status in ('active', 'trialing')
        and coalesce(renewed.current_period_end, renewed.expires_at) > now()
    ) then
      perform public.life_pilot_cancel_subscription_downgrade(
        subscription_row.user_id
      );
      continue;
    end if;

    select lower(email) into owner_email
    from auth.users where id = subscription_row.user_id;
    if owner_email is null then continue; end if;

    deleted_calendar := 0;
    deleted_memory := 0;
    deleted_accounting := 0;
    deleted_points := 0;
    deleted_questions := 0;
    removed_images := 0;
    revoked_shares := 0;

    with ranked as (
      select id, row_number() over (
        order by coalesce(start_date, end_date) desc nulls last, id desc
      ) as position
      from public.calendar_events
      where lower(trim(account)) = owner_email
    ), removed as (
      delete from public.calendar_events e using ranked r
      where e.id = r.id and r.position > 30 returning 1
    ) select count(*) into deleted_calendar from removed;

    with ranked as (
      select id, row_number() over (
        order by coalesce(start_date, end_date) desc nulls last, id desc
      ) as position
      from public.memory_trace
      where lower(trim(account)) = owner_email
    ), removed as (
      delete from public.memory_trace m using ranked r
      where m.id = r.id and r.position > 30 returning 1
    ) select count(*) into deleted_memory from removed;

    select count(*) into reserved_count
    from public.accounting_detail d
    join public.accounting_account a on a.id = d.account_id
    where lower(trim(a.created_by)) = owner_email
      and d.primary_category = 'reserved';
    keep_regular := greatest(30 - reserved_count, 0);
    with ranked as (
      select d.id, row_number() over (
        order by d.date desc nulls last, d.created_at desc, d.id desc
      ) as position
      from public.accounting_detail d
      join public.accounting_account a on a.id = d.account_id
      where lower(trim(a.created_by)) = owner_email
        and d.primary_category <> 'reserved'
    ), removed as (
      delete from public.accounting_detail d using ranked r
      where d.id = r.id and r.position > keep_regular returning 1
    ) select count(*) into deleted_accounting from removed;
    update public.accounting_account a
    set balance = coalesce((
      select sum(d.value) from public.accounting_detail d
      where d.account_id = a.id and d.type = 'balance'
        and d.currency = a.main_currency
    ), 0)
    where lower(trim(a.created_by)) = owner_email;
    update public.accounting_balance_by_currency b
    set balance = coalesce((
      select sum(d.value) from public.accounting_detail d
      where d.account_id = b.account_id and d.currency = b.currency
    ), 0)
    where exists (
      select 1 from public.accounting_account a
      where a.id = b.account_id and lower(trim(a.created_by)) = owner_email
    );

    select count(*) into reserved_count
    from public.point_record_detail d
    join public.point_record_account a on a.id = d.account_id
    where lower(trim(a.created_by)) = owner_email
      and d.primary_category = 'reserved';
    keep_regular := greatest(30 - reserved_count, 0);
    with ranked as (
      select d.id, row_number() over (
        order by d.date desc nulls last, d.created_at desc, d.id desc
      ) as position
      from public.point_record_detail d
      join public.point_record_account a on a.id = d.account_id
      where lower(trim(a.created_by)) = owner_email
        and d.primary_category <> 'reserved'
    ), removed as (
      delete from public.point_record_detail d using ranked r
      where d.id = r.id and r.position > keep_regular returning 1
    ) select count(*) into deleted_points from removed;
    update public.point_record_account a
    set points = coalesce((
      select sum(d.value) from public.point_record_detail d
      where d.account_id = a.id and d.type = 'points'
    ), 0)
    where lower(trim(a.created_by)) = owner_email;

    for candidate in
      with all_questions as (
        select 'game_grammar' as table_name, id, created_at
        from public.game_grammar where owner_id = subscription_row.user_id
        union all
        select 'game_sentence', id, created_at
        from public.game_sentence where owner_id = subscription_row.user_id
        union all
        select 'game_translation', id, created_at
        from public.game_translation where owner_id = subscription_row.user_id
        union all
        select 'game_social_scenarios', id, created_at
        from public.game_social_scenarios
        where owner_id = subscription_row.user_id
      )
      select table_name, id from all_questions
      order by created_at desc nulls last, id desc offset 50
    loop
      if candidate.table_name = 'game_grammar' then
        delete from public.game_grammar_user where question_id = candidate.id;
        delete from public.game_grammar where id = candidate.id;
      elsif candidate.table_name = 'game_sentence' then
        delete from public.game_sentence_user where question_id = candidate.id;
        delete from public.game_speaking_user where question_id = candidate.id;
        delete from public.game_sentence where id = candidate.id;
      elsif candidate.table_name = 'game_translation' then
        delete from public.game_translation_user where question_id = candidate.id;
        delete from public.game_word_search_user where question_id = candidate.id;
        delete from public.game_translation where id = candidate.id;
      else
        delete from public.game_social_user where question_id::text = candidate.id::text;
        delete from public.game_social_scenarios where id = candidate.id;
      end if;
      deleted_questions := deleted_questions + 1;
    end loop;

    with excess as (
      select id from public.calendar_share_invitations
      where lower(trim(shared_by)) = owner_email
        and status in ('pending', 'accepted')
      order by created_at desc nulls last, id desc offset 2
    ), changed as (
      update public.calendar_share_invitations i set status = 'revoked'
      from excess e where i.id = e.id returning 1
    ) select count(*) into revoked_shares from changed;

    with changed as (
      update public.calendar_events set master_graph_url = null
      where lower(trim(account)) = owner_email
        and nullif(trim(master_graph_url), '') is not null returning 1
    ) select count(*) into removed_images from changed;
    with changed as (
      update public.memory_trace set master_graph_url = null
      where lower(trim(account)) = owner_email
        and nullif(trim(master_graph_url), '') is not null returning 1
    ) select removed_images + count(*) into removed_images from changed;
    with changed as (
      update public.recommended_events set master_graph_url = null
      where lower(trim(account)) = owner_email
        and nullif(trim(master_graph_url), '') is not null returning 1
    ) select removed_images + count(*) into removed_images from changed;
    with changed as (
      update public.recommended_attractions set master_graph_url = null
      where lower(trim(account)) = owner_email
        and nullif(trim(master_graph_url), '') is not null returning 1
    ) select removed_images + count(*) into removed_images from changed;

    insert into public.subscription_cleanup_audit(
      user_id, reason, deleted_counts
    ) values (
      subscription_row.user_id,
      'plus_expired_30_days',
      jsonb_build_object(
        'calendar_events', deleted_calendar,
        'memory_trace', deleted_memory,
        'accounting_detail', deleted_accounting,
        'point_record_detail', deleted_points,
        'game_questions', deleted_questions,
        'calendar_shares_revoked', revoked_shares,
        'images_removed', removed_images
      )
    );
    update public.user_subscriptions
    set downgrade_cleanup_completed_at = now(), updated_at = now()
    where user_id = subscription_row.user_id;
    processed := processed + 1;
  end loop;
  return processed;
end;
$$;

create or replace function public.apply_verified_subscription_event(
  p_provider text,
  p_provider_event_id text,
  p_event_type text,
  p_user_id uuid,
  p_plan text,
  p_status text,
  p_period_start timestamptz,
  p_period_end timestamptz,
  p_cancel_at_period_end boolean,
  p_provider_customer_id text,
  p_provider_subscription_id text,
  p_payload jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare inserted_count integer;
begin
  insert into public.subscription_payment_events(
    provider, provider_event_id, event_type, user_id, payload
  ) values (
    p_provider, p_provider_event_id, p_event_type, p_user_id, p_payload
  ) on conflict (provider, provider_event_id) do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count = 0 then return false; end if;

  insert into public.user_subscriptions(
    user_id, plan, status, starts_at, expires_at,
    current_period_start, current_period_end, cancel_at_period_end,
    provider, provider_customer_id, provider_subscription_id,
    last_payment_event_id, updated_at
  ) values (
    p_user_id, p_plan, p_status, coalesce(p_period_start, now()), p_period_end,
    p_period_start, p_period_end, coalesce(p_cancel_at_period_end, false),
    p_provider, p_provider_customer_id, p_provider_subscription_id,
    p_provider_event_id, now()
  )
  on conflict (user_id) do update set
    plan = excluded.plan,
    status = excluded.status,
    current_period_start = excluded.current_period_start,
    current_period_end = excluded.current_period_end,
    expires_at = excluded.expires_at,
    cancel_at_period_end = excluded.cancel_at_period_end,
    provider = excluded.provider,
    provider_customer_id = excluded.provider_customer_id,
    provider_subscription_id = excluded.provider_subscription_id,
    last_payment_event_id = excluded.last_payment_event_id,
    updated_at = now();

  if p_status in ('active', 'trialing') and p_period_end > now() then
    perform public.life_pilot_cancel_subscription_downgrade(p_user_id);
  else
    perform public.life_pilot_begin_subscription_downgrade(p_user_id);
  end if;
  update public.subscription_payment_events
  set processed_at = now()
  where provider = p_provider and provider_event_id = p_provider_event_id;
  return true;
exception when others then
  update public.subscription_payment_events
  set processing_error = sqlerrm
  where provider = p_provider and provider_event_id = p_provider_event_id;
  raise;
end;
$$;

revoke all on function public.life_pilot_begin_subscription_downgrade(uuid)
  from public, anon, authenticated;
revoke all on function public.life_pilot_cancel_subscription_downgrade(uuid)
  from public, anon, authenticated;
revoke all on function public.cleanup_expired_subscription_overages()
  from public, anon, authenticated;
revoke all on function public.apply_verified_subscription_event(
  text, text, text, uuid, text, text, timestamptz, timestamptz,
  boolean, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.life_pilot_begin_subscription_downgrade(uuid)
  to service_role;
grant execute on function public.life_pilot_cancel_subscription_downgrade(uuid)
  to service_role;
grant execute on function public.cleanup_expired_subscription_overages()
  to service_role;
grant execute on function public.apply_verified_subscription_event(
  text, text, text, uuid, text, text, timestamptz, timestamptz,
  boolean, text, text, jsonb
) to service_role;

commit;
