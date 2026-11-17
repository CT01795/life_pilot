begin;

set local lock_timeout = '5s';

do $retirement_guard$
declare
  target_oid oid := to_regprocedure(
    'public.backfill_my_ledger_thumbnail(text,uuid,text,text)'
  );
  dependent_name text;
begin
  if target_oid is null then
    raise exception 'retirement_target_missing:%',
      'public.backfill_my_ledger_thumbnail(text,uuid,text,text)';
  end if;

  select p.oid::regprocedure::text
    into dependent_name
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.oid <> target_oid
    and n.nspname not in ('pg_catalog', 'information_schema')
    and coalesce(p.prosrc, '') ~*
      '\mbackfill_my_ledger_thumbnail\M'
  limit 1;

  if dependent_name is not null then
    raise exception 'retirement_target_still_referenced:%',
      dependent_name;
  end if;

  select pg_describe_object(d.classid, d.objid, d.objsubid)
    into dependent_name
  from pg_depend d
  where d.refobjid = target_oid
    and d.deptype in ('n', 'a')
  limit 1;

  if dependent_name is not null then
    raise exception 'retirement_target_has_catalog_dependency:%',
      dependent_name;
  end if;
end;
$retirement_guard$;

drop function
  public.backfill_my_ledger_thumbnail(text, uuid, text, text)
  restrict;

notify pgrst, 'reload schema';

commit;
