begin;

create table if not exists public.calendar_share_events (
  invitation_id uuid not null references public.calendar_share_invitations(id)
    on delete cascade,
  -- calendar_events uses a composite identity, so ownership is validated by
  -- invite_calendar_viewer instead of an invalid single-column foreign key.
  event_id text not null,
  created_at timestamptz not null default now(),
  primary key (invitation_id, event_id)
);

create index if not exists calendar_share_events_event_idx
on public.calendar_share_events (event_id, invitation_id);

-- Preserve the events visible through invitations created before this change.
insert into public.calendar_share_events (invitation_id, event_id)
select invitation.id, event.id
from public.calendar_share_invitations invitation
join public.calendar_events event
  on lower(trim(event.account)) = lower(trim(invitation.shared_by))
on conflict do nothing;

alter table public.calendar_share_events enable row level security;

drop policy if exists calendar_share_events_select_participant
on public.calendar_share_events;
create policy calendar_share_events_select_participant
on public.calendar_share_events
for select to authenticated
using (
  exists (
    select 1
    from public.calendar_share_invitations invitation
    where invitation.id = calendar_share_events.invitation_id
      and (
        lower(trim(invitation.shared_by)) = public.life_pilot_user_email()
        or lower(trim(invitation.invited_email)) = public.life_pilot_user_email()
      )
  )
);

revoke all on table public.calendar_share_events from public, anon;
revoke insert, update, delete, truncate, references, trigger
on table public.calendar_share_events from authenticated;
grant select on table public.calendar_share_events to authenticated;
grant all on table public.calendar_share_events to service_role;

drop function if exists public.invite_calendar_viewer(text);
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

  insert into public.calendar_share_events (invitation_id, event_id)
  select v_invitation_id, event.id
  from public.calendar_events event
  where event.id = any(p_event_ids)
    and lower(trim(event.account)) = current_email
  on conflict do nothing;
  get diagnostics inserted_event_count = row_count;

  if inserted_event_count = 0 then
    raise exception 'No owned events selected';
  end if;

  return v_invitation_id;
end;
$$;

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
end;
$$;

drop policy if exists calendar_events_select_owner_or_shared
on public.calendar_events;
create policy calendar_events_select_owner_or_shared
on public.calendar_events
for select to authenticated
using (
  lower(trim(account)) = public.life_pilot_user_email()
  or exists (
    select 1
    from public.calendar_share_invitations invitation
    join public.calendar_share_events selected
      on selected.invitation_id = invitation.id
    where invitation.status = 'accepted'
      and selected.event_id = calendar_events.id
      and lower(trim(invitation.shared_by)) = lower(trim(calendar_events.account))
      and lower(trim(invitation.invited_email)) = public.life_pilot_user_email()
  )
);

revoke all on function public.invite_calendar_viewer(text, text[])
from public, anon;
grant execute on function public.invite_calendar_viewer(text, text[])
to authenticated;

commit;
