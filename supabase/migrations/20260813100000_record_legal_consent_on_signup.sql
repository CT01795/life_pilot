-- Records legal consent when an auth user is created.
-- Run this after 20260812170000_create_legal_consents.sql.
-- Review this migration in the Supabase SQL Editor before running it.

create or replace function public.record_legal_consent_on_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.legal_consents (
    user_id,
    privacy_policy_version,
    terms_of_service_version
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'privacy_policy_version', 'unknown'),
    coalesce(new.raw_user_meta_data ->> 'terms_of_service_version', 'unknown')
  )
  on conflict (user_id, privacy_policy_version, terms_of_service_version)
  do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_record_legal_consent on auth.users;

create trigger on_auth_user_created_record_legal_consent
after insert on auth.users
for each row execute procedure public.record_legal_consent_on_signup();
