begin;

create or replace function public.get_my_calendar_sharing_bootstrap()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null then
      jsonb_build_object('invitations', '[]'::jsonb, 'shared_events', '[]'::jsonb)
    else jsonb_build_object(
      'invitations', coalesce((
        select jsonb_agg(to_jsonb(i) order by i.updated_at desc)
        from (
          select id, shared_by, invited_email, status, updated_at
          from public.calendar_share_invitations
          where status in ('pending', 'accepted')
            and (
              lower(trim(shared_by)) = public.life_pilot_user_email()
              or lower(trim(invited_email)) = public.life_pilot_user_email()
            )
          order by updated_at desc
        ) i
      ), '[]'::jsonb),
      'shared_events', coalesce((
        select jsonb_agg(to_jsonb(e))
        from public.get_my_shared_calendar_events() e
      ), '[]'::jsonb)
    )
  end;
$$;

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
    v_email := lower(trim(v_email));
    if nullif(v_email, '') is null then
      return jsonb_build_object('ok', false, 'error', 'invalid_email');
    end if;
    v_result := public.invite_calendar_viewer(v_email, p_event_ids);
    if coalesce((v_result ->> 'ok')::boolean, false) is not true then
      return coalesce(v_result, '{}'::jsonb) || jsonb_build_object(
        'invited_email', v_email
      );
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'processed', array_length(p_invited_emails, 1)
  );
end;
$$;

revoke all on function public.get_my_calendar_sharing_bootstrap() from public, anon;
grant execute on function public.get_my_calendar_sharing_bootstrap() to authenticated, service_role;
revoke all on function public.invite_calendar_viewers(text[], text[]) from public, anon;
grant execute on function public.invite_calendar_viewers(text[], text[]) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
