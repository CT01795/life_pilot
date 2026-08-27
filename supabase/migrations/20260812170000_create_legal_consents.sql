-- Records the versioned legal documents a signed-in user accepted.
-- Review this migration in the Supabase SQL Editor before running it.

create table if not exists public.legal_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  privacy_policy_version text not null,
  terms_of_service_version text not null,
  accepted_at timestamptz not null default now(),
  unique (user_id, privacy_policy_version, terms_of_service_version)
);

alter table public.legal_consents enable row level security;

create policy "Users can read their own legal consent records"
on public.legal_consents
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can create their own legal consent records"
on public.legal_consents
for insert
to authenticated
with check (auth.uid() = user_id);

create index if not exists legal_consents_user_id_accepted_at_idx
on public.legal_consents (user_id, accepted_at desc);
