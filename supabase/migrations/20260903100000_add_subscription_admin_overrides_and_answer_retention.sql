begin;

alter table public.user_subscriptions
  add column if not exists admin_note text,
  add column if not exists unlimited_quota boolean not null default false,
  add column if not exists calendar_quota_override integer,
  add column if not exists accounting_quota_override integer,
  add column if not exists point_quota_override integer,
  add column if not exists memory_quota_override integer,
  add column if not exists game_question_quota_override integer,
  add column if not exists calendar_share_quota_override integer,
  add column if not exists image_bytes_quota_override bigint;

create or replace function public.life_pilot_plan_limit(p_resource text)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  subscription_row public.user_subscriptions%rowtype;
  default_limit bigint;
begin
  if public.life_pilot_is_admin() then return 9223372036854775807; end if;

  select * into subscription_row
  from public.user_subscriptions
  where user_id = auth.uid();

  if coalesce(subscription_row.unlimited_quota, false)
     and coalesce(subscription_row.current_period_end,
                  subscription_row.expires_at) > now() then
    return 9223372036854775807;
  end if;

  default_limit := case p_resource
    when 'calendar_events' then case when public.life_pilot_subscription_plan() = 'plus' then 300 else 30 end
    when 'accounting_detail' then case when public.life_pilot_subscription_plan() = 'plus' then 300 else 30 end
    when 'point_record_detail' then case when public.life_pilot_subscription_plan() = 'plus' then 300 else 30 end
    when 'memory_trace' then case when public.life_pilot_subscription_plan() = 'plus' then 300 else 30 end
    when 'game_questions' then case when public.life_pilot_subscription_plan() = 'plus' then 500 else 50 end
    when 'calendar_shares' then case when public.life_pilot_subscription_plan() = 'plus' then 5 else 2 end
    when 'image_bytes' then case when public.life_pilot_subscription_plan() = 'plus' then 314572800 else 0 end
    else 0
  end;

  if coalesce(subscription_row.current_period_end,
              subscription_row.expires_at) <= now() then
    return default_limit;
  end if;

  return coalesce(case p_resource
    when 'calendar_events' then subscription_row.calendar_quota_override
    when 'accounting_detail' then subscription_row.accounting_quota_override
    when 'point_record_detail' then subscription_row.point_quota_override
    when 'memory_trace' then subscription_row.memory_quota_override
    when 'game_questions' then subscription_row.game_question_quota_override
    when 'calendar_shares' then subscription_row.calendar_share_quota_override
    when 'image_bytes' then subscription_row.image_bytes_quota_override
  end, default_limit);
end;
$function$;

