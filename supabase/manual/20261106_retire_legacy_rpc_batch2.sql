-- Approved retirement batch 2 (2026-11-06).
-- Prerequisites: current App/Edge deployed, old consumers retired, dynamic SQL
-- audited, and definitions/owner/ACL saved in the adjacent snapshot JSON.
-- Removes only these fifteen exact function signatures; no business data.
begin;
set local lock_timeout = '5s';

do $audit$
declare target record; caller text;
begin
  for target in
    select p.oid, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.oid in (
        to_regprocedure('public.admin_set_user_subscription(text,text,timestamp with time zone,text,boolean,integer,integer,integer,integer,integer,integer,integer)'),
        to_regprocedure('public.delete_my_account_and_data()'),
        to_regprocedure('public.get_my_ledger_history_window(text,uuid,text,timestamp with time zone,timestamp with time zone,boolean)'),
        to_regprocedure('public.get_my_question_group_counts(text,bigint)'),
        to_regprocedure('public.get_my_recommendation_submission_usage()'),
        to_regprocedure('public.get_my_vendor_content_analytics()'),
        to_regprocedure('public.get_subscription_pricing_versions()'),
        to_regprocedure('public.get_vendor_pricing_versions()'),
        to_regprocedure('public.life_pilot_cached_map_coordinates(text,text)'),
        to_regprocedure('public.list_my_ledger_change_proposals(uuid,integer,integer)'),
        to_regprocedure('public.list_my_shared_ledger_overview(text,integer,integer,timestamp with time zone,timestamp with time zone,timestamp with time zone,timestamp with time zone)'),
        to_regprocedure('public.list_my_shared_ledgers(integer,integer)'),
        to_regprocedure('public.update_accounting_detail(uuid,bigint,text,text)'),
        to_regprocedure('public.update_accounting_detail_with_date(uuid,numeric,text,text,timestamp with time zone,text,text)'),
        to_regprocedure('public.update_point_record_detail(uuid,bigint,text,timestamp with time zone,text,text)')
      )
  loop
    select q.oid::regprocedure::text into caller
    from pg_proc q join pg_namespace n on n.oid = q.pronamespace
    where n.nspname not in ('pg_catalog', 'information_schema')
      and q.prokind in ('f', 'p') and q.oid <> target.oid
      and q.prosrc ~ ('(^|[^A-Za-z0-9_])' || target.proname || '([^A-Za-z0-9_]|$)')
    limit 1;
    if found then
      raise exception 'legacy_rpc_still_referenced: % by %',
        target.oid::regprocedure, caller;
    end if;
  end loop;
end;
$audit$;

-- Exact signatures and RESTRICT: abort if any registered dependency appears.
drop function if exists public.admin_set_user_subscription(text,text,timestamp with time zone,text,boolean,integer,integer,integer,integer,integer,integer,integer) restrict;
drop function if exists public.delete_my_account_and_data() restrict;
drop function if exists public.get_my_ledger_history_window(text,uuid,text,timestamp with time zone,timestamp with time zone,boolean) restrict;
drop function if exists public.get_my_question_group_counts(text,bigint) restrict;
drop function if exists public.get_my_recommendation_submission_usage() restrict;
drop function if exists public.get_my_vendor_content_analytics() restrict;
drop function if exists public.get_subscription_pricing_versions() restrict;
drop function if exists public.get_vendor_pricing_versions() restrict;
drop function if exists public.life_pilot_cached_map_coordinates(text,text) restrict;
drop function if exists public.list_my_ledger_change_proposals(uuid,integer,integer) restrict;
drop function if exists public.list_my_shared_ledger_overview(text,integer,integer,timestamp with time zone,timestamp with time zone,timestamp with time zone,timestamp with time zone) restrict;
drop function if exists public.list_my_shared_ledgers(integer,integer) restrict;
drop function if exists public.update_accounting_detail(uuid,bigint,text,text) restrict;
drop function if exists public.update_accounting_detail_with_date(uuid,numeric,text,text,timestamp with time zone,text,text) restrict;
drop function if exists public.update_point_record_detail(uuid,bigint,text,timestamp with time zone,text,text) restrict;

notify pgrst, 'reload schema';
commit;

select signature, to_regprocedure(signature) is null as removed
from unnest(array[
  'public.admin_set_user_subscription(text,text,timestamp with time zone,text,boolean,integer,integer,integer,integer,integer,integer,integer)',
  'public.delete_my_account_and_data()',
  'public.get_my_ledger_history_window(text,uuid,text,timestamp with time zone,timestamp with time zone,boolean)',
  'public.get_my_question_group_counts(text,bigint)',
  'public.get_my_recommendation_submission_usage()',
  'public.get_my_vendor_content_analytics()',
  'public.get_subscription_pricing_versions()',
  'public.get_vendor_pricing_versions()',
  'public.life_pilot_cached_map_coordinates(text,text)',
  'public.list_my_ledger_change_proposals(uuid,integer,integer)',
  'public.list_my_shared_ledger_overview(text,integer,integer,timestamp with time zone,timestamp with time zone,timestamp with time zone,timestamp with time zone)',
  'public.list_my_shared_ledgers(integer,integer)',
  'public.update_accounting_detail(uuid,bigint,text,text)',
  'public.update_accounting_detail_with_date(uuid,numeric,text,text,timestamp with time zone,text,text)',
  'public.update_point_record_detail(uuid,bigint,text,timestamp with time zone,text,text)'
]) as signatures(signature);
