begin;

create table if not exists public.user_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'plus')),
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  check (expires_at is null or expires_at > starts_at)
);

alter table public.user_subscriptions
  add column if not exists status text not null default 'inactive',
  add column if not exists provider text,
  add column if not exists provider_customer_id text,
  add column if not exists provider_subscription_id text,
  add column if not exists current_period_start timestamptz,
  add column if not exists current_period_end timestamptz,
  add column if not exists cancel_at_period_end boolean not null default false,
  add column if not exists last_payment_event_id text;

alter table public.user_subscriptions
  drop constraint if exists user_subscriptions_status_check;
alter table public.user_subscriptions
  add constraint user_subscriptions_status_check check (
    status in (
      'inactive', 'trialing', 'active', 'past_due',
      'canceled', 'expired'
    )
  );

create unique index if not exists user_subscriptions_provider_subscription_uidx
on public.user_subscriptions(provider, provider_subscription_id)
where provider is not null and provider_subscription_id is not null;

create table if not exists public.subscription_payment_events (
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  user_id uuid references auth.users(id) on delete set null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_error text,
  payload jsonb not null,
  primary key (provider, provider_event_id)
);
alter table public.subscription_payment_events enable row level security;
revoke all on table public.subscription_payment_events
  from public, anon, authenticated;
grant all on table public.subscription_payment_events to service_role;

alter table public.user_subscriptions enable row level security;
drop policy if exists user_subscriptions_select_own_or_admin
on public.user_subscriptions;
create policy user_subscriptions_select_own_or_admin
on public.user_subscriptions for select to authenticated
using (user_id = auth.uid() or public.life_pilot_is_admin());

revoke all on table public.user_subscriptions from public, anon, authenticated;
grant select on table public.user_subscriptions to authenticated;
grant all on table public.user_subscriptions to service_role;

create or replace function public.life_pilot_subscription_plan()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when public.life_pilot_is_admin() then 'plus'
    else coalesce((
      select s.plan
      from public.user_subscriptions s
      where s.user_id = auth.uid()
        and s.status in ('trialing', 'active')
        and coalesce(s.current_period_end, s.expires_at) > now()
    ), 'free')
  end;
$$;

create or replace function public.life_pilot_plan_limit(p_resource text)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_plan text := public.life_pilot_subscription_plan();
begin
  return case p_resource
    when 'calendar_events' then case current_plan when 'plus' then 300 else 30 end
    when 'accounting_detail' then case current_plan when 'plus' then 300 else 30 end
    when 'point_record_detail' then case current_plan when 'plus' then 300 else 30 end
    when 'memory_trace' then case current_plan when 'plus' then 300 else 30 end
    when 'game_questions' then case current_plan when 'plus' then 500 else 50 end
    when 'calendar_shares' then case current_plan when 'plus' then 5 else 2 end
    when 'image_bytes' then case current_plan when 'plus' then 314572800 else 0 end
    else 0
  end;
end;
$$;

create or replace function public.life_pilot_cloud_writes_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when public.life_pilot_is_admin() then true
    when not exists (
      select 1 from public.user_subscriptions s
      where s.user_id = auth.uid() and s.plan = 'plus'
    ) then true
    else exists (
      select 1 from public.user_subscriptions s
      where s.user_id = auth.uid()
        and s.plan = 'plus'
        and s.status in ('trialing', 'active')
        and coalesce(s.current_period_end, s.expires_at) > now()
    )
  end;
$$;

