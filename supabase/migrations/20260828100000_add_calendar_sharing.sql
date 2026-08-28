begin;

create table if not exists public.calendar_share_invitations (
  id uuid primary key default gen_random_uuid(),
  shared_by text not null,
  invited_email text not null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint calendar_share_different_accounts_check
    check (lower(trim(shared_by)) <> lower(trim(invited_email)))
);

create unique index if not exists calendar_share_accounts_uidx
on public.calendar_share_invitations (
  lower(trim(shared_by)),
  lower(trim(invited_email))
);

create index if not exists calendar_share_received_idx
on public.calendar_share_invitations (lower(trim(invited_email)), status);

alter table public.calendar_share_invitations enable row level security;

drop policy if exists calendar_share_select_participant
on public.calendar_share_invitations;
create policy calendar_share_select_participant
on public.calendar_share_invitations
for select to authenticated
using (
  lower(trim(shared_by)) = public.life_pilot_user_email()
  or lower(trim(invited_email)) = public.life_pilot_user_email()
);

revoke all on table public.calendar_share_invitations from public, anon;
revoke insert, update, delete, truncate, references, trigger
on table public.calendar_share_invitations from authenticated;
grant select on table public.calendar_share_invitations to authenticated;
grant all on table public.calendar_share_invitations to service_role;

create or replace function public.invite_calendar_viewer(p_invited_email text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_email text := public.life_pilot_user_email();
  normalized_invited_email text := lower(trim(coalesce(p_invited_email, '')));
  invitation_id uuid;
begin
  if auth.uid() is null or current_email = '' then
    raise exception 'Authentication required';
  end if;
  if normalized_invited_email = '' or normalized_invited_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
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

  insert into public.calendar_share_invitations (
    shared_by, invited_email, status, responded_at, updated_at
  ) values (
    current_email, normalized_invited_email, 'pending', null, now()
  )
  on conflict (
    (lower(trim(shared_by))), (lower(trim(invited_email)))
  ) do update set
    status = 'pending',
    responded_at = null,
    updated_at = now()
  returning id into invitation_id;

  return invitation_id;
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
    and status = 'pending';

  if not found then
    raise exception 'Pending invitation not found';
  end if;
end;
$$;

create or replace function public.revoke_calendar_invitation(p_invitation_id uuid)
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
end;
$$;

revoke all on function public.invite_calendar_viewer(text) from public, anon;
revoke all on function public.respond_calendar_invitation(uuid, boolean)
from public, anon;
revoke all on function public.revoke_calendar_invitation(uuid)
from public, anon;
grant execute on function public.invite_calendar_viewer(text) to authenticated;
grant execute on function public.respond_calendar_invitation(uuid, boolean)
to authenticated;
grant execute on function public.revoke_calendar_invitation(uuid)
to authenticated;

drop policy if exists calendar_events_select_owner_or_admin
on public.calendar_events;
drop policy if exists calendar_events_select_owner_or_shared
on public.calendar_events;
drop policy if exists "Logged-in users can read all rows"
on public.calendar_events;
create policy calendar_events_select_owner_or_shared
on public.calendar_events
for select to authenticated
using (
  lower(trim(account)) = public.life_pilot_user_email()
  or exists (
    select 1
    from public.calendar_share_invitations invitation
    where invitation.status = 'accepted'
      and lower(trim(invitation.shared_by)) = lower(trim(calendar_events.account))
      and lower(trim(invitation.invited_email)) = public.life_pilot_user_email()
  )
);

drop policy if exists calendar_events_update_owner_or_admin
on public.calendar_events;
drop policy if exists calendar_events_update_owner
on public.calendar_events;
drop policy if exists "Logged-in users can update rows"
on public.calendar_events;
create policy calendar_events_update_owner
on public.calendar_events
for update to authenticated
using (lower(trim(account)) = public.life_pilot_user_email())
with check (lower(trim(account)) = public.life_pilot_user_email());

drop policy if exists calendar_events_delete_owner_or_admin
on public.calendar_events;
drop policy if exists calendar_events_delete_owner
on public.calendar_events;
drop policy if exists "Logged-in users can delete rows"
on public.calendar_events;
create policy calendar_events_delete_owner
on public.calendar_events
for delete to authenticated
using (lower(trim(account)) = public.life_pilot_user_email());

drop policy if exists calendar_events_insert_owner_or_admin
on public.calendar_events;
drop policy if exists calendar_events_insert_owner
on public.calendar_events;
drop policy if exists "Logged-in users can insert rows"
on public.calendar_events;
create policy calendar_events_insert_owner
on public.calendar_events
for insert to authenticated
with check (lower(trim(account)) = public.life_pilot_user_email());

create or replace function public.get_filtered_calendar_events(payload json)
returns table(
  id text, master_graph_url text, master_url text,
  start_date timestamptz, end_date timestamptz,
  start_time text, end_time text,
  country text, city text, location text, name text, type text,
  description text, fee text, unit text, sub_events jsonb, account text,
  repeat_options text, reminder_options text[], is_holiday boolean,
  is_taiwan_holiday boolean, is_approved boolean, age_min numeric,
  age_max numeric, is_free boolean, price_min numeric, price_max numeric,
  is_outdoor boolean, is_like boolean, is_dislike boolean, source text,
  lat double precision, lng double precision,
  map_lat double precision, map_lng double precision
)
language plpgsql
stable
set search_path = ''
as $$
declare
  inputid text := nullif(payload->>'inputid', '');
  inputdates date := nullif(payload->>'inputdates', '')::date;
  inputdatee date := nullif(payload->>'inputdatee', '')::date;
  current_email text := public.life_pilot_user_email();
begin
  if auth.uid() is null or current_email = '' then
    raise exception 'Authentication required';
  end if;

  return query
  select
    e.id, e.master_graph_url, e.master_url, e.start_date, e.end_date,
    e.start_time, e.end_time, e.country, e.city, e.location, e.name,
    e.type, e.description, e.fee, e.unit, e.sub_events, e.account,
    e.repeat_options, e.reminder_options, e.is_holiday,
    e.is_taiwan_holiday, e.is_approved, e.age_min, e.age_max,
    e.is_free, e.price_min, e.price_max, e.is_outdoor,
    null::boolean, null::boolean, e.source, e.lat, e.lng,
    e.map_lat, e.map_lng
  from public.calendar_events e
  where (
      lower(trim(e.account)) = current_email
      or exists (
        select 1
        from public.calendar_share_invitations invitation
        where invitation.status = 'accepted'
          and lower(trim(invitation.shared_by)) = lower(trim(e.account))
          and lower(trim(invitation.invited_email)) = current_email
      )
    )
    and (
      (e.end_date is null and e.start_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
      or
      (e.end_date is not null and e.end_date >= inputdates
        and (inputdatee is null or e.start_date <= inputdatee))
    )
    and (inputid is null or e.id = inputid)
  order by e.start_date, e.start_time, e.account, e.name;
end;
$$;

revoke all on function public.get_filtered_calendar_events(json)
from public, anon;
grant execute on function public.get_filtered_calendar_events(json)
to authenticated;

commit;
