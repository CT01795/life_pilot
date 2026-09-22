begin;

drop function if exists public.invite_calendar_viewer(text, text[]);

create function public.invite_calendar_viewer(
  p_invited_email text,
  p_event_ids text[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_current_email text := public.life_pilot_user_email();
  v_invited_email text := lower(trim(coalesce(p_invited_email, '')));
  v_invitation_id uuid;
  v_invitation_status text;
  v_owned_count integer;
  v_new_event_count integer;
  v_error_detail text;
  v_error_hint text;
begin
  if auth.uid() is null or v_current_email = '' then
    return jsonb_build_object('ok', false, 'error', 'authentication_required');
  end if;
  if v_invited_email = ''
     or v_invited_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_email');
  end if;
  if v_invited_email = v_current_email then
    return jsonb_build_object('ok', false, 'error', 'self_invite');
  end if;
  if not exists (
    select 1 from auth.users u where lower(u.email) = v_invited_email
  ) then
    return jsonb_build_object('ok', false, 'error', 'account_not_found');
  end if;
  if coalesce(array_length(p_event_ids, 1), 0) = 0 then
    return jsonb_build_object('ok', false, 'error', 'event_required');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_current_email, 0)
  );

  select i.id, i.status
    into v_invitation_id, v_invitation_status
    from public.calendar_share_invitations i
   where lower(trim(i.shared_by)) = v_current_email
     and lower(trim(i.invited_email)) = v_invited_email
   for update;

  select count(*)
    into v_owned_count
    from public.calendar_events e
   where e.id = any(p_event_ids)
     and lower(trim(e.account)) = v_current_email;
  if v_owned_count = 0 then
    return jsonb_build_object('ok', false, 'error', 'event_unavailable');
  end if;

  if v_invitation_id is not null
     and v_invitation_status in ('pending', 'accepted') then
    select count(*)
      into v_new_event_count
      from public.calendar_events e
     where e.id = any(p_event_ids)
       and lower(trim(e.account)) = v_current_email
       and not exists (
         select 1
           from public.calendar_share_events selected
          where selected.invitation_id = v_invitation_id
            and selected.event_id = e.id
       );
    if v_new_event_count = 0 then
      return jsonb_build_object('ok', false, 'error', 'duplicate');
    end if;

    insert into public.calendar_share_events(invitation_id, event_id)
    select v_invitation_id, e.id
      from public.calendar_events e
     where e.id = any(p_event_ids)
       and lower(trim(e.account)) = v_current_email
    on conflict do nothing;

    return jsonb_build_object(
      'ok', true,
      'invitation_id', v_invitation_id,
      'added_events', v_new_event_count
    );
  end if;

  if not public.life_pilot_is_admin()
     and not public.life_pilot_cloud_writes_allowed() then
    return jsonb_build_object('ok', false, 'error', 'quota');
  end if;
  if not public.life_pilot_is_admin()
     and public.life_pilot_my_usage('calendar_shares') >=
         public.life_pilot_plan_limit('calendar_shares') then
    return jsonb_build_object('ok', false, 'error', 'quota');
  end if;

  if v_invitation_id is null then
    insert into public.calendar_share_invitations(
      shared_by, invited_email, status, updated_at
    ) values (
      v_current_email, v_invited_email, 'pending', now()
    ) returning id into v_invitation_id;
  else
    delete from public.calendar_share_events selected
     where selected.invitation_id = v_invitation_id;

    update public.calendar_share_invitations i
       set status = 'pending', responded_at = null, updated_at = now()
     where i.id = v_invitation_id;
  end if;

  insert into public.calendar_share_events(invitation_id, event_id)
  select v_invitation_id, e.id
    from public.calendar_events e
   where e.id = any(p_event_ids)
     and lower(trim(e.account)) = v_current_email
  on conflict do nothing;

  return jsonb_build_object(
    'ok', true,
    'invitation_id', v_invitation_id,
    'added_events', v_owned_count
  );
exception
  when others then
    get stacked diagnostics
      v_error_detail = pg_exception_detail,
      v_error_hint = pg_exception_hint;
    return jsonb_build_object(
      'ok', false,
      'error', 'database_error',
      'details', concat_ws(
        ' | ',
        sqlstate || ': ' || sqlerrm,
        nullif(v_error_detail, ''),
        nullif(v_error_hint, '')
      )
    );
end;
$function$;

revoke all on function public.invite_calendar_viewer(text, text[])
from public, anon;
grant execute on function public.invite_calendar_viewer(text, text[])
to authenticated;

delete from public.calendar_share_events selected
using public.calendar_share_invitations invitation
where invitation.id = selected.invitation_id
  and invitation.status in ('declined', 'revoked');

commit;

notify pgrst, 'reload schema';