create or replace function public.admin_set_user_subscription(
  p_email text,
  p_plan text,
  p_expires_at timestamptz,
  p_admin_note text default null,
  p_unlimited_quota boolean default false,
  p_calendar_quota integer default null,
  p_accounting_quota integer default null,
  p_point_quota integer default null,
  p_memory_quota integer default null,
  p_game_question_quota integer default null,
  p_calendar_share_quota integer default null,
  p_image_megabytes integer default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare target_user_id uuid;
begin
  if not public.life_pilot_is_admin() then raise exception 'admin_required'; end if;
  if p_plan not in ('free', 'plus') then raise exception 'invalid_plan'; end if;
  if p_expires_at is null then raise exception 'expiry_required'; end if;
  if least(p_calendar_quota, p_accounting_quota, p_point_quota,
           p_memory_quota, p_game_question_quota, p_calendar_share_quota,
           p_image_megabytes) < 0 then raise exception 'invalid_quota'; end if;

  select id into target_user_id from auth.users
  where lower(email) = lower(trim(p_email)) limit 1;
  if target_user_id is null then raise exception 'user_not_found'; end if;

  insert into public.user_subscriptions(
    user_id, plan, status, current_period_end, expires_at, updated_at,
    updated_by, admin_note, unlimited_quota,
    calendar_quota_override, accounting_quota_override,
    point_quota_override, memory_quota_override,
    game_question_quota_override, calendar_share_quota_override,
    image_bytes_quota_override
  ) values (
    target_user_id, p_plan,
    case when p_expires_at > now() then 'active' else 'expired' end,
    p_expires_at, p_expires_at, now(), auth.uid(), nullif(trim(p_admin_note), ''),
    p_unlimited_quota, p_calendar_quota, p_accounting_quota,
    p_point_quota, p_memory_quota, p_game_question_quota,
    p_calendar_share_quota,
    case when p_image_megabytes is null then null else p_image_megabytes::bigint * 1024 * 1024 end
  )
  on conflict (user_id) do update set
    plan = excluded.plan, status = excluded.status,
    current_period_end = excluded.current_period_end,
    expires_at = excluded.expires_at, updated_at = now(),
    updated_by = auth.uid(), admin_note = excluded.admin_note,
    unlimited_quota = excluded.unlimited_quota,
    calendar_quota_override = excluded.calendar_quota_override,
    accounting_quota_override = excluded.accounting_quota_override,
    point_quota_override = excluded.point_quota_override,
    memory_quota_override = excluded.memory_quota_override,
    game_question_quota_override = excluded.game_question_quota_override,
    calendar_share_quota_override = excluded.calendar_share_quota_override,
    image_bytes_quota_override = excluded.image_bytes_quota_override;
end;
$function$;

create or replace function public.delete_cloud_records_after_local_copy(
  p_records jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare item jsonb; deleted_count integer := 0; affected integer;
begin
  if jsonb_typeof(p_records) <> 'array' then
    raise exception 'invalid_local_move_payload';
  end if;
  for item in select value from jsonb_array_elements(p_records)
  loop
    if item ->> 'table_name' = 'calendar_events' then
      delete from public.calendar_events
      where id = item ->> 'id'
        and lower(trim(account)) = public.life_pilot_user_email();
    elsif item ->> 'table_name' = 'memory_trace' then
      delete from public.memory_trace
      where id = item ->> 'id'
        and lower(trim(account)) = public.life_pilot_user_email();
    else
      raise exception 'unsupported_local_resource:%', item ->> 'table_name';
    end if;
    get diagnostics affected = row_count;
    if affected <> 1 then
      raise exception 'cloud_record_not_deleted:%:%',
        item ->> 'table_name', item ->> 'id';
    end if;
    deleted_count := deleted_count + affected;
  end loop;
  return deleted_count;
end;
$function$;

create or replace function public.life_pilot_subscription_plan_for_user(p_user_id uuid)
returns text language sql stable security definer set search_path = '' as $function$
  select case
    when coalesce(s.unlimited_quota, false)
      and coalesce(s.current_period_end, s.expires_at) > now() then 'plus'
    when s.plan = 'plus' and s.status in ('active','trialing')
      and coalesce(s.current_period_end, s.expires_at) > now() then 'plus'
    else 'free' end
  from (select p_user_id as id) x
  left join public.user_subscriptions s on s.user_id = x.id;
$function$;

create or replace function public.cleanup_expired_game_answer_history()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare deleted_count integer := 0; affected integer;
begin
  perform pg_advisory_xact_lock(hashtext('life_pilot_game_answer_retention'));

  delete from public.game_grammar_user r using auth.users u
  where r.owner_id = u.id and r.created_at < now() -
    (case when coalesce((select public.life_pilot_subscription_plan_for_user(u.id)), 'free') = 'plus'
      then interval '1 year' else interval '30 days' end);
  get diagnostics affected = row_count; deleted_count := deleted_count + affected;
  delete from public.game_sentence_user r using auth.users u
  where r.owner_id = u.id and r.created_at < now() -
    (case when coalesce((select public.life_pilot_subscription_plan_for_user(u.id)), 'free') = 'plus'
      then interval '1 year' else interval '30 days' end);
  get diagnostics affected = row_count; deleted_count := deleted_count + affected;
  delete from public.game_translation_user r using auth.users u
  where r.owner_id = u.id and r.created_at < now() -
    (case when coalesce((select public.life_pilot_subscription_plan_for_user(u.id)), 'free') = 'plus'
      then interval '1 year' else interval '30 days' end);
  get diagnostics affected = row_count; deleted_count := deleted_count + affected;
  delete from public.game_social_user r using auth.users u
  where r.owner_id = u.id and r.created_at < now() -
    (case when coalesce((select public.life_pilot_subscription_plan_for_user(u.id)), 'free') = 'plus'
      then interval '1 year' else interval '30 days' end);
  get diagnostics affected = row_count; deleted_count := deleted_count + affected;
  delete from public.game_speaking_user r using auth.users u
  where r.owner_id = u.id and r.created_at < now() -
    (case when coalesce((select public.life_pilot_subscription_plan_for_user(u.id)), 'free') = 'plus'
      then interval '1 year' else interval '30 days' end);
  get diagnostics affected = row_count; deleted_count := deleted_count + affected;
  delete from public.game_word_search_user r using auth.users u
  where r.owner_id = u.id and r.created_at < now() -
    (case when coalesce((select public.life_pilot_subscription_plan_for_user(u.id)), 'free') = 'plus'
      then interval '1 year' else interval '30 days' end);
  get diagnostics affected = row_count; deleted_count := deleted_count + affected;
  return deleted_count;
end;
$function$;

revoke all on function public.admin_set_user_subscription(text,text,timestamptz,text,boolean,integer,integer,integer,integer,integer,integer,integer) from public, anon, authenticated;
grant execute on function public.admin_set_user_subscription(text,text,timestamptz,text,boolean,integer,integer,integer,integer,integer,integer,integer) to authenticated;
revoke all on function public.delete_cloud_records_after_local_copy(jsonb) from public, anon;
grant execute on function public.delete_cloud_records_after_local_copy(jsonb) to authenticated;
revoke all on function public.cleanup_expired_game_answer_history() from public, anon, authenticated;
grant execute on function public.cleanup_expired_game_answer_history() to service_role;
revoke all on function public.life_pilot_subscription_plan_for_user(uuid) from public, anon, authenticated;
grant execute on function public.life_pilot_subscription_plan_for_user(uuid) to service_role;

commit;
