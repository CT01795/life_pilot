begin;

-- The importer now uses the date-array v2 RPC. Refuse to retire v1 if a
-- database function still assembles a call to it dynamically.
do $$
begin
  if exists (
    select 1
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where procedure.prokind = 'f'
      and not (
        namespace.nspname = 'public'
        and procedure.proname = 'get_public_event_deduplication_rows'
      )
      and position(
        'get_public_event_deduplication_rows('
        in pg_catalog.pg_get_functiondef(procedure.oid)
      ) > 0
  ) then
    raise exception 'public_event_deduplication_v1_still_has_dynamic_callers';
  end if;
end;
$$;

drop function if exists public.get_public_event_deduplication_rows(boolean, date[]);

notify pgrst, 'reload schema';
commit;
