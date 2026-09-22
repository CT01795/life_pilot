begin;

create or replace function public.delete_my_account_and_data()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_id uuid := auth.uid();
  target_email text := public.life_pilot_user_email();
begin
  if target_id is null or target_email = '' then
    raise exception 'authentication_required';
  end if;

  perform public.cleanup_subscription_data(null, 'all');

  delete from public.feedback
   where lower(trim(created_by)) = target_email;
  delete from public.dashboard_setting
   where lower(trim(account)) = target_email;
  delete from public.user_module
   where lower(trim(account)) = target_email;
  delete from public.recommended_events_favor
   where lower(trim(account)) = target_email;
  delete from public.recommended_events_stat
   where lower(trim(account)) = target_email;
  delete from public.legal_consents where user_id = target_id;
  delete from public.user_subscription_entitlements where user_id = target_id;
  delete from public.subscription_payment_events where user_id = target_id;
  delete from public.subscription_cleanup_audit where user_id = target_id;
  delete from public.user_subscriptions where user_id = target_id;
  delete from auth.users where id = target_id;
end;
$function$;

revoke all on function public.delete_my_account_and_data() from public, anon;
grant execute on function public.delete_my_account_and_data() to authenticated;

commit;
