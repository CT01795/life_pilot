begin;

-- The app reads compact feedback rows from get_feedback_summary_page and
-- fetches full content/screenshots only after a row is opened. Retire any
-- older full-content paging overload only when PostgreSQL and function-body
-- checks both confirm that nothing still calls it.
do $$
declare
  candidate record;
  textual_caller regprocedure;
begin
  for candidate in
    select
      p.oid,
      p.oid::regprocedure as signature,
      p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and lower(p.proname) like '%feedback%page%'
      and p.oid <>
          'public.get_feedback_summary_page(text[],timestamptz,bigint,integer)'::regprocedure
      and p.prosrc ~* '\mfrom[[:space:]]+(public\.)?feedback\M'
      and lower(p.prosrc) like '%limit%'
      and (
        p.prosrc ~* '\mcontent\M'
        or p.prosrc ~* 'select[[:space:]]+\*'
      )
  loop
    select caller.oid::regprocedure
    into textual_caller
    from pg_proc caller
    join pg_namespace caller_namespace
      on caller_namespace.oid = caller.pronamespace
    where caller.oid <> candidate.oid
      and caller_namespace.nspname in ('public', 'auth', 'storage')
      and caller.prosrc ~* (
        '(^|[^a-z0-9_])' || candidate.proname || '[[:space:]]*\('
      )
    limit 1;

    if textual_caller is not null then
      raise exception 'legacy_feedback_page_still_called:%:%',
        candidate.signature, textual_caller;
    end if;

    -- RESTRICT is deliberate: registered view/function dependencies must
    -- stop the migration instead of being removed transitively.
    execute format('drop function %s restrict', candidate.signature);
  end loop;
end;
$$;

notify pgrst, 'reload schema';
commit;
