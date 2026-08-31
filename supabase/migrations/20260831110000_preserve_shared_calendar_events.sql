begin;

create or replace function public.invite_calendar_viewer(
  p_invited_email text,
  p_event_ids text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_email text := public.life_pilot_user_email();
  normalized_invited_email text := lower(trim(coalesce(p_invited_email, '')));
  v_invitation_id uuid;
  inserted_event_count integer;
begin
  if auth.uid() is null or current_email = '' then
    raise exception 'Authentication required';
  end if;
  if normalized_invited_email = ''
      or normalized_invited_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Invalid email';
  end if;
  if normalized_invited_email = current_email then
    raise exception 'Cannot invite yourself';
  end if;
  if not exists (
    select 1 from auth.users u where lower(u.email) = normalized_invited_email
  ) then
    raise exception 'Account not found';
  end if;
  if coalesce(array_length(p_event_ids, 1), 0) = 0 then
    raise exception 'Choose at least one event';
  end if;

  insert into public.calendar_share_invitations (
    shared_by, invited_email, status, responded_at, updated_at
  ) values (
    current_email, normalized_invited_email, 'pending', null, now()
  )
  on conflict (
    (lower(trim(shared_by))), (lower(trim(invited_email)))
  ) do update set
    status = case
      when calendar_share_invitations.status = 'accepted' then 'accepted'
      else 'pending'
    end,
    responded_at = case
      when calendar_share_invitations.status = 'accepted'
        then calendar_share_invitations.responded_at
      else null
    end,
    updated_at = now()
  returning id into v_invitation_id;

  -- Add the newly selected events without removing events shared previously.
  insert into public.calendar_share_events (invitation_id, event_id)
  select v_invitation_id, event.id
  from public.calendar_events event
  where event.id = any(p_event_ids)
    and lower(trim(event.account)) = current_email
  on conflict do nothing;
  get diagnostics inserted_event_count = row_count;

  -- Selecting only events already shared is still a successful operation.
  if inserted_event_count = 0 and not exists (
    select 1
    from public.calendar_share_events selected
    where selected.invitation_id = v_invitation_id
      and selected.event_id = any(p_event_ids)
  ) then
    raise exception 'No owned events selected';
  end if;

  return v_invitation_id;
end;
$$;

revoke all on function public.invite_calendar_viewer(text, text[])
from public, anon;
grant execute on function public.invite_calendar_viewer(text, text[])
to authenticated;

commit;
