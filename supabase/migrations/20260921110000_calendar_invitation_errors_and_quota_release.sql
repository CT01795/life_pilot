begin;

create or replace function public.invite_calendar_viewer(
  p_invited_email text,
  p_event_ids text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  current_email text := public.life_pilot_user_email();
  invited_email text := lower(trim(coalesce(p_invited_email, '')));
  invitation_id uuid;
  invitation_status text;
  owned_count integer;
  new_event_count integer;
begin
  if auth.uid() is null or current_email = '' then
    raise exception 'Authentication required';
  end if;
  if invited_email = '' or invited_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Invalid email';
  end if;
  if invited_email = current_email then raise exception 'Cannot invite yourself'; end if;
  if not exists (select 1 from auth.users u where lower(u.email) = invited_email) then
    raise exception 'ACCOUNT_NOT_FOUND';
  end if;
  if coalesce(array_length(p_event_ids, 1), 0) = 0 then
    raise exception 'Choose at least one event';
  end if;

  select i.id, i.status into invitation_id, invitation_status
  from public.calendar_share_invitations i
  where lower(trim(i.shared_by)) = current_email
    and lower(trim(i.invited_email)) = invited_email
  for update;

  select count(*) into owned_count
  from public.calendar_events e
  where e.id = any(p_event_ids)
    and lower(trim(e.account)) = current_email;
  if owned_count = 0 then raise exception 'No owned events selected'; end if;

  if invitation_id is not null and invitation_status in ('pending', 'accepted') then
    select count(*) into new_event_count
    from public.calendar_events e
    where e.id = any(p_event_ids)
      and lower(trim(e.account)) = current_email
      and not exists (
        select 1 from public.calendar_share_events s
        where s.invitation_id = invitation_id and s.event_id = e.id
      );
    if new_event_count = 0 then raise exception 'DUPLICATE_INVITATION'; end if;
    insert into public.calendar_share_events(invitation_id, event_id)
    select invitation_id, e.id
    from public.calendar_events e
    where e.id = any(p_event_ids)
      and lower(trim(e.account)) = current_email
    on conflict do nothing;
    return invitation_id;
  end if;

  if invitation_id is null then
    insert into public.calendar_share_invitations(shared_by, invited_email, status, updated_at)
    values(current_email, invited_email, 'pending', now())
    returning id into invitation_id;
  else
    update public.calendar_share_invitations
    set status = 'pending', responded_at = null, updated_at = now()
    where id = invitation_id;
  end if;

  insert into public.calendar_share_events(invitation_id, event_id)
  select invitation_id, e.id
  from public.calendar_events e
  where e.id = any(p_event_ids)
    and lower(trim(e.account)) = current_email
  on conflict do nothing;
  return invitation_id;
end;
$function$;

revoke all on function public.invite_calendar_viewer(text, text[]) from public, anon;
grant execute on function public.invite_calendar_viewer(text, text[]) to authenticated;

commit;
