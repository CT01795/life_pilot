-- Run only after:
-- 1. 20261119000100_external_cache_batches.sql is applied;
-- 2. the new Edge Function and App are deployed;
-- 3. 20261119_audit_single_holiday_cache_rpc.sql reports
--    database_retirement_ready=true and both legacy row counts are zero.
begin;

do $$
declare
  v_target oid := to_regprocedure(
    'public.life_pilot_cached_holidays(integer,text)'
  );
begin
  if to_regprocedure(
    'public.life_pilot_cached_holidays_batch(integer[],text)'
  ) is null then
    raise exception 'holiday_batch_replacement_missing';
  end if;
  if v_target is null then
    return;
  end if;
  if exists (
    select 1
    from pg_depend
    where refobjid = v_target
      and deptype not in ('i', 'e')
  ) then
    raise exception 'holiday_cache_registered_dependency_exists';
  end if;
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.oid <> v_target
      and p.prokind in ('f', 'p')
      and n.nspname not in ('pg_catalog', 'information_schema')
      and pg_get_functiondef(p.oid) ilike '%life_pilot_cached_holidays(%'
  ) then
    raise exception 'holiday_cache_function_reference_exists';
  end if;
end;
$$;

drop function if exists public.life_pilot_cached_holidays(integer, text)
  restrict;

notify pgrst, 'reload schema';
commit;

select
  to_regprocedure('public.life_pilot_cached_holidays(integer,text)') is null
    as legacy_holiday_cache_removed,
  to_regprocedure(
    'public.life_pilot_cached_holidays_batch(integer[],text)'
  ) is not null as batch_holiday_cache_retained;
