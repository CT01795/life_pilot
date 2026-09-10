begin;

create or replace function public.life_pilot_user_cloud_limit(
  p_user_id uuid,
  p_resource text
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  entitlement_limit bigint;
  target_is_admin boolean;
begin
  select coalesce(u.raw_app_meta_data ->> 'role' = 'admin', false)
  into target_is_admin
  from auth.users u
  where u.id = p_user_id;

  if target_is_admin then
    return 9223372036854775807;
  end if;

  select sum((e.entitlement_snapshot ->> p_resource)::bigint)
  into entitlement_limit
  from public.user_subscription_entitlements e
  where e.user_id = p_user_id
    and e.storage_plan = 'cloud'
    and e.starts_at <= now()
    and e.ends_at > now()
    and e.entitlement_snapshot ? p_resource;

  if entitlement_limit is not null then
    return entitlement_limit;
  end if;

  return case p_resource
    when 'calendar_events' then 30
    when 'accounting_detail' then 30
    when 'point_record_detail' then 30
    when 'memory_trace' then 30
    when 'game_questions' then 50
    when 'calendar_shares' then 2
    when 'image_bytes' then 0
    else 0
  end;
end;
$function$;

create or replace function public.get_subscription_cleanup_preview(
  p_email text default null
)
returns table(
  target_email text,
  resource text,
  used bigint,
  quota bigint,
  excess bigint,
  grace_ends_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  target_id uuid;
  target_email_value text;
  grace_end timestamptz;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  target_email_value := lower(trim(coalesce(p_email, public.life_pilot_user_email())));
  if target_email_value = '' then
    raise exception 'target_email_required';
  end if;
  if target_email_value <> public.life_pilot_user_email()
     and not public.life_pilot_is_admin() then
    raise exception 'admin_required';
  end if;

  select u.id into target_id
  from auth.users u
  where lower(u.email) = target_email_value;
  if target_id is null then
    raise exception 'user_not_found';
  end if;

  select s.downgrade_grace_ends_at into grace_end
  from public.user_subscriptions s
  where s.user_id = target_id;

  return query
  with usage_rows(resource, used) as (
    values
      ('calendar_events'::text, (select count(*) from public.calendar_events e where lower(trim(e.account)) = target_email_value)),
      ('accounting_detail', (select count(*) from public.accounting_detail d join public.accounting_account a on a.id = d.account_id where lower(trim(a.created_by)) = target_email_value)),
      ('point_record_detail', (select count(*) from public.point_record_detail d join public.point_record_account a on a.id = d.account_id where lower(trim(a.created_by)) = target_email_value)),
      ('memory_trace', (select count(*) from public.memory_trace m where lower(trim(m.account)) = target_email_value)),
      ('game_questions',
        (select count(*) from public.game_grammar q where q.owner_id = target_id)
        + (select count(*) from public.game_sentence q where q.owner_id = target_id)
        + (select count(*) from public.game_translation q where q.owner_id = target_id)
        + (select count(*) from public.game_social_scenarios q where q.owner_id = target_id)),
      ('calendar_shares', (select count(distinct lower(trim(i.invited_email))) from public.calendar_share_invitations i where lower(trim(i.shared_by)) = target_email_value and i.status in ('pending', 'accepted')))
  ), calculated as (
    select u.resource, u.used,
      public.life_pilot_user_cloud_limit(target_id, u.resource) as quota
    from usage_rows u
  )
  select target_email_value, c.resource, c.used, c.quota,
    greatest(c.used - c.quota, 0), grace_end
  from calculated c
  order by c.resource;
end;
$function$;

revoke all on function public.life_pilot_user_cloud_limit(uuid, text)
  from public, anon, authenticated;
grant execute on function public.life_pilot_user_cloud_limit(uuid, text)
  to service_role;

revoke all on function public.get_subscription_cleanup_preview(text)
  from public, anon;
grant execute on function public.get_subscription_cleanup_preview(text)
  to authenticated, service_role;

commit;
