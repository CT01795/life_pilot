begin;

set local lock_timeout = '5s';

do $retirement_guard$
declare
  target_oid oid;
  target_name text;
  dependent_name text;
begin
  foreach target_name in array array[
    'public.life_pilot_has_active_cloud_plus()',
    'public.life_pilot_subscription_plan_for_user(uuid)'
  ]
  loop
    target_oid := to_regprocedure(target_name);
    if target_oid is null then
      raise exception 'retirement_target_missing:%', target_name;
    end if;

    select p.oid::regprocedure::text
      into dependent_name
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.oid <> target_oid
      and n.nspname not in ('pg_catalog', 'information_schema')
      and position(
        lower(split_part(split_part(target_name, '.', 2), '(', 1))
        in lower(coalesce(p.prosrc, ''))
      ) > 0
    limit 1;

    if dependent_name is not null then
      raise exception 'retirement_target_still_referenced:%:%',
        target_name, dependent_name;
    end if;

    select pg_describe_object(d.classid, d.objid, d.objsubid)
      into dependent_name
    from pg_depend d
    where d.refobjid = target_oid
      and d.deptype in ('n', 'a')
    limit 1;

    if dependent_name is not null then
      raise exception 'retirement_target_has_catalog_dependency:%:%',
        target_name, dependent_name;
    end if;
  end loop;
end;
$retirement_guard$;

drop function public.life_pilot_has_active_cloud_plus() restrict;
drop function public.life_pilot_subscription_plan_for_user(uuid) restrict;

notify pgrst, 'reload schema';

commit;