create or replace function public.get_my_subscription_status()
returns table(
  plan text,
  status text,
  current_period_end timestamptz,
  cancel_at_period_end boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.life_pilot_subscription_plan(),
    coalesce(s.status, 'inactive'),
    coalesce(s.current_period_end, s.expires_at),
    coalesce(s.cancel_at_period_end, false)
  from (select 1) seed
  left join public.user_subscriptions s on s.user_id = auth.uid();
$$;

create or replace function public.life_pilot_my_usage(p_resource text)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_email text := public.life_pilot_user_email();
  result bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  result := case p_resource
    when 'calendar_events' then (
      select count(*) from public.calendar_events e
      where lower(trim(e.account)) = current_email
    )
    when 'accounting_detail' then (
      select count(*) from public.accounting_detail d
      join public.accounting_account a on a.id = d.account_id
      where lower(trim(a.created_by)) = current_email
    )
    when 'point_record_detail' then (
      select count(*) from public.point_record_detail d
      join public.point_record_account a on a.id = d.account_id
      where lower(trim(a.created_by)) = current_email
    )
    when 'memory_trace' then (
      select count(*) from public.memory_trace m
      where lower(trim(m.account)) = current_email
    )
    when 'game_questions' then (
      (select count(*) from public.game_grammar q where q.owner_id = auth.uid()) +
      (select count(*) from public.game_sentence q where q.owner_id = auth.uid()) +
      (select count(*) from public.game_translation q where q.owner_id = auth.uid()) +
      (select count(*) from public.game_social_scenarios q where q.owner_id = auth.uid())
    )
    when 'calendar_shares' then (
      select count(distinct lower(trim(i.invited_email)))
      from public.calendar_share_invitations i
      where lower(trim(i.shared_by)) = current_email
        and i.status in ('pending', 'accepted')
    )
    when 'image_bytes' then (
      select coalesce(sum(floor(length(
        case when position(',' in e.master_graph_url) > 0
          then split_part(e.master_graph_url, ',', 2)
          else e.master_graph_url end
      ) * 3.0 / 4.0)::bigint), 0)
      from (
        select master_graph_url from public.calendar_events where lower(trim(account)) = current_email
        union all
        select master_graph_url from public.memory_trace where lower(trim(account)) = current_email
        union all
        select master_graph_url from public.recommended_events where lower(trim(account)) = current_email
        union all
        select master_graph_url from public.recommended_attractions where lower(trim(account)) = current_email
      ) e where nullif(trim(e.master_graph_url), '') is not null
        and e.master_graph_url !~ '^https?://'
    )
    else 0
  end;
  return coalesce(result, 0);
end;
$$;

create or replace function public.get_my_subscription_usage()
returns table(resource text, used bigint, quota bigint, plan text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.resource,
         public.life_pilot_my_usage(r.resource),
         public.life_pilot_plan_limit(r.resource),
         public.life_pilot_subscription_plan()
  from unnest(array[
    'calendar_events', 'accounting_detail', 'point_record_detail',
    'memory_trace', 'game_questions', 'calendar_shares', 'image_bytes'
  ]) as r(resource);
$$;

create or replace function public.life_pilot_raise_if_quota_reached(p_resource text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.life_pilot_is_admin() then return; end if;
  if not public.life_pilot_cloud_writes_allowed() then
    raise exception using
      errcode = 'P0001',
      message = 'LIFE_PILOT_RENEWAL_REQUIRED';
  end if;
  if public.life_pilot_my_usage(p_resource) >= public.life_pilot_plan_limit(p_resource) then
    raise exception using
      errcode = 'P0001',
      message = 'LIFE_PILOT_QUOTA_REACHED:' || p_resource;
  end if;
end;
$$;

create or replace function public.life_pilot_enforce_direct_quota()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.life_pilot_raise_if_quota_reached(TG_ARGV[0]);
  return new;
end;
$$;

drop trigger if exists calendar_events_subscription_quota on public.calendar_events;
create trigger calendar_events_subscription_quota before insert on public.calendar_events
for each row execute function public.life_pilot_enforce_direct_quota('calendar_events');
drop trigger if exists memory_trace_subscription_quota on public.memory_trace;
create trigger memory_trace_subscription_quota before insert on public.memory_trace
for each row execute function public.life_pilot_enforce_direct_quota('memory_trace');
drop trigger if exists game_grammar_subscription_quota on public.game_grammar;
create trigger game_grammar_subscription_quota before insert on public.game_grammar
for each row execute function public.life_pilot_enforce_direct_quota('game_questions');
drop trigger if exists game_sentence_subscription_quota on public.game_sentence;
create trigger game_sentence_subscription_quota before insert on public.game_sentence
for each row execute function public.life_pilot_enforce_direct_quota('game_questions');
drop trigger if exists game_translation_subscription_quota on public.game_translation;
create trigger game_translation_subscription_quota before insert on public.game_translation
for each row execute function public.life_pilot_enforce_direct_quota('game_questions');
drop trigger if exists game_social_subscription_quota on public.game_social_scenarios;
create trigger game_social_subscription_quota before insert on public.game_social_scenarios
for each row execute function public.life_pilot_enforce_direct_quota('game_questions');

create or replace function public.life_pilot_enforce_accounting_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.life_pilot_raise_if_quota_reached('accounting_detail');
  return new;
end; $$;
drop trigger if exists accounting_detail_subscription_quota on public.accounting_detail;
create trigger accounting_detail_subscription_quota before insert on public.accounting_detail
for each row execute function public.life_pilot_enforce_accounting_quota();

create or replace function public.life_pilot_enforce_point_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.life_pilot_raise_if_quota_reached('point_record_detail');
  return new;
end; $$;
drop trigger if exists point_record_detail_subscription_quota on public.point_record_detail;
create trigger point_record_detail_subscription_quota before insert on public.point_record_detail
for each row execute function public.life_pilot_enforce_point_quota();

create or replace function public.life_pilot_enforce_image_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  new_size bigint := 0;
  old_size bigint := 0;
begin
  if public.life_pilot_is_admin() or new.master_graph_url is null
     or trim(new.master_graph_url) = '' or new.master_graph_url ~ '^https?://' then
    return new;
  end if;
  if public.life_pilot_subscription_plan() <> 'plus' then
    raise exception using errcode = 'P0001', message = 'LIFE_PILOT_PLUS_REQUIRED:images';
  end if;
  new_size := floor(length(case when position(',' in new.master_graph_url) > 0
    then split_part(new.master_graph_url, ',', 2) else new.master_graph_url end)
    * 3.0 / 4.0)::bigint;
  if TG_OP = 'UPDATE' and old.master_graph_url is not null
     and old.master_graph_url !~ '^https?://' then
    old_size := floor(length(case when position(',' in old.master_graph_url) > 0
      then split_part(old.master_graph_url, ',', 2) else old.master_graph_url end)
      * 3.0 / 4.0)::bigint;
  end if;
  if public.life_pilot_my_usage('image_bytes') - old_size + new_size
       > public.life_pilot_plan_limit('image_bytes') then
    raise exception using errcode = 'P0001', message = 'LIFE_PILOT_QUOTA_REACHED:image_bytes';
  end if;
  return new;
end; $$;

do $$ declare t text; begin
  foreach t in array array['calendar_events','memory_trace','recommended_events','recommended_attractions'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_image_quota', t);
    execute format('create trigger %I before insert or update of master_graph_url on public.%I for each row execute function public.life_pilot_enforce_image_quota()', t || '_image_quota', t);
  end loop;
end $$;

create or replace function public.life_pilot_enforce_calendar_share_quota()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status in ('pending', 'accepted') and
     (TG_OP = 'INSERT' or old.status not in ('pending', 'accepted')) then
    perform public.life_pilot_raise_if_quota_reached('calendar_shares');
  end if;
  return new;
end; $$;
drop trigger if exists calendar_share_subscription_quota on public.calendar_share_invitations;
create trigger calendar_share_subscription_quota before insert or update of status
on public.calendar_share_invitations for each row
execute function public.life_pilot_enforce_calendar_share_quota();

create or replace function public.delete_my_accounting_detail(p_detail_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  d public.accounting_detail%rowtype;
  main_currency text;
begin
  select detail.* into d
  from public.accounting_detail detail
  join public.accounting_account account_row on account_row.id = detail.account_id
  where detail.id = p_detail_id
    and lower(trim(account_row.created_by)) = public.life_pilot_user_email()
  for update of detail;
  if not found then raise exception 'Accounting detail not found'; end if;
  select account_row.main_currency into main_currency
  from public.accounting_account account_row where account_row.id = d.account_id;
  update public.accounting_balance_by_currency
  set balance = balance - coalesce(d.value, 0)
  where account_id = d.account_id and currency = d.currency;
  update public.accounting_account
  set balance = coalesce(balance, 0) - case
    when d.type = 'balance' and d.currency = main_currency then coalesce(d.value, 0)
    else 0 end
  where id = d.account_id;
  delete from public.accounting_detail where id = p_detail_id;
end; $$;

create or replace function public.delete_my_point_record_detail(p_detail_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare d public.point_record_detail%rowtype;
begin
  select detail.* into d
  from public.point_record_detail detail
  join public.point_record_account account_row on account_row.id = detail.account_id
  where detail.id = p_detail_id
    and lower(trim(account_row.created_by)) = public.life_pilot_user_email()
  for update of detail;
  if not found then raise exception 'Point record detail not found'; end if;
  update public.point_record_account
  set points = coalesce(points, 0) - case
    when d.type = 'points' then coalesce(d.value, 0) else 0 end
  where id = d.account_id;
  delete from public.point_record_detail where id = p_detail_id;
end; $$;

-- Business Plan and stock data are administrator-only at both API and UI levels.
do $$ declare t text; p record; begin
  foreach t in array array[
    'business_plan','business_plan_answer','business_plan_question','business_plan_section',
    'business_plan_template','business_plan_template_question','business_plan_template_section'
  ] loop
    for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
      execute format('drop policy if exists %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for all to authenticated using (public.life_pilot_is_admin()) with check (public.life_pilot_is_admin())', t || '_admin_only', t);
  end loop;
  foreach t in array array['futures_institutional','stock_date','stock_institutional','stock_predicted'] loop
    for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
      execute format('drop policy if exists %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy %I on public.%I for select to authenticated using (public.life_pilot_is_admin())', t || '_admin_read', t);
  end loop;
end $$;

revoke all on function public.life_pilot_subscription_plan() from public, anon;
revoke all on function public.life_pilot_cloud_writes_allowed() from public, anon;
revoke all on function public.life_pilot_plan_limit(text) from public, anon;
revoke all on function public.life_pilot_my_usage(text) from public, anon;
revoke all on function public.get_my_subscription_usage() from public, anon;
revoke all on function public.get_my_subscription_status() from public, anon;
grant execute on function public.get_my_subscription_usage() to authenticated;
grant execute on function public.get_my_subscription_status() to authenticated;
revoke all on function public.delete_my_accounting_detail(uuid) from public, anon;
revoke all on function public.delete_my_point_record_detail(uuid) from public, anon;
grant execute on function public.delete_my_accounting_detail(uuid) to authenticated;
grant execute on function public.delete_my_point_record_detail(uuid) to authenticated;

create or replace function public.restore_local_personal_record_admin(
  p_table_name text,
  p_record jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_table_name = 'calendar_events' then
    if exists (select 1 from public.calendar_events where id = p_record ->> 'id') then
      return false;
    end if;
    insert into public.calendar_events
    select * from jsonb_populate_record(null::public.calendar_events, p_record);
  elsif p_table_name = 'memory_trace' then
    if exists (select 1 from public.memory_trace where id = p_record ->> 'id') then
      return false;
    end if;
    insert into public.memory_trace
    select * from jsonb_populate_record(null::public.memory_trace, p_record);
  else
    raise exception 'unsupported_local_resource';
  end if;
  return true;
end;
$$;
revoke all on function public.restore_local_personal_record_admin(text, jsonb)
  from public, anon;
grant execute on function public.restore_local_personal_record_admin(text, jsonb)
  to authenticated;

create or replace function public.restore_local_personal_records_admin(
  p_records jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  item jsonb;
  table_name text;
  record_data jsonb;
  resource_name text;
  incoming_count integer;
  used_count bigint;
  quota_count bigint;
  restored_count integer := 0;
begin
  if jsonb_typeof(p_records) <> 'array' then
    raise exception 'invalid_local_upload_payload';
  end if;

  for resource_name in
    select unnest(array['calendar_events', 'memory_trace'])
  loop
    select count(*) into incoming_count
    from jsonb_array_elements(p_records) value
    where value ->> 'table_name' = resource_name;
    if incoming_count = 0 then continue; end if;
    used_count := public.life_pilot_my_usage(resource_name);
    quota_count := public.life_pilot_plan_limit(resource_name);
    if used_count + incoming_count > quota_count then
      raise exception 'local_upload_quota_exceeded:%:%:%:%',
        resource_name, used_count, incoming_count, quota_count;
    end if;
  end loop;

  for item in select value from jsonb_array_elements(p_records)
  loop
    table_name := item ->> 'table_name';
    record_data := item -> 'record';
    if table_name = 'calendar_events' then
      if lower(trim(coalesce(record_data ->> 'account', ''))) <>
         public.life_pilot_user_email() then
        raise exception 'local_upload_owner_mismatch';
      end if;
      if exists (
        select 1 from public.calendar_events
        where id = record_data ->> 'id'
      ) then
        raise exception 'local_upload_duplicate:calendar_events:%',
          record_data ->> 'id';
      end if;
      insert into public.calendar_events
      select * from jsonb_populate_record(
        null::public.calendar_events,
        record_data
      );
    elsif table_name = 'memory_trace' then
      if lower(trim(coalesce(record_data ->> 'account', ''))) <>
         public.life_pilot_user_email() then
        raise exception 'local_upload_owner_mismatch';
      end if;
      if exists (
        select 1 from public.memory_trace
        where id = record_data ->> 'id'
      ) then
        raise exception 'local_upload_duplicate:memory_trace:%',
          record_data ->> 'id';
      end if;
      insert into public.memory_trace
      select * from jsonb_populate_record(
        null::public.memory_trace,
        record_data
      );
    else
      raise exception 'unsupported_local_resource:%', table_name;
    end if;
    restored_count := restored_count + 1;
  end loop;
  return restored_count;
end;
$$;
revoke all on function public.restore_local_personal_records_admin(jsonb)
  from public, anon;
grant execute on function public.restore_local_personal_records_admin(jsonb)
  to authenticated;

commit;
