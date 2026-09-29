-- Run once in the Supabase SQL editor.
-- Normal users retain the six default modules in the app. These rows only
-- represent extra modules explicitly granted by an administrator.

create or replace function public.admin_get_user_modules(p_email text)
returns table(module_key text)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_email text := lower(trim(p_email));
begin
  if not public.life_pilot_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;
  if v_email = '' or not exists (
    select 1 from auth.users u where lower(u.email) = v_email
  ) then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;

  return query
  select um.module_key
  from public.user_module um
  where lower(trim(um.account)) = v_email
    and um.enabled is true
    and (um.stop_at is null or um.stop_at > now())
    and um.module_key = any (
      array[
        'pointsRecord', 'game', 'ai', 'stock', 'businessPlan', 'feedbackAdmin'
      ]::text[]
    )
  order by um.module_key;
end;
$function$;

create or replace function public.admin_set_user_modules(
  p_email text,
  p_module_keys text[]
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_email text := lower(trim(p_email));
  v_key text;
begin
  if not public.life_pilot_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;
  if v_email = '' or not exists (
    select 1 from auth.users u where lower(u.email) = v_email
  ) then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if exists (
    select 1
    from unnest(coalesce(p_module_keys, array[]::text[])) requested(key)
    where requested.key <> all (
      array[
        'pointsRecord', 'game', 'ai', 'stock', 'businessPlan', 'feedbackAdmin'
      ]::text[]
    )
  ) then
    raise exception 'invalid_module_key' using errcode = '22023';
  end if;

  delete from public.user_module um
  where lower(trim(um.account)) = v_email
    and um.module_key = any (
      array[
        'pointsRecord', 'game', 'ai', 'stock', 'businessPlan', 'feedbackAdmin'
      ]::text[]
    );

  foreach v_key in array coalesce(p_module_keys, array[]::text[])
  loop
    insert into public.user_module(account, module_key, enabled, stop_at)
    values (v_email, v_key, true, null);
  end loop;
end;
$function$;

revoke all on function public.admin_get_user_modules(text) from public, anon;
revoke all on function public.admin_set_user_modules(text, text[]) from public, anon;
grant execute on function public.admin_get_user_modules(text) to authenticated, service_role;
grant execute on function public.admin_set_user_modules(text, text[]) to authenticated, service_role;

create or replace function public.life_pilot_can_use_module(p_module_key text)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select public.life_pilot_is_admin()
    or exists (
      select 1
      from public.user_module um
      where lower(trim(um.account)) = public.life_pilot_user_email()
        and um.module_key = p_module_key
        and um.enabled is true
        and (um.stop_at is null or um.stop_at > now())
    );
$function$;

revoke all on function public.life_pilot_can_use_module(text) from public, anon;
grant execute on function public.life_pilot_can_use_module(text) to authenticated, service_role;

drop policy if exists feedback_select_owner_or_admin on public.feedback;
create policy feedback_select_owner_or_authorized
on public.feedback for select to authenticated
using (
  lower(created_by) = public.life_pilot_user_email()
  or public.life_pilot_can_use_module('feedbackAdmin')
);

drop policy if exists feedback_update_admin on public.feedback;
create policy feedback_update_authorized
on public.feedback for update to authenticated
using (public.life_pilot_can_use_module('feedbackAdmin'))
with check (public.life_pilot_can_use_module('feedbackAdmin'));

drop policy if exists feedback_delete_admin on public.feedback;
create policy feedback_delete_authorized
on public.feedback for delete to authenticated
using (public.life_pilot_can_use_module('feedbackAdmin'));

-- Stock data remains read-only, but is no longer readable by every signed-in
-- account. Administrators and users granted the stock module can read it.
do $block$
declare
  v_table text;
begin
  foreach v_table in array array[
    'futures_institutional',
    'stock_date',
    'stock_institutional',
    'stock_predicted'
  ]
  loop
    execute format(
      'drop policy if exists %I on public.%I',
      v_table || '_registered_users_read',
      v_table
    );
    execute format(
      'drop policy if exists %I on public.%I',
      v_table || '_authorized_read',
      v_table
    );
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.life_pilot_can_use_module(''stock''))',
      v_table || '_authorized_read',
      v_table
    );
  end loop;
end;
$block$;
