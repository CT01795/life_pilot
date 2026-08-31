begin;

create or replace function public.get_my_shared_calendar_events()
returns table(
  invitation_id uuid,
  event_id text,
  event_name text,
  start_date timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    invitation.id,
    selected.event_id,
    event.name,
    event.start_date
  from public.calendar_share_invitations invitation
  join public.calendar_share_events selected
    on selected.invitation_id = invitation.id
  join public.calendar_events event
    on event.id = selected.event_id
   and lower(trim(event.account)) = lower(trim(invitation.shared_by))
  where auth.uid() is not null
    and lower(trim(invitation.shared_by)) = public.life_pilot_user_email()
  order by invitation.updated_at desc, event.start_date, event.name;
$$;

create or replace function public.remove_calendar_shared_event(
  p_invitation_id uuid,
  p_event_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.calendar_share_invitations invitation
    where invitation.id = p_invitation_id
      and lower(trim(invitation.shared_by)) = public.life_pilot_user_email()
  ) then
    raise exception 'Invitation not found';
  end if;

  delete from public.calendar_share_events selected
  where selected.invitation_id = p_invitation_id
    and selected.event_id = p_event_id;

  if not found then
    raise exception 'Shared event not found';
  end if;

  if not exists (
    select 1
    from public.calendar_share_events selected
    where selected.invitation_id = p_invitation_id
  ) then
    update public.calendar_share_invitations
    set status = 'revoked', updated_at = now()
    where id = p_invitation_id;
  end if;
end;
$$;

create or replace function public.revoke_calendar_invitation(
  p_invitation_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.calendar_share_invitations
  set status = 'revoked', updated_at = now()
  where id = p_invitation_id
    and lower(trim(shared_by)) = public.life_pilot_user_email()
    and status in ('pending', 'accepted');

  if not found then
    raise exception 'Invitation not found';
  end if;

  delete from public.calendar_share_events selected
  where selected.invitation_id = p_invitation_id;
end;
$$;

revoke all on function public.get_my_shared_calendar_events()
from public, anon;
revoke all on function public.remove_calendar_shared_event(uuid, text)
from public, anon;
revoke all on function public.revoke_calendar_invitation(uuid)
from public, anon;
grant execute on function public.get_my_shared_calendar_events()
to authenticated;
grant execute on function public.remove_calendar_shared_event(uuid, text)
to authenticated;
grant execute on function public.revoke_calendar_invitation(uuid)
to authenticated;

commit;
