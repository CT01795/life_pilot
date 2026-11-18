begin;

-- Dashboard selectors need identity only. Totals, currencies and images are
-- loaded by the selected-account summary, not by the option list.
create or replace function public.get_my_ledger_account_options(
  p_kind text,
  p_project_limit integer default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_limit integer := least(greatest(coalesce(p_project_limit, 5), 1), 100);
  v_result jsonb;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_kind not in ('accounting', 'points') then
    raise exception 'invalid_ledger_kind' using errcode = '22023';
  end if;

  if p_kind = 'accounting' then
    with selected as (
      select 0 section,
        row_number() over (order by a.account, a.id) position,
        jsonb_build_object('id', a.id, 'account', a.account,
          'category', a.category) payload
      from public.accounting_account a
      where lower(trim(a.created_by)) = v_email
        and a.is_valid is true and a.category = 'personal'
      union all
      select recent.section, recent.position, recent.payload
      from (
        select 1 section,
          row_number() over (order by a.created_at desc, a.id) position,
          jsonb_build_object('id', a.id, 'account', a.account,
            'category', a.category) payload
        from public.accounting_account a
        where lower(trim(a.created_by)) = v_email
          and a.is_valid is true and a.category = 'project'
      ) recent where recent.position <= v_limit
    )
    select coalesce(jsonb_agg(payload order by section, position), '[]'::jsonb)
      into v_result from selected;
  else
    with selected as (
      select 0 section,
        row_number() over (order by a.account, a.id) position,
        jsonb_build_object('id', a.id, 'account', a.account,
          'category', a.category) payload
      from public.point_record_account a
      where lower(trim(a.created_by)) = v_email
        and a.is_valid is true and a.category = 'personal'
      union all
      select recent.section, recent.position, recent.payload
      from (
        select 1 section,
          row_number() over (order by a.created_at desc, a.id) position,
          jsonb_build_object('id', a.id, 'account', a.account,
            'category', a.category) payload
        from public.point_record_account a
        where lower(trim(a.created_by)) = v_email
          and a.is_valid is true and a.category = 'project'
      ) recent where recent.position <= v_limit
    )
    select coalesce(jsonb_agg(payload order by section, position), '[]'::jsonb)
      into v_result from selected;
  end if;
  return coalesce(v_result, '[]'::jsonb);
end;
$$;

revoke all on function public.get_my_ledger_account_options(text, integer)
  from public, anon;
grant execute on function public.get_my_ledger_account_options(text, integer)
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
