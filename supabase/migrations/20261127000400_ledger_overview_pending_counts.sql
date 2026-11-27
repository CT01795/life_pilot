begin;

-- RLS still applies to the account page. The existing per-account helper
-- enforces share-owner eligibility and does not count unseen proposals.
create or replace function public.list_my_ledger_overview_page(
  p_kind text,
  p_expected_email text,
  p_category text,
  p_search text,
  p_offset integer,
  p_limit integer
)
returns setof jsonb
language plpgsql stable security invoker set search_path = ''
as $$
begin
  if auth.uid() is null or nullif(trim(p_expected_email), '') is null
    or lower(trim(p_expected_email)) is distinct from public.life_pilot_user_email() then
    raise exception 'account_scope_changed' using errcode = '42501';
  end if;
  if p_offset is null or p_offset < 0 or p_limit is null or p_limit not between 1 and 100 then
    raise exception 'invalid_page' using errcode = '22023';
  end if;

  if p_kind = 'accounting' then
    return query
    with page as materialized (
      select a.id, a.account, a.category, a.balance, a.main_currency, a.exchange_rate
      from public.accounting_account a
      where lower(trim(a.created_by)) = public.life_pilot_user_email() and a.is_valid
        and (p_category is null or a.category::text = p_category)
        and (nullif(trim(p_search), '') is null or a.account ilike '%' || trim(p_search) || '%')
      order by a.account, a.id offset p_offset limit p_limit
    )
    select to_jsonb(page) || jsonb_build_object('pending_count',
      public.get_my_ledger_account_pending_count(p_kind, page.id::text))
    from page order by page.account, page.id;
  elsif p_kind = 'points' then
    return query
    with page as materialized (
      select a.id, a.account, a.category, a.points
      from public.point_record_account a
      where lower(trim(a.created_by)) = public.life_pilot_user_email() and a.is_valid
        and (p_category is null or a.category::text = p_category)
        and (nullif(trim(p_search), '') is null or a.account ilike '%' || trim(p_search) || '%')
      order by a.account, a.id offset p_offset limit p_limit
    )
    select to_jsonb(page) || jsonb_build_object('pending_count',
      public.get_my_ledger_account_pending_count(p_kind, page.id::text))
    from page order by page.account, page.id;
  else
    raise exception 'invalid_ledger_kind' using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.list_my_ledger_overview_page(text,text,text,text,integer,integer) from public, anon;
grant execute on function public.list_my_ledger_overview_page(text,text,text,text,integer,integer) to authenticated;
notify pgrst, 'reload schema';
commit;
