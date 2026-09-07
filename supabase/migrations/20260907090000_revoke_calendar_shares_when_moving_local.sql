begin;

create or replace function public.delete_cloud_records_and_revoke_shares_after_local_copy(
  p_records jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  deleted_count integer;
  current_email text := public.life_pilot_user_email();
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  -- Keep the record deletion and share-state cleanup atomic. If either part
  -- fails, PostgreSQL rolls the complete cloud-to-local operation back.
  deleted_count := public.delete_cloud_records_after_local_copy(p_records);

  delete from public.calendar_share_events selected
  using public.calendar_share_invitations invitation
  where selected.invitation_id = invitation.id
    and lower(trim(invitation.shared_by)) = current_email;

  update public.calendar_share_invitations invitation
  set status = case
        when lower(trim(invitation.shared_by)) = current_email then 'revoked'
        else 'declined'
      end,
      responded_at = case
        when lower(trim(invitation.invited_email)) = current_email then now()
        else invitation.responded_at
      end,
      updated_at = now()
  where (
      lower(trim(invitation.shared_by)) = current_email
      or lower(trim(invitation.invited_email)) = current_email
    )
    and invitation.status in ('pending', 'accepted');

  return deleted_count;
end;
$function$;

revoke all on function public.delete_cloud_records_and_revoke_shares_after_local_copy(jsonb)
from public, anon;
grant execute on function public.delete_cloud_records_and_revoke_shares_after_local_copy(jsonb)
to authenticated, service_role;

commit;
