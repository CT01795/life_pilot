-- Manual, post-Edge-deployment cleanup; NOT an automatic migration.
-- Retire old clients/external callers and deploy the new life-pilot-services
-- handler BEFORE executing this script in SQL Editor.
-- Only function definitions are removed, never business rows or tables.
begin;
set local lock_timeout = '5s';

-- Extra guard for PL/pgSQL references not recorded in pg_depend. This does
-- not prove the absence of external or dynamically assembled callers.
do $audit$
declare target record; caller text;
begin
  for target in
    select p.oid, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.oid in (
        to_regprocedure('public.admin_list_account_deletion_requests()'),
        to_regprocedure('public.admin_list_user_subscription_summaries()'),
        to_regprocedure('public.fetch_user_progress(text,text,text)'),
        to_regprocedure('public.life_pilot_edge_map_target(text,text)')
      )
  loop
    select q.oid::regprocedure::text into caller
    from pg_proc q join pg_namespace n on n.oid = q.pronamespace
    where n.nspname = 'public' and q.prokind = 'f'
      and q.oid <> target.oid
      and q.prosrc ~ ('\m' || target.proname || '\M')
    limit 1;
    if found then
      raise exception 'legacy_rpc_still_referenced: % by %',
        target.oid::regprocedure, caller;
    end if;
  end loop;
end;
$audit$;

-- Stop on registered dependencies; never replace RESTRICT with CASCADE.
drop function if exists public.admin_list_account_deletion_requests() restrict;
drop function if exists public.admin_list_user_subscription_summaries() restrict;
drop function if exists public.fetch_user_progress(text,text,text) restrict;
drop function if exists public.life_pilot_edge_map_target(text,text) restrict;

notify pgrst, 'reload schema';
commit;

select signature, to_regprocedure(signature) is null as removed
from unnest(array[
  'public.admin_list_account_deletion_requests()',
  'public.admin_list_user_subscription_summaries()',
  'public.fetch_user_progress(text,text,text)',
  'public.life_pilot_edge_map_target(text,text)'
]) as signatures(signature);
