create or replace function public.respond_calendar_invitation(
  p_invitation_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.calendar_share_invitations
  set status = case when p_accept then 'accepted' else 'declined' end,
      responded_at = now(),
      updated_at = now()
  where id = p_invitation_id
    and lower(trim(invited_email)) = public.life_pilot_user_email()
    and (
      status = 'pending'
      or (status = 'accepted' and p_accept = false)
    );

  if not found then
    raise exception 'Invitation cannot be updated';
  end if;

  if not p_accept then
    delete from public.calendar_share_events
    where invitation_id = p_invitation_id;
  end if;
end;
$$;

revoke all on function public.respond_calendar_invitation(uuid, boolean)
from public, anon;
grant execute on function public.respond_calendar_invitation(uuid, boolean)
to authenticated;
