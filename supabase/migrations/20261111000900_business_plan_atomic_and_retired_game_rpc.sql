begin;

-- The App now receives the highest passed level from
-- get_my_game_progress_window. Registered database dependencies still make
-- this DROP fail safely instead of cascading through a live caller.
do $$
begin
  if exists (
    select 1
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where procedure.prokind = 'f'
      and not (
        namespace.nspname = 'public'
        and procedure.proname = 'get_user_game_highest_passed_level'
      )
      and position(
        'get_user_game_highest_passed_level'
        in pg_catalog.pg_get_functiondef(procedure.oid)
      ) > 0
  ) then
    raise exception 'retired_game_progress_rpc_still_has_dynamic_callers';
  end if;
end;
$$;

drop function if exists public.get_user_game_highest_passed_level(text, text);

create or replace function public.create_business_plan_from_template(
  p_plan_id uuid,
  p_title text,
  p_template_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_existing_id uuid;
  v_existing_valid boolean;
  v_template_section record;
  v_section_id uuid;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_plan_id is null or p_template_id is null or nullif(trim(p_title), '') is null then
    raise exception 'invalid_business_plan' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from public.business_plan_template template
    where template.id = p_template_id
      and template.is_valid is true
  ) then
    raise exception 'business_plan_template_not_found' using errcode = 'P0002';
  end if;

  select plan.id, plan.is_valid
    into v_existing_id, v_existing_valid
  from public.business_plan plan
  where lower(trim(plan.created_by)) = v_email
    and plan.title = trim(p_title)
  limit 1
  for update;

  if v_existing_id is not null and v_existing_valid is true then
    raise exception 'plan_name_exists' using errcode = '23505';
  end if;

  -- A legacy soft-deleted plan may still own child rows. Replace the complete
  -- inactive graph so the caller-provided ID remains the single new identity.
  if v_existing_id is not null then
    delete from public.business_plan_answer answer
    where answer.plan_id = v_existing_id;
    delete from public.business_plan_question question
    using public.business_plan_section section
    where question.section_id = section.id
      and section.plan_id = v_existing_id;
    delete from public.business_plan_section section
    where section.plan_id = v_existing_id;
    delete from public.business_plan plan
    where plan.id = v_existing_id;
  end if;

  insert into public.business_plan(
    id, title, template_id, created_by, created_at, is_valid
  ) values (
    p_plan_id, trim(p_title), p_template_id, v_email, now(), true
  );

  for v_template_section in
    select section.id, section.title, section.sort_order
    from public.business_plan_template_section section
    where section.plan_id = p_template_id
    order by section.sort_order, section.id
  loop
    v_section_id := gen_random_uuid();
    insert into public.business_plan_section(id, plan_id, title, sort_order)
    values (
      v_section_id,
      p_plan_id,
      v_template_section.title,
      v_template_section.sort_order
    );

    insert into public.business_plan_question(
      id, section_id, prompt, sort_order
    )
    select
      gen_random_uuid(), v_section_id, question.prompt, question.sort_order
    from public.business_plan_template_question question
    where question.section_id = v_template_section.id
    order by question.sort_order, question.id;
  end loop;

  return p_plan_id;
end;
$$;

revoke all on function public.create_business_plan_from_template(uuid, text, uuid)
  from public, anon;
grant execute on function public.create_business_plan_from_template(uuid, text, uuid)
  to authenticated, service_role;

-- Validate the complete recipient list before writing. Any per-recipient
-- failure is raised so PostgreSQL rolls back invitations created earlier in
-- the same batch.
create or replace function public.invite_calendar_viewers(
  p_invited_emails text[],
  p_event_ids text[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if coalesce(array_length(p_invited_emails, 1), 0) = 0 then
    return jsonb_build_object('ok', true, 'processed', 0);
  end if;

  foreach v_email in array p_invited_emails loop
    if nullif(trim(v_email), '') is null then
      return jsonb_build_object('ok', false, 'error', 'invalid_email');
    end if;
  end loop;

  foreach v_email in array p_invited_emails loop
    v_email := lower(trim(v_email));
    v_result := public.invite_calendar_viewer(v_email, p_event_ids);
    if coalesce((v_result ->> 'ok')::boolean, false) is not true then
      raise exception '%', coalesce(v_result ->> 'error', 'calendar_invitation_failed')
        using detail = coalesce(v_result ->> 'details', v_email);
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'processed', array_length(p_invited_emails, 1)
  );
end;
$$;

revoke all on function public.invite_calendar_viewers(text[], text[])
  from public, anon;
grant execute on function public.invite_calendar_viewers(text[], text[])
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
